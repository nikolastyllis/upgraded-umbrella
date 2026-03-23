extends Interactable

signal picked_up(item: Node)

var _held := false
var _original_parent: Node = null
var _original_transform: Transform3D
@onready var rigid_body = $"."
var player = null
var game_manager = null
var lifeboat = null
var dropped_at_lifeboat = false

var box_types = [$Box_A, $Box_B, $Box_C]
var meshes = [$"Box_A/box_A", $"Box_B/box_B", $"Box_C/box_C"]

func _ready():
	var idx = randi() % box_types.size()
	
	# Show only the chosen box, hide the rest
	for i in box_types.size():
		box_types[i].visible = (i == idx)
	
	# Generate a bounding box collider from the chosen mesh
	var mesh_instance: MeshInstance3D = meshes[idx]
	var aabb: AABB = mesh_instance.get_aabb()
	
	var box_shape = BoxShape3D.new()
	box_shape.size = aabb.size
	
	var col_shape = CollisionShape3D.new()
	col_shape.shape = box_shape
	# Transform the AABB center from mesh-local space into the RigidBody's local space
	col_shape.position = mesh_instance.position + mesh_instance.basis * aabb.get_center()
	add_child(col_shape)
	
	update_action_text()

func update_action_text():
	action_text = "Pick up supplies"

func interact_hold_time() -> float:
	return 1.0

func on_interact(_player):
	
	game_manager = get_tree().get_nodes_in_group("game_manager")[0]
	lifeboat = get_tree().get_nodes_in_group("lifeboat")[0]
	
	player = _player
	player.is_holding_jerry_can = true
	_original_parent = get_parent()
	_original_transform = global_transform
	rigid_body.freeze = true
	set_collision_enabled(false)

	var right_hand_attachment = player.get_node("Character/Armature/Skeleton3D/RightHandAttachment")
	get_parent().remove_child(self)
	right_hand_attachment.add_child(self)
	global_transform = _original_transform

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", Vector3(0.0, 0.0, 0.0), 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation", Vector3.ZERO, 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tween.finished

	_held = true
	picked_up.emit(self)

func can_interact(_player: Node) -> bool:
	return not dropped_at_lifeboat

func _process(_delta):
	if _held and Input.is_action_just_pressed("drop"):
		drop()
		
	if _held and _is_near_lifeboat():
		drop()
		dropped_at_lifeboat = true
		game_manager.number_of_supplies += 1
		
func _is_near_lifeboat() -> bool:
	return (global_position - lifeboat.global_position).length() < 1

func drop():
	player.is_holding_jerry_can = false
	_held = false
	var saved_transform = global_transform
	get_parent().remove_child(self)
	_original_parent.add_child(self)
	global_transform = saved_transform
	set_collision_enabled(true)
	rigid_body.freeze = false

func set_collision_enabled(enabled: bool) -> void:
	for child in rigid_body.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled
