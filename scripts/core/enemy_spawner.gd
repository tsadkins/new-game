extends Node
## Spawns a new enemy on a repeating timer, at a random spot around the player.

## The enemy scene to spawn.
@export var enemy_scene: PackedScene
## Seconds between spawns.
@export var spawn_interval: float = 7.0
## Closest/farthest an enemy can appear from the player.
@export var min_spawn_distance: float = 8.0
@export var max_spawn_distance: float = 14.0
## Enemies never spawn beyond this distance from the world origin (keeps them on the floor).
@export var arena_half_size: float = 22.0
## Height to spawn at (should match where a standing enemy rests on the floor).
@export var spawn_height: float = 1.0
## Stop spawning once this many enemies are alive. 0 = no limit.
@export var max_enemies: int = 15

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.one_shot = false
	_timer.autostart = true
	_timer.timeout.connect(_spawn_enemy)
	add_child(_timer)


func _spawn_enemy() -> void:
	if enemy_scene == null:
		push_warning("EnemySpawner: no enemy_scene assigned.")
		return
	if max_enemies > 0 and get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return

	var scene_root := get_tree().current_scene
	var enemy := enemy_scene.instantiate() as Node3D
	scene_root.add_child(enemy)
	enemy.global_position = _pick_spawn_position()


## Random point in a ring around the player, clamped to the arena.
func _pick_spawn_position() -> Vector3:
	var center := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		center = player.global_position

	var angle := randf() * TAU
	var distance := randf_range(min_spawn_distance, max_spawn_distance)
	var pos := center + Vector3(cos(angle), 0.0, sin(angle)) * distance

	pos.x = clampf(pos.x, -arena_half_size, arena_half_size)
	pos.z = clampf(pos.z, -arena_half_size, arena_half_size)
	pos.y = spawn_height
	return pos
