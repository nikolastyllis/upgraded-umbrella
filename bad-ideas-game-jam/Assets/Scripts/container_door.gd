extends Interactable

@onready var animation_player = $"../../../../AnimationPlayer"
@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)
@onready var mesh_instance = $".."

var opened_act_1 = false
var opened_act_2 = false

func _ready():
	update_action_text()
	
func _process(_delta: float) -> void:
	if game_manager.story_increment == 6 and not opened_act_2:
		_play_sound("door2")
		animation_player.play("Act_2_open")
		opened_act_2 = true

func update_action_text():
	action_text = "Cut open"
	
func interact_hold_time() -> float:
	return 10.0

func on_interact(_player):
	animation_player.play("Act_1_open")
	game_manager.player_has_interacted_with_container = true
	opened_act_1 = true
	_play_sound("door")
	await animation_player.animation_finished
	game_manager.rebake()
		
func can_interact(_player: Node) -> bool:
	return game_manager.story_increment == 2 and opened_act_1 == false
	
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
