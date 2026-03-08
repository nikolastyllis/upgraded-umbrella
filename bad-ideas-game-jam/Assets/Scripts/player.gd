extends CharacterBody3D

@export var sens = 0.5
@export var camera_lerp_speed := 8.0
@export var anim_blend_smooth := 3
@export var idle_blend_smooth := 3
@export var mouse_idle_threshold := 0.1

@onready var pivot = $CameraOrigin
@onready var camera_position_1 = $CameraPosition1
@onready var camera_position_2 = $CameraPosition2
@onready var interact_ray := $CameraOrigin/SpringArm3D/Camera3D/RayCast3D
@onready var interact_label := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Action
@onready var intercat_control := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact
@onready var interact_progress_bar := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Progress
@onready var feet_ray := $test_character/FeetRay
@onready var climb_finished_ray := $test_character/ClimbFinishedRay
@onready var anim_tree: AnimationTree = $test_character/AnimationTree
@onready var anim_player: AnimationPlayer = $test_character/AnimationPlayer
@onready var character := $test_character

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var anim_blend := Vector2.ZERO
var idle_blend := 0.0
var idle_blend_target := 0.0
var interact_hold_timer := 0.0
var interact_locked: bool = false
var current_interactable: Interactable = null
var mouse_idle_time := 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var use_cam_1 := true
var target_origin_pos : Vector3
var near_ladder = false
var use_ladder = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	use_cam_1 = true
	target_origin_pos = camera_position_1.position
	pivot.position = target_origin_pos
	
func _input(event):
	if event is InputEventMouseMotion:
		mouse_idle_time = 0.0
		rotate_y(deg_to_rad(-event.relative.x))
		pivot.rotate_x(deg_to_rad(-event.relative.y))
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(45))

		if abs(event.relative.x) > 10:
			if event.relative.x > 0:
				idle_blend_target = 0.5
			elif event.relative.x < 0:
				idle_blend_target = -0.5

func _process(delta):
	update_interactable()
	
	mouse_idle_time += delta
	
	if mouse_idle_time > mouse_idle_threshold:
		idle_blend_target = 0

	idle_blend = lerp(idle_blend, idle_blend_target, 1.0 - exp(-idle_blend_smooth * delta))
	anim_tree.set("parameters/Idle/blend_position", idle_blend)
	
	var state_machine = anim_tree["parameters/playback"]

	if current_interactable:
		if Input.is_action_pressed("interact") and !interact_locked:
			interact_hold_timer += delta
			
			state_machine.travel("Interact")
			
			var progress = interact_hold_timer / current_interactable.interact_hold_time()
			interact_progress_bar.value = progress * 100

			if interact_hold_timer >= current_interactable.interact_hold_time():
				current_interactable.on_interact(self)
				interact_locked = true
				interact_hold_timer = 0.0
				interact_progress_bar.value = 0

		if Input.is_action_just_released("interact"):
			interact_hold_timer = 0.0
			interact_progress_bar.value = 0
			interact_locked = false

	else:
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

		interact_hold_timer = 0.0
		interact_progress_bar.value = 0
		interact_locked = false
		
		if current_interactable:
			current_interactable.add_highlight()

	current_interactable = new_interactable

	if current_interactable:
		interact_label.text = current_interactable.action_text
		intercat_control.visible = true
	else:
		intercat_control.visible = false

func climb_ladder():
	var state_machine = anim_tree["parameters/playback"]
	
	var normal = feet_ray.get_collision_normal()
	character.look_at(global_position + normal, Vector3.UP)
	character.rotation.x = 0
	character.rotation.z = 0
	velocity = Vector3.ZERO
	
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	var climb_input = -direction.z
	
	if climb_input != 0:
		velocity.y = climb_input
		state_machine.travel("Climb")
		if climb_input > 0:
			anim_tree.set("parameters/Climb/Climb Direction/scale", 1)
		else:
			anim_tree.set("parameters/Climb/Climb Direction/scale", -1)
	else:
		anim_tree.set("parameters/Climb/Climb Direction/scale", 0)
	
	if climb_finished_ray.is_colliding():
		var target_pos = climb_finished_ray.get_collision_point()
		global_position = global_position.lerp(target_pos, 0.15)
		state_machine.travel("Finish Climbing")

		if global_position.distance_to(target_pos) < 0.05:
			use_ladder = false
			velocity = Vector3.ZERO
			state_machine.travel("Idle")

func _physics_process(delta):
	
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var t := 1.0 - exp(-camera_lerp_speed * delta)
	pivot.position = pivot.position.lerp(target_origin_pos, t)
	
	if Input.is_action_just_pressed("camera"):
		use_cam_1 = !use_cam_1
		target_origin_pos = (
			camera_position_1.position
			if use_cam_1
			else camera_position_2.position
		)
		
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	
	if not feet_ray.is_colliding():
		near_ladder = false
		use_ladder = false
		
	near_ladder = feet_ray.is_colliding()
	
	if near_ladder:
		use_ladder = true;
		climb_ladder()
	else:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		if not is_on_floor():
			velocity.y -= gravity * delta
	
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			
		var state_machine = anim_tree["parameters/playback"]
	
		if not is_on_floor():
			state_machine.travel("Fall")
		elif input_dir != Vector2.ZERO:
			state_machine.travel("Move")
			var target_blend: Vector2 = input_dir
			anim_blend = anim_blend.lerp(target_blend, 1.0 - exp(-anim_blend_smooth * delta))
			anim_tree.set("parameters/Move/blend_position", anim_blend)
		else:
			state_machine.travel("Idle")

	move_and_slide()
		
	
	
