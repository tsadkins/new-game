class_name Player
extends Character
## Isometric click-to-move player with click-to-attack.
## - Click the ground: the player walks to that point.
## - Hold the button after a ground click: the player keeps following the cursor.
## - Click an enemy: the player chases it and attacks once in range.
## Movement/health exports (move_speed, acceleration, max_health, ...) come from Character.

## Emitted whenever level or experience changes (including on level-up).
signal experience_changed(level: int, experience: int, required: int)
## Emitted once for each level gained.
signal leveled_up(new_level: int)

## Distance from the target at which the player is considered to have arrived.
@export var stop_distance: float = 0.1
## World-space Y height of the ground plane used for click raycasting.
@export var ground_height: float = 0.0
## Which mouse button issues the move/attack command.
@export var move_button: MouseButton = MOUSE_BUTTON_LEFT

@export_group("Attack")
## Distance at which the player can hit an enemy.
@export var attack_range: float = 1.8
## Damage dealt per hit.
@export var attack_damage: int = 25
## Seconds between attacks.
@export var attack_cooldown: float = 0.6
## Extra forgiveness (in world units) around an enemy's collider when clicking on it.
@export var click_tolerance: float = 0.3

@export_group("Regeneration")
## Health restored per tick.
@export var regen_amount: int = 5
## Seconds between regeneration ticks.
@export var regen_interval: float = 1.0

@export_group("Buffs")
## Multiplier applied to move_speed while the speed buff is active.
@export var speed_buff_multiplier: float = 2.0
## Multiplier applied to attack_damage while the damage buff is active.
@export var damage_buff_multiplier: float = 2.0
## How long speed and damage buffs last, in seconds.
@export var buff_duration: float = 10.0

## How long the green flash lasts when a heal pickup is used, in seconds.
@export var heal_flash_duration: float = 0.5

## How tightly the glow hugs the edge. Higher = thinner rim, lower = glow reaches further in.
@export var glow_edge_power: float = 2.5

@export_group("Attributes")
## Strength: adds max health and attack damage.
@export var strength: int = 0:
	set(value):
		strength = maxi(value, 0)
		_on_attributes_changed()
## Dexterity: adds movement speed and attack speed.
@export var dexterity: int = 0:
	set(value):
		dexterity = maxi(value, 0)
		_on_attributes_changed()
## Intelligence: adds defense.
@export var intelligence: int = 0:
	set(value):
		intelligence = maxi(value, 0)
		_on_attributes_changed()

@export_group("Stat Scaling")
## Defense the player has before any intelligence bonus.
@export var base_defense: float = 0.0
## Max health gained per point of strength.
@export var health_per_strength: float = 5.0
## Attack damage gained per point of strength.
@export var damage_per_strength: float = 1.0
## Movement speed (units/sec) gained per point of dexterity.
@export var move_speed_per_dexterity: float = 0.05
## Attack speed gained per point of dexterity, as a fraction (0.01 = 1% faster).
@export var attack_speed_per_dexterity: float = 0.01
## Defense gained per point of intelligence.
@export var defense_per_intelligence: float = 1.0
## Controls how quickly defense pays off: damage taken is multiplied by
## defense_scale / (defense_scale + defense). Higher scale = defense matters less.
@export var defense_scale: float = 100.0

@export_group("Leveling")
## The highest level the player can reach.
@export var max_level: int = 100
## Experience needed to go from level 1 to level 2. Later levels scale up from this.
@export var xp_base: float = 25.0
## How steeply the requirement grows: needed = xp_base * level ^ xp_exponent.
## Anything above 0 makes every level cost more than the one before.
@export var xp_exponent: float = 1.5

@export_group("Respawn")
## Seconds of invulnerability after respawning.
@export var invulnerability_time: float = 2.0
## How long the fall-over animation takes when the player dies.
@export var fall_duration: float = 0.5

var _target_position: Vector3
var _has_target: bool = false
var _attack_target: Character
var _attack_timer: float = 0.0
var _pending_click: bool = false
var _pending_click_pos: Vector2
var _tracking_mouse: bool = false
var _invulnerable_timer: float = 0.0
var _regen_timer: float = 0.0
var _speed_buff_timer: float = 0.0
var _damage_buff_timer: float = 0.0
var _glow_material: ShaderMaterial
var _glow_on: bool = false

## Additive fresnel shader: bright at the model's edges, transparent facing the camera.
const RIM_GLOW_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float edge_power = 2.5;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), edge_power);
	ALBEDO = glow_color.rgb * intensity;
	ALPHA = clamp(fresnel, 0.0, 1.0);
}
"""

const SPEED_COLOR := Color(0.3, 0.8, 1.0)
const DAMAGE_COLOR := Color(1.0, 0.55, 0.2)
const HEAL_COLOR := Color(0.3, 1.0, 0.4)

var _heal_flash_timer: float = 0.0

var _base_max_health: int = 100
var _stats_ready: bool = false

## Current level (starts at 1 every game) and experience earned toward the next level.
var level: int = 1
var experience: int = 0
var _model: MeshInstance3D
var _model_rest_position: Vector3
var _model_rest_basis: Basis
var _pose_tween: Tween
var _fall_axis: Vector3 = Vector3.RIGHT
var _fall_drop: float = 0.5
var _fall_progress: float = 0.0 # 0 = standing, 1 = lying down

var _anim: AnimationPlayer
var _anim_root: Node3D
var _anim_root_rest: Transform3D
var _playing_action: bool = false
var _clip_idle: StringName
var _clip_run: StringName
var _clip_sprint: StringName
var _clip_attack: StringName
var _clip_death: StringName

const ANIM_IDLE := "Idle_Loop"
const ANIM_WALK := "Walk_Loop"
const ANIM_JOG := "Jog_Fwd_Loop"
const ANIM_SPRINT := "Sprint_Loop"
const ANIM_ATTACK := "Punch_Jab"
const ANIM_DEATH := "Death01"


func _ready() -> void:
	# max_health (from Character) is the base value here; fold in the strength bonus
	# before the base class fills health to the maximum.
	_base_max_health = max_health
	max_health = _base_max_health + int(round(strength * health_per_strength))

	super._ready()
	_stats_ready = true
	add_to_group("player")
	_target_position = global_position

	_setup_animations()
	if _model == null:
		_model = _get_model()
	if _model != null:
		_model_rest_position = _model.position
		_model_rest_basis = _model.basis

		# Edge glow: an additive "fresnel" overlay drawn on top of the normal material.
		# It only lights up near the silhouette, so the middle of the model is unchanged.
		var shader := Shader.new()
		shader.code = RIM_GLOW_SHADER
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = shader
		_glow_material.set_shader_parameter("intensity", 0.0)
		_glow_material.set_shader_parameter("edge_power", glow_edge_power)
		if _liquid_material != null:
			_liquid_material.set_shader_parameter("rim_power", glow_edge_power)


## Instead of being deleted, the player falls over and is switched off so it can respawn.
func _die() -> void:
	is_dead = true
	died.emit()
	# Buffs end on death (this also switches the glow off).
	_speed_buff_timer = 0.0
	_damage_buff_timer = 0.0
	_heal_flash_timer = 0.0
	_set_collision_enabled(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	_play_fall_animation()


## Tips the model onto its side and lowers it so it lies on the ground.
func _play_fall_animation() -> void:
	_set_model_visible(true)
	if _play_clip(ANIM_DEATH, 0.1):
		_playing_action = true
		return
	if _model == null:
		return

	# Standing, the capsule's center is half its height above the ground; lying down it is
	# one radius above the ground. Lower the model by the difference.
	_fall_drop = 0.5
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null:
		var capsule := collider.shape as CapsuleShape3D
		if capsule != null:
			_fall_drop = capsule.height * 0.5 - capsule.radius

	# Pick a random horizontal axis to tip over; the tip direction is perpendicular to it.
	var angle := randf() * TAU
	_fall_axis = Vector3(cos(angle), 0.0, sin(angle))

	_set_model_visible(true) # in case death happened mid-flicker
	if _pose_tween != null:
		_pose_tween.kill()
	_pose_tween = create_tween()
	_pose_tween.tween_method(_set_fall_progress, _fall_progress, 1.0, fall_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Stands the model back up (used on respawn).
func _play_stand_animation() -> void:
	if _reset_model_pose():
		return
	if _model == null:
		return
	if _pose_tween != null:
		_pose_tween.kill()
	_pose_tween = create_tween()
	_pose_tween.tween_method(_set_fall_progress, _fall_progress, 0.0, 0.25)


## Poses the model between standing (0) and lying on the ground (1).
func _set_fall_progress(progress: float) -> void:
	_fall_progress = progress
	_model.basis = Basis(_fall_axis, progress * PI / 2.0) * _model_rest_basis
	_model.position.y = _model_rest_position.y - _fall_drop * progress


func _get_model() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null


func _setup_animations() -> void:
	_anim = _find_richest_animation_player()
	if _anim == null:
		return

	# Hide the placeholder capsule; the mannequin is the visible body now.
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false

	_anim_root = _anim.get_parent() as Node3D
	if _anim_root != null:
		_anim_root_rest = _anim_root.transform
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if mesh.get_parent() == self:
			continue
		_model = mesh
		if String(mesh.name).to_lower().contains("mannequin"):
			break

	_resolve_animation_clips()

	if not _anim.animation_finished.is_connected(_on_animation_finished):
		_anim.animation_finished.connect(_on_animation_finished)

	for path in [_clip_idle, _clip_run, _clip_sprint]:
		if String(path).is_empty() or not _anim.has_animation(path):
			continue
		var animation := _anim.get_animation(path)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR

	_play_clip(ANIM_IDLE, 0.0)


func _find_richest_animation_player() -> AnimationPlayer:
	var best: AnimationPlayer = null
	var best_count := -1
	for node in find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		if player == null:
			continue
		var count := player.get_animation_list().size()
		if count > best_count:
			best = player
			best_count = count
	return best


func _resolve_animation_clips() -> void:
	var list := _anim.get_animation_list()
	_clip_idle = _match_clip(list, ["idle_loop", "idle"], ["talking", "torch", "crouch", "pistol", "sword", "swim", "sit", "spell"])
	# Prefer a true run; jog is the fallback if sprint is missing.
	_clip_sprint = _match_clip(list, ["sprint_loop", "sprint"], ["walk", "crouch", "swim"])
	_clip_run = _match_clip(list, ["sprint_loop", "sprint", "jog_fwd_loop", "jog_fwd", "jog", "run_loop", "run"], ["walk", "crouch", "swim"])
	_clip_attack = _match_clip(list, ["punch_jab", "punch_cross", "sword_attack", "punch"], ["enter", "idle"])
	_clip_death = _match_clip(list, ["death01", "death"], [])
	if _clip_run == StringName():
		_clip_run = _match_clip(list, ["walk_loop", "walk"], ["formal", "crouch"])


func _match_clip(list: PackedStringArray, preferred: Array, exclude: Array) -> StringName:
	for needle in preferred:
		var needle_text := String(needle).to_lower()
		for name in list:
			var base := String(name).get_file().to_lower()
			var skipped := false
			for token in exclude:
				if String(token) in base:
					skipped = true
					break
			if skipped:
				continue
			if base == needle_text or base.begins_with(needle_text) or needle_text in base:
				return StringName(name)
	return StringName()


func _clip_path(clip: String) -> StringName:
	match clip:
		ANIM_IDLE:
			return _clip_idle
		ANIM_WALK, ANIM_JOG:
			return _clip_run
		ANIM_SPRINT:
			return _clip_sprint if _clip_sprint != StringName() else _clip_run
		ANIM_ATTACK:
			return _clip_attack
		ANIM_DEATH:
			return _clip_death
	if _anim == null:
		return StringName(clip)
	if _anim.has_animation(clip):
		return StringName(clip)
	for lib in _anim.get_animation_library_list():
		var path := String(lib)
		var full := clip if path.is_empty() else "%s/%s" % [path, clip]
		if _anim.has_animation(full):
			return StringName(full)
	return StringName(clip)


func _play_clip(clip: String, blend: float, force: bool = false) -> bool:
	if _anim == null:
		return false
	var path := _clip_path(clip)
	if path == StringName() or not _anim.has_animation(path):
		return false
	if not force and _anim.current_animation == path and clip != ANIM_ATTACK:
		return true
	_anim.play(path, blend)
	if force or clip == ANIM_ATTACK:
		_anim.seek(0.0, true)
	return true


## Clears death pose / root motion and returns the mannequin to idle.
func _reset_model_pose() -> bool:
	_playing_action = false
	_fall_progress = 0.0
	if _pose_tween != null:
		_pose_tween.kill()
		_pose_tween = null
	if _anim == null:
		return false
	_anim.stop(false)
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		skeleton.reset_bone_poses()
	if _anim_root != null:
		_anim_root.transform = _anim_root_rest
	if _model != null:
		_model.position = _model_rest_position
		_model.basis = _model_rest_basis
	return _play_clip(ANIM_IDLE, 0.0, true)


func _on_animation_finished(_anim_name: StringName) -> void:
	if is_dead:
		return
	_playing_action = false


func _update_locomotion_animation(desired_velocity: Vector3) -> void:
	if _anim == null or _playing_action or is_dead:
		return
	var moving := desired_velocity.length() > 0.15 \
		or Vector3(velocity.x, 0.0, velocity.z).length() > 0.35
	if not moving:
		_play_clip(ANIM_IDLE, 0.2)
		return
	if _speed_buff_timer > 0.0:
		_play_clip(ANIM_SPRINT, 0.15)
	else:
		_play_clip(ANIM_JOG, 0.15)


## Brings the player back where they died, at full health, with temporary invulnerability.
func respawn() -> void:
	velocity = Vector3.ZERO

	# Clear any leftover orders from before death.
	_target_position = global_position
	_has_target = false
	_attack_target = null
	_attack_timer = 0.0
	_pending_click = false
	_tracking_mouse = false
	_speed_buff_timer = 0.0
	_damage_buff_timer = 0.0

	is_dead = false
	health = max_health
	_update_health_label()
	health_changed.emit(health, max_health)

	_play_stand_animation()
	_set_collision_enabled(true)
	set_physics_process(true)
	set_process_unhandled_input(true)

	_invulnerable_timer = invulnerability_time


## Experience needed to advance from `for_level` to the next level.
## It grows with every level; at max level there is nothing left to earn.
func xp_required(for_level: int) -> int:
	if for_level >= max_level:
		return 0
	return maxi(int(round(xp_base * pow(for_level, xp_exponent))), 1)


## Adds experience, leveling up as many times as the amount allows (up to max_level).
func gain_experience(amount: int) -> void:
	if amount <= 0 or is_dead or level >= max_level:
		return

	_spawn_floating_text("+%d XP" % amount, Color(1.0, 0.9, 0.4))
	experience += amount

	while level < max_level and experience >= xp_required(level):
		experience -= xp_required(level)
		level += 1
		leveled_up.emit(level)
		_spawn_floating_text("LEVEL %d!" % level, Color(1.0, 0.75, 0.2))

	if level >= max_level:
		experience = 0 # nothing further to earn

	experience_changed.emit(level, experience, xp_required(level))


## Movement speed: base + dexterity bonus, times any active speed buff.
func current_move_speed() -> float:
	var speed := move_speed + dexterity * move_speed_per_dexterity
	return speed * (speed_buff_multiplier if _speed_buff_timer > 0.0 else 1.0)


## Attack damage: base + strength bonus, times any active damage buff.
func current_attack_damage() -> int:
	var damage := attack_damage + strength * damage_per_strength
	damage *= damage_buff_multiplier if _damage_buff_timer > 0.0 else 1.0
	return maxi(int(round(damage)), 1)


## Attack speed in attacks per second: base rate (1 / attack_cooldown) boosted by dexterity.
func current_attack_speed() -> float:
	return _attack_speed_multiplier() / attack_cooldown


## Seconds between attacks after the dexterity bonus.
func current_attack_cooldown() -> float:
	return attack_cooldown / _attack_speed_multiplier()


## Defense: base + intelligence bonus.
func current_defense() -> float:
	return base_defense + intelligence * defense_per_intelligence


## Fraction of incoming damage that defense removes (0.0 to just under 1.0).
func damage_reduction() -> float:
	var defense := current_defense()
	return defense / (defense + defense_scale) if defense > 0.0 else 0.0


## All the player's current stats and attributes in one place (handy for UI).
func get_stats() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"defense": current_defense(),
		"damage_reduction": damage_reduction(),
		"move_speed": current_move_speed(),
		"attack_speed": current_attack_speed(),
		"damage": current_attack_damage(),
		"strength": strength,
		"dexterity": dexterity,
		"intelligence": intelligence,
	}


## Adds attribute points. attribute: "strength", "dexterity" or "intelligence".
func add_attribute(attribute: String, points: int = 1) -> void:
	match attribute:
		"strength":
			strength += points
		"dexterity":
			dexterity += points
		"intelligence":
			intelligence += points
		_:
			push_warning("Unknown attribute: %s" % attribute)


func _attack_speed_multiplier() -> float:
	return maxf(1.0 + dexterity * attack_speed_per_dexterity, 0.1)


func _on_attributes_changed() -> void:
	# Setters also run while the scene loads, before _ready; ignore those.
	if not _stats_ready:
		return
	_recalculate_max_health()


## Recomputes max health from the base value and strength. Any extra max health also
## heals the same amount; a lower maximum just clamps current health.
func _recalculate_max_health() -> void:
	var new_max := _base_max_health + int(round(strength * health_per_strength))
	if new_max == max_health:
		return
	var difference := new_max - max_health
	max_health = new_max
	if not is_dead:
		health = clampi(health + maxi(difference, 0), 1, max_health)
	_update_health_label()
	health_changed.emit(health, max_health)


## Doubles movement speed (by default) for buff_duration seconds. Re-collecting refreshes it.
func apply_speed_buff() -> void:
	_speed_buff_timer = buff_duration
	_spawn_floating_text("SPEED x" + String.num(speed_buff_multiplier), SPEED_COLOR)


## Doubles attack damage (by default) for buff_duration seconds. Re-collecting refreshes it.
func apply_damage_buff() -> void:
	_damage_buff_timer = buff_duration
	_spawn_floating_text("DAMAGE x" + String.num(damage_buff_multiplier), DAMAGE_COLOR)


## Briefly flashes green. Called by the heal pickup when it actually heals the player.
func play_heal_flash() -> void:
	_heal_flash_timer = heal_flash_duration


## Glows in the color of the active buff(s) for as long as they last (blended if both),
## with a gentle pulse. A heal flash is layered on top: bright green that fades quickly.
func _process(delta: float) -> void:
	super._process(delta) # drains/refills the liquid
	_heal_flash_timer = maxf(_heal_flash_timer - delta, 0.0)

	var speed_on := _speed_buff_timer > 0.0
	var damage_on := _damage_buff_timer > 0.0
	var flash := _heal_flash_timer / maxf(heal_flash_duration, 0.001) # 1 -> 0 as it fades
	var buffed := speed_on or damage_on

	if not buffed and flash <= 0.0:
		_set_glow_active(false)
		return

	var color := HEAL_COLOR
	var energy := 0.0

	if buffed:
		if speed_on and damage_on:
			color = SPEED_COLOR.lerp(DAMAGE_COLOR, 0.5)
		elif speed_on:
			color = SPEED_COLOR
		else:
			color = DAMAGE_COLOR
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		energy = 1.2 * pulse

	if flash > 0.0:
		color = color.lerp(HEAL_COLOR, flash)
		energy += 2.5 * flash

	_set_glow_active(true)
	if _liquid_material != null:
		# The rim glow is built into the liquid shader (see Character.gd).
		_liquid_material.set_shader_parameter("rim_color", color)
		_liquid_material.set_shader_parameter("rim_intensity", energy)
	elif _glow_material != null:
		_glow_material.set_shader_parameter("glow_color", color)
		_glow_material.set_shader_parameter("intensity", energy)


## Turns the edge glow on/off. With the liquid shader it is a shader parameter; without it,
## a separate overlay material is attached to the model.
func _set_glow_active(active: bool) -> void:
	if active == _glow_on:
		return
	_glow_on = active

	if _liquid_material != null:
		if not active:
			_liquid_material.set_shader_parameter("rim_intensity", 0.0)
	elif _model != null and _glow_material != null:
		_model.material_overlay = _glow_material if active else null


## Ignore all damage while the invulnerability window is active.
func take_damage(amount: int) -> void:
	if _invulnerable_timer > 0.0 or amount <= 0:
		return
	# Defense removes a share of the hit, but any hit still does at least 1 damage.
	var reduced := maxi(int(round(amount * (1.0 - damage_reduction()))), 1)
	super.take_damage(reduced)


func _set_model_visible(show_model: bool) -> void:
	if _anim_root != null:
		_anim_root.visible = show_model
		return
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = show_model


func _set_collision_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == move_button:
		# Resolve the click in _physics_process, where physics queries are safe.
		_pending_click = true
		_pending_click_pos = event.position


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)

	# Passive regeneration (physics processing is off while dead, so this only runs alive).
	if health < max_health:
		_regen_timer += delta
		if _regen_timer >= regen_interval:
			_regen_timer -= regen_interval
			heal(regen_amount)
	else:
		_regen_timer = 0.0

	_speed_buff_timer = maxf(_speed_buff_timer - delta, 0.0)
	_damage_buff_timer = maxf(_damage_buff_timer - delta, 0.0)

	if _invulnerable_timer > 0.0:
		_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
		# Flicker the model while invulnerable; solid again when it ends.
		_set_model_visible(_invulnerable_timer <= 0.0 or int(_invulnerable_timer * 10.0) % 2 == 0)

	if _pending_click:
		_pending_click = false
		_handle_click(_pending_click_pos)

	# While the button is held after a ground click, keep steering toward the cursor.
	if _tracking_mouse:
		if Input.is_mouse_button_pressed(move_button):
			var point: Variant = _get_ground_point(get_viewport().get_mouse_position())
			if point != null:
				_target_position = point
				_has_target = true
		else:
			_tracking_mouse = false

	var desired_velocity := Vector3.ZERO

	# Drop the attack target if it died or was freed.
	if _attack_target != null and (not is_instance_valid(_attack_target) or _attack_target.is_dead):
		_attack_target = null

	if _attack_target != null:
		var to_enemy := _attack_target.global_position - global_position
		to_enemy.y = 0.0

		if to_enemy.length() > attack_range:
			desired_velocity = to_enemy.normalized() * current_move_speed()
		else:
			# In range: stand still, face the enemy, and strike on cooldown.
			rotation.y = lerp_angle(rotation.y, atan2(to_enemy.x, to_enemy.z), clampf(turn_speed * delta, 0.0, 1.0))
			if _attack_timer <= 0.0:
				_attack_target.take_damage(current_attack_damage())
				_attack_timer = current_attack_cooldown()
				if _play_clip(ANIM_ATTACK, 0.08):
					_playing_action = true
	elif _has_target:
		# Only consider horizontal distance so ground height doesn't affect arrival.
		var to_target := _target_position - global_position
		to_target.y = 0.0

		if to_target.length() <= stop_distance:
			_has_target = false
		else:
			desired_velocity = to_target.normalized() * current_move_speed()

			# Don't overshoot the target on the final frame.
			var max_step := to_target.length() / maxf(delta, 0.0001)
			if desired_velocity.length() > max_step:
				desired_velocity = to_target.normalized() * max_step

	_move_smoothed(desired_velocity, delta)
	_update_locomotion_animation(desired_velocity)


## Decides what a click means: attack an enemy under the cursor, or move to the ground point.
func _handle_click(screen_pos: Vector2) -> void:
	var enemy := _get_enemy_at(screen_pos)
	if enemy != null:
		_attack_target = enemy
		_has_target = false
		_tracking_mouse = false
		return

	var point: Variant = _get_ground_point(screen_pos)
	if point != null:
		_attack_target = null
		_target_position = point
		_has_target = true
		_tracking_mouse = true


## Returns the enemy under the cursor, if any.
## Measures how close the camera ray passes to each enemy's capsule axis, with a little
## extra click_tolerance, so clicks near the edge of an enemy still count.
func _get_enemy_at(screen_pos: Vector2) -> Enemy:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var ray_start := camera.project_ray_origin(screen_pos)
	var ray_end := ray_start + camera.project_ray_normal(screen_pos) * 1000.0

	var best: Enemy = null
	var best_distance := INF

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue

		# Read the capsule size from the enemy's collider (falls back to defaults).
		var radius := 0.5
		var half_axis := 0.5
		var center := enemy.global_position
		var collider := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collider != null:
			center = collider.global_position
			var capsule := collider.shape as CapsuleShape3D
			if capsule != null:
				radius = capsule.radius
				half_axis = maxf(capsule.height * 0.5 - capsule.radius, 0.0)

		var axis_top := center + Vector3.UP * half_axis
		var axis_bottom := center - Vector3.UP * half_axis
		var closest := Geometry3D.get_closest_points_between_segments(ray_start, ray_end, axis_top, axis_bottom)
		var distance := closest[0].distance_to(closest[1])

		if distance <= radius + click_tolerance and distance < best_distance:
			best = enemy
			best_distance = distance

	return best


## Projects a screen position through the camera onto the ground plane.
## Returns a Vector3 world position, or null if the ray misses the plane.
func _get_ground_point(screen_pos: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)

	var ground_plane := Plane(Vector3.UP, ground_height)
	var point: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)

	# Keep the target inside the walls so a cursor beyond a wall steers the player
	# along it rather than pushing into it.
	var arena := get_tree().get_first_node_in_group("arena")
	if point != null and arena != null and arena.has_method("clamp_to_bounds"):
		point = arena.clamp_to_bounds(point)
	return point
