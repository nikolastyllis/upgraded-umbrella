class_name CharacterBase
extends CharacterBody3D

@export var anim_blend_smooth := 3
@export var rotation_speed := 5.0

@onready var feet_ray := $Character/FeetRay
@onready var climb_finished_ray := $Character/ClimbFinishedRay
@onready var anim_tree: AnimationTree = $Character/Armature/AnimationTree
@onready var anim_player: AnimationPlayer = $Character/Armature/AnimationPlayer
@onready var character := $Character
@onready var character_anchor := $CharacterAnchor

const SPEED = 2.5
const JUMP_VELOCITY = 3

var anim_blend := Vector2.ZERO
var near_ladder = false
var use_ladder = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Overridden by child classes to supply movement intent each frame
func get_move_direction() -> Vector3: return Vector3.ZERO
func get_input_dir() -> Vector2: return Vector2.ZERO
func get_target_rotation_y() -> float: return rotation.y

func handle_ladder_jump() -> bool:
	return false

func _physics_process(delta):
	check_ladder()
	
	if near_ladder and not handle_ladder_jump():
		use_ladder = true
		climb_ladder(get_input_dir())
	else:
		handle_ground_movement(get_move_direction(), get_input_dir(), delta)

	update_character_rotation(get_target_rotation_y(), delta)
	move_and_slide()

func update_character_rotation(target_rotation_y: float, delta):
	rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)
	character.rotation.y = lerp_angle(character.rotation.y, character_anchor.rotation.y, 3 * delta)

func check_ladder():
	if not feet_ray.is_colliding():
		near_ladder = false
		use_ladder = false
		return
	near_ladder = true

func climb_ladder(input_dir: Vector2):
	var state_machine = anim_tree["parameters/playback"]
	var normal = feet_ray.get_collision_normal()
	character.look_at(global_position + normal, Vector3.UP)
	character.rotation.x = 0
	character.rotation.z = 0
	velocity = Vector3.ZERO
	var climb_input = -input_dir.y
	if is_on_floor() and climb_input < 0:
		dismount_ladder()
		return
	if climb_input != 0:
		velocity.y = climb_input
		state_machine.travel("Climb")
		anim_tree.set("parameters/Climb/Climb Direction/scale", sign(climb_input))
	else:
		anim_tree.set("parameters/Climb/Climb Direction/scale", 0)
	if climb_finished_ray.is_colliding() and climb_input > 0:
		finish_climbing()

func dismount_ladder():
	var launch_normal = feet_ray.get_collision_normal()
	velocity = launch_normal * 2.0
	velocity.y = 1.0
	use_ladder = false
	near_ladder = false

func finish_climbing():
	var target_pos = climb_finished_ray.get_collision_point()
	global_position = global_position.lerp(target_pos, 0.15)
	anim_tree["parameters/playback"].travel("Finish Climbing")

func handle_ground_movement(move_direction: Vector3, input_dir: Vector2, delta):
	apply_gravity(delta)
	apply_movement(move_direction)
	update_movement_anim(input_dir, delta)

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

func apply_movement(move_direction: Vector3):
	if move_direction.length() > 0.01:
		velocity.x = move_direction.x * SPEED
		velocity.z = move_direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

func update_movement_anim(input_dir: Vector2, delta):
	var state_machine = anim_tree["parameters/playback"]
	if not is_on_floor():
		state_machine.travel("Fall")
	elif input_dir != Vector2.ZERO:
		state_machine.travel("Move")
		anim_blend = anim_blend.lerp(input_dir, 1.0 - exp(-anim_blend_smooth * delta))
		anim_tree.set("parameters/Move/blend_position", anim_blend)
	else:
		state_machine.travel("Idle")
