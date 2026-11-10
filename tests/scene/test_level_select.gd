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
	var btn_c1: Button = office.settings_menu.find_child("BtnSelect_course_1", true, false)
	var btn_c2: Button = office.settings_menu.find_child("BtnSelect_course_2", true, false)
	var btn_c3: Button = office.settings_menu.find_child("BtnSelect_course_3", true, false)
	var btn_c4: Button = office.settings_menu.find_child("BtnSelect_course_4", true, false)
	var btn_farm: Button = office.settings_menu.find_child("BtnSelect_farm", true, false)

	_check(btn_c1 != null and btn_c2 != null and btn_c3 != null and btn_c4 != null and btn_farm != null, "All level select buttons exist in settings")

	# 2. Select Course 2 directly from settings
	btn_c2.pressed.emit()
	await process_frame
	_check(not office.in_settings, "Settings closed after level selection")
	_check(is_instance_valid(office.active_course), "Course 2 instantiated via Level Select")
	_check(office.active_course.runner.config.course_id == "course_2", "Active course is course_2 (Minecraft Voxel)")

	# 3. Switch from Course 2 directly to Course 3 from settings
	office._open_settings(false)
	await process_frame
	btn_c3 = office.settings_menu.find_child("BtnSelect_course_3", true, false)
	btn_c3.pressed.emit()
	await process_frame
	_check(is_instance_valid(office.active_course), "Course 3 loaded via Level Select")
	_check(office.active_course.runner.config.course_id == "course_3", "Active course is course_3 (Stealth)")

	# Verify Cardboard Box equip and unequip
	var box: Node3D = office.active_course.stealth_box
	_check(box != null, "Course 3 has stealth_box")
	box.equip_box(office.player)
	_check(office.player.get_meta("in_stealth_box", false), "Cardboard box equipped onto pig")
	box.unequip_box()
	_check(not office.player.get_meta("in_stealth_box", false), "Cardboard box unequipped cleanly via unequip_box()")

	# 4. Switch from Course 3 to Course 4 from settings
	office._open_settings(false)
	await process_frame
	btn_c4 = office.settings_menu.find_child("BtnSelect_course_4", true, false)
	btn_c4.pressed.emit()
	await process_frame
	_check(is_instance_valid(office.active_course), "Course 4 loaded via Level Select")
	_check(office.active_course.runner.config.course_id == "course_4", "Active course is course_4 (Racing)")

	# 5. Return to Farm world
	office._open_settings(false)
	await process_frame
	btn_farm = office.settings_menu.find_child("BtnSelect_farm", true, false)
	btn_farm.pressed.emit()
	await process_frame
	_check(office.active_course == null, "Course unloaded when returning to farm")
	_check(office.farm.get_parent() == office, "Main farm world restored")

	print("\nALL LEVEL SELECT TESTS COMPLETED: %d failures" % failures)
	quit(0 if failures == 0 else 1)
