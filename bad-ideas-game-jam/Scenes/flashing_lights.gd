extends Node3D

@export var look_driver_path: NodePath = ^"../LookDriver"

# LookDriver t range is 0.0 -> 1.0
@export_range(0.0, 1.0, 0.001) var night_start_t: float = 0.30
@export_range(0.0, 1.0, 0.001) var night_end_t: float = 0.70

@export var steady_group_path: NodePath = ^"Steady"
@export var flashing_group_path: NodePath = ^"Flashing"

@export var flashing_enabled: bool = true
@export var flash_speed: float = 4.0
@export var flash_min_multiplier: float = 0.0
@export var flash_max_multiplier: float = 1.0
@export var use_smooth_flash: bool = false
@export var debug_print_state: bool = false

var look_driver: Node = null

var steady_lights: Array[Light3D] = []
var flashing_lights: Array[Light3D] = []

var steady_original_energies: Dictionary = {}
var flashing_original_energies: Dictionary = {}

var steady_original_visibility: Dictionary = {}
var flashing_original_visibility: Dictionary = {}

var is_setup: bool = false
var flash_timer: float = 0.0


func _ready() -> void:
	look_driver = get_node_or_null(look_driver_path)
	if look_driver == null:
		push_warning("Night Lights: LookDriver not found at path: %s" % str(look_driver_path))
		return

	var steady_root: Node = get_node_or_null(steady_group_path)
	var flashing_root: Node = get_node_or_null(flashing_group_path)

	if steady_root != null:
		_collect_lights(steady_root, steady_lights)
		_store_light_values(steady_lights, steady_original_energies, steady_original_visibility)

	if flashing_root != null:
		_collect_lights(flashing_root, flashing_lights)
		_store_light_values(flashing_lights, flashing_original_energies, flashing_original_visibility)

	is_setup = true
	_apply_state(0.0)

	if debug_print_state:
		print("Night Lights ready")
		print("Steady lights: ", steady_lights.size())
		print("Flashing lights: ", flashing_lights.size())


func _process(delta: float) -> void:
	if not is_setup:
		return

	flash_timer += delta
	_apply_state(delta)


func _apply_state(_delta: float) -> void:
	var t: float = _get_look_t()
	var is_night: bool = (t >= night_start_t and t <= night_end_t)

	if debug_print_state:
		print("t=", t, " is_night=", is_night)

	if is_night:
		_apply_steady_night()
		_apply_flashing_night()
	else:
		_apply_all_day()


func _apply_steady_night() -> void:
	for light: Light3D in steady_lights:
		if not is_instance_valid(light):
			continue

		light.visible = bool(steady_original_visibility.get(light, true))
		light.light_energy = float(steady_original_energies.get(light, 1.0))


func _apply_flashing_night() -> void:
	for light: Light3D in flashing_lights:
		if not is_instance_valid(light):
			continue

		light.visible = bool(flashing_original_visibility.get(light, true))

		var base_energy: float = float(flashing_original_energies.get(light, 1.0))

		if not flashing_enabled:
			light.light_energy = base_energy
			continue

		var multiplier: float = 1.0

		if use_smooth_flash:
			multiplier = lerpf(
				flash_min_multiplier,
				flash_max_multiplier,
				(sin(flash_timer * flash_speed) + 1.0) * 0.5
			)
		else:
			if sin(flash_timer * flash_speed) > 0.0:
				multiplier = flash_max_multiplier
			else:
				multiplier = flash_min_multiplier

		light.light_energy = base_energy * multiplier


func _apply_all_day() -> void:
	for light: Light3D in steady_lights:
		if not is_instance_valid(light):
			continue
		light.visible = false
		light.light_energy = 0.0

	for light: Light3D in flashing_lights:
		if not is_instance_valid(light):
			continue
		light.visible = false
		light.light_energy = 0.0


func _get_look_t() -> float:
	if look_driver == null:
		return 0.0

	if look_driver.has_method("_compute_t"):
		var computed_t: float = float(look_driver.call("_compute_t"))
		return clampf(computed_t, 0.0, 1.0)

	return 0.0


func _collect_lights(root: Node, out_array: Array[Light3D]) -> void:
	for child: Node in root.get_children():
		if child is Light3D:
			out_array.append(child as Light3D)
		_collect_lights(child, out_array)


func _store_light_values(
	source_lights: Array[Light3D],
	energy_dict: Dictionary,
	visibility_dict: Dictionary
) -> void:
	for light: Light3D in source_lights:
		energy_dict[light] = light.light_energy
		visibility_dict[light] = light.visible
