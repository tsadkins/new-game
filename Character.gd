class_name Character
extends CharacterBody3D
## Shared base for the Player and Enemy: smoothed movement plus a health mechanic.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export_group("Health")
## Maximum hit points.
@export var max_health: int = 100
## Show a floating "HP: x/y" label above the character.
@export var show_health_label: bool = true

@export_group("Movement")
## Maximum movement speed in units per second.
@export var move_speed: float = 5.0
## How quickly velocity ramps up toward the target velocity (units/sec^2).
@export var acceleration: float = 20.0
## How quickly velocity ramps down when stopping (units/sec^2).
@export var deceleration: float = 25.0
## Acceleration used when changing direction. Higher = sharper turns (set equal to
## acceleration to get the old, floaty feel).
@export var turn_acceleration: float = 100.0
## How quickly the character turns to face its movement direction (higher = snappier).
@export var turn_speed: float = 20.0
## Gravity applied while airborne. Set to 0 to disable.
@export var gravity: float = 20.0

var health: int
var is_dead: bool = false

@export_group("Liquid Fill")
## Render the body as a glass capsule filled with liquid that drops as health drops.
@export var liquid_fill_enabled: bool = true
## How fast the liquid level moves toward the current health (fraction of the capsule per second).
@export var liquid_fill_speed: float = 1.5

var _health_label: Label3D
var _body_mesh: MeshInstance3D
var _liquid_material: ShaderMaterial
var _fill_display: float = 1.0 # the level currently drawn, 0..1

## Glass capsule with liquid up to `fill` (measured along the mesh's local Y).
## The empty part is faint glass with brighter edges; the liquid part is solid.
const LIQUID_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform vec4 liquid_color : source_color = vec4(0.9, 0.3, 0.2, 1.0);
uniform vec4 glass_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float y_min = -1.0;
uniform float y_max = 1.0;

// Optional edge glow (used for buffs): bright at the silhouette, zero when intensity is 0.
uniform vec3 rim_color : source_color = vec3(1.0);
uniform float rim_intensity = 0.0;
uniform float rim_power = 2.5;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// A small ripple on the surface, only while the capsule is partly filled.
	float ripple_strength = clamp(min(fill, 1.0 - fill) * 20.0, 0.0, 1.0);
	float ripple = sin(local_pos.x * 7.0 + TIME * 3.0) * cos(local_pos.z * 6.0 + TIME * 2.3) * 0.025 * ripple_strength;
	float level = mix(y_min, y_max, fill) + ripple;

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);

	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power) * rim_intensity;

	if (fill > 0.0 && local_pos.y <= level) {
		ALBEDO = liquid_color.rgb;
		EMISSION = liquid_color.rgb * 0.25 + rim_color * rim;
		ROUGHNESS = 0.35;
		ALPHA = 1.0;
	} else {
		ALBEDO = glass_color.rgb;
		EMISSION = rim_color * rim;
		ROUGHNESS = 0.05;
		SPECULAR = 0.8;
		// Emission is scaled by alpha when blending, so raise alpha along with the rim.
		ALPHA = clamp(0.08 + fresnel * 0.45 + rim, 0.0, 1.0);
	}
}
"""


func _ready() -> void:
	health = max_health
	if show_health_label:
		_create_health_label()
	if liquid_fill_enabled:
		_setup_liquid()
	_update_health_label()
	health_changed.emit(health, max_health)


func _process(delta: float) -> void:
	_update_liquid(delta)


# --- Liquid fill ----------------------------------------------------------

func _setup_liquid() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			_body_mesh = child
			break
	if _body_mesh == null or _body_mesh.mesh == null:
		return

	# Use the model's existing color for the liquid, so players stay red and enemies purple.
	var liquid_color := Color(0.9, 0.3, 0.2)
	var base_material := _body_mesh.get_active_material(0) as BaseMaterial3D
	if base_material != null:
		liquid_color = base_material.albedo_color

	var shader := Shader.new()
	shader.code = LIQUID_SHADER
	_liquid_material = ShaderMaterial.new()
	_liquid_material.shader = shader
	_liquid_material.set_shader_parameter("liquid_color", liquid_color)

	var bounds := _body_mesh.mesh.get_aabb()
	_liquid_material.set_shader_parameter("y_min", bounds.position.y)
	_liquid_material.set_shader_parameter("y_max", bounds.end.y)

	_fill_display = float(health) / float(max_health)
	_liquid_material.set_shader_parameter("fill", _fill_display)
	_body_mesh.material_override = _liquid_material


## Eases the drawn liquid level toward the character's current health fraction.
func _update_liquid(delta: float) -> void:
	if _liquid_material == null:
		return
	var target := float(health) / float(max_health)
	if is_equal_approx(_fill_display, target):
		return
	_fill_display = move_toward(_fill_display, target, liquid_fill_speed * delta)
	_liquid_material.set_shader_parameter("fill", _fill_display)


# --- Health ---------------------------------------------------------------

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = maxi(health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(health, max_health)
	_update_health_label()
	if health == 0:
		_die()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	var healed_amount := mini(amount, max_health - health)
	if healed_amount <= 0:
		return # already at full health
	health += healed_amount
	healed.emit(healed_amount)
	health_changed.emit(health, max_health)
	_update_health_label()
	_spawn_floating_text("+%d" % healed_amount, Color(0.3, 1.0, 0.4))


## Spawns a small label that floats up above the character and fades out.
func _spawn_floating_text(text: String, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_render_priority = 9
	label.pixel_size = 0.01
	label.font_size = 40
	label.outline_size = 10
	scene.add_child(label)
	label.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 2.0, 0.0)

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _die() -> void:
	is_dead = true
	died.emit()
	queue_free()


func _create_health_label() -> void:
	_health_label = Label3D.new()
	_health_label.position = Vector3(0.0, 1.6, 0.0)
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.no_depth_test = true
	# Draw after the (alpha-blended) walls so a wall can never cover the text.
	_health_label.render_priority = 10
	_health_label.outline_render_priority = 9
	_health_label.fixed_size = false
	_health_label.pixel_size = 0.01
	_health_label.font_size = 48
	_health_label.outline_size = 12
	# Keep the label upright and unrotated even when the body turns.
	_health_label.top_level = true
	add_child(_health_label)


func _update_health_label() -> void:
	if _health_label:
		_health_label.text = "HP: %d/%d" % [health, max_health]


# --- Movement -------------------------------------------------------------

## Smooths horizontal velocity toward desired_velocity, applies gravity,
## turns to face the direction of travel, and moves the body.
func _move_smoothed(desired_velocity: Vector3, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := deceleration
	if desired_velocity != Vector3.ZERO:
		rate = acceleration
		# Changing direction (not just speeding up): use the much higher turn rate
		# so the character reacts almost instantly instead of drifting.
		if horizontal.length() > 0.1 and horizontal.normalized().dot(desired_velocity.normalized()) < 0.95:
			rate = maxf(acceleration, turn_acceleration)
	horizontal = horizontal.move_toward(desired_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Face where we're trying to go (not where we're still drifting) for instant visual response.
	var facing := desired_velocity if desired_velocity != Vector3.ZERO else horizontal
	if facing.length() > 0.1:
		var target_yaw := atan2(facing.x, facing.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

	move_and_slide()

	# top_level labels don't follow the body automatically.
	if _health_label:
		_health_label.global_position = global_position + Vector3(0.0, 1.6, 0.0)
