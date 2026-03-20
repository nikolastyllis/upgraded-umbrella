extends BaseContainerDoor

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

	if _banging_player.stream is AudioStreamOggVorbis:
		_banging_player.stream.loop = true

	add_child(_banging_player)
	_banging_player.play()

func _stop_banging() -> void:
	if _banging_player:
		_banging_player.queue_free()
		_banging_player = null

func update_action_text():
	action_text = "Open"

func interact_hold_time() -> float:
	return 5.0

func on_interact(_player):
	_stop_banging()
	_play_sound("door3")
	await _play_animation_and_rebake("MonsterReveal")
	_set_open_collisions()
	game_manager.player_has_interacted_with_infected_container = true

func can_interact(_player: Node) -> bool:
	return game_manager.story_increment == 7 and not game_manager.player_has_interacted_with_infected_container and _player.has_oxy_torch
