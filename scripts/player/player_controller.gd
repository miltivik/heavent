extends CharacterBody3D
class_name PlayerController

## =============================================================================
## PLAYER CONTROLLER — HEAVENT
## ULTRAKILL-style movement: dash, slide, slam, wall jump, dash jump.
## Air strafing, coyote time, jump buffering, escaloned gravity.
## =============================================================================

# --- Signals ---
signal dashed()
signal slid()
signal slammed()
signal wall_jumped()
signal landed()

# --- Movement ---
@export_group("Movement")
@export var move_speed: float = 9.0
@export var max_speed: float = 16.0
@export var ground_accel: float = 55.0
@export var ground_decel: float = 60.0
@export var ground_turn_accel: float = 85.0
@export var ground_lateral_friction: float = 90.0

# --- Air Control ---
@export_group("Air Control")
@export var air_accel: float = 18.0
@export var air_decel: float = 4.0
@export var air_friction_with_input: float = 0.992

# --- Jump ---
@export_group("Jump")
@export var jump_velocity: float = 10.0
@export var coyote_time_frames: int = 6
@export var jump_buffer_frames: int = 6

# --- Gravity ---
@export_group("Gravity")
@export var gravity_rising: float = 30.0
@export var gravity_falling: float = 55.0
@export var terminal_velocity: float = -40.0

# --- Dash ---
@export_group("Dash")
@export var dash_speed: float = 24.0
@export var dash_duration: float = 0.15
@export var dash_stamina_cost: float = 1.0
@export var dash_iframes: float = 0.2

# --- Slide ---
@export_group("Slide")
@export var slide_speed: float = 14.0
@export var slide_friction: float = 0.98
@export var slide_min_speed: float = 6.5
@export var slide_jump_boost: float = 1.15
@export var slide_collider_height: float = 0.8
@export var low_profile_speed_multiplier: float = 0.8
@export var slide_buffer_time: float = 0.18

# --- Slam ---
@export_group("Slam")
@export var slam_speed: float = -60.0
@export var slam_bounce_multiplier: float = 1.5
@export var slam_stamina_cost: float = 0.0

# --- Wall Jump ---
@export_group("Wall Jump")
@export var wall_jump_force: Vector3 = Vector3(6.0, 9.0, 0.0)
@export var max_wall_jumps: int = 3
@export var wall_cling_friction_start: float = 0.8
@export var wall_cling_friction_decay: float = 0.3
@export var wall_cling_max_time: float = 3.0

# --- Dash Jump ---
@export_group("Dash Jump")
@export var dash_jump_stamina_cost: float = 2.0
@export var dash_jump_horizontal_boost: float = 1.2
@export var dash_jump_vertical_multiplier: float = 0.7

# =============================================================================
# STATE
# =============================================================================

# Core
var _coyote_counter: int = 0
var _jump_buffer_counter: int = 0
var _was_on_floor: bool = false
var _is_jumping: bool = false

# Dash
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _dash_iframes_timer: float = 0.0
var _is_invincible: bool = false

# Slide
var _is_sliding: bool = false
var _is_low_profile: bool = false
var _original_collider_height: float = 1.6
var _slide_buffer_timer: float = 0.0
var _slide_hold_armed: bool = false

# Slam
var _is_slamming: bool = false
var _just_slammed: bool = false

# Wall
var _wall_jumps_remaining: int = 3
var _is_wall_clinging: bool = false
var _wall_cling_timer: float = 0.0
var _wall_normal: Vector3 = Vector3.ZERO

# =============================================================================
# REFERENCES
# =============================================================================

@onready var _stamina: StaminaSystem = $StaminaSystem
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _wall_ray_left: RayCast3D = $WallRayLeft
@onready var _wall_ray_right: RayCast3D = $WallRayRight
@onready var _wall_ray_front: RayCast3D = $WallRayFront
@onready var _wall_ray_back: RayCast3D = $WallRayBack


func _ready() -> void:
	_wall_jumps_remaining = max_wall_jumps
	# Store original collider height for slide restoration
	var capsule := _collision_shape.shape as CapsuleShape3D
	if capsule:
		_original_collider_height = capsule.height

	for ray in [_wall_ray_left, _wall_ray_right, _wall_ray_front, _wall_ray_back]:
		if ray:
			ray.enabled = true


func _physics_process(delta: float) -> void:
	_update_slide_request(delta)
	_handle_dash(delta)
	_apply_gravity(delta)
	_handle_slam()
	_handle_slide(delta)
	_update_low_profile_state()
	_handle_wall_logic(delta)
	_apply_movement(delta)
	_handle_jump_logic()
	_update_floor_state()
	move_and_slide()
	_enforce_horizontal_speed_cap()
	_post_move_checks()


# =============================================================================
# GRAVITY
# =============================================================================

func _apply_gravity(delta: float) -> void:
	if _is_dashing:
		return
	if not is_on_floor():
		var grav := gravity_rising if velocity.y > 0.0 else gravity_falling
		velocity.y = move_toward(velocity.y, terminal_velocity, grav * delta)


# =============================================================================
# DASH
# =============================================================================

func _handle_dash(delta: float) -> void:
	# Iframe countdown (independent of dash state)
	if _dash_iframes_timer > 0.0:
		_dash_iframes_timer -= delta
		if _dash_iframes_timer <= 0.0:
			_is_invincible = false

	if _is_dashing:
		_dash_timer -= delta
		# Override velocity to dash direction
		velocity = _dash_direction * dash_speed
		if _dash_timer <= 0.0:
			_end_dash()
		return

	# Start dash
	if Input.is_action_just_pressed("move_dash") and not _is_dashing:
		if _stamina.can_spend(dash_stamina_cost):
			_start_dash()


func _start_dash() -> void:
	_stamina.spend(dash_stamina_cost)

	# Direction: input direction if available, else player forward
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if wish_dir.length() < 0.01:
		_dash_direction = (-transform.basis.z).normalized()
	else:
		_dash_direction = wish_dir

	# Cancel slam if active
	if _is_slamming:
		_is_slamming = false

	_is_dashing = true
	_dash_timer = dash_duration
	_dash_iframes_timer = dash_iframes
	_is_invincible = true

	# Exit slide if sliding
	if _is_sliding:
		_exit_slide()

	dashed.emit()


func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0
	# Keep momentum from dash direction
	velocity = _dash_direction * dash_speed


# =============================================================================
# SLAM
# =============================================================================

func _handle_slam() -> void:
	if _is_dashing:
		return

	if _is_slamming:
		# Allow dash cancel during slam
		if Input.is_action_just_pressed("move_dash") and _stamina.can_spend(dash_stamina_cost):
			_is_slamming = false
			_start_dash()
		return

	# Start slam: must be in air, not on floor
	if Input.is_action_just_pressed("move_slam") and not is_on_floor():
		_is_slamming = true
		velocity.y = slam_speed
		velocity.x *= 0.05
		velocity.z *= 0.05


# =============================================================================
# SLIDE
# =============================================================================

func _handle_slide(_delta: float) -> void:
	if _is_dashing:
		return

	if _is_sliding:
		# Apply friction
		velocity.x *= slide_friction
		velocity.z *= slide_friction

		# Exit conditions: too slow, released input, or left floor
		var h_speed := get_horizontal_speed()
		if h_speed < slide_min_speed or not Input.is_action_pressed("move_slide") or not is_on_floor():
			_exit_slide()
		return

	_try_start_slide()


func _enter_slide() -> void:
	_is_sliding = true
	_is_low_profile = true
	_consume_slide_request()

	_set_collider_height(slide_collider_height)

	# Set velocity in current movement direction at max of current speed or slide_speed
	var h_speed := get_horizontal_speed()
	var h_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	if h_dir.length() < 0.01:
		h_dir = (-transform.basis.z).normalized()
	var target_speed := maxf(h_speed, slide_speed)
	velocity.x = h_dir.x * target_speed
	velocity.z = h_dir.z * target_speed

	# Pause stamina regen during slide
	_stamina.pause_regen()
	slid.emit()


func _exit_slide() -> void:
	_is_sliding = false
	# Resume stamina regen
	_stamina.resume_regen()
	_try_restore_standing_collider()


func _update_slide_request(delta: float) -> void:
	if Input.is_action_just_pressed("move_slide"):
		_slide_buffer_timer = slide_buffer_time
		if not is_on_floor():
			_slide_hold_armed = true

	if _slide_buffer_timer > 0.0:
		_slide_buffer_timer = maxf(_slide_buffer_timer - delta, 0.0)

	if not Input.is_action_pressed("move_slide"):
		_slide_hold_armed = false
	elif not is_on_floor():
		_slide_hold_armed = true


func _try_start_slide() -> bool:
	if not _can_start_slide():
		return false

	if not _has_pending_slide_request():
		return false

	_enter_slide()
	return true


func _has_pending_slide_request() -> bool:
	return _slide_buffer_timer > 0.0 or _slide_hold_armed


func _consume_slide_request() -> void:
	_slide_buffer_timer = 0.0
	_slide_hold_armed = false


func _can_start_slide() -> bool:
	if _is_dashing or _is_sliding or _is_slamming:
		return false

	if not is_on_floor():
		return false

	return get_horizontal_speed() > slide_min_speed


func _update_low_profile_state() -> void:
	if _is_sliding or not _is_low_profile:
		return

	if _can_restore_standing_collider():
		_restore_standing_collider()


func _set_collider_height(height: float) -> void:
	var capsule := _collision_shape.shape as CapsuleShape3D
	if not capsule:
		return

	capsule.height = height
	_collision_shape.position.y = height / 2.0


func _try_restore_standing_collider() -> bool:
	if not _can_restore_standing_collider():
		return false

	_restore_standing_collider()
	return true


func _restore_standing_collider() -> void:
	_set_collider_height(_original_collider_height)
	_is_low_profile = false


func _can_restore_standing_collider() -> bool:
	var current_capsule := _collision_shape.shape as CapsuleShape3D
	if not current_capsule:
		return true

	var standing_capsule := CapsuleShape3D.new()
	standing_capsule.radius = current_capsule.radius
	standing_capsule.height = _original_collider_height

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_capsule
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]

	var standing_transform := global_transform
	standing_transform.origin += global_transform.basis * Vector3(0.0, _original_collider_height / 2.0, 0.0)
	query.transform = standing_transform

	var space_state := get_world_3d().direct_space_state
	return space_state.intersect_shape(query, 1).is_empty()


# =============================================================================
# WALL LOGIC
# =============================================================================

func _handle_wall_logic(delta: float) -> void:
	if _is_dashing or is_on_floor() or _is_slamming:
		if _is_wall_clinging:
			_is_wall_clinging = false
			_wall_cling_timer = 0.0
		return

	# Check wall raycasts — only when falling
	if velocity.y > 0.0:
		if _is_wall_clinging:
			_is_wall_clinging = false
			_wall_cling_timer = 0.0
		return

	var wall_hit := false
	var hit_normal := Vector3.ZERO

	# Check all 4 rays, use first hit
	var rays: Array[RayCast3D] = [_wall_ray_left, _wall_ray_right, _wall_ray_front, _wall_ray_back]
	for ray in rays:
		if ray.is_colliding():
			wall_hit = true
			hit_normal = ray.get_collision_normal()
			break

	if wall_hit:
		_wall_normal = hit_normal

		if not _is_wall_clinging:
			_is_wall_clinging = true
			_wall_cling_timer = 0.0

		# Wall cling friction — decays over time
		_wall_cling_timer += delta
		var friction_t := clampf(_wall_cling_timer / wall_cling_max_time, 0.0, 1.0)
		var current_friction := lerpf(wall_cling_friction_start, 0.0, friction_t)

		# Reduce fall speed
		if velocity.y < 0.0:
			velocity.y *= (1.0 - current_friction * delta * 10.0)
			# Clamp to not go upward from friction
			velocity.y = minf(velocity.y, 0.0)

		# Wall jump input
		if Input.is_action_just_pressed("move_jump") and _wall_jumps_remaining > 0:
			_execute_wall_jump()
	else:
		if _is_wall_clinging:
			_is_wall_clinging = false
			_wall_cling_timer = 0.0


func _execute_wall_jump() -> void:
	velocity = _wall_normal * wall_jump_force.x + Vector3.UP * wall_jump_force.y
	_wall_jumps_remaining -= 1
	_is_wall_clinging = false
	_wall_cling_timer = 0.0
	_is_jumping = true
	wall_jumped.emit()


# =============================================================================
# MOVEMENT (WASD)
# =============================================================================

func _apply_movement(delta: float) -> void:
	if _is_dashing or _is_sliding:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if is_on_floor():
		var current_hvel := Vector2(velocity.x, velocity.z)
		var target_move_speed := move_speed
		if _is_low_profile:
			target_move_speed *= low_profile_speed_multiplier

		if wish_dir.length() > 0.01:
			var target_hvel := Vector2(wish_dir.x, wish_dir.z) * target_move_speed
			var turn_accel := ground_accel
			if current_hvel.length() > 0.01 and current_hvel.normalized().dot(target_hvel.normalized()) < 0.95:
				turn_accel = ground_turn_accel

			current_hvel = current_hvel.move_toward(target_hvel, turn_accel * delta)

			var target_dir := target_hvel.normalized()
			var forward_component := target_dir * current_hvel.dot(target_dir)
			var lateral_component := current_hvel - forward_component
			lateral_component = lateral_component.move_toward(Vector2.ZERO, ground_lateral_friction * delta)
			current_hvel = forward_component + lateral_component
		else:
			current_hvel = current_hvel.move_toward(Vector2.ZERO, ground_decel * delta)

		velocity.x = current_hvel.x
		velocity.z = current_hvel.y
	else:
		# Air control — ULTRAKILL style
		if wish_dir.length() > 0.01:
			# Apply slight friction when steering (tradeoff: steer = lose speed)
			velocity.x *= air_friction_with_input
			velocity.z *= air_friction_with_input

			# Quake-style air strafing
			var current_hvel := Vector3(velocity.x, 0.0, velocity.z)
			var projected := current_hvel.project(wish_dir)
			var remaining := wish_dir * move_speed - projected
			remaining = remaining.limit_length(air_accel * delta)
			velocity.x += remaining.x
			velocity.z += remaining.z
		else:
			# Very low decel when no input — preserve momentum
			velocity.x = move_toward(velocity.x, 0.0, air_decel * delta)
			velocity.z = move_toward(velocity.z, 0.0, air_decel * delta)

	_enforce_horizontal_speed_cap()


# =============================================================================
# JUMP LOGIC
# =============================================================================

func _handle_jump_logic() -> void:
	var on_floor := is_on_floor()

	# --- Coyote time ---
	if on_floor:
		_coyote_counter = coyote_time_frames
		_is_jumping = false
	elif _was_on_floor and not _is_jumping:
		pass  # coyote counter already set
	if _coyote_counter > 0 and not on_floor:
		_coyote_counter -= 1

	# --- Jump buffer ---
	if Input.is_action_just_pressed("move_jump"):
		_jump_buffer_counter = jump_buffer_frames
	if _jump_buffer_counter > 0:
		_jump_buffer_counter -= 1

	# --- Dash jump: jump during active dash ---
	if _is_dashing and _jump_buffer_counter > 0:
		var remaining_cost := dash_jump_stamina_cost - dash_stamina_cost
		if _stamina.can_spend(remaining_cost):
			_stamina.spend(remaining_cost)
			_execute_dash_jump()
			_jump_buffer_counter = 0
			_coyote_counter = 0
			return

	# --- Slam bounce: jump right after slam landing ---
	if _just_slammed and _jump_buffer_counter > 0:
		velocity.y = jump_velocity * slam_bounce_multiplier
		_just_slammed = false
		_is_jumping = true
		_jump_buffer_counter = 0
		_coyote_counter = 0
		return

	# --- Slide jump: jump during slide ---
	if _is_sliding and _jump_buffer_counter > 0:
		_execute_slide_jump()
		_jump_buffer_counter = 0
		_coyote_counter = 0
		return

	# --- Normal jump (with coyote time) ---
	if _jump_buffer_counter > 0 and (on_floor or _coyote_counter > 0):
		_execute_jump()
		_jump_buffer_counter = 0
		_coyote_counter = 0

	# NO variable jump height — fixed jump only


func _execute_jump() -> void:
	velocity.y = jump_velocity
	_is_jumping = true


func _execute_slide_jump() -> void:
	velocity.y = jump_velocity
	# Boost horizontal speed
	var h_speed := get_horizontal_speed()
	var h_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var boosted_speed := h_speed * slide_jump_boost
	velocity.x = h_dir.x * boosted_speed
	velocity.z = h_dir.z * boosted_speed
	_is_jumping = true
	_exit_slide()


func _execute_dash_jump() -> void:
	# End dash
	_is_dashing = false
	_dash_timer = 0.0

	# Vertical: lower than normal jump
	velocity.y = jump_velocity * dash_jump_vertical_multiplier

	# Horizontal: massive boost from dash direction
	var h_speed := dash_speed * dash_jump_horizontal_boost
	velocity.x = _dash_direction.x * h_speed
	velocity.z = _dash_direction.z * h_speed

	_is_jumping = true


# =============================================================================
# FLOOR STATE
# =============================================================================

func _update_floor_state() -> void:
	_was_on_floor = is_on_floor()


func _post_move_checks() -> void:
	if is_on_floor():
		var just_landed := not _was_on_floor
		if just_landed:
			_try_start_slide()

		_wall_jumps_remaining = max_wall_jumps
		_is_wall_clinging = false
		_wall_cling_timer = 0.0
		if _is_slamming:
			_is_slamming = false
			_just_slammed = true
			slammed.emit()
		if just_landed:
			landed.emit()
	else:
		_just_slammed = false


func _enforce_horizontal_speed_cap() -> void:
	if _is_dashing or _is_sliding:
		return

	var speed_limit := max_speed
	if not is_on_floor():
		speed_limit = maxf(speed_limit, dash_speed * dash_jump_horizontal_boost)
		speed_limit = maxf(speed_limit, slide_speed * slide_jump_boost)

	_clamp_horizontal_speed(speed_limit)


func _clamp_horizontal_speed(speed_limit: float) -> void:
	var hvel := Vector2(velocity.x, velocity.z)
	if hvel.length() <= speed_limit:
		return

	hvel = hvel.normalized() * speed_limit
	velocity.x = hvel.x
	velocity.z = hvel.y


# =============================================================================
# PUBLIC API (used by PlayerCamera and other systems)
# =============================================================================

func is_player_jumping() -> bool:
	return _is_jumping or not is_on_floor()


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_invincible() -> bool:
	return _is_invincible


func is_dashing() -> bool:
	return _is_dashing


func is_sliding() -> bool:
	return _is_sliding


func is_low_profile() -> bool:
	return _is_low_profile


func is_slamming() -> bool:
	return _is_slamming


func is_wall_clinging() -> bool:
	return _is_wall_clinging
