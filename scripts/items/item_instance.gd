class_name ItemInstance
extends Resource
## One stack (or unique copy) of an item. No durability.

@export var item_id: String = ""
@export var count: int = 1
@export var is_equipped: bool = false
@export var custom_properties: Dictionary = {}
@export var instance_id: String = ""


func _init(p_item_id: String = "", p_count: int = 1) -> void:
	item_id = p_item_id
	count = maxi(p_count, 1)
	if instance_id.is_empty():
		instance_id = "%s_%d" % [item_id, Time.get_ticks_usec()]


func definition() -> ItemDefinition:
	return ItemDatabase.get_item_by_id(item_id)


func storage_key() -> String:
	var def := definition()
	if def != null and def.unique:
		return instance_id
	return item_id


func is_usable() -> bool:
	var def := definition()
	return def != null and def.is_consumable() and count > 0


func heal(amount: float) -> void:
	var player := _player()
	if player == null:
		return
	player.heal(maxi(int(round(amount)), 0))
	player.play_heal_flash()


func restore_mana(mana_amount: float) -> void:
	var player := _player()
	if player == null:
		return
	player.restore_mana(mana_amount)


func use_on_player() -> bool:
	if not is_usable():
		return false
	var def := definition()
	if def.health_restore > 0.0:
		heal(def.health_restore)
	if def.mana_restore > 0.0:
		restore_mana(def.mana_restore)
	return true


func to_save_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"count": count,
		"is_equipped": is_equipped,
		"custom_properties": custom_properties.duplicate(true),
		"instance_id": instance_id,
	}


static func from_save_dict(data: Dictionary) -> ItemInstance:
	var inst := ItemInstance.new(str(data.get("item_id", "")), int(data.get("count", 1)))
	inst.is_equipped = bool(data.get("is_equipped", false))
	inst.custom_properties = Dictionary(data.get("custom_properties", {})).duplicate(true)
	inst.instance_id = str(data.get("instance_id", inst.instance_id))
	return inst


func _player() -> Player:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as Player
