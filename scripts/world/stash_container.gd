class_name StashContainer
extends Node3D
## World chest. Storage is separate from the player's bag. No durability.

signal stash_toggled(is_opening: bool)
signal item_added_to_stash(item_id: String, count: int)
signal item_removed_from_stash(item_id: String, count: int)
signal stash_full()
signal stash_closed()
signal stash_changed()

@export var is_open: bool = false
@export var max_stash_size: int = 100
@export var animation_state: String = "closed"
@export var open_animation_duration: float = 0.35

## storage_key -> ItemInstance
var current_items: Dictionary = {}

var _lid: MeshInstance3D
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("stash")
	if max_stash_size <= 0:
		max_stash_size = PlayerInventory.max_inventory_size * 2
	_build_chest_mesh()


func is_full() -> bool:
	return current_items.size() >= max_stash_size


func get_available_space() -> int:
	return maxi(max_stash_size - current_items.size(), 0)


func toggle_open() -> void:
	if animation_state == "opening" or animation_state == "closing":
		return
	if is_open:
		_play_close(false)
	else:
		_play_open()


func force_close() -> void:
	if not is_open and animation_state == "closed":
		return
	_play_close(true)


func add_item(item_instance: ItemInstance, auto_stack: bool = true) -> bool:
	if item_instance == null:
		return false
	var def := item_instance.definition()
	if def == null:
		return false
	var remaining := item_instance.count
	if auto_stack and not def.unique:
		var existing := current_items.get(item_instance.item_id) as ItemInstance
		if existing != null:
			var space := def.stack_size - existing.count
			if space <= 0:
				return false
			var moved: int = mini(space, remaining)
			existing.count += moved
			item_added_to_stash.emit(item_instance.item_id, moved)
			stash_changed.emit()
			return remaining - moved <= 0
	if is_full():
		stash_full.emit()
		return false
	var stored := ItemInstance.new(item_instance.item_id, remaining)
	stored.custom_properties = item_instance.custom_properties.duplicate(true)
	stored.instance_id = item_instance.instance_id
	current_items[stored.storage_key()] = stored
	item_added_to_stash.emit(stored.item_id, remaining)
	stash_changed.emit()
	return true


func remove_item(item_id: String, count: int = 1) -> bool:
	var key := _find_key(item_id)
	if key.is_empty():
		return false
	var inst := current_items[key] as ItemInstance
	var take: int = mini(count, inst.count)
	inst.count -= take
	if inst.count <= 0:
		current_items.erase(key)
	item_removed_from_stash.emit(item_id, take)
	stash_changed.emit()
	return true


func take_item(item_id: String, count: int = 1) -> ItemInstance:
	var key := _find_key(item_id)
	if key.is_empty():
		return null
	var inst := current_items[key] as ItemInstance
	var take: int = mini(count, inst.count)
	var split := ItemInstance.new(inst.item_id, take)
	split.custom_properties = inst.custom_properties.duplicate(true)
	split.instance_id = inst.instance_id
	remove_item(item_id, take)
	return split


func save_to_player_data() -> Dictionary:
	var items: Array = []
	for inst in current_items.values():
		items.append((inst as ItemInstance).to_save_dict())
	return {
		"max_stash_size": max_stash_size,
		"items": items,
	}


func load_from_player_data(data: Dictionary) -> void:
	current_items.clear()
	max_stash_size = int(data.get("max_stash_size", max_stash_size))
	for entry in data.get("items", []):
		if entry is Dictionary:
			var inst := ItemInstance.from_save_dict(entry)
			current_items[inst.storage_key()] = inst
	stash_changed.emit()


func _play_open() -> void:
	animation_state = "opening"
	stash_toggled.emit(true)
	_animate_lid(-0.7)
	await get_tree().create_timer(open_animation_duration).timeout
	is_open = true
	animation_state = "open"


func _play_close(immediate: bool) -> void:
	animation_state = "closing"
	stash_toggled.emit(false)
	var duration := 0.05 if immediate else open_animation_duration
	_animate_lid(0.0, duration)
	await get_tree().create_timer(duration).timeout
	is_open = false
	animation_state = "closed"
	stash_closed.emit()


func _animate_lid(target_x: float, duration: float = -1.0) -> void:
	if _lid == null:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	var time := open_animation_duration if duration < 0.0 else duration
	_tween.tween_property(_lid, "rotation:x", target_x, time)


func _build_chest_mesh() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.7, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.28, 0.14)
	body.mesh = box
	body.material_override = mat
	body.position.y = 0.35
	add_child(body)

	_lid = MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.24, 0.12, 0.84)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.32, 0.20, 0.10)
	_lid.mesh = lid_mesh
	_lid.material_override = lid_mat
	_lid.position = Vector3(0.0, 0.76, -0.36)
	add_child(_lid)

	var label := Label3D.new()
	label.text = "Stash"
	label.font_size = 32
	label.position = Vector3(0.0, 1.25, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _find_key(item_id: String) -> String:
	if current_items.has(item_id):
		return item_id
	for key in current_items.keys():
		var inst := current_items[key] as ItemInstance
		if inst != null and (inst.item_id == item_id or inst.instance_id == item_id):
			return str(key)
	return ""
