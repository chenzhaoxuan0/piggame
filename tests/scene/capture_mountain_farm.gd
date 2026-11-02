extends SceneTree
## Visual composition only. Traversal is covered by test_full_journey.gd.
const OUTPUT := "res://assets/art_references/mountain_farm/"
const SHOTS := [
	["01_normal_pigpen",Vector3(0,32.1,100),8.0],
	["02_normal_switchback",Vector3(-26,27.7,82),8.0],
	["03_normal_fields",Vector3(43,24.1,38),8.0],
	["04_normal_creek",Vector3(44,21.7,2.7),8.0],
	["05_normal_sheep",Vector3(-49,16.1,-41.5),8.0],
	["06_normal_track",Vector3(40,8.1,-109),8.0],
	["07_normal_chase",Vector3(-70,3.1,-185),8.0],
	["08_normal_escape",Vector3(-62,1.1,-251),8.0],
	["09_test_track_overview",Vector3(40,8.1,-120),65.0],
	["10_test_mountain_overview",Vector3(0,10,-80),300.0],
	["11_test_high_view",Vector3(0,32.1,100),16.0],
]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var office: Node=load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(.6).timeout
	office.close_dialogue()
	office.cinematic=true
	office.player.set_control_mode("cinematic")
	office.farm.set_pigpen_open(true)
	for shot in SHOTS:
		office.camera.far=1200
		office.hud.visible = shot[2]<=16.0
		office.player.global_position=shot[1]
		office.camera.camera_offset=Vector3(5,5.25,7) if shot[2]==8.0 else (Vector3(10,10.5,14) if shot[2]==16.0 else Vector3(100,150,160))
		office.camera.size=shot[2]
		office.camera.snap_to_target()
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+shot[0]+".png"))
		print("MOUNTAIN_SHOT %s draws=%d triangles=%d" % [shot[0],RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()
