extends Interactable

@onready var collider = $CollisionShape3D

func _ready():
	update_action_text()

func update_action_text():
	action_text = "Drink energy drink"
	
func interact_hold_time() -> float:
	return 0.5

func on_interact(_player):
	visible = false
	collider.disabled = true
	await play_sound("drink")	
	_player.drink()	
	queue_free()

func can_interact(_player: Node) -> bool:
	return true
	
func play_sound(sound: String) -> void:
	var STATIC_PATH := "res://Assets/Sound/%s.ogg" % sound
	if not ResourceLoader.exists(STATIC_PATH):
		push_warning("Static file not found: %s" % STATIC_PATH)
		return
	var static_player := AudioStreamPlayer.new()
	static_player.bus = "Sound"
	static_player.stream = load(STATIC_PATH)
	static_player.volume_db = 0.0
	add_child(static_player)
	static_player.play()
	await static_player.finished
	static_player.queue_free()
