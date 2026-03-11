class_name NPCBase
extends CharacterBody3D

@export var movement_animation_blend_smooth := 3
@export var rotation_speed := 5.0

@onready var feet_raycast := $Character/FeetRay
@onready var ladder_check_raycast := $Character/LadderCheck
@onready var climb_finished_raycast := $Character/ClimbFinishedRay
@onready var animation_tree: AnimationTree = $Character/Armature/AnimationTree
@onready var character := $Character
@onready var character_anchor := $CharacterAnchor
@onready var target := $"../Target"
@onready var navigation_agent_3d := $NavigationAgent3D
@onready var player := $"../Player"

const SPEED = 2
const JUMP_VELOCITY = 3
const STOP_DISTANCE = 1.0
const WAIT_DISTANCE = 4

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var movement_animation_blend := Vector2.ZERO
var using_ladder := false
var finshed_climbing_timer := 0.0
var finshed_climbing_threshold := 1.5
var finish_start_pos: Vector3
var finish_target_pos: Vector3
var finishing_climb := false

enum LadderDescentState { NONE, MOVING_ACROSS, MOVING_DOWN }
var ladder_descent_state := LadderDescentState.NONE
var cached_descent_target: Vector3  # Cache on state entry

func _physics_process(delta: float) -> void:
	finshed_climbing_timer += delta
	if not target:
		return

	if ladder_descent_state != LadderDescentState.NONE:
		_handle_ladder_descent_approach(delta)
		return

	if not using_ladder:
		navigation_agent_3d.set_target_position(target.global_position)
	check_ladder()
	
	if finishing_climb:
		global_position = finish_start_pos.lerp(finish_target_pos, finshed_climbing_timer)
		if finshed_climbing_timer >= finshed_climbing_threshold:
			finishing_climb = false

	if finshed_climbing_timer > finshed_climbing_threshold and ladder_check_raycast.is_colliding():
		cached_descent_target = _get_ladder_descent_start()  # Cache here once
		var flat_dist := Vector2(
			global_position.x - cached_descent_target.x,
			global_position.z - cached_descent_target.z
		).length()
		# Only do across phase if we actually need to travel horizontally
		ladder_descent_state = LadderDescentState.MOVING_ACROSS if flat_dist > 0.1 else LadderDescentState.MOVING_DOWN
		return

	if near_ladder() and not handle_ladder_jump():
		using_ladder = true
		climb_ladder()
	else:
		handle_ground_movement(get_move_direction(), get_input_dir(), delta)
	move_and_slide()
	update_character_rotation(get_target_rotation_y(), delta)

func _handle_ladder_descent_approach(delta: float) -> void:
	velocity = Vector3.ZERO

	var target_rot_y: float = _get_ladder_rotation()
	rotation.y = lerp_angle(rotation.y, target_rot_y, rotation_speed * delta)
	character.rotation.y = lerp_angle(character.rotation.y, character_anchor.rotation.y, 3 * delta)

	if ladder_descent_state == LadderDescentState.MOVING_ACROSS:
		var flat_target := Vector3(cached_descent_target.x, global_position.y, cached_descent_target.z)
		global_position = global_position.lerp(flat_target, delta * rotation_speed)

		var flat_dist := Vector2(
			global_position.x - cached_descent_target.x,
			global_position.z - cached_descent_target.z
		).length()
		if flat_dist < 0.05:
			ladder_descent_state = LadderDescentState.MOVING_DOWN

	elif ladder_descent_state == LadderDescentState.MOVING_DOWN:
		global_position = global_position.lerp(cached_descent_target, delta * rotation_speed)

		if global_position.distance_to(cached_descent_target) < 0.05:
			ladder_descent_state = LadderDescentState.NONE
			finshed_climbing_timer = 0.0

func get_input_dir() -> Vector2:
	var dir = get_move_direction()
	if dir.length() < 0.01:
		return Vector2.ZERO
	var local = basis.inverse() * dir
	return Vector2(local.x, local.z)

func _get_ladder_climb_direction() -> float:
	var next = navigation_agent_3d.get_next_path_position()
	var y_delta = next.y - global_position.y
	if abs(y_delta) < 0.2:
		return 0.0
	return sign(y_delta)
	
func _get_ladder_to_descend():
	if finshed_climbing_timer < finshed_climbing_threshold:
		return null
	var ladders = get_tree().get_root().find_children("*Ladder*", "", true, false)
	var nearest_ladder = null
	var nearest_dist = INF

	for ladder in ladders:
		
		var nav_link = ladder.get_node_or_null("NavigationLink3D")
		if nav_link == null:
			continue

		var end_pos = ladder.to_global(nav_link.end_position)
		var dist = global_position.distance_to(end_pos)

		if dist < nearest_dist:
			nearest_dist = dist
			nearest_ladder = ladder
	
	if nearest_dist < 1.3:
		return nearest_ladder

	return null

func get_move_direction() -> Vector3:
	if _is_near_destination():
		return Vector3.ZERO
	if _is_too_far():
		return Vector3.ZERO
	var next_pos = navigation_agent_3d.get_next_path_position()
	var dir = (next_pos - global_position)
	dir.y = 0
	if dir.length() < 0.01:
		return Vector3.ZERO
	return dir.normalized()
	
func _get_ladder_rotation():
	if _get_ladder_to_descend():
		return _get_ladder_to_descend().rotation.y + deg_to_rad(90)
	return 0
	
func _get_ladder_descent_start():
	var ladder = _get_ladder_to_descend()
	if ladder:
		var nav_link = ladder.get_node_or_null("NavigationLink3D") as NavigationLink3D
		if nav_link:
			return nav_link.to_global(nav_link.end_position + Vector3(1.5, 0, 0))
	return global_position

func get_target_rotation_y() -> float:
	if _is_too_far():
		var to_player = (player.global_position - global_position)
		to_player.y = 0
		if to_player.length() > 0.01:
			return atan2(-to_player.x, -to_player.z)
		return rotation.y
	if _is_near_destination():
		var to_target = (target.global_position - global_position)
		to_target.y = 0
		if to_target.length() > 0.01:
			return atan2(-to_target.x, -to_target.z)
		return rotation.y
	var dir = get_move_direction()
	if dir.length() > 0.01:
		return atan2(-dir.x, -dir.z)
	return rotation.y

func update_character_rotation(target_rotation_y: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)
	character.rotation.y = lerp_angle(character.rotation.y, character_anchor.rotation.y, 3 * delta)

func check_ladder() -> void:
	if not feet_raycast.is_colliding():
		using_ladder = false

func near_ladder() -> bool:
	return feet_raycast.is_colliding()

func handle_ladder_jump() -> bool:
	return false

func climb_ladder() -> void:
	var state_machine = animation_tree["parameters/playback"]
	var normal = feet_raycast.get_collision_normal()
	character.look_at(global_position + normal, Vector3.UP)
	character.rotation.x = 0
	character.rotation.z = 0
	velocity = Vector3.ZERO
	var climb_input = _get_ladder_climb_direction()
	if is_on_floor() and climb_input < 0:
		dismount_ladder()
		return
	if climb_input != 0:
		velocity.y = climb_input
		state_machine.travel("Climb")
		animation_tree.set("parameters/Climb/Climb Direction/scale", sign(climb_input))
	else:
		animation_tree.set("parameters/Climb/Climb Direction/scale", 0)
	if climb_finished_raycast.is_colliding() and climb_input > 0:
		finish_climbing()

func dismount_ladder() -> void:
	var launch_normal = feet_raycast.get_collision_normal()
	velocity = launch_normal * 2.0
	velocity.y = 1.0
	using_ladder = false
	
func get_top_ladder_exit() -> Vector3:
	if not feet_raycast.is_colliding():
		return global_position
	var ladder = feet_raycast.get_collider().get_parent().get_node("NavigationLink3D") as NavigationLink3D
	if not ladder:
		return global_position
	return ladder.to_global(ladder.end_position)

func finish_climbing():
	if climb_finished_raycast.is_colliding():
		var state_machine = animation_tree["parameters/playback"]
		state_machine.travel("Finish Climbing")
		finish_start_pos = global_position
		finish_target_pos = get_top_ladder_exit() + Vector3(0, 1, 0)
		finshed_climbing_timer = 0.0
		finishing_climb = true

func handle_ground_movement(move_direction: Vector3, input_dir: Vector2, delta: float) -> void:
	apply_gravity(delta)
	apply_movement(move_direction)
	update_movement_animation(input_dir, delta)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func apply_movement(move_direction: Vector3) -> void:
	if move_direction.length() > 0.01:
		velocity.x = move_direction.x * SPEED
		velocity.z = move_direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

func update_movement_animation(input_dir: Vector2, delta: float) -> void:
	var state_machine = animation_tree["parameters/playback"]
	if not is_on_floor():
		state_machine.travel("Fall")
	elif input_dir != Vector2.ZERO:
		state_machine.travel("Move")
		movement_animation_blend = movement_animation_blend.lerp(input_dir, 1.0 - exp(-movement_animation_blend_smooth * delta))
		animation_tree.set("parameters/Move/blend_position", movement_animation_blend)
	else:
		state_machine.travel("Idle")

func _to_target_distance() -> float:
	var to_target = (target.global_position - global_position)
	to_target.y = 0
	return to_target.length()

func _is_near_destination() -> bool:
	return _to_target_distance() < STOP_DISTANCE

func _is_too_far() -> bool:
	var to_player = (player.global_position - global_position)
	to_player.y = 0
	return to_player.length() > WAIT_DISTANCE
