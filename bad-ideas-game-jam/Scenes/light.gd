extends OmniLight3D

var _timer := 0.0
var _next_flicker := 0.0
var _base_energy := 0.0

func _ready():
	_base_energy = light_energy
	_next_flicker = randf_range(0.02, 0.08)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _next_flicker:
		_timer = 0.0
		_next_flicker = randf_range(0.02, 0.08)

		# Occasional big spike, mostly subtle flicker
		var roll = randf()
		if roll < 0.1:
			# Bright flare
			light_energy = _base_energy * randf_range(1.8, 2.5)
		elif roll < 0.3:
			# Dip out
			light_energy = _base_energy * randf_range(0.1, 0.4)
		else:
			# Normal flicker
			light_energy = _base_energy * randf_range(0.7, 1.3)

		# Slightly shift color temperature between blue-white and orange
		light_color = Color(
			randf_range(0.9, 1.0),
			randf_range(0.85, 1.0),
			randf_range(0.7, 1.0)
		)
