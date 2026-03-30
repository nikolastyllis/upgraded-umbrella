extends TextureButton

@export var url: String = "https://www.youtube.com/@nikolasdevyt"
@export var hover_scale: float = 0.11
@export var regular_scale: float = 0.1
@export var tween_duration: float = 0.15

var _tween: Tween = null

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size / 2.0
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	_on_mouse_exited()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		OS.shell_open(url)

func _on_mouse_entered() -> void:
	_animate(Vector2.ONE * hover_scale)

func _on_mouse_exited() -> void:
	_animate(Vector2.ONE * regular_scale)

func _animate(target_scale: Vector2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target_scale, tween_duration)
