extends Node3D

@onready var area := $Area
@onready var navigation_link := $NavigationLink3D

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.start_climbing(self)
		
func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		body.stop_climbing()
		
func end_y() -> float:
	return navigation_link.to_global(navigation_link.end_position).y
	
func start_y() -> float:
	return navigation_link.to_global(navigation_link.start_position).y
