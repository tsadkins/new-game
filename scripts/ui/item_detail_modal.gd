extends Control
## Overlay that shows one ItemDefinition. Hidden when closed so it does not eat clicks.
## No class_name — the viewer loads this via the .tscn so parse order cannot break.

signal modal_closed()

const DB_PATH := "/root/ItemDatabase"

var _backdrop: ColorRect
var _panel: PanelContainer
var _icon: TextureRect
var _name_lbl: Label
var _badges: HBoxContainer
var _stats: VBoxContainer
var _desc: Label
var _item_id: String = ""
var _item_context: String = "inventory"
var _back_btn: Button
var _closing: bool = false
var _tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func load_item_data(item_id: String) -> void:
	open_item(item_id)


func open_item(item_id: String, context: String = "inventory") -> void:
	_item_id = item_id
	_item_context = context
	refresh_from_database()
	_closing = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	await _tween.finished
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_closing = false
	modal_closed.emit()


func refresh_from_database() -> void:
	if _item_id.is_empty():
		return
	var def := _load_item(_item_id)
	if def == null:
		_name_lbl.text = "Unknown item"
		_desc.text = "ItemDatabase has no entry for '%s'." % _item_id
		_clear_box(_badges)
		_clear_box(_stats)
		_icon.texture = _placeholder_tex(Color(0.35, 0.35, 0.4))
		return
	_apply_definition(def)


func _load_item(item_id: String) -> ItemDefinition:
	var db := get_node_or_null(DB_PATH)
	if db == null or not db.has_method("get_item_by_id"):
		return null
	return db.get_item_by_id(item_id) as ItemDefinition


func _apply_definition(def: ItemDefinition) -> void:
	_icon.texture = def.make_icon()
	_name_lbl.text = def.item_name
	_desc.text = def.description if not def.description.is_empty() else "No description."
	_clear_box(_badges)
	_badges.add_child(_badge(_type_label(def.type), _type_color(def.type)))
	_badges.add_child(_badge(def.rarity.capitalize(), _rarity_color(def.rarity)))
	if not _item_context.is_empty() and _item_context != "viewer":
		_badges.add_child(_badge("[ %s ]" % _item_context.capitalize(), Color(0.38, 0.40, 0.46)))
	if _back_btn != null:
		_back_btn.text = "Back to Viewer" if _item_context == "viewer" else "Close"
	_clear_box(_stats)
	for line in _stat_lines(def):
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.9))
		_stats.add_child(lbl)


func _stat_lines(def: ItemDefinition) -> PackedStringArray:
	var lines: PackedStringArray = []
	match def.type:
		"weapon":
			lines.append("Base Damage    %.0f" % def.base_damage)
			lines.append("Weight    %.1f" % def.weight)
			lines.append("Equip Slot    %s" % _slot_label(def.get_equip_slot()))
			if def.attack_speed_bonus != 0.0:
				lines.append("Attack Speed    %+.2f" % def.attack_speed_bonus)
			lines.append("Sell Value    %.0f" % def.sell_value)
		"armor":
			lines.append("Defense    %d" % def.defense)
			lines.append("Weight    %.1f" % def.weight)
			lines.append("Equip Slot    %s" % _slot_label(def.get_equip_slot()))
			lines.append("Sell Value    %.0f" % def.sell_value)
		"consumable":
			if def.health_restore > 0.0:
				lines.append("Health Restore    %.0f" % def.health_restore)
			if def.mana_restore > 0.0:
				lines.append("Mana Restore    %.0f" % def.mana_restore)
			if def.health_restore <= 0.0 and def.mana_restore <= 0.0:
				lines.append("No restore values")
			lines.append("Stack Size    %d" % def.stack_size)
			lines.append("Sell Value    %.0f" % def.sell_value)
			lines.append("Weight    %.1f" % def.weight)
		_:
			lines.append("Weight    %.1f" % def.weight)
			lines.append("Sell Value    %.0f" % def.sell_value)
	return lines


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.14, 0.98)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.38, 0.40, 0.48)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(36, 32)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(96, 96)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture = _placeholder_tex(Color(0.35, 0.35, 0.4))
	vbox.add_child(_icon)

	_name_lbl = Label.new()
	_name_lbl.text = "Item"
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.add_theme_font_size_override("font_size", 28)
	_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_name_lbl)

	_badges = HBoxContainer.new()
	_badges.alignment = BoxContainer.ALIGNMENT_CENTER
	_badges.add_theme_constant_override("separation", 8)
	vbox.add_child(_badges)

	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats)

	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 14)
	_desc.add_theme_color_override("font_color", Color(0.68, 0.70, 0.74))
	vbox.add_child(_desc)

	_back_btn = Button.new()
	_back_btn.text = "Close"
	_back_btn.pressed.connect(close)
	vbox.add_child(_back_btn)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _badge(text: String, color: Color) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
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


func _slot_label(slot: String) -> String:
	if slot.is_empty():
		return "—"
	return slot.replace("_", " ").capitalize()


func _placeholder_tex(color: Color) -> Texture2D:
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _clear_box(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.free()
