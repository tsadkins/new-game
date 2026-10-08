extends Node
## Writes player bag + world stash to user://. Call queue_save() after item changes.
## New games put the starter kit in the stash only. Existing saves load as-is.

const SAVE_PATH := "user://player_items.save"

var _save_queued: bool = false
var _stash_save_bound: bool = false


func _ready() -> void:
	PlayerInventory.item_added_to_inventory.connect(_on_inventory_mutated)
	PlayerInventory.item_removed_from_inventory.connect(_on_inventory_mutated)
	PlayerInventory.item_equipped.connect(_on_equipped)
	PlayerInventory.item_unequipped.connect(func(_slot: String) -> void: queue_save())
	call_deferred("_load_or_start")


func is_first_run() -> bool:
	return not FileAccess.file_exists(SAVE_PATH)


func queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	await get_tree().create_timer(0.15).timeout
	_save_queued = false
	save_now()


func save_now() -> void:
	var stash := _stash()
	var player_data := {
		"inventory": PlayerInventory.save_to_player_data(),
		"stash": stash.save_to_player_data() if stash != null else {},
		"starter_kit_in_stash": true,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(player_data))


func load_now() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var player_data: Dictionary = parsed
	PlayerInventory.load_from_player_data(player_data.get("inventory", {}))
	var stash := _stash()
	if stash != null:
		stash.load_from_player_data(player_data.get("stash", {}))
	return true


func _load_or_start() -> void:
	await _wait_for_stash()
	_bind_stash_save()
	if load_now():
		return
	_apply_first_run_starter_kit()
	save_now()


func _apply_first_run_starter_kit() -> void:
	PlayerInventory.ensure_empty_start()
	var kit := StarterKitData.load_kit()
	if not kit.stash_only:
		push_warning("StarterKitData.stash_only is false; kit still goes to stash only.")
	var stash := _stash()
	if stash == null:
		push_warning("SaveSystem: first run, but no stash in the scene. Kit not granted.")
		return
	kit.grant_to_stash(stash)


func _wait_for_stash() -> void:
	var attempts := 0
	while _stash() == null and attempts < 8:
		await get_tree().process_frame
		attempts += 1


func _bind_stash_save() -> void:
	if _stash_save_bound:
		return
	var stash := _stash()
	if stash == null:
		return
	if not stash.stash_changed.is_connected(_on_stash_changed):
		stash.stash_changed.connect(_on_stash_changed)
	_stash_save_bound = true


func _stash() -> StashContainer:
	return get_tree().get_first_node_in_group("stash") as StashContainer


func _on_inventory_mutated(_item_id: String, _count: int) -> void:
	queue_save()


func _on_equipped(_slot: String, _inst: ItemInstance) -> void:
	queue_save()


func _on_stash_changed() -> void:
	queue_save()
