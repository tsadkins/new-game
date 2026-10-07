class_name Player
extends Character
## Isometric click-to-move player with click-to-attack.
## - Click the ground: the player walks to that point.
## - Hold the button after a ground click: the player keeps following the cursor.
## - Click an enemy: the player chases it and attacks once in range.
## Movement/health exports (move_speed, acceleration, max_health, ...) come from Character.

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
var _model: MeshInstance3D
var _model_rest_position: Vector3
var _model_rest_basis: Basis
var _pose_tween: Tween
var _fall_axis: Vector3 = Vector3.RIGHT
var _fall_drop: float = 0.5
var _fall_progress: float = 0.0 # 0 = standing, 1 = lying down


func _ready() -> void:
	super._ready()
	add_to_group("player")
	_target_position = global_position

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


## Movement speed including any active speed buff.
func current_move_speed() -> float:
	return move_speed * (speed_buff_multiplier if _speed_buff_timer > 0.0 else 1.0)


## Attack damage including any active damage buff.
func current_attack_damage() -> int:
	return int(round(attack_damage * (damage_buff_multiplier if _damage_buff_timer > 0.0 else 1.0)))


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
	if _invulnerable_timer > 0.0:
		return
	super.take_damage(amount)


func _set_model_visible(show_model: bool) -> void:
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
				_attack_timer = attack_cooldown
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
