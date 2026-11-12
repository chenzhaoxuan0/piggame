extends SceneTree

const L = preload("res://scripts/levels/farm_layout.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_03_JOURNEY_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
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

	# 1. Secret Woodland Pipe at Sheep Meadow
	_check(office.farm.has_node("SecretWoodlandPipe"), "Farm has SecretWoodlandPipe entrance")
	_check(office.farm.has_node("SecretWoodlandPipeExit"), "Farm has SecretWoodlandPipeExit at horse pasture entrance")
	var pipe: Node3D = office.farm.get_node("SecretWoodlandPipe")
	_check(pipe.position.distance_to(Vector3(12.0, 8.8, -85.0)) < 1.0, "Secret woodland entrance located at the woodland-chase end before Horse's gate")
	_check(pipe.has_node("PipeBody") and pipe.has_node("PipeTopArea"), "Pipe has solid body and top detection area")

	# Pig standing on pipe rim
	var top_area := pipe.get_node("PipeTopArea") as Area3D
	top_area.body_entered.emit(office.player)
	_check(office.farm._player_on_pipe, "Pig standing on woodland pipe rim detected")

	# Complete ox and sheep NPCs to unlock Struggle and Discern skills
	game.complete_npc("ox")
	game.complete_npc("sheep")
	await process_frame
	_check(game.has_struggle_skill, "Struggle skill granted by Ox")
	_check(game.has_discern_skill, "Discern skill granted by Sheep")

	# Trigger descent into course_3
	office.farm._trigger_pipe_enter("course_3", pipe)
	await create_timer(0.5).timeout
	_check(is_instance_valid(office.active_course), "Secret pipe trigger loaded course_3")
	_check(office.farm.get_parent() == null, "Farm removed from tree during course")
	var runner: CourseRunner = office.active_course.runner
	_check(runner.config.course_id == "course_3", "Course 3 config wired")
	_check(runner._dogs.size() == 1, "Rubber-band dog spawned")
	_check(office.active_course._discern_halo.visible, "Discern skill halo visible in Course 3")

	# 2. Start trigger
	runner._on_start(office.player)
	await process_frame
	_check(runner.started, "Course 3 started")
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

	# 4.1 Stealth & Souls Illusory Mechanics
	var course = office.active_course
	_check(course.stealth_box != null, "Course 3 has CardboardBoxProp")
	course.stealth_box.equip_box(office.player)
	_check(office.player.get_meta("in_stealth_box", false), "Player successfully equipped stealth cardboard box")

	# Vision cone stealth check
	_check(course.patrol_cone != null, "Course 3 has PatrolVisionCone")
	course.patrol_cone.target_player = office.player
	course.patrol_cone._scan_for_player()
	# Stationary in box should not alert
	_check(not course.patrol_cone.is_alert, "Stationary box successfully fooled patrol dog vision cone")

	# Box unequip drops it as a reusable prop instead of destroying it
	course.stealth_box.unequip_box()
	_check(not office.player.get_meta("in_stealth_box", false), "Box unequipped cleanly")
	_check(is_instance_valid(course.stealth_box) and not course.stealth_box.is_equipped, "Unequipped box survives as a pickup")
	course.stealth_box.equip_box(office.player)
	_check(office.player.get_meta("in_stealth_box", false), "Dropped box can be re-equipped")
	course.stealth_box.unequip_box()

	# Patrol guard is a real body: solid, group-tagged for the box dive, stunnable
	_check(course.patrol_dog.is_in_group("chase_dogs") and course.patrol_dog.has_method("stun"), "Patrol guard joins the dogs group with a stun() contract")
	_check(course.patrol_dog.get_node_or_null("GuardShape") != null, "Patrol guard has a solid collision body")
	course.patrol_dog.stun(0.2)
	_check(course.patrol_dog.is_stunned, "Cardboard-box-style stun() knocks the guard out")
	_check(course.patrol_cone.process_mode == Node.PROCESS_MODE_DISABLED, "Stunned guard's vision cone stops scanning")
	for i in 20: await physics_frame
	_check(not course.patrol_dog.is_stunned and course.patrol_cone.process_mode == Node.PROCESS_MODE_INHERIT, "Guard wakes up and resumes patrol")
	office.player.knockback_timer = 0.0
	office.player.reset_at(course.patrol_dog.global_position + Vector3(0.9, 0.6, 0))
	course.patrol_dog._on_nip_entered(office.player)
	_check(office.player.is_knocked_back(), "Touching an awake guard earns a slapstick nip")
	office.player.reset_at(Vector3(0, 0.6, -50))

	# The illusion maze fills the old empty corridor
	for wall_name in ["MazeWallA", "MazeWallB", "MazeWallCSolid", "MazeWallD", "MazeWallE", "MazeWallF"]:
		_check(course.has_node(wall_name), "Maze row exists: " + wall_name)
	_check(course.maze_illusory_wall != null, "Maze row C hides an illusory wall as the true passage")
	course.maze_illusory_wall.shatter()
	await create_timer(0.3).timeout
	_check(course.maze_illusory_wall == null or course.maze_illusory_wall.is_shattered, "Maze illusory wall shatters")
	_check(course.maze_chest_real != null and not course.maze_chest_real.is_mimic, "Real chest chamber hides behind the illusory row")
	_check(course.maze_chest_mimic != null and course.maze_chest_mimic.is_mimic, "Golden dead end is baited with a mimic")
	course.maze_chest_mimic._on_player_entered(office.player)
	_check(course.maze_chest_mimic.is_triggered, "Maze mimic bites the greedy pig")
	_check(runner.checkpoints.size() == 3, "Third checkpoint registered inside the maze")

	# Zigzag guard's patrol legs must not glide through solid maze rows (its own
	# body is excluded: the guard standing on its own route is expected).
	var zig_cone: Node3D = course.zigzag_dog.get_node("VisionCone")
	var pts: Array = zig_cone.patrol_points
	var blocked_legs := 0
	for i in pts.size():
		var from := pts[i] as Vector3
		var to := pts[(i + 1) % pts.size()] as Vector3
		var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.0, to + Vector3.UP * 1.0, 1)
		query.exclude = [course.zigzag_dog.get_rid()]
		if not course.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			blocked_legs += 1
	_check(blocked_legs == 0, "Zigzag guard's patrol legs stay inside the maze gaps (%d blocked)" % blocked_legs)

	# Mimic chest vs Real chest
	_check(course.mimic_chest_fake != null and course.mimic_chest_real != null, "Course 3 has Mimic chests")
	course.mimic_chest_fake._on_player_entered(office.player)
	_check(course.mimic_chest_fake.is_triggered, "Mimic chest triggered bite on pig")
	var chest_base: float = office.player.move_speed
	course.mimic_chest_real._on_player_entered(office.player)
	_check(course.mimic_chest_real.is_triggered, "Real chest opened to award sweet potato")
	_check(is_equal_approx(office.player.move_speed, chest_base * course.CHEST_SPEED_FACTOR), "Real chest grants its course-scoped speed boost")

	# Illusory wall shattering with Discern skill
	_check(course.illusory_wall != null, "Course 3 has IllusoryWall")
	course.illusory_wall.shatter()
	await create_timer(0.3).timeout
	_check(course.illusory_wall == null or course.illusory_wall.is_shattered, "Illusory wall shattered into hidden fairy passage")

	# 5. QTE struggle in course
	var test_dog: ChaseDog = runner._dogs[0]
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

	# 7. Reach exit -> course complete, farm restored, drops at Horse pasture entrance
	runner._on_exit(office.player)
	await process_frame
	_check(game.chase_completed.get("chase_3", false), "chase_3 marked complete via course exit")
	_check(office.active_course == null, "Course scene unloaded")
	_check(office.farm.get_parent() == office, "Farm restored to tree")
	_check(game.stage == "exploring", "Returned to exploring stage")
	_check(office.player.global_position.distance_to(Vector3(16.0, 8.1, -88.0)) < 1.5, "Pig emerged at Horse pasture entrance")
	_check(office.player.global_position.distance_to(L.GATE_HORSE) < 10.0, "Pig emerged near Horse gate")
	_check(is_equal_approx(office.player.move_speed, chest_base), "Chest boost is settled at course exit, not carried into the farm")

	print("\nALL COURSE 03 JOURNEY TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
