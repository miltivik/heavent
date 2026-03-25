extends Node

## ULTRAKILL-style post-processing manager
## Add this as an autoload singleton named "PostProcess"

@export var enabled: bool = true
@export var pixel_scale: float = 2.0

var overlay: CanvasLayer
var effect_rect: ColorRect

func _ready() -> void:
	# Auto-load the post-process overlay into any scene
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_overlay()

func _setup_overlay() -> void:
	var overlay_scene = load("res://scenes/effects/post_process_overlay.tscn")
	if overlay_scene:
		overlay = overlay_scene.instantiate()
		overlay.add_to_group("post_process_overlay")
		add_child(overlay)
		effect_rect = overlay.get_node("EffectRect")
		_apply_preset()

func _apply_preset() -> void:
	if not effect_rect or not effect_rect.material:
		return
	var mat: ShaderMaterial = effect_rect.material
	mat.set_shader_parameter("pixel_scale", pixel_scale)
	mat.set_shader_parameter("contrast", 1.05)
	mat.set_shader_parameter("brightness", 1.12)
	mat.set_shader_parameter("black_level", 0.14)
	mat.set_shader_parameter("shadow_lift", 0.22)
	mat.set_shader_parameter("scanline_intensity", 0.04)
	mat.set_shader_parameter("vignette_intensity", 0.18)

func set_pixel_scale(value: float) -> void:
	pixel_scale = value
	if effect_rect and effect_rect.material:
		effect_rect.material.set_shader_parameter("pixel_scale", value)

func set_black_level(value: float) -> void:
	## Ajusta el nivel de negro (0.0 = negro puro, 0.3 = negro muy suave)
	if effect_rect and effect_rect.material:
		effect_rect.material.set_shader_parameter("black_level", value)

func toggle_effects() -> void:
	enabled = !enabled
	if overlay:
		overlay.visible = enabled


## --- Damage Effect API ---

func trigger_damage(intensity: float = 1.0) -> void:
	## Disparar efectos de daño (shake + flash)
	var damage_node := get_tree().get_first_node_in_group("damage_effect")
	if damage_node and damage_node.has_method("trigger_damage"):
		damage_node.trigger_damage(intensity)
		return

	# Fallback: aplicar directamente al shader
	if not effect_rect or not effect_rect.material:
		return
	var mat: ShaderMaterial = effect_rect.material

	# Direct shake + flash without component
	var shake := minf(6.0 * intensity, 15.0)
	mat.set_shader_parameter("shake_intensity", shake)
	mat.set_shader_parameter("shake_speed", 25.0)
	mat.set_shader_parameter("damage_flash_intensity", 0.6 * intensity)
	mat.set_shader_parameter("damage_flash_color", Vector3(0.8, 0.05, 0.05))

	# Decay via tween
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_shake, shake, 0.0, 0.3)
	tween.tween_method(_set_flash, 0.6 * intensity, 0.0, 0.2)

func _set_shake(value: float) -> void:
	if effect_rect and effect_rect.material:
		effect_rect.material.set_shader_parameter("shake_intensity", value)

func _set_flash(value: float) -> void:
	if effect_rect and effect_rect.material:
		effect_rect.material.set_shader_parameter("damage_flash_intensity", value)

func get_material() -> ShaderMaterial:
	## Retorna el material del post-procesado para que otros componentes lo usen
	if effect_rect:
		return effect_rect.material as ShaderMaterial
	return null
