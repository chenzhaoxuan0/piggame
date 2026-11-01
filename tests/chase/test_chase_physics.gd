extends SceneTree

var _results: Array[bool] = []
var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	world.add_child(floor_body)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30, 0.5, 80)
	collider.shape = shape
	collider.position = Vector3(0, -0.25, -10)
	floor_body.add_child(collider)
	var player: PigController = (load("res://scenes/characters/pig.tscn") as PackedScene).instantiate() as PigController
	world.add_child(player)
	var chase: SimpleChase = SimpleChase.new()
	world.add_child(chase)
	chase.finished.connect(func(success: bool): _results.append(success))
	player.reset_at(Vector3(0, 0.1, -5))
	player.set_control_mode("chase")
	player.set_dash_enabled(false)
	var spawns: Array[Vector3] = [Vector3(-3, 0.1, 0), Vector3(3, 0.1, 1)]
	chase.start_chase(player, spawns)
	Input.action_press("move_up")
	for frame: int in range(480):
		await physics_frame
		if not _results.is_empty():
			break
	Input.action_release("move_up")
	_check(_results.size() == 1 and _results[0], "real physics: base movement with no skill reaches exit")
	chase.stop_chase()
	player.reset_at(Vector3(0, 0.1, -5))
	spawns = [Vector3(0, 0.1, -3)]
	chase.start_chase(player, spawns)
	for frame: int in range(360):
		await physics_frame
		if _results.size() > 1:
			break
	_check(_results.size() == 2 and not _results[1], "real physics: staying still is caught after warning and lunge")
	chase.stop_chase()
	player.set_control_mode("dialogue")
	var locked_position: Vector3 = player.global_position
	Input.action_press("move_up")
	for frame: int in range(30):
		await physics_frame
	Input.action_release("move_up")
	_check(player.global_position.is_equal_approx(locked_position), "real physics: held movement cannot move player during dialogue")
	world.queue_free()
	await process_frame
	print("CHASE PHYSICS TESTS: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)
