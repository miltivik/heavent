extends CanvasLayer

## =============================================================================
## PAUSE MENU - HEAVENT
## Menu de pausa que se abre con ESC.
## Opciones: Reanudar, Ajustes, Salir del juego.
## =============================================================================

signal resume_requested
signal settings_requested
signal quit_requested

@onready var control: Control = %Control
@onready var main_menu_container: VBoxContainer = %MainMenuContainer
@onready var settings_menu_container: VBoxContainer = %SettingsMenuContainer
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var mouse_sensitivity_slider: HSlider = %MouseSensitivitySlider
@onready var mouse_sensitivity_value_label: Label = %MouseSensitivityValueLabel
@onready var base_fov_slider: HSlider = %BaseFovSlider
@onready var base_fov_value_label: Label = %BaseFovValueLabel
@onready var back_button: Button = %BackButton

var _is_paused: bool = false
var _player_camera: PlayerCamera = null


func _ready() -> void:
	control.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_show_main_menu()

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	base_fov_slider.value_changed.connect(_on_base_fov_changed)

	_sync_settings_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not _is_paused:
			_pause_game()
		elif settings_menu_container.visible:
			_show_main_menu()
			settings_button.grab_focus()
		else:
			_resume_game()
		get_viewport().set_input_as_handled()


func _pause_game() -> void:
	if not control or not resume_button:
		return

	_is_paused = true
	control.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_sync_settings_ui()
	_show_main_menu()
	resume_button.grab_focus()


func _resume_game() -> void:
	if not control:
		return

	_is_paused = false
	control.visible = false
	_show_main_menu()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_resume_pressed() -> void:
	_resume_game()
	resume_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()
	_show_settings_menu()


func _on_quit_pressed() -> void:
	quit_requested.emit()
	get_tree().quit()


func is_paused() -> bool:
	return _is_paused


func _on_back_pressed() -> void:
	_show_main_menu()
	settings_button.grab_focus()


func _show_main_menu() -> void:
	main_menu_container.visible = true
	settings_menu_container.visible = false


func _show_settings_menu() -> void:
	_sync_settings_ui()
	main_menu_container.visible = false
	settings_menu_container.visible = true
	mouse_sensitivity_slider.grab_focus()


func _on_mouse_sensitivity_changed(value: float) -> void:
	_update_mouse_sensitivity_label(value)
	if _player_camera:
		_player_camera.set_mouse_sensitivity(value)


func _on_base_fov_changed(value: float) -> void:
	_update_base_fov_label(value)
	if _player_camera:
		_player_camera.set_base_fov(value)


func _sync_settings_ui() -> void:
	_player_camera = _find_player_camera()
	if not _player_camera:
		_update_mouse_sensitivity_label(mouse_sensitivity_slider.value)
		_update_base_fov_label(base_fov_slider.value)
		return

	mouse_sensitivity_slider.set_value_no_signal(_player_camera.mouse_sensitivity)
	base_fov_slider.set_value_no_signal(_player_camera.base_fov)
	_update_mouse_sensitivity_label(mouse_sensitivity_slider.value)
	_update_base_fov_label(base_fov_slider.value)


func _update_mouse_sensitivity_label(value: float) -> void:
	mouse_sensitivity_value_label.text = "Sensibilidad actual: %.4f" % value


func _update_base_fov_label(value: float) -> void:
	base_fov_value_label.text = "FOV actual: %d" % int(round(value))


func _find_player_camera() -> PlayerCamera:
	return get_tree().get_first_node_in_group("player_camera") as PlayerCamera
