extends Node3D
## Scatters rocks and crystals from the Terrain3D pack around the existing arena.
## Props sit on the flat floor so click-to-move and combat stay unchanged.

@export var rock_a_scene: PackedScene
@export var rock_b_scene: PackedScene
@export var rock_c_scene: PackedScene
@export var crystal_scene: PackedScene

func _ready() -> void:
	_place(rock_c_scene, Vector3( 22.0, 0.0,  22.0), Vector3(0.22, 0.22, 0.22), 0.4)
	_place(rock_c_scene, Vector3(-22.0, 0.0,  22.0), Vector3(0.20, 0.18, 0.20), 1.8)
	_place(rock_c_scene, Vector3( 22.0, 0.0, -22.0), Vector3(0.18, 0.22, 0.18), 4.1)
	_place(rock_c_scene, Vector3(-22.5, 0.0, -21.5), Vector3(0.24, 0.20, 0.24), 5.6)

	_place(rock_a_scene, Vector3( 0.0, 0.0,  22.5), Vector3(0.38, 0.32, 0.38), 0.2)
	_place(rock_a_scene, Vector3( 0.5, 0.0, -22.8), Vector3(0.42, 0.36, 0.42), 2.4)
	_place(rock_a_scene, Vector3( 22.6, 0.0,  0.0), Vector3(0.34, 0.40, 0.34), 1.1)
	_place(rock_a_scene, Vector3(-22.8, 0.0, -1.0), Vector3(0.40, 0.34, 0.40), 3.7)

	_place(rock_b_scene, Vector3( 12.5, 0.0,  21.8), Vector3(0.26, 0.24, 0.26), 0.9)
	_place(rock_b_scene, Vector3(-13.0, 0.0,  22.2), Vector3(0.30, 0.22, 0.28), 2.2)
	_place(rock_b_scene, Vector3( 21.5, 0.0, -12.0), Vector3(0.24, 0.28, 0.24), 4.8)
	_place(rock_b_scene, Vector3(-21.8, 0.0,  12.5), Vector3(0.28, 0.24, 0.30), 5.9)
	_place(rock_b_scene, Vector3(-12.0, 0.0, -22.0), Vector3(0.22, 0.26, 0.22), 1.5)
	_place(rock_b_scene, Vector3( 13.5, 0.0, -21.6), Vector3(0.32, 0.26, 0.30), 3.3)

	_place(rock_a_scene, Vector3(-14.5, 0.0,  11.0), Vector3(0.22, 0.20, 0.22), 0.6)
	_place(rock_b_scene, Vector3( 14.0, 0.0, -10.5), Vector3(0.18, 0.16, 0.18), 2.9)
	_place(rock_a_scene, Vector3(-11.0, 0.0, -13.5), Vector3(0.16, 0.18, 0.16), 4.4)

	_place(crystal_scene, Vector3( 18.5, 0.0,  16.0), Vector3(0.16, 0.18, 0.16), 0.3)
	_place(crystal_scene, Vector3(-17.5, 0.0,  8.5), Vector3(0.14, 0.20, 0.14), 1.7)
	_place(crystal_scene, Vector3( 8.0, 0.0, -18.0), Vector3(0.12, 0.16, 0.12), 5.1)


func _place(scene: PackedScene, pos: Vector3, mesh_scale: Vector3, yaw: float) -> void:
	if scene == null:
		return
	var node := scene.instantiate() as Node3D
	if node == null:
		return
	add_child(node)
	node.scale = mesh_scale
	node.rotation.y = yaw
	node.position = pos
	_sit_on_ground(node)


func _sit_on_ground(node: Node3D) -> void:
	var aabb := AABB()
	var has_aabb := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := child as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		var local := mesh_inst.mesh.get_aabb()
		var world := mesh_inst.global_transform * local
		if not has_aabb:
			aabb = world
			has_aabb = true
		else:
			aabb = aabb.merge(world)
	if has_aabb:
		node.global_position.y += -aabb.position.y
