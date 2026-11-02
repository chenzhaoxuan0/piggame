extends SceneTree

var _failures: int = 0
var _results: Array[bool] = []

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
	var packed: PackedScene = load("res://scenes/characters/pig.tscn")
	var player: PigController = packed.instantiate() as PigController
	world.add_child(player)
	player.reset_at(Vector3(0, 0.1, -5))
	player.is_moving = true
	player.velocity = Vector3(4, 0, 0)
	player.set_control_mode("dialogue")
	_check(not player.is_moving and player.velocity == Vector3.ZERO, "dialogue clears movement and velocity")
	player.handle_click_or_tap(Vector2(100, 100))
	_check(not player.is_moving, "locked click does not move")
	player.set_dash_enabled(true)
	player.dash_remaining = 1.0
	player.cooldown_remaining = 4.0
	player.reset_at(Vector3(0, 0.1, -5))
	_check(player.dash_remaining == 0.0 and player.cooldown_remaining == 0.0, "reset clears dash and cooldown")
	player.set_dash_enabled(false)
	_check(not player.dash_enabled, "dash remains unavailable without horse skill")
	var chase: SimpleChase = SimpleChase.new()
	world.add_child(chase)
	chase.finished.connect(func(success: bool): _results.append(success))
	var spawns: Array[Vector3] = [Vector3(-2, 0.1, -1), Vector3(2, 0.1, 0)]
	chase.start_chase(player, spawns)
	_check(chase.get_child_count() == 2 and chase.running, "start creates exactly two dogs")
	chase.start_chase(player, spawns)
	_check(chase.get_child_count() == 2, "repeated start replaces dogs instead of accumulating")
	chase.set_active(false)
	player.global_position.z = -24
	chase._physics_process(0.016)
	_check(_results.is_empty() and chase.running, "paused chase does not finish at exit")
	chase.set_active(true)
	chase._physics_process(0.016)
	chase._physics_process(0.016)
	_check(_results.size() == 1 and _results[0], "exit emits success once")
	chase.stop_chase()
	chase.stop_chase()
	_check(chase.get_child_count() == 0 and not chase.running, "stop is idempotent and removes all dogs")
	player.reset_at(Vector3(0, 0.1, -5))
	chase.start_chase(player, spawns)
	var first_dog: ChaseDog = chase.get_child(0) as ChaseDog
	chase._on_player_caught(first_dog)
	chase._on_player_caught(first_dog)
	_check(_results.size() == 2 and not _results[1], "capture emits failure once")
	for iteration: int in range(3):
		chase.start_chase(player, spawns)
		_check(chase.get_child_count() == 2, "retry %d contains no old dogs" % iteration)
		chase.stop_chase()
	var course: Array[Vector3]=[Vector3(0,0,0),Vector3(-8,0,8),Vector3(-16,0,0),Vector3(-8,0,-8),Vector3(0,0,-4)]
	_results.clear()
	chase.start_course(player,spawns,course)
	player.global_position=course[-1]
	chase._physics_process(.016)
	_check(_results.is_empty() and chase.course_checkpoint==0,"jumping directly to exit cannot skip course")
	player.global_position=course[1]
	chase.set_active(false)
	chase._physics_process(.016)
	_check(chase.course_checkpoint==0,"pause cannot advance course checkpoints")
	chase.set_active(true)
	for point in course.slice(1):
		player.global_position=point
		chase._physics_process(.016)
	_check(_results.size()==1 and _results[0],"ordered curved course finishes once")
	chase.stop_chase()
	_check(chase.course.is_empty() and chase.course_checkpoint==0,"retry clears old checkpoint progress")
	_results.clear()
	chase.start_course(player,spawns,course)
	for point in course.slice(1,-1):
		player.global_position=point
		chase._physics_process(.016)
	player.global_position=course[-1]
	chase._on_player_caught(chase._dogs[0])
	_check(_results.size()==1 and _results[0],"course exit wins same-frame capture before manager tick")
	world.queue_free()
	await process_frame
	print("CHASE CONTRACT TESTS: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)
