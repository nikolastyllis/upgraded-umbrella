extends Node3D

@onready var twin_1 = $"../Twin1"   # Wazza
@onready var twin_2 = $"../Twin2"   # Bazza
@onready var player = $"../Player"

@onready var bedroom             = $Locations/Bedroom
@onready var bedroom2            = $Locations/Bedroom2
@onready var bedroom3           = $Locations/Bedroom3
@onready var bed             	 = $Locations/Bed
@onready var container           = $Locations/Container
@onready var oxy_torch           = $"../OxyTorch"
@onready var store_room          = $Locations/StoreRoom
@onready var bridge              = $Locations/Bridge
@onready var lifeboat            = $Locations/Lifeboat
@onready var infected_spawn_1     = $Locations/InfectedSpawn1
@onready var infected_spawn_2     = $Locations/InfectedSpawn2

@onready var hide1            = $Locations/HideNpcs1
@onready var hide2           = $Locations/HideNpcs2

@onready var environment = $"../Lighting/WorldEnvironment"
@onready var lighting = $"../Lighting/DirectionalLight3D"
@onready var ocean = $"../ocean_mesh"
@onready var audio_manager = $"../AudioManager"
@onready var rain = $"../Player/Rain"

@onready var nav_region = $"../NavigationRegion3D"

# environment -> sky -> sky_material -> shader -> shader_parameter -> time_of_day
@export var DAY_TIME_OF_DAY = 0.5
@export var NIGHT_TIME_OF_DAY = 0
@export var SUNSET_TIME_OF_DAY = 0.25

# lighting -> light -> light_color
@export var DAY_LIGHT_COLOR = Color(1, 1 ,1)
@export var NIGHT_LIGHT_COLOR = Color(1, 1 ,1)
@export var SUNSET_LIGHT_COLOR = Color(0.67, 0.31, 0.26)

# lighting -> light -> light_energy
@export var DAY_LIGHT_ENERGY = 1
@export var NIGHT_LIGHT_ENERGY = 0.02
@export var SUNSET_LIGHT_ENERGY = 0.8

# environment -> fog -> fog_light_color
@export var DAY_FOG_COLOR = Color(0.58, 0.71, 0.84)
@export var NIGHT_FOG_COLOR = Color(0,0,0)
@export var SUNSET_FOG_COLOR = Color(0.67, 0.31, 0.26)

# environment -> volumetric fog -> volumetric_fog_density
@export var DAY_FOG_DENSITY = 0.0
@export var NIGHT_FOG_DENSITY = 0.02
@export var SUNSET_FOG_DENSITY = 0.02

# ocean -> geometry -> material override -> shader_parameter -> shallow_color
@export var DAY_SHALLOW_COLOR = Color(0.07, 0.19, 0.28)

# ocean -> geometry -> material override -> shader_parameter -> deep_color
@export var DAY_DEEP_COLOR = Color(0.35, 0.46, 0.58)

# ocean -> geometry -> material override -> shader_parameter -> horizon_color
@export var DAY_HORIZON_COLOR = Color(0.58, 0.71, 0.85)

@export var NIGHT_SHALLOW_COLOR = Color(0.14, 0.2, 0.38)
@export var NIGHT_DEEP_COLOR = Color(0.08, 0.13, 0.26)
@export var NIGHT_HORIZON_COLOR = Color(0.08, 0.12, 0.24)

@export var SUNSET_SHALLOW_COLOR = Color(0.07, 0.19, 0.28)
@export var SUNSET_DEEP_COLOR = Color(0.35, 0.46, 0.58)
@export var SUNSET_HORIZON_COLOR = Color(0.58, 0.71, 0.85)

@onready var objective_marker_prefab = "res://Prefabs/objective_marker_ui.tscn"

var current_objective = null
var story_increment   = 1
var _is_night = false
var _dialogue_active := false:
	set(value):              # runs every time you do _dialogue_active = something
		_dialogue_active = value             # actually store the new value
		if value:                            # if it was set to true...
			audio_manager.fade_out_music()   # ...fade the music out immediately

var player_has_interacted_with_container = false
var player_has_slept = false
var player_has_interacted_with_infected_container = false
var set_monster_pos_debug = false
var played_impact_lightning = false

# ── DIALOGUE ────────────────────────────────────────────────────────────────

var dialogue = {

}

# ── LIFECYCLE ───────────────────────────────────────────────────────────────

func play_from_act_3():
	player_has_interacted_with_container = true
	player_has_slept = true
	story_increment = 3

func _ready() -> void:
	set_time_of_day(TimeOfDay.DAY, 0.1)
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
	audio_manager.set_target(audio_manager.Track.INSIDE,   -10.0   if inside                  else -40.0)
	audio_manager.set_target(audio_manager.Track.OUTSIDE,  -10.0   if not inside              else -40.0)
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
		var track = audio_manager.Track.AMBIENT1 if rng.randi_range(0, 1) == 0 \
				else audio_manager.Track.AMBIENT2
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
		
	if story_increment == 3 and player_has_slept:
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
		set_time_of_day(TimeOfDay.SUNSET, 120)
		_play_act_2_store_room()
		
	if story_increment == 5 and _player_is_near(container.global_position):
		story_increment += 1
		_remove_objective()
		set_time_of_day(TimeOfDay.NIGHT, 120)
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
	await _wait_for(3.0)
	await twin_1.play_dialogue(18)
	twin_1.play_dialogue(19)
	await twin_2.play_dialogue(20)
	await twin_2.play_dialogue(21)
	await twin_2.play_dialogue(22)
	await _wait_for(3.0)
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
	_spawn_objective_marker(bed)
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
	await twin_1.play_dialogue(43)
	await twin_2.play_dialogue(433)
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
	# Reminder 1 — gentle nudge (audio 33), after 30 s
	await _wait_for(30.0)
	if story_increment > 2.5:
		return
	await twin_1.play_dialogue(33)

	# Reminder 2 — more insistent (audio 34), after another 20 s
	await _wait_for(20.0)
	if story_increment > 2.5:
		return
	await twin_1.play_dialogue(34)

	# Reminder 3 — urgent (audio 35), after another 15 s
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
	
enum TimeOfDay { DAY, NIGHT, SUNSET }

# ── TIME OF DAY ──────────────────────────────────────────────────────────────

const TRANSITION_DURATION := 180.0   # seconds — adjust to taste

var _time_transition_active := false

func set_time_of_day(time: TimeOfDay, duration: float = TRANSITION_DURATION) -> void:
	_is_night = false
	var target := _get_time_of_day_params(time)
	_transition_environment(target, duration, time)


func _get_time_of_day_params(time: TimeOfDay) -> Dictionary:
	match time:
		TimeOfDay.DAY:
			return {
				"time_of_day":   DAY_TIME_OF_DAY,
				"light_color":   DAY_LIGHT_COLOR,
				"light_energy":  DAY_LIGHT_ENERGY,
				"fog_color":     DAY_FOG_COLOR,
				"volumetric_fog_density": DAY_FOG_DENSITY,
				"volumetric_fog_albedo":      DAY_LIGHT_COLOR,
				"shallow_color": DAY_SHALLOW_COLOR,
				"deep_color":    DAY_DEEP_COLOR,
				"horizon_color": DAY_HORIZON_COLOR,
			}
		TimeOfDay.NIGHT:
			return {
				"time_of_day":   NIGHT_TIME_OF_DAY,
				"light_color":   NIGHT_LIGHT_COLOR,
				"light_energy":  NIGHT_LIGHT_ENERGY,
				"fog_color":     NIGHT_FOG_COLOR,
				"volumetric_fog_density": NIGHT_FOG_DENSITY,
				"volumetric_fog_albedo":      NIGHT_LIGHT_COLOR,
				"shallow_color": NIGHT_SHALLOW_COLOR,
				"deep_color":    NIGHT_DEEP_COLOR,
				"horizon_color": NIGHT_HORIZON_COLOR,
			}
		TimeOfDay.SUNSET:
			return {
				"time_of_day":   SUNSET_TIME_OF_DAY,
				"light_color":   SUNSET_LIGHT_COLOR,
				"light_energy":  SUNSET_LIGHT_ENERGY,
				"fog_color":     SUNSET_FOG_COLOR,
				"volumetric_fog_density": SUNSET_FOG_DENSITY,
				"volumetric_fog_albedo":      SUNSET_LIGHT_COLOR,
				"shallow_color": SUNSET_SHALLOW_COLOR,
				"deep_color":    SUNSET_DEEP_COLOR,
				"horizon_color": SUNSET_HORIZON_COLOR,
			}
	return {}


func _transition_environment(target: Dictionary, duration: float, time: TimeOfDay) -> void:
	# Cancel any running transition before starting a new one
	_time_transition_active = false
	await get_tree().process_frame

	_time_transition_active = true

	var sky_material   = environment.environment.sky.sky_material
	var ocean_material = ocean.get_active_material(0)

	# Snapshot current values as the lerp origin
	var from := {
		"time_of_day":   sky_material.get_shader_parameter("time_of_day"),
		"light_color":   lighting.light_color,
		"light_energy":  lighting.light_energy,
		"fog_color":     environment.environment.fog_light_color,
		"volumetric_fog_density":     environment.environment.volumetric_fog_density,
		"volumetric_fog_albedo":      environment.environment.volumetric_fog_albedo,
		"shallow_color": ocean_material.get_shader_parameter("shallow_color"),
		"deep_color":    ocean_material.get_shader_parameter("deep_color"),
		"horizon_color": ocean_material.get_shader_parameter("horizon_color"),
	}

	var elapsed := 0.0

	while elapsed < duration and _time_transition_active:
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / duration, 0.0, 1.0)

		sky_material.set_shader_parameter("time_of_day",
				lerpf(from["time_of_day"], target["time_of_day"], t))
		lighting.light_color   = (from["light_color"]  as Color).lerp(target["light_color"],   t)
		lighting.light_energy  = lerpf(from["light_energy"], target["light_energy"], t)
		environment.environment.fog_light_color = \
				(from["fog_color"] as Color).lerp(target["fog_color"], t)
		environment.environment.volumetric_fog_albedo = \
				(from["light_color"] as Color).lerp(target["light_color"], t)
		environment.environment.volumetric_fog_density = lerpf(from["volumetric_fog_density"], target["volumetric_fog_density"], t)
		ocean_material.set_shader_parameter("shallow_color",
				(from["shallow_color"] as Color).lerp(target["shallow_color"], t))
		ocean_material.set_shader_parameter("deep_color",
				(from["deep_color"]   as Color).lerp(target["deep_color"],    t))
		ocean_material.set_shader_parameter("horizon_color",
				(from["horizon_color"] as Color).lerp(target["horizon_color"], t))

		await get_tree().process_frame

	# Snap to exact target values once complete (avoids floating-point drift)
	if _time_transition_active:
		sky_material.set_shader_parameter("time_of_day", target["time_of_day"])
		lighting.light_color   = target["light_color"]
		lighting.light_energy  = target["light_energy"]
		environment.environment.fog_light_color = target["fog_color"]
		environment.environment.volumetric_fog_density = target["volumetric_fog_density"]
		environment.environment.volumetric_fog_albedo = target["light_color"]
		ocean_material.set_shader_parameter("shallow_color", target["shallow_color"])
		ocean_material.set_shader_parameter("deep_color",    target["deep_color"])
		ocean_material.set_shader_parameter("horizon_color", target["horizon_color"])
	
	if _time_transition_active and time == TimeOfDay.NIGHT:
		_start_night_lightning()
		
	_time_transition_active = false
	
func lightning_strike() -> void:
	var original_color = lighting.light_color
	var original_energy = lighting.light_energy
	var original_fog = environment.environment.fog_light_color
	var original_rotation = lighting.rotation
	var t := 0.0

	# Flash up
	while t < 1.0:
		t += get_process_delta_time() * 20.0
		lighting.light_color = original_color.lerp(Color.WHITE, t)
		lighting.light_energy = lerp(original_energy, 5.0, t)
		environment.environment.fog_light_color = original_fog.lerp(Color(0.8, 0.8, 1.0), t)
		await get_tree().process_frame

	# Snap straight down at peak
	lighting.rotation = Vector3(-PI / 2, 0, 0)

	# Quick flicker before fading
	await _wait_for(0.04)
	lighting.light_energy = original_energy
	await get_tree().process_frame
	await _wait_for(0.03)
	lighting.light_energy = 4.0
	await get_tree().process_frame

	# Restore rotation before fading out
	lighting.rotation = original_rotation

	# Flash down
	t = 1.0
	while t > 0.0:
		t -= get_process_delta_time() * 8.0
		lighting.light_color = original_color.lerp(Color.WHITE, t)
		lighting.light_energy = lerp(original_energy, 5.0, t)
		environment.environment.fog_light_color = original_fog.lerp(Color(0.8, 0.8, 1.0), t)
		await get_tree().process_frame

	lighting.light_color = original_color
	lighting.light_energy = original_energy
	environment.environment.fog_light_color = original_fog
	lighting.rotation = original_rotation
	
	await _wait_for(1.0)
	audio_manager.play(audio_manager.Track.THUNDER, -15.0 if player.is_inside() else 6.0)
	
func _start_night_lightning() -> void:
	_is_night = true
	while _is_night:
		var wait_time = randf_range(0.0, 100)
		await _wait_for(wait_time)
		if _is_night:
			lightning_strike()

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
