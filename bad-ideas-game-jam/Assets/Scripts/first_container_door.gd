extends BaseContainerDoor

var opened_act_1 = false
var opened_act_2 = false

func _ready():
	update_action_text()

func _process(_delta: float) -> void:
	if game_manager.story_increment == 6 and not opened_act_2:
		opened_act_2 = true
		_play_sound("door2")

func update_action_text():
	action_text = "Cut open"

func interact_hold_time() -> float:
	return 5.0

func on_interact(_player):
	opened_act_1 = true
	_play_sound("door")
	animation_player.play("Act_1_open")
	game_manager.player_has_interacted_with_container = true

func can_interact(_player: Node) -> bool:
	return game_manager.story_increment == 2 and not opened_act_1 and _player.has_oxy_torch
