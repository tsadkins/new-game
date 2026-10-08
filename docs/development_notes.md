# Development notes

## Folder reorg (2026-10-08)

Gameplay files were moved off the project root into `scripts/`, `scenes/`, `assets/`, and `docs/`. `project.godot` `run/main_scene` now points at `res://scenes/main.tscn`. Player, HUD, and death overlay were extracted into packed scenes.

Intentionally **not** created as fake game content: slime/skeleton/boss scenes, skill tree, crafting UI, item databases. Those folders exist with `.gitkeep` until the systems exist.

`addons/terrain_3d` and `demo/` were left in place so the Terrain3D plugin and its sample remain usable.

## Known follow-ups

- First editor open after the move may reimport moved textures and animation GLB/FBX (`source_file` in `.import` was updated).
- Player run clip is resolved from `AnimationPlayer.get_animation_list()` (sprint/jog preferred). If run still falls back to walk, inspect clip names in the imported mannequin.
- Terrain3D is installed but the arena still uses a flat `y = 0` plane and click raycast; heightmap movement is not wired.
