extends Node3D

@onready var twin_1 = $"../Twin1"   # Wazza
@onready var twin_2 = $"../Twin2"   # Bazza
@onready var player = $"../Player"

@onready var bedroom             = $Locations/Bedroom
@onready var container           = $Locations/Container
@onready var store_room          = $Locations/StoreRoom
@onready var bridge              = $Locations/Bridge
@onready var lifeboat            = $Locations/Lifeboat

@onready var environment = $"../Lighting/WorldEnvironment"
@onready var lighting = $"../Lighting/DirectionalLight3D"
@onready var ocean = $"../ocean_mesh"
@onready var audio_manager = $"../AudioManager"
@onready var rain = $"../Player/Rain"

# environment -> sky -> sky_material -> shader -> shader_parameter -> time_of_day
const DAY_TIME_OF_DAY = 0.5
const NIGHT_TIME_OF_DAY = 0
const SUNSET_TIME_OF_DAY = 0.3

# lighting -> light -> light_color
const DAY_LIGHT_COLOR = Color(1, 1 ,1)
const NIGHT_LIGHT_COLOR = Color(1, 1 ,1)
const SUNSET_LIGHT_COLOR = Color(0.67, 0.31, 0.26)

# lighting -> light -> light_energy
const DAY_LIGHT_ENERGY = 1
const NIGHT_LIGHT_ENERGY = 0.02
const SUNSET_LIGHT_ENERGY = 0.8

# environment -> fog -> fog_light_color
const DAY_FOG_COLOR = Color(0.58, 0.71, 0.84)
const NIGHT_FOG_COLOR = Color(0,0,0)
const SUNSET_FOG_COLOR = Color(0.67, 0.31, 0.26)

# environment -> volumetric fog -> volumetric_fog_density
const DAY_FOG_DENSITY = 0.01
const NIGHT_FOG_DENSITY = 0.02
const SUNSET_FOG_DENSITY = 0.0

# ocean -> geometry -> material override -> shader_parameter -> shallow_color
const DAY_SHALLOW_COLOR = Color(0.07, 0.19, 0.28)

# ocean -> geometry -> material override -> shader_parameter -> deep_color
const DAY_DEEP_COLOR = Color(0.35, 0.46, 0.58)

# ocean -> geometry -> material override -> shader_parameter -> horizon_color
const DAY_HORIZON_COLOR = Color(0.58, 0.71, 0.85)

const NIGHT_SHALLOW_COLOR = Color(0.14, 0.2, 0.38)
const NIGHT_DEEP_COLOR = Color(0.08, 0.13, 0.26)
const NIGHT_HORIZON_COLOR = Color(0.08, 0.12, 0.24)

const SUNSET_SHALLOW_COLOR = Color(0.07, 0.19, 0.28)
const SUNSET_DEEP_COLOR = Color(0.35, 0.46, 0.58)
const SUNSET_HORIZON_COLOR = Color(0.58, 0.71, 0.85)

@onready var objective_marker_prefab = "res://Prefabs/objective_marker_ui.tscn"

var current_objective = null
var story_increment   = 1
var _is_night = false

var player_has_interacted_with_container = false

# ── DIALOGUE ────────────────────────────────────────────────────────────────

var dialogue = {

}

# ── LIFECYCLE ───────────────────────────────────────────────────────────────

func _ready() -> void:
	player.toggle_movement_disabled()
	set_time_of_day(TimeOfDay.DAY, 0.1)

@warning_ignore("shadowed_variable_base_class")
func _player_is_near(position: Vector3) -> bool:
	return (player.global_position - position).length() < 2

func _update_audio_and_rain() -> void:
	var inside = player.is_inside()
	audio_manager.set_target(audio_manager.Track.INSIDE,   -10.0   if inside                  else -40.0)
	audio_manager.set_target(audio_manager.Track.OUTSIDE,  -10.0   if not inside              else -40.0)
	audio_manager.set_target(audio_manager.Track.RAIN,     -10.0  if _is_night and not inside else -40.0)
	rain.visible = _is_night and not inside

func _process(_delta: float) -> void:
	
	_update_audio_and_rain()

	# ── ACT 1 ────────────────────────────────────────────────────────────────

	if story_increment == 1 and _player_is_near(container.global_position):
		story_increment += 1
		_play_act_1_start()
		
	if story_increment == 2 and player_has_interacted_with_container:
		story_increment += 1
		_play_act1_shift_over()

# ── ACT 1 SEQUENCES ─────────────────────────────────────────────────────────

func _play_act_1_start() -> void:
	player.fade_in_camera(10)
	await _wait_for(3)
	await twin_1.play_dialogue(1)
	await player.play_dialogue(2)
	await twin_2.play_dialogue(3)
	await player.play_dialogue(4)
	await twin_1.play_dialogue(5)
	await twin_2.play_dialogue(6)
	await player.play_dialogue(7)
	await twin_1.play_dialogue(8)
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
	_spawn_objective_marker(container)
	player.toggle_movement_disabled()
	await twin_1.play_dialogue(32)
	_play_container_reminders()
	
func _play_container_reminders() -> void:
	# Reminder 1 — gentle nudge (audio 33), after 30 s
	await _wait_for(30.0)
	if story_increment != 2:
		return
	await twin_1.play_dialogue(33)

	# Reminder 2 — more insistent (audio 34), after another 20 s
	await _wait_for(20.0)
	if story_increment != 2:
		return
	await twin_1.play_dialogue(34)

	# Reminder 3 — urgent (audio 35), after another 15 s
	while true:
		await _wait_for(15.0)
		if story_increment != 2:
			return
		await twin_1.play_dialogue(35)

func _play_act1_shift_over():
	await twin_1.play_dialogue(25)
	await player.play_dialogue(26)
	await twin_1.play_dialogue(27)
	twin_1.play_dialogue(28)
	await twin_2.play_dialogue(29)
	await twin_2.play_dialogue(30)
	await twin_1.play_dialogue(31)

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
		var wait_time = randf_range(0.0, 200)
		await _wait_for(wait_time)
		if _is_night:
			lightning_strike()
