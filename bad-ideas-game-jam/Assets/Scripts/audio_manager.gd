extends Node3D
enum Track { THUNDER, THUNDER2, RAIN, INSIDE, OUTSIDE, AMBIENT1, AMBIENT2, BOSS }
var ambient1_stream: AudioStream = preload("res://Music/ambient1.ogg")
var ambient2_stream: AudioStream = preload("res://Music/ambient2.ogg")
var thunder_stream:  AudioStream = preload("res://Assets/Sound/thunder.ogg")
var thunder2_stream: AudioStream = preload("res://Assets/Sound/thunder2.ogg")
var rain_stream:     AudioStream = preload("res://Assets/Sound/rain.ogg")
var inside_stream:   AudioStream = preload("res://Assets/Sound/inside.ogg")
var outside_stream:  AudioStream = preload("res://Assets/Sound/outside.ogg")
var boss_stream:     AudioStream = preload("res://Music/boss.ogg")
const FADE_SPEED: float = 20
const AMBIENT_TRACKS = [Track.RAIN, Track.INSIDE, Track.OUTSIDE]
const MUSIC_TRACKS = [Track.AMBIENT1, Track.AMBIENT2]
var _players: Dictionary = {}
var _targets: Dictionary = {}

var _creak_streams := [
	preload("res://Assets/Sound/creaks1.ogg"),
	preload("res://Assets/Sound/creaks2.ogg"),
	preload("res://Assets/Sound/creaks3.ogg"),
]
var _creak_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	_players[Track.THUNDER]  = _create_player(thunder_stream)
	_players[Track.THUNDER2] = _create_player(thunder2_stream)
	_players[Track.RAIN]     = _create_player(rain_stream,    true)
	_players[Track.INSIDE]   = _create_player(inside_stream,  true)
	_players[Track.OUTSIDE]  = _create_player(outside_stream, true)
	_players[Track.AMBIENT1] = _create_player(ambient1_stream, false, "Music")
	_players[Track.AMBIENT2] = _create_player(ambient2_stream, false, "Music")
	_players[Track.BOSS]     = _create_player(boss_stream,    false, "Music") 
	for track in _players:
		_targets[track] = -80.0
	for s in _creak_streams:
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = -20.0
		p.bus = "Sound"
		add_child(p)
		_creak_players.append(p)

func _process(delta: float) -> void:
	for track in AMBIENT_TRACKS:
		var p: AudioStreamPlayer = _players[track]
		var target: float = _targets[track]
		if not p.playing and target > -80.0:
			p.volume_db = -80.0
			p.play()
		p.volume_db = move_toward(p.volume_db, target, delta * FADE_SPEED)
		if p.playing and target <= -80.0 and p.volume_db <= -79.0:
			p.stop()
			
	for track in MUSIC_TRACKS:
		var p: AudioStreamPlayer = _players[track]
		var target: float = _targets[track]
		p.volume_db = move_toward(p.volume_db, target, delta * FADE_SPEED)
		if p.playing and target <= -80.0 and p.volume_db <= -79.0:
			p.stop()

func _create_player(stream: AudioStream, looping: bool = false, bus: String = "Sound") -> AudioStreamPlayer:
	if looping:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamMP3:
			stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -80.0
	p.bus = bus
	add_child(p)
	return p
	
func set_target(track: Track, db: float) -> void:
	_targets[track] = db

func fade_out_music() -> void:
	for track in MUSIC_TRACKS:
		_targets[track] = -80.0

func play(track: Track, target_db: float = 0.0) -> void:
	var p: AudioStreamPlayer
	if track == Track.THUNDER:
		p = _players[[Track.THUNDER, Track.THUNDER2].pick_random()]
		p.pitch_scale = randf_range(0.8, 1.2)
		p.volume_db   = target_db + randf_range(0.0, 3.0)
	elif track == Track.AMBIENT1 or track == Track.AMBIENT2:
		p = _players[track]
		if p.playing:
			return
		p.pitch_scale = randf_range(0.95, 1.05)
		p.volume_db   = -80.0
		_targets[track] = target_db
		p.play()
	else:
		p = _players[track]
		p.volume_db = target_db
	p.play()

func play_boss_music(target_db: float = -8) -> void:
	var p: AudioStreamPlayer = _players[Track.BOSS]
	if p.playing:
		return
	fade_out_music()
	p.volume_db = target_db 
	p.play()

func try_play_creak() -> void:
	for p in _creak_players:
		if p.playing:
			return
	_creak_players.pick_random().play()
