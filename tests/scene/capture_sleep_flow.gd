extends SceneTree

# One-shot visual capture of the NEW start-game funnel (GUI engine only):
# pen -> 开始游戏 -> brain quiz -> 不 -> sleep beat -> course_0 entry beat.
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_sleep_flow.gd

func _initialize() -> void:
	call_deferred("_run")

func _shot(tag: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := "res://builds/zone_screens/sleepflow_%s.png" % tag
	img.save_png(path)
	print("saved ", path)

func _find_btn(node: Node, text: String) -> Button:
	if node == null:
		return null
	for b in node.find_children("*", "Button", true, false):
		if b.text.strip_edges().begins_with(text):
			return b
	return null

func _run() -> void:
	var game: Node = root.get_node("GameManager")
	game.reset_run()
	game.pending_boot = "farm"
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout
	await _shot("1_pen")

	var start_btn := _find_btn(office.find_child("TitleCard", true, false), "▶  开始游戏")
	if start_btn == null:
		print("FAIL: no start button")
		quit(1)
		return
	start_btn.pressed.emit()
	await create_timer(0.3).timeout
	await _shot("2_quiz")

	var no_btn := _find_btn(office.find_child("BrainHoleQuiz", true, false), "不")
	if no_btn == null:
		print("FAIL: no quiz")
		quit(1)
		return
	no_btn.pressed.emit()
	await create_timer(1.4).timeout
	await _shot("3_sleeping")

	office.fast_forward_sleep()
	await create_timer(1.6).timeout
	await _shot("4_dream_entry")
	print("active_course=", office.active_course.runner.config.course_id
		if is_instance_valid(office.active_course) else "none")
	if is_instance_valid(office.active_course):
		office.active_course.queue_free()
	office.queue_free()
	await process_frame
	quit(0)
