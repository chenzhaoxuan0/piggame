extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.60, 0.69, 0.75)
	sky_mat.sky_horizon_color = Color(0.84, 0.79, 0.75)
	sky_mat.ground_bottom_color = Color(0.30, 0.36, 0.26)
	sky_mat.ground_horizon_color = Color(0.85, 0.87, 0.78)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.82, 0.86, 0.91)
	env.environment.ambient_light_energy = 0.55
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -52, 0)
	light.light_color = Color(1, 0.94, 0.83)
	light.light_energy = 0.5
	world.add_child(light)
	var course := load("res://scenes/courses/course_01_ox_field.tscn").instantiate() as Node3D
	world.add_child(course)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.0
	world.add_child(camera)
	var shots := [
		["start_terrace", Vector3(0, 0.5, 4)],
		["launch_bumpers", Vector3(0, 0.5, -12)],
		["question_doordash", Vector3(0, 1.5, -23)],
		["fakebridge", Vector3(0, -1.5, -39)],
		["sweeper_pendulum", Vector3(0, 1.0, -54)],
		["hammer_bridge", Vector3(0, 1.0, -81)],
		["finish_arch", Vector3(0, 1.5, -95)],
	]
	await create_timer(0.5).timeout
	for shot in shots:
		var target: Vector3 = shot[1]
		camera.position = target + Vector3(9, 8, 11)
		camera.look_at(target)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/course01_%s.png" % shot[0])
	var meme := course.get_node("MemeLayer")
	meme._show_toast("恶犬扑空", "没技能？那就滚一圈再说", 5.0)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/course01_meme_ui.png")
	print("COURSE01_CAPTURE complete")
	quit()