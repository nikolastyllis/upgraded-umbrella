extends Node3D

class_name Highlightable

var highlight_shader = load("res://Shaders/interactable.gdshader")

# Store the original material so we can restore it later
var original_materials = {}

func add_highlight() -> void:
	print("Adding highlight")
	var mesh_instance = get_mesh_instance()
	
	print(mesh_instance)
	if mesh_instance == null:
		return
	
	var active_material = mesh_instance.get_active_material(0)
	if active_material == null:
		return
	
	# Duplicate the material for this instance only
	var instance_material = active_material.duplicate() as Material
	
	# Wrap the shader in a ShaderMaterial for the next_pass
	var highlight_material = ShaderMaterial.new()
	highlight_material.shader = highlight_shader
	
	instance_material.set_next_pass(highlight_material)
	
	# Apply only to this MeshInstance
	mesh_instance.set_surface_override_material(0, instance_material)
	
	# Save the original for removal
	original_materials[mesh_instance] = active_material

func remove_highlight() -> void:
	print("Removing highlight")
	var mesh_instance = get_mesh_instance()
	if mesh_instance == null:
		return
	
	if not original_materials.has(mesh_instance):
		return
	
	# Restore the original material
	mesh_instance.set_surface_override_material(0, original_materials[mesh_instance])
	original_materials.erase(mesh_instance)

func get_mesh_instance() -> MeshInstance3D:
	var node: Node = self
	while node:
		if node is MeshInstance3D:
			return node
		node = node.get_parent()
	return null
