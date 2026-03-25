extends Area3D
class_name WeaponPickup

## =============================================================================
## WEAPON PICKUP - HEAVENT
## Unlocks a weapon slot when the player walks over it.
## =============================================================================

@export var weapon_id: String = ""
@export var weapon_scene: PackedScene
@export var pickup_name: String = "Nueva arma"
@export var auto_equip_on_pickup: bool = true
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0
@export var spin_speed: float = 1.8

@onready var _mesh: Node3D = $MeshInstance3D

var _base_mesh_position: Vector3 = Vector3.ZERO
var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _mesh:
		_base_mesh_position = _mesh.position


func _process(delta: float) -> void:
	if not _mesh or _collected:
		return

	_mesh.position = _base_mesh_position + Vector3.UP * sin(Time.get_ticks_msec() * 0.001 * bob_speed) * bob_height
	_mesh.rotate_y(spin_speed * delta)


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not (body is PlayerController):
		return

	var player := body as PlayerController
	var weapon_manager := player.get_node_or_null("Camera3D/WeaponManager") as WeaponManager
	if not weapon_manager:
		return

	_collected = true
	var unlocked := weapon_manager.unlock_weapon(weapon_id, weapon_scene, auto_equip_on_pickup)
	if not unlocked:
		push_warning("WeaponPickup: '%s' was already unlocked or not configured" % weapon_id)
	queue_free()
