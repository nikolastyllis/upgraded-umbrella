extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var pivot = $CameraOrigin
@onready var camera_position_1 = $CameraPosition1
@onready var camera_position_2 = $CameraPosition2
@export var sens = 0.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var camera_lerp_speed := 8.0
var use_cam_1 := true
var target_origin_pos : Vector3

@onready var interact_ray := $CameraOrigin/SpringArm3D/Camera3D/RayCast3D
@onready var interact_label := $CameraOrigin/SpringArm3D/Camera3D/Control/Interact/Action
@onready var intercat_control := $CameraOrigin/SpringArm3D/Camera3D/Control/Interact

var current_interactable: Interactable = null

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	use_cam_1 = true
	target_origin_pos = camera_position_1.position
	pivot.position = target_origin_pos
	
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens))
		pivot.rotate_x(deg_to_rad(-event.relative.y * sens))
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(45))
		
func _process(_delta):
	update_interactable()
	
func update_interactable():
	current_interactable = null
	intercat_control.visible = false

	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()

		if collider is Interactable and collider.can_interact(self):
			current_interactable = collider
			interact_label.text = collider.action_text
			intercat_control.visible = true
		
func _physics_process(delta):
	
	var t := 1.0 - exp(-camera_lerp_speed * delta)
	pivot.position = pivot.position.lerp(target_origin_pos, t)
	
	if not is_on_floor():
		velocity.y -= gravity * delta * 2
		
	if Input.is_action_just_pressed("camera"):
		use_cam_1 = !use_cam_1
		target_origin_pos = (
			camera_position_1.position
			if use_cam_1
			else camera_position_2.position
		)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
	if Input.is_action_just_pressed("interact") and current_interactable:
		current_interactable.on_interact(self)
	
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
