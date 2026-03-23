extends Node
class_name DamageEffect

## =============================================================================
## DAMAGE EFFECT — HEAVENT
## Componente de efectos de daño al estilo ULTRAKILL.
## Screen shake + flash rojo en bordes. Señal-driven, totalmente configurable.
##
## USO:
##   1. Añadir como hijo del jugador o como autoload
##   2. Llamar trigger_damage(intensity) desde el sistema de combate
##   3. O emitir la señal damage_taken desde otro componente
## =============================================================================

signal damage_taken(intensity: float)

@export_group("Screen Shake")
@export var shake_base_intensity: float = 6.0
@export var shake_decay: float = 8.0
@export var shake_max_intensity: float = 15.0
@export var shake_speed: float = 25.0

@export_group("Damage Flash")
@export var flash_duration: float = 0.2
@export var flash_max_intensity: float = 0.6
@export var flash_color: Color = Color(0.8, 0.05, 0.05, 1.0)
@export var flash_decay_curve: Curve  # Optional custom decay curve

@export_group("Critical Health")
@export var critical_health_threshold: float = 0.25
@export var critical_pulse_speed: float = 3.0
@export var critical_pulse_intensity: float = 0.15
@export var critical_vignette_boost: float = 0.2

# State
var _shake_intensity: float = 0.0
var _flash_intensity: float = 0.0
var _flash_timer: float = 0.0
var _is_critical: bool = false
var _health_percent: float = 1.0
var _material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("damage_effect")
	damage_taken.connect(_on_damage_taken)
	_find_post_process_material()


func _find_post_process_material() -> void:
	## Busca el ShaderMaterial del post-procesado en el árbol
	var post_process := get_tree().get_first_node_in_group("post_process_overlay")
	if post_process:
		for child in post_process.get_children():
			if child is ColorRect and child.material is ShaderMaterial:
				_material = child.material
				return

	# Fallback: buscar en PostProcess autoload si existe
	if Engine.has_singleton("PostProcess"):
		var pp = Engine.get_singleton("PostProcess")
		if pp.effect_rect and pp.effect_rect.material:
			_material = pp.effect_rect.material
			return


func set_material(mat: ShaderMaterial) -> void:
	## Llamar si el material se asigna manualmente
	_material = mat


func _process(delta: float) -> void:
	if not _material:
		return

	# --- Screen Shake decay ---
	if _shake_intensity > 0.0:
		_shake_intensity = move_toward(_shake_intensity, 0.0, shake_decay * delta)
		_material.set_shader_parameter("shake_intensity", _shake_intensity)
		_material.set_shader_parameter("shake_speed", shake_speed)
	else:
		_material.set_shader_parameter("shake_intensity", 0.0)

	# --- Damage Flash decay ---
	if _flash_timer > 0.0:
		_flash_timer -= delta
		var t: float = 1.0 - (_flash_timer / flash_duration)

		if flash_decay_curve:
			_flash_intensity = flash_max_intensity * (1.0 - flash_decay_curve.sample(t))
		else:
			_flash_intensity = flash_max_intensity * (1.0 - t)

		_material.set_shader_parameter("damage_flash_intensity", _flash_intensity)
		_material.set_shader_parameter("damage_flash_color", Vector3(flash_color.r, flash_color.g, flash_color.b))
	else:
		_material.set_shader_parameter("damage_flash_intensity", 0.0)

	# --- Critical health pulse ---
	if _is_critical:
		var pulse := (sin(Time.get_ticks_msec() * 0.001 * critical_pulse_speed) * 0.5 + 0.5)
		var critical_flash := critical_pulse_intensity * pulse
		var current_flash := _material.get_shader_parameter("damage_flash_intensity") as float
		_material.set_shader_parameter("damage_flash_intensity", maxf(current_flash, critical_flash))
		_material.set_shader_parameter("damage_flash_color", Vector3(0.6, 0.0, 0.0))

		# Boost vignette when critical
		_material.set_shader_parameter("vignette_intensity", 0.35 + critical_vignette_boost * pulse)


## --- API Pública ---

func trigger_damage(intensity: float = 1.0) -> void:
	## Disparar efectos de daño. intensity = 1.0 es daño normal.
	## Usar >1 para daño fuerte, <1 para daño leve.
	var clamped := clampf(intensity, 0.1, 3.0)

	# Shake proporcional al daño
	_shake_intensity = minf(shake_base_intensity * clamped, shake_max_intensity)

	# Flash proporcional
	_flash_intensity = flash_max_intensity * clamped
	_flash_timer = flash_duration * (0.5 + clamped * 0.5)


func trigger_damage_normalized(damage: float, max_health: float) -> void:
	## Disparar daño usando valores reales de juego
	## damage = cantidad de daño recibido, max_health = vida máxima
	var ratio := damage / max_health
	trigger_damage(ratio * 3.0)  # Scale up for feel


func set_health(current: float, max_health: float) -> void:
	## Actualizar estado de vida para efectos críticos
	_health_percent = current / max_health
	var was_critical := _is_critical
	_is_critical = _health_percent <= critical_health_threshold

	# Al entrar en estado crítico, un flash inicial
	if _is_critical and not was_critical:
		trigger_damage(0.5)


func _on_damage_taken(intensity: float) -> void:
	trigger_damage(intensity)


## --- Helpers para integración ---

func attach_to(camera: Camera3D) -> void:
	## Mueve este componente como hijo de la cámara
	if get_parent():
		get_parent().remove_child(self)
	camera.add_child(self)
