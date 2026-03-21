extends Node3D

@onready var skeleton: Skeleton3D = $rigged_container/Skeleton3D
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready():
	anim.animation_finished.connect(_on_animation_finished)

func open_door():
	anim.play("DoorOpen_01")

func _on_animation_finished(anim_name: StringName):
	if anim_name == "DoorOpen_01":
		skeleton.physical_bones_start_simulation()
