class_name Monster
extends NPC

var monster_speed := 2.5

const DETECTION_DISTANCE  := 18.0
const DETECTION_FOV_DOT   := 0.1 
const LOS_CHECK_INTERVAL  := 0.1
const LOSE_SIGHT_DURATION := 10.0 

const ROAR_DURATION  := 6.0
const ROAR_COOLDOWN  := 20.0

const KILL_DISTANCE       := 1.5
const KILL_CHECK_INTERVAL := 0.5

const PATROL_SPEED          := 1.5
const PATROL_WANDER_RADIUS  := 15
const PATROL_WAYPOINT_COUNT := 2
const PATROL_PLAYER_BIAS    := 0.75

const TELEPORT_SAMPLE_INTERVAL := 30.0
const TELEPORT_MOVE_THRESHOLD  := 20.0
const TELEPORT_PLAYER_FOV_DOT  := 0.3

@export var debug_enabled := false

var _is_chasing        := false
var _is_roaring        := false
var _is_killing        := false
var _is_killing_locked := false

var _los_timer           := 0.0
var _lose_sight_timer    := 0.0
var _roar_timer          := 0.0
var _roar_cooldown_timer := 0.0
var _kill_check_timer    := 0.0

var _roar_target_player : Node3D = null
var _last_seen_position := Vector3.ZERO

enum PatrolState { IDLE, PATROLLING }
var _patrol_state     := PatrolState.IDLE
var _patrol_waypoints : Array[Vector3] = []
var _patrol_index     := 0

var _teleport_sample_timer    := TELEPORT_SAMPLE_INTERVAL
var _teleport_sample_position := Vector3.ZERO

var _dbg_root : Node3D = null

func reset_state() -> void:
	_log("reset_state — FULL RESET")
	_is_chasing        = false
	_is_roaring        = false
	_is_killing        = false
	_is_killing_locked = false
	_los_timer           = 0.0
	_lose_sight_timer    = 0.0
	_roar_timer          = 0.0
	_roar_cooldown_timer = 0.0
	_kill_check_timer    = 0.0
	_roar_target_player = null
	_last_seen_position = Vector3.ZERO
	target_position = Vector3.ZERO
	_has_target     = false
	_patrol_state     = PatrolState.IDLE
	_patrol_waypoints.clear()
	_patrol_index     = 0
	_teleport_sample_timer    = TELEPORT_SAMPLE_INTERVAL
	_teleport_sample_position = Vector3.ZERO
	velocity = Vector3.ZERO
	navigation_agent_3d.set_velocity(Vector3.ZERO)
	if navigation_agent_3d:
		navigation_agent_3d.target_position = global_position
	var sm = animation_tree["parameters/AnimationNodeStateMachine/playback"]
	sm.travel("Idle")
	animation_tree.set("parameters/KillOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	animation_tree.set("parameters/RoarOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_clear_debug()
	_log("reset_state — DONE %s" % _state())

func _setup_debug() -> void:
	if not debug_enabled:
		return
	_dbg_root = Node3D.new()
	_dbg_root.name = "MonsterDebug_%s" % name
	get_tree().root.call_deferred("add_child", _dbg_root)

func _clear_debug() -> void:
	if not debug_enabled or not is_instance_valid(_dbg_root):
		return
	for child in _dbg_root.get_children():
		child.queue_free()

func _dbg_ray(from: Vector3, to: Vector3, color: Color, hit: Variant = null) -> void:
	if not debug_enabled or not is_instance_valid(_dbg_root):
		return
	var mat := _dbg_mat(color)
	var mesh := ImmediateMesh.new()

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	var s := 0.10
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(from + Vector3(-s, 0,  0))
	mesh.surface_add_vertex(from + Vector3( s, 0,  0))
	mesh.surface_add_vertex(from + Vector3(0,  0, -s))
	mesh.surface_add_vertex(from + Vector3(0,  0,  s))
	mesh.surface_end()

	if hit != null:
		var hp : Vector3 = hit
		var hm := _dbg_mat(Color.YELLOW)
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, hm)
		mesh.surface_add_vertex(hp + Vector3(-s, 0,  0))
		mesh.surface_add_vertex(hp + Vector3( s, 0,  0))
		mesh.surface_add_vertex(hp + Vector3(0, -s,  0))
		mesh.surface_add_vertex(hp + Vector3(0,  s,  0))
		mesh.surface_add_vertex(hp + Vector3(0,  0, -s))
		mesh.surface_add_vertex(hp + Vector3(0,  0,  s))
		mesh.surface_end()

	_dbg_add_mesh(mesh)

func _dbg_circle(center: Vector3, radius: float, color: Color, steps := 24) -> void:
	if not debug_enabled or not is_instance_valid(_dbg_root):
		return
	var mesh := ImmediateMesh.new()
	var mat  := _dbg_mat(color)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in range(steps):
		var a0 := TAU * i / steps
		var a1 := TAU * (i + 1) / steps
		mesh.surface_add_vertex(center + Vector3(cos(a0) * radius, 0, sin(a0) * radius))
		mesh.surface_add_vertex(center + Vector3(cos(a1) * radius, 0, sin(a1) * radius))
	mesh.surface_end()
	_dbg_add_mesh(mesh)

func _dbg_arc_cone(origin: Vector3, forward: Vector3, half_angle: float,
		range_dist: float, color: Color, steps := 32) -> void:
	if not debug_enabled or not is_instance_valid(_dbg_root):
		return
	var mesh := ImmediateMesh.new()
	var mat  := _dbg_mat(color)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	# arc
	for i in range(steps):
		var a0 := -half_angle + (2.0 * half_angle * i       / steps)
		var a1 := -half_angle + (2.0 * half_angle * (i + 1) / steps)
		var d0 := Basis(Vector3.UP, a0) * forward
		var d1 := Basis(Vector3.UP, a1) * forward
		mesh.surface_add_vertex(origin + d0 * range_dist)
		mesh.surface_add_vertex(origin + d1 * range_dist)
	var left  := Basis(Vector3.UP, -half_angle) * forward
	var right := Basis(Vector3.UP,  half_angle) * forward
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(origin + left  * range_dist)
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(origin + right * range_dist)
	mesh.surface_end()
	_dbg_add_mesh(mesh)

func _dbg_point(pos: Vector3, color: Color) -> void:
	if not debug_enabled or not is_instance_valid(_dbg_root):
		return
	var mesh := ImmediateMesh.new()
	var mat  := _dbg_mat(color)
	var s    := 0.25
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(pos + Vector3(-s, 0,  0)); mesh.surface_add_vertex(pos + Vector3( s, 0,  0))
	mesh.surface_add_vertex(pos + Vector3(0, -s,  0)); mesh.surface_add_vertex(pos + Vector3(0,  s,  0))
	mesh.surface_add_vertex(pos + Vector3(0,  0, -s)); mesh.surface_add_vertex(pos + Vector3(0,  0,  s))
	mesh.surface_end()
	_dbg_add_mesh(mesh)

func _dbg_line(from: Vector3, to: Vector3, color: Color) -> void:
	if not debug_enabled or not is_instance_valid(_dbg_root):
		return
	var mesh := ImmediateMesh.new()
	var mat  := _dbg_mat(color)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	_dbg_add_mesh(mesh)

func _dbg_mat(color: Color) -> StandardMaterial3D:
	var mat                  := StandardMaterial3D.new()
	mat.shading_mode          = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color          = color
	mat.flags_no_depth_test   = true
	return mat

func _dbg_add_mesh(mesh: ImmediateMesh) -> void:
	var mi              := MeshInstance3D.new()
	mi.mesh              = mesh
	mi.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dbg_root.add_child(mi)

func _draw_debug_scene() -> void:
	var my_origin := global_position + Vector3.UP * 1.0
	var forward   := -global_transform.basis.z

	var fov_half := acos(DETECTION_FOV_DOT)
	_dbg_arc_cone(my_origin, forward, fov_half, DETECTION_DISTANCE,
			Color(1.0, 0.9, 0.0, 1.0))

	var player = get_player()
	var in_kill_range := is_instance_valid(player) and \
		global_position.distance_to(player.global_position) <= KILL_DISTANCE
	_dbg_circle(global_position, KILL_DISTANCE,
			Color.RED if in_kill_range else Color(0.6, 0.0, 0.0))

	if _last_seen_position != Vector3.ZERO:
		_dbg_point(_last_seen_position, Color.ORANGE)
		_dbg_line(my_origin, _last_seen_position + Vector3.UP, Color(1.0, 0.5, 0.0))

	if _has_target and target_position != Vector3.ZERO:
		_dbg_point(target_position, Color.WHITE)
		_dbg_line(my_origin, target_position + Vector3.UP * 0.5, Color(0.8, 0.8, 0.8))

	if _patrol_state == PatrolState.PATROLLING:
		for i in range(_patrol_waypoints.size()):
			var wp    := _patrol_waypoints[i]
			var color := Color.CYAN if i == _patrol_index else Color(0.0, 0.5, 1.0)
			_dbg_point(wp + Vector3.UP * 0.05, color)
			if i < _patrol_waypoints.size() - 1:
				_dbg_line(wp + Vector3.UP * 0.1,
						_patrol_waypoints[i + 1] + Vector3.UP * 0.1,
						Color(0.0, 0.5, 0.8))

	if _is_roaring and is_instance_valid(_roar_target_player):
		_dbg_line(my_origin,
				_roar_target_player.global_position + Vector3.UP * 1.0,
				Color(1.0, 0.3, 0.0))
		_dbg_circle(global_position, 1.8, Color(1.0, 0.3, 0.0))

	if _is_chasing and _lose_sight_timer < LOSE_SIGHT_DURATION:
		var t      := _lose_sight_timer / LOSE_SIGHT_DURATION
		var bar_h  := 2.0 * t
		_dbg_line(global_position + Vector3.UP * 2.2,
				global_position + Vector3.UP * (2.2 + bar_h),
				Color(0.0, 1.0, 0.3))

func _log(msg: String) -> void:
	if not debug_enabled:
		return
	print("[Monster][%.2f] %s" % [Time.get_ticks_msec() / 1000.0, msg])

func _state() -> String:
	return "(chasing=%s roaring=%s killing=%s locked=%s patrol=%s)" % [
		_is_chasing, _is_roaring, _is_killing, _is_killing_locked,
		PatrolState.keys()[_patrol_state]
	]

func _ready() -> void:
	_log("_ready — spawned at %s" % global_position)
	super._ready()
	_setup_debug()

func get_speed() -> float:
	return PATROL_SPEED if _patrol_state == PatrolState.PATROLLING else monster_speed

func _process(delta: float) -> void:
	_update_head_look_weight(delta)
	if debug_enabled:
		_clear_debug()
		_draw_debug_scene()
	if _roar_cooldown_timer > 0.0:
		_roar_cooldown_timer -= delta
	_update_los(delta)
	_update_kill_check(delta)

func _physics_process(delta: float) -> void:
	if _is_roaring:
		_tick_roar(delta)
		_face_player(delta)
		_tick_patrol()
		apply_gravity(delta)
		move_and_slide()
		return

	elif _is_killing_locked:
		_face_player(delta)
		apply_gravity(delta)
		move_and_slide()
		return
	else:
		super._physics_process(delta)
		_tick_patrol()

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
		
	var player = get_player()
	if player.is_dead:
		velocity = Vector3(0, velocity.y, 0)

	super._on_navigation_agent_3d_velocity_computed(safe_velocity)

func _face_player(delta: float) -> void:
	var player = get_player()
	if not is_instance_valid(player):
		return

	var to_player = player.global_position - global_position
	to_player.y = 0.0

	if to_player.length() < 0.001:
		return

	var target_rot := atan2(-to_player.x, -to_player.z)
	rotation.y = lerp_angle(rotation.y, target_rot, delta * 10.0)

func _update_los(delta: float) -> void:
	_los_timer -= delta
	if _los_timer > 0.0:
		return
	_los_timer = LOS_CHECK_INTERVAL

	var player = get_player()
	if not is_instance_valid(player):
		_log("_update_los — player invalid → stopping chase")
		_stop_chase()
		return

	var dist := global_position.distance_to(player.global_position)

	if _can_see_player(player):
		_last_seen_position = player.global_position
		_lose_sight_timer   = LOSE_SIGHT_DURATION
		_stop_patrol()

		if not _is_chasing:
			_log("_update_los — SPOTTED  dist=%.2f  %s" % [dist, _state()])
			_start_chase(player)
		else:
			target_position = player.global_position
			_has_target = true
			_log("_update_los — tracking  dist=%.2f" % dist)
	else:
		if _is_chasing:
			_lose_sight_timer -= LOS_CHECK_INTERVAL
			_log("_update_los — LOST SIGHT  dist=%.2f  countdown=%.2f" % [dist, _lose_sight_timer])
			if _lose_sight_timer <= 0.0:
				_log("_update_los — sight expired → stop chase → patrol")
				_stop_chase()
				_begin_patrol()
		else:
			_log("_update_los — no sight, idle  dist=%.2f" % dist)

func _can_see_player(player: Node3D) -> bool:
	var to_player := player.global_position - global_position
	var dist      := to_player.length()

	if dist > DETECTION_DISTANCE:
		_log("_can_see_player — FAIL range  %.2f > %.2f" % [dist, DETECTION_DISTANCE])
		return false

	if dist > KILL_DISTANCE * 2.0:
		var forward        := -global_transform.basis.z
		var to_player_flat := Vector3(to_player.x, 0.0, to_player.z).normalized()
		var dot            := forward.dot(to_player_flat)
		if dot < DETECTION_FOV_DOT:
			_log("_can_see_player — FAIL fov  dot=%.3f < %.3f" % [dot, DETECTION_FOV_DOT])
			return false

	var space  := get_world_3d().direct_space_state
	var origin := global_position
	var target := player.global_position
	var query  := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude        = [self]
	query.collision_mask = 1
	var result := space.intersect_ray(query)

	if result.is_empty():
		_dbg_ray(origin, target, Color.GREEN)
		_log("_can_see_player — PASS clear  dist=%.2f" % dist)
		return true
	elif result.collider == player:
		_dbg_ray(origin, target, Color.CYAN, result.position)
		_log("_can_see_player — PASS hit player  dist=%.2f" % dist)
		return true
	else:
		_dbg_ray(origin, target, Color.RED, result.position)
		_log("_can_see_player — FAIL blocked by '%s'  dist=%.2f" % [
			result.collider.name if result.collider else "?", dist])
		return false

func _start_chase(player: Node3D) -> void:
	if _roar_cooldown_timer <= 0.0:
		_log("_start_chase — roar ready → roaring first")
		_begin_roar()
	else:
		_log("_start_chase — roar on cooldown (%.2fs) → chase directly" % _roar_cooldown_timer)
		_is_chasing     = true
		target_position = player.global_position
		_has_target     = true

func _stop_chase() -> void:
	if _is_chasing:
		_log("_stop_chase — chase ended")
	_is_chasing     = false
	target_position = Vector3.ZERO
	_has_target     = false

func _begin_roar() -> void:
	_log("_begin_roar — duration=%.1f  cooldown=%.1f" % [ROAR_DURATION, ROAR_COOLDOWN])
	_is_roaring          = true
	_roar_timer          = ROAR_DURATION
	_roar_cooldown_timer = ROAR_COOLDOWN
	
	animation_tree.set("parameters/RoarOneShot/request",
				AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	var dialogue_id := randi_range(80, 84)
	_log("_begin_roar — playing dialogue id=%d" % dialogue_id)
	play_dialogue(dialogue_id, 30, 0.5)

func _tick_roar(delta: float) -> void:
	_roar_timer -= delta

	_log("_tick_roar — timer=%.2f" % _roar_timer)

	if _roar_timer <= 0.0:
		_log("_tick_roar — roar expired → _end_roar")
		_end_roar()

func _end_roar() -> void:
	_is_roaring = false

func roar() -> void:
	_begin_roar()

func _update_kill_check(delta: float) -> void:
	if _is_killing:
		return

	var player = get_player()
	if not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)

	if not _is_chasing and dist > KILL_DISTANCE:
		return

	_kill_check_timer -= delta
	if _kill_check_timer > 0.0:
		return
	_kill_check_timer = KILL_CHECK_INTERVAL

	_log("_update_kill_check — dist=%.3f  threshold=%.3f  chasing=%s" % [
			dist, KILL_DISTANCE, _is_chasing])

	if dist <= KILL_DISTANCE:
		_log("_update_kill_check — IN KILL RANGE → _begin_kill")
		_begin_kill(player)

func _begin_kill(player: Node3D) -> void:
	
	if player.is_dead:
		return
	
	_log("_begin_kill — start  player=%s  me=%s" % [
			player.global_position, global_position])
	_is_killing     = true
	_is_chasing     = true
	_has_target     = true
	target_position = player.global_position

	animation_tree.set("parameters/KillOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_log("_begin_kill — attack anim started, waiting 0.3 s")

	await get_tree().create_timer(0.3).timeout

	_is_killing        = false
	_is_killing_locked = true

	var cur = get_player()
	if is_instance_valid(cur):
		var dist_now := global_position.distance_to(cur.global_position)
		_log("_begin_kill — post-delay dist=%.3f  threshold=%.3f" % [dist_now, KILL_DISTANCE])
		if dist_now <= KILL_DISTANCE:
			_log("_begin_kill — KILL CONFIRMED")
			player.die()
			_is_chasing = false
			_has_target = false
			roar()
		else:
			_log("_begin_kill — player escaped, resuming chase")
			target_position = cur.global_position  # keep chasing
	else:
		_log("_begin_kill — player became invalid during attack delay")
		_is_chasing = false
		_has_target = false

	_is_killing_locked = false
	_log("_begin_kill — sequence complete  %s" % _state())

func _begin_patrol() -> void:
	_log("_begin_patrol — generating %d waypoints around last_seen=%s" % [
			PATROL_WAYPOINT_COUNT, _last_seen_position])
	_patrol_waypoints.clear()
	_patrol_index = 0

	var player = get_player()
	for i in range(PATROL_WAYPOINT_COUNT):
		var angle         := randf() * TAU
		var radius        := randf_range(PATROL_WANDER_RADIUS * 0.4, PATROL_WANDER_RADIUS)
		var random_offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var wander_pt     := _last_seen_position + random_offset
		var bias_target   = player.global_position if is_instance_valid(player) else _last_seen_position
		var waypoint      := wander_pt.lerp(bias_target, PATROL_PLAYER_BIAS * randf())
		_patrol_waypoints.append(waypoint)
		_log("_begin_patrol — waypoint[%d] = %s" % [i, waypoint])

	_patrol_state = PatrolState.PATROLLING
	_advance_patrol_waypoint()

func _tick_patrol() -> void:
	if _patrol_state != PatrolState.PATROLLING or _is_chasing:
		return

	var player = get_player()
	if is_instance_valid(player) and _patrol_index < _patrol_waypoints.size():
		_patrol_waypoints[_patrol_index] = _patrol_waypoints[_patrol_index].lerp(
				player.global_position, PATROL_PLAYER_BIAS * 0.02)
		target_position = _patrol_waypoints[_patrol_index]

	var to_wp := target_position - global_position
	to_wp.y   = 0.0
	if to_wp.length() < STOP_DISTANCE + 0.5:
		_log("_tick_patrol — reached waypoint[%d]" % _patrol_index)
		_patrol_index += 1
		if _patrol_index >= _patrol_waypoints.size():
			_log("_tick_patrol — all waypoints done → idle")
			_stop_patrol()
		else:
			_advance_patrol_waypoint()

func _advance_patrol_waypoint() -> void:
	if _patrol_index < _patrol_waypoints.size():
		target_position = _patrol_waypoints[_patrol_index]
		_has_target     = true
		_log("_advance_patrol_waypoint — [%d] → %s" % [_patrol_index, target_position])

func _stop_patrol() -> void:
	if _patrol_state == PatrolState.PATROLLING:
		_log("_stop_patrol — patrol ended")
	_patrol_state = PatrolState.IDLE
	_patrol_waypoints.clear()
	target_position = Vector3.ZERO
	_has_target     = false
	
func _is_in_player_view() -> bool:
	var player = get_player()
	if not is_instance_valid(player):
		return false

	var to_monster = global_position - player.global_position
	to_monster.y   = 0.0
	if to_monster.length() < 0.001:
		return true

	var player_fwd = -player.global_transform.basis.z
	player_fwd.y   = 0.0
	if player_fwd.length() < 0.001:
		return false

	return player_fwd.normalized().dot(to_monster.normalized()) >= TELEPORT_PLAYER_FOV_DOT


func _update_teleport(delta: float) -> void:
	var player = get_player()
	if not is_instance_valid(player) or player.is_dead:
		return

	_teleport_sample_timer -= delta

	if _teleport_sample_timer <= 0.0:
		_teleport_sample_position = player.global_position
		_teleport_sample_timer    = TELEPORT_SAMPLE_INTERVAL
		_log("_update_teleport — snapshot %s" % _teleport_sample_position)
		return

	if _teleport_sample_position == Vector3.ZERO:
		return

	if _is_in_player_view():
		return

	var dist_from_sample = player.global_position.distance_to(_teleport_sample_position)
	if dist_from_sample <= TELEPORT_MOVE_THRESHOLD:
		return

	_log("_update_teleport — TELEPORT  sample=%s  player_drift=%.1f" % [
			_teleport_sample_position, dist_from_sample])

	global_position = _teleport_sample_position

	if navigation_agent_3d:
		navigation_agent_3d.target_position = global_position

	_teleport_sample_position = Vector3.ZERO
	_teleport_sample_timer    = TELEPORT_SAMPLE_INTERVAL

func apply_movement() -> void:
	if is_climbing:
		apply_climbing_movement()
		return
	var dir := get_move_direction()
	navigation_agent_3d.set_velocity(
			dir * get_speed() if dir.length() > 0.01 else Vector3.ZERO)

func update_movement_animation(input_dir: Vector2) -> void:
	if _is_killing:
		return
	var sm = animation_tree["parameters/AnimationNodeStateMachine/playback"]

	if current_ladder \
			and current_ladder.end_y() < global_position.y \
			and get_climb_input() > 0 \
			and finish_climb_animation_cooldown_timer > finish_climb_animation_cooldown:
		finish_climb_animation_cooldown_timer = 0
		sm.travel("Finish Climbing")
		is_finishing_climb = true

	if is_finishing_climb:
		return

	if is_climbing:
		sm.travel("Climb")
		animation_tree.set("parameters/AnimationNodeStateMachine/Climb/Climb Direction/scale",
				sign(get_climb_input()))
	elif not is_on_floor():
		sm.travel("Fall")
	elif input_dir.length() > 0.01 and Vector2(velocity.x, velocity.z).length() > 0.05:
		sm.travel("Jog")
	else:
		sm.travel("Idle")

func _is_near_destination() -> bool:
	
	var player = get_player()
	if player.is_dead:
		return true
	
	return false

func get_target_rotation_y() -> float:
	if is_climbing and current_ladder:
		return current_ladder.rotation.y - deg_to_rad(90)
	elif _is_near_destination():
		var to_target := target_position - global_position
		to_target.y   = 0.0
		if to_target.length() > 0.01:
			return atan2(-to_target.x, -to_target.z)
	else:
		var dir := get_move_direction()
		if dir.length() > 0.01:
			return atan2(-dir.x, -dir.z)
	return rotation.y
