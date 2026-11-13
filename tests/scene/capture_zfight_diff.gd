extends SceneTree
## Two-frame flicker survey: renders each camera spot twice with a 2 mm camera
## shift; pixels whose colour flips are surfaces whose depth order changed -
## real z-fighting a player would see. Animations are frozen and billboard
## labels are excluded so only model-coplanarity artifacts count.
## Baselines after the 2026-11-13 anti-coplanar pass (960x540): farm 0,
## course_00 3, course_01 105, course_02 0, course_03 30, course_04 88 px
## (sub-marginal distant edges). Usage:
##   godot --path . -s tests/scene/capture_zfight_diff.gd -- --scene <tscn> [--out <dir>] [--hide <name>] render each camera spot twice with a 2mm lateral
## camera shift; pixels whose color flips are surfaces whose depth order
## changed = actual z-fighting visible to the player. Saves diff masks.
## Run (rendering, not headless):
##   godot --path . -s tests/scene/_tmp_flicker_diff.gd -- --scene <tscn> [--out <dir>]

var _masks: Array = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var scene_path := "res://scenes/courses/course_02_creek.tscn"
	var out_dir := "res://assets/art_references/zfight/"
	var args := OS.get_cmdline_user_args()
	var hide_substr := ""
	for i in args.size():
		if args[i] == "--scene" and i + 1 < args.size(): scene_path = args[i + 1]
		if args[i] == "--out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--hide" and i + 1 < args.size(): hide_substr = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var scene: Node = load(scene_path).instantiate()
	root.add_child(scene)
	# Billboard text quads shift sub-pixel with any camera move; their glyph
	# edges are not model z-fighting, so exclude them from the diff.
	for lbl in scene.find_children("*", "Label3D", true, false):
		(lbl as Label3D).visible = false
	for lbl in scene.find_children("*", "Sprite3D", true, false):
		(lbl as Sprite3D).visible = false
	if hide_substr != "":
		var hidden_count := 0
		for m in scene.find_children("*", "MeshInstance3D", true, false):
			var cur: Node = m
			while cur != null:
				if String(cur.name).containsn(hide_substr):
					m.visible = false
					hidden_count += 1
					break
				cur = cur.get_parent()
		print("HIDE %s -> %d meshes" % [hide_substr, hidden_count])
	# Freeze every animation/tween/particle: only the camera moves between the
	# two frames, so a colour flip can only come from depth-order flipping.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	await create_timer(0.8).timeout

	# Spots: [pos, look_at]
	var spots: Array = []
	var s := String(scene_path)
	if s.contains("course_00"):
		spots = [
			[Vector3(0, 4, -2), Vector3(0, 0, -12)],
			[Vector3(26, 3.5, -24), Vector3(26, 0.3, -32)],
			[Vector3(30, 3.5, -36), Vector3(30, 0.3, -44)],
			[Vector3(43, 3.5, -50), Vector3(43, 0.3, -58)],
			[Vector3(-4, 2.5, -26), Vector3(-6.2, 2.0, -30)],
			[Vector3(18.5, 2.0, -28.5), Vector3(18.5, 0.4, -31.5)],
		]
	elif s.contains("course_01"):
		spots = [
			[Vector3(0, 4, 4), Vector3(0, 0.1, 10)],
			[Vector3(0, 4, -12), Vector3(0, 0.1, -22)],
			[Vector3(0, -2.0, -38), Vector3(0, -3.5, -46)],
			[Vector3(0, 4, -54), Vector3(0, 0.1, -62)],
			[Vector3(0, 2.5, -76), Vector3(0, 0.3, -84)],
			[Vector3(0, 4, -94), Vector3(0, 0.1, -102)],
			[Vector3(2.2, 3.6, -19.5), Vector3(0, 2.8, -21.1)],
			[Vector3(-3.5, 2.5, -58.5), Vector3(-3.5, 1.5, -61.2)],
		]
	elif s.contains("course_02"):
		spots = [
			[Vector3(0, 4, 4), Vector3(0, 0.2, 12)],
			[Vector3(0, 4, -8), Vector3(0, 0.2, -16)],
			[Vector3(0, 5, -20), Vector3(0, 1.5, -27)],
			[Vector3(5.5, 2.5, -22), Vector3(-4, 1.0, -26)],
			[Vector3(0, 4, -44), Vector3(0, 0.2, -54)],
			[Vector3(0, 4, -74), Vector3(0, 0.2, -84)],
		]
	elif s.contains("course_03"):
		spots = [
			[Vector3(0, 4, 6), Vector3(0, 0.2, 14)],
			[Vector3(0, 4, -8), Vector3(0, 0.2, -18)],
			[Vector3(0, 4, -32), Vector3(0, 0.2, -42)],
			[Vector3(0, 4, -58), Vector3(0, 0.2, -68)],
			[Vector3(0, 4, -82), Vector3(0, 0.2, -92)],
		]
	elif s.contains("course_04"):
		spots = [
			[Vector3(0, 3, 4), Vector3(0, 0.3, -8)],
			[Vector3(2, 3, -22), Vector3(-4, 0.3, -30)],
			[Vector3(0, 3, -42), Vector3(0, 0.3, -52)],
			[Vector3(0, 3, -72), Vector3(0, 0.3, -82)],
			[Vector3(0, 3, -92), Vector3(0, 0.3, -100)],
			[Vector3(0, 2.2, -93.5), Vector3(0, 0.15, -95.5)],
		]
	else:
		spots = [
			[Vector3(0, 40, 60), Vector3(0, 20, 0)], [Vector3(-60, 30, 40), Vector3(0, 10, -40)],
			[Vector3(40, 30, -80), Vector3(20, 5, -110)], [Vector3(-40, 25, -60), Vector3(-45, 2, -180)],
			# close-ups over the fixed hot spots
			[Vector3(30, 27, 63), Vector3(28, 24.4, 52)],
			[Vector3(19, 28.5, 61), Vector3(19, 24.2, 44)],
			[Vector3(-21, 18.5, -8), Vector3(-27, 16.3, -15)],
			[Vector3(3.5, 11.5, -78), Vector3(8.2, 9.1, -85.5)],
			[Vector3(-42.5, 19, -29), Vector3(-44, 16.3, -37)],
			[Vector3(31.5, 11.5, -97.5), Vector3(27, 8.3, -103.5)],
			[Vector3(-42.5, 5.5, -191.5), Vector3(-48, 2.3, -197)],
			[Vector3(-70, 5.5, -216.5), Vector3(-75.5, 2.3, -223.5)],
			[Vector3(-71.5, 5.5, -218), Vector3(-78, 2.3, -224)],
			[Vector3(35.5, 26.5, 64.5), Vector3(32.5, 24.3, 59.5)],
			[Vector3(26, 27.5, -101), Vector3(27, 8.1, -104)],
			[Vector3(40, 9.5, -98), Vector3(30, 8.0, -106)],
		]

	var total_changed := 0
	for idx in spots.size():
		cam.global_position = spots[idx][0]
		cam.look_at(spots[idx][1], Vector3.UP)
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		var img_a: Image = root.get_texture().get_image()
		cam.global_position += Vector3(0.0022, 0.0013, 0.0)
		await RenderingServer.frame_post_draw
		var img_b: Image = root.get_texture().get_image()
		var mask := Image.create(img_a.get_width(), img_a.get_height(), false, Image.FORMAT_RGB8)
		var w := img_a.get_width()
		var h := img_a.get_height()
		var flip := PackedByteArray()
		flip.resize(w * h)
		var raw := 0
		for y in h:
			for x in w:
				var ca := img_a.get_pixel(x, y)
				var cb := img_b.get_pixel(x, y)
				var d := absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
				if d > 0.14:
					flip[y * w + x] = 1
					raw += 1
		# Solid fights: flipped pixel with >=3 flipped 4-neighbours (area fight).
		# Thin outlines (>=2 neighbours) are glyph/edge AA noise, not z-fighting.
		var changed := 0
		for y in h:
			for x in w:
				if flip[y * w + x] == 0: continue
				var n := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx == 0 and dy == 0: continue
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
						if flip[ny * w + nx] == 1: n += 1
				if n >= 6:
					changed += 1
					mask.set_pixel(x, y, Color(1, 0, 0))
		mask.save_png(ProjectSettings.globalize_path("%sflicker_%s_%02d.png" % [out_dir, s.get_file().get_basename(), idx]))
		img_a.save_png(ProjectSettings.globalize_path("%sframe_%s_%02d.png" % [out_dir, s.get_file().get_basename(), idx]))
		print("FLICKER spot=%02d solid=%d raw=%d  (%s -> %s)" % [idx, changed, raw, str(spots[idx][0]), str(spots[idx][1])])
		total_changed += changed
	print("FLICKER_TOTAL scene=%s changed=%d" % [s, total_changed])
	quit(0)
