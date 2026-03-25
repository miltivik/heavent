extends Node3D
class_name WeaponManager

## =============================================================================
## WEAPON MANAGER — HEAVENT
## Lives under Camera3D. Routes input to active weapon, handles switching.
## ULTRAKILL-style: instant weapon swap, no switch delay.
## =============================================================================

signal weapon_changed(weapon: WeaponBase, index: int)
signal weapon_fired(weapon: WeaponBase)
signal weapon_alt_fired(weapon: WeaponBase)

@export_group("Weapon Position")
@export var weapon_offset: Vector3 = Vector3(0.3, -0.25, -0.5)

# --- State ---
var _weapons: Array[WeaponBase] = []
var _active_index: int = -1
var _camera: Camera3D = null


func _ready() -> void:
	# Find camera — expect to be child of Camera3D
	_camera = get_parent() as Camera3D
	if not _camera:
		push_error("WeaponManager: Must be a child of Camera3D")
		return

	# Scan for weapon children
	_scan_weapons()


func _scan_weapons() -> void:
	_weapons.clear()
	for child in get_children():
		if child is WeaponBase:
			var weapon := child as WeaponBase
			weapon.setup(_camera)
			weapon.deactivate()
			weapon.fired.connect(_on_weapon_fired.bind(weapon))
			weapon.alt_fired.connect(_on_weapon_alt_fired.bind(weapon))
			_weapons.append(weapon)

	if _weapons.size() > 0:
		switch_to(0)


func _unhandled_input(event: InputEvent) -> void:
	if not _camera or _weapons.is_empty():
		return

	# --- Fire inputs ---
	if event.is_action_pressed("shoot_primary"):
		_try_fire()
	elif event.is_action_pressed("shoot_secondary"):
		_try_alt_fire()

	# --- Weapon switching ---
	if event.is_action_pressed("weapon_1"):
		switch_to(0)
	elif event.is_action_pressed("weapon_2"):
		switch_to(1)
	elif event.is_action_pressed("weapon_3"):
		switch_to(2)
	elif event.is_action_pressed("weapon_next"):
		switch_next()
	elif event.is_action_pressed("weapon_prev"):
		switch_prev()


# =============================================================================
# WEAPON SWITCHING — Instant (ULTRAKILL style)
# =============================================================================

func switch_to(index: int) -> void:
	if index < 0 or index >= _weapons.size():
		return
	if index == _active_index:
		return

	# Deactivate current
	if _active_index >= 0 and _active_index < _weapons.size():
		_weapons[_active_index].deactivate()

	# Activate new
	_active_index = index
	_weapons[_active_index].activate()
	weapon_changed.emit(_weapons[_active_index], _active_index)


func switch_next() -> void:
	if _weapons.is_empty():
		return
	var next_index := (_active_index + 1) % _weapons.size()
	switch_to(next_index)


func switch_prev() -> void:
	if _weapons.is_empty():
		return
	var prev_index := (_active_index - 1)
	if prev_index < 0:
		prev_index = _weapons.size() - 1
	switch_to(prev_index)


func get_active_weapon() -> WeaponBase:
	if _active_index >= 0 and _active_index < _weapons.size():
		return _weapons[_active_index]
	return null


func get_weapon_count() -> int:
	return _weapons.size()


func get_active_index() -> int:
	return _active_index


## Register a new weapon at runtime (e.g. pickup).
func register_weapon(weapon: WeaponBase) -> void:
	add_child(weapon)
	weapon.setup(_camera)
	weapon.deactivate()
	weapon.fired.connect(_on_weapon_fired.bind(weapon))
	weapon.alt_fired.connect(_on_weapon_alt_fired.bind(weapon))
	_weapons.append(weapon)

	# If this is our first weapon, equip it
	if _weapons.size() == 1:
		switch_to(0)


# =============================================================================
# FIRE ROUTING
# =============================================================================

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
