extends Interactable

@export var is_open := false

func _ready():
	update_action_text()

func update_action_text():
	action_text = "close" if is_open else "open"

func on_interact(player):
	is_open = !is_open
	update_action_text()
