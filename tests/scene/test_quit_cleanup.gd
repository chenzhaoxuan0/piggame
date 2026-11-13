extends SceneTree

# Teardown hygiene: while a course is active the farm hub is parked outside the
# scene tree (office_level_1._enter_course). Tearing the level down mid-course
# (quit to desktop, return to main menu, restart) must free that parked subtree
# by hand - an orphaned farm leaks every physics body, mesh and texture it owns
# (thousands of RID-leak errors at exit and even a crash), because the engine's
# tree cleanup never reaches nodes that are no longer in the tree.
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/test_quit_cleanup.gd

var _failures := 0

func _check(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		_failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.reset_run()
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.5).timeout
	office.start_game()
	await process_frame

	# In the hub the farm lives in the tree: normal teardown owns it.
	_check(is_instance_valid(office.farm) and office.farm.is_inside_tree(),
		"Farm hub lives in the tree while roaming")

	office._select_level_from_settings("course_1")
	await create_timer(0.5).timeout
	_check(is_instance_valid(office.active_course), "Course 1 is active")
	var farm_ref: WeakRef = weakref(office.farm)
	var farm_in_tree: bool = office.farm.is_inside_tree()
	_check(farm_ref.get_ref() != null and not farm_in_tree,
		"Farm is parked outside the tree during a course")

	# Tear the level down mid-course - exactly what quitting or returning to
	# the main menu from inside a course does. The parked farm must die with it.
	office.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_check(farm_ref.get_ref() == null,
		"Parked farm is freed with the level (no orphaned world at exit)")

	gm.reset_run()
	print("QUIT_CLEANUP_TEST %s" % ("PASS" if _failures == 0 else "FAIL(%d)" % _failures))
	quit(1 if _failures > 0 else 0)
