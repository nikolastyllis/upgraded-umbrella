extends MeshInstance3D
@export var y_level := 0.0

func _process(_dt):
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position.x = cam.global_position.x
		global_position.z = cam.global_position.z
		global_position.y = y_level
