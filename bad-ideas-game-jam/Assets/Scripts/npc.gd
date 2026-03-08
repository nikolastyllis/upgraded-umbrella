extends CharacterBase

@onready var player := $"../Player"

func get_move_direction() -> Vector3:
	if not player: return Vector3.ZERO
	var to_player = player.global_position - global_position
	to_player.y = 0
	return to_player.normalized() if to_player.length() > 5 else Vector3.ZERO

func get_input_dir() -> Vector2:
	var dir = get_move_direction()
	return Vector2(0, -1) if dir.length() > 0.01 else Vector2.ZERO

func get_target_rotation_y() -> float:
	var dir = get_move_direction()
	if dir.length() > 0.01:
		return atan2(-dir.x, -dir.z)
	return rotation.y
