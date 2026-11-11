extends SceneTree

# End-to-end traversal of the nightmare prologue: the pig walks the whole dream
# with real physics - past the pen guards' cones, down the hook lane (the belt
# wade is the slower-but-safe option for players; the walker takes the hooks),
# through the dock crates and into the waking light. Proves the dream is
# completable and reports the lap time against the 1.5-2.5 min design target.

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
		Vector3(0.0, 0.6, 9.0),    # cross the start line into the dream
		Vector3(0.0, 0.6, -6.0),   # pens: between the patrol rectangles
		Vector3(0.0, 0.6, -18.0),  # checkpoint 1
		Vector3(2.5, 0.6, -26.0),  # hook lane entry (belt wade is x = -2.6)
		Vector3(2.5, 0.6, -40.0),  # through the meathooks
		Vector3(2.5, 0.6, -54.0),  # checkpoint 2 approach
		Vector3(0.0, 0.6, -58.0),  # onto the dock (butcher alarm)
		Vector3(0.0, 0.6, -70.0),  # weave the crates
		Vector3(0.0, 0.6, -84.0),  # into the waking light
	], func(): return runner.completed, 110.0)
	_check(result["ok"], "Pig physically walked the whole nightmare to the door (waypoint %d at %s, reason: %s)" % [result["index"], result["position"], result["reason"]])
	print("COURSE_00_TRAVERSAL_TEST INFO: dream lap = %.1f s, knocks = %d (design target for players: 90-150 s)" % [result["seconds"], result["knocks"]])

	if result["ok"]:
		await create_timer(0.3).timeout
		_check(office.active_course == null and office.farm.get_parent() == office, "Course exited and farm restored (the dream ends)")
		_check(office.player.control_mode != "qte", "Bot never needed a QTE (skill-less dream)")

	print("\nALL COURSE 00 TRAVERSAL TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
