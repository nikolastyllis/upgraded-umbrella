class_name NPC
extends BaseCharacter

@onready var navigation_agent_3d := $NavigationAgent3D

const NPC_SPEED = 1.5
const STOP_DISTANCE = 1.5
const STUCK_TIME_THRESHOLD = 2.5
const STUCK_DISTANCE_THRESHOLD = 0.3
const STUCK_SAMPLE_INTERVAL = 0.5
const UNSTICK_DETOUR_DISTANCE = 8.0
const UNSTICK_DETOUR_DURATION = 6.0

const UNSTICK_ANGLE_COUNT = 8
const UNSTICK_MIN_ANGLE_DIFF = 60.0

var _last_unstick_angle := 0.0
var _unstick_attempt_count := 0

var target_position := Vector3.ZERO 
var _has_target := false

var climb_target_y := 0.0
var stuck_timer := 0.0
var stuck_sample_timer := 0.0
var last_sampled_position := Vector3.ZERO
var unstick_timer := 0.0
var unstick_target := Vector3.ZERO

@onready var skeleton := $Character/Armature/Skeleton3D
@onready var _player := $"../Player"

const HEAD_LOOK_DISTANCE = 10.0
const HEAD_LOOK_FOV = 0.3
const HEAD_LOOK_SPEED = 5.0
const HEAD_MAX_YAW = 60.0

var _head_bone_idx := -1
var _head_look_weight := 0.0

func _ready() -> void:
	super._ready()
	last_sampled_position = global_position
	_head_bone_idx = skeleton.find_bone("mixamorig_Head")
	print("Head bone index: ", _head_bone_idx)
	skeleton.skeleton_updated.connect(_on_skeleton_updated)
	add_to_group("npcs")

func set_target_position(pos: Vector3) -> void:
	if get_tree() == null:
		return
	await get_tree().create_timer(randf() * 3).timeout
	target_position = pos
	_has_target = true

func _process(delta: float) -> void:
	_update_head_look_weight(delta)
	_has_target = target_position != Vector3.ZERO
	
func get_player():
	return _player	

func _on_skeleton_updated() -> void:
	_apply_head_look()

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
	update_movement_animation(get_input_dir())
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
	if is_climbing or _is_near_destination() or unstick_timer > 0:
		stuck_timer = 0.0
		stuck_sample_timer = 0.0
		last_sampled_position = global_position
		if _is_near_destination():
			_unstick_attempt_count = 0
		return
	stuck_sample_timer += delta
	if stuck_sample_timer >= STUCK_SAMPLE_INTERVAL:
		var moved = global_position.distance_to(last_sampled_position)
		var should_be_moving = not _is_near_destination()
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
	_unstick_attempt_count += 1

	var ref_dir = (target_position - global_position)
	ref_dir.y = 0
	if ref_dir.length() < 0.01:
		ref_dir = -global_transform.basis.z
	ref_dir = ref_dir.normalized()

	var candidates: Array[float] = []
	for i in range(UNSTICK_ANGLE_COUNT):
		var angle = (float(i) / UNSTICK_ANGLE_COUNT) * TAU  # 0..2π
		candidates.append(angle)
	candidates.shuffle()

	var chosen_angle := candidates[0]
	for angle in candidates:
		var diff = abs(angle_difference(angle, _last_unstick_angle))
		if rad_to_deg(diff) >= UNSTICK_MIN_ANGLE_DIFF:
			chosen_angle = angle
			break

	_last_unstick_angle = chosen_angle

	var detour_dir = Vector3(sin(chosen_angle), 0.0, cos(chosen_angle))
	unstick_target = global_position + detour_dir * UNSTICK_DETOUR_DISTANCE
	unstick_timer = UNSTICK_DETOUR_DURATION

	var boosted_distance = UNSTICK_DETOUR_DISTANCE * (1.0 + 0.5 * min(_unstick_attempt_count - 1, 4))
	unstick_target = global_position + detour_dir * boosted_distance

func get_move_direction() -> Vector3:
	if _is_near_destination():
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
		pass

func dismount_ladder() -> void:
	if is_climbing and is_on_floor() and get_climb_input() < 0 and current_ladder.end_y() > global_position.y:
		stop_climbing()

func get_target_rotation_y() -> float:
	if is_climbing and current_ladder:
		return current_ladder.rotation.y - deg_to_rad(90)
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
	
func _update_head_look_weight(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var to_player = _player.global_position - global_position
	var dist = to_player.length()
	var forward = -global_transform.basis.z
	var to_player_flat = Vector3(to_player.x, 0.0, to_player.z).normalized()
	var dot = forward.dot(to_player_flat)
	var target_weight = 1.0 if (dist <= HEAD_LOOK_DISTANCE and dot >= HEAD_LOOK_FOV) else 0.0
	_head_look_weight = move_toward(_head_look_weight, target_weight, HEAD_LOOK_SPEED * delta)

func _apply_head_look() -> void:
	if _head_bone_idx == -1:
		return

	if _head_look_weight < 0.01:
		skeleton.set_bone_global_pose_override(_head_bone_idx, Transform3D(), 0.0, false)
		return

	var to_player = _player.global_position - global_position
	var forward = -global_transform.basis.z
	var to_player_flat = Vector3(to_player.x, 0.0, to_player.z).normalized()
	var yaw_angle = forward.signed_angle_to(to_player_flat, Vector3.UP)
	yaw_angle = clampf(yaw_angle, deg_to_rad(-HEAD_MAX_YAW), deg_to_rad(HEAD_MAX_YAW)) * _head_look_weight

	var bone_pose = skeleton.get_bone_global_pose_no_override(_head_bone_idx)
	var world_pose = skeleton.global_transform * bone_pose
	world_pose.basis = Basis(Vector3.UP, yaw_angle) * world_pose.basis
	var new_pose = skeleton.global_transform.affine_inverse() * world_pose
	skeleton.set_bone_global_pose_override(_head_bone_idx, new_pose, 1.0, true)
