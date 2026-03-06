extends Highlightable
class_name Interactable

@export var action_text: String = "Interact"

func can_interact(_player: Node) -> bool:
	return true
	
func interact_hold_time() -> float:
	return 1.0

func on_interact(_player: Node) -> void:
	pass
