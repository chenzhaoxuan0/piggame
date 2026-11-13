extends SceneTree

# Zone-style QA screenshots: load each hidden-course scene, shoot a few fixed
# camera angles with the real renderer, and save PNGs for visual inspection.
# Each course mounts inside a holder that carries the neutral base
# WorldEnvironment + Sun as siblings - exactly like the office hub - so the
# course's own ZoneEnvironment swap AND its ZoneGrade filter both apply: the
# captures show the REAL zone look (fog, tonemap, pixelation, grading).
# Run with the GUI engine binary (headless uses the dummy renderer, no image):
#   Godot_v4.3-stable_win64.exe --path . -s scripts/art/capture_zone_screens.gd

const SHOTS := [
	{"scene": "res://scenes/courses/course_00_nightmare.tscn", "tag": "C0",
		"cams": [
			{"pos": Vector3(0, 4, 14), "look": Vector3(0, 1, 0)},        # pens + cages + fog lane
			{"pos": Vector3(20, 2.5, -27.2), "look": Vector3(27, 1, -30)}, # L2 belts + hooks inside
			{"pos": Vector3(43, 4, -56), "look": Vector3(46, 1, -68)},   # dock + crates
		]},
	{"scene": "res://scenes/courses/course_01_ox_field.tscn", "tag": "C1",
		"cams": [
			{"pos": Vector3(0, 5, 12), "look": Vector3(0, 1, -12)},      # start field + checker line
			{"pos": Vector3(12, 7, -34), "look": Vector3(0, 1, -48)},    # door dash + pendulum alley
			{"pos": Vector3(0, 5, -82), "look": Vector3(0, 2, -95)},     # hammer bridge + finish arch
		]},
	{"scene": "res://scenes/courses/course_02_creek.tscn", "tag": "C2",
		"cams": [
			{"pos": Vector3(0, 4, 14), "look": Vector3(0, 0, 0)},      # start bank + creek
			{"pos": Vector3(0, 7, -28), "look": Vector3(0, 0, -44)},   # canyon + walls
			{"pos": Vector3(0, 5, -72), "look": Vector3(0, 2, -82)},   # nether portal
		]},
	{"scene": "res://scenes/courses/course_03_woodland.tscn", "tag": "C3",
		"cams": [
			{"pos": Vector3(0, 4, 12), "look": Vector3(0, 0, -2)},     # meadow + trees
			{"pos": Vector3(0, 5, -30), "look": Vector3(0, 1, -44)},   # gold plaza + chests
			{"pos": Vector3(0, 5, -55), "look": Vector3(0, 1, -70)},   # maze + hollow tree
		]},
	{"scene": "res://scenes/courses/course_04_courtyard.tscn", "tag": "C4",
		"cams": [
			{"pos": Vector3(0, 4, 14), "look": Vector3(0, 0, -4)},     # start grid + gantry
			{"pos": Vector3(14, 6, -40), "look": Vector3(4, 0, -52)},  # east lane + gravel
			{"pos": Vector3(0, 5, -148), "look": Vector3(0, 1, -156)}, # ramp + finish gate
		]},
]

const OUT_DIR := "res://builds/zone_screens"

func _init() -> void:
	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)
	for shot in SHOTS:
		var packed: PackedScene = load(shot["scene"])
		if packed == null:
			push_error("cannot load " + str(shot["scene"]))
			continue
		# The holder mirrors the office root (WorldEnvironment + Sun + course as
		# direct children of one child-of-root node): ZoneEnvironment walks up
		# from the course to exactly this node and scans its children, so the
		# swap finds the env/sun and the zone look - including the ZoneGrade
		# full-screen filter - lands in the captures.
		var holder := Node3D.new()
		holder.name = "CaptureHolder"
		root.add_child(holder)
		var world_env := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.5, 0.55, 0.6)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.9, 0.92, 1.0)
		env.ambient_light_energy = 0.9
		world_env.environment = env
		holder.add_child(world_env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -35, 0)
		sun.light_energy = 0.8
		holder.add_child(sun)
		var course: Node3D = packed.instantiate()
		holder.add_child(course)
		await process_frame
		await process_frame
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
		root.remove_child(holder)
		holder.queue_free()
		await process_frame
	quit(0)
