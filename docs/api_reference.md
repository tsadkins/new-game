# Script API

Global classes (Godot `class_name`) used by the arena:

## `Character` — `res://scripts/characters/character.gd`

Shared movement and health for player and enemies. Exports include `move_speed`, `acceleration`, `deceleration`, `max_health`. Emits `died` and health-related signals used by HUD and death UI.

## `Player` — `res://scripts/characters/player.gd`

Click-to-move / click-to-attack controller. Signals: `experience_changed`, `leveled_up`, plus inherited `died`. Finds AnimationPlayer clips at runtime (idle / run / attack / death). Gear and inventory UI are built in `hud.gd`.

## `Enemy` — `res://scripts/characters/enemy.gd`

Simple chase-and-attack AI. Scene: `res://scenes/enemies/enemy.tscn`. Spawned by `EnemySpawner`.

## `Pickup` — `res://scripts/inventory/pickup.gd`

World pickup instance created by `PickupSpawner`.

## Other scripts (no `class_name`)

| Script | Role |
| --- | --- |
| `scripts/characters/camera_follow.gd` | Isometric follow camera |
| `scripts/core/arena.gd` | Arena bounds / walls |
| `scripts/core/arena_decor.gd` | Rocks and crystals |
| `scripts/core/enemy_spawner.gd` | Timed enemy spawns |
| `scripts/core/pickup_spawner.gd` | Timed pickups |
| `scripts/ui/hud.gd` | Health, XP, gear, inventory |
| `scripts/ui/death_screen.gd` | Respawn overlay |

Reserved folders (`scripts/combat`, `scripts/ai`, `scripts/skills`, `scripts/audio`) have no implementations yet.
