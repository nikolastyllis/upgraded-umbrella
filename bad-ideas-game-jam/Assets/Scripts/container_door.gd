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
	_play_sound()
		
func can_interact(_player: Node) -> bool:
	return game_manager.story_increment == 2 and opened_act_1 == false
	
func _play_sound() -> void:
	var STATIC_PATH := "res://Assets/Sound/door.ogg"
	if not ResourceLoader.exists(STATIC_PATH):
		push_warning("Static file not found: %s" % STATIC_PATH)
		return
	var static_player := AudioStreamPlayer3D.new()
	static_player.bus = "Sound"
	static_player.stream = load(STATIC_PATH)
	static_player.volume_db = 0.0
	add_child(static_player)
	static_player.play()
	await static_player.finished
	static_player.queue_free()
