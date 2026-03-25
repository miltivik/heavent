# HEAVENT — Roadmap de Desarrollo

> Scopes ordenados del más importante al menos. Cada scope debe ser **jugable y testeable** antes de pasar al siguiente.

---

## Fase 0 — Fundación del Proyecto
**Objetivo:** Proyecto Godot configurado y listo para desarrollo.

- [ ] Crear proyecto Godot 4 (Forward+ renderer)
- [ ] Configurar estructura de carpetas (ver `FEATURES.md`)
- [ ] Definir Input Map (WASD, mouse, acciones base)
- [ ] Configurar viewport (1920x1080, fullscreen por defecto)
- [ ] Crear escena de prueba vacía con suelo plano

**Entregable:** Proyecto Godot vacío pero compilable, con carpetas e input listo.

---

## Scope 1 — Player Movement Core ⭐ (CRÍTICO)
**Objetivo:** Un jugador que se mueve rápido, fluye bien y se siente genial.

Este es el **scope más importante**. Si el movimiento no se siente bien, nada importa. Este scope debe iterarse hasta que esté perfecto.

### Tareas
- [ ] `player.tscn`: `CharacterBody3D` + `CollisionShape3D` (capsule) + `Camera3D`
- [ ] `player_controller.gd`: Movimiento WASD con aceleración y desaceleración
- [ ] Gravedad escalonada (fall speed > jump speed)
- [ ] Salto con altura configurable
- [ ] Air strafing (control lateral en el aire estilo Quake)
- [ ] Coyote time (5-8 frames de gracia para saltar)
- [ ] Jump buffering (5-8 frames de buffer antes de tocar suelo)
- [ ] Límite de velocidad con posibilidad de boosts temporales
- [ ] `player_camera.gd`: Mouse look raw (sin smoothing), sensibilidad configurable
- [ ] Head bob sutil al caminar
- [ ] FOV dinámico (aumenta al sprintar/moverse rápido)
- [ ] Probar en un mapa de test: saltos, rampas, paredes altas

**Entregable:** Jugador moviéndose en un mapa vacío que *se siente* como ULTRAKILL. Rápido, aéreo, flotante.

**Referencia de sensación:**
- Quake air strafing
- Doom 2016 movement speed
- Debe sentirse como "patinar" por el mapa

---

## Scope 2 — Movimiento Avanzado ⭐⭐ (ALTO)
**Objetivo:** Dash, slide, wall jump y slam para un kit de movimiento completo.

### Tareas
- [ ] `movement_abilities.gd`: Separar habilidades del controller principal
- [ ] **Dash:** Impulso rápido en dirección del input, cooldown ~1s
- [ ] **Slide:** Reducir collider height, mantener velocity, boost en bajadas
- [ ] **Wall jump:** Detectar pared con RayCast, permitir salto con velocity reflejada
- [ ] **Slam:** Velocity.y negativa alta al presionar tecla en aire
- [ ] **Dash jump:** Combinar dash + salto para mega impulso
- [ ] Partículas visuales para cada habilidad (dash trail, slide sparks, etc.)
- [ ] Sonidos placeholder para cada habilidad
- [ ] Probar combinaciones: dash → slide → wall jump → slam

**Entregable:** Kit de movimiento completo. Jugador puede navegar niveles verticales y horizontales con estilo.

---

## Scope 3 — Sistema de Armas (MVP) ⭐⭐ (ALTO)
**Objetivo:** Un arma funcional que se puede disparar y probar.

### Tareas
- [ ] `weapon_base.gd`: Clase base con states (Idle, Fire, AltFire, Reload)
- [ ] `weapon_manager.gd`: Gestor de cambio de armas
- [ ] **Pistola (primera arma):**
  - Disparo primario: hitscan (RayCast)
  - Variante ricochet: rebota en superficies
  - Variante charge: disparo cargado con más daño
- [ ] Efecto visual de disparo (muzzle flash, trazador)
- [ ] Impacto en superficies (decals, partículas)
- [ ] Impacto en enemigos (feedback de daño)
- [ ] Sistema de ammo (infinito para pistola, limitado para otras)
- [ ] Feedback screen shake sutil al disparar

**Entregable:** Pistola completamente funcional. Se puede disparar y ver impactos.

---

## Scope 4 — Enemigos Básicos ⭐⭐⭐ (ALTO-MEDIO)
**Objetivo:** Al menos 2 tipos de enemigos con AI funcional.

### Tareas
- [ ] `enemy_base.gd`: Clase base con state machine (Idle, Chase, Attack, Hurt, Death)
- [ ] `NavigationAgent3D` para pathfinding
- [ ] **Filth:** Enemigo melee, camina al jugador, ataca de cerca
- [ ] **Stray:** Enemigo rango, mantiene distancia, lanza proyectiles
- [ ] Sistema de daño (proyectiles del enemigo pueden herir al jugador)
- [ ] Animaciones placeholder (colores que cambian según estado)
- [ ] Muerte de enemigo → spawnea blood splatter
- [ ] Señales: `enemy_died`, `enemy_damaged` para conectar con otros sistemas
- [ ] Probar: 5-10 enemigos en una arena sin destruir performance

**Entregable:** Se puede pelear contra enemigos. Se mueven, atacan y mueren correctamente.

---

## Scope 5 — Sistema de Salud (Blood Fuel) ⭐⭐⭐ (ALTO-MEDIO)
**Objetivo:** Sangre como sistema de salud. Muerte enemiga = curación.

### Tareas
- [ ] `health_system.gd`: Health del jugador (100 max, overhealth hasta 200)
- [ ] `blood_pickup.gd`: Area3D de sangre al morir enemigo
- [ ] Absorción: el jugador se acerca → recupera HP proporcional a la distancia del kill
- [ ] Overhealth decae con Timer (1 HP/s)
- [ ] Borde rojo en pantalla cuando la salud baja (<30)
- [ ] Muerte del jugador → respawn o checkpoint
- [ ] Conectar con enemigos: al morir spawnean blood splatter
- [ ] Probar: matar enemigos, curarse, recibir daño, morir

**Entregable:** Loop completo de salud. Matar para curar. Si no matás, morís.

---

## Scope 6 — Sistema de Estilo ⭐⭐⭐⭐ (MEDIO)
**Objetivo:** Ranking de estilo que recompensa variedad y habilidad.

### Tareas
- [ ] `style_manager.gd`: Autoload singleton
- [ ] Sistema de puntos de estilo con decaimiento por inactividad (~3-5s)
- [ ] Rangos: D → C → B → A → S → SS → SSS → ULTRAKILL
- [ ] Acciones que suman estilo:
  - Kill normal: +50
  - Kill aéreo: +100
  - Coin shot: +250
  - Ricochet kill: +150
  - Multi-kill rápido: +200
  - Variedad de armas: bonus por cambiar
- [ ] `style_notification.gd`: Notificaciones flotantes ("AIRSHOT +100")
- [ ] HUD con indicador de rango animado
- [ ] Multiplier por rango actual (S = x1.5, ULTRAKILL = x4.0)
- [ ] Probar: jugar una arena y ver que el sistema recompensa bien

**Entregable:** Sistema de estilo funcional que motiva jugar de forma agresiva y variada.

---

## Scope 7 — Arena de Combate y Wave Spawner ⭐⭐⭐⭐ (MEDIO)
**Objetivo:** Un nivel jugable donde todo el loop de combate funciona.

### Tareas
- [ ] `arena_base.tscn`: Arena cerrada con plataformas, rampas y paredes
- [ ] `wave_spawner.gd`: Sistema de olas de enemigos
  - Ola 1: 5 Filth
  - Ola 2: 3 Filth + 2 Stray
  - Ola 3: 2 Filth + 3 Stray + 1 Schism
  - Ola 4: Boss (Swordsmachine o Malicious Face)
- [ ] `level_manager.gd`: Gestión de inicio/fin de nivel
- [ ] Portal de salida al completar todas las olas
- [ ] Probar: nivel completo jugable de principio a fin

**Entregable:** Nivel jugable con loop completo: entrar → pelear olas → jefe → salir.

---

## Scope 8 — Armas Adicionales ⭐⭐⭐⭐⭐ (MEDIO-BAJO)
**Objetivo:** Arsenal completo de 3 armas con variantes.

### Tareas
- [ ] **Escopeta (Pump Charge):**
  - Primario: disparo de perdigones (spread)
  - Alt: sierra proyectil que se queda en el suelo
- [ ] **Revólver (Sharpshooter):**
  - Primario: disparo penetrante
  - Alt: modo railgun (carga larga, alto daño)
- [ ] Sistema de cambio de arma fluido (sin delay molesto)
- [ ] Probar: combate con las 3 armas, cambio rápido

**Entregable:** Arsenal de 3 armas con 6 variantes total. Cambio fluido entre ellas.

---

## Scope 9 — Enemigos Avanzados y Jefes ⭐⭐⭐⭐⭐ (MEDIO-BAJO)
**Objetivo:** Completar roster de enemigos con variedad.

### Tareas
- [ ] **Schism:** Ataque de tijera de energía (rayo lineal)
- [ ] **Malicious Face:** Enemigo flotante, rayo láser + proyectiles
- [ ] **Swordsmachine:** Jefe con espadazo + escopeta, fases múltiples
- [ ] Patrones de jefe con fases (más agresivo al bajar de HP)
- [ ] Introducción de cada enemigo (spawn dramático o tutorial)
- [ ] Probar: combates con todos los enemigos, balance de dificultad

**Entregable:** 5 tipos de enemigos + 1 jefe con patrones reconocibles.

---

## Scope 10 — UI/HUD Pulido ⭐⭐⭐⭐⭐⭐ (BAJO)
**Objetivo:** Interfaz visual atractiva e informativa.

### Tareas
- [ ] HUD final: health bar, arma actual, munición, rango de estilo
- [ ] Crosshair reactivo (expande al disparar, cambia color con rango)
- [ ] Menú principal con título animado
- [ ] Pantalla de muerte con estadísticas
- [ ] Pantalla de resultados por nivel (rango final, tiempo, kills)
- [ ] Configuración: sensibilidad, FOV, volumen, keybinds
- [ ] Probar: toda la UI es legible y no obstruye el gameplay

**Entregable:** UI completa y pulida. Información clara sin distraer del combate.

---

## Scope 11 — Audio y Música ⭐⭐⭐⭐⭐⭐⭐ (BAJO)
**Objetivo:** Atmosfera sonora completa.

### Tareas
- [ ] `audio_manager.gd`: Singleton para gestión de audio
- [ ] Sonidos de armas (disparo, impacto, cambio)
- [ ] Sonidos de movimiento (pasos, dash, slide, landing, wall jump)
- [ ] Sonidos de enemigos (daño, muerte, ataque)
- [ ] Música de combate (industrial/metal, intensidad variable)
- [ ] Música ambiental para exploración
- [ ] Ducking: música baja al recibir daño o al morir
- [ ] Probar: toda la experiencia sonora completa

**Entregable:** Experiencia audiovisual completa.

---

## Scope 12 — Niveles Adicionales y Progresión ⭐⭐⭐⭐⭐⭐⭐ (BAJO)
**Objetivo:** Campaña de varios niveles con dificultad creciente.

### Tareas
- [ ] 3-5 niveles con diseño progresivo
- [ ] Cada nivel introduce un nuevo enemigo o mecánica
- [ ] Secretos escondidos en cada nivel
- [ ] Ranking P (perfección) por nivel
- [ ] Pantalla de selección de niveles
- [ ] Progresión: desbloquear armas y variantes

**Entregable:** Campaña jugable de 3-5 niveles con sentido de progresión.

---

## Orden Resumido (de más a menos importante)

| # | Scope | Prioridad | Dependencias |
|---|-------|-----------|-------------|
| 0 | Fundación | Crítica | Ninguna |
| 1 | Player Movement Core | **Crítica** | Scope 0 |
| 2 | Movimiento Avanzado | Alta | Scope 1 |
| 3 | Sistema de Armas MVP | Alta | Scope 1 |
| 4 | Enemigos Básicos | Alta-Media | Scope 1, 3 |
| 5 | Sistema de Salud | Alta-Media | Scope 4 |
| 6 | Sistema de Estilo | Media | Scope 3, 4 |
| 7 | Arena y Wave Spawner | Media | Scope 4, 5, 6 |
| 8 | Armas Adicionales | Media-Baja | Scope 3 |
| 9 | Enemigos Avanzados | Media-Baja | Scope 4 |
| 10 | UI/HUD Pulido | Baja | Scope 5, 6 |
| 11 | Audio y Música | Baja | Todos |
| 12 | Niveles y Progresión | Baja | Scope 7, 8, 9 |

---

## Nota sobre iteración

> **El Scope 1 (Player Movement) debe iterarse hasta que esté perfecto.**
> Si el movimiento no se siente increíble, el juego entero falla.
> Dedicale todo el tiempo necesario. Jugá otros fast-FPS como Quake,
> Doom Eternal y ULTRAKILL para calibrar la sensación.
> Pedile feedback a otros jugadores lo antes posible.
