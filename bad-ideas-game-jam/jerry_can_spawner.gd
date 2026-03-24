extends Node3D

func _ready():
	if randf() < 0.5:
		var jerry_can_scene = load("res://Prefabs/jerry_can.tscn")
		var jerry_can = jerry_can_scene.instantiate()
		add_child(jerry_can)
		jerry_can.global_transform = global_transform
