extends CanvasLayer
## Menu shown while a world stash chest is open.
## Bag singleton is the autoload at /root/PlayerInventory (not a class_name).

const BAG_PATH := "/root/PlayerInventory"
const SAVE_PATH := "/root/SaveSystem"

@export var player_inventory_node: Node = null
@export var stash_container_node: Node = null

var _stash: Node
var _grid: GridContainer
var _bag_grid: GridContainer
var _summary: Label
var _root: Control
var _modal: Control


func _bag() -> Node:
	if player_inventory_node == null or not is_instance_valid(player_inventory_node):
		player_inventory_node = get_node_or_null(BAG_PATH)
	return player_inventory_node


func _save() -> Node:
	return get_node_or_null(SAVE_PATH)


func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	call_deferred("_bind_nodes")


func _bind_nodes() -> void:
	_stash = stash_container_node
	if _stash == null:
		_stash = get_tree().get_first_node_in_group("stash")
	var bag := _bag()
	if bag != null and not bag.inventory_changed.is_connected(_on_bag_changed):
		bag.inventory_changed.connect(_on_bag_changed)
	if _stash == null:
		push_warning("StashUI: no stash node in group 'stash'.")
		return
	if _stash.has_signal("stash_toggled") and not _stash.stash_toggled.is_connected(_on_stash_toggled):
		_stash.stash_toggled.connect(_on_stash_toggled)
	if _stash.has_signal("stash_closed") and not _stash.stash_closed.is_connected(_on_stash_closed):
		_stash.stash_closed.connect(_on_stash_closed)
	if _stash.has_signal("stash_changed") and not _stash.stash_changed.is_connected(update_stash_display):
		_stash.stash_changed.connect(update_stash_display)
	if _stash.has_signal("stash_full"):
		_stash.stash_full.connect(func() -> void: _summary.text = "Stash is full")
	var bag_label := "MISSING"
	if bag != null:
		bag_label = String(bag.name)
	print("Stash UI bag: ", bag_label, " stash: ", _stash.name)


func update_stash_display() -> void:
	if _stash == null:
		return
	_clear_container(_grid)
	var keys: Array = _stash.current_items.keys()
	keys.sort()
	var shown: int = mini(maxi(keys.size(), 20), _stash.max_stash_size)
	for i in shown:
		if i < keys.size():
			_grid.add_child(_make_item_slot(str(keys[i])))
		else:
			_grid.add_child(_empty_slot())
	_refresh_bag_grid()
	update_inventory_summary()


func _refresh_bag_grid() -> void:
	if _bag_grid == null:
		return
	var bag := _bag()
	if bag == null:
		return
	_clear_container(_bag_grid)
	var keys: Array = bag.current_items.keys()
	keys.sort()
	for key in keys:
		var inst: ItemInstance = bag.current_items[key]
		if inst == null or inst.is_equipped:
			continue
		_bag_grid.add_child(_make_bag_slot(str(key)))


func _clear_container(container: GridContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()


func _on_bag_changed() -> void:
	if visible:
		_refresh_bag_grid()
	update_inventory_summary()


func update_inventory_summary() -> void:
	var bag := _bag()
	var stash_used := 0
	if _stash != null:
		stash_used = _stash.current_items.size()
		_summary.text = "Player inventory: %d/%d   Stash: %d/%d  (left-click: details, right-click: move)" % [
			bag.slot_count() if bag else 0,
			bag.max_inventory_size if bag else 0,
			stash_used,
			_stash.max_stash_size,
		]


func on_close_button_pressed() -> void:
	if _stash != null and _stash.is_open:
		_stash.force_close()
	_hide_ui()


func on_move_all_to_stash_pressed() -> void:
	var bag := _bag()
	if _stash == null or bag == null:
		return
	for key in bag.get_unequipped_keys():
		var inst: ItemInstance = bag.current_items.get(key)
		if inst == null:
			continue
		var taken: ItemInstance = bag.take_item(key, inst.count)
		if taken == null:
			continue
		if not _stash.add_item(taken):
			bag.add_item(taken)
			break
	update_stash_display()
	_queue_save()


func on_move_all_to_inventory_pressed() -> void:
	var bag := _bag()
	if _stash == null or bag == null:
		return
	var keys: Array = _stash.current_items.keys()
	for key in keys:
		var inst: ItemInstance = _stash.current_items.get(key)
		if inst == null:
			continue
		var taken: ItemInstance = _stash.take_item(str(key), inst.count)
		if taken == null:
			continue
		if not bag.add_item(taken):
			_stash.add_item(taken)
			break
	update_stash_display()
	_queue_save()


func _on_stash_toggled(is_opening: bool) -> void:
	if is_opening:
		visible = true
		get_tree().paused = true
		update_stash_display()
	else:
		_hide_ui()


func _on_stash_closed() -> void:
	_hide_ui()


func _hide_ui() -> void:
	_hide_detail_modal()
	visible = false
	if get_tree().paused:
		get_tree().paused = false


func _send_to_stash(key: String) -> void:
	var bag := _bag()
	if bag == null or _stash == null:
		return
	var inst: ItemInstance = bag.current_items.get(key)
	if inst == null or inst.is_equipped:
		return
	var taken: ItemInstance = bag.take_item(key, inst.count)
	if taken == null:
		return
	if not _stash.add_item(taken):
		bag.add_item(taken)
	update_stash_display()
	_queue_save()


func _make_bag_slot(key: String) -> PanelContainer:
	var bag := _bag()
	var inst: ItemInstance = bag.current_items[key]
	var def := inst.definition()
	var slot := _panel()
	var btn := Button.new()
	btn.flat = true
	var title := def.item_name if def else inst.item_id
	if inst.count > 1:
		title = "%s x%d" % [title, inst.count]
	btn.text = title
	btn.pressed.connect(func() -> void: _show_item_detail(inst.item_id, "inventory"))
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_send_to_stash(key)
	)
	slot.add_child(btn)
	return slot


func _take_from_stash(key: String) -> void:
	var bag := _bag()
	if _stash == null or bag == null:
		return
	var taken: ItemInstance = _stash.take_item(key, 1)
	if taken == null:
		return
	if not bag.add_item(taken):
		_stash.add_item(taken)
	update_stash_display()
	_queue_save()


func _queue_save() -> void:
	var save := _save()
	if save != null:
		save.queue_save()


func _make_item_slot(key: String) -> PanelContainer:
	var inst: ItemInstance = _stash.current_items[key]
	var def := inst.definition()
	var slot := _panel()
	var btn := Button.new()
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := def.item_name if def else inst.item_id
	if inst.count > 1:
		title = "%s x%d" % [title, inst.count]
	btn.text = title
	btn.clip_text = true
	btn.pressed.connect(func() -> void: _show_item_detail(inst.item_id, "stash"))
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_take_from_stash(key)
	)
	slot.add_child(btn)
	return slot


func _show_item_detail(item_id: String, context: String = "stash") -> void:
	if item_id.is_empty():
		return
	if _modal == null or not is_instance_valid(_modal):
		var packed := load("res://scenes/ui/item_detail_modal.tscn") as PackedScene
		if packed == null:
			push_error("StashUI: missing item_detail_modal.tscn")
			return
		_modal = packed.instantiate() as Control
		_root.add_child(_modal)
	if _modal.has_method("open_item"):
		_modal.call("open_item", item_id, context)
	elif _modal.has_method("load_item_data"):
		_modal.call("load_item_data", item_id)


func _hide_detail_modal() -> void:
	if _modal != null and is_instance_valid(_modal) and _modal.visible and _modal.has_method("close"):
		_modal.call("close")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _modal != null and _modal.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		on_close_button_pressed()
		get_viewport().set_input_as_handled()


func _empty_slot() -> PanelContainer:
	var slot := _panel()
	var lbl := Label.new()
	lbl.text = ""
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_child(lbl)
	return slot


func _panel() -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 1.0)
	style.border_color = Color(0.30, 0.30, 0.42, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", style)
	slot.custom_minimum_size = Vector2(0, 36)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slot


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)
	center.add_child(panel)

	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 12)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

	var title := Label.new()
	title.text = "Stash"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(_grid)

	_summary = Label.new()
	vbox.add_child(_summary)

	var bag_title := Label.new()
	bag_title.text = "Your bag (left-click: details, right-click: store)"
	vbox.add_child(bag_title)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 5
	_bag_grid.add_theme_constant_override("h_separation", 3)
	_bag_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(_bag_grid)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var to_stash := Button.new()
	to_stash.text = "Move All to Stash"
	to_stash.pressed.connect(on_move_all_to_stash_pressed)
	row.add_child(to_stash)

	var to_inv := Button.new()
	to_inv.text = "Move All to Inventory"
	to_inv.pressed.connect(on_move_all_to_inventory_pressed)
	row.add_child(to_inv)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(on_close_button_pressed)
	vbox.add_child(close)
