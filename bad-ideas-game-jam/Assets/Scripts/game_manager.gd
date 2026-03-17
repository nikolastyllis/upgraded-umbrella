extends Node3D

@onready var twin_1 = $"../Twin1"   # Wazza
@onready var twin_2 = $"../Twin2"   # Bazza
@onready var player = $"../Player"

@onready var bedroom             = $Locations/Bedroom
@onready var container           = $Locations/Container
@onready var back_right_corner   = $Locations/BackRightCorner
@onready var oxy_torch           = $Locations/OxyTorch
@onready var container_door      = $Locations/ContainerDoor
@onready var store_room          = $Locations/StoreRoom
@onready var engine_room         = $Locations/EngineRoom
@onready var bridge              = $Locations/Bridge
@onready var lifeboat            = $Locations/Lifeboat
@onready var infected_container  = $Locations/InfectedContainer

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
var _is_night := false


# ── DIALOGUE ────────────────────────────────────────────────────────────────

var dialogue = {

	# ── ACT 1 ──────────────────────────────────────────────────────────────

	act1_player_wakeup     = "[Bubbles]: *yawn* ...What time is it.",
	act1_wazza_wake        = "[Wazza]: Oi Bubbles, you're finally up. Get down here — we've got something for ya.",
	act1_bazza_add         = "[Bazza]: Yeah, you're gonna love this one.",
	act1_player_groan      = "[Bubbles]: ...I just got off shift.",
	act1_wazza_tough       = "[Wazza]: Yeah, and now you're back on. Chop chop.",

	act1_wazza_greet       = "[Wazza]: There he is. Alright Bubbles, today you're gonna learn something useful for once.",
	act1_bazza_greet       = "[Bazza]: Don't stress, it's dead easy. Even you can do it.",
	act1_wazza_torch_inst  = "[Wazza]: Grab that oxy torch over there and we'll walk you through it down at the container door.",
	act1_bazza_torch_add   = "[Bazza]: Don't point it at yourself.",
	act1_player_torch_resp = "[Bubbles]: ...I wasn't going to.",
	act1_wazza_sure        = "[Wazza]: Sure you weren't.",

	act1_bazza_steady      = "[Bazza]: Nice and slow along the seam. Keep a steady hand.",
	act1_wazza_hurry       = "[Wazza]: Hurry up, mate! Are you trying to retire on this one cut?!",
	act1_player_cutting    = "[Bubbles]: I'm doin' it how you showed m-eee!",
	act1_bazza_pop         = "[Bazza]: Ahaha — was that a teste pop?!",
	act1_player_deny       = "[Bubbles]: It wasn't a teste pop!",
	act1_wazza_confirm     = "[Wazza]: It was.",
	act1_bazza_snapcrackle = "[Bazza]: Oi, where's Snap and Crackle?",
	act1_player_confused   = "[Bubbles]: ...Huh?",
	act1_bazza_ricebubs    = "[Bazza]: Rice Bubbles. Snap, Crackle and Pop.",
	act1_wazza_chuckle     = "[Wazza]: Heh...",
	act1_player_shutup     = "[Bubbles]: Shut. Up.",
	act1_wazza_snap        = "[Wazza]: There's Snap!",
	act1_bazza_mj          = "[Bazza]: Don't get teste, Michael Jackson. Didn't realise we were in the company of music royalty.",
	act1_wazza_kingofpop   = "[Wazza]: King of Pop.",
	act1_bazza_laugh       = "[Bazza]: HAHAHA!",
	act1_player_rage       = "[Bubbles]: IT WASN'T A TESTE POP!",
	act1_bazza_settle      = "[Bazza]: Alright alright, that's enough........It wasn't a real pop.",
	act1_wazza_tarantino   = "[Wazza]: Leave Quinton Tarantino alone.",
	act1_bazza_popfiction  = "[Bazza]: Pop Fiction.",
	act1_twins_roar        = "[Wazza & Bazza]: HAHAHAHAHA!",
	act1_player_foff       = "[Bubbles]: F*** off!!!",
	act1_wazza_backtowork  = "[Wazza]: Alright, cut it out. Back on the door.",

	act1_player_almostdone = "[Bubbles]: Are we gonna leave it like that? We're almost done — surely we'll just finish it.",
	act1_wazza_philosophy  = "[Wazza]: Listen, Ricebubbles. You're new to this game. I dunno how they taught you at school, but here in the real world we have a saying...",
	act1_twins_saying      = "[Wazza & Bazza]: Why do today what you can do tomorrow.",
	act1_bazza_packup      = "[Bazza]: Go on, pack it up!",
	act1_player_disbelief  = "[Bubbles]: ...You're serious.",
	act1_wazza_walkaway    = "[Wazza]: Dead serious. Come on Baz.",
	act1_bazza_walkaway    = "[Bazza]: Don't lose that torch, Ricebubbles.",
	act1_player_bed        = "[Bubbles]: ...I'm going back to bed.",

	# ── ACT 2 ──────────────────────────────────────────────────────────────

	act2_wazza_morning     = "[Wazza]: Rise and shine Bubbles. Big day.",
	act2_bazza_morning     = "[Bazza]: We're gonna finish cracking that container, fix the backup power, and have a crack at the lifeboat.",
	act2_player_morning    = "[Bubbles]: ...It's barely light out.",
	act2_wazza_plan        = "[Wazza]: Quit whinging. We'll head down and get that last bit cracked first.",
	act2_bazza_redirect    = "[Bazza]: Actually — you head down to the storeroom and grab the gear we'll need. We've got the torch.",
	act2_wazza_list        = "[Wazza]: You'll need: three boxes of sky hooks, four tins of tartan paint, two spirit level bubbles, a box of sparks for the grinder, one long weight, a tub of elbow grease, and a reach around.",
	act2_player_listq      = "[Bubbles]: ...Is that a real list?",
	act2_bazza_serious     = "[Bazza]: Dead serious, mate. We'll be on the radio. Chop chop.",
	act2_player_mutter     = "[Bubbles]: Sky hooks...",

	act2_radio_longwait    = "[Bazza]: Oi! How ya going down there? You must've found that long wait by now. Heh heh.",
	act2_wazza_piecost     = "[Wazza]: Oh, while you're faffing about down there — grab a pie cost.",
	act2_player_piecostq   = "[Bubbles]: What's a pie cost?",
	act2_bazza_tubby       = "[Bazza]: Like you don't know, tubby!",
	act2_twins_laugh       = "[Wazza & Bazza]: HAHAHAHAHA!",
	act2_bazza_getback     = "[Bazza]: Alright Einstein, stop mucking around. Get your arse back up here.",
	act2_player_getback    = "[Bubbles]: Yeah yeah, I'm coming.",

	# ── ACT 2 — ENGINE ROOM TASK ───────────────────────────────────────────

	act2_engine_senddown   = "[Wazza]: Oi, before you come back up — pop down to the engine room and check the gauges for us.",
	act2_engine_which      = "[Bubbles]: ...Which gauges?",
	act2_bazza_gauges      = "[Bazza]: The gauges. You know. The important ones.",
	act2_player_gauges     = "[Bubbles]: That doesn't narrow it down.",
	act2_wazza_round       = "[Wazza]: Big round ones. Numbers on 'em.",
	act2_player_all        = "[Bubbles]: ...That describes all of them.",
	act2_bazza_wrong       = "[Bazza]: Just write down anything that looks wrong.",

	act2_engine_arrive     = "[Bubbles]: Alright. I'm in the engine room.",
	act2_engine_look       = "[Bubbles]: Everything looks... fine. Nothing looks wrong to me.",
	act2_bazza_perfect     = "[Bazza]: Perfect. See? Easy.",
	act2_wazza_fuel        = "[Wazza]: Fuel pressure's a bit low but she'll be right.",
	act2_player_lowfuel    = "[Bubbles]: Should I be worried about that?",
	act2_wazza_nah         = "[Wazza]: Nah. Probably.",
	act2_player_probably   = "[Bubbles]: ...Probably.",

	# ── ACT 2 — BRIDGE TASK ────────────────────────────────────────────────

	act2_bridge_send       = "[Bazza]: While you're running around — head up to the bridge and let Captain Joyce know we're working on the backup power today.",
	act2_player_bridge_q   = "[Bubbles]: Can't you just radio him?",
	act2_wazza_bridge_why  = "[Wazza]: Yeah, but you need the exercise.",
	act2_bazza_bridge_add  = "[Bazza]: And he doesn't like us.",
	act2_player_bridge_ok  = "[Bubbles]: ...Why doesn't he like you.",
	act2_wazza_bridge_shrug = "[Wazza]: Long story. Off you go.",

	act2_bridge_arrive     = "[Bubbles]: Captain Joyce?",
	act2_captain_response  = "[Captain Joyce]: What is it.",
	act2_player_relay      = "[Bubbles]: Wazza and Bazza wanted me to let you know they're working on the backup power today. And the lifeboat.",
	act2_captain_pause     = "[Captain Joyce]: ...Right.",
	act2_player_bridge_ok2 = "[Bubbles]: That's it. That's the message.",
	act2_captain_dismiss   = "[Captain Joyce]: Tell Warren and Barry I'd prefer they stayed off the bridge.",
	act2_player_understood = "[Bubbles]: Understood. Yeah.",
	act2_bazza_heard       = "[Bazza]: We heard that.",
	act2_wazza_rude        = "[Wazza]: Bit rude.",

	# ── ACT 2 — LIFEBOAT TASK ──────────────────────────────────────────────

	act2_lifeboat_send     = "[Wazza]: Last thing — go have a look at the lifeboat and let us know what state it's in.",
	act2_player_lifeboat_q = "[Bubbles]: What am I looking for?",
	act2_bazza_lifeboat_a  = "[Bazza]: Holes. Rust. General... not-working-ness.",
	act2_player_lifeboat_m = "[Bubbles]: Great. Very technical.",

	act2_lifeboat_arrive   = "[Bubbles]: Alright. Lifeboat.",
	act2_lifeboat_look     = "[Bubbles]: It's... not great. There's rust on the release mechanism and one of the brackets looks bent.",
	act2_wazza_lifeboat    = "[Wazza]: Yeah she's seen better days.",
	act2_player_fix        = "[Bubbles]: Are we going to fix it today?",
	act2_bazza_lifeboat    = "[Bazza]: We're gonna have a crack at it.",
	act2_player_crack      = "[Bubbles]: When?",
	act2_twins_tomorrow    = "[Wazza & Bazza]: Tomorrow.",
	act2_player_ofcourse   = "[Bubbles]: ...Of course.",
	act2_wazza_backup      = "[Wazza]: Alright, we've nearly got this container open. Get back up here.",

	# ── ACT 2 — CONTAINER RETURN ───────────────────────────────────────────

	act2_container_open    = "[Bubbles]: ...The container's already open.",
	act2_tools_on_deck     = "[Bubbles]: Tools just left on the deck. There's still a smoke burning on the ground.",
	act2_player_calls      = "[Bubbles]: Boys?",
	act2_player_calls2     = "[Bubbles]: Wazza? Baz?",

	# ── ACT 3 ──────────────────────────────────────────────────────────────

	act3_missing_call      = "[Bubbles]: Oi boys, where are you? Come in.",
	act3_lights_out        = "[System]: Main power failure. Switching to backup generators.",
	act3_engine_stops      = "[Bubbles]: ...The engines stopped.",
	act3_engine_stops2     = "[Bubbles]: Why have the engines stopped.",
	act3_player_nervous    = "[Bubbles]: Ha... very funny. If this is a prank, you're not fooling anyone.",
	act3_silence           = "[Bubbles]: ...Hello?",
	act3_radio_static      = "[Radio]: *static*",
	act3_player_worried    = "[Bubbles]: Guys, come in. Seriously.",
	act3_get_torch         = "[Bubbles]: I need a torch. Back to my room.",

	act3_bedroom_dark      = "[Bubbles]: Can't see a thing in here...",
	act3_bedroom_find      = "[Bubbles]: There it is.",

	act3_engine_arrive     = "[Bubbles]: The fuel pressure's dropped completely. That's why the engines stopped.",
	act3_engine_noone      = "[Bubbles]: No one's been down here. Those gauges Wazza told me not to worry about...",
	act3_engine_look       = "[Bubbles]: Where are you two...",

	act3_bridge_arrive     = "[Bubbles]: Captain? Anyone up here?",
	act3_bridge_empty      = "[Bubbles]: Bridge is empty. The helm's just... sitting there.",
	act3_bridge_radio_try  = "[Bubbles]: Main radio. Come on...",
	act3_bridge_no_captain = "[Bubbles]: Captain Joyce, this is Bubbles. Is anyone reading me? Over.",
	act3_bridge_static     = "[Radio]: *long static*",
	act3_bridge_give_up    = "[Bubbles]: ...Nothing. He was right here this morning.",
	act3_bridge_window     = "[Bubbles]: The deck looks clear from up here. Where the hell has everyone gone.",
	act3_bridge_handheld   = "[Bubbles]: Wazza. Bazza. Come in. Where are you two?",
	act3_bridge_silence    = "[Bubbles]: ...",

	# -- Wazza's call comes through on the bridge main radio --
	act3_radio_creepy      = "[Wazza]: ...At the lifeboat. Come help us out, mate.",
	act3_player_concern    = "[Bubbles]: Are you alright? You sound... weird.",
	act3_radio_flat        = "[Wazza]: ...I'm fine.",
	act3_player_uneasy     = "[Bubbles]: ...On my way.",

	act3_lifeboat_arrive   = "[Bubbles]: Wazza? Bazza?",
	act3_lifeboat_wrong    = "[Bubbles]: Something's not right here...",
	act3_lifeboat_blood    = "[Bubbles]: Is that... what is that on the deck.",
	act3_lifeboat_smell    = "[Bubbles]: What is that smell.",
	act3_bazza_lure        = "[Bazza]: ...The container. Come see.",
	act3_player_lure_resp  = "[Bubbles]: Baz? Which container? Where are you?",
	act3_lure_silence      = "[Bubbles]: ...Bazza.",

	# ── ACT 4 ──────────────────────────────────────────────────────────────

	act4_arrive            = "[Bubbles]: Wazza? Bazza? What the hell happened here...?",
	act4_creature_sound    = "[Unknown]: *wet screeching noise*",
	act4_player_panic      = "[Bubbles]: BAZZA?! WAZZA?!",
	act4_reveal            = "[System]: RUN.",
}


# ── LIFECYCLE ───────────────────────────────────────────────────────────────

func _ready() -> void:
	
	set_time_of_day(TimeOfDay.DAY, 0.1)
	# Act 1 — player wakes up in their bedroom
	_teleport_player(bedroom)
	twin_1.set_target_position(back_right_corner.global_position)
	twin_2.set_target_position(back_right_corner.global_position)
	_remove_objective()

	await _wait_for(1.5)
	player.show_dialog_text(dialogue.act1_player_wakeup)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act1_wazza_wake)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act1_bazza_add)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act1_player_groan)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act1_wazza_tough)
	await _wait_for(3.5)
	_spawn_objective_marker(twin_1)


@warning_ignore("shadowed_variable_base_class")
func _player_is_near(position: Vector3) -> bool:
	return (player.global_position - position).length() < 2

func _update_audio_and_rain() -> void:
	var inside = player.is_inside()
	audio_manager.set_target(audio_manager.Track.INSIDE,   -10.0   if inside                  else -40.0)
	audio_manager.set_target(audio_manager.Track.OUTSIDE,  -10.0   if not inside              else -40.0)
	audio_manager.set_target(audio_manager.Track.RAIN,     -10.0  if _is_night and not inside else -40.0)
	rain.visible = not inside and _is_night
	

func _process(_delta: float) -> void:
	
	_update_audio_and_rain()

	# ── ACT 1 ────────────────────────────────────────────────────────────────

	if story_increment == 1 and _player_is_near(back_right_corner.global_position):
		story_increment += 1
		_remove_objective()
		_play_act1_meet_twins()

	if story_increment == 2 and _player_is_near(oxy_torch.global_position):
		story_increment += 1
		_remove_objective()
		_play_act1_torch_pickup()

	if story_increment == 3 and _player_is_near(container_door.global_position):
		story_increment += 1
		_remove_objective()
		_play_act1_container_cut()

	# ── ACT 2 ────────────────────────────────────────────────────────────────

	# Storeroom run — fake items list
	if story_increment == 4 and _player_is_near(store_room.global_position):
		set_time_of_day(TimeOfDay.SUNSET)
		story_increment += 1
		_play_act2_storeroom()

	# Engine room — gauge check
	if story_increment == 5 and _player_is_near(engine_room.global_position):
		story_increment += 1
		set_time_of_day(TimeOfDay.NIGHT)
		_remove_objective()
		_play_act2_engine_room()

	# Bridge — relay message to captain
	if story_increment == 6 and _player_is_near(bridge.global_position):
		story_increment += 1
		_remove_objective()
		_play_act2_bridge()

	# Lifeboat — condition inspection
	if story_increment == 7 and _player_is_near(lifeboat.global_position):
		story_increment += 1
		_remove_objective()
		_play_act2_lifeboat()

	# Container return — twins are gone, lights go out
	if story_increment == 8 and _player_is_near(container.global_position):
		story_increment += 1
		_remove_objective()
		_play_act2_return()

	# ── ACT 3 ────────────────────────────────────────────────────────────────

	# Bedroom — grab flashlight in the dark
	if story_increment == 9 and _player_is_near(bedroom.global_position):
		story_increment += 1
		_remove_objective()
		_play_act3_bedroom()

	# Engine room — now dark, engines dead
	if story_increment == 10 and _player_is_near(engine_room.global_position):
		story_increment += 1
		_remove_objective()
		_play_act3_engine_room()

	# Bridge — try the main radio, captain gone
	if story_increment == 11 and _player_is_near(bridge.global_position):
		story_increment += 1
		_remove_objective()
		_play_act3_bridge()

	# Lifeboat — aftermath, Bazza lures player to container
	if story_increment == 12 and _player_is_near(lifeboat.global_position):
		story_increment += 1
		_remove_objective()
		_play_act3_lifeboat()

	# ── ACT 4 ────────────────────────────────────────────────────────────────

	if story_increment == 13 and _player_is_near(infected_container.global_position):
		story_increment += 1
		_remove_objective()
		_play_act4_reveal()


# ── ACT 1 SEQUENCES ─────────────────────────────────────────────────────────

func _play_act1_meet_twins() -> void:
	player.show_dialog_text(dialogue.act1_wazza_greet)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act1_bazza_greet)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act1_wazza_torch_inst)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act1_bazza_torch_add)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_player_torch_resp)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_wazza_sure)
	await _wait_for(3.0)
	_spawn_objective_marker(oxy_torch)


func _play_act1_torch_pickup() -> void:
	twin_1.set_target_position(container_door.global_position)
	twin_2.set_target_position(container_door.global_position)
	await _wait_for(1.5)
	_spawn_objective_marker(container_door)


func _play_act1_container_cut() -> void:
	player.show_dialog_text(dialogue.act1_bazza_steady)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act1_wazza_hurry)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act1_player_cutting)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_bazza_pop)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_player_deny)
	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act1_wazza_confirm)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_bazza_snapcrackle)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act1_player_confused)
	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act1_bazza_ricebubs)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act1_wazza_chuckle)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_player_shutup)
	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act1_wazza_snap)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_bazza_mj)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act1_wazza_kingofpop)
	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act1_bazza_laugh)
	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act1_player_rage)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_bazza_settle)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act1_wazza_tarantino)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act1_bazza_popfiction)
	await _wait_for(1.5)
	player.show_dialog_text(dialogue.act1_twins_roar)
	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act1_player_foff)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_wazza_backtowork)

	# ── Work bell ───────────────────────────────────────────────────────────
	await _wait_for(7.0)

	player.show_dialog_text(dialogue.act1_player_almostdone)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act1_wazza_philosophy)
	await _wait_for(6.0)
	player.show_dialog_text(dialogue.act1_twins_saying)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act1_bazza_packup)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_player_disbelief)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_wazza_walkaway)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act1_bazza_walkaway)

	# Twins head back to quarters — night over
	twin_1.set_target_position(back_right_corner.global_position)
	twin_2.set_target_position(back_right_corner.global_position)

	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act1_player_bed)

	# ── Time skip to next morning — Act 2 ───────────────────────────────────
	await _wait_for(3.5)
	_teleport_player(bedroom)
	twin_1.set_target_position(container.global_position)
	twin_2.set_target_position(container.global_position)

	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act2_wazza_morning)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act2_bazza_morning)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act2_player_morning)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_wazza_plan)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act2_bazza_redirect)
	await _wait_for(5.5)
	player.show_dialog_text(dialogue.act2_wazza_list)
	await _wait_for(7.0)
	player.show_dialog_text(dialogue.act2_player_listq)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_bazza_serious)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_player_mutter)
	await _wait_for(2.0)
	_spawn_objective_marker(store_room)


# ── ACT 2 SEQUENCES ─────────────────────────────────────────────────────────

func _play_act2_storeroom() -> void:
	await _wait_for(6.0)
	player.show_dialog_text(dialogue.act2_radio_longwait)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act2_wazza_piecost)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act2_player_piecostq)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act2_bazza_tubby)
	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act2_twins_laugh)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_bazza_getback)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_player_getback)
	await _wait_for(3.5)

	# Chain straight into the next task
	player.show_dialog_text(dialogue.act2_engine_senddown)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act2_engine_which)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_bazza_gauges)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_player_gauges)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_wazza_round)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_player_all)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_bazza_wrong)
	await _wait_for(3.0)
	_remove_objective()
	_spawn_objective_marker(engine_room)


func _play_act2_engine_room() -> void:
	# Twins are working the container — split slightly so they look active
	twin_1.set_target_position(container_door.global_position)
	twin_2.set_target_position(container.global_position)
	player.show_dialog_text(dialogue.act2_engine_arrive)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act2_engine_look)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act2_bazza_perfect)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_wazza_fuel)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act2_player_lowfuel)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_wazza_nah)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act2_player_probably)
	await _wait_for(4.0)

	# Chain into bridge task
	player.show_dialog_text(dialogue.act2_bridge_send)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act2_player_bridge_q)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_wazza_bridge_why)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_bazza_bridge_add)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_player_bridge_ok)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_wazza_bridge_shrug)
	await _wait_for(3.5)
	_spawn_objective_marker(bridge)


func _play_act2_bridge() -> void:
	# Twins still working — Wazza moves toward the container door, Bazza back a bit
	twin_1.set_target_position(container.global_position)
	twin_2.set_target_position(back_right_corner.global_position)
	# Player runs up to the bridge alone
	player.show_dialog_text(dialogue.act2_bridge_arrive)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_captain_response)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act2_player_relay)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act2_captain_pause)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_player_bridge_ok2)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_captain_dismiss)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act2_player_understood)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_bazza_heard)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act2_wazza_rude)
	await _wait_for(4.0)

	# Chain into lifeboat task
	player.show_dialog_text(dialogue.act2_lifeboat_send)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act2_player_lifeboat_q)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_bazza_lifeboat_a)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act2_player_lifeboat_m)
	await _wait_for(3.5)
	_spawn_objective_marker(lifeboat)


func _play_act2_lifeboat() -> void:
	# Both twins converge back on the container door — nearly done
	twin_1.set_target_position(container_door.global_position)
	twin_2.set_target_position(container_door.global_position)
	player.show_dialog_text(dialogue.act2_lifeboat_arrive)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_lifeboat_look)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act2_wazza_lifeboat)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_player_fix)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act2_bazza_lifeboat)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act2_player_crack)
	await _wait_for(2.0)
	player.show_dialog_text(dialogue.act2_twins_tomorrow)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act2_player_ofcourse)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_wazza_backup)
	await _wait_for(3.5)
	_spawn_objective_marker(container)


func _play_act2_return() -> void:
	# Twins have vanished into the infected container — hide them immediately
	twin_1.hide()
	twin_2.hide()

	player.show_dialog_text(dialogue.act2_container_open)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act2_tools_on_deck)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act2_player_calls)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act2_player_calls2)
	await _wait_for(4.0)

	# ── Lights go out ───────────────────────────────────────────────────────
	player.show_dialog_text(dialogue.act3_missing_call)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act3_lights_out)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act3_engine_stops)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act3_engine_stops2)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act3_player_nervous)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act3_silence)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act3_radio_static)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act3_player_worried)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act3_get_torch)
	await _wait_for(3.0)
	_spawn_objective_marker(bedroom)


# ── ACT 3 SEQUENCES ─────────────────────────────────────────────────────────

func _play_act3_bedroom() -> void:
	player.show_dialog_text(dialogue.act3_bedroom_dark)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act3_bedroom_find)
	await _wait_for(3.0)
	_spawn_objective_marker(engine_room)


func _play_act3_engine_room() -> void:
	# Hidden twins drift around the ship — player may hear footsteps
	twin_1.set_target_position(bridge.global_position)
	twin_2.set_target_position(store_room.global_position)

	# Player recognises this room — and now the gauges mean something
	player.show_dialog_text(dialogue.act3_engine_arrive)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act3_engine_noone)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act3_engine_look)
	await _wait_for(4.0)
	_spawn_objective_marker(bridge)


func _play_act3_bridge() -> void:
	# Both twins converge on the lifeboat — positioning for the lure
	twin_1.set_target_position(lifeboat.global_position)
	twin_2.set_target_position(lifeboat.global_position)

	# Player was just here this morning — now it's empty and the captain is gone
	player.show_dialog_text(dialogue.act3_bridge_arrive)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act3_bridge_empty)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act3_bridge_radio_try)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act3_bridge_no_captain)
	await _wait_for(6.0)
	player.show_dialog_text(dialogue.act3_bridge_static)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act3_bridge_give_up)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act3_bridge_window)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act3_bridge_handheld)
	await _wait_for(5.5)
	player.show_dialog_text(dialogue.act3_bridge_silence)
	await _wait_for(5.5)
	# Wazza comes through the bridge main speakers
	player.show_dialog_text(dialogue.act3_radio_creepy)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act3_player_concern)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act3_radio_flat)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act3_player_uneasy)
	await _wait_for(3.0)
	_spawn_objective_marker(lifeboat)


func _play_act3_lifeboat() -> void:
	# Twins move to infected container — the lifeboat player just inspected is now a crime scene
	twin_1.set_target_position(infected_container.global_position)
	twin_2.set_target_position(infected_container.global_position)

	player.show_dialog_text(dialogue.act3_lifeboat_arrive)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act3_lifeboat_wrong)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act3_lifeboat_blood)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act3_lifeboat_smell)
	await _wait_for(6.0)
	player.show_dialog_text(dialogue.act3_bazza_lure)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act3_player_lure_resp)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act3_lure_silence)
	await _wait_for(4.0)
	_spawn_objective_marker(infected_container)


# ── ACT 4 SEQUENCES ─────────────────────────────────────────────────────────

func _play_act4_reveal() -> void:
	# Show the twins again — they are now the creatures
	twin_1.show()
	twin_2.show()
	twin_1.set_target_position(infected_container.global_position)
	twin_2.set_target_position(infected_container.global_position)

	player.show_dialog_text(dialogue.act4_arrive)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act4_creature_sound)
	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act4_player_panic)
	await _wait_for(2.5)
	player.show_dialog_text(dialogue.act4_reveal)


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
	match time:
		TimeOfDay.NIGHT:
			_start_night_lightning()
		_:
			_is_night = false

	var target := _get_time_of_day_params(time)
	_transition_environment(target, duration)


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


func _transition_environment(target: Dictionary, duration: float) -> void:
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
