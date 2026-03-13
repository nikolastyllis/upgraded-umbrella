extends "base_character.gd"

@export var view_toggle_lerp_speed := 8.0
@export var idle_animation_blend_smooth := 3
@export var mouse_idle_threshold := 0.1

@onready var camera_origin = $CameraOrigin
@onready var camera_position_right = $CameraPosition1
@onready var camera_position_left = $CameraPosition2
@onready var interact_raycast := $CameraOrigin/SpringArm3D/Camera3D/RayCast3D
@onready var interact_action_text := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Action
@onready var interact_ui_control := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact
@onready var interact_progress_bar := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Progress

const PLAYER_SPEED = 2.5
const JUMP_VELOCITY = 3

var idle_animation_blend := 0.0
var idle_animation_blend_target := 0.0
var interaction_hold_timer := 0.0
var interaction_disabled: bool = false
var interactable: Interactable = null
var mouse_idle_timer := 0.0
var use_camera_position_right := true
var current_camera_position: Vector3
var reset_camera_y := false
var is_free_looking := false

func _ready() -> void:
	super._ready()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	use_camera_position_right = true
	current_camera_position = camera_position_right.position
	camera_origin.position = current_camera_position

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	handle_mouse_look(event)

func _process(delta: float) -> void:
	update_interactable()
	update_idle_animation_blend(delta)
	handle_interact(delta)

func _apply_free_look():
	if Input.is_action_pressed("free_look"):
		is_free_looking = true
	else:
		is_free_looking = false
		reset_camera_y = true

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	update_camera(delta)
	handle_quit()
	if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or is_climbing):
		velocity.y = JUMP_VELOCITY
		if is_climbing:
			stop_climbing()
	apply_gravity(delta)
	apply_movement(get_raw_input_dir())
	update_movement_animation(get_raw_input_dir(), delta)
	update_character_rotation(rotation.y, delta)
	move_and_slide()
	reset_camera()
	dismount_ladder()
	update_climb_position()
	_apply_free_look()
	if climb_cooldown > 0:
		climb_cooldown -= delta
		
func get_speed() -> float:
	return PLAYER_SPEED

func get_climb_input() -> float:
	return -get_raw_input_dir().y

func stop_climbing() -> void:
	super.stop_climbing()

func get_raw_input_dir() -> Vector2:
	return Input.get_vector("left", "right", "up", "down")

func get_move_direction() -> Vector3:
	var dir = get_raw_input_dir()
	return (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()

func apply_movement(_input_dir: Vector2) -> void:
	if is_climbing:
		apply_climbing_movement()
		return
	var move_direction = get_move_direction()
	if move_direction.length() > 0.01:
		velocity.x = move_direction.x * PLAYER_SPEED
		velocity.z = move_direction.z * PLAYER_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, PLAYER_SPEED)
		velocity.z = move_toward(velocity.z, 0, PLAYER_SPEED)

func dismount_ladder() -> void:
	if is_climbing and is_on_floor() and get_climb_input() < 0 and current_ladder.end_y() > global_position.y:
		stop_climbing()

func reset_camera() -> void:
	if reset_camera_y:
		camera_origin.rotation.y = lerp_angle(camera_origin.rotation.y, 0.0, 0.1)
		if abs(camera_origin.rotation.y) < 0.001:
			camera_origin.rotation.y = 0.0
			reset_camera_y = false

func update_camera(delta: float) -> void:
	var t := 1.0 - exp(-view_toggle_lerp_speed * delta)
	camera_origin.position = camera_origin.position.lerp(current_camera_position, t)
	if Input.is_action_just_pressed("camera"):
		use_camera_position_right = !use_camera_position_right
		current_camera_position = camera_position_right.position if use_camera_position_right else camera_position_left.position

func handle_mouse_look(event: InputEventMouseMotion) -> void:
	mouse_idle_timer = 0.0
	var y_flip = cos(camera_origin.rotation.y)
	camera_origin.rotate_x(deg_to_rad(-event.relative.y) * sign(y_flip) if abs(y_flip) > 0.01 else deg_to_rad(-event.relative.y))
	camera_origin.rotation.x = clamp(camera_origin.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	camera_origin.rotation.z = 0
	
	if is_free_looking:
		camera_origin.rotate_y(deg_to_rad(-event.relative.x))
	else:
		if not is_climbing: 
			rotate_y(deg_to_rad(-event.relative.x))
		if abs(event.relative.x) > 10:
			idle_animation_blend_target = 0.5 if event.relative.x > 0 else -0.5

func update_idle_animation_blend(delta: float) -> void:
	mouse_idle_timer += delta
	if mouse_idle_timer > mouse_idle_threshold:
		idle_animation_blend_target = 0
	idle_animation_blend = lerp(idle_animation_blend, idle_animation_blend_target, 1.0 - exp(-idle_animation_blend_smooth * delta))
	animation_tree.set("parameters/Idle/blend_position", idle_animation_blend)

func handle_quit() -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func handle_interact(delta: float) -> void:
	var state_machine = animation_tree["parameters/playback"]
	if interactable:
		if Input.is_action_pressed("interact") and not interaction_disabled:
			advance_interact_timer(delta, state_machine)
		if Input.is_action_just_released("interact"):
			reset_interact_timer()
	else:
		reset_interact_state()

func advance_interact_timer(delta: float, state_machine: AnimationNodeStateMachinePlayback) -> void:
	interaction_hold_timer += delta
	state_machine.travel("Interact")
	var progress = interaction_hold_timer / interactable.interact_hold_time()
	interact_progress_bar.value = progress * 100
	if interaction_hold_timer >= interactable.interact_hold_time():
		interactable.on_interact(self)
		interaction_disabled = true
		interaction_hold_timer = 0.0
		interact_progress_bar.value = 0

func reset_interact_timer() -> void:
	interaction_hold_timer = 0.0
	interact_progress_bar.value = 0
	interaction_disabled = false

func reset_interact_state() -> void:
	interaction_hold_timer = 0.0
	interact_progress_bar.set_value_no_signal(0)
	interaction_disabled = false

func update_interactable() -> void:
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
