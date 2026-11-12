extends SceneTree

# Visual capture of the loan skill card over the farm level (GUI engine only).
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_skill_card.gd

func _initialize() -> void:
	call_deferred("_run")

func _shot(tag: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := "res://builds/zone_screens/skillcard_%s.png" % tag
	img.save_png(path)
	print("saved ", path)

func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.reset_run()
	# Skip the start menu so the shot shows the farm behind the card.
	gm.pending_boot = "farm"

	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout

	gm.grant_course_skills(["dash"])
	await create_timer(0.8).timeout
	await _shot("loan")

	gm.reset_run()
	quit(0)
