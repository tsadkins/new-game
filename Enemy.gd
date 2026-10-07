class_name Enemy
extends Character
## Simple chasing enemy. Walks toward the player once in detection range and
## deals contact damage on a cooldown when close enough.
## Movement/health exports (move_speed, acceleration, max_health, ...) come from Character.

## How far away the enemy notices the player.
@export var detection_range: float = 12.0
## Distance at which the enemy stops and attacks.
@export var attack_range: float = 1.6
## Damage dealt per attack.
@export var attack_damage: int = 10
## Seconds between attacks.
@export var attack_cooldown: float = 1.0

@export_group("Death")
## How long the enemy tips over, in seconds.
@export var fall_duration: float = 0.5
## How long the body lies there (liquid draining) before it disappears, counted from death.
@export var death_linger: float = 1.5

var _target: Character
var _attack_timer: float = 0.0

var _fall_mesh: MeshInstance3D
var _fall_axis: Vector3
var _fall_radius: float = 0.5
var _fall_half_height: float = 1.0
var _fall_pivot: Vector3
var _death_position: Vector3
var _rest_basis: Basis
var _rest_position: Vector3


func _ready() -> void:
	super._ready()
	add_to_group("enemies")


func _process(delta: float) -> void:
	super._process(delta) # liquid level
	# A dead enemy must not travel at all: hold it exactly where it died.
	if is_dead:
		global_position = _death_position


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)

	if not is_instance_valid(_target) or _target.is_dead:
		_target = _find_player()

	var desired_velocity := Vector3.ZERO

	if _target:
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()

		if distance <= attack_range:
			if _attack_timer <= 0.0:
				_target.take_damage(attack_damage)
				_attack_timer = attack_cooldown
			# Face the target while attacking.
			rotation.y = lerp_angle(rotation.y, atan2(to_target.x, to_target.z), clampf(turn_speed * delta, 0.0, 1.0))
		elif distance <= detection_range:
			desired_velocity = to_target.normalized() * move_speed

	_move_smoothed(desired_velocity, delta)


## Instead of vanishing instantly, the enemy tips over away from the player, lies there
## while its liquid drains, and is removed after death_linger seconds.
func _die() -> void:
	is_dead = true
	died.emit()
	remove_from_group("enemies") # no longer counts toward spawn limits or click targets
	set_physics_process(false)

	# Freeze in place: drop all momentum and take the body out of physics immediately,
	# so nothing can nudge or push the corpse while it lies there.
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_death_position = global_position

	_start_fall_away_from_player()

	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	await get_tree().create_timer(death_linger).timeout
	queue_free()


func _start_fall_away_from_player() -> void:
	_fall_mesh = _body_mesh
	if _fall_mesh == null:
		for child in get_children():
			if child is MeshInstance3D:
				_fall_mesh = child
				break
	if _fall_mesh == null:
		return

	# Direction pointing from the player toward this enemy (so the enemy falls backward).
	var away := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) # fallback
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var offset := global_position - player.global_position
		offset.y = 0.0
		if offset.length() > 0.01:
			away = offset
	away = away.normalized()

	# Rotating about (away.z, 0, -away.x) tips the top of the capsule toward `away`.
	# Convert that world axis into this body's local space, since the mesh is a child.
	var world_axis := Vector3(away.z, 0.0, -away.x)
	_fall_axis = (global_basis.inverse() * world_axis).normalized()

	_fall_radius = 0.5
	_fall_half_height = 1.0
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null:
		var capsule := collider.shape as CapsuleShape3D
		if capsule != null:
			_fall_radius = capsule.radius
			_fall_half_height = capsule.height * 0.5

	_rest_basis = _fall_mesh.basis
	_rest_position = _fall_mesh.position

	# Pivot on the capsule's bottom rim on the side it falls toward, like a real body
	# tipping over: the feet stay planted and the body swings down onto the floor.
	var local_away := global_basis.inverse() * away
	var bottom_y := _rest_position.y - _fall_half_height
	_fall_pivot = Vector3(local_away.x * _fall_radius, bottom_y, local_away.z * _fall_radius)

	var tween := create_tween()
	tween.tween_method(_set_fall_progress, 0.0, 1.0, fall_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Poses the mesh between standing (0) and lying on the ground (1) by rotating it about
## the pivot at its feet. The rim of the capsule stays on the floor the whole way down.
func _set_fall_progress(progress: float) -> void:
	var step := Basis(_fall_axis, progress * PI / 2.0)
	_fall_mesh.basis = step * _rest_basis
	_fall_mesh.position = _fall_pivot + step * (_rest_position - _fall_pivot)


func _find_player() -> Character:
	var player := get_tree().get_first_node_in_group("player")
	if player is Character and not player.is_dead:
		return player
	return null
