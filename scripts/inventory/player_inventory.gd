extends Node
## Autoload. The player's personal bag and worn gear. Separate from world stash chests.

signal item_added_to_inventory(item_id: String, count: int)
signal item_removed_from_inventory(item_id: String, count: int)
signal item_equipped(slot: String, item_instance: ItemInstance)
signal item_unequipped(slot: String)
signal inventory_full()
signal item_used(item_id: String, effect_type: String)
signal inventory_changed()

@export var max_inventory_size: int = 50

## storage_key -> ItemInstance (item_id for stacks, instance_id for unique items)
var current_items: Dictionary = {}
## equip_slot -> storage_key
var equipped_items: Dictionary = {}


func slot_count() -> int:
	return current_items.size()


func is_full() -> bool:
	return slot_count() >= max_inventory_size


func add_item(item_instance: ItemInstance, auto_stack: bool = true) -> bool:
	if item_instance == null or item_instance.item_id.is_empty():
		return false
	var def := item_instance.definition()
	if def == null:
		push_warning("PlayerInventory: unknown item_id '%s'." % item_instance.item_id)
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
			remaining -= moved
			item_added_to_inventory.emit(item_instance.item_id, moved)
			inventory_changed.emit()
			return remaining <= 0

	if remaining <= 0:
		return true
	if is_full():
		inventory_full.emit()
		return false

	var stored := ItemInstance.new(item_instance.item_id, remaining)
	stored.custom_properties = item_instance.custom_properties.duplicate(true)
	stored.instance_id = item_instance.instance_id
	current_items[stored.storage_key()] = stored
	item_added_to_inventory.emit(stored.item_id, remaining)
	inventory_changed.emit()
	return true


func remove_item(item_id: String, count: int = 1) -> bool:
	var key := _find_key(item_id)
	if key.is_empty():
		return false
	var inst := current_items[key] as ItemInstance
	if inst.is_equipped:
		return false
	var take: int = mini(count, inst.count)
	inst.count -= take
	if inst.count <= 0:
		current_items.erase(key)
	item_removed_from_inventory.emit(item_id, take)
	inventory_changed.emit()
	return true


func take_item(item_id: String, count: int = 1) -> ItemInstance:
	var key := _find_key(item_id)
	if key.is_empty():
		return null
	var inst := current_items[key] as ItemInstance
	if inst.is_equipped:
		return null
	var take: int = mini(count, inst.count)
	var split := ItemInstance.new(inst.item_id, take)
	split.custom_properties = inst.custom_properties.duplicate(true)
	split.instance_id = inst.instance_id
	remove_item(item_id, take)
	return split


func equip_item(slot: String, item_id: String) -> bool:
	var key := _find_key(item_id)
	if key.is_empty():
		return false
	var inst := current_items[key] as ItemInstance
	var def := inst.definition()
	if def == null or def.get_equip_slot() != slot:
		return false
	if equipped_items.has(slot):
		unequip_item(slot)
	inst.is_equipped = true
	equipped_items[slot] = key
	item_equipped.emit(slot, inst)
	inventory_changed.emit()
	return true


func unequip_item(slot: String) -> ItemInstance:
	if not equipped_items.has(slot):
		return null
	var key: String = equipped_items[slot]
	equipped_items.erase(slot)
	var inst := current_items.get(key) as ItemInstance
	if inst != null:
		inst.is_equipped = false
	item_unequipped.emit(slot)
	inventory_changed.emit()
	return inst


func get_equipped_item(slot: String) -> ItemInstance:
	if not equipped_items.has(slot):
		return null
	return current_items.get(equipped_items[slot]) as ItemInstance


func equipped_stat_bonus(stat: String) -> float:
	var total := 0.0
	for slot in equipped_items.keys():
		var inst := get_equipped_item(str(slot))
		if inst == null:
			continue
		var def := inst.definition()
		if def == null:
			continue
		match stat:
			"damage":
				total += def.base_damage
			"defense":
				total += float(def.defense)
			"attack_speed":
				total += def.attack_speed_bonus
	return total


func use_item(item_id: String) -> bool:
	var key := _find_key(item_id)
	if key.is_empty():
		return false
	var inst := current_items[key] as ItemInstance
	if not inst.use_on_player():
		return false
	var def := inst.definition()
	var effect := "heal" if def.health_restore > 0.0 else "mana"
	remove_item(item_id, 1)
	item_used.emit(item_id, effect)
	return true


func get_unequipped_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in current_items.keys():
		var inst := current_items[key] as ItemInstance
		if inst != null and not inst.is_equipped:
			keys.append(str(key))
	return keys


func save_to_player_data() -> Dictionary:
	var items: Array = []
	for inst in current_items.values():
		items.append((inst as ItemInstance).to_save_dict())
	return {
		"max_inventory_size": max_inventory_size,
		"items": items,
		"equipped_items": equipped_items.duplicate(true),
	}


func load_from_player_data(data: Dictionary) -> void:
	current_items.clear()
	equipped_items.clear()
	max_inventory_size = int(data.get("max_inventory_size", max_inventory_size))
	for entry in data.get("items", []):
		if entry is Dictionary:
			var inst := ItemInstance.from_save_dict(entry)
			current_items[inst.storage_key()] = inst
	var eq: Dictionary = data.get("equipped_items", {})
	for slot in eq.keys():
		equipped_items[str(slot)] = str(eq[slot])
	inventory_changed.emit()


func ensure_empty_start() -> void:
	current_items.clear()
	equipped_items.clear()
	inventory_changed.emit()


## Starter kit must never be added to the bag. SaveSystem puts it in the stash.
func grant_starter_kit() -> void:
	pass


## Pulls starter-kit stacks out of the bag (unequips first) so they can go to stash.
func take_starter_kit_from_bag() -> Array[ItemInstance]:
	var kit := StarterKitData.load_kit()
	var taken: Array[ItemInstance] = []
	for item_id in kit.item_ids:
		_unequip_item_id(str(item_id))
		while true:
			var inst := take_item(str(item_id), 9999)
			if inst == null:
				break
			taken.append(inst)
	return taken


func _unequip_item_id(item_id: String) -> void:
	var slots: Array = equipped_items.keys()
	for slot in slots:
		var inst := get_equipped_item(str(slot))
		if inst != null and inst.item_id == item_id:
			unequip_item(str(slot))


func _find_key(item_id: String) -> String:
	if current_items.has(item_id):
		return item_id
	for key in current_items.keys():
		var inst := current_items[key] as ItemInstance
		if inst != null and (inst.item_id == item_id or inst.instance_id == item_id):
			return str(key)
	return ""
