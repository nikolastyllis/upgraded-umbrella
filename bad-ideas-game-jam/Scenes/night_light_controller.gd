extends Node3D

@export var look_driver_path: NodePath = ^"../LookDriver"

# LookDriver t range is 0.0 -> 1.0
@export_range(0.0, 1.0, 0.001) var night_start_t: float = 0.30
@export_range(0.0, 1.0, 0.001) var night_end_t: float = 0.99
@export var debug_print_state: bool = false

var look_driver: Node = null
var lights: Array[Light3D] = []
var original_energies: Dictionary = {}
var original_visibility: Dictionary = {}
var is_setup: bool = false


func _ready() -> void:
	look_driver = get_node_or_null(look_driver_path)

	if look_driver == null:
		push_warning("Night Lights: LookDriver not found at path: %s" % str(look_driver_path))
		return

	_collect_lights(self)
	_store_original_values()

	is_setup = true
	_apply_night_state()

	if debug_print_state:
		print("Night Lights ready")
		print("LookDriver: ", look_driver)
		print("Lights found: ", lights.size())


func _process(_delta: float) -> void:
	if not is_setup:
		return

	_apply_night_state()


func _apply_night_state() -> void:
	var t: float = _get_look_t()
	var is_night: bool = (t >= night_start_t and t <= night_end_t)

	if debug_print_state:
		print("Night Lights t=", t, " is_night=", is_night)

	for light: Light3D in lights:
		if not is_instance_valid(light):
			continue

		if is_night:
			light.visible = bool(original_visibility.get(light, true))
			light.light_energy = float(original_energies.get(light, 1.0))
		else:
			light.visible = false
			light.light_energy = 0.0


func _get_look_t() -> float:
	if look_driver == null:
		return 0.0

	if look_driver.has_method("_compute_t"):
		var computed_t: float = float(look_driver.call("_compute_t"))
		return clampf(computed_t, 0.0, 1.0)

	var use_manual: bool = false
	var manual_value: float = 0.0

	# Safe fallback if you ever need it
	if look_driver.get("use_manual_t") != null:
		use_manual = bool(look_driver.get("use_manual_t"))

	if look_driver.get("manual_t") != null:
		manual_value = float(look_driver.get("manual_t"))

	if use_manual:
		return clampf(manual_value, 0.0, 1.0)

	return 0.0


func _collect_lights(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Light3D:
			lights.append(child as Light3D)
		_collect_lights(child)


func _store_original_values() -> void:
	for light: Light3D in lights:
		original_energies[light] = light.light_energy
		original_visibility[light] = light.visible
