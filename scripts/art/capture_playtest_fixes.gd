extends SceneTree

# 2026-11-16 三笔实机修复的验收近景：路面嫩香草（Lux3D 模型 + 金黄调色）、
# 羊矮棚水边的草垛跳水（三级跳台 + 草垛 + 靶环牌）、马场桶/架分离与
# 检查点柱贴地。GUI 引擎跑：
#   Godot_v4.3-stable_win64.exe --path . -s scripts/art/capture_playtest_fixes.gd

const SCENE := "res://scenes/levels/farm/farm_grounds.tscn"
const OUT_DIR := "res://builds/playtest_fixes"

const SHOTS := [
	{"tag": "herb_summit", "pos": Vector3(3.5, 33.2, 86), "look": Vector3(0.5, 31.6, 81)},     # 第一丛（下山路面上）
	{"tag": "herb_zigzag", "pos": Vector3(-24, 28.2, 103), "look": Vector3(-27.5, 26.7, 99)},  # zigzag 北弯丛
	{"tag": "pond_dive_wide", "pos": Vector3(4, 21, -34), "look": Vector3(-10, 16.5, -44)},    # 池塘东北：跳台+草垛+水
	{"tag": "pond_dive_steps", "pos": Vector3(-1.5, 18.5, -31.5), "look": Vector3(-6, 17.5, -36)}, # 三级跳台近景
	{"tag": "pond_dive_stack", "pos": Vector3(-6, 19.0, -33.5), "look": Vector3(-6, 17.3, -40)},   # 顶台望草垛（起跳视角）
	{"tag": "rack_barrel", "pos": Vector3(74, 10.5, -126), "look": Vector3(79, 8.8, -130)},    # 饲料架与泵桶（修复后）
	{"tag": "cp_pole", "pos": Vector3(50, 10.0, -117), "look": Vector3(52, 8.6, -123)},        # 检查点柱（修复后）
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
