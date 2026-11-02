extends SceneTree
## Visual review only: teleport for composition, never used as traversal proof.
const OUTPUT := "res://assets/art_references/environment_v2/"
const SHOTS := [
	["01_pigpen", Vector3(0, .1, 93), 16.0],
	["02_summit_lane", Vector3(0, .1, 78), 18.0],
	["03_ox_fields", Vector3(-17, .1, 53), 24.0],
	["04_shearing_shed", Vector3(-9.5, .1, 10), 17.0],
	["05_pond", Vector3(23, .1, 6), 22.0],
	["06_racecourse", Vector3(16, .1, -28), 26.0],
	["07_workyard", Vector3(-3, .1, -67), 26.0],
	["08_gateway", Vector3(0, .1, -86), 18.0],
	["09_cable_station", Vector3(0, .1, -101), 22.0],
]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(.6).timeout
	office.close_dialogue()
	office.cinematic = true
	office.player.set_control_mode("cinematic")
	office.hud.hide()
	for shot in SHOTS:
		office.player.global_position = shot[1]
		office.camera.snap_to_target()
		office.camera.size = shot[2]
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + shot[0] + ".png"))
		print("PASTORAL_SHOT %s draws=%d triangles=%d" % [shot[0], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	office.hud.show()
	office.player.global_position = Vector3(0, .1, 93)
	office.camera.size = 16
	office.camera.snap_to_target()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "10_gameplay.png"))
	quit(0)
