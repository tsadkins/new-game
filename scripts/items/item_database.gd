extends Node
## Autoload. Catalog of ItemDefinition templates keyed by item_id. No durability.

static var _ITEMS: Dictionary = {}


func _init() -> void:
	_register_builtins()


func _ready() -> void:
	_load_tres_folder("res://resources/items/")


func get_item_by_id(item_id: String) -> ItemDefinition:
	return _ITEMS.get(item_id) as ItemDefinition


func get_items_by_type(type_name: String) -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for value in _ITEMS.values():
		var def := value as ItemDefinition
		if def != null and def.type == type_name:
			out.append(def)
	return out


func get_items_by_rarity(rarity: String) -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for value in _ITEMS.values():
		var def := value as ItemDefinition
		if def != null and def.rarity == rarity:
			out.append(def)
	return out


func register_item(item_def: ItemDefinition) -> void:
	if item_def == null or item_def.item_id.is_empty():
		push_warning("ItemDatabase: refused to register an item without item_id.")
		return
	_ITEMS[item_def.item_id] = item_def


func unregister_item(item_id: String) -> void:
	_ITEMS.erase(item_id)


func get_all_items() -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for value in _ITEMS.values():
		var def := value as ItemDefinition
		if def != null:
			out.append(def)
	return out


func _load_tres_folder(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			if file_name == "starter_kit_data.tres":
				file_name = dir.get_next()
				continue
			var res := load(folder.path_join(file_name)) as ItemDefinition
			if res != null:
				register_item(res)
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_builtins() -> void:
	_add("sword_iron", "Iron Sword", "A plain iron blade. Reliable, nothing fancy.",
		"weapon", "common", 15.0, 0, 0.0, 0.0, 3.0, "main_hand", 1, 12.0, 0.0)
	_add("sword_steel", "Steel Sword", "Better steel, sharper edge.",
		"weapon", "uncommon", 25.0, 0, 0.0, 0.0, 4.0, "main_hand", 1, 28.0, 0.0)
	_add("dagger_rapid", "Rapid Dagger", "Light and quick. Slightly faster swings.",
		"weapon", "uncommon", 12.0, 0, 0.0, 0.0, 1.5, "main_hand", 1, 18.0, 0.2)
	_add("helmet_iron", "Iron Helmet", "Covers the skull. That's the idea.",
		"armor", "common", 0.0, 5, 0.0, 0.0, 2.0, "head", 1, 10.0, 0.0)
	_add("chestplate_chain", "Chainmail Chestplate", "Rings of iron over a leather backing.",
		"armor", "uncommon", 0.0, 12, 0.0, 0.0, 6.0, "chest", 1, 32.0, 0.0)
	_add("greaves_leather", "Leather Greaves", "Light protection for the legs.",
		"armor", "common", 0.0, 3, 0.0, 0.0, 1.5, "legs", 1, 8.0, 0.0)
	_add("boots_travel", "Travel Boots", "Worn soles, still better than bare feet.",
		"armor", "common", 0.0, 2, 0.0, 0.0, 1.2, "boots", 1, 7.0, 0.0)
	_add("potion_health_small", "Health Potion (Small)", "Restores a little health. Gone when used.",
		"consumable", "common", 0.0, 0, 30.0, 0.0, 0.3, "", 5, 5.0, 0.0)
	_add("potion_mana", "Mana Potion", "Restores a little mana. Gone when used.",
		"consumable", "common", 0.0, 0, 0.0, 40.0, 0.3, "", 3, 8.0, 0.0)
	_add("bread", "Bread", "A dense loaf. Better than fighting on an empty stomach.",
		"consumable", "common", 0.0, 0, 15.0, 0.0, 0.5, "", 99, 2.0, 0.0)


func _add(
		id: String, item_name: String, description: String,
		type: String, rarity: String,
		base_damage: float, defense: int,
		health_restore: float, mana_restore: float,
		weight: float, p_equip_slot: String, stack_size: int,
		sell_value: float, attack_speed_bonus: float
	) -> void:
	if _ITEMS.has(id):
		return
	var def := ItemDefinition.new()
	def.item_id = id
	def.item_name = item_name
	def.description = description
	def.type = type
	def.rarity = rarity
	def.base_damage = base_damage
	def.defense = defense
	def.health_restore = health_restore
	def.mana_restore = mana_restore
	def.weight = weight
	def.icon_path = "res://assets/textures/items/%s.png" % id
	def.set("equip_slot", p_equip_slot)
	def.stack_size = stack_size
	def.sell_value = sell_value
	def.attack_speed_bonus = attack_speed_bonus
	def.unique = false
	register_item(def)
