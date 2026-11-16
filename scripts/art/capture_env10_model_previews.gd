extends SceneTree

# ENV_10 新模型逐个特写：中性天空下单模型两机位出 PNG，供美术核对变形/破损。
# 须用 GUI 引擎二进制跑（headless 是 dummy 渲染器，不出图）：
#   Godot_v4.3-stable_win64.exe --path . -s scripts/art/capture_env10_model_previews.gd

const ASSETS = preload("res://scripts/art/asset_library.gd")
const OUT_DIR := "res://builds/env10_previews"

const IDS := [
	"ENV_10_BARN",
	"ENV_10_SHED_SHEAR",
	"ENV_10_RUINED_SHED",
	"ENV_10_SILO",
	"ENV_10_FEED_RACK",
	"ENV_10_BENCH",
	"ENV_10_STONE_PILLAR",
	"ENV_10_STATION",
	"ENV_10_GATE_TIMBER",
	"ENV_10_APPLE_FRUIT",
	"ENV_10_POTATO",
]

# 两个机位方向（前 3/4 与侧 3/4），按模型 AABB 自适应距离取景。
const ANGLES := [
	Vector3(1.0, 0.55, 1.0),
	Vector3(-0.85, 0.35, 0.75),
]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.4, 0.58, 0.74)
	sky_mat.sky_horizon_color = Color(0.8, 0.84, 0.82)
	sky_mat.ground_bottom_color = Color(0.34, 0.36, 0.32)
	sky_mat.ground_horizon_color = Color(0.8, 0.84, 0.82)
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
	for id in IDS:
		var model: Node3D = ASSETS.make(id)
		if model == null:
			push_error("cannot make " + id)
			continue
		root.add_child(model)
		await process_frame
		if model.find_children("*", "GeometryInstance3D", true, false).is_empty():
			push_error("no geometry in " + id)
			model.queue_free()
			continue
		var bounds := _gather_aabb(model)
		# 落地居中：min.y 贴 0，x/z 中心回原点，机位围绕原点取景。
		model.global_position -= Vector3(bounds.position.x + bounds.size.x * .5, bounds.position.y, bounds.position.z + bounds.size.z * .5)
		await process_frame
		var center := Vector3(0, bounds.size.y * .5, 0)
		var radius: float = bounds.size.length() * .5
		var cam := Camera3D.new()
		cam.fov = 35
		root.add_child(cam)
		for i in ANGLES.size():
			var dir: Vector3 = ANGLES[i].normalized()
			var dist: float = maxf(radius / tan(deg_to_rad(35) * .5) * 1.12, 1.2)
			cam.global_position = center + dir * dist
			cam.look_at(center, Vector3.UP)
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			var path := "%s/%s_%d.png" % [out_abs, id, i]
			img.save_png(path)
			print("saved ", path)
		cam.queue_free()
		model.queue_free()
		await process_frame
	quit(0)

func _gather_aabb(node: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		var gi := child as GeometryInstance3D
		var box: AABB = gi.get_global_transform() * gi.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	return bounds
