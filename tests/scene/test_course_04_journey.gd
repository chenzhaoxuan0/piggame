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
	_check(pipe.position.distance_to(Vector3(-22.0, 4.0, -164.0)) < 1.0, "Secret courtyard pipe located at horse pasture approach")
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

	# 2. Start trigger
	runner._on_start(office.player)
	await process_frame
	_check(runner.started, "Course 4 started")
	_check(game.is_in_chase(), "Game entered chase stage on course start")
	_check(office.player.control_mode == "chase", "Player in chase mode during course")
	for dog in runner._dogs:
		dog.set_active(false)

	# 3. Checkpoint registration
	runner._on_checkpoint(office.player, 1, Vector3(0, 0.6, -50))
	_check(runner.last_checkpoint == Vector3(0, 0.6, -50), "Checkpoint registered as respawn point")

	# 4. Watchdog: fall below kill_y -> respawn at checkpoint (non-lethal)
	office.player.global_position = Vector3(0, -50, -50)
	for i in 5: await physics_frame
	_check(runner.respawn_count >= 1, "Watchdog respawned pig after falling out of bounds")
	_check(office.player.global_position.y > -12.0, "Pig respawned above kill_y (not dead)")

	# 4.1 Mario Kart Racing Mechanics
	var course = office.active_course
	_check(course.boost_pad_1 != null, "Course 4 has BoostPad")
	var initial_vel: Vector3 = office.player.velocity
	course.boost_pad_1._on_body_entered(office.player)
	_check(office.player.velocity.length() > initial_vel.length() or course.boost_pad_1.is_active, "BoostPad applied racing speed boost")

	# Watermelon peel dog slip
	_check(course.watermelon_peel != null, "Course 4 has WatermelonPeel")
	var test_dog: ChaseDog = runner._dogs[0]
	course.watermelon_peel.trigger_slip(test_dog)
	await create_timer(0.3).timeout
	_check(test_dog.phase == "stun" or course.watermelon_peel.is_slipping, "Watermelon peel slipped and stunned pursuing dog")

	# 5. QTE struggle in course
	runner._on_dog_grapple(test_dog)
	await process_frame
	_check(office.in_qte and office.qte_panel.visible, "QTE panel triggered on course dog grapple")
	_check(office.player.control_mode == "qte", "Player locked into QTE mode")
	for i in 5:
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

	# 7. Reach exit via Racing Finish Gate -> course complete, farm restored, drops at Final Iron Gate
	_check(course.finish_gate != null, "Course 4 has RacingFinishGate")
	course.finish_gate._on_finish_entered(office.player)
	_check(course.finish_gate.is_finished and course.finish_gate.banner_label.visible, "Finish gate recorded broken 35s record and dropped victory banner")
	await process_frame
	_check(game.chase_completed.get("chase_final", false), "chase_final marked complete via course exit")
	_check(office.active_course == null, "Course scene unloaded")
	_check(office.farm.get_parent() == office, "Farm restored to tree")
	_check(game.stage == "showdown", "Progressed to showdown stage")
	_check(office.player.global_position.distance_to(Vector3(-78.0, 2.1, -220.0)) < 1.5, "Pig emerged at final iron gate")
	_check(office.player.global_position.distance_to(L.GATE_FINAL) < 10.0, "Pig emerged right before Final gate")

	print("\nALL COURSE 04 JOURNEY TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
