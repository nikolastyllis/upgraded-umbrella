class_name NPCBase
extends CharacterBase

@onready var target := $"../Target"
@onready var navigation_agent_3d := $NavigationAgent3D
@onready var player := $"../Player"

const STUCK_CHECK_INTERVAL = 1.0
const STUCK_DISTANCE_THRESHOLD = 0.2
const UNSTICK_DURATION = 0.6
const MAX_UNSTICK_ATTEMPTS = 4
const STOP_DISTANCE = 1.0       # Stop moving when within this distance of target
const WAIT_DISTANCE = 8.0       # Stop and wait if target is farther than this

var _stuck_timer := 0.0
var _last_position := Vector3.ZERO
var _unstick_timer := 0.0
var _unstick_dir := Vector3.ZERO
var _unstick_phase := 0
var _unstick_attempts := 0
var _previous_unstick_dirs: Array[Vector3] = []

func _physics_process(delta: float) -> void:
	if not target:
		return
	if not _is_too_far():
		_handle_stuck_check(delta)
	navigation_agent_3d.set_target_position(target.global_position)
	super(delta)

# --- CharacterBase overrides ---

func get_move_direction() -> Vector3:
	if _is_near_destination():
		return Vector3.ZERO

	if _is_too_far():
		return Vector3.ZERO

	if _unstick_timer > 0.0:
		return _unstick_dir

	var next_pos = navigation_agent_3d.get_next_path_position()
	var dir = (next_pos - global_position)
	dir.y = 0
	if dir.length() < 0.01:
		return Vector3.ZERO
	return dir.normalized()

func get_input_dir() -> Vector2:
	var dir = get_move_direction()
	if dir.length() < 0.01:
		return Vector2.ZERO
	var local = basis.inverse() * dir
	return Vector2(local.x, local.z)

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

# --- Helpers ---

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

# --- Internal ---

func _handle_stuck_check(delta: float) -> void:
	if navigation_agent_3d.is_navigation_finished() or _is_near_destination():
		_stuck_timer = 0.0
		_last_position = global_position
		_unstick_attempts = 0
		_previous_unstick_dirs.clear()
		return

	_stuck_timer += delta

	if _unstick_phase == 2 and is_on_floor() and _unstick_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		var to_target = (target.global_position - global_position)
		to_target.y = 0
		_unstick_dir = to_target.normalized()
		_unstick_phase = 3

	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		return

	if _stuck_timer >= STUCK_CHECK_INTERVAL:
		_stuck_timer = 0.0
		if global_position.distance_to(_last_position) < STUCK_DISTANCE_THRESHOLD:
			_start_unstick()
		else:
			_unstick_attempts = 0
			_previous_unstick_dirs.clear()
		_last_position = global_position

func _start_unstick() -> void:
	_unstick_attempts += 1

	if _unstick_attempts > MAX_UNSTICK_ATTEMPTS:
		_unstick_attempts = 0
		_previous_unstick_dirs.clear()
		velocity.y = JUMP_VELOCITY
		var to_target = (target.global_position - global_position)
		to_target.y = 0
		_unstick_dir = to_target.normalized()
		_unstick_phase = 3
		_unstick_timer = UNSTICK_DURATION
		return

	var best_dir := Vector3.ZERO
	var best_score := -INF
	var candidates: Array[Vector3] = []

	for i in 8:
		var angle = (TAU / 8.0) * i
		candidates.append(Vector3(sin(angle), 0, cos(angle)))

	for candidate in candidates:
		var score = 0.0
		for prev in _previous_unstick_dirs:
			score += -candidate.dot(prev)
		var to_target = (target.global_position - global_position)
		to_target.y = 0
		if to_target.length() > 0.01:
			score += candidate.dot(to_target.normalized()) * 0.3
		if score > best_score:
			best_score = score
			best_dir = candidate

	_unstick_dir = best_dir
	_previous_unstick_dirs.append(best_dir)
	if _previous_unstick_dirs.size() > 4:
		_previous_unstick_dirs.pop_front()

	match _unstick_attempts % 3:
		0:
			_unstick_phase = 1
			_unstick_timer = UNSTICK_DURATION
		1:
			_unstick_dir = -_unstick_dir
			_unstick_phase = 2
			_unstick_timer = UNSTICK_DURATION * 0.4
		2:
			_unstick_phase = 1
			_unstick_timer = UNSTICK_DURATION * 1.5
