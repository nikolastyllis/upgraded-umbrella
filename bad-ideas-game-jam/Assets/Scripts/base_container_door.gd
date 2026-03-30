extends Interactable
class_name BaseContainerDoor

@onready var skeleton: Skeleton3D = $"../rigged_container/Skeleton3D"
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)
@onready var mesh: MeshInstance3D = $"../rigged_container/Skeleton3D/mesh_container_model"
@onready var interact_collider: CollisionShape3D = $CollisionShape3D
@onready var hull_1: CollisionShape3D = $Hull1
@onready var hull_2: CollisionShape3D = $Hull2
@onready var hull_3: CollisionShape3D = $Hull3
@onready var hull_4: CollisionShape3D = $Hull4
@onready var hull_5: CollisionShape3D = $Hull5
@onready var root = $".."

var _banging_player: AudioStreamPlayer3D = null

var is_hero_container_1 = false
var is_hero_container_2 = false

var opened_act_2 = false

const CONTAINER_MATERIALS: Array[String] = [
	"res://Materials/Containers/Container_Mat_01.tres",
	"res://Materials/Containers/Container_Mat_02.tres",
	"res://Materials/Containers/Container_Mat_03.tres",
	"res://Materials/Containers/Container_Mat_04.tres",
	"res://Materials/Containers/Container_Mat_05.tres",
]

func play_sound(sound: String) -> void:
	var path := "res://Assets/Sound/%s.ogg" % sound
	if not ResourceLoader.exists(path):
		push_warning("Sound file not found: %s" % path)
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = "Sound"
	player.stream = load(path)
	player.volume_db = -15
	add_child(player)
	player.play()
	await player.finished
	player.queue_free()
	
func _start_banging() -> void:
	var path := "res://Assets/Sound/banging_heavy.ogg"
	if not ResourceLoader.exists(path):
		push_warning("Sound file not found: %s" % path)
		return

	_banging_player = AudioStreamPlayer3D.new()
	_banging_player.bus = "Sound"
	_banging_player.volume_db = -10
	_banging_player.stream = load(path)

	if _banging_player.stream is AudioStreamOggVorbis:
		_banging_player.stream.loop = true

	add_child(_banging_player)
	_banging_player.play()

func _stop_banging() -> void:
	if _banging_player:
		_banging_player.queue_free()
		_banging_player = null

func update_action_text():
	action_text = "Breach"

func interact_hold_time() -> float:
	return 3.0

func on_interact(_player):
	if is_hero_container_1:
		open_door_act1()
		game_manager.player_has_interacted_with_container = true
		return
	
	elif is_hero_container_2:
		open_door_monster_reveal()
		game_manager.player_has_interacted_with_infected_container = true
		return
	
	else: open_door_act2()
	
func can_interact(_player: Node) -> bool:
	
	if _player.is_holding_jerry_can:
		return false
	
	if is_hero_container_1:
		return game_manager.story_increment == 2.5 and _player.has_oxy_torch
		
	if is_hero_container_2:
		return game_manager.story_increment == 7 and _player.has_oxy_torch
	
	return game_manager.story_increment == 8 and _player.has_oxy_torch

func _ready():
	
	hull_1.disabled = true
	hull_2.disabled = true
	hull_3.disabled = true
	hull_4.disabled = true
	hull_5.disabled = true
	interact_collider.disabled = false
	
	update_action_text()
	
	if root is HeroContainer:
		is_hero_container_1 = root.get_is_hero_container_1()
		is_hero_container_2 = root.get_is_hero_container_2()
	animation_player.animation_finished.connect(_on_animation_finished)
	apply_material()

func _process(_delta: float):
	
	if game_manager == null:
		return
	
	if game_manager.story_increment == 6 and not opened_act_2 and is_hero_container_1:
		opened_act_2 = true
		open_door_act2()
	
	if game_manager.story_increment == 7 and not interact_collider.disabled and is_hero_container_2:
		if _banging_player == null:
			_start_banging()
	else:
		_stop_banging()

func apply_material() -> void:
	var mat: Material = null
	
	if is_hero_container_1 or is_hero_container_2:
		return 
	else:
		var random_path: String = CONTAINER_MATERIALS[randi() % CONTAINER_MATERIALS.size()]
		mat = load(random_path)
		
	if mat:
		mesh.set_surface_override_material(0, mat)
	
func open_door_act1():
	skeleton.physical_bones_start_simulation()
	animation_player.play("Act_1_open")
	play_sound("door")
	
func open_door_act2():
	skeleton.physical_bones_start_simulation()
	animation_player.play("Act_2_open")
	play_sound("door2")
	
func open_door_monster_reveal():
	print("here")
	_stop_banging()
	skeleton.physical_bones_start_simulation()
	animation_player.play("MonsterReveal")
	play_sound("door3")

func _on_animation_finished(_animation_name: String):
	interact_collider.disabled = true
	
