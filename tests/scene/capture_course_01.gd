extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("e3e8df")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.75
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	light.light_energy = 0.8
	world.add_child(light)
	var course := load("res://scenes/courses/course_01_ox_field.tscn").instantiate() as Node3D
	world.add_child(course)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.0
	world.add_child(camera)
	var shots := [
		["launch_bumpers", Vector3(0, 0.5, -12)],
		["question_doordash", Vector3(0, 1.5, -23)],
		["fakebridge", Vector3(0, -1.5, -40)],
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
	print("COURSE01_CAPTURE complete")
	quit()