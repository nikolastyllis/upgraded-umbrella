extends Interactable

@export var is_open := false

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Close" if is_open else "Open"
	
func interact_hold_time() -> float:
	return 1.0

func on_interact(_player):
	is_open = !is_open
	update_action_text()
