extends CanvasLayer
## Player bag + equipment. Toggle with I. Does not include the world stash.
## Bag singleton is the autoload at /root/PlayerInventory (not a class_name).

const BAG_PATH := "/root/PlayerInventory"

@export var columns: int = 10
@export var player_inventory_node: Node = null

var _grid: GridContainer
var _equip_labels: Dictionary = {}
var _status: Label
var _selected_id: String = ""
var _root: Control

const EQUIP_SLOTS: Array[String] = [
	"main_hand", "off_hand", "head", "chest", "legs", "boots", "ring", "amulet"
]


func _bag() -> Node:
	if player_inventory_node == null or not is_instance_valid(player_inventory_node):
		player_inventory_node = get_node_or_null(BAG_PATH)
	return player_inventory_node


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	_connect_bag_signals()
	_debug_print()


func _connect_bag_signals() -> void:
	var bag := _bag()
	if bag == null:
		push_warning("InventoryUI: /root/PlayerInventory not found.")
		return
	if not bag.inventory_changed.is_connected(update_inventory):
		bag.inventory_changed.connect(update_inventory)
	if not bag.inventory_full.is_connected(_on_full):
		bag.inventory_full.connect(_on_full)


func _debug_print() -> void:
	var bag := _bag()
	if bag != null:
		print("Inventory UI connected to: ", bag.name)
	else:
		print("WARNING: Could not find PlayerInventory autoload at ", BAG_PATH)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		visible = not visible
		get_tree().paused = visible
		if visible:
			update_inventory()
		get_viewport().set_input_as_handled()


func update_inventory() -> void:
	var bag := _bag()
	if bag == null:
		return
	_refresh_grid()
	refresh_equipment_panel()
	_status.text = "Inventory %d / %d slots  (click: select, U: use, Q: equip)" % [
		bag.slot_count(), bag.max_inventory_size
	]


func on_item_selected(item_instance: ItemInstance) -> void:
	if item_instance == null:
		_selected_id = ""
		return
	_selected_id = item_instance.storage_key()
	_refresh_grid()


func refresh_equipment_panel() -> void:
	var bag := _bag()
	if bag == null:
		return
	for slot in EQUIP_SLOTS:
		var inst: ItemInstance = bag.get_equipped_item(slot)
		var label := _equip_labels.get(slot) as Label
		if label == null:
			continue
		if inst == null:
			label.text = "%s: Empty" % slot.replace("_", " ").capitalize()
			label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		else:
			var def := inst.definition()
			label.text = "%s: %s" % [slot.replace("_", " ").capitalize(), def.item_name if def else inst.item_id]
			label.add_theme_color_override("font_color", def.rarity_color() if def else Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U:
			_use_selected()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
			_equip_selected()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			visible = false
			get_tree().paused = false
			get_viewport().set_input_as_handled()


func _use_selected() -> void:
	if _selected_id.is_empty():
		return
	var bag := _bag()
	if bag != null:
		bag.use_item(_selected_id)


func _equip_selected() -> void:
	if _selected_id.is_empty():
		return
	var bag := _bag()
	if bag == null:
		return
	var inst: ItemInstance = bag.current_items.get(_selected_id)
	if inst == null:
		return
	var def := inst.definition()
	if def == null or not def.is_equippable():
		return
	bag.equip_item(def.get_equip_slot(), _selected_id)


func _on_full() -> void:
	_status.text = "Inventory full — store items in the stash chest"


func _refresh_grid() -> void:
	if _grid == null:
		return
	var bag := _bag()
	if bag == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.free()
	var keys: Array = bag.current_items.keys()
	keys.sort()
	for i in bag.max_inventory_size:
		if i < keys.size():
			_grid.add_child(_make_item_slot(str(keys[i])))
		else:
			_grid.add_child(_make_empty_slot())


func _make_item_slot(key: String) -> PanelContainer:
	var bag := _bag()
	var inst: ItemInstance = bag.current_items[key]
	var def := inst.definition()
	var slot := _slot_panel(key == _selected_id)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	slot.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if def != null:
		icon.texture = def.make_icon()
	vbox.add_child(icon)

	var btn := Button.new()
	btn.flat = true
	var title := def.item_name if def else inst.item_id
	if inst.is_equipped:
		title = "[E] " + title
	btn.text = title
	btn.clip_text = true
	btn.pressed.connect(func() -> void: on_item_selected(inst))
	vbox.add_child(btn)

	if inst.count > 1:
		var count_lbl := Label.new()
		count_lbl.text = "x%d" % inst.count
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(count_lbl)
	return slot


func _make_empty_slot() -> PanelContainer:
	var slot := _slot_panel(false)
	var lbl := Label.new()
	lbl.text = "Empty"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(lbl)
	return slot


func _slot_panel(selected: bool) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 1.0)
	style.border_color = Color(0.85, 0.75, 0.30) if selected else Color(0.30, 0.30, 0.42, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", style)
	slot.custom_minimum_size = Vector2(64, 72)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slot


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 520)
	center.add_child(panel)

	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 12)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pad.add_child(vbox)

	_status = Label.new()
	vbox.add_child(_status)

	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_grid)

	var equip := VBoxContainer.new()
	equip.add_theme_constant_override("separation", 4)
	vbox.add_child(equip)
	for slot in EQUIP_SLOTS:
		var lbl := Label.new()
		_equip_labels[slot] = lbl
		equip.add_child(lbl)

	var close := Button.new()
	close.text = "Close (I / Esc)"
	close.pressed.connect(func() -> void:
		visible = false
		get_tree().paused = false
	)
	vbox.add_child(close)
