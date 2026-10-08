extends Camera3D
## Keeps the camera locked on its target (the player) so the target stays at the
## center of the screen, preserving the camera's angle and distance.

## Node to follow. If left empty, the first node in the "player" group is used.
@export var target: Node3D
## 0 = rigidly locked to the target. Higher values add a soft lag (try 8-15).
@export var follow_smoothing: float = 0.0

var _offset: Vector3
var _offset_ready: bool = false
var _warned: bool = false


func _process(delta: float) -> void:
	# Find the target lazily so load order never matters.
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
		if target == null:
			if not _warned:
				push_warning("CameraFollow: no target set and no node in group 'player' found.")
				_warned = true
			return

	# Remember the camera's starting offset from the target and keep it constant.
	# The offset is placed along the camera's view axis, so the target sits exactly
	# at screen center.
	if not _offset_ready:
		var distance := global_position.distance_to(target.global_position)
		_offset = global_basis.z * distance
		_offset_ready = true

	var desired := target.global_position + _offset
	if follow_smoothing > 0.0:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_smoothing * delta))
	else:
		global_position = desired
