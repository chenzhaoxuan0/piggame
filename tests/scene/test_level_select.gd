extends SceneTree

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("LEVEL_SELECT_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await process_frame

	# 1. Open settings from gameplay
	office._open_settings(false)
	await process_frame
	_check(office.in_settings and office.settings_menu.visible, "Settings menu opened")

	# Check presence of Level Select buttons
	var btn_c0: Button = office.settings_menu.find_child("BtnSelect_course_0", true, false)
	var btn_c1: Button = office.settings_menu.find_child("BtnSelect_course_1", true, false)
	var btn_c2: Button = office.settings_menu.find_child("BtnSelect_course_2", true, false)
	var btn_c3: Button = office.settings_menu.find_child("BtnSelect_course_3", true, false)
	var btn_c4: Button = office.settings_menu.find_child("BtnSelect_course_4", true, false)
	var btn_farm: Button = office.settings_menu.find_child("BtnSelect_farm", true, false)

	_check(btn_c0 != null and btn_c1 != null and btn_c2 != null and btn_c3 != null and btn_c4 != null and btn_farm != null, "All level select buttons exist in settings (prologue included)")

	# Hub atmosphere baseline: courses swap it for their zone look and must restore it.
	var hub_world: WorldEnvironment = office.get_node("WorldEnvironment")
	var hub_environment: Environment = hub_world.environment
	var sun: DirectionalLight3D = office.get_node("Sun")
	var hub_sun_energy: float = sun.light_energy
	# 0. The nightmare prologue is replayable from level select
	btn_c0.pressed.emit()
	await process_frame
	_check(office.active_course != null and office.active_course.runner.config.course_id == "course_0", "Prologue nightmare replayable via Level Select")
	_check(game.stage == "prologue", "Entering the dream leaves the run stage untouched")
	btn_c0.pressed.emit()
	await process_frame
	_check(game.stage == "prologue" and not game.chase_completed.get("chase_1", false), "Re-entering the dream still books no chase progress")


	# 2. Select Course 2 directly from settings
	btn_c2.pressed.emit()
	await process_frame
	_check(not office.in_settings, "Settings closed after level selection")
	_check(is_instance_valid(office.active_course), "Course 2 instantiated via Level Select")
	_check(office.active_course.runner.config.course_id == "course_2", "Active course is course_2 (Minecraft Voxel)")
	_check(game.has_struggle_skill, "Course 2 lends the struggle skill")
	_check(not game.npc_completed["ox"], "Course 2 skill loan leaves the Ox quest unfinished")
	_check(hub_world.environment != hub_environment and hub_world.environment.fog_enabled, "Course 2 swaps in its own foggy zone environment")

	# 3. Switch from Course 2 directly to Course 3 from settings
	office._open_settings(false)
	await process_frame
	btn_c3 = office.settings_menu.find_child("BtnSelect_course_3", true, false)
	btn_c3.pressed.emit()
	await process_frame
	_check(is_instance_valid(office.active_course), "Course 3 loaded via Level Select")
	_check(office.active_course.runner.config.course_id == "course_3", "Active course is course_3 (Plunger gauntlet)")
	_check(game.has_discern_skill and game.has_struggle_skill, "Course 3 lends discern and struggle")
	_check(not game.npc_completed["sheep"] and not game.npc_completed["ox"], "Course 3 skill loans leave companion quests unfinished")
	_check(hub_world.environment.fog_density > 0.03, "Course 3 woodland is properly misty")

	# 2026-11-15 redesign: the stealth loop is gone - the plunger armory is the
	# course's combat identity now (no box, no vision cones, five pocket rounds).
	_check(office.active_course.get_node_or_null("StealthCardboardBox") == null, "Course 3 retired the stealth cardboard box")
	_check(office.active_course.patrol_dog.get_node_or_null("VisionCone") == null, "Course 3 guards no longer carry vision cones")
	_check(office.active_course.plunger_launcher.ammo == 5, "Course 3 opens the plunger armory with five rounds")

	# 4. Switch from Course 3 to Course 4 from settings
	office._open_settings(false)
	await process_frame
	btn_c4 = office.settings_menu.find_child("BtnSelect_course_4", true, false)
	btn_c4.pressed.emit()
	await process_frame
	_check(is_instance_valid(office.active_course), "Course 4 loaded via Level Select")
	_check(office.active_course.runner.config.course_id == "course_4", "Active course is course_4 (Racing)")
	_check(game.has_dash_skill and not game.has_discern_skill, "Course 4 lends dash and drops the previous course's discern loan")
	_check(not game.npc_completed["horse"], "Course 4 skill loan leaves the Horse quest unfinished")
	_check(office.player.dash_enabled, "Course 4 dash loan actually enables the sprint")
	_check(sun.light_energy < hub_sun_energy, "Course 4 neon night dims the hub sun")

	# 5. Return to Farm world
	office._open_settings(false)
	await process_frame
	btn_farm = office.settings_menu.find_child("BtnSelect_farm", true, false)
	btn_farm.pressed.emit()
	await process_frame
	_check(office.active_course == null, "Course unloaded when returning to farm")
	_check(office.farm.get_parent() == office, "Main farm world restored")
	_check(not game.has_struggle_skill and not game.has_discern_skill and not game.has_dash_skill, "Skill loans cleared on course exit")
	_check(not office.player.dash_enabled, "Borrowed sprint is switched off again on course exit")
	_check(hub_world.environment == hub_environment, "Hub environment restored after leaving the courses")
	_check(is_equal_approx(sun.light_energy, hub_sun_energy), "Hub sun restored after leaving the courses")

	# --- 2026-11-15 playtest #16: farm return lands on the LAST TRAIL CHECKPOINT
	# (not the old fixed ox-field pad), and R self-rescues the same way.
	office.player.global_position = Vector3(-46, 16.1, -60) # sheep meadow, on the journey line
	for i in 40: await physics_frame # let farm._checkpoint trail the walk
	var cp: Vector3 = office.farm._checkpoint
	_check(office.farm._checkpoint != Vector3.ZERO, "Trail checkpoint is tracking the walk")
	office._select_level_from_settings("farm")
	await process_frame
	_check(office.player.global_position.distance_to(cp) < 1.0,
		"Farm return lands on the last checkpoint, not a fixed pad")
	office.player.global_position = Vector3(-70, 16.1, -30) # walkable but well off the trail line
	for i in 10: await physics_frame
	var r_ev := InputEventAction.new()
	r_ev.action = "action_respawn"
	r_ev.pressed = true
	Input.parse_input_event(r_ev)
	await create_timer(0.25).timeout
	_check(office.player.global_position.distance_to(cp) < 1.5,
		"R returns a stuck pig to the last checkpoint")

	print("\nALL LEVEL SELECT TESTS COMPLETED: %d failures" % failures)
	quit(0 if failures == 0 else 1)
