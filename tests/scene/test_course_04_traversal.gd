extends SceneTree

# End-to-end traversal of course 4: the pig runs the whole circuit with real
# physics and click-to-move, from the starting grid behind the boom barrier to
# the finish gate. This is the only place that proves the redesigned double-S
# track is actually completable. It runs two laps - one plain, one holding the
# horse dash - and reports both times so the 35 s record can be tuned against
# measured baselines instead of guesses.

const TRAVERSAL = preload("res://tests/scene/course_traversal.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_04_TRAVERSAL_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _racing_line() -> Array[Vector3]:
	# Left of the tire's lane, clear of the item boxes: a neutral baseline line.
	return [
		Vector3(-3.6, 0.6, 9.0),     # cross the start line
		Vector3(-3.6, 0.6, -12.0),   # start straight
		Vector3(1.0, 0.6, -19.0),    # bend 1 (right)
		Vector3(10.0, 0.6, -28.0),   # east lane entry
		Vector3(10.0, 0.6, -52.0),   # east lane: cones, mud, boost pads
		Vector3(8.0, 0.6, -60.0),    # bend 2 (left)
		Vector3(0.0, 0.6, -67.0),    # mid straight
		Vector3(0.0, 0.6, -78.0),
		Vector3(-10.0, 0.6, -92.0),  # bend 3 (left) into the nitro tunnel
		Vector3(-10.0, 0.6, -118.0), # west lane: boost pads and sweepers
		Vector3(0.0, 0.6, -131.0),   # bend 4 (right) onto the final straight
		Vector3(0.0, 0.6, -140.0),   # up the stunt ramp
		Vector3(0.0, 0.6, -164.0),   # through the finish gate
	]

func _lap(hold_dash: bool, check_barrier: bool) -> float:
	# Runs one full lap through the demo shortcut; returns the gate's real time
	# in seconds, or -1.0 if the pig never reached the finish line.
	var label := "dash lap" if hold_dash else "plain lap"
	office._select_level_from_settings("course_4")
	await process_frame
	var course = office.active_course
	var runner: CourseRunner = course.runner
	_check(is_instance_valid(course) and runner.config.course_id == "course_4", "Course 4 loaded (%s)" % label)

	# 进场节拍：先锁住讲剧情，快进放行后 3-2-1 倒计时才接管——台词不吃比赛时间。
	if check_barrier:
		_check(runner.beat_active() and runner.active_beat_id() == "course_4_intro", "Intro dialogue beat holds the grid (%s)" % label)
		_check(office.player.control_mode == "cinematic", "Pig locked during the intro beat")
	runner.skip_beats()
	await create_timer(0.15).timeout
	if check_barrier:
		_check(not runner.beat_active() and office.player.control_mode != "cinematic", "Beat released the pig")
		_check(course.race_timer.state == "countdown", "3-2-1 countdown starts after the intro beat")

	if check_barrier:
		# The boom barrier must physically hold the pig while the 3 s countdown
		# runs: order the pig down the track and make sure it gets nowhere.
		_check(course.race_timer.state == "countdown", "Race clock is counting down on the grid")
		office.player.interact_target = null
		office.player._click_route.clear()
		office.player.target_destination = Vector3(0, 0.6, 4.0)
		office.player.is_moving = true
		await create_timer(0.8).timeout
		_check(office.player.global_position.z > 10.5, "Boom barrier physically holds the pig on the grid")
		_check(not runner.started, "Start line does not trigger while the barrier is down")

	var go_wait := 0
	while course.race_timer.state != "running" and go_wait < 50:
		await create_timer(0.1).timeout
		go_wait += 1
	_check(course.race_timer.state == "running", "Race clock runs after GO (%s)" % label)
	runner.course_started.connect(func(): runner.set_dogs_active(false)) # Keep the bot out of QTEs

	var finish: Dictionary = {"time": -1.0}
	course.finish_gate.finish_line_crossed.connect(func(_p):
		finish["time"] = course.finish_gate.final_time
	)

	# Dash strategy for the held lap: burn the bar on straights, hands off near
	# the timing hazards (sweepers, pendulum, tire) - how a competent player
	# uses 疾风之步. Dashing full-tilt through the sweeper tunnel just feeds the
	# bot into the bars. Holding Shift nonstop additionally stalls at zero
	# stamina because recovery only ticks while the key is up.
	# (State lives in a Dictionary: lambdas capture plain locals by value.)
	var hazard_points: Array[Vector3] = []
	for hazard_name in ["RollingTire", "NeonSweeper1", "NeonSweeper2", "NeonSignPendulum", "MudPatch"]:
		var hazard: Node3D = course.get_node_or_null(hazard_name)
		if hazard != null:
			hazard_points.append(hazard.global_position)
	var dash := {"held": false}
	if hold_dash:
		Input.action_press("action_dash")
		dash["held"] = true
	var dash_tick := func() -> void:
		if not hold_dash:
			return
		var near_hazard := false
		for hp in hazard_points:
			if office.player.global_position.distance_to(hp) < 8.0:
				near_hazard = true
				break
		var stamina: float = office.player.stamina
		if dash["held"] and (stamina <= 0.05 or near_hazard):
			Input.action_release("action_dash")
			dash["held"] = false
		elif not dash["held"] and stamina >= office.player.max_stamina * 0.98 and not near_hazard:
			Input.action_press("action_dash")
			dash["held"] = true
	# 剧情节拍一出现即快进（bot 与玩家连按跳过共用 runner.skip_beats()）：
	# 终直道宣言照样出现并冻结计时，但绝不卡死 bot。
	var beats_seen := {}
	runner.beat_started.connect(func(id: String): beats_seen[id] = true)
	var beat_tick := func() -> void:
		if runner.beat_active():
			runner.skip_beats()
		dash_tick.call()
	var result: Dictionary = await TRAVERSAL.walk(self, office.player, _racing_line(), func(): return runner.completed, 110.0, 1.3, beat_tick)
	if dash["held"]:
		Input.action_release("action_dash")
		dash["held"] = false
	_check(result["ok"], "Pig physically ran the whole circuit to the finish line, %s (waypoint %d at %s, reason: %s)" % [label, result["index"], result["position"], result["reason"]])
	_check(beats_seen.has("course_4_final_straight"), "Final-straight sprint beat fired along the lap (%s)" % label)
	print("COURSE_04_TRAVERSAL_TEST INFO: %s splits=%s knocks=%d" % [label, result["splits"], result["knocks"]])
	await create_timer(0.3).timeout # Let the deferred course exit land
	if not result["ok"]:
		return -1.0
	_check(office.active_course == null and office.farm.get_parent() == office, "Course exited and farm restored after the finish (%s)" % label)
	return float(finish["time"])

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await process_frame
	game.choose_red()

	var plain_lap: float = await _lap(false, true)
	_check(plain_lap > 10.0 and plain_lap < 110.0, "Plain lap recorded a sane real time (%.2f s)" % plain_lap)
	_check(game.chase_completed.get("chase_final", false), "chase_final completed by physically finishing the race")

	var dash_lap: float = await _lap(true, false)
	_check(dash_lap > 10.0 and dash_lap < 110.0, "Dash lap recorded a sane real time (%.2f s)" % dash_lap)

	# Both lap times are reported, not asserted against each other: the bot
	# dodges nothing (4-5 knockbacks per lap), so physics chaos dominates the
	# dash-vs-plain gap. The meaningful checks are completion and the INFO line
	# for tuning the record time.

	print("COURSE_04_TRAVERSAL_TEST INFO: plain lap = %.2f s, dash lap = %.2f s (farm record to beat: 35.00 s)" % [plain_lap, dash_lap])

	# Leave the course before quitting: tearing the engine down with a live
	# course (after a failed lap) leaks its bodies and can crash on exit, which
	# would bury the real failure above.
	if is_instance_valid(office.active_course):
		office._select_level_from_settings("farm")
		await process_frame

	print("\nALL COURSE 04 TRAVERSAL TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
