class_name PlayerCharacter
extends CharacterBody3D

#@export va = 0.5
@export var view_toggle_lerp_speed := 8.0
@export var idle_animation_blend_smooth := 3
@export var mouse_idle_threshold := 0.1
@export var movement_animation_blend_smooth := 3
@export var rotation_speed := 5.0

const SPEED = 2.5
const JUMP_VELOCITY = 3

@onready var camera_origin = $CameraOrigin
@onready var camera_position_right = $CameraPosition1
@onready var camera_position_left = $CameraPosition2
@onready var interact_raycast := $CameraOrigin/SpringArm3D/Camera3D/RayCast3D
@onready var interact_action_text := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Action
@onready var interact_ui_control := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact
@onready var interact_progress_bar := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Progress
@onready var feet_raycast := $Character/FeetRay
@onready var climb_finished_raycast := $Character/ClimbFinishedRay
@onready var animation_tree: AnimationTree = $Character/Armature/AnimationTree
@onready var character := $Character
@onready var character_anchor := $CharacterAnchor

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var movement_animation_blend := Vector2.ZERO
var idle_animation_blend := 0.0
var idle_animation_blend_target := 0.0
var interaction_hold_timer := 0.0
var interaction_disabled: bool = false
var interactable: Interactable = null
var mouse_idle_timer := 0.0
var use_camera_position_right := true
var current_camera_position: Vector3
var using_ladder := false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	use_camera_position_right = true
	current_camera_position = camera_position_right.position
	camera_origin.position = current_camera_position

func _input(event):
	if not event is InputEventMouseMotion:
		return
	handle_mouse_look(event)

func _process(delta):
	update_interactable()
	update_idle_animation_blend(delta)
	handle_interact(delta)

func _physics_process(delta):
	update_camera(delta)
	handle_quit()
	check_ladder()
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if near_ladder() and not handle_ladder_jump():
		using_ladder = true
		climb_ladder(get_input_dir())
	else:
		handle_ground_movement(get_move_direction(), get_input_dir(), delta)
	update_character_rotation(rotation.y, delta)
	move_and_slide()

func get_input_dir() -> Vector2:
	return Input.get_vector("left", "right", "up", "down")

func get_move_direction() -> Vector3:
	var dir = get_input_dir()
	return (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()

func handle_mouse_look(event):
	mouse_idle_timer = 0.0
	rotate_y(deg_to_rad(-event.relative.x ))
	camera_origin.rotate_x(deg_to_rad(-event.relative.y ))
	camera_origin.rotation.x = clamp(camera_origin.rotation.x, deg_to_rad(-90), deg_to_rad(45))
	if abs(event.relative.x) > 10:
		idle_animation_blend_target = 0.5 if event.relative.x > 0 else -0.5

func update_idle_animation_blend(delta):
	mouse_idle_timer += delta
	if mouse_idle_timer > mouse_idle_threshold:
		idle_animation_blend_target = 0
	idle_animation_blend = lerp(idle_animation_blend, idle_animation_blend_target, 1.0 - exp(-idle_animation_blend_smooth * delta))
	animation_tree.set("parameters/Idle/blend_position", idle_animation_blend)

func update_camera(delta):
	var t := 1.0 - exp(-view_toggle_lerp_speed * delta)
	camera_origin.position = camera_origin.position.lerp(current_camera_position, t)
	if Input.is_action_just_pressed("camera"):
		use_camera_position_right = !use_camera_position_right
		current_camera_position = camera_position_right.position if use_camera_position_right else camera_position_left.position

func handle_quit():
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func update_character_rotation(target_rotation_y: float, delta):
	rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)
	character.rotation.y = lerp_angle(character.rotation.y, character_anchor.rotation.y, 3 * delta)

func check_ladder():
	if not feet_raycast.is_colliding():
		using_ladder = false
		return
	
func near_ladder():
	return feet_raycast.is_colliding()

func climb_ladder(input_dir: Vector2):
	var state_machine = animation_tree["parameters/playback"]
	var normal = feet_raycast.get_collision_normal()
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
		animation_tree.set("parameters/Climb/Climb Direction/scale", sign(climb_input))
	else:
		animation_tree.set("parameters/Climb/Climb Direction/scale", 0)
	if climb_finished_raycast.is_colliding() and climb_input > 0:
		finish_climbing()

func dismount_ladder():
	var launch_normal = feet_raycast.get_collision_normal()
	velocity = launch_normal * 2.0
	velocity.y = 1.0
	using_ladder = false

func finish_climbing():
	var target_pos = climb_finished_raycast.get_collision_point()
	global_position = global_position.lerp(target_pos, 0.15)
	animation_tree["parameters/playback"].travel("Finish Climbing")

func handle_ground_movement(move_direction: Vector3, input_dir: Vector2, delta):
	apply_gravity(delta)
	apply_movement(move_direction)
	update_movemement_animation(input_dir, delta)

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

func update_movemement_animation(input_dir: Vector2, delta):
	var state_machine = animation_tree["parameters/playback"]
	if not is_on_floor():
		state_machine.travel("Fall")
	elif input_dir != Vector2.ZERO:
		state_machine.travel("Move")
		movement_animation_blend = movement_animation_blend.lerp(input_dir, 1.0 - exp(-movement_animation_blend_smooth * delta))
		animation_tree.set("parameters/Move/blend_position", movement_animation_blend)
	else:
		state_machine.travel("Idle")

func handle_ladder_jump() -> bool:
	if Input.is_action_pressed("ui_accept"):
		var launch_normal = feet_raycast.get_collision_normal()
		velocity = launch_normal * JUMP_VELOCITY * 2
		velocity.y = JUMP_VELOCITY
		using_ladder = false
		return true
	return false

func handle_interact(delta):
	var state_machine = animation_tree["parameters/playback"]
	if interactable:
		if Input.is_action_pressed("interact") and not interaction_disabled:
			advance_interact_timer(delta, state_machine)
		if Input.is_action_just_released("interact"):
			reset_interact_timer()
	else:
		reset_interact_state()

func advance_interact_timer(delta, state_machine):
	interaction_hold_timer += delta
	state_machine.travel("Interact")
	var progress = interaction_hold_timer / interactable.interact_hold_time()
	interact_progress_bar.value = progress * 100
	if interaction_hold_timer >= interactable.interact_hold_time():
		interactable.on_interact(self)
		interaction_disabled = true
		interaction_hold_timer = 0.0
		interact_progress_bar.value = 0

func reset_interact_timer():
	interaction_hold_timer = 0.0
	interact_progress_bar.value = 0
	interaction_disabled = false

func reset_interact_state():
	interaction_hold_timer = 0.0
	interact_progress_bar.set_value_no_signal(0)
	interaction_disabled = false

func update_interactable():
	var new_interactable: Interactable = null
	if interact_raycast.is_colliding():
		var collider = interact_raycast.get_collider()
		if collider is Interactable and collider.can_interact(self):
			new_interactable = collider
	if new_interactable != interactable:
		if interactable:
			interactable.remove_highlight()
		interactable = new_interactable
		reset_interact_timer()
		if interactable:
			interactable.add_highlight()
	interactable = new_interactable
	if interactable:
		interact_action_text.text = interactable.action_text
		interact_ui_control.visible = true
	else:
		interact_ui_control.visible = false
