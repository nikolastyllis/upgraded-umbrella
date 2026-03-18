@tool
extends Node3D

@export_group("Container Assets")
@export var container_mesh: Mesh:
	set(value):
		container_mesh = value
		_regen_in_editor()

@export var container_materials: Array[Material] = []:
	set(value):
		container_materials = value
		_regen_in_editor()

@export_group("Stack Layout")
@export var bays: int = 20:
	set(value):
		bays = value
		_regen_in_editor()

@export var rows: int = 8:
	set(value):
		rows = value
		_regen_in_editor()

@export var max_tiers: int = 5:
	set(value):
		max_tiers = value
		_regen_in_editor()

@export_group("Mesh Gap Spacing")
@export var gap_x: float = 0.0:
	set(value):
		gap_x = value
		_regen_in_editor()

@export var gap_y: float = 0.0:
	set(value):
		gap_y = value
		_regen_in_editor()

@export var gap_z: float = 0.0:
	set(value):
		gap_z = value
		_regen_in_editor()

@export_group("Stack Shape")
@export var min_tiers: int = 1:
	set(value):
		min_tiers = value
		_regen_in_editor()

@export var stack_presence_chance: float = 0.92:
	set(value):
		stack_presence_chance = value
		_regen_in_editor()

@export var height_variation_bias: float = 0.65:
	set(value):
		height_variation_bias = value
		_regen_in_editor()

@export_group("Colour Grouping")
@export_range(0.0, 1.0, 0.01) var dominant_material_strength: float = 0.8:
	set(value):
		dominant_material_strength = value
		_regen_in_editor()

@export_group("Randomisation")
@export var seed_value: int = 12345:
	set(value):
		seed_value = value
		_regen_in_editor()

@export_range(0.0, 1.0, 0.01) var flip_180_chance: float = 0.08:
	set(value):
		flip_180_chance = value
		_regen_in_editor()

@export var random_offset_x: float = 0.01:
	set(value):
		random_offset_x = value
		_regen_in_editor()

@export var random_offset_z: float = 0.01:
	set(value):
		random_offset_z = value
		_regen_in_editor()

@export_group("Placement")
@export var centre_on_node: bool = true:
	set(value):
		centre_on_node = value
		_regen_in_editor()

@export_group("Debug")
@export var measured_mesh_size: Vector3 = Vector3.ZERO
@export var final_step: Vector3 = Vector3.ZERO

@export_group("Actions")
@export var generate_now: bool = false:
	set(value):
		if value:
			generate_now = false
			generate_containers()
			notify_property_list_changed()

@export var clear_now: bool = false:
	set(value):
		if value:
			clear_now = false
			clear_containers()
			notify_property_list_changed()

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if not Engine.is_editor_hint():
		if get_child_count() == 0:
			generate_containers()

func _regen_in_editor() -> void:
	if not Engine.is_editor_hint():
		return
	if container_mesh == null:
		return
	if container_materials.is_empty():
		return
	generate_containers()

func clear_containers() -> void:
	for child: Node in get_children():
		if child.is_in_group("generated_containers"):
			child.queue_free()

func generate_containers() -> void:
	if container_mesh == null:
		push_warning("No container_mesh assigned.")
		return

	if container_materials.is_empty():
		push_warning("No container_materials assigned.")
		return

	clear_containers()
	rng.seed = seed_value

	var mesh_size: Vector3 = _get_mesh_size(container_mesh)
	measured_mesh_size = mesh_size

	var step_x: float = mesh_size.x + gap_x
	var step_y: float = mesh_size.y + gap_y
	var step_z: float = mesh_size.z + gap_z
	final_step = Vector3(step_x, step_y, step_z)

	var x_origin: float = 0.0
	var z_origin: float = 0.0

	if centre_on_node:
		x_origin = float(rows - 1) * step_x * 0.5
		z_origin = float(bays - 1) * step_z * 0.5

	for bay: int in range(bays):
		for row: int in range(rows):
			if rng.randf() > stack_presence_chance:
				continue

			var stack_height: int = _get_stack_height()
			var dominant_index: int = rng.randi_range(0, container_materials.size() - 1)

			for tier: int in range(stack_height):
				var container: MeshInstance3D = MeshInstance3D.new()
				container.mesh = container_mesh

				var chosen_index: int = dominant_index
				if rng.randf() > dominant_material_strength:
					chosen_index = rng.randi_range(0, container_materials.size() - 1)

				container.material_override = container_materials[chosen_index]

				var pos: Vector3 = Vector3(
					float(row) * step_x - x_origin,
					float(tier) * step_y,
					float(bay) * step_z - z_origin
				)

				pos.x += rng.randf_range(-random_offset_x, random_offset_x)
				pos.z += rng.randf_range(-random_offset_z, random_offset_z)

				container.position = pos

				if rng.randf() < flip_180_chance:
					container.rotation.y = PI

				container.add_to_group("generated_containers")
				add_child(container)

				if Engine.is_editor_hint():
					if get_tree() != null:
						container.owner = get_tree().edited_scene_root

	notify_property_list_changed()

func _get_mesh_size(mesh: Mesh) -> Vector3:
	var aabb: AABB = mesh.get_aabb()
	var size: Vector3 = aabb.size

	# Just in case anything odd comes through negative/small.
	size.x = absf(size.x)
	size.y = absf(size.y)
	size.z = absf(size.z)

	return size

func _get_stack_height() -> int:
	var safe_min: int = mini(min_tiers, max_tiers)
	var safe_max: int = maxi(min_tiers, max_tiers)

	if safe_min == safe_max:
		return safe_min

	var t: float = pow(rng.randf(), 1.0 + (1.0 - height_variation_bias) * 3.0)
	var result: int = safe_min + int(round((1.0 - t) * float(safe_max - safe_min)))
	return clampi(result, safe_min, safe_max)
