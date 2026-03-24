class_name Monster
extends NPC

# ─────────────────────────────────────────────
#  Speed
#  Player jog = PLAYER_SPEED * 2.0 = 3.0
#  Monster is slightly slower at 2.5
# ─────────────────────────────────────────────
const MONSTER_SPEED := 2.5

# ─────────────────────────────────────────────
#  Line-of-sight detection
# ─────────────────────────────────────────────
const DETECTION_DISTANCE  := 18.0
const DETECTION_FOV_DOT   := 0.3
const LOS_CHECK_INTERVAL  := 0.2
const LOSE_SIGHT_DURATION := 4.0

# ─────────────────────────────────────────────
#  Roar
# ─────────────────────────────────────────────
const ROAR_ANIM_NAME := "Roar"
const ROAR_DURATION  := 6.0
const ROAR_COOLDOWN  := 20.0

# ─────────────────────────────────────────────
#  Pounce — jump at the player
# ─────────────────────────────────────────────
const POUNCE_DISTANCE      := 5.0    # max horizontal range to trigger a pounce
const POUNCE_JUMP_VELOCITY := 10.0   # upward component
const POUNCE_LUNGE_SPEED   := 8.0    # forward speed applied during the pounce
const POUNCE_COOLDOWN      := 4.0    # seconds between pounces
const POUNCE_CHECK_INTERVAL := 0.3   # how often to test if a pounce should fire

# ─────────────────────────────────────────────
#  Step-jump
# ─────────────────────────────────────────────
const STEP_CHECK_DISTANCE := 0.6
const STEP_MAX_HEIGHT     := 0.55
const STEP_MIN_HEIGHT     := 0.08
const STEP_JUMP_VELOCITY  := 3.2
const STEP_CHECK_INTERVAL := 0.12

# ─────────────────────────────────────────────
#  Patrol — wander after losing the player
# ─────────────────────────────────────────────
const PATROL_WANDER_RADIUS  := 12.0  # how far from last-seen pos to pick a waypoint
const PATROL_WAYPOINT_COUNT := 3     # waypoints to visit before giving up
const PATROL_SPEED          := 1.2   # slower plod while patrolling

# ─────────────────────────────────────────────
#  Internal state
# ─────────────────────────────────────────────
var _is_chasing          := false
var _is_roaring          := false
var _roar_timer          := 0.0
var _roar_cooldown_timer := 0.0
var _los_timer           := 0.0
var _lose_sight_timer    := 0.0
var _step_timer          := 0.0

var _roar_target_player: Node3D = null

# Patrol
enum PatrolState { IDLE, PATROLLING }
var _patrol_state        := PatrolState.IDLE
var _patrol_waypoints    : Array[Vector3] = []
var _patrol_index        := 0
var _last_seen_position  := Vector3.ZERO

func _ready() -> void:
	super._ready()

# ─────────────────────────────────────────────
#  Speed override
# ─────────────────────────────────────────────
func get_speed() -> float:
	if _patrol_state == PatrolState.PATROLLING:
		return PATROL_SPEED
	return MONSTER_SPEED

# ─────────────────────────────────────────────
#  Main loops
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	_update_head_look_weight(delta)
	_update_los(delta)
	if _roar_cooldown_timer > 0.0:
		_roar_cooldown_timer -= delta

func _physics_process(delta: float) -> void:
	if _is_roaring:
		velocity.x = 0.0
		velocity.z = 0.0
		_tick_roar(delta)
		apply_gravity(delta)
		move_and_slide()
		return

	super._physics_process(delta)
	_check_step_jump(delta)
	_tick_patrol()

# ─────────────────────────────────────────────
#  Nav agent — block velocity during roar
# ─────────────────────────────────────────────
func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	if _is_roaring:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	super._on_navigation_agent_3d_velocity_computed(safe_velocity)

# ─────────────────────────────────────────────
#  Line-of-sight
# ─────────────────────────────────────────────
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

# ─────────────────────────────────────────────
#  Roar sequence
# ─────────────────────────────────────────────
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

	var dialogue_id = randi_range(80, 91)
	play_dialogue(dialogue_id, 50)

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

# ─────────────────────────────────────────────
#  Patrol — wander after losing the player
# ─────────────────────────────────────────────
func _begin_patrol() -> void:
	_patrol_waypoints.clear()
	_patrol_index = 0

	# Generate a short list of random waypoints around the last known position
	for i in range(PATROL_WAYPOINT_COUNT):
		var angle  = randf() * TAU
		var radius = randf_range(PATROL_WANDER_RADIUS * 0.4, PATROL_WANDER_RADIUS)
		var offset = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_patrol_waypoints.append(_last_seen_position + offset)

	_patrol_state = PatrolState.PATROLLING
	_advance_patrol_waypoint()

func _tick_patrol() -> void:
	if _patrol_state != PatrolState.PATROLLING or _is_chasing:
		return

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

# ─────────────────────────────────────────────
#  Step-jump
# ─────────────────────────────────────────────
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

# ─────────────────────────────────────────────
#  Movement — always full speed, no walk state
# ─────────────────────────────────────────────
func apply_movement() -> void:
	if is_climbing:
		apply_climbing_movement()
		return
	var move_direction = get_move_direction()
	var desired_velocity := Vector3.ZERO
	if move_direction.length() > 0.01:
		desired_velocity = move_direction * get_speed()
	navigation_agent_3d.set_velocity(desired_velocity)

# ─────────────────────────────────────────────
#  Animation — Jog when moving, Idle when still
# ─────────────────────────────────────────────
func update_movement_animation(input_dir: Vector2) -> void:
	var state_machine = animation_tree["parameters/AnimationNodeStateMachine/playback"]
	if input_dir.length() > 0.01:
		state_machine.travel("Jog")
	else:
		state_machine.travel("Idle")

# ─────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────

# Trigger a roar immediately, bypassing the cooldown.
# Optionally pass a Node3D for the monster to face while roaring.
# If omitted, defaults to the player. Pass null to roar in place.
func roar(look_at_target: Node3D = get_player()) -> void:
	_begin_roar(look_at_target)
