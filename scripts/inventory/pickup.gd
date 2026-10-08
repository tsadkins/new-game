class_name Pickup
extends Area3D
## A buff the player collects by walking over it. The visuals are built in code.
##   HEAL   - restores health instantly
##   SPEED  - doubles move speed for a while (multiplier/duration are set on the Player)
##   DAMAGE - doubles attack damage for a while (multiplier/duration are set on the Player)

enum Type { HEAL, SPEED, DAMAGE }

## Which buff this pickup grants. Set before adding to the scene.
@export var type: Type = Type.HEAL
## Health restored by a HEAL pickup.
@export var heal_amount: int = 50
## Radius of the area that triggers the pickup.
@export var pickup_radius: float = 0.9
## Bobbing height and spin speed of the floating model.
@export var bob_height: float = 0.2
@export var spin_speed: float = 2.0

var _mesh: MeshInstance3D
var _time: float = 0.0
var _base_y: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_build_visuals()
	_time = randf() * TAU # so pickups don't all bob in sync


func _process(delta: float) -> void:
	_time += delta
	_mesh.rotation.y += spin_speed * delta
	_mesh.position.y = _base_y + sin(_time * 3.0) * bob_height


# Polling (rather than the body_entered signal) lets a pickup that was refused earlier,
# like a heal at full health, still be collected later while the player stands on it.
func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		_try_collect(body)
		if _collected:
			return


func _try_collect(body: Node3D) -> void:
	if _collected:
		return
	var player := body as Player
	if player == null or player.is_dead:
		return
	# A heal is wasted at full health, so leave it on the ground.
	if type == Type.HEAL and player.health >= player.max_health:
		return

	_collected = true
	match type:
		Type.HEAL:
			player.heal(heal_amount)
			player.play_heal_flash()
		Type.SPEED:
			player.apply_speed_buff()
		Type.DAMAGE:
			player.apply_damage_buff()
	queue_free()


func _build_visuals() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	shape.shape = sphere
	add_child(shape)

	var color := _color_for_type()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.5

	_mesh = MeshInstance3D.new()
	_mesh.mesh = _mesh_for_type()
	_mesh.material_override = material
	_base_y = 0.0
	add_child(_mesh)

	# A little label so it's clear what each pickup does.
	var label := Label3D.new()
	label.text = _name_for_type()
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_render_priority = 9
	label.pixel_size = 0.008
	label.font_size = 36
	label.outline_size = 8
	label.position = Vector3(0.0, 0.9, 0.0)
	add_child(label)


func _mesh_for_type() -> Mesh:
	match type:
		Type.SPEED:
			var prism := PrismMesh.new()
			prism.size = Vector3(0.7, 0.8, 0.7)
			return prism
		Type.DAMAGE:
			var box := BoxMesh.new()
			box.size = Vector3(0.6, 0.6, 0.6)
			return box
		_:
			var sphere := SphereMesh.new()
			sphere.radius = 0.4
			sphere.height = 0.8
			return sphere


func _color_for_type() -> Color:
	match type:
		Type.SPEED:
			return Color(0.3, 0.8, 1.0)
		Type.DAMAGE:
			return Color(1.0, 0.55, 0.2)
		_:
			return Color(0.3, 1.0, 0.4)


func _name_for_type() -> String:
	match type:
		Type.SPEED:
			return "SPEED"
		Type.DAMAGE:
			return "DAMAGE"
		_:
			return "HEAL"
