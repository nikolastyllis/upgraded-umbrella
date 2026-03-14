extends Node3D

@onready var twin_1 = $"../Twin1"
@onready var twin_2 = $"../Twin2"
@onready var player = $"../Player"
@onready var container = $Locations/Container
@onready var back_right_corner = $Locations/BackRightCorner
@onready var oxy_torch = $Locations/OxyTorch
@onready var container_door = $Locations/ContainerDoor
@onready var objective_marker_prefab = "res://Prefabs/objective_marker_ui.tscn"

var player_has_oxy_torch = false
var current_objective = null
var story_increment = 1

# Dialogue
var dialogue = {
	intro = "[Azza]: Hey, you're finally awake. Come on down, we have a task for you. You're going to love it.",
	container_info = "[Azza]: Bazza says there's a suspicious container. We're going to need you to head down to the storeroom and grab the oxy torch so we can crack her open and take a look.",
	meet_bazza = "[Azza]: Alright, let's go meet Bazza at the suspicious container.",
	bazza_intro = "[Bazza]: Well you boys took your sweet time. Let's crack her open, shall we."
}

func _on_oxy_torch_picked_up() -> void:
	player_has_oxy_torch = true
	
func _on_container_door_breached() -> void:
	return

func _ready() -> void:
	oxy_torch.picked_up.connect(_on_oxy_torch_picked_up)
	container_door.breached_container_door.connect(_on_container_door_breached)
	
	player.show_dialog_text(dialogue.intro)
	twin_2.set_target_position(container.global_position)
	twin_1.set_target_position(back_right_corner.global_position)
	
	_remove_objective()
	await _wait_for(10.0)
	_spawn_objective_marker(twin_1)

func _player_is_near(position: Vector3) -> bool:
	return (player.global_position - position).length() < 2

func _process(_delta: float) -> void:
	if story_increment == 1 and _player_is_near(back_right_corner.global_position):
		story_increment += 1
		_remove_objective()
		player.show_dialog_text(dialogue.container_info)
		await _wait_for(10.0)
		_spawn_objective_marker(oxy_torch)

	if story_increment == 2 and player_has_oxy_torch:
		_remove_objective()
		_spawn_objective_marker(twin_1)
		story_increment += 1

	if story_increment == 3 and _player_is_near(back_right_corner.global_position):
		story_increment += 1
		_remove_objective()
		player.show_dialog_text(dialogue.meet_bazza)
		await _wait_for(10.0)
		twin_1.set_target_position(container.global_position)
		_spawn_objective_marker(twin_1)

	if story_increment == 4 and _player_is_near(container.global_position):
		story_increment += 1
		_remove_objective()
		player.show_dialog_text(dialogue.bazza_intro)
		await _wait_for(10.0)
		_spawn_objective_marker(container_door)

func _spawn_objective_marker(parent: Node3D) -> void:
	var packed = load(objective_marker_prefab)
	var marker = packed.instantiate()
	parent.add_child(marker)
	current_objective = marker
	
func _remove_objective() -> void:
	if current_objective:
		current_objective.queue_free()
	current_objective = null
	
func _wait_for(time: float):
	return get_tree().create_timer(time).timeout
