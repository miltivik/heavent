extends Node3D
class_name WeaponBase

## =============================================================================
## WEAPON BASE — HEAVENT
## State machine for weapons: Idle → Fire → Cooldown, with AltFire support.
## Subclasses override _on_fire() and _on_alt_fire() for specific behavior.
## =============================================================================

# --- Signals ---
signal fired()
signal alt_fired()
signal hit_landed(hit_data: Dictionary)
signal state_changed(new_state: int)

# --- Enums ---
enum State { IDLE, FIRE, ALT_FIRE, COOLDOWN }

# --- Base Stats ---
@export_group("Weapon Stats")
@export var weapon_name: String = "Weapon"
@export var damage: float = 15.0
@export var fire_rate: float = 0.15           # seconds between shots
@export var weapon_range: float = 200.0       # hitscan max distance
@export var has_alt_fire: bool = false
@export var alt_damage: float = 30.0
@export var alt_fire_rate: float = 0.5

@export_group("Feedback")
@export var fire_shake_intensity: float = 1.5
@export var fire_shake_duration: float = 0.08
@export var alt_fire_shake_intensity: float = 3.0
@export var alt_fire_shake_duration: float = 0.12

# --- State ---
var current_state: int = State.IDLE
var _cooldown_timer: float = 0.0
var _active: bool = false

# --- References (set by WeaponManager) ---
var _camera: Camera3D = null


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func activate() -> void:
	_active = true
	visible = true
	current_state = State.IDLE
	_cooldown_timer = 0.0
	set_process(true)


func deactivate() -> void:
	_active = false
	visible = false
	current_state = State.IDLE
	_cooldown_timer = 0.0
	set_process(false)


func setup(camera: Camera3D) -> void:
	_camera = camera


func _process(delta: float) -> void:
	if not _active:
		return

	match current_state:
		State.IDLE:
			pass
		State.FIRE:
			_transition(State.COOLDOWN)
		State.ALT_FIRE:
			_transition(State.COOLDOWN)
		State.COOLDOWN:
			_cooldown_timer -= delta
			if _cooldown_timer <= 0.0:
				_transition(State.IDLE)


# =============================================================================
# INPUT — Called by WeaponManager
# =============================================================================

func try_fire() -> bool:
	if current_state != State.IDLE:
		return false
	_transition(State.FIRE)
	_cooldown_timer = fire_rate
	_on_fire()
	fired.emit()
	return true


func try_alt_fire() -> bool:
	if current_state != State.IDLE or not has_alt_fire:
		return false
	_transition(State.ALT_FIRE)
	_cooldown_timer = alt_fire_rate
	_on_alt_fire()
	alt_fired.emit()
	return true


# =============================================================================
# VIRTUAL — Override in subclasses
# =============================================================================

## Called when primary fire executes. Override for weapon-specific behavior.
func _on_fire() -> void:
	pass


## Called when alt fire executes. Override for weapon-specific behavior.
func _on_alt_fire() -> void:
	pass


## Returns the forward direction from camera for hitscan weapons.
func get_aim_origin() -> Vector3:
	if _camera:
		return _camera.global_position
	return global_position


## Returns the forward direction from camera for hitscan weapons.
func get_aim_direction() -> Vector3:
	if _camera:
		return -_camera.global_basis.z
	return -global_basis.z


# =============================================================================
# INTERNAL
# =============================================================================

func _transition(new_state: int) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func is_idle() -> bool:
	return current_state == State.IDLE


func is_firing() -> bool:
	return current_state == State.FIRE or current_state == State.ALT_FIRE


func is_cooling_down() -> bool:
	return current_state == State.COOLDOWN
