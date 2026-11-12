extends SceneTree

# One-shot visual capture of the unified bottom-right feedback zone:
# a playground gag notice (NoticeFeed card) on the HUD layer together with
# an achievement unlock popup above it (GUI engine only).
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_corner_notices.gd

func _initialize() -> void:
	call_deferred("_run")

func _shot(tag: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := "res://builds/zone_screens/notice_%s.png" % tag
	img.save_png(path)
	print("saved ", path)

func _run() -> void:
	var am: Node = root.get_node("AchievementManager")
	am.save_path = "user://achievements_notice_capture.json"
	am.reset_progress(true)

	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout
	office.start_game()
	await physics_frame

	# A gag notice: walk the pig into a nibble-grass tuft (world label + corner card).
	var farm: Node = office.farm
	var tufts: Array = farm.find_children("NibbleGrass*", "", true, false)
	if tufts.size() > 0:
		office.player.global_position = tufts[0].global_position + Vector3(0, 0.4, 0.4)
	# And an achievement popup at the same moment, to show they stack.
	am.unlock("grass_gourmet")
	await create_timer(0.6).timeout
	await _shot("corner")

	am.reset_progress(true)
	quit(0)
