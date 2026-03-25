extends WeaponBase
class_name Pistol

## =============================================================================
## PISTOL — HEAVENT (Marksman)
## Hitscan weapon using HitscanUtil. Primary fire is semi-auto.
## Spawns impact effects on surface hits, applies damage via take_damage().
## =============================================================================

@export_group("Pistol")
@export var impact_effect_scene: PackedScene = null

# Collision mask: Layer 1 (World) + Layer 3 (Enemies)
const HITSCAN_MASK: int = 0b00000101


func _on_fire() -> void:
	var origin := get_aim_origin()
	var direction := get_aim_direction()

	var world := get_viewport().world_3d
	if not world:
		return

	var hit := HitscanUtil.cast(world, origin, direction, weapon_range, HITSCAN_MASK)

	if hit["hit"]:
		var collider = hit["collider"]
		var point: Vector3 = hit["point"]
		var normal: Vector3 = hit["normal"]

		# Apply damage if target supports it
		if collider and collider.has_method("take_damage"):
			collider.take_damage(damage, point, direction)

		# Spawn impact effect
		_spawn_impact(point, normal)

		emit_hit_landed(hit)
	
	# Screen shake feedback
	_apply_screen_shake(fire_shake_intensity, fire_shake_duration)


func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	if not impact_effect_scene:
		return

	var effect := impact_effect_scene.instantiate() as Node3D
	if not effect:
		return

	# Add to the scene root (not as child of weapon)
	get_tree().current_scene.add_child(effect)
	effect.global_position = point

	# Orient effect to face along the surface normal
	if normal.length_squared() > 0.001:
		# Look in the direction of the normal (away from surface)
		var up := Vector3.UP
		if abs(normal.dot(up)) > 0.99:
			up = Vector3.FORWARD
		effect.look_at(point + normal, up)


func _apply_screen_shake(intensity: float, duration: float) -> void:
	# Find post-process effect and set shake
	var effect_rect := get_tree().current_scene.find_child("EffectRect", true, false)
	if effect_rect and effect_rect.material:
		var mat := effect_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("shake_intensity", intensity)
			# Reset after duration
			get_tree().create_timer(duration).timeout.connect(
				func(): mat.set_shader_parameter("shake_intensity", 0.0)
			)
