extends Interactable
class_name BaseContainerDoor

@onready var skeleton: Skeleton3D = $"../rigged_container/Skeleton3D"
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)
@onready var mesh: MeshInstance3D = $"../rigged_container/Skeleton3D/mesh_container_model"
@onready var interact_collider: CollisionShape3D = $CollisionShape3D

const CONTAINER_MATERIALS: Array[String] = [
	"res://Shaders/Containers/Container_Mat_01.tres",
	"res://Shaders/Containers/Container_Mat_02.tres",
	"res://Shaders/Containers/Container_Mat_03.tres",
	"res://Shaders/Containers/Container_Mat_04.tres",
	"res://Shaders/Containers/Container_Mat_05.tres",
]

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

func update_action_text():
	action_text = "Cut open"

func interact_hold_time() -> float:
	return 5.0

func on_interact(_player):
	open_door()

func can_interact(_player: Node) -> bool:
	return _player.has_oxy_torch

func _ready():
	animation_player.animation_finished.connect(_on_animation_finished)
	_apply_random_material()

func _apply_random_material() -> void:
	var random_path: String = CONTAINER_MATERIALS[randi() % CONTAINER_MATERIALS.size()]
	var mat: Material = load(random_path)
	if mat:
		mesh.set_surface_override_material(0, mat)
	else:
		push_warning("Failed to load container material: %s" % random_path)

func open_door():
	skeleton.physical_bones_start_simulation()
	animation_player.play("DoorOpen_01")

func _on_animation_finished(_animation_name: String):
	interact_collider.disabled = true
