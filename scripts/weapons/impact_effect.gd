extends Node3D
class_name ImpactEffect

## =============================================================================
## IMPACT EFFECT — HEAVENT
## Spawned at hitscan hit points. Plays particles then auto-frees.
## =============================================================================

@export var lifetime: float = 1.0


func _ready() -> void:
	# Start all particle children
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
		elif child is CPUParticles3D:
			child.emitting = true

	# Auto-free after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
