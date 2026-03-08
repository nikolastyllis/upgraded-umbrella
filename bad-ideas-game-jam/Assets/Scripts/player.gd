extends CharacterBase

@export var sens = 0.5
@export var camera_lerp_speed := 8.0
@export var idle_blend_smooth := 3
@export var mouse_idle_threshold := 0.1

@onready var pivot = $CameraOrigin
@onready var camera_position_1 = $CameraPosition1
@onready var camera_position_2 = $CameraPosition2
@onready var interact_ray := $CameraOrigin/SpringArm3D/Camera3D/RayCast3D
@onready var interact_label := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Action
@onready var intercat_control := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact
@onready var interact_progress_bar := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Progress

var idle_blend := 0.0
var idle_blend_target := 0.0
var interact_hold_timer := 0.0
var interact_locked: bool = false
var current_interactable: Interactable = null
var mouse_idle_time := 0.0
var use_cam_1 := true
var target_origin_pos: Vector3

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	use_cam_1 = true
	target_origin_pos = camera_position_1.position
	pivot.position = target_origin_pos

func _input(event):
	if not event is InputEventMouseMotion:
		return
	handle_mouse_look(event)

func _process(delta):
	update_interactable()
	update_idle_blend(delta)
	handle_interact(delta)

func _physics_process(delta):
	update_camera(delta)
	handle_quit()
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if near_ladder:
		handle_ladder_jump()
	super(delta)

# --- Hook overrides ---

func get_input_dir() -> Vector2:
	return Input.get_vector("left", "right", "up", "down")

func get_move_direction() -> Vector3:
	var dir = get_input_dir()
	return (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()

func get_target_rotation_y() -> float:
	return rotation.y  # Player rotates via mouse look directly

# --- Mouse look ---

func handle_mouse_look(event):
	mouse_idle_time = 0.0
	rotate_y(deg_to_rad(-event.relative.x * sens))
	pivot.rotate_x(deg_to_rad(-event.relative.y * sens))
	pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(45))
	if abs(event.relative.x) > 10:
		idle_blend_target = 0.5 if event.relative.x > 0 else -0.5

func update_idle_blend(delta):
	mouse_idle_time += delta
	if mouse_idle_time > mouse_idle_threshold:
		idle_blend_target = 0
	idle_blend = lerp(idle_blend, idle_blend_target, 1.0 - exp(-idle_blend_smooth * delta))
	anim_tree.set("parameters/Idle/blend_position", idle_blend)

# --- Camera ---

func update_camera(delta):
	var t := 1.0 - exp(-camera_lerp_speed * delta)
	pivot.position = pivot.position.lerp(target_origin_pos, t)
	if Input.is_action_just_pressed("camera"):
		use_cam_1 = !use_cam_1
		target_origin_pos = camera_position_1.position if use_cam_1 else camera_position_2.position

func handle_quit():
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

# --- Ladder jump (player only) ---

func handle_ladder_jump() -> bool:
	if Input.is_action_pressed("ui_accept"):
		var launch_normal = feet_ray.get_collision_normal()
		velocity = launch_normal * JUMP_VELOCITY * 2
		velocity.y = JUMP_VELOCITY
		use_ladder = false
		near_ladder = false
		return true
	return false

# --- Interact ---

func handle_interact(delta):
	var state_machine = anim_tree["parameters/playback"]
	if current_interactable:
		if Input.is_action_pressed("interact") and not interact_locked:
			advance_interact_timer(delta, state_machine)
		if Input.is_action_just_released("interact"):
			reset_interact_timer()
	else:
		reset_interact_state()

func advance_interact_timer(delta, state_machine):
	interact_hold_timer += delta
	state_machine.travel("Interact")
	var progress = interact_hold_timer / current_interactable.interact_hold_time()
	interact_progress_bar.value = progress * 100
	if interact_hold_timer >= current_interactable.interact_hold_time():
		current_interactable.on_interact(self)
		interact_locked = true
		interact_hold_timer = 0.0
		interact_progress_bar.value = 0

func reset_interact_timer():
	interact_hold_timer = 0.0
	interact_progress_bar.value = 0
	interact_locked = false

func reset_interact_state():
	interact_hold_timer = 0.0
	interact_progress_bar.set_value_no_signal(0)
	interact_locked = false

func update_interactable():
	var new_interactable: Interactable = null
	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider is Interactable and collider.can_interact(self):
			new_interactable = collider
	if new_interactable != current_interactable:
		if current_interactable:
			current_interactable.remove_highlight()
		current_interactable = new_interactable
		reset_interact_timer()
		if current_interactable:
			current_interactable.add_highlight()
	current_interactable = new_interactable
	if current_interactable:
		interact_label.text = current_interactable.action_text
		intercat_control.visible = true
	else:
		intercat_control.visible = false
