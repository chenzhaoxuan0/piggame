extends SceneTree

# One-shot visual capture of the rocky crossings and the cabbage field.
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_cabbage_crossings.gd

const SHOTS := [
	["crossing_a_road", Vector3(10.2, 26.5, 64.0), Vector3(10.2, 24.0, 56.0)],   # gap in the roadside fence + stepping stone, from the road
	["crossing_a_field", Vector3(6.0, 26.0, 50.0), Vector3(11.0, 24.2, 58.0)],  # the same gap seen from inside the ox terrace
	["crossing_b_road", Vector3(24.0, 26.5, 64.0), Vector3(22.9, 24.0, 55.0)],   # broken fence section near the gate dip
	["cabbage_field", Vector3(52.0, 28.5, 38.0), Vector3(58.5, 24.3, 26.0)],     # planted cabbages right of the goal
	["field_to_goal", Vector3(62.0, 27.0, 32.0), Vector3(46.0, 24.4, 24.6)],     # kick lane: beds -> goal mouth
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
		img.save_png("res://builds/zone_screens/cabbage_%s.png" % shot[0])
		print("saved ", shot[0])
		cam.queue_free()
	office.queue_free()
	quit(0)
