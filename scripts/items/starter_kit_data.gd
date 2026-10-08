class_name StarterKitData
extends Resource
## First-run kit. Items go into the world stash, never the bag or the ground.

const RESOURCE_PATH := "res://resources/items/starter_kit_data.tres"

## When true, grant_to_stash() is the only legal placement.
@export var stash_only: bool = true
## When true, ItemPickup nodes whose item_id is in this kit delete themselves.
@export var skip_ground_spawn: bool = true
@export var item_ids: PackedStringArray = PackedStringArray([
	"sword_iron",
	"sword_steel",
	"chestplate_chain",
	"potion_mana",
	"bread",
	"potion_health_small",
])
@export var item_counts: PackedInt32Array = PackedInt32Array([1, 1, 1, 3, 2, 5])


static func load_kit() -> StarterKitData:
	var loaded := load(RESOURCE_PATH) as StarterKitData
	return loaded if loaded != null else StarterKitData.new()


func contains(item_id: String) -> bool:
	return item_ids.has(item_id)


func should_skip_ground_spawn(item_id: String) -> bool:
	return stash_only and skip_ground_spawn and contains(item_id)


func entry_count() -> int:
	return mini(item_ids.size(), item_counts.size())


func make_instances() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for i in entry_count():
		var amount: int = maxi(int(item_counts[i]), 1)
		out.append(ItemInstance.new(item_ids[i], amount))
	return out


func grant_to_stash(stash: StashContainer) -> void:
	if stash == null:
		push_warning("StarterKitData: no stash container; kit was not granted.")
		return
	for inst in make_instances():
		if not stash.add_item(inst):
			push_warning("StarterKitData: stash rejected %s x%d." % [inst.item_id, inst.count])
