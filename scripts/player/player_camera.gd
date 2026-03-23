extends Camera3D
class_name PlayerCamera

## =============================================================================
## PLAYER CAMERA — HEAVENT
## Mouse look raw, FOV dinámico por velocidad, head bob al caminar.
## =============================================================================

@export_group("Mouse")
@export var mouse_sensitivity: float = 0.003

@export_group("FOV")
@export var base_fov: float = 90.0
@export var max_fov: float = 110.0
@export var fov_speed_threshold: float = 200.0
@export var fov_lerp_speed: float = 6.0

@export_group("Head Bob")
@export var bob_frequency: float = 10.0
@export var bob_amplitude_walk: float = 0.06
@export var bob_amplitude_max: float = 0.12
@export var bob_smooth_speed: float = 12.0

# State
var _bob_phase: float = 0.0
var _bob_current_amplitude: float = 0.0
var _target_bob_offset: float = 0.0
var _head_base_position: Vector3


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	fov = base_fov
	_head_base_position = position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var rotation_y: float = -event.relative.x * mouse_sensitivity
			var rotation_x: float = -event.relative.y * mouse_sensitivity

			# Yaw on the player (parent), pitch on the camera (self)
			owner.rotation.y += rotation_y
			rotation.x = clampf(rotation.x + rotation_x, deg_to_rad(-89.0), deg_to_rad(89.0))


func _process(delta: float) -> void:
	var player: CharacterBody3D = owner as CharacterBody3D
	if not player:
		return

	var h_speed: float = player.get_horizontal_speed()

	# --- Dynamic FOV ---
	var speed_ratio := clampf(h_speed / fov_speed_threshold, 0.0, 1.0)
	var target_fov := lerpf(base_fov, max_fov, speed_ratio)
	fov = lerpf(fov, target_fov, fov_lerp_speed * delta)

	# --- Head Bob ---
	var is_walking := player.is_on_floor() and h_speed > 20.0

	if is_walking:
		_bob_phase += bob_frequency * delta * (h_speed / player.move_speed)
		var dynamic_amplitude := lerpf(bob_amplitude_walk, bob_amplitude_max, speed_ratio)
		_target_bob_offset = sin(_bob_phase) * dynamic_amplitude
		_bob_current_amplitude = lerpf(_bob_current_amplitude, dynamic_amplitude, bob_smooth_speed * delta)
	else:
		_bob_phase = 0.0
		_target_bob_offset = 0.0
		_bob_current_amplitude = lerpf(_bob_current_amplitude, 0.0, bob_smooth_speed * delta)

	position = _head_base_position + Vector3(0.0, _target_bob_offset, 0.0)
