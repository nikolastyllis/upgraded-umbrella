extends Interactable

@onready var animation_player = $"../../../../AnimationPlayer"
@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)

var opened_act_1 = false

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Cut open"
	
func interact_hold_time() -> float:
	return 10.0

func on_interact(_player):
	animation_player.play("Act_1_open")
	game_manager.player_has_interacted_with_container = true
	opened_act_1 = true
		
func can_interact(_player: Node) -> bool:
	return game_manager.story_increment == 2 and opened_act_1 == false
