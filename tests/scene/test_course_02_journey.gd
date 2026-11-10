extends SceneTree

const L = preload("res://scripts/levels/farm_layout.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_02_JOURNEY_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
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

	# 1. Secret Creek Pipe at Ox Terrace
	_check(office.farm.has_node("SecretCreekPipe"), "Farm has SecretCreekPipe entrance")
	_check(office.farm.has_node("SecretCreekPipeExit"), "Farm has SecretCreekPipeExit at sheep meadow entrance")
	var pipe: Node3D = office.farm.get_node("SecretCreekPipe")
	_check(pipe.position.distance_to(Vector3(70.0, 24.0, 24.0)) < 1.0, "Secret creek pipe located at Ox terrace")
	_check(pipe.has_node("PipeBody") and pipe.has_node("PipeTopArea"), "Pipe has solid body and top detection area")

	# Pig standing on pipe rim
	var top_area := pipe.get_node("PipeTopArea") as Area3D
	top_area.body_entered.emit(office.player)
	_check(office.farm._player_on_pipe, "Pig standing on creek pipe rim detected")

	# Trigger descent into course_2
	office.farm._trigger_pipe_enter("course_2", pipe)
	await create_timer(0.5).timeout
	_check(is_instance_valid(office.active_course), "Secret pipe trigger loaded course_2")
	_check(office.farm.get_parent() == null, "Farm removed from tree during course")
	var runner: CourseRunner = office.active_course.runner
	_check(runner.config.course_id == "course_2", "Course 2 config wired")
	_check(runner._dogs.size() == 1, "Rubber-band dog spawned")

	# Grant Ox struggle skill
	game.complete_npc("ox")
	await process_frame
	_check(game.has_struggle_skill, "Struggle skill active")

	# 2. Start trigger
	runner._on_start(office.player)
	await process_frame
	_check(runner.started, "Course 2 started")
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

	# 4.1 Minecraft Voxel Mechanics
	var course = office.active_course
	_check(course.water_stream != null, "Course 2 has VoxelWaterStream")
	_check(course.dirt_block_1 != null and course.dirt_block_2 != null, "Course 2 has pushable dirt blocks")
	# Push dirt block 1 into stream
	course.dirt_block_1.push(Vector3(0, 0, -2.0))
	await create_timer(0.3).timeout
	course.water_stream._handle_block_drop(course.dirt_block_1)
	await create_timer(0.3).timeout
	_check(course.dirt_block_1.has_bridged, "Dirt block bridged the voxel water stream")

	# Sand block burying dog
	_check(course.sand_block != null and course.canyon_dog != null, "Course 2 has sand block and canyon dog")
	course.sand_block.push(Vector3(0, 0, -2.0))
	await create_timer(0.3).timeout
	course._bury_dog(course.canyon_dog.get_node("DogLabel"), course.canyon_dog.get_node("DogMesh"))
	_check(course.canyon_dog.get_node("DogLabel").text.contains("活埋"), "Sand block buried and stunned canyon dog")

	# TNT and Obsidian wall
	_check(course.obsidian_wall != null and course.pressure_plate != null, "Course 2 has obsidian wall and pressure plate")
	course.pressure_plate._on_body_entered(course.tnt_block)
	await create_timer(0.6).timeout
	_check(course.obsidian_wall == null or course.obsidian_wall.is_demolished, "TNT on pressure plate demolished obsidian wall")

	# 5. QTE struggle in course
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

	# 6. QTE failure is slapstick knockback
	runner._on_dog_grapple(test_dog)
	await process_frame
	if office.in_qte:
		office._finish_qte(false)
		await process_frame
	_check(game.stage != "ending", "QTE failure does not end the run (non-lethal)")
	_check(office.player.is_knocked_back() or office.player.control_mode == "chase", "QTE failure knocks pig back and resumes")

	# 7. Reach exit -> course complete, farm restored, drops at Sheep meadow entrance
	runner._on_exit(office.player)
	await process_frame
	_check(game.chase_completed.get("chase_2", false), "chase_2 marked complete via course exit")
	_check(office.active_course == null, "Course scene unloaded")
	_check(office.farm.get_parent() == office, "Farm restored to tree")
	_check(game.stage == "exploring", "Returned to exploring stage")
	_check(office.player.global_position.distance_to(Vector3(-38.0, 16.1, -20.0)) < 1.5, "Pig emerged at Sheep meadow entrance")
	_check(office.player.global_position.distance_to(L.GATE_SHEEP) < 10.0, "Pig emerged near Sheep gate")

	print("\nALL COURSE 02 JOURNEY TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
