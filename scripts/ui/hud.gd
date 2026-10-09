extends CanvasLayer
## Shows the player's level and an experience bar in the top-left corner.
## Also manages the level-up attribute selection popup and the [C] gear/character screen.

const MANNEQUIN_SCENE_PATH := "res://assets/animations/player_animations/AnimationLibrary_Godot_Standard.glb"

## The player to display. If empty, the first node in the "player" group is used.
@export var player: Player

var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _stats_label: Label

## Level-up popup
var _levelup_panel: PanelContainer
var _levelup_title: Label
var _pending_levels: int = 0

## Gear / character screen
var _gear_panel: Control  # HBoxContainer wrapper that holds both sub-panels
var _gear_open: bool = false
var _inventory_grid: GridContainer
var _gear_item_labels: Dictionary = {}
var _detail_modal: Control


func _ready() -> void:
	layer = 5
	# Keep processing (input + _process) even when the game tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_levelup_popup()
	_build_gear_menu()
	PlayerInventory.inventory_changed.connect(_refresh_gear_inventory, CONNECT_DEFERRED)
	_refresh_gear_inventory()

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("HUD: no Player found.")
		return

	player.experience_changed.connect(_on_experience_changed)
	player.leveled_up.connect(_on_leveled_up)
	# The player's _ready already ran, so show its current state right away.
	_on_experience_changed(player.level, player.experience, player.xp_required(player.level))


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE # never block clicks on the game
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 28)
	_level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_level_label.add_theme_constant_override("outline_size", 6)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(220, 18)
	_xp_bar.show_percentage = false
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.8, 0.25)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_xp_bar)

	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 14)
	_xp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_xp_label.add_theme_constant_override("outline_size", 4)
	_xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_xp_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_stats_label.add_theme_constant_override("outline_size", 5)
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_stats_label)


# Stats change with buffs, attributes and health, so just refresh the text every frame.
func _process(_delta: float) -> void:
	if player == null:
		return
	var s := player.get_stats()
	_stats_label.text = "\n".join([
		"Health: %d / %d" % [s.health, s.max_health],
		"Mana: %d / %d" % [round(s.mana), round(s.max_mana)],
		"Defense: %d  (-%d%% damage)" % [round(s.defense), round(s.damage_reduction * 100.0)],
		"Move speed: %.1f" % s.move_speed,
		"Attack speed: %.2f/s" % s.attack_speed,
		"Damage: %d" % s.damage,
		"",
		"STR %d   DEX %d   INT %d" % [s.strength, s.dexterity, s.intelligence],
		"I Gear   C Database   E Stash",
	])


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			if _pending_levels > 0:
				get_viewport().set_input_as_handled()
				return
			_toggle_gear_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:
			# ItemViewer owns C (database/stash/equipment tabs).
			if _pending_levels > 0:
				get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_ESCAPE and _gear_open:
			if _detail_modal != null and _detail_modal.visible:
				return
			_toggle_gear_menu()
			get_viewport().set_input_as_handled()


func _on_experience_changed(level: int, experience: int, required: int) -> void:
	_level_label.text = "Level %d" % level
	if required <= 0:
		# Max level reached: show a full bar.
		_xp_bar.max_value = 1
		_xp_bar.value = 1
		_xp_label.text = "MAX LEVEL"
	else:
		_xp_bar.max_value = required
		_xp_bar.value = experience
		_xp_label.text = "XP %d / %d" % [experience, required]


# ---------------------------------------------------------------------------
# Level-up popup
# ---------------------------------------------------------------------------

func _build_levelup_popup() -> void:
	# Dim overlay behind the panel.
	var overlay := ColorRect.new()
	overlay.name = "LevelUpOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Must keep processing while the game tree is paused.
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	add_child(overlay)

	_levelup_panel = PanelContainer.new()
	_levelup_panel.name = "LevelUpPanel"
	# Centre the panel on screen.
	_levelup_panel.set_anchors_preset(Control.PRESET_CENTER)
	_levelup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_levelup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_levelup_panel.custom_minimum_size = Vector2(380, 0)
	_levelup_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_levelup_panel.visible = false
	add_child(_levelup_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	# Inner padding
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 30)
	pad.add_theme_constant_override("margin_right", 30)
	pad.add_theme_constant_override("margin_top", 26)
	pad.add_theme_constant_override("margin_bottom", 26)
	_levelup_panel.add_child(pad)
	pad.add_child(vbox)

	_levelup_title = Label.new()
	_levelup_title.text = "LEVEL UP!"
	_levelup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_levelup_title.add_theme_font_size_override("font_size", 36)
	_levelup_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_levelup_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_levelup_title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(_levelup_title)

	var subtitle := Label.new()
	subtitle.text = "Choose an attribute to increase"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle.add_theme_constant_override("outline_size", 4)
	vbox.add_child(subtitle)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Attribute buttons: [attribute_key, display name, description]
	var attributes := [
		["strength",     "⚔  Strength",     "+5 Max HP  ·  +1 Attack Damage"],
		["dexterity",    "🏃  Dexterity",    "+Move Speed  ·  +Attack Speed"],
		["intelligence", "✨  Intelligence", "+1 Defense"],
	]
	for entry in attributes:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 68)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 20)
		btn.text = "%s\n%s" % [entry[1], entry[2]]
		btn.process_mode = Node.PROCESS_MODE_ALWAYS

		# Capture the attribute key in a local variable for the closure.
		var key: String = entry[0]
		btn.pressed.connect(func() -> void: _pick_attribute(key))

		vbox.add_child(btn)

	# Store a reference to the overlay so we can toggle it together with the panel.
	_levelup_panel.set_meta("overlay", overlay)


func _on_leveled_up(new_level: int) -> void:
	_pending_levels += 1
	if _pending_levels == 1:
		_show_levelup_popup(new_level)


func _show_levelup_popup(new_level: int) -> void:
	_levelup_title.text = "LEVEL %d!" % new_level
	_levelup_panel.visible = true
	var overlay: ColorRect = _levelup_panel.get_meta("overlay")
	overlay.visible = true
	get_tree().paused = true


func _pick_attribute(attribute: String) -> void:
	if player != null:
		player.add_attribute(attribute, 1)
	_pending_levels -= 1
	if _pending_levels > 0:
		# Another level was banked while the popup was open — show it immediately.
		_show_levelup_popup(player.level if player != null else 0)
	else:
		_levelup_panel.visible = false
		var overlay: ColorRect = _levelup_panel.get_meta("overlay")
		overlay.visible = false
		get_tree().paused = false


# ---------------------------------------------------------------------------
# Gear / character screen
# ---------------------------------------------------------------------------

## Slot definitions: [display label, emoji icon, ItemDefinition.equip_slot id]
const GEAR_SLOTS: Array = [
	["Helmet",     "⛑", "head"],
	["Body Armor", "🦺", "chest"],
	["Gloves",     "🧤", ""],
	["Boots",      "👢", "boots"],
	["Weapon",     "⚔", "main_hand"],
	["Amulet",     "📿", "amulet"],
	["Ring 1",     "💍", "ring"],
	["Ring 2",     "💍", ""],
	["Belt",       "🔗", ""],
	["Off-Hand",   "🛡", "off_hand"],
]

func _build_gear_menu() -> void:
	# Root: VBoxContainer — top row (gear + preview), bottom row (inventory).
	var wrapper := VBoxContainer.new()
	wrapper.name = "GearMenuWrapper"
	wrapper.set_anchors_preset(Control.PRESET_CENTER)
	wrapper.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wrapper.grow_vertical   = Control.GROW_DIRECTION_BOTH
	wrapper.add_theme_constant_override("separation", 12)
	wrapper.process_mode = Node.PROCESS_MODE_ALWAYS
	wrapper.visible = false
	add_child(wrapper)
	_gear_panel = wrapper

	# Top row: gear slots on the left, preview (with overlaid ✕) on the right.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	wrapper.add_child(top_row)
	top_row.add_child(_build_character_panel())
	top_row.add_child(_build_preview_panel())

	# Full-width inventory below both panels.
	wrapper.add_child(_build_inventory_panel())


## Builds the left "CHARACTER" panel containing the 10 gear slots.
func _build_character_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CharacterPanel"
	panel.custom_minimum_size = Vector2(500, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left",   12)
	pad.add_theme_constant_override("margin_right",  12)
	pad.add_theme_constant_override("margin_top",    10)
	pad.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(pad)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	pad.add_child(root_vbox)

	# --- Two-column slot grid ---
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	root_vbox.add_child(columns)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)

	columns.add_child(VSeparator.new())

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)

	for i in GEAR_SLOTS.size():
		var slot_data: Array = GEAR_SLOTS[i]
		var slot := _make_gear_slot(str(slot_data[0]), str(slot_data[1]), str(slot_data[2]))
		if i < 5:
			left_col.add_child(slot)
		else:
			right_col.add_child(slot)

	return panel


## Builds one gear-slot widget: a dark panel with an icon and slot-name label.
func _make_gear_slot(slot_name: String, icon: String, equip_id: String) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 1.0)
	style.border_color = Color(0.35, 0.35, 0.45, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 6
	style.content_margin_bottom = 6

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 56)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var slot_id := equip_id
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_gear_slot_clicked(slot_id)
	)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_lbl)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = slot_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var empty_lbl := Label.new()
	empty_lbl.text = "Empty"
	empty_lbl.add_theme_font_size_override("font_size", 13)
	empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(empty_lbl)
	if not equip_id.is_empty():
		_gear_item_labels[equip_id] = empty_lbl

	return panel


## Builds the "INVENTORY" panel that sits below the gear slots: 5-column item grid.
func _build_inventory_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "InventoryPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left",   10)
	pad.add_theme_constant_override("margin_right",  10)
	pad.add_theme_constant_override("margin_top",    10)
	pad.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(pad)

	# 10-column × 2-row grid = 20 slots. Each slot has SIZE_EXPAND_FILL so the
	# grid stretches to fill exactly the panel width with no overflow or gap.
	var grid := GridContainer.new()
	grid.name = "InventoryGrid"
	grid.columns = 10
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	pad.add_child(grid)
	_inventory_grid = grid
	_refresh_gear_inventory()

	return panel


## Builds one square inventory slot: a dark bordered box showing "Empty".
func _make_inventory_slot() -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 1.0)
	style.border_color = Color(0.30, 0.30, 0.42, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)

	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", style)
	slot.custom_minimum_size = Vector2(0, 56)   # height fixed, width flexible
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = "Empty"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(lbl)

	return slot


## Builds the character preview panel: a live 3D SubViewport showing the player model.
## Returns a Control so the ✕ button can be overlaid without affecting layout width.
func _build_preview_panel() -> Control:
	var root := Control.new()
	root.name = "PreviewRoot"
	root.custom_minimum_size = Vector2(220, 0)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# PanelContainer fills the Control entirely.
	var panel := PanelContainer.new()
	panel.name = "PreviewPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	# Close button overlaid at the top-right corner — not in the layout flow.
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	close_btn.grow_vertical   = Control.GROW_DIRECTION_END
	close_btn.offset_right = -4
	close_btn.offset_top   = 4
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_toggle_gear_menu)
	root.add_child(close_btn)

	# SubViewportContainer — fills the PanelContainer entirely.
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vpc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vpc)

	# SubViewport — render resolution; stretch scales it to the container size.
	var vp := SubViewport.new()
	vp.size = Vector2i(220, 400)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)

	# Dark background matching the panel style.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.11, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.75, 0.75, 0.85)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)

	# Key light — front and slightly above.
	var key_light := DirectionalLight3D.new()
	key_light.transform = Transform3D.IDENTITY.looking_at(Vector3(-0.3, -1.0, -0.6), Vector3.UP)
	key_light.light_energy = 1.2
	vp.add_child(key_light)

	# Fill light — soft from the opposite side.
	var fill_light := DirectionalLight3D.new()
	fill_light.transform = Transform3D.IDENTITY.looking_at(Vector3(0.6, -0.5, 0.4), Vector3.UP)
	fill_light.light_energy = 0.4
	vp.add_child(fill_light)

	# Camera — orthographic, framed on a standing humanoid (~1.8m).
	# Node.look_at() needs the tree; Basis.looking_at() does not.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.2
	var cam_pos := Vector3(0.0, 0.9, 3.0)
	var look_target := Vector3(0.0, 0.9, 0.0)
	cam.transform = Transform3D(Basis.looking_at(look_target - cam_pos, Vector3.UP), cam_pos)
	vp.add_child(cam)

	var preview := load(MANNEQUIN_SCENE_PATH) as PackedScene
	if preview != null:
		var mannequin := preview.instantiate() as Node3D
		vp.add_child(mannequin)
		var preview_anim := mannequin.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if preview_anim != null:
			if preview_anim.has_animation("Idle_Loop"):
				preview_anim.play("Idle_Loop")
			else:
				for lib in preview_anim.get_animation_library_list():
					var path := "%s/Idle_Loop" % lib
					if preview_anim.has_animation(path):
						preview_anim.play(path)
						break
	else:
		var mesh_inst := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.5
		capsule.height = 2.0
		mesh_inst.mesh = capsule
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.3, 0.2)
		mesh_inst.material_override = mat
		vp.add_child(mesh_inst)

	return root


func _toggle_gear_menu() -> void:
	_gear_open = not _gear_open
	_gear_panel.visible = _gear_open
	# Pause while open; unpause on close (unless a level-up choice is still pending).
	if _gear_open:
		get_tree().paused = true
		_refresh_gear_inventory()
	else:
		_hide_detail_modal()
		if _pending_levels == 0:
			get_tree().paused = false


func _refresh_gear_inventory() -> void:
	if _inventory_grid == null:
		return
	for child in _inventory_grid.get_children():
		_inventory_grid.remove_child(child)
		child.queue_free()
	var keys: Array = PlayerInventory.current_items.keys()
	keys.sort()
	var slot_total: int = maxi(PlayerInventory.max_inventory_size, 20)
	# Keep the C-menu compact: show items first, then empty slots up to 20 visible cells.
	var visible_slots: int = mini(slot_total, 20)
	if keys.size() > visible_slots:
		visible_slots = mini(keys.size(), 50)
		_inventory_grid.columns = 10
	for i in visible_slots:
		if i < keys.size():
			_inventory_grid.add_child(_make_filled_inventory_slot(str(keys[i])))
		else:
			_inventory_grid.add_child(_make_inventory_slot())
	for equip_id in _gear_item_labels.keys():
		var lbl := _gear_item_labels[equip_id] as Label
		var inst := PlayerInventory.get_equipped_item(str(equip_id))
		if inst == null:
			lbl.text = "Empty"
			lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		else:
			var def := inst.definition()
			lbl.text = def.item_name if def else inst.item_id
			lbl.add_theme_color_override("font_color", def.rarity_color() if def else Color.WHITE)


func _make_filled_inventory_slot(key: String) -> PanelContainer:
	var inst := PlayerInventory.current_items.get(key) as ItemInstance
	if inst == null:
		return _make_inventory_slot()
	var def := inst.definition()
	var slot := _make_inventory_slot()
	var lbl := slot.get_child(0) as Label
	var title := def.item_name if def else inst.item_id
	if inst.count > 1:
		title = "%s\nx%d" % [title, inst.count]
	if inst.is_equipped:
		title = "[E] " + title
	lbl.text = title
	lbl.add_theme_color_override("font_color", def.rarity_color() if def else Color(0.9, 0.9, 0.92))
	lbl.add_theme_font_size_override("font_size", 10)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var item_id := inst.item_id
	slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_item_detail(item_id, "inventory")
	)
	return slot


func _on_gear_slot_clicked(equip_id: String) -> void:
	if equip_id.is_empty():
		return
	var inst := PlayerInventory.get_equipped_item(equip_id)
	if inst == null:
		return
	_show_item_detail(inst.item_id, "equipment")


func _show_item_detail(item_id: String, context: String = "inventory") -> void:
	if item_id.is_empty():
		return
	if _detail_modal == null or not is_instance_valid(_detail_modal):
		var packed := load("res://scenes/ui/item_detail_modal.tscn") as PackedScene
		if packed == null:
			push_error("HUD: missing item_detail_modal.tscn")
			return
		_detail_modal = packed.instantiate() as Control
		add_child(_detail_modal)
	if _detail_modal.has_method("open_item"):
		_detail_modal.call("open_item", item_id, context)
	elif _detail_modal.has_method("load_item_data"):
		_detail_modal.call("load_item_data", item_id)


func _hide_detail_modal() -> void:
	if _detail_modal != null and is_instance_valid(_detail_modal) and _detail_modal.visible:
		if _detail_modal.has_method("close"):
			_detail_modal.call("close")
