extends SceneTree

# End-to-end traversal of course 2. The creek is a puzzle course, so the bot
# walks with real physics between puzzle beats and solves each beat with the
# same interactions a player uses: stepping stones, the cliff stairs (with
# jumps), the sand cascade that buries the throat sentry, the waterfall slide,
# the TNT push chain, and the 2.5 m canyon gap jump, into the nether portal.

const TRAVERSAL = preload("res://tests/scene/course_traversal.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_02_TRAVERSAL_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _tap_jump() -> void:
	# The pig's jump is event-driven, so a synthetic InputEventAction must go
	# through the input pipeline (Input.action_press alone never reaches it).
	var pressed := InputEventAction.new()
	pressed.action = "action_jump"
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventAction.new()
	released.action = "action_jump"
	released.pressed = false
	Input.parse_input_event(released)

func _climb_tick() -> void:
	# Auto-jump for stairs: pressed into a step face and grounded -> hop.
	var pig: Node3D = office.player
	if pig.is_on_floor() and pig.is_moving and Vector2(pig.velocity.x, pig.velocity.z).length() < 0.7:
		_tap_jump()

func _all_ticks() -> void:
	_climb_tick()
	_exit_tick()

func _exit_tick() -> void:
	# Auto-jump for the 2.5 m canyon gap. The window is deliberately tight and
	# close to the lip: a running jump covers ~2.9 m, so leaping from further
	# back lands short in the gap and the watchdog loop eats the timeout.
	var pig: Node3D = office.player
	if pig.is_on_floor() and pig.global_position.z > -68.1 and pig.global_position.z < -67.7 and pig.velocity.z < -1.0:
		_tap_jump()

func _walk(course: Node, waypoints: Array[Vector3], done: Callable, tick: Callable) -> bool:
	var result: Dictionary = await TRAVERSAL.walk(self, office.player, waypoints, done, 90.0, 1.3, tick)
	if not result["ok"]:
		_check(false, "Walk stalled at waypoint %d (%s), reason: %s" % [result["index"], result["position"], result["reason"]])
		if is_instance_valid(course) and is_instance_valid(office.active_course):
			office._select_level_from_settings("farm")
			await process_frame
		return false
	return true

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await process_frame
	game.choose_red()

	office._select_level_from_settings("course_2")
	await process_frame
	var course = office.active_course
	var runner: CourseRunner = course.runner
	_check(is_instance_valid(course) and runner.config.course_id == "course_2", "Course 2 loaded")
	runner.course_started.connect(func(): runner.set_dogs_active(false)) # Keep the bot out of QTEs

	# Phase 1: stepping stones across the creek (x = 3.6 lane)
	if not await _walk(course, [Vector3(3.6, 0.6, 6.0), Vector3(3.6, 0.6, -6.0)],
			func(): return office.player.global_position.distance_to(Vector3(3.6, 0.6, -6.0)) < 1.6, _climb_tick):
		quit(1)
		return
	_check(true, "Stepping stones crossed on foot")

	# Phase 2: up the cliff stairs (auto-jumps the 0.375 m steps) to the sand
	if not await _walk(course, [Vector3(0, 0.6, -12.0), Vector3(0, 0.6, -21.0), Vector3(0, 3.6, -28.0)],
			func(): return office.player.global_position.z < -27.0, _climb_tick):
		quit(1)
		return
	_check(office.player.global_position.y > 2.5, "Cliff stairs climbed to the high cliff")

	# Phase 3: the sand cascade - three pushes down the waterfall, one east push
	for i in 3:
		course.sand_block.push(Vector3(0, 0, -1.0))
		await create_timer(0.5).timeout
	course.sand_block.push(Vector3(1, 0, 0))
	await create_timer(0.5).timeout
	_check(course.canyon_dog_buried, "Sand cascade buried the throat sentry (4 pushes, real physics)")

	# Phase 4: down the waterfall chute into the canyon
	if not await _walk(course, [Vector3(0, 3.6, -32.2)],
			func(): return office.player.global_position.y < 1.2 and office.player.global_position.z < -34.0, Callable()):
		quit(1)
		return
	_check(true, "Waterfall chute ridden down into the canyon")

	# Phase 5: along the corridor under the waterfall steps, through the (now
	# open) throat and down to the pressure plate
	if not await _walk(course, [Vector3(-3.0, 0.6, -35.8), Vector3(2.8, 0.6, -35.8), Vector3(3.1, 0.6, -38.0), Vector3(0, 0.6, -44.0), Vector3(0, 0.6, -48.0)],
			func(): return office.player.global_position.z < -47.0, Callable()):
		quit(1)
		return
	_check(true, "Canyon throat passed after the burial")

	# Phase 6: the TNT push chain onto the plate blows the obsidian wall
	for i in 3:
		course.tnt_block.push(Vector3(0, 0, -1.0))
		await create_timer(0.45).timeout
	await create_timer(0.5).timeout
	_check(course.obsidian_wall == null or course.obsidian_wall.is_demolished, "TNT push chain demolished the obsidian wall")

	# Phase 7: the 2.5 m canyon gap (jump) and through the nether portal
	if not await _walk(course, [Vector3(0, 0.6, -67.8), Vector3(0, 0.6, -72.0), Vector3(0, 0.6, -84.0)],
			func(): return runner.completed, _all_ticks):
		quit(1)
		return
	_check(true, "Canyon gap jumped and the nether portal reached")

	await create_timer(0.3).timeout
	_check(office.active_course == null and office.farm.get_parent() == office, "Course exited and farm restored after the portal")
	_check(game.chase_completed.get("chase_2", false), "chase_2 completed by physically finishing the creek")

	print("\nALL COURSE 02 TRAVERSAL TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
