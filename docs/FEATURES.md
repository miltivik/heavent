# HEAVENT — Base Features & Implementation Guide

> Documento maestro de características del juego y cómo implementarlas en Godot 4.

---

## 1. Player Controller (Movimiento)

**El pilar #1.** Sin un movimiento que *se sienta bien*, el juego no funciona. ULTRAKILL vive o muere por su sensación de velocidad y fluidez.

### Características base
- Velocidad de movimiento alta (ground speed ~450-500 u/s)
- Salto con altura significativa
- Física aérea con control de aire (air strafing estilo Quake)
- Sin fricción excesiva — el jugador debe *deslizarse* por el mapa
- Gravity escalonada (caída más rápida que subida → sensación de peso)

### Implementación en Godot
- **Nodo:** `CharacterBody3D` como raíz del jugador
- **Script:** `player_controller.gd`
- Usar `move_and_slide()` con velocity directa, no `move_and_collide()`
- Implementar air strafing: leer input y aplicar aceleración lateral limitada cuando está en el aire
- `Coyote time` (5-8 frames de gracia para saltar después de dejar el suelo)
- `Jump buffering` (buffer de salto 5-8 frames antes de tocar suelo)
- Límite de velocidad con `velocity.limit_length(max_speed)` pero permitir boosts temporales

### Archivos
```
scenes/player/player.tscn          — Escena del jugador
scripts/player/player_controller.gd — Lógica de movimiento
scripts/player/player_camera.gd     — Cámara en primera persona (MouseLook)
```

---

## 2. Cámara en Primera Persona (FPS Camera)

### Características base
- Sensibilidad de mouse configurable
- Head bob al caminar (oscilación sutil)
- FOV dinámico: aumenta al sprintar/slidear para sensación de velocidad
- Sin aceleración de mouse (raw input)
- Clamp de pitch (-89° a 89°)

### Implementación en Godot
- **Nodo:** `Camera3D` como hijo del `CharacterBody3D`
- Usar `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`
- Capturar `InputEventMouseMotion` en `_input()` para rotación
- FOV base: ~90°, FOV boost: ~105-110° (interpolado suavemente)

### Archivos
```
scripts/player/player_camera.gd — Mouse look, FOV dinámico, head bob
```

---

## 3. Movimiento Avanzado (Movement Tech)

### Características base (por orden de prioridad)
1. **Dash** — impulso rápido en cualquier dirección (cooldown corto, ~1s)
2. **Slide** — deslizamiento manteniendo velocidad al agacharse
3. **Wall jump** — saltar desde paredes
4. **Slam** — caída acelerada hacia el suelo
5. **Dash jump** — combinar dash + salto para mega impulso

### Implementación en Godot
- **Dash:** aplicar un velocity instantáneo en la dirección del input, breve invencibilidad opcional
- **Slide:** reducir collider height, mantener velocity, aplicar boost si el suelo baja
- **Wall jump:** `RayCast3D` lateral, al detectar pared permitir salto con velocity reflejada
- **Slam:** setear velocity.y a un valor negativo alto al presionar la tecla
- Todo en el mismo `player_controller.gd` o separar en `movement_abilities.gd`

### Archivos
```
scripts/player/movement_abilities.gd — Dash, slide, wall jump, slam
```

---

## 4. Armas y Arsenal

### Armas base (MVP)
| Arma | Tipo | Variante A | Variante B |
|------|------|-----------|-----------|
| Pistola (Marksman) | Hitscan | Ricochet (rebota en superficies) | Charge shot (disparo cargado) |
| Escopeta (Pump Charge) | Hitscan/Splash | Spread (disparo múltiple) | Sawblade (sierra proyectil) |
| Revólver (Sharpshooter) | Hitscan | Piercing (atraviesa enemigos) | Railgun mode |

### Monedas (Coin Toss) — mecánica central
- Lanzar moneda con tecla dedicada
- La moneda flota brevemente en el aire
- Disparar a la moneda redirige el disparo al enemigo más cercano
- Si hay múltiples monedas, el disparo rebota entre ellas → combos espectaculares

### Implementación en Godot
- Sistema de armas con patrón **State Machine** (Idle → Fire → Reload → AltFire)
- **Proyectiles:** `RigidBody3D` o `CharacterBody3D` dependiendo del tipo
- **Hitscan:** `RayCast3D` desde la cámara con detección instantánea
- **Coin:** `RigidBody3D` con gravedad reducida, area3D de detección
- **Weapon Manager:** script que gestiona el cambio de armas y variantes

### Archivos
```
scenes/weapons/weapon_base.tscn      — Plantilla base de arma
scenes/weapons/pistol.tscn           — Pistola
scenes/weapons/shotgun.tscn          — Escopeta
scenes/weapons/revolver.tscn         — Revólver
scenes/weapons/projectile_base.tscn  — Proyectil base
scenes/weapons/coin.tscn             — Moneda
scripts/weapons/weapon_manager.gd    — Gestor de armas
scripts/weapons/weapon_base.gd       — Clase base de arma
scripts/weapons/hitscan.gd           — Utilidad para hitscan
scripts/weapons/coin.gd              — Lógica de la moneda
```

---

## 5. Sistema de Salud (Blood Fuel)

### Características base
- Salud máxima: 100 (con posible overhealth hasta 200)
- **No hay regeneración automática**
- Matar enemigos deja "blood splatter" en el suelo
- Acercarse al blood splatter absorbe sangre → cura al jugador
- Cuanto más cerca mates al enemigo, más sangre absorbes directamente
- Overhealth (>100) decae lentamente con el tiempo

### Implementación en Godot
- Variable `health` en el jugador
- Enemigos spawnean un `Area3D` al morir (blood pickup)
- El `Area3D` detecta al jugador y aplica curación
- Overhealth con `Timer` que reduce 1 HP por segundo
- Feedback visual: borde rojo en pantalla cuando baja la salud

### Archivos
```
scripts/player/health_system.gd      — Gestión de salud del jugador
scenes/pickups/blood_splatter.tscn   — Pickup de sangre
scripts/pickups/blood_pickup.gd      — Lógica de absorción
```

---

## 6. Sistema de Estilo (Style Rank)

### Características base
- **Rangos:** D, C, B, A, S, SS, SSS, ULTRAKILL
- Cada acción en combato suma puntos de estilo
- El rango decae si no hacés nada (pasividad = castigo)
- Acciones que suman estilo:
  - Matar enemigos
  - Variedad de armas usadas (no spammear la misma)
  - Kills aéreos
  - Coin shots (disparar monedas)
  - Multi-kills rápidos
  - Kills con proyectiles enemigos (parry)
  - No recibir daño

### Implementación en Godot
- Singleton/Autoload `style_manager.gd`
- Sistema de "combo" con timer de decaimiento (~3-5s sin acción = pierde rango)
- Cada acción tiene un valor base que se multiplica según el rango actual
- Mostrar notificaciones flotantes: "AIRSHOT +150", "RICOSHOT +250"
- HUD con indicador de rango animado

### Archivos
```
autoload/style_manager.gd            — Singleton de estilo
scripts/ui/style_notification.gd     — Notificaciones flotantes
scenes/ui/style_notification.tscn    — Escena de notificación
```

---

## 7. Sistema de Enemigos

### Enemigos base (MVP)
| Enemigo | Comportamiento | Ataque |
|---------|---------------|--------|
| **Filth** | Camina hacia el jugador | Melee (mordida/golpe) |
| **Stray** | Se mantiene a distancia | Proyectil a distancia |
| **Schism** | A media distancia | Tijera de energía (rayo) |
| **Malicious Face (Cerberus)** | Flota, jefe mini | Rayo láser + proyectiles |
| **Swordsmachine** | Jefe temprano | Espadazo + escopeta |

### Implementación en Godot
- **AI con State Machine:** Idle → Chase → Attack → Hurt → Death
- `NavigationAgent3D` para pathfinding
- Cada enemigo: `CharacterBody3D` con script específico que hereda de `enemy_base.gd`
- Señales para eventos: `enemy_died`, `enemy_damaged`
- El enemigo muere → spawnea blood splatter + notifica al Style Manager

### Archivos
```
scenes/enemies/enemy_base.tscn       — Plantilla base de enemigo
scenes/enemies/filth.tscn            — Enemigo básico
scenes/enemies/stray.tscn            — Enemigo rango
scenes/enemies/schism.tscn           — Enemigo medio
scenes/enemies/malicious_face.tscn   — Mini jefe
scenes/enemies/swordsmachine.tscn    — Jefe
scripts/enemies/enemy_base.gd        — Clase base con state machine
scripts/enemies/filth.gd             — Comportamiento específico
scripts/enemies/stray.gd
scripts/enemies/schism.gd
scripts/enemies/malicious_face.gd
scripts/enemies/swordsmachine.gd
```

---

## 8. UI / HUD

### Elementos base
- **Health bar** (esquina inferior izquierda, con overhealth visible)
- **Weapon display** (arma actual + munición, esquina inferior derecha)
- **Style rank** (parte superior derecha, grande y animado)
- **Style notifications** (flotantes en el centro-derecha)
- **Crosshair** (centro, simple, que reacciona al disparar)
- **Speed meter** (opcional, muestra velocidad actual)

### Implementación en Godot
- UI con `Control` nodes, CanvasLayer separado (layer 1)
- `TextureProgressBar` para salud
- `Label` animado para rango de estilo
- Crosshair con `TextureRect` centrado
- Animaciones con `AnimationPlayer` o `Tween`

### Archivos
```
scenes/ui/hud.tscn                   — HUD principal
scenes/ui/main_menu.tscn             — Menú principal
scripts/ui/hud.gd                    — Lógica del HUD
scripts/ui/main_menu.gd              — Lógica del menú
```

---

## 9. Level Design

### Principios de diseño
- **Arenas cerradas** con olas de enemigos (no pasillos largos)
- Espacios verticales (saltos, plataformas altas)
- Paredes para wall jumps
- Rampas para slides
- Salidas rápidas y rutas alternativas
- Secretos escondidos detrás de paredes falsas o saltos difíciles

### Implementación en Godot
- Niveles como escenas `.tscn` separadas
- Usar `GridMap` o modelado directo con `CSGBox3D` para prototipado rápido
- `Area3D` para triggers de olas de enemigos
- `NavigationRegion3D` para que los enemigos naveguen
- Transiciones entre niveles con `change_scene_to_file()`

### Archivos
```
scenes/levels/level_01.tscn          — Primer nivel
scenes/levels/level_02.tscn          — Segundo nivel
scenes/levels/arena_base.tscn        — Plantilla de arena reutilizable
scripts/levels/wave_spawner.gd       — Spawner de olas de enemigos
scripts/levels/level_manager.gd      — Gestión de nivel actual
```

---

## 10. Audio

### Elementos base
- Sonidos de armas (disparo, recarga, cambio)
- Sonidos de movimiento (pasos, dash, slide, landing)
- Música intensa (industrial/metal para combate, ambiental para exploración)
- Sonidos de enemigos (daño, muerte, ataque)
- Sonido de estilo (notificaciones, cambio de rango)

### Implementación en Godot
- `AudioStreamPlayer3D` para sonidos posicionales (armas, enemigos)
- `AudioStreamPlayer` para UI y música (no-posicional)
- Bus de audio separado para música, SFX, UI
- Ducking de música al recibir daño

### Archivos
```
autoload/audio_manager.gd            — Singleton de audio
audio/sfx/                           — Efectos de sonido (.wav/.ogg)
audio/music/                         — Música (.ogg)
```

---

## 11. Controles y Input

### Mapa de input (por defecto)
| Acción | Tecla |
|--------|-------|
| Mover | WASD |
| Salto | Space / Right Click |
| Dash | Shift / Q |
| Slide | Ctrl |
| Disparo primario | Left Click |
| Disparo secundario / Coin | E / R |
| Cambiar arma | 1, 2, 3 / Scroll |
| Slam | S + Space (en aire) |

### Implementación en Godot
- Todas las acciones definidas en `Project > Input Map`
- Input buffering en el controller (no perder inputs entre frames)
- Soporte para gamepad (opcional para MVP, mapear a las mismas acciones)

### Archivos
```
project.godot                        — Input map definido aquí
```

---

## Estructura final de carpetas

```
Heavent/
├── project.godot
├── docs/
│   ├── FEATURES.md                  ← Este documento
│   └── ROADMAP.md                   ← Roadmap ordenado
├── autoload/
│   ├── style_manager.gd
│   ├── audio_manager.gd
│   └── game_manager.gd
├── scenes/
│   ├── player/
│   │   ├── player.tscn
│   │   └── player_camera.gd
│   ├── weapons/
│   │   ├── weapon_base.tscn
│   │   ├── pistol.tscn
│   │   ├── shotgun.tscn
│   │   ├── revolver.tscn
│   │   └── coin.tscn
│   ├── enemies/
│   │   ├── enemy_base.tscn
│   │   ├── filth.tscn
│   │   ├── stray.tscn
│   │   ├── schism.tscn
│   │   ├── malicious_face.tscn
│   │   └── swordsmachine.tscn
│   ├── levels/
│   │   ├── level_01.tscn
│   │   └── level_02.tscn
│   ├── pickups/
│   │   └── blood_splatter.tscn
│   └── ui/
│       ├── hud.tscn
│       └── main_menu.tscn
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd
│   │   ├── player_camera.gd
│   │   ├── movement_abilities.gd
│   │   └── health_system.gd
│   ├── weapons/
│   │   ├── weapon_manager.gd
│   │   ├── weapon_base.gd
│   │   ├── hitscan.gd
│   │   └── coin.gd
│   ├── enemies/
│   │   ├── enemy_base.gd
│   │   ├── filth.gd
│   │   ├── stray.gd
│   │   ├── schism.gd
│   │   ├── malicious_face.gd
│   │   └── swordsmachine.gd
│   ├── levels/
│   │   ├── wave_spawner.gd
│   │   └── level_manager.gd
│   ├── pickups/
│   │   └── blood_pickup.gd
│   ├── ui/
│   │   ├── hud.gd
│   │   ├── main_menu.gd
│   │   └── style_notification.gd
│   └── utils/
│       └── helpers.gd
├── audio/
│   ├── sfx/
│   └── music/
└── assets/
    ├── models/
    ├── textures/
    └── materials/
```
