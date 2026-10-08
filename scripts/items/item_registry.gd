extends Node
## Registers extra item templates into ItemDatabase on boot.
## ItemDatabase already has builtins; matching item_ids overwrite those entries.


func _ready() -> void:
	register_all_items()


func register_all_items() -> void:
	ItemDatabase.register_item(_make("sword_iron", "Iron Sword", "A basic iron sword for combat", "weapon", "common", 15.0, 0, 0.0, 0.0, 3.0, "main_hand", 1, 12.0))
	ItemDatabase.register_item(_make("sword_steel", "Steel Sword", "A stronger sword made of steel", "weapon", "uncommon", 25.0, 0, 0.0, 0.0, 4.0, "main_hand", 1, 28.0))
	ItemDatabase.register_item(_make("dagger_rapid", "Rapid Dagger", "A quick, light dagger for fast attacks", "weapon", "common", 12.0, 0, 0.0, 0.0, 1.5, "main_hand", 1, 18.0))
	ItemDatabase.register_item(_make("helmet_iron", "Iron Helmet", "Basic iron helmet for head protection", "armor", "common", 0.0, 5, 0.0, 0.0, 2.0, "head", 1, 10.0))
	ItemDatabase.register_item(_make("chestplate_chain", "Chainmail Chestplate", "Light armor made of chain links", "armor", "uncommon", 0.0, 12, 0.0, 0.0, 6.0, "chest", 1, 32.0))
	ItemDatabase.register_item(_make("potion_health_small", "Health Potion (Small)", "Restores a small amount of health", "consumable", "common", 0.0, 0, 30.0, 0.0, 0.3, "", 5, 5.0))
	ItemDatabase.register_item(_make("potion_mana", "Mana Potion", "Restores mana for spellcasting", "consumable", "common", 0.0, 0, 0.0, 40.0, 0.3, "", 3, 8.0))
	ItemDatabase.register_item(_make("bread", "Bread", "Simple bread that restores a bit of health", "consumable", "common", 0.0, 0, 15.0, 0.0, 0.5, "", 99, 2.0))
	print("=== Items Registered Successfully ===")
	for item in ItemDatabase.get_all_items():
		print("%s - %s - %s" % [item.item_name, item.type, item.rarity])


func _make(
		id: String, display_name: String, description: String,
		type: String, rarity: String,
		base_damage: float, defense: int,
		health_restore: float, mana_restore: float,
		weight: float, p_equip_slot: String, stack_size: int, sell_value: float
	) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.item_id = id
	def.item_name = display_name
	def.description = description
	def.type = type
	def.rarity = rarity
	def.base_damage = base_damage
	def.defense = defense
	def.health_restore = health_restore
	def.mana_restore = mana_restore
	def.weight = weight
	def.set("equip_slot", p_equip_slot)
	def.stack_size = stack_size
	def.sell_value = sell_value
	return def
