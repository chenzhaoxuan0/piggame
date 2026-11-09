extends Node3D
class_name SimpleChase

signal finished(success: bool)
signal pressure_changed(distance: float)
signal qte_requested(dog: ChaseDog)

const DOG_SCRIPT = preload("res://scripts/chase/chase_dog.gd")

var running: bool = false
var active: bool = false
var in_qte: bool = false
var current_stage_id: String = ""
var _player: Node3D = null
var _exit_z: float = -23.0
var _exit_pos: Vector3 = Vector3.INF
var _dogs: Array[ChaseDog] = []
var course: Array[Vector3] = []
var course_checkpoint := 0
var _ambushes: Array = []
var _current_stage_speed: float = 5.4

func start_stage(stage_id: String, player: Node3D, config: Dictionary, route_points: Array[Vector3]) -> void:
	stop_chase()
	current_stage_id = stage_id
	_player = player
	running = true
	active = true
	in_qte = false
	course = route_points.duplicate()
	course_checkpoint = 0
	_exit_pos = config.get("gate_pos", Vector3.INF)
	_exit_z = -INF
	_ambushes = config.get("ambushes", []).duplicate(true)
	
	var spawns: Array = config.get("spawns", [])
	var speed: float = float(config.get("dog_speed", 5.4))
	_current_stage_speed = speed
	var has_phantom: bool = bool(config.get("has_phantom", false))
	var phantom_count: int = int(config.get("phantom_count", 0))
	var gm := _get_gm()
	var can_discern: bool = bool(gm.get("has_discern_skill")) if gm else false
	
	# Spawn real dogs (spawn all specified in spawns)
	for index in range(spawns.size()):
		var dog: ChaseDog = DOG_SCRIPT.new()
		dog.name = "RealDog%d" % index
		add_child(dog)
		dog.global_position = spawns[index]
		_dogs.append(dog)
		dog.course = course
		dog.chase_speed = speed
		dog.caught_player.connect(_on_player_caught.bind(dog))
		dog.grapple_started.connect(_on_dog_grapple)
		dog.configure(player, 0.4 + index * 0.3)
	
	# Spawn phantom dogs if applicable
	if has_phantom and phantom_count > 0:
		for p_idx in range(phantom_count):
			var p_dog: ChaseDog = DOG_SCRIPT.new()
			add_child(p_dog)
			var base_spawn: Vector3 = spawns[0] if not spawns.is_empty() else player.global_position + Vector3(0, 0, 5)
			p_dog.global_position = base_spawn + Vector3((p_idx + 1) * 2.2, 0, 1.5)
			p_dog.course = course
			p_dog.chase_speed = speed * 1.02
			p_dog.set_phantom(true)
			p_dog.update_discern_state(can_discern)
			_dogs.append(p_dog)
			p_dog.caught_player.connect(_on_player_caught.bind(p_dog))
			p_dog.grapple_started.connect(_on_dog_grapple)
			p_dog.configure(player, 0.6 + p_idx * 0.3)

func can_dog_grapple() -> bool:
	return running and active and not in_qte

func has_threatening_dog() -> bool:
	if not running or not active:
		return false
	for dog in _dogs:
		if is_instance_valid(dog) and dog.has_method("is_threatening_player") and dog.is_threatening_player():
			return true
	return false

func _on_dog_grapple(dog: ChaseDog) -> void:
	if not running or not active or in_qte:
		if is_instance_valid(dog) and dog.phase == "grapple":
			dog.phase = "seek"
		return
	in_qte = true
	dog._captured = false
	qte_requested.emit(dog)

func resolve_qte(dog: ChaseDog, success: bool) -> void:
	in_qte = false
	if success:
		if is_instance_valid(dog):
			var gm := _get_gm()
			var has_ox_skill: bool = bool(gm.get("has_struggle_skill")) if gm else false
			var knock_dir := (dog.global_position - _player.global_position)
			knock_dir.y = 0
			var knock_power: float = 6.0 if has_ox_skill else 3.5
			var stun_time: float = 2.8 if has_ox_skill else 1.8
			dog.stun(stun_time, knock_dir.normalized() * knock_power)
		# Stagger other close dogs so player gets breathing room to escape
		for other_dog in _dogs:
			if is_instance_valid(other_dog) and other_dog != dog and other_dog.phase != "stun":
				if is_instance_valid(_player) and other_dog.global_position.distance_to(_player.global_position) < 4.0:
					var stagger_dir := (other_dog.global_position - _player.global_position)
					stagger_dir.y = 0
					other_dog.stun(1.2, stagger_dir.normalized() * 3.0)
	else:
		_finish(false)

func refresh_discern_status() -> void:
	var gm := _get_gm()
	var can_discern: bool = bool(gm.get("has_discern_skill")) if gm else false
	for dog in _dogs:
		if is_instance_valid(dog) and dog.is_phantom:
			dog.update_discern_state(can_discern)

func _get_gm() -> Node:
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

func start_course(player: Node3D, spawns: Array[Vector3], points: Array[Vector3], pursuit_path: Array[Vector3] = []) -> void:
	start_chase(player, spawns, -INF)
	course = points.duplicate()
	course_checkpoint = 0
	for dog in _dogs:
		dog.course = course if pursuit_path.is_empty() else pursuit_path
		dog.chase_speed = 4.1

func fail_course() -> void:
	if running and active: _finish(false)

func _at_exit() -> bool:
	if not is_instance_valid(_player): return false
	if _exit_pos != Vector3.INF and _player.global_position.distance_to(_exit_pos) < 6.5:
		return true
	if course.is_empty(): return _player.global_position.z <= _exit_z
	return course_checkpoint >= course.size()-1 and _player.global_position.distance_to(course[-1]) < 6.0

func _update_course_progress() -> void:
	if not course.is_empty() and course_checkpoint < course.size()-1 and is_instance_valid(_player):
		if _player.global_position.distance_to(course[course_checkpoint+1]) < 3.8:
			course_checkpoint += 1

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
	course.clear()
	course_checkpoint = 0
	_ambushes.clear()
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
	_update_course_progress()
	_check_ambushes()
	if _at_exit():
		_finish(true)
		return
	var nearest: float = 999.0
	for dog: ChaseDog in _dogs:
		if is_instance_valid(dog):
			var offset: Vector3 = dog.global_position - _player.global_position
			offset.y = 0.0
			nearest = minf(nearest, offset.length())
	pressure_changed.emit(nearest)

func _check_ambushes() -> void:
	if not is_instance_valid(_player): return
	var gm := _get_gm()
	var can_discern: bool = bool(gm.get("has_discern_skill")) if gm else false
	for ambush in _ambushes:
		if ambush.get("triggered", false):
			continue
		var trigger_pos: Vector3 = ambush.get("trigger", Vector3.INF)
		var radius: float = float(ambush.get("radius", 5.0))
		if _player.global_position.distance_to(trigger_pos) <= radius:
			ambush["triggered"] = true
			_spawn_ambush_dog(ambush, can_discern)

func _spawn_ambush_dog(ambush: Dictionary, can_discern: bool) -> void:
	var dog: ChaseDog = DOG_SCRIPT.new()
	var is_p: bool = bool(ambush.get("phantom", false))
	dog.name = ("AmbushPhantom_%d" if is_p else "AmbushDog_%d") % _dogs.size()
	add_child(dog)
	var spawn_pos: Vector3 = ambush.get("spawn", _player.global_position + Vector3(0, 0, 4))
	dog.global_position = spawn_pos
	dog.course = course
	dog.chase_speed = float(ambush.get("speed", _current_stage_speed))
	if is_p:
		dog.set_phantom(true)
		dog.update_discern_state(can_discern)
	_dogs.append(dog)
	dog.caught_player.connect(_on_player_caught.bind(dog))
	dog.grapple_started.connect(_on_dog_grapple)
	dog.configure(_player, 0.45)
	# Ambush dog lunges forward dynamically from bushes
	var dir := (_player.global_position - spawn_pos).normalized()
	dir.y = 0
	dog.velocity = dir * 3.5 + Vector3.UP * 4.2

func _on_player_caught(dog: ChaseDog) -> void:
	if running and active and _dogs.has(dog):
		# Crossing the exit and a dog callback in the same frame favors escape.
		_update_course_progress()
		_finish(_at_exit())

func _finish(success: bool) -> void:
	if not running:
		return
	running = false
	active = false
	for dog: ChaseDog in _dogs:
		if is_instance_valid(dog):
			dog.set_active(false)
	finished.emit(success)
