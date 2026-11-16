extends SceneTree

# 马场模型重叠/闪烁 QA 近景：谷仓、饲料架、围栏门、跨栏标记墩、牧场边界、
# 赛道直道逐一近拍。GUI 引擎跑：
#   Godot_v4.3-stable_win64.exe --path . -s scripts/art/capture_ranch_closeups.gd

const SCENE := "res://scenes/levels/farm/farm_grounds.tscn"
const OUT_DIR := "res://builds/ranch_closeups"

const SHOTS := [
	{"tag": "barn", "pos": Vector3(74, 10.5, -126), "look": Vector3(81, 9.6, -135)},      # 马场谷仓正面
	{"tag": "rack", "pos": Vector3(72, 9.8, -124), "look": Vector3(77, 8.6, -127)},      # 饲料架近景
	{"tag": "gate", "pos": Vector3(24, 10.5, -87), "look": Vector3(18, 8.8, -91)},       # 马场围栏门
	{"tag": "hurdle", "pos": Vector3(50, 10.0, -117), "look": Vector3(52, 8.4, -123)},   # 跨栏 + 标记墩
	{"tag": "boundary_ne", "pos": Vector3(78, 12, -98), "look": Vector3(86, 9, -105)},   # 牧场东北边界围栏
	{"tag": "straight", "pos": Vector3(66, 11.5, -133), "look": Vector3(52, 9, -123)},   # 赛道直道回望
]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)
	var packed: PackedScene = load(SCENE)
	if packed == null:
		push_error("cannot load " + SCENE)
		quit(1)
		return
	var farm: Node3D = packed.instantiate()
	root.add_child(farm)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.72)
	sky_mat.sky_horizon_color = Color(0.78, 0.82, 0.80)
	sky_mat.ground_bottom_color = Color(0.3, 0.32, 0.3)
	sky_mat.ground_horizon_color = Color(0.78, 0.82, 0.80)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	world_env.environment = env
	root.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.98, 0.9)
	root.add_child(sun)
	await process_frame
	await process_frame
	await process_frame
	for shot in SHOTS:
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.global_position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out_abs, shot["tag"]]
		img.save_png(path)
		print("saved ", path)
		cam.queue_free()
	quit(0)
