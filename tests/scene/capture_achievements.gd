extends SceneTree

# One-shot visual capture of the achievement popup and the wall panel
# (GUI engine only). Uses a throwaway save file so real progress is untouched.
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_achievements.gd

func _initialize() -> void:
	call_deferred("_run")

func _shot(tag: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := "res://builds/zone_screens/achv_%s.png" % tag
	img.save_png(path)
	print("saved ", path)

func _run() -> void:
	var am: Node = root.get_node("AchievementManager")
	am.save_path = "user://achievements_capture.json"
	am.reset_progress(true)

	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout

	# Popup: unlock mid-farm, shoot while it is on screen.
	am.unlock("first_dodge")
	await create_timer(0.5).timeout
	await _shot("popup")

	# Wall: open from the start menu path with a couple more unlocks banked.
	am.unlock("red_pin")
	am.unlock("nightmare_survivor")
	office._open_achievements(true)
	await create_timer(0.3).timeout
	await _shot("wall")

	am.reset_progress(true)
	quit(0)
