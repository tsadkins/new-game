extends CanvasLayer
## "You died" popup with a Respawn button. The UI is built in code, so this script
## is all that's needed: add a CanvasLayer node with this script to the scene.

## The player to watch. If empty, the first node in the "player" group is used.
@export var player: Player
## Seconds to wait after death before showing the popup.
@export var show_delay: float = 0.8

var _root: Control


func _ready() -> void:
	layer = 10
	_build_ui()
	_root.hide()

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("DeathScreen: no Player found.")
		return
	player.died.connect(_on_player_died)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP # block clicks reaching the game
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)

	var label := Label.new()
	label.text = "You died"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	box.add_child(label)

	var button := Button.new()
	button.text = "Respawn"
	button.custom_minimum_size = Vector2(200, 50)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(_on_respawn_pressed)
	box.add_child(button)

	_respawn_button = button


var _respawn_button: Button


func _on_player_died() -> void:
	# Let the fall-over animation play before the popup covers the screen.
	await get_tree().create_timer(show_delay).timeout
	_root.show()
	_respawn_button.grab_focus()


func _on_respawn_pressed() -> void:
	_root.hide()
	player.respawn()
