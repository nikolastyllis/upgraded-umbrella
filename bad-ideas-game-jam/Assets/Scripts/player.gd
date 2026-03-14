extends BaseCharacter

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
@onready var dialog_text := $CameraOrigin/SpringArm3D/Camera3D/Dialog/DialogText
@onready var dialog_control := $CameraOrigin/SpringArm3D/Camera3D/Dialog
@onready var dialog_animation_player := $CameraOrigin/SpringArm3D/Camera3D/Dialog/AnimationPlayer

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

func _ready() -> void:
	super._ready()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	use_camera_position_right = false
	current_camera_position = camera_position_left.position
	camera_origin.position = current_camera_position

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	handle_mouse_look(event)

func _process(delta: float) -> void:
	update_interactable()
	update_idle_animation_blend(delta)
	handle_interact(delta)

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
	dismount_ladder()
	update_climb_position()
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
	if dir.length() < 0.01:
		return Vector3.ZERO
	# Movement is relative to where the camera is looking, not where the character faces
	var cam_forward = -camera_origin.global_transform.basis.z
	var cam_right = camera_origin.global_transform.basis.x
	cam_forward.y = 0
	cam_right.y = 0
	return (cam_right * dir.x + cam_forward * -dir.y).normalized()

func apply_movement(_input_dir: Vector2) -> void:
	if is_climbing:
		apply_climbing_movement()
		return
	var move_direction = get_move_direction()
	if move_direction.length() > 0.01:
		velocity.x = move_direction.x * PLAYER_SPEED
		velocity.z = move_direction.z * PLAYER_SPEED
		# Rotate character smoothly toward movement direction
		var target_angle = atan2(move_direction.x, move_direction.z)
		var old_y = rotation.y
		var t = 1.0 - exp(-10.0 * get_physics_process_delta_time())
		rotation.y = lerp_angle(rotation.y, target_angle, t)
		# Counter-rotate camera_origin so it keeps pointing the same world direction
		camera_origin.rotation.y += old_y - rotation.y
	else:
		velocity.x = move_toward(velocity.x, 0, PLAYER_SPEED)
		velocity.z = move_toward(velocity.z, 0, PLAYER_SPEED)

func dismount_ladder() -> void:
	if is_climbing and is_on_floor() and get_climb_input() < 0 and current_ladder.end_y() > global_position.y:
		stop_climbing()

func update_camera(delta: float) -> void:
	var t := 1.0 - exp(-view_toggle_lerp_speed * delta)
	camera_origin.position = camera_origin.position.lerp(current_camera_position, t)
	if Input.is_action_just_pressed("camera"):
		use_camera_position_right = !use_camera_position_right
		current_camera_position = camera_position_right.position if use_camera_position_right else camera_position_left.position

func handle_mouse_look(event: InputEventMouseMotion) -> void:
	mouse_idle_timer = 0.0
	# Directly set euler angles so pitch and yaw never interfere with each other
	camera_origin.rotation.x -= deg_to_rad(event.relative.y * 0.5)
	camera_origin.rotation.x = clamp(camera_origin.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	camera_origin.rotation.y -= deg_to_rad(event.relative.x * 0.5)
	camera_origin.rotation.z = 0
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

func show_dialog_text(dialog: String) -> void:
	dialog_control.visible = true
	dialog_text.text = dialog
	dialog_animation_player.play("Dialog")

func update_interactable() -> void:
	var new_interactable: Interactable = null
	if interact_raycast.is_colliding():
		var collider = interact_raycast.get_collider()
		if collider is Interactable and collider.can_interact(self):
			new_interactable = collider
	# While actively holding an interaction, keep the current interactable locked in
	# so looking away doesn't cancel the hold progress
	if interaction_hold_timer > 0 and interactable != null and Input.is_action_pressed("interact"):
		interact_ui_control.visible = true
		return
	if new_interactable != interactable:
		interactable = new_interactable
		reset_interact_timer()
	interactable = new_interactable
	if interactable:
		interact_action_text.text = interactable.action_text
		interact_ui_control.visible = true
	else:
		interact_ui_control.visible = false

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	await get_tree().create_timer(10.0).timeout
	dialog_control.visible = false
	dialog_text.text = ""
