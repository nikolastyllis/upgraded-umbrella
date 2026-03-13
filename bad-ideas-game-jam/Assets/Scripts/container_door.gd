extends Interactable

signal breached_container_door()

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Breach"
	
func interact_hold_time() -> float:
	return 10.0

func on_interact(_player):
	breached_container_door.emit()
	queue_free()
