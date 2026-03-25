extends Node3D
class_name WeaponManager

## =============================================================================
## WEAPON MANAGER - HEAVENT
## Owns the player's weapon inventory, equips unlocked weapons, and routes input.
## Fixed-slot inventory v1: 3 stable slots, instant swap, no ammo.
## =============================================================================

signal weapon_changed(weapon: WeaponBase, slot_index: int)
signal weapon_unlocked(weapon: WeaponBase, slot_index: int)
signal weapon_fired(weapon: WeaponBase)
signal weapon_alt_fired(weapon: WeaponBase)
signal inventory_changed()

@export_group("Weapon Position")
@export var weapon_offset: Vector3 = Vector3(0.3, -0.25, -0.5)

@export_group("Slot 1")
@export var slot_1_weapon_id: String = ""
@export var slot_1_scene: PackedScene
@export var slot_1_unlocked_by_default: bool = true

@export_group("Slot 2")
@export var slot_2_weapon_id: String = ""
@export var slot_2_scene: PackedScene
@export var slot_2_unlocked_by_default: bool = false

@export_group("Slot 3")
@export var slot_3_weapon_id: String = ""
@export var slot_3_scene: PackedScene
@export var slot_3_unlocked_by_default: bool = false

var _slots: Array[Dictionary] = []
var _active_slot_index: int = -1
var _camera: Camera3D = null


func _ready() -> void:
	add_to_group("weapon_manager")

	_camera = get_parent() as Camera3D
	if not _camera:
		push_error("WeaponManager: Must be a child of Camera3D")
		return

	_initialize_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if not _camera or get_unlocked_weapon_count() == 0:
		return

	if event.is_action_pressed("shoot_primary"):
		_try_fire()
	elif event.is_action_pressed("shoot_secondary"):
		_try_alt_fire()

	if event.is_action_pressed("weapon_1"):
		switch_to_slot(0)
	elif event.is_action_pressed("weapon_2"):
		switch_to_slot(1)
	elif event.is_action_pressed("weapon_3"):
		switch_to_slot(2)
	elif event.is_action_pressed("weapon_next"):
		switch_next()
	elif event.is_action_pressed("weapon_prev"):
		switch_prev()


func _initialize_inventory() -> void:
	_slots.clear()
	_slots.append(_make_slot(slot_1_weapon_id, slot_1_scene, slot_1_unlocked_by_default))
	_slots.append(_make_slot(slot_2_weapon_id, slot_2_scene, slot_2_unlocked_by_default))
	_slots.append(_make_slot(slot_3_weapon_id, slot_3_scene, slot_3_unlocked_by_default))

	for slot_index in range(_slots.size()):
		if _slots[slot_index]["unlocked"]:
			_get_or_create_weapon_instance(slot_index)

	_ensure_active_weapon()
	inventory_changed.emit()


func _make_slot(weapon_id: String, weapon_scene: PackedScene, unlocked: bool) -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"weapon_scene": weapon_scene,
		"weapon_instance": null,
		"display_name": "",
		"unlocked": unlocked,
	}


func _get_or_create_weapon_instance(slot_index: int) -> WeaponBase:
	if not _is_valid_slot(slot_index):
		return null

	var slot := _slots[slot_index]
	if slot["weapon_instance"] != null:
		return slot["weapon_instance"] as WeaponBase

	var weapon_scene := slot["weapon_scene"] as PackedScene
	if not weapon_scene:
		push_warning("WeaponManager: Slot %d has no scene configured" % (slot_index + 1))
		return null

	var weapon := weapon_scene.instantiate() as WeaponBase
	if not weapon:
		push_warning("WeaponManager: Scene for slot %d is not a WeaponBase" % (slot_index + 1))
		return null

	add_child(weapon)
	weapon.position = Vector3.ZERO
	weapon.setup(_camera)
	weapon.deactivate()
	_connect_weapon_signals(weapon)

	slot["weapon_instance"] = weapon
	slot["weapon_id"] = weapon.weapon_id
	slot["display_name"] = weapon.get_display_name()
	_slots[slot_index] = slot
	return weapon


func _connect_weapon_signals(weapon: WeaponBase) -> void:
	weapon.fired.connect(_on_weapon_fired.bind(weapon))
	weapon.alt_fired.connect(_on_weapon_alt_fired.bind(weapon))


func _ensure_active_weapon() -> void:
	if _active_slot_index >= 0 and _is_slot_unlocked(_active_slot_index):
		var active_weapon := _get_or_create_weapon_instance(_active_slot_index)
		if active_weapon:
			active_weapon.activate()
			return

	var fallback_slot := _find_first_unlocked_slot()
	if fallback_slot == -1:
		_active_slot_index = -1
		return

	switch_to_slot(fallback_slot)


func _find_first_unlocked_slot() -> int:
	for slot_index in range(_slots.size()):
		if _is_slot_unlocked(slot_index):
			return slot_index
	return -1


func switch_to_slot(slot_index: int) -> void:
	if not _is_slot_unlocked(slot_index):
		return
	if slot_index == _active_slot_index:
		return

	var next_weapon := _get_or_create_weapon_instance(slot_index)
	if not next_weapon:
		return

	var current_weapon := get_active_weapon()
	if current_weapon:
		current_weapon.deactivate()

	_active_slot_index = slot_index
	next_weapon.activate()
	weapon_changed.emit(next_weapon, _active_slot_index)
	inventory_changed.emit()


func switch_next() -> void:
	var next_slot := _find_relative_unlocked_slot(1)
	if next_slot != -1:
		switch_to_slot(next_slot)


func switch_prev() -> void:
	var prev_slot := _find_relative_unlocked_slot(-1)
	if prev_slot != -1:
		switch_to_slot(prev_slot)


func _find_relative_unlocked_slot(direction: int) -> int:
	if get_unlocked_weapon_count() <= 1:
		return -1

	var start_index := _active_slot_index
	if start_index == -1:
		start_index = _find_first_unlocked_slot()
		if start_index == -1:
			return -1

	var slot_index := start_index
	for _i in range(_slots.size()):
		slot_index = posmod(slot_index + direction, _slots.size())
		if _is_slot_unlocked(slot_index):
			return slot_index

	return -1


func unlock_weapon(weapon_id: String, weapon_scene: PackedScene = null, auto_equip: bool = true) -> bool:
	var slot_index := _find_slot_index_by_weapon_id(weapon_id)
	if slot_index == -1:
		push_warning("WeaponManager: No inventory slot configured for weapon_id '%s'" % weapon_id)
		return false

	var slot := _slots[slot_index]
	if slot["unlocked"]:
		return false

	if weapon_scene:
		slot["weapon_scene"] = weapon_scene
	if slot["weapon_scene"] == null:
		push_warning("WeaponManager: Slot %d cannot unlock '%s' without a scene" % [slot_index + 1, weapon_id])
		return false

	slot["unlocked"] = true
	_slots[slot_index] = slot

	var weapon := _get_or_create_weapon_instance(slot_index)
	if not weapon:
		return false

	weapon_unlocked.emit(weapon, slot_index)
	inventory_changed.emit()

	if auto_equip or _active_slot_index == -1:
		switch_to_slot(slot_index)
	elif get_active_weapon() == null:
		_ensure_active_weapon()

	return true


func has_weapon(weapon_id: String) -> bool:
	var slot_index := _find_slot_index_by_weapon_id(weapon_id)
	return slot_index != -1 and _is_slot_unlocked(slot_index)


func _find_slot_index_by_weapon_id(weapon_id: String) -> int:
	for slot_index in range(_slots.size()):
		var slot_weapon_id := String(_slots[slot_index]["weapon_id"])
		if slot_weapon_id == weapon_id:
			return slot_index
	return -1


func get_active_weapon() -> WeaponBase:
	if not _is_valid_slot(_active_slot_index):
		return null
	return _slots[_active_slot_index]["weapon_instance"] as WeaponBase


func get_weapon_count() -> int:
	return get_unlocked_weapon_count()


func get_unlocked_weapon_count() -> int:
	var count := 0
	for slot in _slots:
		if slot["unlocked"]:
			count += 1
	return count


func get_slot_count() -> int:
	return _slots.size()


func get_active_index() -> int:
	return _active_slot_index


func is_slot_unlocked(slot_index: int) -> bool:
	return _is_slot_unlocked(slot_index)


func get_slot_data(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {}

	var slot := _slots[slot_index]
	var display_name := String(slot["display_name"])
	if display_name.is_empty():
		display_name = "Slot %d" % (slot_index + 1)

	return {
		"slot_index": slot_index,
		"weapon_id": String(slot["weapon_id"]),
		"display_name": display_name,
		"unlocked": bool(slot["unlocked"]),
		"active": slot_index == _active_slot_index,
	}


func get_slots_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for slot_index in range(_slots.size()):
		snapshot.append(get_slot_data(slot_index))
	return snapshot


func register_weapon(weapon: WeaponBase, auto_equip: bool = true) -> void:
	if not weapon:
		return

	var slot_index := _find_slot_index_by_weapon_id(weapon.weapon_id)
	if slot_index == -1:
		push_warning("WeaponManager: register_weapon called for unknown weapon_id '%s'" % weapon.weapon_id)
		return

	var slot := _slots[slot_index]
	if slot["weapon_instance"] == null:
		add_child(weapon)
		weapon.position = Vector3.ZERO
		weapon.setup(_camera)
		weapon.deactivate()
		_connect_weapon_signals(weapon)
		slot["weapon_instance"] = weapon
		slot["weapon_scene"] = null
		slot["display_name"] = weapon.get_display_name()
		slot["weapon_id"] = weapon.weapon_id
		slot["unlocked"] = true
		_slots[slot_index] = slot
		weapon_unlocked.emit(weapon, slot_index)
		inventory_changed.emit()

	if auto_equip:
		switch_to_slot(slot_index)


func _try_fire() -> void:
	var weapon := get_active_weapon()
	if weapon:
		weapon.try_fire()


func _try_alt_fire() -> void:
	var weapon := get_active_weapon()
	if weapon:
		weapon.try_alt_fire()


func _on_weapon_fired(weapon: WeaponBase) -> void:
	weapon_fired.emit(weapon)


func _on_weapon_alt_fired(weapon: WeaponBase) -> void:
	weapon_alt_fired.emit(weapon)


func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _slots.size()


func _is_slot_unlocked(slot_index: int) -> bool:
	return _is_valid_slot(slot_index) and bool(_slots[slot_index]["unlocked"])
