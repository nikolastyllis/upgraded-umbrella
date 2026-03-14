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

@onready var objective_marker_prefab = "res://Prefabs/objective_marker_ui.tscn"

var current_objective = null
var story_increment   = 1


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
	act2_bazza_redirect    = "[Bazza]: Actually — you head down to the storeroom and grab the gear we'll need for later. We've got the torch.",
	act2_wazza_list        = "[Wazza]: You'll need: three boxes of sky hooks, four tins of tartan paint, two spirit level bubbles, a box of sparks for the grinder, one long weight, a tub of elbow grease, and a reach around.",
	act2_player_listq      = "[Bubbles]: ...Is that a real list?",
	act2_bazza_serious     = "[Bazza]: Dead serious, mate. We'll be on the radio if you need anything. Chop chop.",
	act2_player_mutter     = "[Bubbles]: Sky hooks...",

	act2_radio_longwait    = "[Bazza]: Oi! How ya going down there? You must've found that long wait by now. Heh heh.",
	act2_wazza_piecost     = "[Wazza]: Oh, while you're faffing about down there — grab a pie cost.",
	act2_player_piecostq   = "[Bubbles]: What's a pie cost?",
	act2_bazza_tubby       = "[Bazza]: Like you don't know, tubby!",
	act2_twins_laugh       = "[Wazza & Bazza]: HAHAHAHAHA!",
	act2_bazza_getback     = "[Bazza]: Alright Einstein, stop mucking around and get your arse back up here.",
	act2_player_getback    = "[Bubbles]: Yeah yeah, I'm coming.",

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

	act3_engine_arrive     = "[Bubbles]: Nothing's tripped the breakers... Backup power just kicked in by itself.",
	act3_engine_noone      = "[Bubbles]: No one's been down here.",
	act3_engine_look       = "[Bubbles]: Where are you two...",

	act3_bridge_arrive     = "[Bubbles]: Captain? Anyone up here?",
	act3_bridge_empty      = "[Bubbles]: Bridge is empty. The helm's just... sitting there.",
	act3_bridge_radio_try  = "[Bubbles]: Main radio. Come on...",
	act3_bridge_no_captain = "[Bubbles]: Captain Joyce, this is Bubbles. Is anyone reading me? Over.",
	act3_bridge_static     = "[Radio]: *long static*",
	act3_bridge_give_up    = "[Bubbles]: ...Nothing.",
	act3_bridge_handheld   = "[Bubbles]: Wazza. Bazza. Come in. Where are you two?",
	act3_bridge_silence    = "[Bubbles]: ...",
	act3_bridge_window     = "[Bubbles]: The deck looks clear from up here. Where the hell have they gone.",

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
	# Act 1 — player wakes up in their bedroom
	_teleport_player(bedroom)

	# Both twins are outside waiting — they've already radioed in
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


func _player_is_near(position: Vector3) -> bool:
	return (player.global_position - position).length() < 2


func _process(_delta: float) -> void:

	# ── ACT 1 ────────────────────────────────────────────────────────────────

	# Player walks out to the twins
	if story_increment == 1 and _player_is_near(back_right_corner.global_position):
		story_increment += 1
		_remove_objective()
		_play_act1_meet_twins()

	# Player picks up the oxy torch
	if story_increment == 2 and _player_is_near(oxy_torch.global_position):
		story_increment += 1
		_remove_objective()
		_play_act1_torch_pickup()

	# Player follows twins to the container door — cutting scene + work bell
	if story_increment == 3 and _player_is_near(container_door.global_position):
		story_increment += 1
		_remove_objective()
		_play_act1_container_cut()

	# ── ACT 2 ────────────────────────────────────────────────────────────────

	# Player heads down to the storeroom
	if story_increment == 4 and _player_is_near(store_room.global_position):
		story_increment += 1
		_play_act2_storeroom()

	# Player returns to the container — twins are gone, lights go out
	if story_increment == 5 and _player_is_near(container.global_position):
		story_increment += 1
		_remove_objective()
		_play_act2_return()

	# ── ACT 3 ────────────────────────────────────────────────────────────────

	# Player returns to bedroom to grab their torch
	if story_increment == 6 and _player_is_near(bedroom.global_position):
		story_increment += 1
		_remove_objective()
		_play_act3_bedroom()

	# Player reaches the engine room
	if story_increment == 7 and _player_is_near(engine_room.global_position):
		story_increment += 1
		_remove_objective()
		_play_act3_engine_room()

	# Player reaches the bridge — tries the main radio
	if story_increment == 8 and _player_is_near(bridge.global_position):
		story_increment += 1
		_remove_objective()
		_play_act3_bridge()

	# Player reaches the lifeboat — aftermath, gets lured
	if story_increment == 9 and _player_is_near(lifeboat.global_position):
		story_increment += 1
		_remove_objective()
		_play_act3_lifeboat()

	# ── ACT 4 ────────────────────────────────────────────────────────────────

	# Player reaches the infected container — creature reveal
	if story_increment == 10 and _player_is_near(infected_container.global_position):
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
	# Both twins lead the way to the container door — player follows
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

	# ── Work bell — twins immediately drop everything ────────────────────────
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

	# Twins head back to their quarters — night is over
	twin_1.set_target_position(back_right_corner.global_position)
	twin_2.set_target_position(back_right_corner.global_position)

	await _wait_for(3.0)
	player.show_dialog_text(dialogue.act1_player_bed)

	# ── Time skip to next morning — Act 2 ───────────────────────────────────
	# Player snaps back to their bedroom; twins radio in with the day's plan
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
	# Player hunts around — radio crackles in after a moment
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
	await _wait_for(3.0)
	_remove_objective()
	_spawn_objective_marker(container)


func _play_act2_return() -> void:
	# Twins have vanished into the infected container — hide them immediately
	twin_1.hide()
	twin_2.hide()

	# Player arrives and notices something is very wrong
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
	# Player is back in their dark cabin grabbing the torch
	player.show_dialog_text(dialogue.act3_bedroom_dark)
	await _wait_for(4.0)
	player.show_dialog_text(dialogue.act3_bedroom_find)
	await _wait_for(3.0)
	_spawn_objective_marker(engine_room)


func _play_act3_engine_room() -> void:
	# Wazza drifts toward the bridge — Bazza drifts back toward the store room.
	# Twins are invisible but moving — player may hear footsteps ahead of them.
	twin_1.set_target_position(bridge.global_position)
	twin_2.set_target_position(store_room.global_position)

	player.show_dialog_text(dialogue.act3_engine_arrive)
	await _wait_for(4.5)
	player.show_dialog_text(dialogue.act3_engine_noone)
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act3_engine_look)
	await _wait_for(4.0)
	_spawn_objective_marker(bridge)


func _play_act3_bridge() -> void:
	# Both twins converge on the lifeboat — positioning for the lure
	twin_1.set_target_position(lifeboat.global_position)
	twin_2.set_target_position(lifeboat.global_position)

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
	await _wait_for(3.5)
	player.show_dialog_text(dialogue.act3_bridge_window)
	await _wait_for(5.0)
	player.show_dialog_text(dialogue.act3_bridge_handheld)
	await _wait_for(5.5)
	player.show_dialog_text(dialogue.act3_bridge_silence)
	await _wait_for(5.5)
	# Wazza comes through the bridge main speakers — not the handheld
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
	# Twins move to infected_container — they've already lured the player here
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
