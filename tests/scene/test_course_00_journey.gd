extends SceneTree

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

	# Serpentine structure: five floor legs, four camera turns, exit faces -Z.
	for leg in ["FloorL1", "FloorL2", "FloorL3", "FloorL4", "FloorL5"]:
		_check(course.has_node(leg), "Serpentine leg exists: " + leg)
	_check(absf(course.get_node("FloorL2").position.z - (-30.0)) < 0.1, "L2 is the eastbound belt corridor (z=-30)")
	for turn in ["CameraTurn1", "CameraTurn2", "CameraTurn3", "CameraTurn4"]:
		_check(course.has_node(turn), "Camera turn trigger exists: " + turn)
	var turn1: Area3D = course.get_node("CameraTurn1")
	var turn2: Area3D = course.get_node("CameraTurn2")
	_check(is_equal_approx(float(turn1.get_meta("turn_yaw_deg")), -90.0) and is_equal_approx(float(turn2.get_meta("turn_yaw_deg")), 0.0), "Turns alternate east/south (exit still faces -Z)")
	_check(course.get_node("CourseExit").position.z < course.get_node("FloorL5").position.z - 10.0, "The exit sits at the far end of the final -Z leg")

	# Pens: fog + cages + sleeping dog (no vision cones anywhere in the dream).
	_check(course.has_node("CagePenA") and course.has_node("CagePenD"), "Holding pens have weave blocks")
	_check(course.drowsy_fog != null and course.drowsy_fog.global_position.z > 12.0, "Drowsy fog starts behind the spawn")
	_check(course.sleeping_dog.is_in_group("chase_dogs") and course.sleeping_dog.get_node_or_null("VisionCone") == null, "Sleeping dog is a solid obstacle with NO vision cone")
	_check(course.has_node("PensDoorTrigger"), "The slam-door trigger ends the fog chase")

	# Belts: the corridor IS the road; hooks hang over 8 m legs.
	_check(course.belt_a != null and course.belt_d != null, "Processing floor is a conveyor escape (four belts)")
	_check(is_equal_approx(course.belt_a.global_position.y, -0.35), "Belt decks sit flush with the floor (no unjumpable lips)")
	_check(course.belt_a.belt_size.z >= 7.0 and course.belt_b.belt_size.z >= 7.0, "L2 lines span the eastbound corridor - no side bypass")
	_check(course.belt_c.belt_size.x >= 7.0, "L3 line spans the southbound corridor - no side bypass")
	_check(course.belt_a.belt_speed < course.belt_b.belt_speed, "The two lines escalate in speed")
	_check(course.belt_d.belt_direction.normalized().x > 0.9, "The final belt is a lateral transfer running toward the east wall")
	_check(course.belt_d.position.x + course.belt_d.belt_size.x * 0.5 < 34.0, "Transfer belt stops short of the wall (drift can never shove the pig through geometry)")
	_check(course.has_node("MeatHook1") and course.has_node("MeatHook4"), "Four meathooks hang over the belts")
	for hook_name in ["MeatHook1", "MeatHook2", "MeatHook3", "MeatHook4"]:
		var hook_node: Node3D = course.get_node(hook_name)
		_check(hook_node.gantry_half_width <= 3.7, hook_name + " spans the narrow 8 m corridor (hooks actually block)")
	_check(absf(course.get_node("MeatHook1").rotation.y) > 1.4, "L2 hooks are rotated to swing across the eastbound belt")
	_check(absf(course.get_node("MeatHook3").rotation.y) < 0.01, "L3 hook swings across the southbound belt")
	_check(course.has_node("FakeSunDoor") and course.exit_hint_label != null and not course.exit_hint_label.visible, "Painted-sun decoy door exists, real-exit hint hidden until baited")
	_check(absf(course.fake_sun_door.position.z - course.belt_d.position.z) < 1.5 and course.fake_sun_door.position.x > course.belt_d.position.x + course.belt_d.belt_size.x * 0.5 - 1.0, "The decoy door sits where the transfer belt flings you")
	_check(course.has_node("DockCrateA") and course.has_node("RollerDoorTop"), "Loading dock has crates and the roller door")

	# 进场对话节拍：入关先锁住猪讲剧情（出了什么事/在哪/干什么），快进放行
	# 后玩家迈步才触发起点 marker → course_started（出生点在 marker 之外）。
	_check(runner.beat_active() and runner.active_beat_id() == "course_0_intro", "Intro dialogue beat shows on nightmare entry")
	_check(office.player.control_mode == "cinematic", "Pig is locked while the intro beat talks")
	_check(not runner.started, "Beat plays before the start marker (course_started timing preserved)")
	runner.skip_beats()
	await create_timer(0.15).timeout
	_check(not runner.beat_active(), "Intro beat ends via the shared skip path")
	_check(office.player.control_mode != "cinematic", "Pig control restored after the beat")

	# Start + checkpoints + exit along the serpentine.
	runner._on_start(office.player)
	await process_frame
	_check(runner.started, "Course 0 started")
	_check(office.player.control_mode == "chase", "Player in chase mode inside the dream")
	_check(runner.checkpoints.size() == 3, "Three checkpoints registered along the serpentine")
	for dog in runner._dogs:
		dog.set_active(false)

	# The drowsy fog creeps forward until the door slams.
	var fog_z_start: float = course.drowsy_fog.global_position.z
	await create_timer(0.5).timeout
	_check(course.drowsy_fog.global_position.z < fog_z_start - 0.5, "Drowsy fog creeps forward (z %.2f -> %.2f)" % [fog_z_start, course.drowsy_fog.global_position.z])

	# Catching the pig is the standard non-lethal failure: back to the last
	# checkpoint, fog parked a lead behind it (the old forward-jolt pinned the
	# pig against cage faces).
	runner._on_checkpoint(office.player, 1, Vector3(0, 0.6, -18.0))
	office.player.global_position = Vector3(0, 0.6, 10.0)
	course.drowsy_fog.global_position = Vector3(0, 0, 10.6)
	course.drowsy_fog._touch_cooldown_left = 0.0
	course.drowsy_fog._on_body_entered(office.player)
	await physics_frame
	_check(not office.player.is_knocked_back() and office.player.global_position.distance_to(Vector3(0, 0.6, -18.0)) < 0.1, "Fog catch resets the pig to the last lit corner (non-lethal)")
	_check(course.drowsy_fog.global_position.z > -18.0 + 10.0, "Fog parks a lead behind the checkpoint after a catch (z=%.2f)" % course.drowsy_fog.global_position.z)

	# Slamming the door stops and dissolves the fog for good.
	course.drowsy_fog._touch_cooldown_left = 0.0
	course._on_pens_door_entered(office.player)
	_check(course.drowsy_fog.stopped and not course.drowsy_fog.chasing, "The slam-door stops the fog")
	await create_timer(1.2).timeout
	_check(not is_instance_valid(course.drowsy_fog), "The fog dissolves after the slam")

	# The L2 lines carry the pig back WEST (-X): the wade is the puzzle.
	office.player.reset_at(course.belt_b.global_position + Vector3(-2.0, 0.95, 0.0))
	office.player.velocity = Vector3.ZERO
	office.player.is_moving = false
	await create_timer(1.0).timeout
	_check(office.player.global_position.x < course.belt_b.global_position.x - 2.0, "Standing on an L2 line is carried back west (x=%.2f)" % office.player.global_position.x)
	# The lateral transfer belt drifts the pig east (+X) toward the decoy wall.
	office.player.reset_at(course.belt_d.global_position + Vector3(-1.5, 0.95, 0.0))
	office.player.velocity = Vector3.ZERO
	office.player.is_moving = false
	await create_timer(1.0).timeout
	_check(office.player.global_position.x > course.belt_d.global_position.x - 1.5 + 2.0, "The transfer belt drags the pig east toward the painted-sun wall (x=%.2f)" % office.player.global_position.x)

	# Watchdog: fall below kill_y -> respawn at checkpoint (non-lethal).
	runner._on_checkpoint(office.player, 3, Vector3(30, 0.6, -55.5))
	office.player.global_position = Vector3(30, -50, -55.5)
	for i in 5: await physics_frame
	_check(runner.respawn_count >= 1 and office.player.global_position.y > -12.0, "Watchdog respawned the dreaming pig (non-lethal)")

	# Dock trigger plays the butcher alarm once - now as a pause beat.
	var dock_area: Area3D = course.get_node("DockChaseTrigger")
	dock_area.body_entered.emit(office.player)
	_check(course._dock_chase_triggered, "Stepping onto the dock arms the butcher alarm")
	_check(runner.beat_active() and runner.active_beat_id() == "course_0_dock", "Butcher chase upgraded to a dialogue beat")
	runner.skip_beats()
	await create_timer(0.15).timeout
	_check(not runner.beat_active() and office.player.control_mode != "cinematic", "Dock beat releases the pig")

	# TUTORIAL: hurdles block walking (0.4..0.7 m) and are jump-clearable.
	for hurdle_name in ["TutorialHurdle1", "TutorialHurdle2"]:
		var hurdle: Node3D = course.get_node(hurdle_name)
		var hs: Vector3 = hurdle.scale * Vector3.ONE # hurdles are unit boxes
		_check(hurdle.has_node("JumpHint"), hurdle_name + " carries the jump prompt")
	# Walking into hurdle 1 is stopped (its collision is solid at 0.55 m).
	office.player.reset_at(Vector3(0, 0.6, -21.5))
	office.player.knockback_timer = 0.0
	office.player.interact_target = null
	office.player._click_route.clear()
	office.player.target_destination = Vector3(0, 0.6, -26.0)
	office.player.is_moving = true
	await create_timer(1.5).timeout
	_check(office.player.global_position.z > -24.2, "Hurdle 1 blocks walking (z=%.2f)" % office.player.global_position.z)

	# TUTORIAL: stepping on the first belt teaches the dash loan (stamina HUD).
	_check(not game.has_dash_skill, "No dash before the belt lesson")
	office.player.reset_at(course.belt_a.global_position + Vector3(0, 0.95, 0))
	await create_timer(0.8).timeout
	_check(game.has_dash_skill, "First belt contact wakes the dream dash (course-scoped loan)")
	_check(office.player.dash_enabled, "The taught dash actually enables the sprint")
	_check(game.npc_completed["horse"] == false, "The dream dash loans without touching the horse quest")

	# Reach the exit -> course completes, farm restored.
	runner._on_exit(office.player)
	await process_frame
	_check(office.active_course == null, "Course scene unloaded after the door")
	_check(office.farm.get_parent() == office, "Farm restored to tree (the dream ends)")

	print("\nALL COURSE 00 JOURNEY TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
