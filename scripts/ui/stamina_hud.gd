extends Control
class_name StaminaHUD

## =============================================================================
## STAMINA HUD — HEAVENT
## Displays 3 stamina charges as colored rectangles.
## Connects to StaminaSystem signals for reactive updates.
## =============================================================================

@export var charge_color_full: Color = Color(0.2, 0.85, 1.0, 0.9)     # Cyan
@export var charge_color_empty: Color = Color(0.15, 0.15, 0.2, 0.4)   # Dark
@export var charge_color_regen: Color = Color(0.2, 0.85, 1.0, 0.5)    # Faded cyan
@export var charge_width: float = 60.0
@export var charge_height: float = 8.0
@export var charge_gap: float = 4.0

var _stamina_system: StaminaSystem = null
var _charge_bars: Array[ColorRect] = []


func _ready() -> void:
	# Find StaminaSystem — expects to be child of Player scene
	var player := get_parent()
	while player and not player is CharacterBody3D:
		player = player.get_parent()

	if player:
		_stamina_system = player.get_node_or_null("StaminaSystem") as StaminaSystem

	if not _stamina_system:
		push_warning("StaminaHUD: Could not find StaminaSystem node")
		return

	_stamina_system.stamina_changed.connect(_on_stamina_changed)
	_create_bars()
	_update_bars(_stamina_system.current_stamina, _stamina_system.max_charges)


func _create_bars() -> void:
	for i in range(_stamina_system.max_charges):
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(charge_width, charge_height)
		bar.size = Vector2(charge_width, charge_height)
		bar.position = Vector2(i * (charge_width + charge_gap), 0.0)
		bar.color = charge_color_full
		add_child(bar)
		_charge_bars.append(bar)


func _on_stamina_changed(current: float, _max_charges: int) -> void:
	_update_bars(current, _max_charges)


func _update_bars(current: float, _max_charges: int) -> void:
	for i in range(_charge_bars.size()):
		var bar := _charge_bars[i]
		var charge_threshold := float(i + 1)
		if current >= charge_threshold:
			# Full charge
			bar.color = charge_color_full
		elif current > float(i):
			# Partially regenerating
			var fill := current - float(i)
			bar.color = charge_color_empty.lerp(charge_color_regen, fill)
		else:
			# Empty
			bar.color = charge_color_empty
