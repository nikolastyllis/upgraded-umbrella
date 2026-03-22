extends Node3D

@onready var twin_1 = $"../Twin1"   # Wazza
@onready var twin_2 = $"../Twin2"   # Bazza
@onready var player = $"../Player"

@onready var bedroom          = $Locations/Bedroom
@onready var bedroom2         = $Locations/Bedroom2
@onready var bedroom3         = $Locations/Bedroom3
@onready var bed              = $Locations/Bed
@onready var container        = $Locations/Container
@onready var oxy_torch        = $"../OxyTorch"
@onready var store_room       = $Locations/StoreRoom
@onready var bridge           = $Locations/Bridge
@onready var lifeboat         = $Locations/Lifeboat
@onready var infected_spawn_1 = $Locations/InfectedSpawn1
@onready var infected_spawn_2 = $Locations/InfectedSpawn2

@onready var hide1 = $Locations/HideNpcs1
@onready var hide2 = $Locations/HideNpcs2

@onready var audio_manager = $"../AudioManager"
@onready var rain = $"../Player/Rain"
@onready var nav_region = $"../NavigationRegion3D"

# --- NEW: Sun-driven look (LookDriver reads this light direction) ---
@onready var sun_light: DirectionalLight3D = $"../Lighting/DirectionalLight3D"
@onready var world_environment: WorldEnvironment = $"../Lighting/WorldEnvironment"
@onready var look_driver = $"../Lighting/LookDriver"

@onready var objective_marker_prefab = "res://Prefabs/objective_marker_ui.tscn"

var current_objective = null
var story_increment   = 1

var _is_night = false
var _dialogue_active := false:
	set(value):
		_dialogue_active = value
		if value:
			audio_manager.fade_out_music()

var player_has_interacted_with_container = false
var player_has_slept = false
var player_has_returned_oxy_torch = false
var player_has_interacted_with_infected_container = false
var _oxy_return_obj_state := ""   # "storeroom" | "torch" | ""

var set_monster_pos_debug = false
var played_impact_lightning = false

# ── DIALOGUE ────────────────────────────────────────────────────────────────
var dialogue = {
	# (unchanged; fill as needed)
}

# ── LIFECYCLE ───────────────────────────────────────────────────────────────

func play_from_act_3():
	player_has_interacted_with_container = true
	player_has_returned_oxy_torch = true
	player_has_slept = true
	story_increment = 3

func _ready() -> void:
	# Start in DAY instantly (no tween)
	set_time_of_day(TimeOfDay.DAY, 0.0)
	_ambient_music_loop()

@warning_ignore("shadowed_variable_base_class")
func _player_is_near(position: Vector3, distance: float = 2.0) -> bool:
	return (player.global_position - position).length() < distance

@warning_ignore("shadowed_variable_base_class")
func _npcs_are_near(position: Vector3) -> bool:
	return (twin_1.global_position - position).length() < 5 and (twin_2.global_position - position).length() < 5

func rebake():
	nav_region.bake_navigation_mesh()

func _update_audio_and_rain() -> void:
	var inside = player.is_inside()
	audio_manager.set_target(audio_manager.Track.INSIDE,   -10.0  if inside                  else -40.0)
	audio_manager.set_target(audio_manager.Track.OUTSIDE,  -10.0  if not inside              else -40.0)
	audio_manager.set_target(audio_manager.Track.RAIN,     -20.0  if _is_night and not inside else -40.0)
	rain.visible = _is_night and not inside

func _ambient_music_loop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while story_increment <= 5:
		var wait_time := rng.randf_range(100.0, 200.0)
		await _wait_for(wait_time)
		if story_increment > 5 or _dialogue_active:
			continue
		var track = audio_manager.Track.AMBIENT1 if rng.randi_range(0, 1) == 0 else audio_manager.Track.AMBIENT2
		audio_manager.play(track, -12.0)

func _process(_delta: float) -> void:
	_update_audio_and_rain()

	# ── ACT 1 ────────────────────────────────────────────────────────────────

	if story_increment == 1 and _player_is_near(container.global_position):
		story_increment += 1
		_play_act_1_start()

	if story_increment == 2 and player.has_oxy_torch:
		story_increment += 0.5
		_remove_objective()
		_spawn_objective_marker(container)

	if story_increment == 2.5 and player_has_interacted_with_container:
		story_increment += 0.5
		_remove_objective()
		_play_act1_shift_over()

	if story_increment == 3 and not player_has_returned_oxy_torch:
		_update_oxy_torch_return_objective()
		var torch_near_store = (oxy_torch.global_position - store_room.global_position).length() < 3.0
		if _player_is_near(store_room.global_position, 3.0) and not player.has_oxy_torch and torch_near_store:
			player_has_returned_oxy_torch = true
			_oxy_return_obj_state = ""
			_remove_objective()
			_spawn_objective_marker(bed)

	if story_increment == 3 and player_has_returned_oxy_torch and player_has_slept:
		player.fade_in_camera(5)
		twin_1.global_position = bedroom.global_position
		twin_2.global_position = bedroom2.global_position
		player.global_position = bedroom3.global_position
		story_increment += 1
		_remove_objective()
		_play_act3_wake_up()

	if story_increment == 4 and _player_is_near(store_room.global_position):
		story_increment += 1
		twin_1.global_position = hide1.global_position
		twin_2.global_position = hide2.global_position
		twin_1.set_target_position(Vector3.ZERO)
		twin_2.set_target_position(Vector3.ZERO)
		_remove_objective()
		set_time_of_day(TimeOfDay.SUNSET, 120.0)
		_play_act_2_store_room()

	if story_increment == 5 and _player_is_near(container.global_position):
		story_increment += 1
		_remove_objective()
		set_time_of_day(TimeOfDay.NIGHT, 120.0)
		_play_act_3_container()

	if story_increment == 6 and _player_is_near(lifeboat.global_position):
		story_increment += 1
		_remove_objective()
		_play_act_4_search()

	if player_has_interacted_with_infected_container and not set_monster_pos_debug:
		twin_1.global_position = player.global_position
		twin_2.global_position = player.global_position
		set_monster_pos_debug = true

	if story_increment == 7 and player_has_interacted_with_infected_container:
		if not played_impact_lightning:
			played_impact_lightning = true
			lightning_strike()
			story_increment += 1

	if story_increment == 8:
		twin_1.set_target_position(player.global_position)
		twin_2.set_target_position(player.global_position)

# ── ACT 1 SEQUENCES ─────────────────────────────────────────────────────────

func _update_oxy_torch_return_objective() -> void:
	if player_has_returned_oxy_torch or _dialogue_active:
		return
	var new_state := "storeroom" if player.has_oxy_torch else "torch"
	if new_state == _oxy_return_obj_state:
		return               # nothing changed, don't thrash the marker
	_oxy_return_obj_state = new_state
	_remove_objective()
	if new_state == "storeroom":
		_spawn_objective_marker(store_room)
	else:
		_spawn_objective_marker(oxy_torch)

func _play_act_1_start() -> void:
	player.toggle_movement_disabled()
	_dialogue_active = true
	player.fade_in_camera(10)
	await _wait_for(10)
	await twin_1.play_dialogue(1)
	await player.play_dialogue(2)
	await twin_2.play_dialogue(3)
	await player.play_dialogue(4)
	await twin_1.play_dialogue(5)
	await twin_2.play_dialogue(6)
	await player.play_dialogue(7)
	await twin_2.play_dialogue(8)
	twin_1.play_dialogue(9)
	await twin_2.play_dialogue(10)
	await player.play_dialogue(11)
	await twin_1.play_dialogue(12)
	twin_1.play_dialogue(13)
	await twin_2.play_dialogue(14)
	await player.play_dialogue(15)
	await twin_1.play_dialogue(16)
	await twin_1.play_dialogue(17)
	await _wait_for(1.0)
	await twin_1.play_dialogue(18)
	twin_1.play_dialogue(19)
	await twin_2.play_dialogue(20)
	await twin_2.play_dialogue(21)
	await twin_2.play_dialogue(22)
	await _wait_for(2.0)
	await twin_2.play_dialogue(23)
	await twin_1.play_dialogue(24)
	_spawn_objective_marker(oxy_torch)
	player.toggle_movement_disabled()
	await twin_1.play_dialogue(32)
	_play_container_reminders()
	_dialogue_active = false

func _play_act1_shift_over():
	_dialogue_active = true
	await _wait_for(3.0)
	await _play_sound("bell")
	player.toggle_movement_disabled()
	await twin_2.play_dialogue(25)
	await twin_1.play_dialogue(266)
	await player.play_dialogue(26)
	await twin_1.play_dialogue(27)
	twin_1.play_dialogue(28)
	await twin_2.play_dialogue(29)
	await twin_2.play_dialogue(30)
	await twin_1.play_dialogue(31)
	twin_2.set_target_position(bedroom.global_position)
	await _wait_for(3.0)
	twin_1.set_target_position(bedroom.global_position)
	_update_oxy_torch_return_objective()
	player.toggle_movement_disabled()
	_dialogue_active = false

func _play_act3_wake_up():
	_dialogue_active = true
	await _wait_for(2)
	twin_1.set_target_position(player.global_position)
	twin_2.set_target_position(player.global_position)
	player.toggle_movement_disabled()
	await _play_sound("bell")
	await twin_1.play_dialogue(36)
	await player.play_dialogue(37)
	await twin_2.play_dialogue(38)
	await twin_2.play_dialogue(60)
	await twin_1.play_dialogue(61)
	await twin_2.play_dialogue(62)
	await twin_1.play_dialogue(63)
	await twin_1.play_dialogue(64)
	await twin_2.play_dialogue(39)
	twin_1.set_target_position(container.global_position)
	twin_2.set_target_position(container.global_position)
	player.toggle_movement_disabled()
	_spawn_objective_marker(store_room)
	_play_store_room_reminders()
	_dialogue_active = false

func _play_act_2_store_room():
	_dialogue_active = true
	await _wait_for(2.0)
	await twin_1.play_dialogue(41)
	await player.play_dialogue(42)
	await twin_2.play_dialogue(433)
	await twin_1.play_dialogue(43)
	await twin_1.play_dialogue(44)
	await _wait_for(3.0)
	await twin_2.play_dialogue(45)
	_spawn_objective_marker(container)
	_play_back_to_container_reminders()
	_dialogue_active = false

func _play_act_3_container():
	_dialogue_active = true
	await _wait_for(10.0)
	await player.play_dialogue(70)
	await _wait_for(10.0)
	await player.play_dialogue(71)
	await _wait_for(10.0)
	await player.play_dialogue(72)
	await _wait_for(10.0)
	await player.play_dialogue(73)
	await _wait_for(10.0)
	await twin_1.play_dialogue(79)
	await _wait_for(2.0)
	await player.play_dialogue(74)
	await _wait_for(1.0)
	await player.play_dialogue(75)
	await _wait_for(5.0)
	await twin_1.play_dialogue(76)
	await player.play_dialogue(77)
	await twin_1.play_dialogue(78)
	_spawn_objective_marker(lifeboat)
	_play_lifeboat_reminders()
	_dialogue_active = false

func _play_act_4_search():
	await _wait_for(5.0)
	await player.play_dialogue(74)
	_play_search_noises()

func _play_search_noises() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	while true:
		if story_increment != 7:
			return
		var wait_time = rng.randf_range(1.0, 60.0)
		await _wait_for(wait_time)
		var dialogue_id = rng.randi_range(80, 91)
		var speaker = twin_1 if rng.randi_range(0, 1) == 0 else twin_2
		await speaker.play_dialogue(dialogue_id)

func _play_store_room_reminders() -> void:
	while true:
		await _wait_for(35.0)
		if story_increment != 4:
			return
		await twin_1.play_dialogue(65)

		await _wait_for(20.0)
		if story_increment != 4:
			return
		await twin_1.play_dialogue(46)

		await _wait_for(20.0)
		if story_increment != 4:
			return
		await twin_2.play_dialogue(47)

		await _wait_for(20.0)
		if story_increment != 4:
			return
		await twin_1.play_dialogue(48)

		await _wait_for(20.0)
		if story_increment != 4:
			return
		await twin_2.play_dialogue(49)

		await _wait_for(20.0)
		if story_increment != 4:
			return
		await twin_2.play_dialogue(50)

		await _wait_for(20.0)
		if story_increment != 4:
			return
		await twin_1.play_dialogue(66)

		await _wait_for(20.0)
		if story_increment != 4:
			return
		await twin_2.play_dialogue(67)

func _play_lifeboat_reminders() -> void:
	while true:
		await _wait_for(30.0)
		if story_increment != 6:
			return
		await twin_1.play_dialogue(92)

		await _wait_for(20.0)
		if story_increment != 6:
			return
		await twin_1.play_dialogue(93)

func _play_back_to_container_reminders() -> void:
	while true:
		await _wait_for(20.0)
		if story_increment != 5 or _player_is_near(container.global_position, 20):
			return
		await twin_1.play_dialogue(55)

		await _wait_for(20.0)
		if story_increment != 5 or _player_is_near(container.global_position, 20):
			return
		await twin_1.play_dialogue(57)

		await _wait_for(20.0)
		if story_increment != 5 or _player_is_near(container.global_position, 20):
			return
		await twin_1.play_dialogue(58)

		await _wait_for(20.0)
		if story_increment != 5 or _player_is_near(container.global_position, 20):
			return
		await twin_1.play_dialogue(59)

		await _wait_for(20.0)
		if story_increment != 5 or _player_is_near(container.global_position, 20):
			return
		await twin_2.play_dialogue(51)

		await _wait_for(20.0)
		if story_increment != 5 or _player_is_near(container.global_position, 20):
			return
		await twin_1.play_dialogue(53)

		await _wait_for(20.0)
		if story_increment != 5 or _player_is_near(container.global_position, 20):
			return
		await twin_2.play_dialogue(52)

func _play_container_reminders() -> void:
	await _wait_for(30.0)
	if story_increment > 2.5:
		return
	await twin_1.play_dialogue(33)

	await _wait_for(20.0)
	if story_increment > 2.5:
		return
	await twin_1.play_dialogue(34)

	while true:
		await _wait_for(15.0)
		if story_increment > 2.5:
			return
		await twin_1.play_dialogue(35)

# ── HELPERS ─────────────────────────────────────────────────────────────────

func _teleport_player(location: Node3D) -> void:
	player.global_position = location.global_position

func _spawn_objective_marker(parent: Node3D) -> void:
	var packed = load(objective_marker_prefab)
	var marker = packed.instantiate()
	parent.add_child(marker)
	current_objective = marker

func _remove_objective() -> void:
	if current_objective:
		current_objective.queue_free()
	current_objective = null

func _wait_for(time: float):
	return get_tree().create_timer(time).timeout

# ── TIME OF DAY (Sun rotation only) ─────────────────────────────────────────

enum TimeOfDay { DAY, NIGHT, SUNSET }

@export_group("Sun Angles (Degrees)")
@export var DAY_SUN_PITCH_DEG: float = -85.0
@export var DAY_SUN_YAW_DEG: float = -125.0

@export var SUNSET_SUN_PITCH_DEG: float = 1.0
@export var SUNSET_SUN_YAW_DEG: float = -135.0

@export var NIGHT_SUN_PITCH_DEG: float = 115.7
@export var NIGHT_SUN_YAW_DEG: float = -125.0

var _sun_tween: Tween

func set_time_of_day(time: TimeOfDay, duration: float = 180.0) -> void:
	# Stop “night mode” as soon as we leave night
	if time != TimeOfDay.NIGHT:
		_is_night = false

	if sun_light == null:
		push_warning("GameManager: sun_light missing at ../Lighting/DirectionalLight3D")
		return

	# Kill existing tween
	if _sun_tween and _sun_tween.is_running():
		_sun_tween.kill()

	var target_rot := _get_sun_rotation(time)

	# Instant set
	if duration <= 0.0:
		sun_light.rotation = target_rot
		if time == TimeOfDay.NIGHT:
			_start_night_lightning()
		return

	_sun_tween = create_tween()
	_sun_tween.set_trans(Tween.TRANS_SINE)
	_sun_tween.set_ease(Tween.EASE_IN_OUT)
	_sun_tween.tween_property(sun_light, "rotation", target_rot, duration)

	_sun_tween.tween_callback(func():
		if time == TimeOfDay.NIGHT:
			_start_night_lightning()
	)

func _get_sun_rotation(time: TimeOfDay) -> Vector3:
	match time:
		TimeOfDay.DAY:
			return Vector3(deg_to_rad(DAY_SUN_PITCH_DEG), deg_to_rad(DAY_SUN_YAW_DEG), 0.0)
		TimeOfDay.SUNSET:
			return Vector3(deg_to_rad(SUNSET_SUN_PITCH_DEG), deg_to_rad(SUNSET_SUN_YAW_DEG), 0.0)
		TimeOfDay.NIGHT:
			return Vector3(deg_to_rad(NIGHT_SUN_PITCH_DEG), deg_to_rad(NIGHT_SUN_YAW_DEG), 0.0)
	return Vector3(deg_to_rad(DAY_SUN_PITCH_DEG), deg_to_rad(DAY_SUN_YAW_DEG), 0.0)

# ── LIGHTNING ───────────────────────────────────────────────────────────────

func lightning_strike() -> void:
	if sun_light == null or world_environment == null or world_environment.environment == null:
		return

	var original_color: Color = sun_light.light_color
	var original_energy: float = sun_light.light_energy
	var original_fog: Color = world_environment.environment.fog_light_color
	var original_rotation: Vector3 = sun_light.rotation
	var t := 0.0

	# Flash up
	while t < 1.0:
		t += get_process_delta_time() * 20.0
		sun_light.light_color = original_color.lerp(Color.WHITE, t)
		sun_light.light_energy = lerp(original_energy, 5.0, t)
		world_environment.environment.fog_light_color = original_fog.lerp(Color(0.8, 0.8, 1.0), t)
		await get_tree().process_frame

	# Snap straight down at peak
	sun_light.rotation = Vector3(-PI / 2, 0, 0)

	# Quick flicker before fading
	await _wait_for(0.04)
	sun_light.light_energy = original_energy
	await get_tree().process_frame
	await _wait_for(0.03)
	sun_light.light_energy = 4.0
	await get_tree().process_frame

	# Restore rotation before fading out
	sun_light.rotation = original_rotation

	# Flash down
	t = 1.0
	while t > 0.0:
		t -= get_process_delta_time() * 8.0
		sun_light.light_color = original_color.lerp(Color.WHITE, t)
		sun_light.light_energy = lerp(original_energy, 5.0, t)
		world_environment.environment.fog_light_color = original_fog.lerp(Color(0.8, 0.8, 1.0), t)
		await get_tree().process_frame

	sun_light.light_color = original_color
	sun_light.light_energy = original_energy
	world_environment.environment.fog_light_color = original_fog
	sun_light.rotation = original_rotation

	await _wait_for(1.0)
	audio_manager.play(audio_manager.Track.THUNDER, -15.0 if player.is_inside() else 6.0)

func _start_night_lightning() -> void:
	_is_night = true
	while _is_night:
		var wait_time = randf_range(0.0, 100.0)
		await _wait_for(wait_time)
		if _is_night:
			lightning_strike()

# ── AUDIO HELPERS ───────────────────────────────────────────────────────────

func _play_sound(sound: String) -> void:
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
