extends Node3D

enum Track { THUNDER, THUNDER2, RAIN, INSIDE, OUTSIDE }

var thunder_stream:  AudioStream = preload("res://Assets/Sound/thunder.ogg")
var thunder2_stream: AudioStream = preload("res://Assets/Sound/thunder2.ogg")
var rain_stream:     AudioStream = preload("res://Assets/Sound/rain.ogg")
var inside_stream:   AudioStream = preload("res://Assets/Sound/inside.ogg")
var outside_stream:  AudioStream = preload("res://Assets/Sound/outside.ogg")

const FADE_SPEED: float = 60

const AMBIENT_TRACKS = [Track.RAIN, Track.INSIDE, Track.OUTSIDE]


var _players: Dictionary = {}
var _targets: Dictionary = {}

func _ready() -> void:
	_players[Track.THUNDER]  = _create_player(thunder_stream)
	_players[Track.THUNDER2] = _create_player(thunder2_stream)
	_players[Track.RAIN]     = _create_player(rain_stream,    true)
	_players[Track.INSIDE]   = _create_player(inside_stream,  true)
	_players[Track.OUTSIDE]  = _create_player(outside_stream, true)

	# Initialise all targets to silent
	for track in _players:
		_targets[track] = -80.0


func _process(delta: float) -> void:
	for track in AMBIENT_TRACKS:  # ← was "for track in _players"
		var p: AudioStreamPlayer = _players[track]
		var target: float = _targets[track]
		if not p.playing and target > -80.0:
			p.volume_db = -80.0
			p.play()
		p.volume_db = move_toward(p.volume_db, target, delta * FADE_SPEED)
		if p.playing and target <= -80.0 and p.volume_db <= -79.0:
			p.stop()


func _create_player(stream: AudioStream, looping: bool = false) -> AudioStreamPlayer:
	if looping:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamMP3:
			stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -80.0
	p.bus = "Sound"
	add_child(p)
	return p


# ── PUBLIC API ───────────────────────────────────────────────────────────────

# Set the volume a looping ambient track should converge toward
func set_target(track: Track, db: float) -> void:
	_targets[track] = db


# One-shot playback with randomisation for thunder variants
func play(track: Track, target_db: float = 0.0) -> void:
	var p: AudioStreamPlayer
	if track == Track.THUNDER:
		p = _players[[Track.THUNDER, Track.THUNDER2].pick_random()]
		p.pitch_scale = randf_range(0.8, 1.2)
		p.volume_db   = target_db + randf_range(0.0, 3.0)
	else:
		p = _players[track]
		p.volume_db = target_db
	p.play()
