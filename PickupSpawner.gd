extends Node
## Spawns a random buff pickup somewhere in the arena on a repeating timer.

## Seconds between spawns.
@export var spawn_interval: float = 20.0
## Pickups appear within this distance of the world origin on X and Z (keep inside the walls).
@export var arena_half_size: float = 22.0
## Height above the floor the pickup floats at.
@export var spawn_height: float = 0.8
var _timer: Timer
var _live_pickups: Array = []


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.one_shot = false
	_timer.autostart = true
	_timer.timeout.connect(_spawn_pickup)
	add_child(_timer)


func _spawn_pickup() -> void:
	# Forget pickups that have been collected.
	_live_pickups = _live_pickups.filter(func(p) -> bool: return is_instance_valid(p))

	# Only one of each buff may be on the field: choose among the types not already out there.
	var available: Array[Pickup.Type] = [Pickup.Type.HEAL, Pickup.Type.SPEED, Pickup.Type.DAMAGE]
	for live in _live_pickups:
		available.erase(live.type)
	if available.is_empty():
		return # all three are already on the field

	var pickup := Pickup.new()
	pickup.type = available.pick_random()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = Vector3(
		randf_range(-arena_half_size, arena_half_size),
		spawn_height,
		randf_range(-arena_half_size, arena_half_size))
	_live_pickups.append(pickup)
