extends SceneTree
var world: Node3D
var camera: Camera3D
var players: Array[AnimationPlayer] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	world = Node3D.new()
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
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21
	world.add_child(camera)
	camera.position = Vector3(9, 12, -17)
	camera.look_at(Vector3(9, 0.5, 2.5))
	var ids: Array[String] = []
	for i in range(1, 8): ids.append("CHAR_%02d" % i)
	for i in range(1, 8): ids.append("PROP_%02d" % i)
	for i in ids.size():
		var id := ids[i]
		var path := "res://assets/models/aholo/%s/%s_game.glb" % [id, id]
		var model := load(path).instantiate() as Node3D
		world.add_child(model)
		model.position = Vector3((i % 7) * 3.2, 0, 5.5 if i >= 7 else 0)
		if id == "PROP_01": model.scale *= 0.55
		if id == "PROP_02": model.scale *= 0.55
		if id in ["PROP_03", "PROP_05", "PROP_07"]: model.scale *= 2
		for animation_player in model.find_children("*", "AnimationPlayer", true, false):
			players.append(animation_player)
			print(id, " clips=", animation_player.get_animation_list())
			if animation_player.has_animation("walk"):
				animation_player.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
				animation_player.play("walk")
		var label := Label3D.new()
		label.text = id
		label.font_size = 48
		label.pixel_size = 0.008
		label.modulate = Color("263c31")
		label.outline_size = 0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = model.position + Vector3(0, -0.1, -1.65)
		world.add_child(label)
	for frame in 3:
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/model_gallery_%d.png" % frame)
	for index in [0, 3, 4, 6]:
		var center := Vector3(index * 3.2, 0.85, 0)
		camera.size = 3.0
		camera.position = center + Vector3(3.2, 1.8, -4)
		camera.look_at(center)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/character_close_%d.png" % index)
	print("MODEL_GALLERY complete")
	quit()
