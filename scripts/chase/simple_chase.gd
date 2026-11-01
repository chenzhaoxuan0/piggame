extends Node3D
class_name SimpleChase

signal finished(success: bool)
signal pressure_changed(distance: float)

const DOG_SCRIPT = preload("res://scripts/chase/chase_dog.gd")

var running: bool = false
var active: bool = false
var _player: Node3D = null
var _exit_z: float = -23.0
var _dogs: Array[ChaseDog] = []

func start_chase(player: Node3D, spawn_positions: Array[Vector3], exit_z: float = -23.0) -> void:
	stop_chase()
	if not is_instance_valid(player) or not player.is_inside_tree():
		push_warning("SimpleChase: player is not in the scene tree")
		return
	_player = player
	_exit_z = exit_z
	running = true
	active = true
	var positions: Array[Vector3] = spawn_positions.duplicate()
	if positions.is_empty():
		positions.append(player.global_position + Vector3(0, 0, 4))
	for index: int in range(mini(positions.size(), 2)):
		var dog: ChaseDog = DOG_SCRIPT.new()
		dog.name = "ChaseDog%d" % index
		add_child(dog)
		dog.global_position = positions[index]
		_dogs.append(dog)
		dog.caught_player.connect(_on_player_caught.bind(dog))
		dog.configure(player, 0.75 + index * 0.4)

func stop_chase() -> void:
	running = false
	active = false
	_player = null
	for dog: ChaseDog in _dogs:
		if is_instance_valid(dog):
			dog.set_active(false)
			remove_child(dog)
			dog.queue_free()
	_dogs.clear()

func set_active(enabled: bool) -> void:
	active = enabled and running
	for dog: ChaseDog in _dogs:
		if is_instance_valid(dog):
			dog.set_active(active)

func _physics_process(_delta: float) -> void:
	if not running or not active:
		return
	if not is_instance_valid(_player):
		stop_chase()
		return
	if _player.global_position.z <= _exit_z:
		_finish(true)
		return
	var nearest: float = 999.0
	for dog: ChaseDog in _dogs:
		if is_instance_valid(dog):
			var offset: Vector3 = dog.global_position - _player.global_position
			offset.y = 0.0
			nearest = minf(nearest, offset.length())
	pressure_changed.emit(nearest)

func _on_player_caught(dog: ChaseDog) -> void:
	if running and active and _dogs.has(dog):
		# Crossing the exit and a dog callback in the same frame favors escape.
		_finish(is_instance_valid(_player) and _player.global_position.z <= _exit_z)

func _finish(success: bool) -> void:
	if not running:
		return
	running = false
	active = false
	for dog: ChaseDog in _dogs:
		if is_instance_valid(dog):
			dog.set_active(false)
	finished.emit(success)
