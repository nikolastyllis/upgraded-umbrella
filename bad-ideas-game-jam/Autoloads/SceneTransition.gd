extends CanvasLayer

var _overlay: ColorRect

func _ready() -> void:
	layer = 128
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # ← add this
	add_child(_overlay)

func fade_out(duration: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, duration).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func fade_in(duration: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, duration).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
