extends Node3D

var dialog: Dictionary = {
	1: "[Ronnie] Here you go, first attempt. Try not to retire on this one cut, will ya.",
	2: "[Gilbert] I'm doing it how you showed me!",
	3: "[Wazza] Haha! Was that a teste pop?",
	4: "[Gilbert] Not it... no it wasn't!",
	5: "[Ronnie] It was.",
	6: "[Wazza] Heh, where's snap and crackle?",
	7: "[Gilbert] Huh?",
	8: "[Wazza] Like Rice Bubbles, snap, crackle, pop.",
	9: "[Ronnie] Hahahaha.",
	10: "[Wazza] Hahahaa.",
	11: "[Gilbert] Shut up!",
	12: "[Ronnie] Oh well, there's snap.",
	13: "[Ronnie] Hahahaha.",
	14: "[Wazza] Ahahaa.",
	16: "[Ronnie] Haha, don't get testy, Michael Jackson.",
	17: "[Ronnie] We didn't realise we were in the company of music royalty.",
	18: "[Ronnie] King of pop.",
	19: "[Ronnie] Hehaa.",
	20: "[Wazza] Ahahahaa.",
	21: "[Wazza] Alright, that's enough. It wasn't a real pop.",
	22: "[Wazza] Leave Quentin Tarantino alone.",
	23: "[Wazza] Pop Fiction! Hahaha.",
	24: "[Ronnie] Aahahaha... haha. Alright, cut it out, we have work to do.",
	25: "[Wazza] That bell signals tools down, mate. Put them down.",
	26: "[Gilbert] Are we seriously gonna finish now?",
	27: "[Ronnie] Listen, Rice Bubbles, you're new to this game and I don't know what they taught you at school. But here in the real world, we have a saying.",
	28: "[Ronnie] Why do today what you can do tomorrow!",
	29: "[Wazza] Why do today what you can do tomorrow!",
	30: "[Wazza] Go on, pick up the tools.",
	31: "[Ronnie] Go on, mate. These tools won't pick themselves up. Let's get out of here.",
	32: "[Ronnie] Pick up the oxy torch, mate. Pick up the oxy torch.",
	33: "[Ronnie] We've got to, uh, oxy the door, mate. Just what I said, oxy the door.",
	34: "[Ronnie] What did I just tell you, mate? Are your ears painted on? Oxy the door.",
	35: "[Ronnie] Oxy the door!",
	36: "[Ronnie] Alright, Bubbles, we're gonna head over and get this last container open from yesterday. Then we're gonna have a crack at fixing the power supply and getting that lifeboat working.",
	37: "[Gilbert] Okay sweet, I'll pick up the oxy cutter.",
	38: "[Wazza] Nah, mate, we got it. You head down to the storeroom and pick us up some of this important gear.",
	39: "[Wazza] We'll be on the radio. Give us a call if you get in any trouble.",
	40: "[Wazza] How you going, young fella? You must've found that long wait by now?",
	41: "[Ronnie] While you're faffing about down there, mate, you wanna pick us up a pie cost?",
	42: "[Gilbert] Uh, what's a pie cost?",
	43: "[Ronnie] Like you don't know, Tubby!",
	44: "[Ronnie] Ahahahahahaha.",
	45: "[Wazza] Alright, Einstein, stop f*****g around and get your ass back up here!",
	46: "[Ronnie] Hey, mate. You found that reach-around yet?",
	47: "[Wazza] Oh mate, you got that, uh, tub of elbow grease? That's pretty important too.",
	48: "[Ronnie] Oh mate, we really need those sparks for the grinder.",
	49: "[Wazza] Mate, I need those three boxes of sky hooks as soon as possible.",
	50: "[Wazza] What are you doing down there, mate? It's really important we get that reach-around soon.",
	51: "[Wazza] Mate, you know Ronnie is bloody stinging for a reach-around.",
	52: "[Wazza] It's not gonna grab itself. C'mon, hurry it up, mate.",
	53: "[Ronnie] Oh yeah, mate... the, uh... the old reach-around... it's important. You wanna go in there, get in there, two hands, mate. Come and grab it, c'mon, quick.",
	54: "[Ronnie] Come meet the boys.",
	55: "[Ronnie] Yeah, come meet us down here.",
	56: "[Ronnie] Meet the boys.",
	57: "[Ronnie] Bubbles, get the items and come meet us up here.",
	58: "[Wazza] Mate, Bubbles, get the bloody supplies and come meet us up near the door.",
	59: "[Wazza] Mate, it's not rocket surgery. Just get the items from the storeroom and bring them back up.",
	60: "[Wazza] Three boxes of sky hooks, mate.",
	61: "[Ronnie] Four tins of tartan paint.",
	62: "[Wazza] Two spirit level bubbles.",
	63: "[Ronnie] One box of sparks for the grinder.",
	64: "[Ronnie] One long wait.",
	65: "[Ronnie] Have you got the long wait yet, mate?",
	66: "[Ronnie] Big poppa, get the items and come up here, mate.",
	67: "[Wazza] Listen, MJ, get the stuff we need and moonwalk your way back up here.",
	68: "[Ronnie] Oh mate, these aren't real items, Einstein. Get your ass back up here.",
	69: "[Ronnie] Alright, Bubbles, found all your stuff? Nah, come round, mate, come back.",
	70: "[Gilbert] Oi, boys, where are you?",
	71: "[Gilbert] Guys?",
	72: "[Gilbert] Where are you guys?",
	73: "[Gilbert] Guys if this is a prank, you're not fooling anyone!",
	74: "[Gilbert] Hello?",
	75: "[Gilbert] Ronnie? Wazza?",
	76: "[Ronnie] At the lifeboat. Come help us out, my friend.",
	77: "[Gilbert] Uh, are you alright? You sound weird.",
	78: "[Ronnie] I'm fine.",
	778: "[Gilbert] To the life boat.",
	92: "[Ronnie] Meet us at the lifeboat.",
	93: "[Ronnie] Come and see us at the lifeboat.",
	266: "[Ronnie] Yeah, mate, end of the day. Put the tools down and let's get out of here.",
	433: "[Wazza] Around five-fifty at the servo.",
}

@onready var twin_1 = $"../Twin1"
@onready var twin_2 = $"../Twin2"
@onready var dead_twin_2 = $"../DeadTwin2"
@onready var player = $"../Player"
@onready var creature = $"../Creature"

@onready var bedroom          = $Locations/Bedroom
@onready var bedroom2         = $Locations/Bedroom2
@onready var bedroom3         = $Locations/Bedroom3
@onready var bed              = $Locations/Bed
@onready var container        = $Locations/Container
@onready var infected_container = $Locations/InfectedContainer
@onready var infected_spawn = $Locations/InfectedSpawn
@onready var oxy_torch        = $"../OxyTorch"
@onready var store_room       = $Locations/StoreRoom
@onready var lifeboat         = $Locations/Lifeboat
@onready var respawn         = $Locations/Respawn
@onready var lifeboat_anim_player = $"../NavigationRegion3D/Ship Enviroment/Ship Model/BIGJ_LifeBoat/AnimationPlayer"

@onready var hide1 = $Locations/HideNpcs1
@onready var hide2 = $Locations/HideNpcs2

@onready var audio_manager = $"../AudioManager"
@onready var rain = $"../Player/Rain"
@onready var nav_region = $"../NavigationRegion3D"

@onready var sun_light: DirectionalLight3D = $"../Lighting/DirectionalLight3D"
@onready var world_environment: WorldEnvironment = $"../Lighting/WorldEnvironment"
@onready var look_driver = $"../Lighting/LookDriver"

@onready var objective_marker_prefab = "res://Prefabs/objective_marker_ui.tscn"

var current_objective = null
var story_increment   = 1
var player_has_completed_game = false

@export var debug_skip_dialog = false

@export_group("Debug: Play From Act")
@export var debug_play_from_act_3 = false
@export var debug_play_from_act_4 = false
@export var debug_play_from_act_5 = false
@export var debug_play_from_act_6 = false
@export var debug_play_from_act_7 = true
@export var debug_play_from_act_8 = false

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
var _act_1_obj_state := ""   # "container" | "torch" | ""
var _fuel_obj_state := ""   # "lifeboat" | "search" | ""
var _act4_oxy_obj_state := ""   # "torch" | "infected" | ""

var set_monster_pos_debug = false
var played_impact_lightning = false

var shown_interact_control_tip = false
var shown_move_control_tip = false
var shown_camera_control_tip = false
var shown_jog_control_tip = false
var shown_jump_control_tip = false
var shown_drop_control_tip = false
var shown_torch_control_tip = false

var number_of_supplies = 0

func play_from_act_3():
	player_has_interacted_with_container = true
	player_has_returned_oxy_torch = true
	player_has_slept = true
	story_increment = 3

func play_from_act_4():
	play_from_act_3()
	story_increment = 4
	twin_1.global_position = hide1.global_position
	twin_2.global_position = hide2.global_position
	twin_1.set_target_position(Vector3.ZERO)
	twin_2.set_target_position(Vector3.ZERO)
	set_time_of_day(TimeOfDay.SUNSET, 0.0)

func play_from_act_5():
	play_from_act_4()
	story_increment = 5
	set_time_of_day(TimeOfDay.NIGHT, 0.0)

func play_from_act_6():
	play_from_act_5()
	story_increment = 6

func play_from_act_7():
	play_from_act_6()
	story_increment = 7
	
func restart_from_act_7() -> void:
	reset_monster_speed()
	player.global_position = respawn.global_position
	player.rotation = respawn.rotation
	creature.global_position = infected_spawn.global_position
	player.is_holding_jerry_can = false
	number_of_supplies = 0
	_remove_objective()
	player.set_objective_text("Search the containers for supplies to escape on the lifeboat (%s/5 Collected)" % number_of_supplies)
	if not player.has_oxy_torch:
		oxy_torch.on_interact(player)
	await player.fade_in_camera(1.5)
	player.is_dead = false
	creature.reset_state()

func reset_monster_speed():
	creature.monster_speed = 2.5 + (.15 * number_of_supplies)

func try_play_creak():
	audio_manager.try_play_creak()

func play_from_act_8():
	play_from_act_7()
	player_has_interacted_with_infected_container = true
	set_monster_pos_debug = true
	played_impact_lightning = true
	story_increment = 8

func _ready() -> void:
	add_to_group("game_manager")
	lifeboat.add_to_group("lifeboat")
	set_time_of_day(TimeOfDay.DAY, 0.0)
	_ambient_music_loop()

	if    debug_play_from_act_8: play_from_act_8()
	elif  debug_play_from_act_7: play_from_act_7()
	elif  debug_play_from_act_6: play_from_act_6()
	elif  debug_play_from_act_5: play_from_act_5()
	elif  debug_play_from_act_4: play_from_act_4()
	elif  debug_play_from_act_3: play_from_act_3()

@warning_ignore("shadowed_variable_base_class")
func _player_is_near(position: Vector3, distance: float = 1.5) -> bool:
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
	audio_manager.set_target(audio_manager.Track.RAIN,     -13.0  if _is_night and not inside else -40.0)
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

	if story_increment == 1 and _player_is_near(container.global_position):
		creature.global_position = hide1.global_position
		creature.set_target_position(Vector3.ZERO)
		player.toggle_movement_disabled()
		_play_act_1_start()
		story_increment += 1
		
	if story_increment <= 2.5:
		_update_act_1_objective()
		
	if story_increment == 2 and not player.has_oxy_torch and not shown_move_control_tip:
		show_control_hint("[WASD] Move", [&"left", &"right", &"up", &"down"], func(): shown_move_control_tip = true)
		
	if story_increment == 2 and not player.has_oxy_torch and not shown_camera_control_tip and shown_move_control_tip:
		show_control_hint("[V] Camera", [&"camera"], func(): shown_camera_control_tip = true)
	
	if story_increment == 2 and player.has_oxy_torch:
		story_increment += 0.5

	if story_increment == 2.5 and player_has_interacted_with_container:
		story_increment += 0.5
		_remove_objective()
		_play_act1_shift_over()
		
	if story_increment == 3 and not shown_jump_control_tip and shown_jog_control_tip:
		show_control_hint("[Space] Jump", [&"jump"],  func(): shown_jump_control_tip = true)
		
	if story_increment == 3 and not player_has_returned_oxy_torch and _player_is_near(store_room.global_position, 3.0) and player.has_oxy_torch and not shown_drop_control_tip:
		show_control_hint("[Q] Drop", [&"drop"], func(): shown_drop_control_tip = true)

	if story_increment == 3 and not player_has_returned_oxy_torch:
		_update_oxy_torch_return_objective()
		var torch_near_store = (oxy_torch.global_position - store_room.global_position).length() < 3.0
		if _player_is_near(store_room.global_position, 3.0) and not player.has_oxy_torch and torch_near_store:
			player_has_returned_oxy_torch = true
			_oxy_return_obj_state = ""
			_remove_objective()
			_spawn_objective_marker(bed, "Go to sleep")

	if story_increment == 3 and player_has_returned_oxy_torch and player_has_slept:
		player.fade_in_camera(5)
		twin_1.global_position = bedroom2.global_position
		twin_2.global_position = bedroom3.global_position
		player.global_position = bedroom.global_position
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
		dead_twin_2.visible = true
		
	if story_increment == 6 and not shown_torch_control_tip:
		show_control_hint("[F] Flashlight", [&"torch"], func(): shown_torch_control_tip = true)

	if story_increment == 6 and _player_is_near(lifeboat.global_position):
		story_increment += 1
		_remove_objective()
		_play_act_4_lifeboat()

	if player_has_interacted_with_infected_container and not set_monster_pos_debug:
		set_monster_pos_debug = true
		creature.global_position = infected_spawn.global_position
		
	if story_increment == 7 and not player_has_interacted_with_infected_container:
		_update_act4_oxy_objective()

	if story_increment == 7 and player_has_interacted_with_infected_container:
		if not played_impact_lightning:
			_remove_objective()
			played_impact_lightning = true
			audio_manager.play_boss_music()
			lightning_strike()
			player.toggle_movement_disabled()
			creature.roar()
			await _wait_for(6.0)
			player.toggle_movement_disabled()
			player.play_dialogue(97)
			story_increment += 1

	if story_increment == 8:
		_update_fuel_objective()

func _update_act_1_objective() -> void:
	if player_has_interacted_with_container or _dialogue_active:
		return
	var new_state := "container" if player.has_oxy_torch else "torch"
	if new_state == _act_1_obj_state:
		return
	_act_1_obj_state = new_state
	_remove_objective()
	if new_state == "container":
		_spawn_objective_marker(container, "Use the oxy–acetylene torch on the container door")
	else:
		_spawn_objective_marker(oxy_torch, "Pick up the oxy–acetylene torch")

func _update_oxy_torch_return_objective() -> void:
	if player_has_returned_oxy_torch or _dialogue_active:
		return
	var new_state := "storeroom" if player.has_oxy_torch else "torch"
	if new_state == _oxy_return_obj_state:
		return
	_oxy_return_obj_state = new_state
	_remove_objective()
	if new_state == "storeroom":
		_spawn_objective_marker(store_room, "Drop the oxy–acetylene torch in the store-room")
	else:
		_spawn_objective_marker(oxy_torch, "Pick up the oxy–acetylene torch")
		
func _update_act4_oxy_objective() -> void:
	if player_has_interacted_with_infected_container or _dialogue_active:
		return
	var new_state := "infected" if player.has_oxy_torch else "torch"
	if new_state == _act4_oxy_obj_state:
		return
	_act4_oxy_obj_state = new_state
	_remove_objective()
	if new_state == "infected":
		_spawn_objective_marker(infected_container, "Use the oxy–acetylene torch on the container door")
	else:
		_spawn_objective_marker(oxy_torch, "Pick up the oxy–acetylene torch")
		
func _update_fuel_objective() -> void:
	if player_has_completed_game:
		_remove_objective()
		return
	var new_state := "lifeboat" if player.is_holding_jerry_can else "search"
	if new_state == _fuel_obj_state:
		return               
	_fuel_obj_state = new_state
	_remove_objective()
	if new_state == "lifeboat":
		_spawn_objective_marker(lifeboat, "Drop supplies at the lifeboat (%s/5 Collected)" % number_of_supplies)
	else:
		player.set_objective_text("Search the containers for supplies to escape on the lifeboat (%s/5 Collected)" % number_of_supplies)
		_remove_objective()

func _play_act_1_start() -> void:
	_dialogue_active = true
	player.fade_in_camera(10)
	await _wait_for(5)
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
	player.toggle_movement_disabled()
	_spawn_objective_marker(oxy_torch, "Pick up the oxy–acetylene torch")
	await twin_1.play_dialogue(32)
	_play_container_reminders()
	_dialogue_active = false
	
func _play_act_4_lifeboat() -> void:
	player.toggle_movement_disabled()
	_dialogue_active = true
	await _play_sound("dead_wazza_reveal")
	await player.play_dialogue(102)
	await dead_twin_2.play_dialogue(62)
	await player.play_dialogue(103)
	await dead_twin_2.play_dialogue(62)
	await player.play_dialogue(104)
	await dead_twin_2.play_dialogue(62)
	await player.play_dialogue(105)
	await dead_twin_2.play_dialogue(62)
	await player.play_dialogue(106)
	await dead_twin_2.play_dialogue(62)
	await player.play_dialogue(107)
	await dead_twin_2.play_dialogue(62)
	player.toggle_movement_disabled()
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
	twin_2.set_target_position(bedroom3.global_position)
	twin_1.set_target_position(bedroom2.global_position)
	_update_oxy_torch_return_objective()
	player.toggle_movement_disabled()
	_dialogue_active = false
	show_control_hint("[Shift] Jog", [&"shift"], func(): shown_jog_control_tip = true)

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
	_spawn_objective_marker(store_room, "Go to the store-room")
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
	_spawn_objective_marker(container, "Meet the twins at the container")
	_play_back_to_container_reminders()
	_dialogue_active = false

func _play_act_3_container():
	_dialogue_active = true
	await _wait_for(5.0)
	await player.play_dialogue(70)
	await _wait_for(5.0)
	await player.play_dialogue(71)
	await _wait_for(5.0)
	await player.play_dialogue(72)
	await _wait_for(5.0)
	await player.play_dialogue(73)
	await _wait_for(5.0)
	await player.play_dialogue(74)
	await _wait_for(1.0)
	await player.play_dialogue(75)
	await _wait_for(5.0)
	await twin_1.play_dialogue(76)
	await player.play_dialogue(77)
	await twin_1.play_dialogue(78)
	await player.play_dialogue(778)
	_spawn_objective_marker(lifeboat, "Meet Ronnie at the lifeboat")
	_play_lifeboat_reminders()
	_dialogue_active = false

func add_supply():
	number_of_supplies += 1
	lifeboat_anim_player.play("Supply_drop")
	_play_sound("supply_drop")

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

func _teleport_player(location: Node3D) -> void:
	player.global_position = location.global_position

func _spawn_objective_marker(parent: Node3D, objective_text: String) -> void:
	var packed = load(objective_marker_prefab)
	var marker = packed.instantiate()
	parent.add_child(marker)
	player.set_objective_text(objective_text)
	current_objective = marker

func _remove_objective() -> void:
	if current_objective:
		current_objective.queue_free()
	current_objective = null

func _wait_for(time: float):
	return get_tree().create_timer(time).timeout

enum TimeOfDay { DAY, NIGHT, SUNSET }

@export_group("Sun Angles (Degrees)")
@export var DAY_SUN_PITCH_DEG: float = -89.5
@export var DAY_SUN_YAW_DEG: float = -39.3

@export var SUNSET_SUN_PITCH_DEG: float = -58.6
@export var SUNSET_SUN_YAW_DEG: float = -185.8

@export var NIGHT_SUN_PITCH_DEG: float = 86.7
@export var NIGHT_SUN_YAW_DEG: float = 89.2

var _sun_tween: Tween

func set_time_of_day(time: TimeOfDay, duration: float = 180.0) -> void:
	if time != TimeOfDay.NIGHT:
		_is_night = false

	if sun_light == null:
		push_warning("GameManager: sun_light missing at ../Lighting/DirectionalLight3D")
		return

	if _sun_tween and _sun_tween.is_running():
		_sun_tween.kill()

	var target_rot := _get_sun_rotation(time)

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

func lightning_strike() -> void:
	if sun_light == null or world_environment == null or world_environment.environment == null:
		return

	var original_color: Color = sun_light.light_color
	var original_energy: float = sun_light.light_energy
	var original_fog: Color = world_environment.environment.fog_light_color
	var original_rotation: Vector3 = sun_light.rotation
	var t := 0.0

	while t < 1.0:
		t += get_process_delta_time() * 20.0
		sun_light.light_color = original_color.lerp(Color.WHITE, t)
		sun_light.light_energy = lerp(original_energy, 5.0, t)
		world_environment.environment.fog_light_color = original_fog.lerp(Color(0.8, 0.8, 1.0), t)
		await get_tree().process_frame

	sun_light.rotation = Vector3(-PI / 2, 0, 0)

	await _wait_for(0.04)
	sun_light.light_energy = original_energy
	await get_tree().process_frame
	await _wait_for(0.03)
	sun_light.light_energy = 4.0
	await get_tree().process_frame

	sun_light.rotation = original_rotation

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
	audio_manager.play(audio_manager.Track.THUNDER, -10.0 if player.is_inside() else 0.0)

func _start_night_lightning() -> void:
	_is_night = true
	while _is_night:
		var wait_time = randf_range(0.0, 100.0)
		await _wait_for(wait_time)
		if _is_night:
			lightning_strike()

func show_dialog_text(id: int, time: float) -> void:
	if not dialog.has(id):
		return
	player.show_dialog_text(dialog[id], time)

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
	
func show_control_hint(
		hint: String,
		clear_actions: Array[StringName],
		on_done: Callable = Callable()
	) -> void:

	player.set_alert_text(hint)

	var watched := clear_actions.duplicate()

	while not watched.is_empty():
		await get_tree().process_frame
		watched = watched.filter(func(action): return not Input.is_action_just_pressed(action))

	player.clear_alert_text()

	if on_done.is_valid():
		on_done.call()
