extends SceneTree

# End-to-end traversal of the nightmare prologue: the pig walks the whole
# dream with real physics - the fog-chased pens, then the SERPENTINE conveyor
# plant (right turn east, left turn south, right turn east, left turn south),
# into the dock and the waking light. Proves the turns are walkable and the
# exit is reachable; reports the lap time.

const TRAVERSAL = preload("res://tests/scene/course_traversal.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_00_TRAVERSAL_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await process_frame
	game.choose_red()

	office.current_chase_id = "intro"
	office._enter_course("course_0")
	await process_frame
	var course = office.active_course
	var runner: CourseRunner = course.runner
	_check(is_instance_valid(course) and runner.config.course_id == "course_0", "Nightmare course loaded")
	runner.course_started.connect(func(): runner.set_dogs_active(false)) # Keep the bot out of grapples

	var result: Dictionary = await TRAVERSAL.walk(self, office.player, [
		Vector3(0.0, 0.6, 9.0),     # cross the start line into the dream
		Vector3(0.0, 0.6, -6.0),    # pens: between the patrol cages
		Vector3(0.0, 0.6, -18.0),   # checkpoint 1, fog door ahead
		Vector3(0.0, 0.6, -23.0),   # past the door, into the corner
		# Eastbound/southbound belt legs hug the SOUTH/EAST wall lane (z -33.2,
		# x 33.2, z -57.2): the hook mid-band is a timing gate for players; the
		# bot cannot time swings, so it takes the 1.3 m safe lane like a cautious
		# player would.
		Vector3(9.0, 0.6, -33.2),   # RIGHT TURN: onto the eastbound lines
		Vector3(17.0, 0.6, -33.2),  # belt A wade (against 2.4 m/s), south lane
		Vector3(26.0, 0.6, -33.2),  # belt B (3.0 m/s), south lane
		Vector3(31.5, 0.6, -33.0),  # overshoot EAST past the mouth before turning
		Vector3(33.2, 0.6, -38.0),  # LEFT TURN: south onto belt C, east lane
		Vector3(33.2, 0.6, -44.0),  # belt C wade, east lane under hook 3
		Vector3(33.3, 0.6, -47.3),  # prod crossing IN THE EAST LANE (cutting to
		# the centre here drags the pig through hook 3's sweep and resonates)
		Vector3(30.5, 0.6, -49.3),  # centre-line cut AFTER the hook, on solid floor
		Vector3(29.5, 0.6, -52.0),  # lateral transfer belt (drift east, aim west)
		Vector3(30.0, 0.6, -55.5),  # checkpoint 3
		Vector3(31.0, 0.6, -57.0),  # line up with the L4 mouth (opens at x 34)
		Vector3(37.0, 0.6, -57.2),  # RIGHT TURN: east link, south lane
		Vector3(43.0, 0.6, -57.2),  # steam gauntlet past hook 4
		Vector3(44.0, 0.6, -59.0),  # LEFT TURN: into the dock
		Vector3(46.0, 0.6, -63.0),  # dock crates
		Vector3(46.0, 0.6, -75.0),
		Vector3(46.0, 0.6, -84.0),  # into the waking light
	], func(): return runner.completed, 130.0)
	_check(result["ok"], "Pig physically walked the serpentine dream to the door (waypoint %d at %s, reason: %s)" % [result["index"], result["position"], result["reason"]])
	print("COURSE_00_TRAVERSAL_TEST INFO: dream lap = %.1f s, knocks = %d (design target for players: 90-150 s)" % [result["seconds"], result["knocks"]])
	if result["ok"]:
		await create_timer(0.3).timeout
		_check(office.active_course == null and office.farm.get_parent() == office, "Course exited and farm restored (the dream ends)")
		_check(office.player.control_mode != "qte", "Bot never needed a QTE (skill-less dream)")
	else:
		# Leave the course before quitting: tearing the engine down with a live
		# course leaks bodies and crashes at exit, burying the real failure.
		if is_instance_valid(office.active_course):
			office._select_level_from_settings("farm")
			await process_frame

	print("\nALL COURSE 00 TRAVERSAL TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
