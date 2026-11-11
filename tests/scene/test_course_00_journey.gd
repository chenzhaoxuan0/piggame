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

	# Structure: fog-chased pens, plant gauntlet, dock crates, roller door exit.
	_check(course.has_node("CagePenA") and course.has_node("CagePenD"), "Holding pens have weave blocks")
	_check(course.drowsy_fog != null and course.drowsy_fog.global_position.z > 12.0, "Drowsy fog starts behind the spawn")
	_check(course.sleeping_dog.is_in_group("chase_dogs") and course.sleeping_dog.get_node_or_null("VisionCone") == null, "Sleeping dog is a solid obstacle with NO vision cone")
	_check(course.has_node("PensDoorTrigger"), "The slam-door trigger ends the fog chase")
	_check(course.belt_a != null and course.belt_d != null, "Processing floor is a conveyor escape (four belts)")
	_check(is_equal_approx(course.belt_a.global_position.y, -0.35), "Belt decks sit flush with the floor (no unjumpable lips)")
	_check(course.belt_a.belt_size.x >= 11.0 and course.belt_b.belt_size.x >= 11.0 and course.belt_c.belt_size.x >= 11.0, "Line belts span the full corridor - no middle bypass floor")
	_check(course.belt_a.belt_speed < course.belt_b.belt_speed and course.belt_b.belt_speed < course.belt_c.belt_speed, "The three lines escalate in speed")
	_check(course.belt_d.belt_direction.normalized().x > 0.9, "The final belt is a lateral transfer running toward the east wall")
	_check(course.belt_d.position.x + course.belt_d.belt_size.x * 0.5 < 4.5, "Transfer belt stops short of the wall (drift can never shove the pig through geometry)")
	_check(course.has_node("MeatHook1") and course.has_node("MeatHook4"), "Four meathooks hang over the belts")
	for hook_name in ["MeatHook1", "MeatHook2", "MeatHook3", "MeatHook4"]:
		var hook_node: Node3D = course.get_node(hook_name)
		_check(absf(hook_node.position.x) < 0.1 and hook_node.gantry_half_width > 5.9, hook_name + " hangs over the belt center with wall-flush posts")
	_check(course.has_node("FakeSunDoor") and course.exit_hint_label != null and not course.exit_hint_label.visible, "Painted-sun decoy door exists, real-exit hint hidden until baited")
	_check(absf(course.fake_sun_door.position.z - course.belt_d.position.z) < 1.5 and course.fake_sun_door.position.x > course.belt_d.position.x + course.belt_d.belt_size.x * 0.5, "The decoy door sits exactly where the transfer belt flings you")
	_check(course.has_node("DockCrateA") and course.has_node("RollerDoorTop"), "Loading dock has crates and the roller door")

	# The drowsy fog creeps forward until the door slams.
	var fog_z_start: float = course.drowsy_fog.global_position.z
	await create_timer(0.5).timeout
	_check(course.drowsy_fog.global_position.z < fog_z_start - 0.5, "Drowsy fog creeps forward (z %.2f -> %.2f)" % [fog_z_start, course.drowsy_fog.global_position.z])

	# Catching the pig jolts it onward (no respawn) and the fog falls back.
	office.player.reset_at(Vector3(0, 0.6, 10.0))
	office.player.knockback_timer = 0.0
	course.drowsy_fog.global_position = Vector3(0, 0, 10.6)
	course.drowsy_fog._touch_cooldown_left = 0.0
	course.drowsy_fog._on_body_entered(office.player)
	await physics_frame
	_check(office.player.is_knocked_back(), "Fog catch jolts the pig forward (non-lethal, no respawn)")
	var fog_z_before_retreat: float = course.drowsy_fog.global_position.z
	_check(fog_z_before_retreat > 10.6, "Fog retreated behind the pig after the catch (z=%.2f)" % fog_z_before_retreat)

	# Slamming the door stops and dissolves the fog for good.
	course.drowsy_fog._touch_cooldown_left = 0.0
	course._on_pens_door_entered(office.player)
	_check(course.drowsy_fog.stopped and not course.drowsy_fog.chasing, "The slam-door stops the fog")
	await create_timer(1.2).timeout
	_check(not is_instance_valid(course.drowsy_fog), "The fog dissolves after the slam")

	# The lines carry the pig back north (+Z): the wade is the puzzle.
	office.player.reset_at(course.belt_b.global_position + Vector3(0, 0.95, 2.0))
	office.player.velocity = Vector3.ZERO
	office.player.is_moving = false
	await create_timer(1.0).timeout
	_check(office.player.global_position.z > course.belt_b.global_position.z + 2.2, "Standing on a line belt is carried back north (z=%.2f)" % office.player.global_position.z)
	# The lateral transfer belt drifts the pig east (+X) toward the decoy wall.
	office.player.reset_at(course.belt_d.global_position + Vector3(-1.5, 0.95, 0.0))
	office.player.velocity = Vector3.ZERO
	office.player.is_moving = false
	await create_timer(1.0).timeout
	_check(office.player.global_position.x > course.belt_d.global_position.x - 1.5 + 2.0, "The transfer belt drags the pig east toward the painted-sun wall (x=%.2f)" % office.player.global_position.x)

	# Watchdog: fall below kill_y -> respawn at checkpoint (non-lethal).
	runner._on_checkpoint(office.player, 2, Vector3(0, 0.6, -52.5))
	office.player.global_position = Vector3(0, -50, -52.5)
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
