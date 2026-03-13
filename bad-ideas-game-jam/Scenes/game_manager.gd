extends Node3D

@onready var billy = $"../Billy"
@onready var bob = $"../Bob"
@onready var player = $"../Player"
@onready var container = $Locations/Container
@onready var back_right_corner = $Locations/BackRightCorner
@onready var oxy_torch = $Locations/OxyTorch
@onready var objective_marker_prefab = "res://Prefabs/objective_marker_ui.tscn"

var current_objective = null
var story_increment = 1

func _on_oxy_torch_picked_up() -> void:
	_remove_objective()
	player.set_objective_text("Meet Billy Again on the ship deck")
	_spawn_objective_marker(billy)
	story_increment += 1

func _ready() -> void:
	oxy_torch.picked_up.connect(_on_oxy_torch_picked_up)
	bob.set_target_position(container.global_position)
	billy.set_target_position(back_right_corner.global_position)
	player.set_objective_text("Meet Billy on the ship deck")
	_spawn_objective_marker(billy)
	
func _player_is_near(position: Vector3) -> bool:
	return (player.global_position - position).length() < 2

func _process(_delta: float) -> void:
	if story_increment == 1 and _player_is_near(back_right_corner.global_position):
		_remove_objective()
		player.set_objective_text("Retrieve the oxy-acetylene torch from the store room")
		_spawn_objective_marker(oxy_torch)
		story_increment += 1
	if story_increment == 3 and _player_is_near(back_right_corner.global_position):
		_remove_objective()
		player.set_objective_text("Follow Billy to meet Bob at the suspicious container")
		billy.set_target_position(container.global_position)
		_spawn_objective_marker(billy)
		story_increment += 1
		
func _spawn_objective_marker(parent: Node3D) -> void:
	var packed = load(objective_marker_prefab)
	var marker = packed.instantiate()
	parent.add_child(marker)
	current_objective = marker
	
func _remove_objective() -> void:
	current_objective.remove()
	current_objective = null
