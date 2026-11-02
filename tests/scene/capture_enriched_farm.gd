extends SceneTree
## Normal camera survey, including every road segment and all story districts.
const L=preload("res://scripts/levels/farm_layout.gd")
const OUTPUT="res://assets/art_references/enriched_farm/"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var office: Node=load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(.6).timeout
	office.close_dialogue();office.cinematic=true
	office.player.set_control_mode("cinematic")
	office.farm.set_pigpen_open(true)
	var shots: Array=[
		["01_pigpen",Vector3(0,32.1,100)],
		["02_fields",Vector3(41,24.1,39)],
		["03_orchard",Vector3(73,24.1,44)],
		["04_sheep",Vector3(-52,16.1,-41.5)],
		["05_pond",Vector3(-20,16.1,-40)],
		["06_track",Vector3(48,8.1,-121)],
		["07_gate",Vector3(-82,2.1,-225)],
		["08_station",Vector3(-12,.1,-276)],
		["09_summit_edge",Vector3(10,32.1,107)],
		["10_ox_edge",Vector3(92,24.1,40)],
		["11_sheep_edge",Vector3(-75,16.1,-36)],
		["12_track_edge",Vector3(83,8.1,-120)],
	]
	for id in L.ROUTES:
		var route:=L.path(id)
		for i in route.size()-1:
			shots.append(["route_%s_%02d" % [id,i],route[i].lerp(route[i+1],.5)+Vector3.UP*.1])
	for shot in shots:
		office.player.global_position=shot[1]
		office.camera.snap_to_target()
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+shot[0]+".png"))
		print("ENRICHED_SHOT %s draws=%d triangles=%d" % [shot[0],RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()
