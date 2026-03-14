class_name BaseCharacter
extends CharacterBody3D

@export var movement_animation_blend_smooth := 3
@export var rotation_speed := 5.0

@onready var animation_tree: AnimationTree = $Character/Armature/AnimationTree
@onready var character := $Character
@onready var character_anchor := $CharacterAnchor

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var movement_animation_blend := Vector2.ZERO
var is_climbing := false
var current_ladder: Node3D = null
var climb_cooldown := 0.0
var is_finishing_climb := false
var finish_climb_animation_cooldown_timer = 0.0
var finish_climb_animation_cooldown = 4.0


func _physics_process(delta: float) -> void:
	finish_climb_animation_cooldown_timer += delta

func _ready() -> void:
	animation_tree.animation_finished.connect(_on_animation_finished)

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
		rotation.y = lerp_angle(rotation.y, current_ladder.rotation.y + deg_to_rad(90), 0.15)
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

func update_movement_animation(input_dir: Vector2, delta: float) -> void:
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
		movement_animation_blend = movement_animation_blend.lerp(input_dir, 1.0 - exp(-movement_animation_blend_smooth * delta))
		animation_tree.set("parameters/Move/blend_position", movement_animation_blend)
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
