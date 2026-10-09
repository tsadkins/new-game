extends CanvasLayer
## Gear screen (C): bag, equipment, stash, and item database.
## F6 this scene to browse without running the arena.

signal item_selected(item_id: String)

const DB_PATH := "/root/ItemDatabase"
const BAG_PATH := "/root/PlayerInventory"

@export var columns: int = 3
@export var item_database_node: Node = null
@export var player_inventory_node: Node = null

var _tabs: TabContainer
var _catalog_grid: GridContainer
var _stash_grid: GridContainer
var _equip_grid: GridContainer
var _inventory_grid: GridContainer
var _status: Label
var _ui_root: Control
var _modal: Control
var _selected_id: String = ""


func _db() -> Node:
	if item_database_node == null or not is_instance_valid(item_database_node):
		item_database_node = get_node_or_null(DB_PATH)
	return item_database_node


func _bag() -> Node:
	if player_inventory_node == null or not is_instance_valid(player_inventory_node):
		player_inventory_node = get_node_or_null(BAG_PATH)
	return player_inventory_node


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("item_viewer")
	_build()
	_connect_live_updates()
	visible = get_tree().current_scene == self
	call_deferred("refresh_all")


func _connect_live_updates() -> void:
	var bag := _bag()
	if bag != null and bag.has_signal("inventory_changed"):
		if not bag.inventory_changed.is_connected(_on_bag_changed):
			bag.inventory_changed.connect(_on_bag_changed, CONNECT_DEFERRED)
	var stash := _stash()
	if stash != null and stash.has_signal("stash_changed"):
		if not stash.stash_changed.is_connected(_on_stash_changed):
			stash.stash_changed.connect(_on_stash_changed, CONNECT_DEFERRED)


func _on_bag_changed() -> void:
	if not visible:
		return
	_fill_inventory()
	_fill_equipment()
	_update_status()


func _on_stash_changed() -> void:
	if not visible:
		return
	_fill_stash()
	_update_status()


func refresh_all() -> void:
	_fill_catalog()
	_fill_inventory()
	_fill_stash()
	_fill_equipment()
	_update_status()
	if _modal != null and _modal.visible and _modal.has_method("refresh_from_database"):
		_modal.call("refresh_from_database")


func load_all_items() -> Array:
	var db := _db()
	if db == null or not db.has_method("get_all_items"):
		return []
	return db.get_all_items()


func _stash() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("stash")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _modal != null and _modal.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_set_open(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U:
			_use_selected()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
			_equip_selected()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	_set_open(not visible)


func _set_open(open: bool) -> void:
	visible = open
	if open:
		refresh_all()
		if get_tree().current_scene != self:
			get_tree().paused = true
	else:
		if _modal != null and _modal.visible and _modal.has_method("close"):
			_modal.call("close")
		if get_tree().paused:
			get_tree().paused = false


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
		for key in bag.current_items.keys():
			var found: ItemInstance = bag.current_items[key]
			if found != null and found.item_id == _selected_id:
				inst = found
				break
	if inst == null:
		return
	var def := inst.definition()
	if def == null or not def.is_equippable():
		return
	bag.equip_item(def.get_equip_slot(), inst.storage_key())


func _fill_inventory() -> void:
	_clear(_inventory_grid)
	var bag := _bag()
	if bag == null:
		_inventory_grid.add_child(_hint_label("PlayerInventory autoload not found."))
		return
	var keys: Array = bag.current_items.keys()
	keys.sort()
	if keys.is_empty():
		_inventory_grid.add_child(_hint_label("Bag is empty. Stash starter gear lives in the chest (E)."))
		return
	for key in keys:
		var inst: ItemInstance = bag.current_items[key]
		if inst == null:
			continue
		var cap := "Equipped" if inst.is_equipped else ""
		_inventory_grid.add_child(_make_instance_card(inst, cap, "inventory"))


func _fill_catalog() -> void:
	_clear(_catalog_grid)
	var items: Array = load_all_items()
	items.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool:
		return a.item_name < b.item_name
	)
	for def in items:
		if def is ItemDefinition:
			_catalog_grid.add_child(_make_definition_card(def))


func _fill_stash() -> void:
	_clear(_stash_grid)
	var stash := _stash()
	if stash == null:
		_stash_grid.add_child(_hint_label("No stash chest in this scene."))
		return
	var keys: Array = stash.current_items.keys()
	keys.sort()
	if keys.is_empty():
		_stash_grid.add_child(_hint_label("Stash is empty."))
		return
	for key in keys:
		var inst: ItemInstance = stash.current_items[key]
		if inst != null:
			_stash_grid.add_child(_make_instance_card(inst, "", "stash"))


func _fill_equipment() -> void:
	_clear(_equip_grid)
	var bag := _bag()
	if bag == null:
		_equip_grid.add_child(_hint_label("PlayerInventory autoload not found."))
		return
	var any := false
	for slot in ["main_hand", "off_hand", "head", "chest", "legs", "boots", "ring", "amulet"]:
		var inst: ItemInstance = bag.get_equipped_item(slot)
		if inst == null:
			continue
		any = true
		_equip_grid.add_child(_make_instance_card(inst, slot.replace("_", " ").capitalize(), "equipment"))
	if not any:
		_equip_grid.add_child(_hint_label("Nothing equipped."))


func _update_status() -> void:
	var count := load_all_items().size()
	var bag := _bag()
	var inv_count := 0
	var inv_max := 0
	if bag != null:
		inv_count = bag.slot_count()
		inv_max = bag.max_inventory_size
	_status.text = "%d in database   Inventory: %d/%d   selected: %s   (U use, Q equip)" % [
		count,
		inv_count,
		inv_max,
		_selected_id if not _selected_id.is_empty() else "(none)",
	]


func _make_definition_card(def: ItemDefinition) -> Control:
	return _make_card(
		def.item_id,
		def.item_name,
		def.description,
		def.type,
		def.rarity,
		def.base_damage,
		def.defense,
		def.health_restore,
		def.mana_restore,
		def.weight,
		def.sell_value,
		def.make_icon(),
		"",
		"database"
	)


func _make_instance_card(inst: ItemInstance, slot_caption: String = "", context: String = "inventory") -> Control:
	var def := inst.definition()
	if def == null:
		return _hint_label("Unknown item: %s" % inst.item_id)
	var extra := slot_caption
	if inst.count > 1:
		extra = extra if extra.is_empty() else extra + "  "
		extra += "x%d" % inst.count
	return _make_card(
		inst.item_id,
		def.item_name,
		def.description,
		def.type,
		def.rarity,
		def.base_damage,
		def.defense,
		def.health_restore,
		def.mana_restore,
		def.weight,
		def.sell_value,
		def.make_icon(),
		extra,
		context
	)


func _make_card(
		item_id: String,
		display_name: String,
		description: String,
		type: String,
		rarity: String,
		base_damage: float,
		defense: int,
		health_restore: float,
		mana_restore: float,
		weight: float,
		sell_value: float,
		icon: Texture2D,
		caption: String,
		context: String = "viewer"
	) -> Control:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	style.border_color = Color(0.32, 0.34, 0.42, 1.0)
	if item_id == _selected_id:
		style.border_color = Color(0.95, 0.82, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(240, 168)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_clicked(item_id, context)
	)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(header)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = icon
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon_rect)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(titles)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	titles.add_child(name_lbl)

	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 6)
	titles.add_child(badges)
	badges.add_child(_badge(_type_label(type), _type_color(type)))
	badges.add_child(_badge(rarity.capitalize(), _rarity_color(rarity)))

	if not caption.is_empty():
		var cap := Label.new()
		cap.text = caption
		cap.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		cap.add_theme_font_size_override("font_size", 12)
		body.add_child(cap)

	if not description.is_empty():
		var desc := Label.new()
		desc.text = description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
		body.add_child(desc)

	var stats := Label.new()
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(0.88, 0.88, 0.9))
	stats.text = _stats_line(type, base_damage, defense, health_restore, mana_restore, weight, sell_value)
	body.add_child(stats)
	_ignore_mouse_recursive(body)
	return card


func _on_card_clicked(item_id: String, context: String = "inventory") -> void:
	_selected_id = item_id
	item_selected.emit(item_id)
	_update_status()
	_show_item_detail(item_id, context)


func _show_item_detail(item_id: String, context: String = "inventory") -> void:
	if _modal == null or not is_instance_valid(_modal):
		var packed := load("res://scenes/ui/item_detail_modal.tscn") as PackedScene
		if packed == null:
			push_error("Item Viewer: missing res://scenes/ui/item_detail_modal.tscn")
			return
		_modal = packed.instantiate() as Control
		_ui_root.add_child(_modal)
	if _modal.has_method("open_item"):
		_modal.call("open_item", item_id, context)
	elif _modal.has_method("load_item_data"):
		_modal.call("load_item_data", item_id)


func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)


func _stats_line(
		type: String,
		base_damage: float,
		defense: int,
		health_restore: float,
		mana_restore: float,
		weight: float,
		sell_value: float
	) -> String:
	var parts: PackedStringArray = []
	match type:
		"weapon":
			parts.append("Damage  %.0f" % base_damage)
		"armor":
			parts.append("Defense  %d" % defense)
		"consumable":
			if health_restore > 0.0:
				parts.append("HP +%.0f" % health_restore)
			if mana_restore > 0.0:
				parts.append("MP +%.0f" % mana_restore)
		_:
			pass
	parts.append("Weight  %.1f" % weight)
	parts.append("Sell  %.0f" % sell_value)
	return "   ·   ".join(parts)


func _badge(text: String, color: Color) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1) if color.get_luminance() > 0.55 else Color.WHITE)
	panel.add_child(lbl)
	return panel


func _type_label(type: String) -> String:
	match type:
		"weapon":
			return "Weapon"
		"armor":
			return "Armor"
		"consumable":
			return "Consumable"
		"tool":
			return "Tool"
		"key_item":
			return "Key"
		_:
			return type.capitalize()


func _type_color(type: String) -> Color:
	match type:
		"weapon":
			return Color(0.72, 0.28, 0.22)
		"armor":
			return Color(0.28, 0.42, 0.62)
		"consumable":
			return Color(0.22, 0.52, 0.32)
		_:
			return Color(0.35, 0.35, 0.4)


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.25, 0.45, 0.85)
		"rare":
			return Color(0.55, 0.32, 0.78)
		"legendary":
			return Color(0.85, 0.68, 0.18)
		_:
			return Color(0.45, 0.45, 0.48)


func _hint_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	return lbl


func _clear(grid: GridContainer) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _build() -> void:
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_ui_root)
	var root := _ui_root

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Gear"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)

	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.pressed.connect(refresh_all)
	header.add_child(refresh)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	header.add_child(_status)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)

	_inventory_grid = _make_scroll_tab("Inventory")
	_equip_grid = _make_scroll_tab("Equipment")
	_stash_grid = _make_scroll_tab("Stash")
	_catalog_grid = _make_scroll_tab("Database")


func _make_scroll_tab(tab_name: String) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	return grid
