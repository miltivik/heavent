# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HEAVENT** is a fast-paced FPS game in Godot 4, inspired by ULTRAKILL's movement and combat mechanics. The project is in early development with a clear prioritized roadmap.

- **Engine:** Godot 4.0 (Forward+ renderer)
- **Target:** 1920x1080, fullscreen by default
- **Genre:** Arena-based fast-FPS with style ranking system
- **Development Philosophy:** Movement-first. The player controller must feel perfect before other systems.

## Critical Documents

- `docs/FEATURES.md` — Complete implementation guide for all game systems (movement, weapons, enemies, UI, audio, level design)
- `docs/ROADMAP.md` — Ordered scopes with dependencies; Scope 1 (Player Movement) is the critical path

**Read these before making any major changes.**

## Project Structure

```
Heavent/
├── project.godot              # Godot config; input map defined here
├── autoload/                  # Singletons (add in Project Settings)
│   └── [empty currently]      # Planned: style_manager.gd, audio_manager.gd
├── scenes/
│   ├── player/player.tscn    # Player scene (CharacterBody3D + Camera3D)
│   ├── levels/test_level.tscn # Current test level
│   └── effects/
│       └── post_process_overlay.tscn  # Full-screen effects (Ultrakill-style)
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd  # Movement (WASD, jump, air strafing, coyote time, jump buffer)
│   │   └── player_camera.gd      # Mouse look, dynamic FOV, head bob
│   └── utils/
│       ├── damage_effect.gd      # Screen shake + red flash on damage
│       └── post_process_manager.gd # Wrapper for post-process effects
├── assets/                     # Textures, models, materials (organized subfolders)
├── audio/                      # SFX and music (organized subfolders)
└── docs/                       # FEATURES.md, ROADMAP.md
```

## Common Development Commands

### Running the Project

**From Godot Editor:**
1. Open Godot 4, import project from `project.godot`
2. Main scene: `scenes/levels/test_level.tscn` (configured in project.godot)
3. Press F5 to run

**From CLI:**
```bash
# Run the project (starts main scene)
godot --path .

# Run without editor (exports to binary if configured)
godot --headless --script res://main.tscn  # if you create a main launcher

# Export a build (first configure export in editor)
godot --export-release "Linux/X11" /tmp/heavent.x86_64
```

### Script Validation (Linting)

Godot GDScript has a built-in linter. From the project root:

```bash
# Check all scripts for syntax/semantic errors (doesn't run)
godot --check-only --script scripts/player/player_controller.gd --quit

# Validate entire project (slower but catches all)
godot --path . --check-only --quit

# Validate specific file
godot --path . --check-only --script scripts/player/player_camera.gd --quit
```

### Running in Headless Mode (for automated checks)

```bash
# Useful for CI or pre-commit hooks
godot --headless --path . --quit
```

### Debugging

- **In-editor:** Set breakpoints in scripts, use Debugger panel
- **CLI:** `godot --debug --path .` to start with remote debugger
- **Logs:** View output in editor or CLI; use `print()` or `push_error()`

### Scene Management

- Main scene is set in project.godot: `run/main_scene="res://scenes/levels/test_level.tscn"`
- Change via Editor: Project → Project Settings → Application → Run → Main Scene
- Switch scenes at runtime: `get_tree().change_scene_to_file("res://scenes/level_02.tscn")`

## Architecture & Conventions

### Input System

All input actions are defined in `project.godot` under `[input]`. Use action names in code:

- Movement: `move_forward`, `move_back`, `move_left`, `move_right`
- Actions: `move_jump`, `move_dash`, `move_slide`, `move_slam`, `shoot_primary`, `shoot_secondary`
- Weapons: `weapon_next`, `weapon_prev`, `weapon_1`, `weapon_2`, `weapon_3`
- UI: `ui_cancel`

**Add new actions** in Project Settings → Input Map, not in code.

### Player Movement Design (ULTRAKILL-style)

Current implementation (`scripts/player/player_controller.gd`):

- **Ground:** High speed (~450 u/s), snappy acceleration/deceleration
- **Air:** Quake-style air strafing (preserves momentum, no air decel)
- **Gravity:** Escaloned — faster falling than rising for "weight" feel
- **Coyote time:** 6 frames grace period after leaving ground
- **Jump buffering:** 6 frames buffer before landing
- **Variable jump height:** Release jump key early to cut ascent

Camera (`scripts/player/player_camera.gd`):

- Raw mouse input (no smoothing)
- Dynamic FOV: increases with movement speed (90 → 110)
- Head bob on walking (amplitude scales with speed)

**DO NOT simplify or dumb down movement.** The entire game depends on this feeling incredible.

### Post-Processing Pipeline

- `scenes/effects/post_process_overlay.tscn` → full-screen ColorRect with `ultrakill_post_process.gdshader`
- Shader provides: screen shake, damage flash, vignette, pixelation effect
- Access via `PostProcess` autoload or `DamageEffect` component
- Usage: `PostProcess.trigger_damage(intensity)` or emit `damage_taken` signal

See `scripts/utils/post_process_manager.gd` and `scripts/utils/damage_effect.gd`.

### Scene & Script Patterns

- **Player:** `CharacterBody3D` root, `Camera3D` child. Movement logic in controller, camera logic separate.
- **Enemies (planned):** `CharacterBody3D` with state machine (Idle, Chase, Attack, Hurt, Death) + `NavigationAgent3D`
- **Weapons (planned):** State machine pattern (Idle, Fire, AltFire, Reload). Hitscan via RayCast3D, projectiles as RigidBody3D.
- **UI:** `Control` nodes in `CanvasLayer` (layer 1 for HUD). Keep UI logic separate from gameplay.

### Autoloads (Singletons)

Planned (see `docs/FEATURES.md`):

- `StyleManager` — tracks style rank, points, decay
- `AudioManager` — SFX and music buses, ducking
- `GameManager` — level progression, state

**Currently none are configured.** Add via Project Settings → Autoload.

### Asset Organization

Assets are placeholder-organized by type:

```
assets/
├── models/
│   ├── weapons/
│   ├── enemies/
│   └── props/
├── textures/
│   ├── environment/
│   ├── characters/
│   ├── effects/
│   └── ui/
└── materials/
    └── effects/  # contains ultrakill_post_process.tres
```

ImportTexture3D for models, ensure mipmaps for textures.

### Physics & Collision

- Player uses `CharacterBody3D` with capsule collider
- Physics layers (defined in `project.godot`):
  - Layer 1: World
  - Layer 2: Player
  - Layer 3: Enemies
  - Layer 4: Projectiles
  - Layer 5: Pickups

Configure collision masks appropriately. Use groups for flexible querying.

## Development Workflow

1. **Movement first:** If you're implementing new features, ensure existing movement still feels good. Test in `test_level.tscn`.
2. **Iterate on feel:** Use the `--check-only` validation before committing. Playtest constantly.
3. **Follow the roadmap:** `docs/ROADMAP.md` is ordered by priority. Scope 1 (movement) is critical. Don't jump ahead.
4. **Use placeholders:** For audio/art, use simple sounds or colored shapes. Get gameplay working before polish.
5. **Signal-driven design:** Use Godot signals for enemy death, damage events, style updates to keep systems decoupled.
6. **Performance:** Profile with Godot's debugger. Keep scene tree shallow. Use `NavigationRegion3D` for navmesh, not per-enemy pathfinding.

## Godot CLI Reference

```bash
# Open editor (if DISPLAY available)
godot --path .

# Export builds
godot --export "Linux/X11" builds/heavent.x86_64
godot --export-debug "Windows Desktop" builds/heavent.exe

# Run headless tests (if you add GUT tests)
godot --headless --script addons/gut/gut_cmdln.gd -gdir=test

# Deploy to Android (if configured)
godot --export "Android" builds/heavent.apk

# Get help
godot --help
```

## Testing

Project doesn't have a formal test suite yet. Recommended approaches:

- **Manual playtesting:** Use `test_level.tscn` to test movement feel, weapon prototypes, enemy AI.
- **Scene isolation:** Build and test each component in a minimal scene before integrating.
- **Consider adding GUT** (Godot Unit Testing) addon for automated tests, especially for utility functions (`scripts/utils/`).

## Known Issues & TODOs

- No autoloads configured yet (StyleManager, AudioManager pending)
- No weapons implemented (pistol MVP planned for Scope 3)
- No enemies (Filth/Stray planned for Scope 4)
- Health system not implemented (Blood Fuel planned for Scope 5)
- Style rank not implemented (Scope 6)
- Level wave spawner not implemented (Scope 7)
- UI/HUD minimal or missing (Scope 10)
- Audio system not implemented (Scope 11)

See `docs/ROADMAP.md` for full backlog.

## Tips for Claude Code

- **When refactoring:** Keep movement feel identical. Test before/after.
- **When implementing from roadmap:** Read the detailed specs in `docs/FEATURES.md`. It contains exact implementation guidance (scripts, scenes, expected behavior).
- **When creating new scripts:** Follow naming convention: `snake_case.gd`, class_name matches file name. Export variables for tuning.
- **When modifying project.godot:** Document the change in a comment.
- **Performance:** Use `_process()` sparingly; prefer `_physics_process()` for movement. Profile with `Performance` class.

## Relevant Skills to Use

- **`godot` skill:** Use when writing GDScript, building scenes, debugging Godot-specific issues, or validating the project.
- **`superpowers:writing-plans`:** Before implementing major features (weapons, enemies, UI).
- **`superpowers:test-driven-development`:** If a formal test approach is desired (TDD not currently in use).
- **`superpowers:systematic-debugging`:** For any bugs (collision issues, weird movement, state machine problems).

## Excluded

- No npm/bun/traditional web stack — pure Godot
- No database or backend
- No multi-platform build automation yet
- No CI/CD configured

---

**Quick Start:** Open in Godot 4 Editor, press F5, move with WASD, space to jump. The player should feel fast and floaty like ULTRAKILL. If it doesn't, check `scripts/player/player_controller.gd` parameters.
