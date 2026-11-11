extends SceneTree

# End-to-end traversal of course 3: the pig walks the whole woodland with real
# physics and click-to-move - stealth zone, mimic grove, the entry illusory
# wall, and the new illusion maze (through every gap, past the golden mimic
# dead end) - to the hollow-tree exit. Proves the maze is completable and its
# gaps line up with the fixed -Z camera.

const TRAVERSAL = preload("res://tests/scene/course_traversal.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_03_TRAVERSAL_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _route() -> Array[Vector3]:
	# Every leg is verified to clear each maze row's z-band (±0.4) inside its gap.
	return [
		Vector3(0.0, 0.6, 8.0),     # stealth zone entrance
		Vector3(0.0, 0.6, -10.0),   # patrol guard corridor
		Vector3(0.0, 0.6, -36.0),   # mimic grove
		Vector3(0.0, 0.6, -44.0),   # approach the entry illusory wall
		Vector3(3.0, 0.6, -50.0),   # maze corridor 1
		Vector3(3.0, 0.6, -53.5),   # through row A's right gap (x = 3)
		Vector3(0.0, 0.6, -53.5),   # west along corridor 2
		Vector3(-1.0, 0.6, -59.0),  # south through row B's left gap (x = -1)
		Vector3(0.5, 0.6, -61.8),   # through the illusory row C (shatters on touch)
		Vector3(1.0, 0.6, -67.5),   # through row D's right gap
		Vector3(3.0, 0.6, -67.5),   # line up with row E's narrow right gap
		Vector3(3.5, 0.6, -70.5),   # through row E's gap (x = 2..5)
		Vector3(0.5, 0.6, -72.6),   # corridor between E and F (past the mimic lure)
		Vector3(-2.0, 0.6, -76.0),  # through row F's left gap
		Vector3(0.0, 0.6, -88.0),   # hollow-tree exit
	]

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await process_frame
	game.choose_red()

	office._select_level_from_settings("course_3")
	await process_frame
	var course = office.active_course
	var runner: CourseRunner = course.runner
	_check(is_instance_valid(course) and runner.config.course_id == "course_3", "Course 3 loaded")
	runner.course_started.connect(func(): runner.set_dogs_active(false)) # Keep the bot out of QTEs

	var result: Dictionary = await TRAVERSAL.walk(self, office.player, _route(), func(): return runner.completed, 110.0)
	_check(result["ok"], "Pig physically walked the woodland to the exit (waypoint %d at %s, reason: %s)" % [result["index"], result["position"], result["reason"]])
	print("COURSE_03_TRAVERSAL_TEST INFO: lap splits=%s knocks=%d" % [result["splits"], result["knocks"]])

	if result["ok"]:
		await create_timer(0.3).timeout
		_check(office.active_course == null and office.farm.get_parent() == office, "Course exited and farm restored after the portal")
		_check(game.chase_completed.get("chase_3", false), "chase_3 completed by physically reaching the exit")
		_check(course == null or not is_instance_valid(course.maze_illusory_wall) or course.maze_illusory_wall.is_shattered, "Entry through the maze required shattering the illusory row")
	else:
		if is_instance_valid(office.active_course):
			office._select_level_from_settings("farm")
			await process_frame

	print("\nALL COURSE 03 TRAVERSAL TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
