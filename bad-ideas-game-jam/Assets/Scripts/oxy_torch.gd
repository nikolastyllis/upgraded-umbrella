extends Interactable

signal picked_up(item: Node)

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Pick up"
	
func interact_hold_time() -> float:
	return 3.0

func on_interact(_player):
	picked_up.emit()
	queue_free()
