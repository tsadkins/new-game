# Chat Log: Isometric Click-to-Move Game (Godot 4)

A running record of every prompt and what was done in response. New prompts are appended at the bottom.

## Project files (current state)

| File | Purpose |
|---|---|
| `Main.tscn` | Main scene: camera, player, enemy, floor, light, environment, death screen, spawners, arena |
| `Character.gd` | Base class for Player and Enemy: health, smoothed movement, HP label, floating text, liquid-fill shader |
| `Player.gd` | Click-to-move, click-to-attack, regen, buffs, glow, death/respawn |
| `Enemy.gd` / `Enemy.tscn` | Chasing enemy with contact attack and fall-over death |
| `CameraFollow.gd` | Keeps the player centered on screen |
| `DeathScreen.gd` | "You died" popup with Respawn button (built in code) |
| `EnemySpawner.gd` | Spawns an enemy on a timer |
| `Arena.gd` | Builds walls, fades near walls that block the view, clamps click targets |
| `Pickup.gd` / `PickupSpawner.gd` | Heal / speed / damage buffs spawned around the arena |
| `Floor.gdshader` | Earthy floor with mottled dirt and a faint world-space grid |

## Prompt history

### 1. Isometric click-to-move player
**Prompt:** Create `Player.gd` using `CharacterBody3D` for an isometric click-to-move player. Raycast from the camera to the ground plane, include velocity smoothing and an `@export` movement speed.

**Done:** Created `Player.gd`. Click casts a ray from the camera onto a ground `Plane`, then the player walks to that point with `move_toward` acceleration/deceleration smoothing. Exports: `move_speed`, `acceleration`, `deceleration`, `turn_speed`, `stop_distance`, `ground_height`, `move_button`, `gravity`.

### 2. Can't see the player when running
**Done:** `Main.tscn` camera had no 45° turn and was not aimed at the origin, and the player sat half inside the floor. Gave the camera the isometric rotation (-35.264°, 45°) and moved the player to y = 1.

### 3. Still can't see anything
**Done:** The scene had no light or environment, so everything rendered black (a black floor filling the screen). Added a `DirectionalLight3D`, a `WorldEnvironment`, and colored materials for the floor and player.

### 4. Enemy and health (max 100)
**Done:** Created `Character.gd` as a shared base with health (`max_health = 100`, `take_damage`, `heal`, `health_changed`/`damaged`/`healed`/`died` signals, floating HP label). Refactored `Player.gd` to extend it and added `Enemy.gd` (chases the player, deals contact damage on a cooldown) plus a purple enemy in the scene.

### 5. Click an enemy to attack it
**Done:** Clicking an enemy makes the player chase it and attack when in range. Clicking the ground cancels the attack. Exports: `attack_range`, `attack_damage` (25), `attack_cooldown` (0.6).

### 6. Enemy hit box felt off at the edges
**Done:** Replaced the physics raycast with a ray-to-capsule-axis distance test plus a `click_tolerance` export (0.3). Enemies join an `"enemies"` group.

### 7. Instant direction changes
**Done:** Added `turn_acceleration` (100) used when the new heading differs from the current one, raised `turn_speed` to 20, and made the model face the desired direction instead of the lagging velocity.

### 8. Track the mouse while the button is held
**Done:** After a ground click, holding the button keeps re-aiming at the cursor each physics frame. Starting on an enemy does not use hold-tracking.

### 9. Camera follows the player
**Done:** Added `CameraFollow.gd`, keeping the camera's angle and distance so the player stays at screen center. Exports: `target`, `follow_smoothing`.

### 10. Camera not tracking
**Done:** Rewrote `CameraFollow.gd` to update every rendered frame, find the target lazily, and warn if none is found.

### 11. "You died" popup with Respawn
**Done:** Added `DeathScreen.gd` (a `CanvasLayer` that builds its UI in code). Player is now hidden and disabled on death instead of freed. `respawn()` restores full health.

### 12. Respawn where died, 2 seconds invulnerable
**Done:** Respawn keeps the death position. `invulnerability_time = 2.0`; the model flickers during the window and `take_damage` is ignored.

### 13. Fall over on death instead of disappearing
**Done:** Player model tips onto its side and rests on the floor (`fall_duration`). Respawn stands it back up. Popup waits `show_delay` (0.8 s).

### 14. Random fall direction
**Done:** A random horizontal axis is picked each death. The pose is driven by a tween over a 0 to 1 progress value, which also reverses for standing up.

### 15. Heal over time
**Done:** `regen_amount = 5` every `regen_interval = 1.0` s, only while below max health.

### 16. Green heal indicator
**Done:** `heal()` now spawns a floating green `+N` label (actual amount healed) that rises and fades. Added a `healed(amount)` signal.

### 17. Spawn enemies every 7 seconds
**Done:** Made `Enemy.tscn`, added `EnemySpawner.gd` (`spawn_interval = 7`, spawn ring 8 to 14 units from the player, clamped to the arena, `max_enemies = 15`).

### 18. Larger floor, walls, see-through walls
**Done:** Floor to 150×150 and added `Arena.gd`, which builds solid wall segments that fade when blocking the camera's view of the player.

### 19. Northern walls fading, walls covering health values
**Done:** Initial far-wall fix and raised the render priority of HP labels and heal text so alpha-blended walls can't cover them.

### 20. Northern walls still fading, wall blocking movement, shrink arena
**Done:**
- Each wall now has an outward direction; only walls facing the camera can fade (north and west never do).
- Click targets are clamped inside the walls with `clamp_to_bounds()`, so holding the cursor beyond a wall slides the player along it.
- Arena shrunk back to 50×50 (walls at ±25, spawner limit 22).

### 21. Three buffs spawning every 20 seconds
**Done:** `Pickup.gd` plus `PickupSpawner.gd`.
- **Heal:** +50 HP, instant.
- **Speed:** 2× move speed.
- **Damage:** 2× attack damage.
- Buffs last 10 s (`buff_duration`). Exports: `speed_buff_multiplier`, `damage_buff_multiplier`.

### 22. One of each buff at a time; no heal at full health
**Done:** The spawner only picks types not already on the field. Pickups poll overlapping bodies, so a heal refused at full health is collected as soon as the player is hurt while standing on it.

### 23. Glow matching the active buff
**Done:** First version used an emissive material plus a colored light (cyan for speed, orange for damage, blended for both, with a gentle pulse). Dying clears buffs.

### 24. Heal flash
**Done:** `play_heal_flash()` gives a brief bright green flash (`heal_flash_duration = 0.5`) when a heal pickup is actually used.

### 25. Glow on the edge only
**Done:** Replaced the full-body glow with an additive fresnel (rim) shader and removed the colored light. Export: `glow_edge_power`.

### 26. Earthy floor color
**Done:** Floor changed from green to brown (roughly 0.42, 0.31, 0.20), fully matte.

### 27. Liquid-filled capsule that tracks HP
**Done:** Characters render as a glass capsule with liquid up to `health / max_health`. Liquid color comes from the model's existing color. The level eases smoothly (`liquid_fill_speed`), with a small surface ripple. Lives in `Character.gd` so both player and enemies get it.

### 28. Enemy death delay and fall away from the player
**Done:** Enemies tip over away from the player, lie there while the liquid drains, and are removed after `death_linger` (1.5 s). They leave the `"enemies"` group and lose collision immediately.

### 29. Enemies "sliding southwards" when they die
**Done:** Tried several fixes: pinned the corpse in place, zeroed velocity, and adjusted the fall pose.

### 30. Clarification
**Prompt:** The sliding was caused by clicking after killing the enemy, since the camera follows the player and the flat floor gave no sense of movement.
**Result:** Not a bug. Suggested a floor texture and restoring the foot-pivot fall.

### 31. Floor texture and foot-pivot fall
**Done:** Added `Floor.gdshader` (mottled dirt plus a faint world-space grid with stronger lines every 5 cells). Enemy fall now pivots on the bottom rim on the side it falls toward.

### 32. Buff glow stopped working
**Done:** The overlay glow was being drawn under the liquid shader's transparent pass. Moved the rim glow into the liquid shader itself. The old overlay remains as a fallback if `liquid_fill_enabled` is off.

### 33. Chat log (this file)
**Prompt:** Create a markdown file of this entire chat and update it as more prompts are given.
**Done:** Created `CHAT_LOG.md` (this file). It will be appended to after each new prompt.

### 34. Push to GitHub and sync daily at 4:30 PM Central
**Prompt:** Add this project to `https://github.com/tsadkins/new-game.git` and sync it every day at 4:30 PM Central.

**Status:** Local setup done; push is blocked. Daily task not scheduled yet.
- Ran `git init` (branch `main`) and added `origin` pointing at the URL above.
- The machine's global git identity was `daviddorr <ddorr@jpassessor.net>`, so the project uses its own identity instead: **Tyler Adkins <saintsfan349@gmail.com>** (repo-local only).
- Made the first commit (30 files) and wrote `sync-to-github.ps1`, which commits any changes and pushes to `origin/main`, logging to `sync.log`.
- `git push` fails with **"Repository not found"** and no sign-in prompt appeared. Either the repo doesn't exist at that URL, or it is private and this machine isn't signed in to the right GitHub account (the username in the URL is `tsadkins`; the Windows user is `tadkins`).
- Next: once a push succeeds, register a Windows scheduled task for 4:30 PM daily running `sync-to-github.ps1`. The machine is already on Central Standard Time.

---

## Key tunables (quick reference)

| Setting | Where | Default |
|---|---|---|
| Max health | `Character.gd` | 100 |
| Move speed | `Character.gd` / Enemy scene | 5 / 3 |
| Player attack damage / cooldown / range | `Player.gd` | 25 / 0.6 s / 1.8 |
| Enemy attack damage / cooldown / range | `Enemy.gd` | 10 / 1.0 s / 1.6 |
| Regen | `Player.gd` | 5 HP per 1.0 s |
| Invulnerability after respawn | `Player.gd` | 2.0 s |
| Buff duration / multipliers | `Player.gd` | 10 s / 2× |
| Enemy spawn interval / cap | `EnemySpawner.gd` | 7 s / 15 |
| Pickup spawn interval | `PickupSpawner.gd` | 20 s |
| Enemy death linger | `Enemy.gd` | 1.5 s |
| Arena half size | `Arena.gd` | 25 |
