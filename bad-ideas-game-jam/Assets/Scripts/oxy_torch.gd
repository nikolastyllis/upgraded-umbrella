extends Interactable

signal picked_up(item: Node)

var _held := false
var _original_parent: Node = null
var _original_transform: Transform3D
@onready var rigid_body = $"."
var player = null

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Pick up oxy-fuel torch"

func interact_hold_time() -> float:
	return 1.0

func on_interact(_player):
	player = _player
	player.has_oxy_torch = true
	_original_parent = get_parent()
	_original_transform = global_transform
	rigid_body.freeze = true
	set_collision_enabled(false)

	var hand_attachment = player.get_node("Character/Armature/Skeleton3D/RightHandAttachment")
	get_parent().remove_child(self)
	hand_attachment.add_child(self)
	global_transform = _original_transform

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", Vector3.ZERO, 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation", Vector3.ZERO, 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	await tween.finished
	_held = true
	picked_up.emit(self)

func _process(_delta):
	if _held and Input.is_action_just_pressed("drop"):
		drop()

func drop():
	player.has_oxy_torch = false
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
