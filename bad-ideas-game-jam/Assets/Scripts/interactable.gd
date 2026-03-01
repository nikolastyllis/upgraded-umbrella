extends Node3D
class_name Interactable

@export var action_text: String = "interact"

func can_interact(player: Node) -> bool:
	return true

func on_interact(player: Node) -> void:
	pass
