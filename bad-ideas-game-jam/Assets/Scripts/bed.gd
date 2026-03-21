extends Interactable

@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Go to sleep"
	
func interact_hold_time() -> float:
	return 1.0

func on_interact(_player):
	game_manager.player_has_slept = true
		
func can_interact(_player: Node) -> bool:
	return not game_manager.player_has_slept
