extends Node

## =============================================================================
## PSX AUTO-APPLY — HEAVENT
## Autoload that applies the PSX material to all MeshInstance3D nodes
## in the scene tree on load and when new nodes are added.
## =============================================================================

const PSX_MATERIAL_PATH := "res://assets/materials/effects/psx_material.tres"

var _psx_material: ShaderMaterial = null


func _ready() -> void:
	_psx_material = load(PSX_MATERIAL_PATH) as ShaderMaterial
	if not _psx_material:
		push_error("PSXAutoApply: Failed to load PSX material at " + PSX_MATERIAL_PATH)
		return

	# Apply to existing scene tree
	get_tree().node_added.connect(_on_node_added)
	# Defer initial scan to ensure scene is fully loaded
	call_deferred("_apply_to_tree", get_tree().root)


func _apply_to_tree(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_material(node as MeshInstance3D)
	for child in node.get_children():
		_apply_to_tree(child)


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		# Defer to ensure the node is fully initialized
		(node as MeshInstance3D).set_deferred("material_override", _psx_material.duplicate())


func _apply_material(mesh_instance: MeshInstance3D) -> void:
	# Don't override if the mesh already has a custom shader material
	if mesh_instance.material_override and mesh_instance.material_override is ShaderMaterial:
		return
	mesh_instance.material_override = _psx_material.duplicate()
