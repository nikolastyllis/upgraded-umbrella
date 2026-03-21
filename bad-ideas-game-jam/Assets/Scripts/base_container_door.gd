extends Interactable
class_name BaseContainerDoor

@onready var animation_player = $"../../../../AnimationPlayer"
@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)

# --- Shared sound logic ---
func _play_sound(sound: String) -> void:
	var path := "res://Assets/Sound/%s.ogg" % sound
	if not ResourceLoader.exists(path):
		push_warning("Sound file not found: %s" % path)
		return

	var player := AudioStreamPlayer3D.new()
	player.bus = "Sound"
	player.stream = load(path)
	player.volume_db = 0.0

	add_child(player)
	player.play()
	await player.finished
	player.queue_free()

# --- Shared collision logic ---
func _set_open_collisions() -> void:
	$"../StaticBody3D2/ClosedCollision".disabled = true
	$"../StaticBody3D2/OpenCollision3".disabled = false
	$"../StaticBody3D2/OpenCollision4".disabled = false
	$"../StaticBody3D2/OpenCollision5".disabled = false
	$"../StaticBody3D2/OpenCollision6".disabled = false
	$"../StaticBody3D2/OpenCollision7".disabled = false
	$"../StaticBody3D/CollisionShape3D3".disabled = true
	$"../StaticBody3D/CollisionShape3D2".disabled = true
	$"../StaticBody3D/CollisionShape3D".disabled = true

# --- Shared animation helper ---
func _play_animation_and_rebake(anim_name: String) -> void:
	animation_player.play(anim_name)
	await animation_player.animation_finished
	game_manager.rebake()

# --- Virtual methods (override in children) ---
func update_action_text():
	pass

func interact_hold_time() -> float:
	return 0.0

func on_interact(_player):
	pass

func can_interact(_player: Node) -> bool:
	return false
