extends Area3D
## Detects the player near a stash chest. Press E to open/close.

signal interaction_requested(is_opening: bool)

@export var stash_container: StashContainer
@export var interaction_radius: float = 2.4
@export var interact_cooldown: float = 0.25

var last_interaction_time: float = -999.0
var _player_in_range: bool = false
var _hint: Label3D


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_radius
	shape.shape = sphere
	add_child(shape)

	_hint = Label3D.new()
	_hint.text = "E — Open stash"
	_hint.font_size = 28
	_hint.position = Vector3(0.0, 1.55, 0.0)
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.visible = false
	add_child(_hint)

	if stash_container == null:
		stash_container = get_parent() as StashContainer


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		attempt_interact()


func attempt_interact() -> void:
	if not _player_in_range or stash_container == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_interaction_time < interact_cooldown:
		return
	last_interaction_time = now
	var opening := not stash_container.is_open
	stash_container.toggle_open()
	emit_interaction_signal(opening)


func emit_interaction_signal(is_opening: bool) -> void:
	interaction_requested.emit(is_opening)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_dead:
		_player_in_range = true
		_hint.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		_player_in_range = false
		_hint.visible = false
		if stash_container != null and stash_container.is_open:
			stash_container.force_close()
