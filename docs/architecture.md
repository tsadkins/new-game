# Project architecture

Godot 4.7 3D click-to-move arena. Game content lives under `scripts/`, `scenes/`, `assets/`, and `resources/`. Vendor plugins stay in `addons/`; the Terrain3D sample stays in `demo/` and is not part of the playable game loop.

## Layout

| Path | Purpose |
| --- | --- |
| `scenes/main.tscn` | Playable arena (main scene) |
| `scenes/characters/` | Player and other character scenes |
| `scenes/enemies/` | Enemy packed scenes |
| `scenes/ui/` | HUD, death screen, future menus |
| `scenes/systems/` | Inventory / skill / crafting UI (placeholders) |
| `scenes/transitions/` | Screen transitions (placeholders) |
| `scripts/core/` | Arena, spawners, world decoration |
| `scripts/characters/` | Player, enemy, camera, shared `Character` |
| `scripts/inventory/` | Pickups |
| `scripts/ui/` | HUD and death overlay |
| `scripts/combat/`, `scripts/ai/`, `scripts/skills/`, `scripts/audio/` | Reserved for future systems |
| `assets/textures/environment/` | Ground and rock textures |
| `assets/animations/player_animations/` | Quaternius mannequin + animation libraries |
| `assets/models/`, `assets/materials/`, `assets/shaders/` | 3D props, materials, floor shader |
| `resources/` | Shared data (Terrain3D asset pack, future item/enemy/skill defs) |
| `user_data/` | Local save games and screenshots (not for shipping content) |
| `addons/terrain_3d/` | Terrain3D editor plugin |
| `demo/` | Terrain3D demo scenes; do not mix with arena scripts |

## Conventions

- Use absolute `res://` paths.
- Scripts: `snake_case.gd`. Classes: `PascalCase` via `class_name`.
- Scenes: `snake_case.tscn`.
- Do not put gameplay scripts in the project root.
- Runtime saves belong in `user://` at runtime; `user_data/` is only a project-side folder for captured files you choose to keep.

## Main scene graph

`res://scenes/main.tscn` instances:

- `scenes/characters/player.tscn`
- `scenes/enemies/enemy.tscn`
- `scenes/ui/hud.tscn`
- `scenes/ui/death_screen.tscn`

Camera follow, arena walls, decor, and spawners remain nodes on the main scene with scripts under `scripts/`.
