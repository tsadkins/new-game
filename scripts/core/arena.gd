extends Node3D
## Builds visible, solid walls around the arena and fades out any wall segment that
## would block the camera's view of the player.

## The walls enclose the square from -arena_half_size to +arena_half_size on X and Z.
@export var arena_half_size: float = 25.0
@export var wall_height: float = 4.0
@export var wall_thickness: float = 1.0
## Walls are built from segments this long, so only the part in the way fades.
@export var segment_length: float = 10.0
@export var wall_color: Color = Color(0.55, 0.5, 0.45, 1.0)
## Optional rock material for the walls. Duplicated per segment so fade still works.
@export var wall_material: Material
## Wall opacity while it is blocking the view (0 = invisible, 1 = solid).
@export_range(0.0, 1.0) var faded_alpha: float = 0.15
## How fast walls fade in/out (alpha per second).
@export var fade_speed: float = 5.0
## Extra margin around each wall used when testing whether it blocks the view.
@export var obstruction_padding: float = 0.75

class WallSegment:
	var mesh: MeshInstance3D
	var material: StandardMaterial3D
	var alpha: float = 1.0
	var outward: Vector3 # horizontal direction the wall faces away from the arena

var _segments: Array[WallSegment] = []


func _ready() -> void:
	add_to_group("arena")

	var h := arena_half_size
	var t := wall_thickness
	var half_t := t * 0.5
	var outer := h + t # side walls along X run a bit longer to close the corners

	# North (-Z) / South (+Z) along X, then West (-X) / East (+X) along Z.
	_build_wall(Vector3(0.0, 0.0, -(h + half_t)), 2.0 * outer, true, Vector3.FORWARD)
	_build_wall(Vector3(0.0, 0.0, h + half_t), 2.0 * outer, true, Vector3.BACK)
	_build_wall(Vector3(-(h + half_t), 0.0, 0.0), 2.0 * h, false, Vector3.LEFT)
	_build_wall(Vector3(h + half_t, 0.0, 0.0), 2.0 * h, false, Vector3.RIGHT)


## Clamps a world position to the walkable area (inside the walls, with a margin for the
## size of a character). Used so clicking/holding the mouse beyond a wall steers the
## player along the wall instead of pushing into it.
func clamp_to_bounds(pos: Vector3, margin: float = 0.6) -> Vector3:
	var limit := arena_half_size - margin
	pos.x = clampf(pos.x, -limit, limit)
	pos.z = clampf(pos.z, -limit, limit)
	return pos


## Builds one side of the arena out of several segments.
## center: middle of the whole side; length: total length; along_x: wall runs along X if true;
## outward: direction the wall faces away from the arena.
func _build_wall(center: Vector3, length: float, along_x: bool, outward: Vector3) -> void:
	var count := maxi(ceili(length / segment_length), 1)
	var seg_len := length / count

	for i in count:
		var offset := -length * 0.5 + seg_len * (i + 0.5)
		var pos := center + (Vector3(offset, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, offset))
		pos.y = wall_height * 0.5
		var size := Vector3(seg_len, wall_height, wall_thickness) if along_x \
			else Vector3(wall_thickness, wall_height, seg_len)
		_build_segment(pos, size, outward)


func _build_segment(pos: Vector3, size: Vector3, outward: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	var material: StandardMaterial3D
	if wall_material is StandardMaterial3D:
		material = (wall_material as StandardMaterial3D).duplicate()
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = wall_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material

	var mesh := MeshInstance3D.new()
	mesh.mesh = box_mesh
	body.add_child(mesh)

	var segment := WallSegment.new()
	segment.mesh = mesh
	segment.material = material
	segment.outward = outward
	_segments.append(segment)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D

	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var toward_camera := Vector3.ZERO # horizontal direction from the player toward the camera
	var can_test := camera != null and player != null
	if can_test:
		from = camera.global_position
		to = player.global_position
		toward_camera = Vector3(from.x - to.x, 0.0, from.z - to.z).normalized()

	for segment in _segments:
		var target_alpha := 1.0
		if can_test and _faces_camera(segment, toward_camera) and _blocks_view(segment, from, to):
			target_alpha = faded_alpha

		if not is_equal_approx(segment.alpha, target_alpha):
			segment.alpha = move_toward(segment.alpha, target_alpha, fade_speed * delta)
			var color := segment.material.albedo_color
			color.a = segment.alpha
			segment.material.albedo_color = color


## Only the near walls (whose outer face points toward the camera) may ever fade.
## The far walls (north/west with the current camera) always stay solid.
func _faces_camera(segment: WallSegment, toward_camera: Vector3) -> bool:
	return segment.outward.dot(toward_camera) > 0.1


## True if the line from the camera to the player passes through (or very near) the segment.
func _blocks_view(segment: WallSegment, from: Vector3, to: Vector3) -> bool:
	var box := segment.mesh.global_transform * segment.mesh.get_aabb()
	box = box.grow(obstruction_padding)
	return box.intersects_segment(from, to) != null
