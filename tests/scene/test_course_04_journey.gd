extends SceneTree

const L = preload("res://scripts/levels/farm_layout.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_04_JOURNEY_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _ground_under(point: Vector3) -> bool:
	# True when a world-layer collider sits under the given XZ (track slab, ramp...).
	var space: PhysicsDirectSpaceState3D = office.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 4.0, point.z), Vector3(point.x, -4.0, point.z), 1)
	return not space.intersect_ray(query).is_empty()

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await process_frame

	game.choose_red()
	office.farm.set_pigpen_open(true)
	await process_frame

	# 1. Secret Courtyard Pipe at Horse Pasture approach
	_check(office.farm.has_node("SecretCourtyardPipe"), "Farm has SecretCourtyardPipe entrance")
	_check(office.farm.has_node("SecretCourtyardPipeExit"), "Farm has SecretCourtyardPipeExit at final gate")
	var pipe: Node3D = office.farm.get_node("SecretCourtyardPipe")
	_check(pipe.position.distance_to(Vector3(-48.0, 2.0, -197.0)) < 1.0, "Secret courtyard entrance at the breakout-chase end, clear of the chase fence")
	_check(pipe.has_node("PipeBody") and pipe.has_node("PipeTopArea"), "Pipe has solid body and top detection area")

	# Pig standing on pipe rim
	var top_area := pipe.get_node("PipeTopArea") as Area3D
	top_area.body_entered.emit(office.player)
	_check(office.farm._player_on_pipe, "Pig standing on courtyard pipe rim detected")

	# Unlock companion skills (Ox, Sheep, Horse)
	game.complete_npc("ox")
	game.complete_npc("sheep")
	game.read_record()
	game.complete_npc("horse")
	await process_frame
	_check(game.has_dash_skill, "Dash skill granted by Horse")

	# Trigger descent into course_4
	office.farm._trigger_pipe_enter("course_4", pipe)
	await create_timer(0.5).timeout
	_check(is_instance_valid(office.active_course), "Secret pipe trigger loaded course_4")
	_check(office.farm.get_parent() == null, "Farm removed from tree during course")
	var runner: CourseRunner = office.active_course.runner
	_check(runner.config.course_id == "course_4", "Course 4 config wired")
	_check(runner._dogs.size() == 1, "Rubber-band dog spawned")
	var course = office.active_course

	# 1.1 Race start: the clock counts down behind a closed boom barrier
	_check(course.race_timer != null and course.race_timer.state == "countdown", "Race clock counts down from course entry")
	_check(is_instance_valid(course.start_barrier) and not course.start_barrier.get_child(0).disabled, "Boom barrier holds the grid during the countdown")
	_check(course.start_light_label.text in ["3", "2", "1"], "Start gantry mirrors the countdown")
	_check(not runner.started, "Dogs stay asleep until the pig crosses the line after GO")

	# 1.2 Real circuit layout: double S-bend, open gravel infields, outer barriers
	_check(course.has_node("StraightA") and course.has_node("CurveB") and course.has_node("OuterB") and course.has_node("HairpinC") and course.has_node("MidC") and course.has_node("CurveD") and course.has_node("OuterD") and course.has_node("HairpinE") and course.has_node("StraightC"), "Track has start straight, four bends, east and west lanes and a final straight")
	_check(course.get_node("OuterB").position.x - course.get_node("StraightA").position.x >= 8.0, "East lane is laterally offset from the start straight (not one straight line)")
	_check(course.get_node("StraightA").position.x - course.get_node("OuterD").position.x >= 8.0, "West lane swings out to the other side (double S)")
	_check(course.has_node("InfieldGravel") and course.has_node("InfieldGravel2") and course.gravel_traps.size() == 2, "Both infields between the lanes are gravel traps, not voids")
	_check(course.guardrails.size() >= 14, "Outer neon guardrails enclose the circuit")
	_check(runner.checkpoints.size() == 8, "Eight checkpoints registered around the circuit")
	await physics_frame
	var route: Array[Vector3] = [Vector3(0, 0.6, 12)]
	route.append_array(runner.checkpoints)
	route.append(runner.exit_position)
	var off_track := 0
	for i in route.size() - 1:
		for step in 13:
			if not _ground_under(route[i].lerp(route[i + 1], float(step) / 12.0)):
				off_track += 1
	_check(off_track == 0, "Dog route between checkpoints stays on the track through all four bends (%d samples off)" % off_track)
	_check(_ground_under(Vector3(2, 0, 18)), "Dog spawn point behind the grid has ground under it")

	# 2. Start trigger
	runner._on_start(office.player)
	await process_frame
	_check(runner.started, "Course 4 started")
	_check(game.is_in_chase(), "Game entered chase stage on course start")
	_check(office.player.control_mode == "chase", "Player in chase mode during course")
	_check(office.player.dash_enabled, "Dash sprint is live on the racing course")
	for dog in runner._dogs:
		dog.set_active(false)

	# 3. Checkpoint registration (outer lane, before the left bend)
	var checkpoint_3 := Vector3(10, 0.6, -54)
	runner._on_checkpoint(office.player, 3, checkpoint_3)
	_check(runner.last_checkpoint == checkpoint_3, "Checkpoint registered as respawn point")
	_check(is_zero_approx(runner.respawn_yaw()), "Respawn camera looks straight down the lane, not at the next bend")

	# 4. Watchdog: fall below kill_y -> respawn at checkpoint (non-lethal)
	office.player.global_position = Vector3(10, -50, -54)
	for i in 5: await physics_frame
	_check(runner.respawn_count >= 1, "Watchdog respawned pig after falling out of bounds")
	_check(office.player.global_position.y > -12.0, "Pig respawned above kill_y (not dead)")

	# 4.1 Mario Kart Racing Mechanics
	_check(course.boost_pad_1 != null, "Course 4 has BoostPad")
	office.player.velocity = Vector3.ZERO
	course.boost_pad_1._on_body_entered(office.player)
	_check(office.player.velocity.length() > 10.0, "BoostPad applied racing speed boost")
	office.player.velocity = Vector3.ZERO

	# Mud puddle and gravel infield slow the pig and give the speed back on exit
	var base_speed: float = office.player.move_speed
	course.mud_patch._on_body_entered(office.player)
	_check(is_equal_approx(office.player.move_speed, base_speed * 0.45), "Mud patch bogs the pig down to 45% speed")
	course.mud_patch._on_body_exited(office.player)
	_check(is_equal_approx(office.player.move_speed, base_speed), "Leaving the mud restores full speed")
	course.gravel_traps[0]._on_body_entered(office.player)
	_check(office.player.move_speed < base_speed * 0.5, "Gravel infield slows harder than the mud (shortcut is a trap)")
	course.gravel_traps[0]._on_body_exited(office.player)
	_check(is_equal_approx(office.player.move_speed, base_speed), "Leaving the gravel restores full speed")

	# Golden star: real invincibility against trap knockbacks, granted by the
	# course (course-scoped: it cannot leak into the farm).
	office.player.knockback_timer = 0.0
	var star_base_speed: float = office.player.move_speed
	course.get_node("MysteryItemBox1").item_collected.emit("GOLDEN_STAR", office.player)
	_check(office.player.get_meta("star_invincible", false), "Golden star flags the pig invincible")
	_check(is_equal_approx(office.player.move_speed, star_base_speed * 1.6), "Golden star grants its course-scoped speed boost")
	course.get_node("MysteryItemBox1").item_collected.emit("GOLDEN_STAR", office.player)
	_check(is_equal_approx(office.player.move_speed, star_base_speed * 1.6), "A second star refreshes the boost without stacking")
	course.sign_pendulum._knock(office.player, Vector3(6, 4, 0))
	_check(not office.player.is_knocked_back(), "Star pig plows through trap knockback")
	course._end_golden_star()
	_check(not office.player.get_meta("star_invincible", false) and is_equal_approx(office.player.move_speed, star_base_speed), "Star ends cleanly on demand")
	course.sign_pendulum._knock(office.player, Vector3(6, 4, 0))
	_check(office.player.is_knocked_back(), "Without the star the same trap knocks the pig")
	office.player.reset_at(checkpoint_3)

	# Final straight: horse dash payoff refills the sprint stamina
	office.player.stamina = 0.5
	course._on_final_straight_entered(office.player)
	_check(is_equal_approx(office.player.stamina, office.player.max_stamina), "Final straight refills dash stamina for the sprint to the line")
	_check(course.stunt_ramp.position.z > course.finish_gate.position.z, "Stunt ramp sits before the finish line")

	# No stuck pocket beside the pendulum gantry. Reproduces the exact pose a
	# traversal run got wedged in: hugging the west rail just north of where the
	# gantry post used to stand 0.8 m inside it (narrower than the pig), steering
	# for the ramp. The pig must be able to run on down the final straight.
	var wedge_target := Vector3(0, 0.6, -140.0)
	office.player.reset_at(Vector3(-4.38, 0.6, -135.12))
	office.player.interact_target = null
	office.player._click_route.clear()
	office.player.target_destination = wedge_target
	office.player.is_moving = true
	var pocket_wait := 0
	while office.player.global_position.z > -138.0 and pocket_wait < 50:
		await create_timer(0.1).timeout
		pocket_wait += 1
		if not office.player.is_moving and office.player.global_position.z > -138.0:
			office.player.target_destination = wedge_target
			office.player.is_moving = true
	_check(office.player.global_position.z <= -138.0, "Pig is not wedged between the pendulum gantry and the guardrail (z=%.2f)" % office.player.global_position.z)
	office.player.reset_at(checkpoint_3)
	runner.last_checkpoint = checkpoint_3

	# Watermelon peel: an ACTIVE dog must slip through real physics overlap
	# (dog layer 4 in the peel's mask) and stay stunned via stun().
	_check(course.watermelon_peel != null, "Course 4 has WatermelonPeel")
	var test_dog: ChaseDog = runner._dogs[0]
	var peel: Node3D = course.watermelon_peel
	test_dog.set_active(true)
	test_dog.global_position = peel.global_position + Vector3(0, 0.5, 0)
	for i in 4: await physics_frame
	_check(peel.is_slipping, "Watermelon peel detected the dog through its collision mask")
	_check(test_dog.phase == "stun", "Watermelon peel stunned the pursuing dog")
	await create_timer(0.5).timeout
	_check(test_dog.phase == "stun", "Peel stun lasts (driven by stun(), not a one-frame phase write)")
	test_dog.set_active(false)

	# 4.2 GO: the barrier opens and the real clock starts running
	var waited := 0
	while course.race_timer.state == "countdown" and waited < 60:
		await create_timer(0.1).timeout
		waited += 1
	_check(course.race_timer.state == "running", "Race clock runs after GO")
	_check(not is_instance_valid(course.start_barrier) or course.start_barrier.get_child(0).disabled, "Boom barrier opens on GO")
	await create_timer(0.3).timeout
	_check(course.race_timer.elapsed > 0.2, "Race clock accumulates real time")

	# 5. QTE struggle in course
	runner._on_dog_grapple(test_dog)
	await process_frame
	_check(office.in_qte and office.qte_panel.visible, "QTE panel triggered on course dog grapple")
	_check(office.player.control_mode == "qte", "Player locked into QTE mode")
	for i in office.QTE_TARGET_HITS:
		office._on_qte_tapped()
		await process_frame
	_check(not office.in_qte, "QTE resolved after rapid taps")
	_check(test_dog.phase == "stun", "Dog stunned after successful struggle")
	_check(office.player.control_mode == "chase", "Player restored to chase mode")

	# 6. QTE failure is slapstick knockback
	runner._on_dog_grapple(test_dog)
	await process_frame
	if office.in_qte:
		office._finish_qte(false)
		await process_frame
	_check(game.stage != "ending", "QTE failure does not end the run (non-lethal)")
	_check(office.player.is_knocked_back() or office.player.control_mode == "chase", "QTE failure knocks pig back and resumes")

	# 7. Reach exit via Racing Finish Gate -> real time on the banner, course complete,
	#    farm restored, drops at Final Iron Gate
	_check(course.finish_gate != null, "Course 4 has RacingFinishGate")
	var gate = course.finish_gate
	var timer = course.race_timer
	gate._on_finish_entered(office.player)
	_check(gate.is_finished and gate.banner_label.visible, "Finish gate dropped the banner")
	_check(timer.state == "stopped" and timer.final_time > 0.0, "Race clock froze at the line with a real time")
	_check(is_equal_approx(gate.final_time, timer.final_time), "Finish gate pulled the real race time from the clock")
	_check(gate.banner_label.text.contains(gate.format_time(gate.final_time)), "Banner shows the pig's actual time")
	_check(gate.record_broken and gate.banner_label.text.contains("RECORD BROKEN"), "A sub-35s run breaks the farm record")
	await process_frame
	_check(game.chase_completed.get("chase_final", false), "chase_final marked complete via course exit")
	_check(office.active_course == null, "Course scene unloaded")
	_check(office.farm.get_parent() == office, "Farm restored to tree")
	_check(game.stage == "showdown", "Progressed to showdown stage")
	_check(office.player.global_position.distance_to(Vector3(-75.5, 2.1, -223.5)) < 1.5, "Pig emerged on the gate court beside the farmer")
	_check(office.player.global_position.distance_to(L.GATE_FINAL) < 10.0, "Pig emerged within walking reach of the Final gate")
	_check(office.player.global_position.distance_to(Vector3(-48.0, 2.0, -197.0)) > 20.0, "Exit drop is far from the courtyard pipe entrance")
	_check(office.player.move_speed >= base_speed - 0.001, "No course slowdown leaks back into the farm")
	_check(is_equal_approx(office.player.move_speed, base_speed), "The star boost is settled at course exit, not carried into the farm")

	print("\nALL COURSE 04 JOURNEY TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
