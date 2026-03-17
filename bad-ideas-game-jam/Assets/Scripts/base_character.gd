class_name BaseCharacter
extends CharacterBody3D

@export var rotation_speed := 5.0
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

var footstep_timer := 0.0
var footstep_interval := .78  # Seconds between steps

var ladder_step_timer := 0.0
var ladder_step_interval := 0.8  # Slightly faster than footsteps
var ladder_player: AudioStreamPlayer3D

var footstep_player: AudioStreamPlayer3D

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
	footstep_player.volume_db = randf_range(-20, -10)
	footstep_player.play()
	
func _play_ladder_step() -> void:
	ladder_player.pitch_scale = randf_range(0.8, 1.2)
	ladder_player.volume_db = randf_range(-20, -10)
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
	var state_machine = animation_tree["parameters/playback"]
	
	if current_ladder and current_ladder.end_y() < global_position.y and get_climb_input() > 0 and finish_climb_animation_cooldown_timer > finish_climb_animation_cooldown:
			finish_climb_animation_cooldown_timer = 0
			animation_tree["parameters/playback"].travel("Finish Climbing")
			is_finishing_climb = true
			
	if is_finishing_climb:
		return
	if is_climbing:
		state_machine.travel("Climb")
		animation_tree.set("parameters/Climb/Climb Direction/scale", sign(get_climb_input()))
	elif not is_on_floor():
		state_machine.travel("Fall")
	elif input_dir != Vector2.ZERO:
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
