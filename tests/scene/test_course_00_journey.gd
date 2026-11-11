extends SceneTree

const L = preload("res://scripts/levels/farm_layout.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_00_JOURNEY_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
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

	# Enter the nightmare directly (the boot flow wiring lands separately).
	office.current_chase_id = "intro"
	office._enter_course("course_0")
	await create_timer(0.5).timeout
	_check(is_instance_valid(office.active_course), "Nightmare course loaded")
	_check(office.farm.get_parent() == null, "Farm removed from tree during the dream")
	var course = office.active_course
	var runner: CourseRunner = course.runner
	_check(runner.config.course_id == "course_0", "Course 0 config wired")
	_check(runner.config.title.contains("噩梦"), "Course 0 is the nightmare")
	_check(runner._dogs.size() == 1, "One rubber-band chaser spawned")
	_check(runner._dogs[0].visual_asset_id == "CHAR_07", "The chaser dresses as the farmer (CHAR_07)")

	# The dream pig has NOTHING: no skill loans, no QTE - slapstick only.
	_check(not game.has_struggle_skill and not game.has_discern_skill and not game.has_dash_skill, "Course 0 grants no skills (pure slapstick tutorial)")
	_check(not game.npc_completed["ox"] and not game.npc_completed["sheep"] and not game.npc_completed["horse"], "Course 0 leaves the farm story untouched")

	# Structure: pens cover, plant gauntlet, dock crates, roller door exit.
	_check(course.has_node("CagePenA") and course.has_node("CagePenD"), "Holding pins have cage cover")
	_check(course.guard_dog_1.is_in_group("chase_dogs") and course.guard_dog_1.has_node("GuardShape"), "Pen guard 1 is a solid dog")
	_check(course.guard_dog_2.is_in_group("chase_dogs") and course.guard_dog_2.has_node("GuardShape"), "Pen guard 2 is a solid dog")
	_check(course.main_belt != null, "Processing floor has the conveyor")
	_check(is_equal_approx(course.main_belt.global_position.y, -0.35), "Belt deck sits flush with the floor (no unjumpable lip)")
	_check(course.has_node("MeatHook1") and course.has_node("MeatHook3"), "Hook lane has three swinging meathooks")
	_check(course.has_node("FakeSunDoor") and course.exit_hint_label != null and not course.exit_hint_label.visible, "Painted-sun decoy door exists, real-exit hint hidden until baited")
	_check(course.has_node("DockCrateA") and course.has_node("RollerDoorTop"), "Loading dock has crates and the roller door")

	# Patrol legs must not glide through cages or walls (guard body excluded).
	await physics_frame
	var blocked_legs := 0
	for guard in [course.guard_dog_1, course.guard_dog_2]:
		var cone: Node3D = guard.get_node("VisionCone")
		var pts: Array = cone.patrol_points
		for i in pts.size():
			var from := pts[i] as Vector3
			var to := pts[(i + 1) % pts.size()] as Vector3
			var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.0, to + Vector3.UP * 1.0, 1)
			query.exclude = [guard.get_rid(), course.guard_dog_1.get_rid(), course.guard_dog_2.get_rid()]
			if not course.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				blocked_legs += 1
	_check(blocked_legs == 0, "Pen guards' patrol legs stay inside the corridor (%d blocked)" % blocked_legs)

	# Start + checkpoints + exit are registered along one -Z line.
	runner._on_start(office.player)
	await process_frame
	_check(runner.started, "Course 0 started")
	_check(office.player.control_mode == "chase", "Player in chase mode inside the dream")
	_check(runner.checkpoints.size() == 2, "Two checkpoints registered")
	for dog in runner._dogs:
		dog.set_active(false)

	# Vision cones: an exposed stationary pig is spotted; the same pig behind a
	# cage is not (cover occlusion works in the dream too). The cone is paused
	# and aimed deterministically - its patrol facing varies frame to frame.
	var cone1: Node3D = course.guard_dog_1.get_node("VisionCone")
	cone1.target_player = office.player
	cone1.process_mode = Node.PROCESS_MODE_DISABLED
	cone1.global_position = Vector3(0, 0, 0)
	cone1.global_rotation = Vector3.ZERO # Facing -Z, straight down the corridor
	office.player.reset_at(Vector3(0, 0.6, -4.0))
	await physics_frame
	cone1._scan_for_player()
	_check(cone1.is_alert, "Exposed pig inside the cone raises the alarm")
	# Cover case: cone north of cage C, pig straight behind it.
	cone1.global_position = Vector3(-4.6, 0, -6.0)
	cone1.global_rotation = Vector3.ZERO
	office.player.reset_at(Vector3(-4.6, 0.6, -10.0))
	await physics_frame
	cone1._scan_for_player()
	_check(not cone1.is_alert, "Pig behind a cage is hidden from the cone (real cover)")
	cone1.process_mode = Node.PROCESS_MODE_INHERIT

	# The belt carries the pig back north (+Z): the wade is the puzzle.
	office.player.reset_at(course.main_belt.global_position + Vector3(0, 0.95, 2.0))
	office.player.velocity = Vector3.ZERO
	office.player.is_moving = false
	await create_timer(1.0).timeout
	_check(office.player.global_position.z > course.main_belt.global_position.z + 2.2, "Standing on the belt is carried back north (z=%.2f)" % office.player.global_position.z)

	# Watchdog: fall below kill_y -> respawn at checkpoint (non-lethal).
	runner._on_checkpoint(office.player, 2, Vector3(0, 0.6, -56))
	office.player.global_position = Vector3(0, -50, -56)
	for i in 5: await physics_frame
	_check(runner.respawn_count >= 1 and office.player.global_position.y > -12.0, "Watchdog respawned the dreaming pig (non-lethal)")

	# Dock trigger plays the butcher alarm once.
	var dock_area: Area3D = course.get_node("DockChaseTrigger")
	dock_area.body_entered.emit(office.player)
	_check(course._dock_chase_triggered, "Stepping onto the dock arms the butcher alarm")

	# Reach the exit -> course completes, farm restored.
	runner._on_exit(office.player)
	await process_frame
	_check(office.active_course == null, "Course scene unloaded after the door")
	_check(office.farm.get_parent() == office, "Farm restored to tree (the dream ends)")

	print("\nALL COURSE 00 JOURNEY TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
