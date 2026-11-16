extends SceneTree

# 白模清扫 QA 截图：加载 farm_grounds 主场景，在白模替换过的地标处拍固定机
# 位（谷仓/筒仓/剪毛棚/索道站台/木门/铁门石柱/饲料架/长椅/菜畦/追逐草捆），
# 用真实渲染器出 PNG 供目视验收。须用 GUI 引擎二进制跑（headless 是 dummy
# 渲染器，不出图）：
#   Godot_v4.3-stable_win64.exe --path . -s scripts/art/capture_farm_sweep_screens.gd

const SCENE := "res://scenes/levels/farm/farm_grounds.tscn"
const OUT_DIR := "res://builds/farm_sweep_screens"

const SHOTS := [
	{"tag": "pigpen", "cams": [
		{"pos": Vector3(-2, 36, 108), "look": Vector3(-5, 32.5, 89)},   # 废棚 + 圈门 + 饲料架 + 水桶
		{"pos": Vector3(12, 35, 95), "look": Vector3(0, 32, 88)},       # 圈门正面
	]},
	{"tag": "ox_terrace", "cams": [
		{"pos": Vector3(2, 30, 18), "look": Vector3(14, 26, 30)},       # 谷仓 + 筒仓天际线
		{"pos": Vector3(36, 28, 62), "look": Vector3(29, 25, 54)},      # 牛耕地木门
		{"pos": Vector3(60, 27, 33), "look": Vector3(57, 24.5, 26)},    # 菜畦卷心菜 + 灌溉渠
	]},
	{"tag": "sheep", "cams": [
		{"pos": Vector3(-46, 21, -28), "look": Vector3(-56, 17, -41)},  # 剪毛棚 + 羊毛堆
	]},
	{"tag": "horses", "cams": [
		{"pos": Vector3(70, 12, -122), "look": Vector3(81, 9, -135)},   # 马场谷仓 + 饲料架
		{"pos": Vector3(36, 11, -93), "look": Vector3(40, 9, -100)},    # 长椅
		{"pos": Vector3(12, 11, -83), "look": Vector3(18, 9, -90)},     # 马场围栏门
	]},
	{"tag": "chase", "cams": [
		{"pos": Vector3(-70, 8, -158), "look": Vector3(-58, 4, -174)},  # 设备场谷仓 + 草捆
		{"pos": Vector3(-74, 7, -218), "look": Vector3(-82, 3, -229)},  # 铁门石柱
	]},
	{"tag": "station", "cams": [
		{"pos": Vector3(-12, 8, -266), "look": Vector3(-12, 2, -280)},  # 索道站台
		{"pos": Vector3(-20, 6, -272), "look": Vector3(-12, 3, -280)},  # 站台侧视
	]},
]

func _initialize() -> void:
	# Deferred like the scene tests: autoloads (AchievementManager etc.) must be
	# in the tree before farm_grounds.gd compiles - loading in _init() fails it.
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
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.86, 0.82)
	env.fog_density = 0.0022
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
		var index := 0
		for cam_def in shot["cams"]:
			var cam := Camera3D.new()
			root.add_child(cam)
			cam.global_position = cam_def["pos"]
			cam.look_at(cam_def["look"], Vector3.UP)
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			var path := "%s/%s_%d.png" % [out_abs, shot["tag"], index]
			img.save_png(path)
			print("saved ", path)
			cam.queue_free()
			index += 1
	quit(0)
