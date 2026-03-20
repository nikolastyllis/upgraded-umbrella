class_name BaseCharacter
extends CharacterBody3D

@export var rotation_speed := 5
@onready var animation_tree: AnimationTree = $Character/Armature/AnimationTree
@onready var character := $Character
@onready var character_anchor := $CharacterAnchor

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_climbing := false
var current_ladder: Node3D = null
var climb_cooldown := 0.0
var is_finishing_climb := false
var finish_climb_animation_cooldown_timer = 0.0
var finish_climb_animation_cooldown = 4.0

var is_jogging: bool = false

var footstep_timer := 0.0
var footstep_interval := .78  # Seconds between steps
var jog_footstep_interval := .39

var ladder_step_timer := 0.0
var ladder_step_interval := 0.8  # Slightly faster than footsteps
var ladder_player: AudioStreamPlayer3D

var footstep_player: AudioStreamPlayer3D

var _loop_player: AudioStreamPlayer = null
var _oxy_torch_looping = false

func _ready() -> void:
	animation_tree.animation_finished.connect(_on_animation_finished)
	_setup_footstep_player()

func _setup_footstep_player() -> void:
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.bus = "Sound"
	footstep_player.stream = load("res://Assets/Sound/footstep.ogg")
	add_child(footstep_player)

	ladder_player = AudioStreamPlayer3D.new()
	ladder_player.bus = "Sound"
	ladder_player.stream = load("res://Assets/Sound/ladder.ogg")
	add_child(ladder_player)

func _physics_process(delta: float) -> void:
	finish_climb_animation_cooldown_timer += delta
	_update_footsteps(delta)
	_update_ladder_sounds(delta)  # ADD THIS LINE

func _update_footsteps(delta: float) -> void:
	var is_walking = is_on_floor() and velocity.length() > 0.5 and not is_climbing and not is_finishing_climb
	
	if is_walking:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			_play_footstep()
			if is_jogging: 
				footstep_timer = jog_footstep_interval
			else: 
				footstep_timer = footstep_interval
	else:
		footstep_timer = 0.0  # Reset so next step plays immediately on movement

func _update_ladder_sounds(delta: float) -> void:
	var is_moving_on_ladder = is_climbing and abs(get_climb_input()) > 0.1 and not is_finishing_climb

	if is_moving_on_ladder:
		ladder_step_timer -= delta
		if ladder_step_timer <= 0.0:
			_play_ladder_step()
			ladder_step_timer = ladder_step_interval
	else:
		ladder_step_timer = 0.0  # Reset so next step plays immediately

func _play_footstep() -> void:
	footstep_player.pitch_scale = randf_range(0.8, 1.2)
	footstep_player.volume_db = randf_range(-20, -15)
	footstep_player.play()
	
func _play_ladder_step() -> void:
	ladder_player.pitch_scale = randf_range(0.8, 1.2)
	ladder_player.volume_db = randf_range(-20, -15)
	ladder_player.play()
	
func start_climbing(ladder: Node3D) -> void:
	if climb_cooldown > 0:
		return
	current_ladder = ladder
	is_climbing = true

func stop_climbing() -> void:
	if current_ladder:
		current_ladder = null
		is_climbing = false
		climb_cooldown = 0.5

func update_climb_position() -> void:
	if not current_ladder:
		return
	var to_ladder = current_ladder.global_position - global_position
	to_ladder.y = 0
	if to_ladder.length() > 0.01:
		var ladder_offset = -deg_to_rad(90) if self is NPC else deg_to_rad(90)
		rotation.y = lerp_angle(rotation.y, current_ladder.rotation.y + ladder_offset, 0.15)
	var ladder_forward = current_ladder.global_transform.basis.x
	var target_pos = current_ladder.global_position + ladder_forward * -0.4
	var aligned = Vector3(target_pos.x, global_position.y, target_pos.z)
	global_position = global_position.lerp(aligned, 0.15)

func apply_climbing_movement() -> void:
	velocity = Vector3.ZERO
	velocity.y = get_climb_input() * get_speed() / 3.0

func apply_gravity(delta: float) -> void:
	if is_climbing:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

func update_movement_animation(input_dir: Vector2) -> void:
	var state_machine = animation_tree["parameters/AnimationNodeStateMachine/playback"]
	
	if current_ladder and current_ladder.end_y() < global_position.y and get_climb_input() > 0 and finish_climb_animation_cooldown_timer > finish_climb_animation_cooldown:
			finish_climb_animation_cooldown_timer = 0
			animation_tree["parameters/AnimationNodeStateMachine/playback"].travel("Finish Climbing")
			is_finishing_climb = true
			
	if is_finishing_climb:
		return
	if is_climbing:
		state_machine.travel("Climb")
		animation_tree.set("parameters/Climb/Climb Direction/scale", sign(get_climb_input()))
	elif not is_on_floor():
		state_machine.travel("Fall")
	elif input_dir != Vector2.ZERO:
		if is_jogging:
			state_machine.travel("Jog")
		else:
			state_machine.travel("Move")
	else:
		state_machine.travel("Idle")

func update_character_rotation(target_rotation_y: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)
	character.rotation.y = lerp_angle(character.rotation.y, character_anchor.rotation.y, 3 * delta)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Finish Climbing":
		finish_climbing_complete()

func finish_climbing_complete() -> void:
	is_finishing_climb = false

func get_speed() -> float:
	return 2.5

func get_climb_input() -> float:
	return 0.0
	
func get_player():
	pass

func play_dialogue(id: int) -> void:
	var path := "res://Assets/Dialogue/%d.ogg" % id
	if not ResourceLoader.exists(path):
		push_warning("Dialogue file not found: %s" % path)
		return
	
	var player_node = self.get_player()
	var use_radio = false
	var use_blip = false
	
	if self is NPC:
		use_radio = global_position.distance_to(player_node.global_position) > 7.0
		
	if self is Player:
		var npcs = get_tree().get_nodes_in_group("npcs")
		for npc in npcs:
			use_blip = global_position.distance_to(npc.global_position) > 7.0 or use_blip
	
	if use_radio:
		await _play_static()
		
	if use_blip:
		await _play_blip()

	var dialogue_player = null
	if use_radio:
		dialogue_player = AudioStreamPlayer.new()
		dialogue_player.volume_db = 5
	else:
		dialogue_player = AudioStreamPlayer3D.new()
		dialogue_player.volume_db = 20
		
	dialogue_player.bus = "Radio" if use_radio else "Sound"
	dialogue_player.stream = load(path)
	add_child(dialogue_player)
	animation_tree.set("parameters/TalkAdd/add_amount", 1.0)
	if use_radio or use_blip:
		var tween_in = create_tween()
		tween_in.tween_method(
			func(v): animation_tree.set("parameters/RadioBlend/blend_amount", v),
			0.0, 1.0, 0.3
		)
	dialogue_player.play()
	await dialogue_player.finished
	if use_radio or use_blip:
		var tween_in = create_tween()
		tween_in.tween_method(
			func(v): animation_tree.set("parameters/RadioBlend/blend_amount", v),
			1.0, 0.0, 0.3
		)
	animation_tree.set("parameters/TalkAdd/add_amount", 0.0)

	var tween := create_tween()
	tween.tween_property(dialogue_player, "volume_db", -80.0, 0.1)
	await tween.finished
	dialogue_player.queue_free()

	if use_radio:
		await _play_static()
		
	if use_blip:
		await _play_end_blip()

	await get_tree().create_timer(1.5).timeout

func _play_static() -> void:
	const STATIC_PATH := "res://Assets/Dialogue/static.ogg"
	if not ResourceLoader.exists(STATIC_PATH):
		push_warning("Static file not found: %s" % STATIC_PATH)
		return
	var static_player := AudioStreamPlayer.new()
	static_player.bus = "Radio"
	static_player.stream = load(STATIC_PATH)
	static_player.volume_db = -10
	add_child(static_player)
	static_player.play()
	await static_player.finished
	static_player.queue_free()
	
func _play_blip() -> void:
	const STATIC_PATH := "res://Assets/Dialogue/blip.ogg"
	if not ResourceLoader.exists(STATIC_PATH):
		push_warning("Static file not found: %s" % STATIC_PATH)
		return
	var static_player := AudioStreamPlayer.new()
	static_player.bus = "Sound"
	static_player.stream = load(STATIC_PATH)
	static_player.volume_db = -10
	add_child(static_player)
	static_player.play()
	await static_player.finished
	static_player.queue_free()
	
func _play_end_blip() -> void:
	const STATIC_PATH := "res://Assets/Dialogue/end_blip.ogg"
	if not ResourceLoader.exists(STATIC_PATH):
		push_warning("Static file not found: %s" % STATIC_PATH)
		return
	var static_player := AudioStreamPlayer.new()
	static_player.bus = "Sound"
	static_player.stream = load(STATIC_PATH)
	static_player.volume_db = -10
	add_child(static_player)
	static_player.play()
	await static_player.finished
	static_player.queue_free()

func _play_torch() -> void:
	const STATIC_PATH := "res://Assets/Sound/torch.ogg"
	if not ResourceLoader.exists(STATIC_PATH):
		push_warning("Static file not found: %s" % STATIC_PATH)
		return
	var static_player := AudioStreamPlayer.new()
	static_player.bus = "Sound"
	static_player.stream = load(STATIC_PATH)
	static_player.volume_db = 5.0
	add_child(static_player)
	static_player.play()
	await static_player.finished
	static_player.queue_free()
	
func _play_oxy_torch_loop() -> void:
	if _oxy_torch_looping:
		return
	const LOOP_PATH := "res://Assets/Sound/oxy_torch_loop.ogg"
	if not ResourceLoader.exists(LOOP_PATH):
		push_warning("Loop file not found: %s" % LOOP_PATH)
		return
	var loop_player := AudioStreamPlayer.new()
	loop_player.bus = "Sound"
	loop_player.stream = load(LOOP_PATH)
	loop_player.volume_db = -30
	add_child(loop_player)
	loop_player.play()
	_loop_player = loop_player
	_oxy_torch_looping = true

var _oxy_torch_start_player: AudioStreamPlayer = null

func _play_oxy_torch() -> void:
	const STATIC_PATH := "res://Assets/Sound/oxy_torch_start.ogg"
	if not ResourceLoader.exists(STATIC_PATH):
		push_warning("Static file not found: %s" % STATIC_PATH)
		return
	var static_player := AudioStreamPlayer.new()
	static_player.bus = "Sound"
	static_player.stream = load(STATIC_PATH)
	static_player.volume_db = -30
	add_child(static_player)
	_oxy_torch_start_player = static_player
	static_player.play()
	await static_player.finished
	_oxy_torch_start_player = null
	static_player.queue_free()

func _stop_oxy_torch_loop() -> void:
	_oxy_torch_looping = false
	if is_instance_valid(_oxy_torch_start_player):
		_oxy_torch_start_player.stop()
		_oxy_torch_start_player.queue_free()
		_oxy_torch_start_player = null
	if is_instance_valid(_loop_player):
		_loop_player.stop()
		_loop_player.queue_free()
		_loop_player = null
