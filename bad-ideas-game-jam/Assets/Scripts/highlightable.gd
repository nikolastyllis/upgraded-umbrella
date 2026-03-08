extends Node3D

class_name Highlightable

var highlight_shader = load("res://Shaders/interactable.gdshader")

var original_materials = {}

func add_highlight() -> void:
	var mesh_instance = get_mesh_instance()
	
	if mesh_instance == null:
		return
	
	var active_material = mesh_instance.get_active_material(0)
	if active_material == null:
		return
	
	var instance_material = active_material.duplicate() as Material
	
	var highlight_material = ShaderMaterial.new()
	highlight_material.shader = highlight_shader
	
	instance_material.set_next_pass(highlight_material)
	
	mesh_instance.set_surface_override_material(0, instance_material)
	
	original_materials[mesh_instance] = active_material

func remove_highlight() -> void:
	var mesh_instance = get_mesh_instance()
	if mesh_instance == null:
		return
	
	if not original_materials.has(mesh_instance):
		return
	
	mesh_instance.set_surface_override_material(0, original_materials[mesh_instance])
	original_materials.erase(mesh_instance)

func get_mesh_instance() -> MeshInstance3D:
	var node: Node = self
	while node:
		if node is MeshInstance3D:
			return node
		node = node.get_parent()
	return null
