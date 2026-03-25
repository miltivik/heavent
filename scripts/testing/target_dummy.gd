extends StaticBody3D
class_name TargetDummy

## =============================================================================
## TARGET DUMMY — HEAVENT
## Test target for weapon development. Receives damage, flashes, prints info.
## =============================================================================

signal damage_received(amount: float, point: Vector3)

@export var flash_duration: float = 0.1
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var _original_color: Color = Color(0.8, 0.2, 0.2, 1.0)
var _mesh_instance: MeshInstance3D = null
var _total_damage: float = 0.0
var _hit_count: int = 0


func _ready() -> void:
	# Find mesh child for flash effect
	for child in get_children():
		if child is MeshInstance3D:
			_mesh_instance = child
			break


func take_damage(amount: float, point: Vector3, _direction: Vector3 = Vector3.ZERO) -> void:
	_total_damage += amount
	_hit_count += 1
	print("[TargetDummy] Hit #%d | Damage: %.1f | Total: %.1f | Point: %s" % [_hit_count, amount, _total_damage, point])
	damage_received.emit(amount, point)
	_flash()


func _flash() -> void:
	if not _mesh_instance:
		return

	# Create a temporary override material for flash
	var mat := StandardMaterial3D.new()
	mat.albedo_color = flash_color
	mat.emission_enabled = true
	mat.emission = flash_color
	mat.emission_energy_multiplier = 2.0
	_mesh_instance.material_override = mat

	get_tree().create_timer(flash_duration).timeout.connect(_reset_material)


func _reset_material() -> void:
	if _mesh_instance:
		_mesh_instance.material_override = null
