extends Control

@onready var settings := $CenterContainer/SettingsMenu
@onready var credits := $CenterContainer/Credits
@onready var main := $CenterContainer/MainMenu
@onready var full_screen := $CenterContainer/SettingsMenu/CheckBox
@onready var master_slider := $"CenterContainer/SettingsMenu/Master Volume"
@onready var music_slider := $"CenterContainer/SettingsMenu/Music Volume"
@onready var sound_slider := $"CenterContainer/SettingsMenu/Sound Volume"

func _ready() -> void:
	full_screen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	sound_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Sound")))

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_sequence_scene.tscn")

func _on_settings_pressed() -> void:
	main.visible = false
	settings.visible = true

func _on_credits_pressed() -> void:
	main.visible = false
	credits.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	main.visible = true
	credits.visible = false
	settings.visible = false

func _on_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _on_master_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)

func _on_music_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)

func _on_sound_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Sound"), value)
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Radio"), value)
