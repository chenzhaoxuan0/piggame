extends SceneTree

const SCENE := "res://scenes/levels/farm/farm_grounds.tscn"
const OUT_DIR := "res://builds/gate_top"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)
	var farm: Node3D = load(SCENE).instantiate()
	root.add_child(farm)
	await process_frame
	await process_frame
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	world_env.environment = env
	root.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var shots := [
		{"tag": "south_straight", "pos": Vector3(53, 14, -119), "look": Vector3(53, 8, -131)},  # 1号门北侧斜俯视
		{"tag": "east_bend", "pos": Vector3(64, 14, -120), "look": Vector3(76, 8, -120)},      # 0号门弯顶自西向东斜俯视
	]
	for shot in shots:
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.global_position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_abs, shot["tag"]])
		print("saved")
		cam.queue_free()
	quit(0)
