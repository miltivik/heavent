extends CharacterBody3D
class_name PlayerController

## =============================================================================
## PLAYER CONTROLLER — HEAVENT
## Movimiento rápido estilo Quake/ULTRAKILL.
## Air strafing, coyote time, jump buffering, gravedad escalonada.
## =============================================================================

# --- Movement ---
@export_group("Movement")
@export var move_speed: float = 450.0
@export var max_speed: float = 600.0
@export var ground_accel: float = 40.0
@export var ground_decel: float = 15.0
@export var air_accel: float = 20.0
@export var air_decel: float = 3.0

# --- Jump ---
@export_group("Jump")
@export var jump_velocity: float = 10.0
@export var jump_cut_multiplier: float = 0.4
@export var coyote_time_frames: int = 6
@export var jump_buffer_frames: int = 6

# --- Gravity ---
@export_group("Gravity")
@export var gravity_rising: float = 30.0
@export var gravity_falling: float = 55.0
@export var terminal_velocity: float = -40.0

# State
var _coyote_counter: int = 0
var _jump_buffer_counter: int = 0
var _was_on_floor: bool = false
var _is_jumping: bool = false


func _ready() -> void:
	# Ensure we don't capture input meant for UI
	pass


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta)
	_handle_jump_logic()
	_update_floor_state()
	move_and_slide()


# --- GRAVITY ---

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var grav := gravity_rising if velocity.y > 0.0 else gravity_falling
		velocity.y = move_toward(velocity.y, terminal_velocity, grav * delta)


# --- MOVEMENT ---

func _apply_movement(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if is_on_floor():
		if wish_dir.length() > 0.01:
			velocity.x = move_toward(velocity.x, wish_dir.x * move_speed, ground_accel)
			velocity.z = move_toward(velocity.z, wish_dir.z * move_speed, ground_decel)
		else:
			# Full deceleration when no input
			velocity.x = move_toward(velocity.x, 0.0, ground_decel)
			velocity.z = move_toward(velocity.z, 0.0, ground_decel)
	else:
		# Air strafing — Quake style
		# Only accelerate, don't decelerate (preserves momentum)
		if wish_dir.length() > 0.01:
			var current_hvel := Vector3(velocity.x, 0.0, velocity.z)
			var projected := current_hvel.project(wish_dir)
			var remaining := wish_dir * move_speed - projected
			remaining = remaining.limit_length(air_accel)
			velocity.x += remaining.x
			velocity.z += remaining.z
		else:
			# Minimal air deceleration when no input
			velocity.x = move_toward(velocity.x, 0.0, air_decel)
			velocity.z = move_toward(velocity.z, 0.0, air_decel)

	# Clamp horizontal speed
	var hvel := Vector2(velocity.x, velocity.z)
	if hvel.length() > max_speed:
		hvel = hvel.normalized() * max_speed
		velocity.x = hvel.x
		velocity.z = hvel.y


# --- JUMP ---

func _handle_jump_logic() -> void:
	var on_floor := is_on_floor()

	# Coyote time: allow jump for a few frames after leaving the ground
	if on_floor:
		_coyote_counter = coyote_time_frames
		_is_jumping = false
	elif _was_on_floor and not _is_jumping:
		# Just left the ground without jumping — start coyote countdown
		pass  # _coyote_counter already set
	if _coyote_counter > 0 and not on_floor:
		_coyote_counter -= 1

	# Jump buffer: remember jump press for a few frames before landing
	if Input.is_action_just_pressed("move_jump"):
		_jump_buffer_counter = jump_buffer_frames
	if _jump_buffer_counter > 0:
		_jump_buffer_counter -= 1

	# Execute jump if we have buffer and can jump (on floor or in coyote time)
	if _jump_buffer_counter > 0 and (on_floor or _coyote_counter > 0):
		_execute_jump()
		_jump_buffer_counter = 0
		_coyote_counter = 0

	# Variable jump height: release early → cut velocity
	if Input.is_action_just_released("move_jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier


func _execute_jump() -> void:
	velocity.y = jump_velocity
	_is_jumping = true


func _update_floor_state() -> void:
	_was_on_floor = is_on_floor()


# --- UTILITY ---

func is_player_jumping() -> bool:
	return _is_jumping or not is_on_floor()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
