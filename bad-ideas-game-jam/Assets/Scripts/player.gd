class_name Player
extends BaseCharacter

@export var view_toggle_lerp_speed := 8.0

@onready var camera_origin = $CameraOrigin
@onready var camera_position_right = $CameraPosition1
@onready var camera_position_left = $CameraPosition2
@onready var interact_raycast := $CameraOrigin/SpringArm3D/Camera3D/RayCast3D
@onready var interact_action_text := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Action
@onready var interact_ui_control := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact
@onready var interact_progress_bar := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI/Interact/Progress
@onready var dialog_control := $CameraOrigin/SpringArm3D/Camera3D/DialogControl
@onready var crosshair_ui := $CameraOrigin/SpringArm3D/Camera3D/CrosshairUI

@onready var tool_tip: Node3D = $Character/Armature/Skeleton3D/RightHandAttachment/ToolTip
@onready var skeleton: Skeleton3D = $Character/Armature/Skeleton3D
@onready var right_hand_ik: SkeletonIK3D = $Character/Armature/Skeleton3D/RightHandIK
var _ik_target_node: Node3D = null
var _ik_tool_local_offset: Vector3 = Vector3.ZERO

@onready var sparks := $Sparks
@onready var spark_light := $Sparks/Light

@onready var torch = $SpotLight3D

@onready var camera := $CameraOrigin/SpringArm3D/Camera3D

const FOV_NORMAL := 80.0
const FOV_DISABLED := 60.0

const SENSITIVITY_NORMAL = 0.25
const SENSITIVITY_DISABLED = 0.1

const PLAYER_SPEED = 1.5
const JUMP_VELOCITY = 3
const DIALOG_SCENE = preload("res://Prefabs/dialog.tscn")

var is_interacting: bool = false
var is_container_door_interaction: bool = false
const SENSITIVITY_INTERACT = 0.005
const FOV_INTERACT := 70.0

var sensitivity := 0.25
var interaction_hold_timer := 0.0
var interaction_disabled: bool = false
var can_interact: bool = true
var has_oxy_torch: bool = false
var interactable: Interactable = null
var use_camera_position_right := true
var current_camera_position: Vector3
var dialog_hide_timer: SceneTreeTimer = null
var movement_disabled = false

func _start_right_hand_ik(world_target: Vector3) -> void:
	var tip_bone_idx    := skeleton.find_bone("mixamorig_RightHandIndex4")
	var tip_bone_xform  := skeleton.global_transform * skeleton.get_bone_global_pose(tip_bone_idx)
	var tool_world_pos  := tip_bone_xform * _ik_tool_local_offset
	var tip_world_pos   := tip_bone_xform.origin
	_ik_target_node.global_position = world_target + (tip_world_pos - tool_world_pos)
	right_hand_ik.start()

func _stop_right_hand_ik() -> void:
	right_hand_ik.stop()
	
func _exit_tree() -> void:
	if _ik_target_node:
		_ik_target_node.queue_free()

func _setup_right_hand_ik() -> void:
	_ik_target_node = Node3D.new()
	get_tree().root.add_child(_ik_target_node)

	right_hand_ik.root_bone     = "mixamorig_RightArm"
	right_hand_ik.tip_bone      = "mixamorig_RightHandIndex4"
	right_hand_ik.interpolation = 1.0
	right_hand_ik.use_magnet    = true
	right_hand_ik.magnet        = Vector3(0.5, 0.0, 0.5)
	right_hand_ik.target_node   = _ik_target_node.get_path()
	right_hand_ik.stop()

	# Snapshot offset in tip bone's LOCAL space — valid regardless of hand pose
	var tip_bone_idx   := skeleton.find_bone("mixamorig_RightHandIndex4")
	var tip_bone_xform := skeleton.global_transform * skeleton.get_bone_global_pose(tip_bone_idx)
	_ik_tool_local_offset = tip_bone_xform.affine_inverse() * tool_tip.global_position

func _ready() -> void:
	super._ready()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	use_camera_position_right = false
	current_camera_position = camera_position_left.position
	camera_origin.position = current_camera_position
	torch.light_energy = 0.0
	sparks.visible = false
	spark_light.visible = false
	_setup_right_hand_ik()

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	handle_mouse_look(event)

func toggle_movement_disabled():
	movement_disabled = not movement_disabled
	crosshair_ui.visible = not movement_disabled
	tween_camera_fov(FOV_DISABLED if movement_disabled else FOV_NORMAL)
	sensitivity = SENSITIVITY_DISABLED if movement_disabled else SENSITIVITY_NORMAL
	can_interact = false if movement_disabled else true
	var npcs = get_tree().get_nodes_in_group("npcs")
	if movement_disabled:
		velocity.x = 0
		velocity.z = 0
		var state_machine = animation_tree["parameters/AnimationNodeStateMachine/playback"]
		state_machine.travel("Idle")
	if movement_disabled and npcs.size() >= 2:
		var midpoint = (npcs[0].global_position + npcs[1].global_position) * 0.5
		var direction = (midpoint - global_position)
		direction.y = 0
		if direction.length() > 0.01:
			var target_angle = atan2(direction.x, direction.z)
			var tween = create_tween()
			tween.tween_method(
				func(angle: float): rotation.y = angle,
				rotation.y,
				target_angle,
				0.4
			).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

func tween_camera_fov(target_fov: float) -> void:
	var tween = create_tween()
	tween.tween_property(camera, "fov", target_fov, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

func _process(delta: float) -> void:
	update_interactable()
	handle_interact(delta)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	update_camera(delta)
	handle_quit()
	if Input.is_action_just_pressed("ui_accept") and is_climbing:
		if is_climbing:
			stop_climbing()
			
	if Input.is_action_just_pressed("torch"):
		await _play_torch()
		if torch.light_energy == 2.0:
			torch.light_energy = 0.0
		else:
			torch.light_energy = 2.0
			
	apply_gravity(delta)
	
	if not movement_disabled:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_climbing:
			velocity.y = JUMP_VELOCITY
		apply_movement(get_raw_input_dir())
		update_movement_animation(get_raw_input_dir())
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

func get_player():
	return self

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
	is_jogging = Input.is_action_pressed("shift") and get_move_direction().length() > 0.01 and not has_oxy_torch
	var speed = PLAYER_SPEED * (2.0 if is_jogging else 1.0)
	var move_direction = get_move_direction()
	if move_direction.length() > 0.01:
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
		var target_angle = atan2(move_direction.x, move_direction.z)
		var old_y = rotation.y
		var t = 1.0 - exp(-4.0 * get_physics_process_delta_time())
		rotation.y = lerp_angle(rotation.y, target_angle, t)
		camera_origin.rotation.y += old_y - rotation.y
	else:
		is_jogging = false
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
	if is_container_door_interaction:
		rotation.y -= deg_to_rad(event.relative.x * SENSITIVITY_INTERACT)
		camera_origin.rotation.x -= deg_to_rad(event.relative.y * SENSITIVITY_INTERACT)
		camera_origin.rotation.x = clamp(camera_origin.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		return

	camera_origin.rotation.x -= deg_to_rad(event.relative.y * sensitivity)
	camera_origin.rotation.x = clamp(camera_origin.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	camera_origin.rotation.y -= deg_to_rad(event.relative.x * sensitivity)
	camera_origin.rotation.z = 0

func handle_quit() -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func handle_interact(delta: float) -> void:
	if not can_interact:
		return
	var state_machine = animation_tree["parameters/AnimationNodeStateMachine/playback"]
	if interactable:
		if Input.is_action_pressed("interact") and not interaction_disabled:
			advance_interact_timer(delta, state_machine)
		if Input.is_action_just_released("interact"):
			reset_interact_timer()
	else:
		reset_interact_state()

func advance_interact_timer(delta: float, state_machine: AnimationNodeStateMachinePlayback) -> void:
	var current = interactable
	if current == null:
		reset_interact_timer()
		return
	if is_container_door_interaction and (not interact_raycast.is_colliding() or interact_raycast.get_collider() != current):
		reset_interact_timer()
		return
	if not is_interacting:
		is_interacting = true
		movement_disabled = true
		is_container_door_interaction = current is BaseContainerDoor
		if is_container_door_interaction:
			tween_camera_fov(FOV_INTERACT)
			_play_oxy_torch() 

	if is_container_door_interaction and interact_raycast.is_colliding():
		var hit_point: Vector3 = interact_raycast.get_collision_point()
		var normal: Vector3    = interact_raycast.get_collision_normal()

		var x_axis   = normal
		var arbitrary = Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		var z_axis   = x_axis.cross(arbitrary).normalized()
		var y_axis   = z_axis.cross(x_axis).normalized()
		sparks.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), hit_point)

		if interactable == null or not is_interacting:
			_stop_oxy_torch_loop()
			_stop_right_hand_ik()   # ← stop IK if interaction lost
			sparks.visible      = false
			spark_light.visible = false
			return

		_play_oxy_torch_loop()
		_start_right_hand_ik(hit_point)   # ← drive IK to the spark point
		sparks.visible      = true
		spark_light.visible = true
	else:
		_stop_oxy_torch_loop()
		_stop_right_hand_ik()             # ← no collision, release IK
		sparks.visible      = false
		spark_light.visible = false

	interaction_hold_timer += delta
	if not is_container_door_interaction:
		state_machine.travel("Interact")
	var progress = interaction_hold_timer / current.interact_hold_time()
	interact_progress_bar.value = progress * 100
	if interaction_hold_timer >= current.interact_hold_time():
		current.on_interact(self)
		interaction_disabled = true
		interaction_hold_timer = 0.0
		interact_progress_bar.value = 0
		reset_interaction_state()
# --- update reset_interaction_state to kill IK on cancel/complete ---

func reset_interaction_state() -> void:
	if is_interacting:
		is_interacting = false
		movement_disabled = false
		if is_container_door_interaction:
			tween_camera_fov(FOV_NORMAL)
		is_container_door_interaction = false
		sparks.visible      = false
		spark_light.visible = false
		_stop_oxy_torch_loop()
		_stop_right_hand_ik()

func reset_interact_timer() -> void:
	interaction_hold_timer = 0.0
	interact_progress_bar.value = 0
	interaction_disabled = false
	reset_interaction_state()

func reset_interact_state() -> void:
	interaction_hold_timer = 0.0
	interact_progress_bar.set_value_no_signal(0)
	interaction_disabled = false
	reset_interaction_state()

func update_interactable() -> void:
	if not can_interact:
		return
	var new_interactable: Interactable = null
	if interact_raycast.is_colliding():
		var collided_interactable = interact_raycast.get_collider()
		if collided_interactable is Interactable and collided_interactable.can_interact(self):
			new_interactable = collided_interactable
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

func show_dialog_text(dialog: String) -> void:
	var instance = DIALOG_SCENE.instantiate()
	dialog_control.add_child(instance)
	instance.get_node("DialogText").text = dialog
	instance.get_node("AnimationPlayer").play("Dialog")
	get_tree().create_timer(10.0).timeout.connect(func():
		if is_instance_valid(instance):
			instance.queue_free()
	)
	
const INSIDE_RAY_COUNT  := 1000
const INSIDE_RAY_LENGTH := 100

func is_inside() -> bool:
	var space := get_world_3d().direct_space_state
	var origin := global_position
	var hits := 0

	for i in INSIDE_RAY_COUNT:
		var theta := acos(1.0 - 2.0 * (i + 0.5) / INSIDE_RAY_COUNT)
		var phi   := PI * (1.0 + sqrt(5.0)) * i
		var dir   := Vector3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))

		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * INSIDE_RAY_LENGTH)
		query.collision_mask = 8
		if space.intersect_ray(query):
			hits += 1

	return hits >= INSIDE_RAY_COUNT * 0.99

var _fade_layer: CanvasLayer = null

func fade_out_camera(duration: float = 1.0) -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128
	add_child(_fade_layer)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	_fade_layer.add_child(overlay)
	overlay.position = Vector2.ZERO
	overlay.size = get_viewport().get_visible_rect().size
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, duration).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func fade_in_camera(duration: float = 1.0) -> void:
	var canvas_layer: CanvasLayer
	if _fade_layer:
		canvas_layer = _fade_layer
		_fade_layer = null
	else:
		canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 128
		add_child(canvas_layer)
		@warning_ignore("confusable_local_declaration")
		var overlay := ColorRect.new()
		overlay.color = Color.BLACK
		canvas_layer.add_child(overlay)
		overlay.position = Vector2.ZERO
		overlay.size = get_viewport().get_visible_rect().size

	var overlay := canvas_layer.get_child(0) as ColorRect
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.0, duration).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	canvas_layer.queue_free()
