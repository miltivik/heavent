extends Control
class_name WeaponInventoryHUD

## =============================================================================
## WEAPON INVENTORY HUD - HEAVENT
## Minimal HUD for fixed-slot weapon inventory.
## Shows the active weapon, slot states, and pickup feedback.
## =============================================================================

@export var active_color: Color = Color(0.95, 0.95, 1.0, 1.0)
@export var unlocked_color: Color = Color(0.75, 0.82, 0.92, 0.95)
@export var locked_color: Color = Color(0.3, 0.34, 0.42, 0.8)
@export var feedback_duration: float = 1.8

@onready var _active_weapon_label: Label = %ActiveWeaponLabel
@onready var _slot_container: HBoxContainer = %SlotContainer
@onready var _feedback_label: Label = %FeedbackLabel

var _weapon_manager: WeaponManager = null
var _slot_labels: Array[Label] = []
var _feedback_timer: SceneTreeTimer = null


func _ready() -> void:
	_weapon_manager = _find_weapon_manager()
	if not _weapon_manager:
		push_warning("WeaponInventoryHUD: Could not find WeaponManager")
		return

	_weapon_manager.inventory_changed.connect(_refresh)
	_weapon_manager.weapon_changed.connect(_on_weapon_changed)
	_weapon_manager.weapon_unlocked.connect(_on_weapon_unlocked)
	_build_slots()
	_refresh()


func _find_weapon_manager() -> WeaponManager:
	var player := get_parent()
	while player and not player is CharacterBody3D:
		player = player.get_parent()

	if player:
		return player.get_node_or_null("Camera3D/WeaponManager") as WeaponManager
	return null


func _build_slots() -> void:
	for child in _slot_container.get_children():
		child.queue_free()
	_slot_labels.clear()

	for slot_index in range(_weapon_manager.get_slot_count()):
		var slot_label := Label.new()
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.custom_minimum_size = Vector2(110.0, 28.0)
		slot_label.add_theme_font_size_override("font_size", 13)
		_slot_container.add_child(slot_label)
		_slot_labels.append(slot_label)


func _refresh() -> void:
	if not _weapon_manager:
		return

	var active_weapon := _weapon_manager.get_active_weapon()
	if active_weapon:
		_active_weapon_label.text = "Arma: %s" % active_weapon.get_display_name()
	else:
		_active_weapon_label.text = "Arma: Sin equipar"

	for slot_index in range(_slot_labels.size()):
		var slot_data := _weapon_manager.get_slot_data(slot_index)
		var slot_label := _slot_labels[slot_index]
		if slot_data.is_empty():
			slot_label.text = "%d | ---" % (slot_index + 1)
			slot_label.modulate = locked_color
			continue

		if slot_data["unlocked"]:
			slot_label.text = "%d | %s" % [slot_index + 1, String(slot_data["display_name"])]
			slot_label.modulate = active_color if slot_data["active"] else unlocked_color
		else:
			slot_label.text = "%d | BLOQ" % (slot_index + 1)
			slot_label.modulate = locked_color


func _on_weapon_changed(_weapon: WeaponBase, _slot_index: int) -> void:
	_refresh()


func _on_weapon_unlocked(weapon: WeaponBase, slot_index: int) -> void:
	_refresh()
	_show_feedback("Recogiste %s [Slot %d]" % [weapon.get_display_name(), slot_index + 1])


func _show_feedback(text: String) -> void:
	_feedback_label.text = text
	_feedback_label.visible = true

	_feedback_timer = get_tree().create_timer(feedback_duration)
	_feedback_timer.timeout.connect(
		func() -> void:
			_feedback_label.visible = false
			_feedback_label.text = ""
	)
