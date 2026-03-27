class_name Monster
extends NPC

const MONSTER_SPEED := 3.0

const DETECTION_DISTANCE  := 18.0
const DETECTION_FOV_DOT   := 0.3
const LOS_CHECK_INTERVAL  := 0.2
const LOSE_SIGHT_DURATION := 4.0

const ROAR_ANIM_NAME := "Roar"
const ROAR_DURATION  := 6.0
const ROAR_COOLDOWN  := 20.0

const POUNCE_DISTANCE      := 5.0
const POUNCE_JUMP_VELOCITY := 10.0
const POUNCE_LUNGE_SPEED   := 8.0
const POUNCE_COOLDOWN      := 4.0
const POUNCE_CHECK_INTERVAL := 0.3

const STEP_CHECK_DISTANCE := 0.6
const STEP_MAX_HEIGHT     := 0.55
const STEP_MIN_HEIGHT     := 0.08
const STEP_JUMP_VELOCITY  := 3.2
const STEP_CHECK_INTERVAL := 0.12

const PATROL_WANDER_RADIUS  := 8.0
const PATROL_WAYPOINT_COUNT := 4
const PATROL_SPEED          := 2.0
const PATROL_PLAYER_BIAS    := 0.65

const KILL_DISTANCE       := 1.25
const KILL_ANIM_NAME      := "Attack"
const KILL_CHECK_INTERVAL := 0.2

const STUCK_CHECK_INTERVAL := 3.0
const STUCK_MOVE_THRESHOLD := 2.0
const STUCK_TIME_LIMIT     := 20.0
const TELEPORT_RADIUS_MIN  := 6.0
const TELEPORT_RADIUS_MAX  := 14.0
const TELEPORT_ATTEMPTS    := 20

var _is_chasing          := false
var _is_roaring          := false
var _is_killing          := false
var _is_killing_locked   := false
var _roar_timer          := 0.0
var _roar_cooldown_timer := 0.0
var _los_timer           := 0.0
var _lose_sight_timer    := 0.0
var _step_timer          := 0.0
var _kill_check_timer    := 0.0
var _stuck_timer         := 0.0
var _stuck_check_timer   := 0.0
var _last_sampled_position := Vector3.ZERO

var _roar_target_player: Node3D = null

enum PatrolState { IDLE, PATROLLING }
var _patrol_state       := PatrolState.IDLE
var _patrol_waypoints   : Array[Vector3] = []
var _patrol_index       := 0
var _last_seen_position := Vector3.ZERO

func _ready() -> void:
	super._ready()

func get_speed() -> float:
	if _patrol_state == PatrolState.PATROLLING:
		return PATROL_SPEED
	return MONSTER_SPEED

func _process(delta: float) -> void:
	_update_head_look_weight(delta)
	_update_los(delta)
	if _roar_cooldown_timer > 0.0:
		_roar_cooldown_timer -= delta
	_update_kill_check(delta)
	_update_stuck_check(delta)

func _physics_process(delta: float) -> void:
	if _is_roaring:
		velocity.x = 0.0
		velocity.z = 0.0
		_tick_roar(delta)
		apply_gravity(delta)
		move_and_slide()
		return

	if _is_killing_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		apply_gravity(delta)
		move_and_slide()
		return

	super._physics_process(delta)
	_check_step_jump(delta)
	_tick_patrol()

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	if _is_roaring or _is_killing_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	super._on_navigation_agent_3d_velocity_computed(safe_velocity)

func _update_los(delta: float) -> void:
	if _is_roaring:
		return

	_los_timer -= delta
	if _los_timer > 0.0:
		return
	_los_timer = LOS_CHECK_INTERVAL

	var player = get_player()
	if not is_instance_valid(player):
		_stop_chase()
		return

	if _can_see_player(player):
		_last_seen_position = player.global_position
		_lose_sight_timer   = LOSE_SIGHT_DURATION
		_stop_patrol()
		_start_chase(player)
	else:
		if _is_chasing:
			_lose_sight_timer -= LOS_CHECK_INTERVAL
			if _lose_sight_timer <= 0.0:
				_stop_chase()
				_begin_patrol()

func _can_see_player(player: Node3D) -> bool:
	var to_player = player.global_position - global_position
	var dist      = to_player.length()

	if dist > DETECTION_DISTANCE:
		return false

	if dist > KILL_DISTANCE * 2.0:
		var forward        = -global_transform.basis.z
		var to_player_flat = Vector3(to_player.x, 0.0, to_player.z).normalized()
		if forward.dot(to_player_flat) < DETECTION_FOV_DOT:
			return false

	var space  = get_world_3d().direct_space_state
	var origin = global_position + Vector3.UP * 1.6
	var target = player.global_position + Vector3.UP * 1.0

	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude        = [self]
	query.collision_mask = 1

	var result = space.intersect_ray(query)
	return result.is_empty() or result.collider == player

func _start_chase(player: Node3D) -> void:
	if _roar_cooldown_timer <= 0.0:
		_begin_roar(player)
	else:
		_is_chasing     = true
		target_position = player.global_position
		_has_target     = true

func _stop_chase() -> void:
	_is_chasing     = false
	target_position = Vector3.ZERO
	_has_target     = false

func _begin_roar(look_target: Node3D = null) -> void:
	_is_roaring          = true
	_roar_timer          = ROAR_DURATION
	_roar_cooldown_timer = ROAR_COOLDOWN
	_roar_target_player  = look_target

	velocity.x  = 0.0
	velocity.z  = 0.0
	_has_target = false

	if is_instance_valid(look_target):
		var to_target = look_target.global_position - global_position
		to_target.y   = 0.0
		if to_target.length() > 0.01:
			rotation.y = atan2(-to_target.x, -to_target.z)

	var state_machine = animation_tree["parameters/AnimationNodeStateMachine/playback"]
	state_machine.travel(ROAR_ANIM_NAME)

	var dialogue_id = randi_range(80, 84)
	play_dialogue(dialogue_id, 30, 0.5)

func _tick_roar(delta: float) -> void:
	_roar_timer -= delta

	if is_instance_valid(_roar_target_player):
		var to_target = _roar_target_player.global_position - global_position
		to_target.y   = 0.0
		if to_target.length() > 0.01:
			var target_angle = atan2(-to_target.x, -to_target.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 0.1)

	if _roar_timer <= 0.0:
		_end_roar()

func _end_roar() -> void:
	_is_roaring = false

	if is_instance_valid(_roar_target_player):
		_is_chasing     = true
		target_position = _roar_target_player.global_position
		_has_target     = true

	_roar_target_player = null

func _update_kill_check(delta: float) -> void:
	if _is_killing or _is_roaring:
		return

	var player = get_player()
	if not is_instance_valid(player):
		return

	var dist = global_position.distance_to(player.global_position)

	if not _is_chasing and dist > KILL_DISTANCE:
		return

	_kill_check_timer -= delta
	if _kill_check_timer > 0.0:
		return
	_kill_check_timer = KILL_CHECK_INTERVAL

	if dist <= KILL_DISTANCE:
		_begin_kill(player)

func _begin_kill(player: Node3D) -> void:
	_is_killing = true

	_is_chasing     = true
	_has_target     = true
	target_position = player.global_position

	var to_player = player.global_position - global_position
	to_player.y   = 0.0
	if to_player.length() > 0.01:
		rotation.y = atan2(-to_player.x, -to_player.z)

	var state_machine = animation_tree["parameters/AnimationNodeStateMachine/playback"]
	state_machine.start(KILL_ANIM_NAME, true)

	await get_tree().create_timer(0.3).timeout
	
	var current_player = get_player()
	if is_instance_valid(current_player) and global_position.distance_to(current_player.global_position) <= KILL_DISTANCE:
		current_player.die()
		roar()

	_is_killing_locked = true
	_is_chasing        = false
	_has_target        = false
	_is_killing        = false
	_is_killing_locked = false

func _begin_patrol() -> void:
	_patrol_waypoints.clear()
	_patrol_index = 0

	var player = get_player()

	for i in range(PATROL_WAYPOINT_COUNT):
		var angle  := randf() * TAU
		var radius := randf_range(PATROL_WANDER_RADIUS * 0.4, PATROL_WANDER_RADIUS)
		var random_offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

		var wander_point := _last_seen_position + random_offset
		var bias_target  = player.global_position if is_instance_valid(player) else _last_seen_position
		var waypoint     := wander_point.lerp(bias_target, PATROL_PLAYER_BIAS * randf())

		_patrol_waypoints.append(waypoint)

	_patrol_state = PatrolState.PATROLLING
	_advance_patrol_waypoint()

func _tick_patrol() -> void:
	if _patrol_state != PatrolState.PATROLLING or _is_chasing:
		return

	var player = get_player()
	if is_instance_valid(player) and _patrol_index < _patrol_waypoints.size():
		_patrol_waypoints[_patrol_index] = _patrol_waypoints[_patrol_index].lerp(
			player.global_position, PATROL_PLAYER_BIAS * 0.02
		)
		target_position = _patrol_waypoints[_patrol_index]

	var to_wp = target_position - global_position
	to_wp.y   = 0.0
	if to_wp.length() < STOP_DISTANCE + 0.5:
		_patrol_index += 1
		if _patrol_index >= _patrol_waypoints.size():
			_stop_patrol()
		else:
			_advance_patrol_waypoint()

func _advance_patrol_waypoint() -> void:
	if _patrol_index < _patrol_waypoints.size():
		target_position = _patrol_waypoints[_patrol_index]
		_has_target     = true

func _stop_patrol() -> void:
	_patrol_state = PatrolState.IDLE
	_patrol_waypoints.clear()
	target_position = Vector3.ZERO
	_has_target     = false

func _update_stuck_check(delta: float) -> void:
	if not _is_chasing or _is_roaring or _is_killing:
		_stuck_timer           = 0.0
		_stuck_check_timer     = 0.0
		_last_sampled_position = global_position
		return

	_stuck_check_timer -= delta
	if _stuck_check_timer > 0.0:
		return
	_stuck_check_timer = STUCK_CHECK_INTERVAL

	var moved = global_position.distance_to(_last_sampled_position)
	_last_sampled_position = global_position

	if moved < STUCK_MOVE_THRESHOLD:
		_stuck_timer += STUCK_CHECK_INTERVAL
		if _stuck_timer >= STUCK_TIME_LIMIT:
			_stuck_timer = 0.0
			_teleport_out_of_sight()
	else:
		_stuck_timer = 0.0

func _teleport_out_of_sight() -> void:
	var player = get_player()
	if not is_instance_valid(player):
		return

	var player_cam_forward = -player.camera_origin.global_transform.basis.z
	player_cam_forward.y = 0.0
	player_cam_forward   = player_cam_forward.normalized()

	var space := get_world_3d().direct_space_state

	for i in TELEPORT_ATTEMPTS:
		var angle      := randf_range(deg_to_rad(120), deg_to_rad(240))
		var base_angle := atan2(player_cam_forward.x, player_cam_forward.z)
		angle += base_angle

		var radius    := randf_range(TELEPORT_RADIUS_MIN, TELEPORT_RADIUS_MAX)
		var offset    := Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
		var candidate = player.global_position + offset

		var to_candidate = (candidate - player.global_position).normalized()
		to_candidate.y = 0.0
		if player_cam_forward.dot(to_candidate) > 0.3:
			continue

		var ray_from = candidate + Vector3.UP * 5.0
		var ray_to   = candidate + Vector3.DOWN * 5.0
		var query    := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.exclude        = [self]
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue

		var los_query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP * 1.6,
			hit.position + Vector3.UP * 1.6
		)
		los_query.exclude        = [self]
		los_query.collision_mask = 1
		var los_hit := space.intersect_ray(los_query)
		if not los_hit.is_empty():
			global_position = hit.position
			return

	_stuck_timer = STUCK_TIME_LIMIT * 0.5

func _check_step_jump(delta: float) -> void:
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	_step_timer = STEP_CHECK_INTERVAL

	if not is_on_floor() or is_climbing:
		return
	var move_dir = get_move_direction()
	if move_dir.length() < 0.01:
		return

	var space  = get_world_3d().direct_space_state
	var origin = global_position + Vector3.UP * 0.05
	var probe  = origin + move_dir * STEP_CHECK_DISTANCE

	var low_query = PhysicsRayQueryParameters3D.create(origin, probe)
	low_query.exclude        = [self]
	low_query.collision_mask = 1
	if space.intersect_ray(low_query).is_empty():
		return

	var above_step = global_position + move_dir * STEP_CHECK_DISTANCE + Vector3.UP * (STEP_MAX_HEIGHT + 0.1)
	var below_step = above_step + Vector3.DOWN * (STEP_MAX_HEIGHT + 0.2)
	var down_query = PhysicsRayQueryParameters3D.create(above_step, below_step)
	down_query.exclude        = [self]
	down_query.collision_mask = 1
	var down_hit = space.intersect_ray(down_query)

	if down_hit.is_empty():
		return

	var step_height = down_hit.position.y - global_position.y
	if step_height < STEP_MIN_HEIGHT or step_height > STEP_MAX_HEIGHT:
		return

	var jump_v = sqrt(2.0 * step_height) * (STEP_JUMP_VELOCITY / sqrt(2.0 * STEP_MAX_HEIGHT))
	velocity.y = clampf(jump_v, 1.5, STEP_JUMP_VELOCITY)

func apply_movement() -> void:
	if is_climbing:
		apply_climbing_movement()
		return
	var move_direction = get_move_direction()
	var desired_velocity := Vector3.ZERO
	if move_direction.length() > 0.01:
		desired_velocity = move_direction * get_speed()
	navigation_agent_3d.set_velocity(desired_velocity)

func update_movement_animation(input_dir: Vector2) -> void:
	if _is_killing:
		return
	var state_machine = animation_tree["parameters/AnimationNodeStateMachine/playback"]

	if current_ladder and current_ladder.end_y() < global_position.y and get_climb_input() > 0 and finish_climb_animation_cooldown_timer > finish_climb_animation_cooldown:
		finish_climb_animation_cooldown_timer = 0
		state_machine.travel("Finish Climbing")
		is_finishing_climb = true

	if is_finishing_climb:
		return

	if is_climbing:
		state_machine.travel("Climb")
		animation_tree.set("parameters/AnimationNodeStateMachine/Climb/Climb Direction/scale", sign(get_climb_input()))
	elif not is_on_floor():
		state_machine.travel("Fall")
	elif input_dir.length() > 0.01:
		state_machine.travel("Jog")
	else:
		state_machine.travel("Idle")

func roar(look_at_target: Node3D = get_player()) -> void:
	_begin_roar(look_at_target)
