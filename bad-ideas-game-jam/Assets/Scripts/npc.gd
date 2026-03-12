extends "base_character.gd"

@onready var target := $"../Target"
@onready var navigation_agent_3d := $NavigationAgent3D
@onready var player := $"../Player"

const NPC_SPEED = 1.5
const STOP_DISTANCE = 1.0
const WAIT_DISTANCE = 10.0

func _ready() -> void:
	super._ready()

func _physics_process(delta: float) -> void:
	if not target:
		return
	navigation_agent_3d.set_target_position(target.global_position)
	apply_gravity(delta)
	apply_movement()
	update_movement_animation(get_input_dir(), delta)
	update_character_rotation(get_target_rotation_y(), delta)
	move_and_slide()
	update_climb_position()
	dismount_ladder()
	if climb_cooldown > 0:
		climb_cooldown -= delta

func get_speed() -> float:
	return NPC_SPEED

var climb_target_y := 0.0

func start_climbing(ladder: Node3D) -> void:
	super.start_climbing(ladder)
	# Commit to the opposite end from where we entered
	var mid_y = (ladder.start_y() + ladder.end_y()) / 2.0
	climb_target_y = ladder.end_y() + 2 if global_position.y < mid_y else ladder.start_y() - 2

func get_climb_input() -> float:
	if not is_climbing or not current_ladder:
		return 0.0
	var diff = climb_target_y - global_position.y
	if abs(diff) < 0.1:
		return 0.0
	return sign(diff)

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
	if move_direction.length() > 0.01:
		velocity.x = move_direction.x * NPC_SPEED
		velocity.z = move_direction.z * NPC_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, NPC_SPEED)
		velocity.z = move_toward(velocity.z, 0, NPC_SPEED)

		
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
		var to_target = target.global_position - global_position
		to_target.y = 0
		if to_target.length() > 0.01:
			return atan2(-to_target.x, -to_target.z)
	else:
		var dir = get_move_direction()
		if dir.length() > 0.01:
			return atan2(-dir.x, -dir.z)
	return rotation.y

func _to_target_distance() -> float:
	var to_target = target.global_position - global_position
	to_target.y = 0
	return to_target.length()

func _is_near_destination() -> bool:
	return _to_target_distance() < STOP_DISTANCE

func _is_too_far() -> bool:
	var to_player = player.global_position - global_position
	to_player.y = 0
	return to_player.length() > WAIT_DISTANCE
