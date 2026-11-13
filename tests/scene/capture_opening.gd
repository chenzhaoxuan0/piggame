extends SceneTree

# One-shot visual capture of the boot flow (GUI engine only).
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_opening.gd
# Shot 1: the plain menu (the floating key-test pen is gone).
# Shot 2: the pigpen tutorial the "farm" boot now lands in - the pig roams its
#         real pen while the key-test strip lights up in the HUD.

func _initialize() -> void:
	call_deferred("_run")

func _shot(tag: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := "res://builds/zone_screens/opening_%s.png" % tag
	img.save_png(path)
	print("saved ", path)

func _run() -> void:
	var game: Node = root.get_node("GameManager")
	var opening: Node = load("res://scenes/ui/opening_scene.tscn").instantiate()
	root.add_child(opening)
	await create_timer(0.8).timeout
	await _shot("menu")
	opening.queue_free()
	await process_frame

	game.reset_run()
	game.pending_boot = "farm"
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout
	# Hold D so a keycap lights up and the pig takes a few steps in its pen.
	Input.action_press("move_right")
	await create_timer(0.6).timeout
	await _shot("tutorial")
	Input.action_release("move_right")
	quit(0)
