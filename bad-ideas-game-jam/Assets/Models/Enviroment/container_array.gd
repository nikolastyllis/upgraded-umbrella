@tool
extends Node3D

@export_group("Container Assets")
@export var container_scene: PackedScene:
	set(value):
		container_scene = value
		_regen_in_editor()

@export_group("Hold Grid")
@export var bays: int = 6:
	set(value):
		bays = value
		_regen_in_editor()

@export var rows: int = 5:
	set(value):
		rows = value
		_regen_in_editor()

@export var min_tiers: int = 1:
	set(value):
		min_tiers = value
		_regen_in_editor()

@export var max_tiers: int = 3:
	set(value):
		max_tiers = value
		_regen_in_editor()

@export_group("Spacing From Mesh Bounds")
@export var gap_x: float = 0.03:
	set(value):
		gap_x = value
		_regen_in_editor()

@export var gap_y: float = 0.00:
	set(value):
		gap_y = value
		_regen_in_editor()

@export var gap_z: float = 0.03:
	set(value):
		gap_z = value
		_regen_in_editor()

@export_group("Density")
@export_range(0.0, 1.0, 0.01) var stack_presence: float = 0.85:
	set(value):
		stack_presence = value
		_regen_in_editor()

@export_range(0.0, 1.0, 0.01) var outer_row_multiplier: float = 0.85:
	set(value):
		outer_row_multiplier = value
		_regen_in_editor()

@export_group("Stack Shape")
@export_range(0.0, 1.0, 0.01) var taller_stack_bias: float = 0.65:
	set(value):
		taller_stack_bias = value
		_regen_in_editor()

@export_group("Optional Empty Lane")
@export var use_empty_bay_lane: bool = false:
	set(value):
		use_empty_bay_lane = value
		_regen_in_editor()

@export var empty_bay_index: int = 0:
	set(value):
		empty_bay_index = value
		_regen_in_editor()

@export var use_empty_row_lane: bool = false:
	set(value):
		use_empty_row_lane = value
		_regen_in_editor()

@export var empty_row_index: int = 0:
	set(value):
		empty_row_index = value
		_regen_in_editor()

@export_group("Placement")
@export var centre_on_node: bool = true:
	set(value):
		centre_on_node = value
		_regen_in_editor()

@export var correct_to_mesh_aabb_position: bool = true:
	set(value):
		correct_to_mesh_aabb_position = value
		_regen_in_editor()

@export_group("Randomisation")
@export var seed_value: int = 12345:
	set(value):
		seed_value = value
		_regen_in_editor()

@export var random_offset_x: float = 0.005:
	set(value):
		random_offset_x = value
		_regen_in_editor()

@export var random_offset_z: float = 0.005:
	set(value):
		random_offset_z = value
		_regen_in_editor()

@export var flip_base_rotation: bool = false:
	set(value):
		flip_base_rotation = value
		_regen_in_editor()

@export_group("Debug")
@export var measured_mesh_size: Vector3 = Vector3.ZERO
@export var measured_mesh_aabb_pos: Vector3 = Vector3.ZERO
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

const MESH_NODE_PATH := "rigged_container/Skeleton3D/mesh_container_model"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if not Engine.is_editor_hint():
		if _generated_child_count() == 0:
			generate_containers()

func _regen_in_editor() -> void:
	if not Engine.is_editor_hint():
		return
	if container_scene == null:
		return
	generate_containers()

func clear_containers() -> void:
	for child: Node in get_children():
		if child.is_in_group("generated_containers"):
			child.queue_free()

func _get_mesh_aabb() -> AABB:
	var probe: Node = container_scene.instantiate()
	var mesh_node := probe.get_node_or_null(MESH_NODE_PATH) as MeshInstance3D
	var aabb := AABB()
	if mesh_node and mesh_node.mesh:
		aabb = mesh_node.mesh.get_aabb()
	probe.queue_free()
	return aabb

func _get_facing(bay: int, row: int, tier: int) -> float:
	var parity: int = (bay + row + tier) % 2
	if flip_base_rotation:
		parity = 1 - parity
	return PI if parity == 1 else 0.0

func generate_containers() -> void:
	if container_scene == null:
		push_warning("No container_scene assigned.")
		return

	clear_containers()
	rng.seed = seed_value

	var aabb: AABB = _get_mesh_aabb()
	var mesh_size: Vector3 = aabb.size.abs()

	measured_mesh_size = mesh_size
	measured_mesh_aabb_pos = aabb.position

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
		if use_empty_bay_lane and bay == empty_bay_index:
			continue

		for row: int in range(rows):
			if use_empty_row_lane and row == empty_row_index:
				continue

			var presence: float = stack_presence * _get_row_multiplier(row)
			if rng.randf() > presence:
				continue

			var stack_height: int = _get_stack_height()
			if stack_height <= 0:
				continue

			for tier: int in range(stack_height):
				var container: Node3D = container_scene.instantiate() as Node3D

				var pos: Vector3 = Vector3(
					float(row) * step_x - x_origin,
					float(tier) * step_y,
					float(bay) * step_z - z_origin
				)

				if correct_to_mesh_aabb_position:
					pos -= aabb.position

				pos.x += rng.randf_range(-random_offset_x, random_offset_x)
				pos.z += rng.randf_range(-random_offset_z, random_offset_z)

				container.position = pos

				if tier == 0:
					container.rotation.y = _get_facing(bay, row, 0)
				else:
					container.rotation.y = 0.0

				container.add_to_group("generated_containers")
				add_child(container)

				if Engine.is_editor_hint():
					container.owner = get_tree().edited_scene_root

	notify_property_list_changed()

func _generated_child_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child.is_in_group("generated_containers"):
			count += 1
	return count

func _get_row_multiplier(row: int) -> float:
	if rows <= 1:
		return 1.0
	var is_outer_row: bool = (row == 0 or row == rows - 1)
	if is_outer_row:
		return outer_row_multiplier
	return 1.0

func _get_stack_height() -> int:
	var safe_min: int = mini(min_tiers, max_tiers)
	var safe_max: int = maxi(min_tiers, max_tiers)
	if safe_max <= 0:
		return 0
	if safe_min == safe_max:
		return safe_min
	var shaped: float = pow(rng.randf(), 1.0 + (1.0 - taller_stack_bias) * 3.0)
	var result: int = safe_min + int(round((1.0 - shaped) * float(safe_max - safe_min)))
	return clampi(result, safe_min, safe_max)
