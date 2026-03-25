extends MeshInstance3D

@export var blink_shape_name: String = "Blink"

@export var min_time_between_blinks: float = 2.0
@export var max_time_between_blinks: float = 6.0

@export var close_time: float = 0.06
@export var open_time: float = 0.08
@export var double_blink_chance: float = 0.15

var _blink_index: int = -1
var _timer: float = 0.0
var _state: String = "waiting"
var _shape_value: float = 0.0

func _ready() -> void:
	randomize()

	_blink_index = _find_blend_shape_index(blink_shape_name)
	if _blink_index == -1:
		push_warning("Blink blend shape '%s' not found on %s" % [blink_shape_name, name])
		set_process(false)
		return

	_schedule_next_blink()
	set_blend_shape_value(_blink_index, 0.0)


func _process(delta: float) -> void:
	match _state:
		"waiting":
			_timer -= delta
			if _timer <= 0.0:
				_state = "closing"

		"closing":
			_shape_value += delta / close_time
			_shape_value = clamp(_shape_value, 0.0, 1.0)
			set_blend_shape_value(_blink_index, _shape_value)

			if _shape_value >= 1.0:
				_state = "opening"

		"opening":
			_shape_value -= delta / open_time
			_shape_value = clamp(_shape_value, 0.0, 1.0)
			set_blend_shape_value(_blink_index, _shape_value)

			if _shape_value <= 0.0:
				if randf() < double_blink_chance:
					_timer = randf_range(0.05, 0.18)
					_state = "waiting_double"
				else:
					_schedule_next_blink()

		"waiting_double":
			_timer -= delta
			if _timer <= 0.0:
				_state = "closing"


func _schedule_next_blink() -> void:
	_timer = randf_range(min_time_between_blinks, max_time_between_blinks)
	_state = "waiting"


func _find_blend_shape_index(shape_name: String) -> int:
	if mesh == null:
		return -1

	for i in range(mesh.get_blend_shape_count()):
		if mesh.get_blend_shape_name(i) == shape_name:
			return i

	return -1
