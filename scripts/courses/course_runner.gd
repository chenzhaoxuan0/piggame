extends Node3D
class_name CourseRunner

signal checkpoint_reached(index: int, pos: Vector3)
signal course_started
signal course_completed
signal player_respawned(pos: Vector3)
signal qte_requested(dog: ChaseDog)
signal pressure_changed(distance: float)

const DOG_SCRIPT = preload("res://scripts/chase/chase_dog.gd")

@export var config: CourseConfig

var player: Node3D = null
var checkpoints: Array[Vector3] = []
var last_checkpoint: Vector3 = Vector3.ZERO
var respawn_count := 0
var in_qte := false
var started := false
var completed := false
var exit_position: Vector3 = Vector3.INF

var _dogs: Array[ChaseDog] = []
var _meme_layer: Node = null
var _stuck_time := 0.0
var _last_pos: Vector3 = Vector3.INF
var _alert_time := 0.0 # Stealth alarm: dogs sprint at boosted max speed while active
var _checkpoint_yaws: Dictionary = {} # respawn pos -> camera yaw pinned via "respawn_yaw" meta

func _ready() -> void:
	if config == null:
		config = CourseConfig.new()
	var collected: Array = []
	for node in get_tree().get_nodes_in_group("course_checkpoint"):
		if not get_parent().is_ancestor_of(node):
			continue
		var area := node as Area3D
		if area == null:
			continue
		var index: int = int(area.get_meta("checkpoint_index", checkpoints.size()))
		var pos: Vector3 = area.get_meta("respawn_pos", area.global_position)
		collected.append([index, pos])
		if area.has_meta("respawn_yaw"):
			# Optional camera yaw pin: on tracks that bend, the direction toward the
			# next checkpoint can point sideways, but the camera stays track-locked.
			_checkpoint_yaws[pos] = float(area.get_meta("respawn_yaw"))
		area.body_entered.connect(_on_checkpoint.bind(index, pos))
	# Order by checkpoint index: dog routes and respawn_yaw() must follow the course's
	# travel direction (a plain Array[Vector3].sort() is lexicographic x/y/z and
	# reverses these tracks, which all run toward -Z).
	collected.sort()
	for entry in collected:
		checkpoints.append(entry[1])
	for node in get_tree().get_nodes_in_group("course_exit"):
		if get_parent().is_ancestor_of(node) and node is Area3D:
			exit_position = node.global_position
			node.body_entered.connect(_on_exit)
	for node in get_tree().get_nodes_in_group("course_start"):
		if get_parent().is_ancestor_of(node) and node is Area3D:
			node.body_entered.connect(_on_start)
	for node in get_tree().get_nodes_in_group("meme_layer"):
		if get_parent().is_ancestor_of(node):
			_meme_layer = node
			break
	if _meme_layer and _meme_layer.has_method("configure"):
		_meme_layer.configure(config.memes)

func setup(p: Node3D, spawn_pos: Vector3) -> void:
	player = p
	last_checkpoint = spawn_pos
	_last_pos = spawn_pos
	_spawn_dogs()

func _spawn_dogs() -> void:
	var route: Array[Vector3] = checkpoints.duplicate()
	if exit_position != Vector3.INF:
		route.append(exit_position)
	for i in config.dog_count:
		var dog: ChaseDog = DOG_SCRIPT.new()
		dog.name = "CourseDog%d" % i
		add_child(dog)
		dog.global_position = last_checkpoint + Vector3((i + 1) * 2.0, 0.5, 6.0)
		dog.course = route
		dog.caught_player.connect(_on_dog_caught.bind(dog))
		dog.grapple_started.connect(_on_dog_grapple)
		dog.configure(player, 0.5 + i * 0.4)
		dog.set_active(false)
		_dogs.append(dog)

func _on_start(body: Node3D) -> void:
	if body != player or started or completed:
		return
	started = true
	for dog in _dogs:
		if is_instance_valid(dog):
			dog.set_active(true)
	course_started.emit()
	_meme("course_start", player.global_position)

func _on_checkpoint(body: Node3D, index: int, pos: Vector3) -> void:
	if body != player:
		return
	last_checkpoint = pos
	checkpoint_reached.emit(index, pos)

func _on_exit(body: Node3D) -> void:
	if body != player or not started or completed:
		return
	completed = true
	for dog in _dogs:
		if is_instance_valid(dog):
			dog.set_active(false)
	course_completed.emit()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_alert_time = maxf(0.0, _alert_time - delta)
	_watchdog(delta)
	if started and not completed:
		_rubber_band()

func alert_dogs(duration: float = 4.0) -> void:
	# Stealth alarm (course 3 vision cones): the rubber-band dogs sprint at a
	# boosted max speed for a while, so being spotted has real consequences
	# while staying non-lethal (grapples still resolve via QTE/slapstick).
	_alert_time = maxf(_alert_time, duration)

func _watchdog(delta: float) -> void:
	var pos: Vector3 = player.global_position
	if pos.y < config.kill_y or not config.bounds.has_point(pos):
		_respawn()
		return
	if not started or in_qte or completed:
		_last_pos = pos
		return
	if player.has_method("is_knocked_back") and player.is_knocked_back():
		_last_pos = pos
		_stuck_time = 0.0
		return
	var on_floor: bool = not player.has_method("is_on_floor") or player.is_on_floor()
	if not on_floor and _last_pos != Vector3.INF and pos.distance_to(_last_pos) < 0.05:
		_stuck_time += delta
		if _stuck_time >= config.stuck_timeout:
			_respawn()
			return
	else:
		_stuck_time = 0.0
	_last_pos = pos

func _respawn() -> void:
	_stuck_time = 0.0
	respawn_count += 1
	in_qte = false
	if player.has_method("reset_at"):
		player.reset_at(last_checkpoint)
	else:
		player.global_position = last_checkpoint
	_last_pos = last_checkpoint
	for dog in _dogs:
		if is_instance_valid(dog) and dog.phase == "grapple":
			dog.stun(1.5)
	player_respawned.emit(last_checkpoint)
	_meme("respawn", last_checkpoint)

func _rubber_band() -> void:
	var nearest := 999.0
	for dog in _dogs:
		if not is_instance_valid(dog) or not dog.active:
			continue
		var offset: Vector3 = dog.global_position - player.global_position
		offset.y = 0.0
		var dist: float = offset.length()
		nearest = minf(nearest, dist)
		var t: float = clampf((dist - config.dog_close_distance) / maxf(0.01, config.dog_far_distance - config.dog_close_distance), 0.0, 1.0)
		var speed_max: float = config.dog_speed_max * (1.35 if _alert_time > 0.0 else 1.0)
		dog.chase_speed = lerpf(config.dog_speed_min, speed_max, t)
		if dist > config.dog_catchup_distance:
			var dir: Vector3 = offset.normalized() if dist > 0.01 else Vector3.BACK
			dog.global_position = player.global_position + dir * (config.dog_far_distance + 2.0)
			dog.velocity = Vector3.ZERO
	pressure_changed.emit(nearest)

func can_dog_grapple() -> bool:
	return started and not completed and not in_qte

func set_dogs_active(enabled: bool) -> void:
	for dog in _dogs:
		if is_instance_valid(dog):
			dog.set_active(enabled)

func reject_qte(dog: ChaseDog) -> void:
	# The level refused the qte_requested signal (pause, dialogue, cinematic...):
	# roll back so in_qte cannot stick (it would disable grappling and the
	# watchdog's kill_y rescue for the rest of the course) and free the dog.
	in_qte = false
	if is_instance_valid(dog) and dog.phase == "grapple":
		dog._captured = false
		dog.phase = "seek"

func respawn_yaw() -> float:
	# Third-person camera yaw (0 = looking -Z) aimed along the course from the
	# current checkpoint toward the next one (or the exit), so respawns and course
	# entries face down the track instead of wherever the last chase happened to end.
	if _checkpoint_yaws.has(last_checkpoint):
		return _checkpoint_yaws[last_checkpoint]
	var target := exit_position
	for i in checkpoints.size():
		if checkpoints[i].distance_to(last_checkpoint) < 0.01:
			if i + 1 < checkpoints.size():
				target = checkpoints[i + 1]
			break
	var dir := target - last_checkpoint
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	return atan2(-dir.x, -dir.z)

func _on_dog_grapple(dog: ChaseDog) -> void:
	if not started or completed:
		dog.phase = "seek"
		return
	if in_qte:
		dog.phase = "seek"
		return
	var gm := _gm()
	var has_skill: bool = bool(gm.get("has_struggle_skill")) if gm else false
	if has_skill:
		in_qte = true
		dog._captured = false
		qte_requested.emit(dog)
	else:
		_slapstick_escape(dog)

func _on_dog_caught(dog: ChaseDog) -> void:
	if in_qte:
		return
	_slapstick_escape(dog)

func _slapstick_escape(dog: ChaseDog) -> void:
	var dir: Vector3 = player.global_position - dog.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	if player.has_method("apply_knockback"):
		player.apply_knockback(dir * 6.0 + Vector3.UP * 4.5, 0.7)
	dog.stun(2.0, -dir * 3.0)
	_meme("dog_bonk", player.global_position)

func resolve_qte(dog: ChaseDog, success: bool) -> void:
	in_qte = false
	if not is_instance_valid(dog):
		return
	var dir: Vector3 = dog.global_position - player.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	if success:
		dog.stun(2.8, dir * 6.0)
		_meme("qte_success", player.global_position)
	else:
		if player.has_method("apply_knockback"):
			player.apply_knockback(-dir * 5.0 + Vector3.UP * 4.0, 0.6)
		dog.stun(1.2)
		_meme("qte_fail", player.global_position)

func _gm() -> Node:
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

func _meme(meme_id: String, world_pos: Vector3) -> void:
	if _meme_layer and _meme_layer.has_method("play"):
		_meme_layer.play(meme_id, world_pos)