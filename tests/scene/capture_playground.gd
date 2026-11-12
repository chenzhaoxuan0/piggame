extends SceneTree

# One-shot visual capture of the farm playground and the relocated field.
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_playground.gd

const SHOTS := [
	["field", Vector3(38, 32, 62), Vector3(22, 24, 44)],   # relocated furrows + ditch vs road
	["pitch", Vector3(46, 29, 36), Vector3(46, 24, 26)],   # cabbage pitch + goal + mailbox
	["scarecrow", Vector3(14, 28, 56), Vector3(14, 24, 48)],
	["log", Vector3(-52, 28, 90), Vector3(-55, 24.5, 95)],
	["hay", Vector3(-52, 28, 70), Vector3(-57.5, 23.6, 74.5)],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout
	office.start_game()
	await create_timer(0.2).timeout
	office.player.set_control_mode("cinematic")
	if is_instance_valid(office.hud):
		office.hud.visible = false
	for shot in SHOTS:
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.global_position = shot[1]
		cam.look_at(shot[2], Vector3.UP)
		cam.current = true # office's isometric camera would win otherwise
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://builds/zone_screens/play_%s.png" % shot[0])
		print("saved ", shot[0])
		cam.queue_free()
	office.queue_free()
	quit(0)
