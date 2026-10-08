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
| `HUD.gd` | Level label and experience bar (built in code) |
| `sync-to-github.ps1` | Commits and pushes to GitHub; run daily at 4:30 PM by a scheduled task |
| `CHAT_LOG.md` | This file |

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

**Status:** Done. See entries 35 to 38 for how it got there.
- Ran `git init` (branch `main`) and added `origin` pointing at the URL above.
- Wrote `sync-to-github.ps1`, which commits any changes and pushes to `origin/main`, logging to `sync.log` (git-ignored).
- Registered a Windows scheduled task, `GodotProjectDailySync`, for 4:30 PM every day.

### 35. Git identity
**Prompt:** Provided name and email for commits (Tyler Adkins). The machine's global git identity belonged to someone else, so the identity is set for this repo only.
**Done:** Made the first commit (30 files).

### 36. "Not a git repository" error
**Prompt:** Running the push in PowerShell said "not a git repository".
**Result:** Confirmed `.git` exists at `C:\Users\tadkins\Documents\new-game-project`; the terminal was in the wrong folder. The user corrected this.

### 37. "Repository not found" error
**Prompt:** After fixing the folder, the push said "Repository not found".
**Result:** Explained the likely causes (repo missing or misnamed, or a saved login for a different GitHub account).

### 38. Repo made public, sign-in fixed
**Prompt:** Repo made public and the saved login fixed in Windows Credential Manager; push now works.
**Done:** Verified `main` matches `origin/main`. Registered the scheduled task:
- **Name:** `GodotProjectDailySync`
- **When:** every day at 4:30 PM (the machine is on Central Standard Time)
- **Action:** `powershell.exe -File sync-to-github.ps1` in the project folder
- **Missed runs:** if the computer is off or asleep at 4:30, it runs at the next opportunity
- **Runs only while the user is logged in**
- Results are written to `sync.log`.

### 39. Player level system
**Prompt:** Add a player level system. Start each game at level 1, gain experience from kills toward the next level, max level 100, each level needing more experience than the last.

**Done:**
- `Player.gd`: `level` (starts at 1) and `experience`. `gain_experience(amount)` handles multiple level-ups from one reward and carries leftover XP over. At level 100 it stops awarding XP. Signals: `experience_changed`, `leveled_up`. Level and XP are kept across death and respawn.
- XP curve: `xp_required(level) = round(xp_base * level ^ xp_exponent)` with `xp_base = 25` and `xp_exponent = 1.5`. It strictly increases with level: 25 (L1 to L2), 71 (L2), 130 (L3), 791 (L10), 8,839 (L50), 24,631 (L99). Exports: `max_level`, `xp_base`, `xp_exponent`.
- `Enemy.gd`: new `xp_reward` export (20). Awards XP to the player when the enemy dies.
- `HUD.gd` (new `HUD` node in `Main.tscn`): top-left "Level N" label and a gold XP bar with "XP x / y", or "MAX LEVEL" at the cap. It never blocks clicks.
- Floating text above the player shows `+N XP` and `LEVEL N!` on a level-up.
- Levels do not change any stats yet.

### 40. Player stats and attributes
**Prompt:** Create player stats (health, defense, movement speed, attack speed, damage) and three attributes: strength (health and damage), dexterity (movement speed and attack speed), intelligence (defense). The prompt was sent three times; it was handled once.

**Done (`Player.gd`, `HUD.gd`):**
- **Attributes:** `strength`, `dexterity`, `intelligence` exports (all start at 0, so gameplay is unchanged until points are added). `add_attribute(name, points)` adds points in code.
- **Per-point scaling (exports under Stat Scaling):**
  - Strength: +5 max health, +1 damage.
  - Dexterity: +0.05 move speed, +1% attack speed.
  - Intelligence: +1 defense.
- **Stats:** max health, defense, move speed, attack speed (attacks/sec), damage. `get_stats()` returns them all.
- **Defense:** damage taken is multiplied by `defense_scale / (defense_scale + defense)` with `defense_scale = 100`, so it never reaches 100% reduction. Any hit still does at least 1 damage.
- **Health:** the `max_health` export on `Player.gd` is the base. Raising strength raises max health and heals the same amount; lowering it only clamps current health.
- **Buffs** still multiply on top of the attribute-adjusted speed and damage.
- **HUD:** a stats readout under the XP bar shows health, defense and damage reduction, move speed, attack speed, damage, and STR/DEX/INT.
- Attribute points are not awarded or spendable in-game yet; use the Inspector or `add_attribute()`.

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
| Max level / XP base / XP exponent | `Player.gd` | 100 / 25 / 1.5 |
| XP per enemy kill | `Enemy.gd` | 20 |
| Strength: health / damage per point | `Player.gd` | +5 / +1 |
| Dexterity: move speed / attack speed per point | `Player.gd` | +0.05 / +1% |
| Intelligence: defense per point | `Player.gd` | +1 |
| Defense scale | `Player.gd` | 100 |
