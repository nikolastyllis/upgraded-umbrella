extends Interactable

@export var is_open := false
@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Escape on the lifeboat"
	
func interact_hold_time() -> float:
	return 2.0

func can_interact(_player: Node) -> bool:
	return game_manager.story_increment == 9

func on_interact(_player):
	game_manager.escape_cut_scene()
