extends SceneTree

# One-shot visual capture of the opening key-test scene (GUI engine only).
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_opening.gd

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
	var opening: Node = load("res://scenes/ui/opening_scene.tscn").instantiate()
	root.add_child(opening)
	await create_timer(0.8).timeout
	await _shot("menu")

	# Hold D so a keycap lights up and the pig takes a few steps.
	Input.action_press("move_right")
	await create_timer(0.6).timeout
	await _shot("keys")
	Input.action_release("move_right")
	quit(0)
