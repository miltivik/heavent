extends Node
class_name StaminaSystem

## =============================================================================
## STAMINA SYSTEM — HEAVENT
## Resource-based stamina with charges, regen delay, and pause support.
## Used by PlayerController for dash, dash-jump, etc.
## =============================================================================

signal stamina_changed(current: float, max_charges: int)
signal stamina_depleted()

@export var max_charges: int = 3
@export var regen_rate: float = 0.5  # charges per second
@export var regen_delay: float = 0.5  # seconds before regen starts after use

var current_stamina: float = 3.0
var _regen_paused: bool = false
var _regen_timer: float = 0.0


func _ready() -> void:
	current_stamina = float(max_charges)


func _physics_process(delta: float) -> void:
	if _regen_paused:
		return
	if _regen_timer > 0.0:
		_regen_timer -= delta
		return
	if current_stamina < float(max_charges):
		current_stamina = min(current_stamina + regen_rate * delta, float(max_charges))
		stamina_changed.emit(current_stamina, max_charges)


func can_spend(amount: float) -> bool:
	return current_stamina >= amount


func spend(amount: float) -> bool:
	if current_stamina < amount:
		stamina_depleted.emit()
		return false
	current_stamina -= amount
	_regen_timer = regen_delay
	stamina_changed.emit(current_stamina, max_charges)
	return true


func pause_regen() -> void:
	_regen_paused = true


func resume_regen() -> void:
	_regen_paused = false


func get_charges() -> int:
	return int(floor(current_stamina))
