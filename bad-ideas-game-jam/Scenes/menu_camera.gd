extends Camera3D

@export var fade_overlay: NodePath = NodePath("")
@export var hold_duration: float = 4.0
@export var fade_duration: float = 0.55
@export var camera_height: float = 2.2
@export var height_jitter: float = 1.4
@export var min_shot_distance: float = 8.0
@export var clearance_radius: float = 0.55
@export var nudge_step: float = 0.3
@export var max_nudge_attempts: int = 24
@export var max_roll_deg: float = 2.0
@export var fov_min: float = 52.0
@export var fov_max: float = 74.0
@export var fov_lerp_speed: float = 0.35
@export_flags_3d_physics var collision_mask: int = 1

var _overlay: CanvasItem
var _tween: Tween
var _holding: bool = false
var _hold_timer: float = 0.0
var _fov_target: float = 62.0
var _nav_regions: Array = []

func _ready() -> void:
	_overlay = get_node_or_null(fade_overlay)
	if _overlay == null:
		push_warning("CinematicMenuCamera: fade_overlay NodePath is not set or invalid.")

	_refresh_nav_regions()
	fov = (fov_min + fov_max) * 0.5

	var start := _safe_nav_point(Vector3.ZERO)
	global_position = start
	_apply_look(_pick_look_target(start), randf_range(-max_roll_deg, max_roll_deg))
	_fov_target = randf_range(fov_min, fov_max)

	_set_overlay_alpha(0.0)
	_begin_hold()

func _process(delta: float) -> void:
	fov = lerpf(fov, _fov_target, fov_lerp_speed * delta)

	if _holding:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_holding = false
			_do_fade_cut()

func _begin_hold() -> void:
	_holding = true
	_hold_timer = hold_duration + randf_range(-0.6, 1.0)

func _do_fade_cut() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()

	_tween.tween_method(_set_overlay_alpha, 0.0, 1.0, fade_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_cut_to_new_shot)
	_tween.tween_method(_set_overlay_alpha, 1.0, 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_begin_hold)

func _cut_to_new_shot() -> void:
	var new_pos := _safe_nav_point(global_position)
	global_position = new_pos
	_apply_look(_pick_look_target(new_pos), randf_range(-max_roll_deg, max_roll_deg))
	_fov_target = randf_range(fov_min, fov_max)

func _set_overlay_alpha(a: float) -> void:
	if is_instance_valid(_overlay):
		_overlay.modulate.a = a

func _safe_nav_point(last_pos: Vector3) -> Vector3:
	_refresh_nav_regions()
	var min_dist_sq := min_shot_distance * min_shot_distance
	var best := Vector3.ZERO
	var best_dist := -1.0

	for _i in range(30):
		var raw := _random_navmesh_point()
		raw.y += camera_height + randf_range(0.0, height_jitter)
		var dist_sq := raw.distance_squared_to(last_pos)

		if dist_sq > best_dist:
			best_dist = dist_sq
			best = raw

		if dist_sq < min_dist_sq:
			continue

		return _push_clear(raw)

	if best != Vector3.ZERO:
		return _push_clear(best)

	return _push_clear(_random_navmesh_point())

func _random_navmesh_point() -> Vector3:
	if _nav_regions.is_empty():
		return Vector3(randf_range(-20.0, 20.0), 0.0, randf_range(-20.0, 20.0))

	var region: NavigationRegion3D = _nav_regions.pick_random()
	return NavigationServer3D.region_get_random_point(region.get_rid(), region.navigation_layers, true)

func _refresh_nav_regions() -> void:
	if not _nav_regions.is_empty() or not is_inside_tree():
		return
	_collect_nav_regions(get_tree().root)

func _collect_nav_regions(node: Node) -> void:
	if node is NavigationRegion3D:
		_nav_regions.append(node)

	for child in node.get_children():
		_collect_nav_regions(child)

func _push_clear(pos: Vector3) -> Vector3:
	if _has_clearance(pos):
		return pos

	var dirs: Array[Vector3] = [
		Vector3.UP,
		Vector3(1,1,0).normalized(), Vector3(-1,1,0).normalized(),
		Vector3(0,1,1).normalized(), Vector3(0,1,-1).normalized(),
		Vector3(1,0,0), Vector3(-1,0,0),
		Vector3(0,0,1), Vector3(0,0,-1),
		Vector3(1,1,1).normalized(), Vector3(-1,1,-1).normalized(),
		Vector3(1,1,-1).normalized(), Vector3(-1,1,1).normalized()
	]

	for step in range(1, max_nudge_attempts + 1):
		for dir in dirs:
			var candidate := pos + dir * (nudge_step * float(step))
			if _has_clearance(candidate):
				return candidate

	return pos + Vector3.UP * (nudge_step * float(max_nudge_attempts))

func _has_clearance(pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true

	var shape := SphereShape3D.new()
	shape.radius = clearance_radius

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, pos)
	params.collision_mask = collision_mask

	return space.intersect_shape(params, 1).is_empty()

func _pick_look_target(from: Vector3) -> Vector3:
	var angle := randf() * TAU
	var h_dist := randf_range(5.0, 25.0)
	var v_drop := randf_range(-1.5, 0.5)

	return from + Vector3(cos(angle) * h_dist, v_drop, sin(angle) * h_dist)

func _apply_look(target: Vector3, roll_deg: float) -> void:
	if (target - global_position).length_squared() < 0.01:
		return

	look_at(target, Vector3.UP)
	rotate_object_local(Vector3.FORWARD, deg_to_rad(roll_deg))
