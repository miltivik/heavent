extends Camera3D
class_name PlayerCamera

## =============================================================================
## PLAYER CAMERA — HEAVENT
## Mouse look raw, FOV dinámico por velocidad, head bob al caminar.
## =============================================================================

@export_group("Mouse")
@export var mouse_sensitivity: float = 0.003

@export_group("FOV")
@export var base_fov: float = 88.0
@export var max_fov: float = 96.0
@export var fov_speed_threshold: float = 16.0
@export var fov_lerp_speed: float = 6.0

@export_group("Head Bob")
@export var bob_frequency: float = 10.0
@export var bob_amplitude_walk: float = 0.06
@export var bob_amplitude_max: float = 0.12
@export var bob_smooth_speed: float = 12.0

@export_group("Camera Tilt")
@export var slide_tilt_angle: float = 4.0    # degrees of roll during slide
@export var dash_tilt_angle: float = 2.5     # degrees of roll during dash
@export var tilt_lerp_speed: float = 10.0    # how fast tilt transitions

@export_group("Slide Crouch")
@export var slide_crouch_offset: float = 0.65
@export var crouch_lerp_speed: float = 12.0

# State
var _bob_phase: float = 0.0
var _bob_current_amplitude: float = 0.0
var _target_bob_offset: float = 0.0
var _head_base_position: Vector3
var _current_tilt: float = 0.0
var _target_tilt: float = 0.0
var _current_crouch_offset: float = 0.0
var _player: PlayerController


func _ready() -> void:
	add_to_group("player_camera")
	_player = get_parent() as PlayerController
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	make_current()
	_apply_current_fov()
	_head_base_position = position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var rotation_y: float = -event.relative.x * mouse_sensitivity
			var rotation_x: float = -event.relative.y * mouse_sensitivity

			# Yaw on the player (parent), pitch on the camera (self)
			if _player:
				_player.rotation.y += rotation_y
			rotation.x = clampf(rotation.x + rotation_x, deg_to_rad(-89.0), deg_to_rad(89.0))


func _process(delta: float) -> void:
	if not _player:
		return

	var h_speed: float = _player.get_horizontal_speed()
	var speed_ratio := clampf(h_speed / fov_speed_threshold, 0.0, 1.0)

	# --- Dynamic FOV ---
	var target_fov := _get_target_fov()
	fov = lerpf(fov, target_fov, fov_lerp_speed * delta)

	# --- Head Bob ---
	var is_walking := _player.is_on_floor() and h_speed > 1.0

	if is_walking:
		var move_speed := maxf(_player.move_speed, 0.001)
		_bob_phase += bob_frequency * delta * (h_speed / move_speed)
		var dynamic_amplitude := lerpf(bob_amplitude_walk, bob_amplitude_max, speed_ratio)
		_target_bob_offset = sin(_bob_phase) * dynamic_amplitude
		_bob_current_amplitude = lerpf(_bob_current_amplitude, dynamic_amplitude, bob_smooth_speed * delta)
	else:
		_bob_phase = 0.0
		_target_bob_offset = 0.0
		_bob_current_amplitude = lerpf(_bob_current_amplitude, 0.0, bob_smooth_speed * delta)

	var target_crouch_offset := slide_crouch_offset if _player.is_low_profile() else 0.0
	_current_crouch_offset = lerpf(_current_crouch_offset, target_crouch_offset, crouch_lerp_speed * delta)
	position = _head_base_position + Vector3(0.0, _target_bob_offset - _current_crouch_offset, 0.0)

	# --- Camera Tilt ---
	_target_tilt = 0.0
	if _player.is_sliding():
		var lateral := Input.get_axis("move_left", "move_right")
		_target_tilt = -slide_tilt_angle if lateral == 0.0 else -slide_tilt_angle * signf(lateral)
	elif _player.is_dashing():
		var lateral := Input.get_axis("move_left", "move_right")
		_target_tilt = -dash_tilt_angle * lateral

	_current_tilt = lerpf(_current_tilt, _target_tilt, tilt_lerp_speed * delta)
	rotation.z = deg_to_rad(_current_tilt)


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0001, 0.05)


func set_base_fov(value: float) -> void:
	var fov_boost_range := maxf(max_fov - base_fov, 0.0)
	base_fov = clampf(value, 1.0, 179.0)
	max_fov = clampf(base_fov + fov_boost_range, base_fov, 179.0)
	_apply_current_fov()


func _get_target_fov() -> float:
	if not _player:
		return base_fov

	var speed_ratio := clampf(_player.get_horizontal_speed() / fov_speed_threshold, 0.0, 1.0)
	return lerpf(base_fov, max_fov, speed_ratio)


func _apply_current_fov() -> void:
	fov = _get_target_fov()
