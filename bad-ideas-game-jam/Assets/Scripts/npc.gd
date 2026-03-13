class_name NPC
extends BaseCharacter

@onready var navigation_agent_3d := $NavigationAgent3D
@onready var player := $"../Player"

const NPC_SPEED = 1.5
const STOP_DISTANCE = 1.0
const WAIT_DISTANCE = 10.0
const STUCK_TIME_THRESHOLD = 2.5
const STUCK_DISTANCE_THRESHOLD = 0.3
const STUCK_SAMPLE_INTERVAL = 0.5
const UNSTICK_DETOUR_DISTANCE = 3.0
const UNSTICK_DETOUR_DURATION = 2.0

var target_position := Vector3.ZERO
var _has_target := false

var climb_target_y := 0.0
var stuck_timer := 0.0
var stuck_sample_timer := 0.0
var last_sampled_position := Vector3.ZERO
var unstick_timer := 0.0
var unstick_target := Vector3.ZERO

func _ready() -> void:
	super._ready()
	last_sampled_position = global_position

func set_target_position(pos: Vector3) -> void:
	target_position = pos
	_has_target = true

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _has_target:
		return
	if unstick_timer > 0:
		unstick_timer -= delta
		navigation_agent_3d.set_target_position(unstick_target)
	else:
		navigation_agent_3d.set_target_position(target_position)
	apply_gravity(delta)
	apply_movement()
	update_movement_animation(get_input_dir(), delta)
	update_character_rotation(get_target_rotation_y(), delta)
	move_and_slide()
	update_climb_position()
	dismount_ladder()
	check_stuck(delta)
	if climb_cooldown > 0:
		climb_cooldown -= delta

func get_speed() -> float:
	return NPC_SPEED

func start_climbing(ladder: Node3D) -> void:
	super.start_climbing(ladder)
	var mid_y = (ladder.start_y() + ladder.end_y()) / 2.0
	climb_target_y = ladder.end_y() + 2 if global_position.y < mid_y else ladder.start_y() - 2

func get_climb_input() -> float:
	if not is_climbing or not current_ladder:
		return 0.0
	var diff = climb_target_y - global_position.y
	if abs(diff) < 0.1:
		return 0.0
	return sign(diff)

func check_stuck(delta: float) -> void:
	if is_climbing or _is_near_destination() or _is_too_far() or unstick_timer > 0:
		stuck_timer = 0.0
		stuck_sample_timer = 0.0
		last_sampled_position = global_position
		return
	stuck_sample_timer += delta
	if stuck_sample_timer >= STUCK_SAMPLE_INTERVAL:
		var moved = global_position.distance_to(last_sampled_position)
		var should_be_moving = not _is_near_destination() and not _is_too_far()
		if should_be_moving and moved < STUCK_DISTANCE_THRESHOLD:
			stuck_timer += STUCK_SAMPLE_INTERVAL
			if stuck_timer >= STUCK_TIME_THRESHOLD:
				unstick()
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
		last_sampled_position = global_position
		stuck_sample_timer = 0.0

func unstick() -> void:
	var move_dir = get_move_direction()
	if move_dir.length() < 0.01:
		move_dir = (target_position - global_position).normalized()
		move_dir.y = 0
	var perp = Vector3(-move_dir.z, 0, move_dir.x)
	if randi() % 2 == 0:
		perp = -perp
	unstick_target = global_position + perp * UNSTICK_DETOUR_DISTANCE
	unstick_timer = UNSTICK_DETOUR_DURATION

func get_move_direction() -> Vector3:
	if _is_near_destination() or _is_too_far():
		return Vector3.ZERO
	var dir = navigation_agent_3d.get_next_path_position() - global_position
	dir.y = 0
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO

func get_input_dir() -> Vector2:
	if is_climbing:
		return Vector2(0.0, -get_climb_input())
	var dir = get_move_direction()
	if dir.length() < 0.01:
		return Vector2.ZERO
	var local = basis.inverse() * dir
	return Vector2(local.x, local.z)

func apply_movement() -> void:
	if is_climbing:
		apply_climbing_movement()
		return
	var move_direction = get_move_direction()
	var desired_velocity := Vector3.ZERO
	if move_direction.length() > 0.01:
		desired_velocity = move_direction * NPC_SPEED
	navigation_agent_3d.set_velocity(desired_velocity)

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	if not is_on_floor():
		pass  # gravity is handled separately, don't overwrite y

func dismount_ladder() -> void:
	if is_climbing and is_on_floor() and get_climb_input() < 0 and current_ladder.end_y() > global_position.y:
		stop_climbing()

func get_target_rotation_y() -> float:
	if is_climbing and current_ladder:
		return current_ladder.rotation.y - deg_to_rad(90)
	if _is_too_far():
		var to_player = player.global_position - global_position
		to_player.y = 0
		if to_player.length() > 0.01:
			return atan2(-to_player.x, -to_player.z)
	elif _is_near_destination():
		var to_target = target_position - global_position
		to_target.y = 0
		if to_target.length() > 0.01:
			return atan2(-to_target.x, -to_target.z)
	else:
		var dir = get_move_direction()
		if dir.length() > 0.01:
			return atan2(-dir.x, -dir.z)
	return rotation.y

func _to_target_distance() -> float:
	var to_target = target_position - global_position
	to_target.y = 0
	return to_target.length()

func _is_near_destination() -> bool:
	return _has_target and _to_target_distance() < STOP_DISTANCE

func _is_too_far() -> bool:
	var to_player = player.global_position - global_position
	to_player.y = 0
	return to_player.length() > WAIT_DISTANCE
