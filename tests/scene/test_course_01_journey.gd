extends SceneTree

const L = preload("res://scripts/levels/farm_layout.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_JOURNEY_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
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

	# 1. Secret Mario Pipe on the final downhill summit corner
	_check(office.farm.has_node("SecretMarioPipe"), "Farm has SecretMarioPipe branch")
	var pipe: Node3D = office.farm.get_node("SecretMarioPipe")
	_check(pipe.position.distance_to(Vector3(16.5, 24.0, 66.2)) < 0.5, "Secret pipe located at final summit corner")
	_check(pipe.has_node("PipeBody") and pipe.has_node("PipeTopArea"), "Pipe has solid body and top detection area")

	# Pig jumps onto pipe rim -> top area triggers stance
	office.farm._on_pipe_top_entered(office.player)
	_check(office.farm._player_on_pipe, "Pig standing on pipe rim detected")

	# Press S / trigger descent
	office.farm._trigger_pipe_enter()
	await create_timer(0.5).timeout
	_check(is_instance_valid(office.active_course), "Secret pipe S-key trigger loaded course_1")
	_check(office.farm.get_parent() == null, "Farm removed from tree during course")
	_check(office.player.control_mode == "explore", "Entrance is explore mode so ox dialogue works")
	var runner: CourseRunner = office.active_course.runner
	_check(runner.config.course_id == "course_1", "Course config wired")
	_check(runner._dogs.size() == 1, "Rubber-band dog spawned")

	# 2. Ox dialogue at entrance grants struggle skill
	game.complete_npc("ox")
	await process_frame
	_check(game.has_struggle_skill, "Struggle skill granted at course entrance")

	# 3. Cross course start trigger
	runner._on_start(office.player)
	await process_frame
	_check(runner.started, "Course started")
	_check(game.is_in_chase(), "Game entered chase_1 stage on course start")
	_check(office.player.control_mode == "chase", "Player in chase mode during course")
	for dog in runner._dogs:
		dog.set_active(false)

	# 4. Checkpoint registration
	runner._on_checkpoint(office.player, 1, Vector3(0, 0.6, -50))
	_check(runner.last_checkpoint == Vector3(0, 0.6, -50), "Checkpoint registered as respawn point")

	# 5. Watchdog: fall below kill_y -> respawn at checkpoint (non-lethal)
	office.player.global_position = Vector3(0, -50, -50)
	for i in 5: await physics_frame
	_check(runner.respawn_count >= 1, "Watchdog respawned pig after falling out of bounds")
	_check(office.player.global_position.y > -12.0, "Pig respawned above kill_y (not dead)")

	# 6. QTE struggle in course (skill gated)
	var test_dog: ChaseDog = runner._dogs[0]
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

	# 7. QTE failure is slapstick knockback, not death
	runner._on_dog_grapple(test_dog)
	await process_frame
	if office.in_qte:
		office._finish_qte(false)
		await process_frame
	_check(game.stage != "ending", "QTE failure does not end the run (non-lethal)")
	_check(office.player.is_knocked_back() or office.player.control_mode == "chase", "QTE failure knocks pig back and resumes")

	# 8. Reach exit -> course complete, farm restored
	runner._on_exit(office.player)
	await process_frame
	_check(game.chase_completed.get("chase_1", false), "chase_1 marked complete via course exit")
	_check(office.active_course == null, "Course scene unloaded")
	_check(office.farm.get_parent() == office, "Farm restored to tree")
	_check(game.stage == "exploring", "Returned to exploring stage")
	_check(office.player.global_position.distance_to(L.NPCS["ox"]) < 6.0, "Pig emerged at Ox's terrace next to Ox")

	print("\nALL COURSE JOURNEY TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)