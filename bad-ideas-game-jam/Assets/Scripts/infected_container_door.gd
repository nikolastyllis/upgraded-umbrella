extends Interactable
@onready var animation_player = $"../../../../AnimationPlayer"
@onready var game_manager = get_tree().get_root().find_child("GameManager", true, false)
@onready var mesh_instance = $".."

var _banging_player: AudioStreamPlayer3D = null

func _ready():
	update_action_text()

func _process(_delta: float) -> void:
	if game_manager.story_increment == 7 and not game_manager.player_has_interacted_with_infected_container:
		if _banging_player == null:
			_start_banging()
	else:
		_stop_banging()

func _start_banging() -> void:
	var path := "res://Assets/Sound/banging_heavy.ogg"
	if not ResourceLoader.exists(path):
		push_warning("Sound file not found: %s" % path)
		return
	_banging_player = AudioStreamPlayer3D.new()
	_banging_player.bus = "Sound"
	_banging_player.stream = load(path)
	_banging_player.volume_db = 0.0
	# Loop the stream
	var playback: AudioStream = _banging_player.stream
	if playback is AudioStreamOggVorbis:
		playback.loop = true
	add_child(_banging_player)
	_banging_player.play()

func _stop_banging() -> void:
	if _banging_player:
		_banging_player.queue_free()
		_banging_player = null

func update_action_text():
	action_text = "Open"
	
func interact_hold_time() -> float:
	return 3.0

func on_interact(_player):
	_stop_banging()
	_play_sound("door3")
	animation_player.play("MonsterReveal")
	game_manager.player_has_interacted_with_infected_container = true
	await animation_player.animation_finished
	_rebuild_collision()
	game_manager.rebake()
	
func _rebuild_collision() -> void:
	var new_shape = mesh_instance.mesh.create_trimesh_shape()
	$CollisionShape3D.shape = new_shape

func can_interact(_player: Node) -> bool:
	return game_manager.story_increment == 7 and not game_manager.player_has_interacted_with_infected_container
	
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
