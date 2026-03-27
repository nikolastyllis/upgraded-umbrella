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
var idx = -1

@onready var boxes = [$Box_A, $Box_B, $Box_C]
@onready var colliders = [$box_A_collider,$box_B_collider,$box_C_collider]
@onready var interiors = [$"../Container_Interior_BoxA_Stack", $"../Container_Interior_BoxB_Stack", $"../Container_Interior_BoxC_Stack"]

func _ready():
	idx = randi() % boxes.size()
	
	for i in boxes.size():
		boxes[i].visible = (i == idx)
	
	for i in colliders.size():
		if i != idx:
			colliders[i].queue_free()
			
	for i in interiors.size():
		if i == idx:
			interiors[i].visible = true
		if i != idx:
			interiors[i].queue_free()
	
	update_action_text()

func update_action_text():
	action_text = "Pick up supplies"

func interact_hold_time() -> float:
	return 1.0

func on_interact(_player):
	
	add_to_group("interacted_boxes")
	
	if idx == 0:
		_player.play_dialogue(95)
		
	if idx == 1:
		_player.play_dialogue(96)
	
	if idx == 2:
		_player.play_dialogue(94)
	
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
