class_name ItemPickup
extends Area3D
## Ground item. Walking over it tries to put it in the player inventory.

signal picked_up(item_id: String)

@export var item_id: String = "potion_health_small"
@export var count: int = 1
@export var pickup_radius: float = 1.0
@export var pickup_cooldown: float = 0.5
@export var bob_height: float = 0.15
@export var spin_speed: float = 1.6

var item_instance: ItemInstance
var last_pickup_time: float = -999.0
var _mesh: MeshInstance3D
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	if StarterKitData.load_kit().should_skip_ground_spawn(item_id):
		queue_free()
		return
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	if item_instance == null:
		item_instance = ItemInstance.new(item_id, count)
	_build_visuals()


func _process(delta: float) -> void:
	if _mesh == null:
		return
	_time += delta
	_mesh.rotation.y += spin_speed * delta
	_mesh.position.y = 0.35 + sin(_time * 3.0) * bob_height


func _physics_process(_delta: float) -> void:
	if _collected:
		return
	for body in get_overlapping_bodies():
		if body is Player:
			attempt_pickup()
			return


func attempt_pickup() -> bool:
	if _collected or item_instance == null:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_pickup_time < pickup_cooldown:
		return false
	last_pickup_time = now
	if PlayerInventory.is_full() and not _can_stack_into_bag():
		_toast("Inventory full — use the stash")
		return false
	if not PlayerInventory.add_item(item_instance):
		_toast("Inventory full — use the stash")
		return false
	_collected = true
	emit_pickup_signal(item_instance.item_id)
	queue_free()
	return true


func emit_pickup_signal(picked_item_id: String) -> void:
	picked_up.emit(picked_item_id)
	SaveSystem.queue_save()


func _can_stack_into_bag() -> bool:
	var def := item_instance.definition()
	if def == null or def.unique:
		return false
	var existing := PlayerInventory.current_items.get(item_instance.item_id) as ItemInstance
	return existing != null and existing.count < def.stack_size


func _toast(text: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.show_world_message(text, Color(1.0, 0.85, 0.4))


func _build_visuals() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	shape.shape = sphere
	add_child(shape)

	var def := item_instance.definition()
	var color := def.rarity_color() if def != null else Color.WHITE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.1

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	_mesh.mesh = box
	_mesh.material_override = mat
	add_child(_mesh)

	var label := Label3D.new()
	label.text = def.item_name if def != null else item_id
	label.font_size = 24
	label.position = Vector3(0.0, 0.85, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
