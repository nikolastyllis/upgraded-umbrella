extends Node3D

@export var marker_ui_scene: PackedScene
@export var edge_padding: float = 40.0
@export var move_smoothness: float = 25.0
@export var rotation_smoothness: float = 20.0
@export var world_offset: Vector3 = Vector3(0, 1, 0)

@onready var marker_ui := $ObjectiveMarkerUI
var icon: TextureRect
var distance: RichTextLabel
var camera: Camera3D

var target_pos: Vector2
var target_rotation: float = 0.0

func _ready():
	camera = get_viewport().get_camera_3d()
	icon = marker_ui.get_node("Icon")
	distance = marker_ui.get_node("Distance")
	target_pos = marker_ui.position

func _process(delta: float):
	if camera == null or marker_ui == null:
		return

	var world_pos: Vector3 = global_position + world_offset

	var screen_pos: Vector2 = camera.unproject_position(world_pos)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var is_behind: bool = camera.is_position_behind(world_pos)

	var on_screen: bool = (
		screen_pos.x > 0.0 and screen_pos.x < viewport_size.x and
		screen_pos.y > 0.0 and screen_pos.y < viewport_size.y and
		not is_behind
	)
	
	var distance_magnitude = (camera.global_position - global_position).length()

	if distance_magnitude > 10:
		distance.visible = true
		distance.text = str(roundi(distance_magnitude)) + "m"
	else:
		distance.visible = false

	var min_scale = 0.05
	var max_scale = 0.1 
	var scale_distance = clamp(distance_magnitude, 5, 50)  # clamp distance to avoid extremes
	var scale_factor = lerp(max_scale, min_scale, (scale_distance - 5) / (50 - 5))
	icon.scale = Vector2(scale_factor, scale_factor)
	
	if on_screen:
		_set_marker_position(screen_pos)
	else:
		_set_marker_edge(screen_pos, viewport_size)

	marker_ui.position = marker_ui.position.lerp(target_pos, 1.0 - pow(0.01, delta * move_smoothness))

	icon.rotation = lerp_angle(icon.rotation, target_rotation, 1.0 - pow(0.01, delta * rotation_smoothness))

func _set_marker_position(pos: Vector2):
	marker_ui.visible = true
	target_pos = pos
	target_rotation = 0.0

func _set_marker_edge(screen_pos: Vector2, viewport_size: Vector2):
	var center: Vector2 = viewport_size * 0.5
	var dir: Vector2 = screen_pos - center

	if dir.length() == 0.0:
		dir = Vector2.UP
	else:
		dir = dir.normalized()

	target_rotation = dir.angle() + PI * 1.5

	var half_size: Vector2 = viewport_size * 0.5
	var max_x: float = half_size.x - edge_padding
	var max_y: float = half_size.y - edge_padding

	var t_x: float = max_x / abs(dir.x) if dir.x != 0.0 else INF
	var t_y: float = max_y / abs(dir.y) if dir.y != 0.0 else INF
	var t: float = min(t_x, t_y)

	target_pos = center + dir * t
	marker_ui.visible = true

func remove():
	queue_free()
