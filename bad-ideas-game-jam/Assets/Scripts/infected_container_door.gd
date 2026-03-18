extends Interactable

@onready var animation_player = $"../../../../AnimationPlayer"
@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Cut open"
	
func interact_hold_time() -> float:
	return 10.0

func on_interact(_player):
	_play_sound("door3")
	animation_player.play("Act_3_open")
	game_manager.player_has_interacted_with_infected_container = true
		
func can_interact(_player: Node) -> bool:
	return game_manager.story_increment == 6 and game_manager.player_has_interacted_with_infected_container == false
	
func _play_sound(sound: String) -> void:
	var STATIC_PATH := "res://Assets/Sound/%s.ogg" % sound
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
