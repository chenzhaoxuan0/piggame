extends Node3D

const ASSETS = preload("res://scripts/art/asset_library.gd")
const RUNNER_SCRIPT = preload("res://scripts/courses/course_runner.gd")
const MEME_SCRIPT = preload("res://scripts/courses/meme_layer.gd")
const CONFIG_SCRIPT = preload("res://scripts/courses/course_config.gd")
const LAUNCH_PAD = preload("res://scripts/courses/components/launch_pad.gd")
const SPIN_HAMMER = preload("res://scripts/courses/components/spin_hammer.gd")
const FAKE_FLOOR = preload("res://scripts/courses/components/fake_floor.gd")
const DECOY_GOAL = preload("res://scripts/courses/components/decoy_goal.gd")
const ROLLING_HAY = preload("res://scripts/courses/components/rolling_hay.gd")
const SPINNING_SWEEPER = preload("res://scripts/courses/components/spinning_sweeper.gd")
const BUMPER_PILLAR = preload("res://scripts/courses/components/bumper_pillar.gd")
const DOOR_DASH = preload("res://scripts/courses/components/door_dash_gate.gd")
const PENDULUM_BALL = preload("res://scripts/courses/components/pendulum_ball.gd")
const BOUNCY_MUSHROOM = preload("res://scripts/courses/components/bouncy_mushroom.gd")

const SPAWN := Vector3(0, 0.6, 6)
const STORYBOOK_GREEN := Color("86A873") # Fairy green
const STORYBOOK_GOLD := Color("FDE68A") # Pastel cream gold
const STORYBOOK_CORAL := Color("E74C3C") # Mushroom red
const STORYBOOK_PURPLE := Color("A855F7") # Magic wisteria
const STORYBOOK_WOOD := Color("6D4C41") # Bark brown
const PUMPKIN_ORANGE := Color("EA580C") # Cinderella pumpkin
const STORYBOOK_LOAM := Color("4E342E") # Warm soil
const CREAM := Color("FFFBEB")
const DARK := Color("292524")

var runner: CourseRunner
var meme_layer: MemeLayer
var _discern_halo: Node3D

func _ready() -> void:
	_build_ground()
	_build_surroundings()
	_build_mushrooms()
	_build_bumpers()
	_build_pumpkin_trap()
	_build_door_dash()
	_build_fake_bridge()
	_build_vine_sweepers()
	_build_pendulums()
	_build_cheshire_illusion()
	_build_decorations()
	_build_exit()
	_build_markers()

	meme_layer = MEME_SCRIPT.new()
	meme_layer.name = "MemeLayer"
	add_child(meme_layer)

	runner = RUNNER_SCRIPT.new()
	runner.name = "CourseRunner"
	runner.config = _make_config()
	add_child(runner)

func setup(player: Node3D) -> void:
	player.reset_at(SPAWN)
	runner.setup(player, SPAWN)
	_update_discern_visuals()

func _update_discern_visuals() -> void:
	var gm := _gm()
	var has_discern: bool = bool(gm.get("has_discern_skill")) if gm else false
	if is_instance_valid(_discern_halo):
		_discern_halo.visible = has_discern

func _gm() -> Node:
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_3"
	cfg.title = "林间隐藏闯关 · 童话绘本漫游"
	cfg.desc = "穿越童话树影！踩巨型弹力蘑菇、躲避失控大南瓜与幻影荆棘！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-35, -16, -115), Vector3(70, 40, 135))
	cfg.dog_count = 1
	cfg.dog_speed_min = 2.8
	cfg.dog_speed_max = 6.2
	cfg.memes = {
		"course_start": {"title": "翻开童话绘本！", "text": "画风突变！温暖水彩绘本世界展开！", "duration": 3.0},
		"mushroom_bounce": {"title": "采蘑菇的小猪！", "text": "Duang！踩中童话红白大蘑菇，飞越林间深谷！", "duration": 2.2},
		"super_bounce": {"title": "仙女教母的恩赐！", "text": "跌落谷底？金光弹簧送你重返童话跑道！", "duration": 2.5},
		"bumper_hit": {"title": "花蕊轻弹！", "text": "撞上巨大的童话花蕊立柱！弹飞打滚！", "duration": 2.0},
		"pumpkin_telegraph": {"title": "午夜十二点的钟声！", "text": "前方南瓜马车失控滚下斜坡啦！快让开！", "duration": 2.2},
		"pumpkin_hit": {"title": "南瓜保龄球！", "text": "巨大南瓜横冲直撞！猪猪被保龄球式击飞！", "duration": 2.6},
		"vine_hit": {"title": "藤蔓扫腿！", "text": "花藤横木扫过来啦！按空格起跳越过！", "duration": 2.2},
		"pendulum_hit": {"title": "橡果大摆锤！", "text": "百斤巨型黄金橡果迎面荡来！", "duration": 2.2},
		"door_bonk": {"title": "树精之门紧闭！", "text": "这扇大树门被魔法封印了！换一扇撞！", "duration": 2.0},
		"door_dash_break": {"title": "破茧而出！", "text": "一头撞碎空心木门！穿行童话林海！", "duration": 2.4},
		"cheshire_decoy": {"title": "柴郡猫的恶作剧！", "text": "嘻嘻嘻~ 你撞上的不过是画在树上的笑脸！", "duration": 3.0},
		"cheshire_again": {"title": "别被眼睛骗了！", "text": "真路就在旁边！相信小羊的洞察之眸！", "duration": 2.0},
		"fake_bridge_telegraph": {"title": "迷雾浮桥", "text": "看似平整的落叶桥……似乎有些松动？", "duration": 2.0},
		"fake_bridge": {"title": "落叶纷飞！", "text": "枯叶桥面坍塌！滑落底层树根滑道！", "duration": 2.8},
		"dog_bonk": {"title": "恶犬扑空", "text": "童话里的狗子也有打滑的时候", "duration": 2.0},
		"qte_success": {"title": "坚韧挣脱！", "text": "阿牛之力：咬紧牙关，震退恶犬！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "摔了个猪啃泥……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "童话重生", "text": "林间精灵把你送回了安全检查点", "duration": 2.2},
	}
	return cfg

func _build_ground() -> void:
	# 1. Start Terrace (Storybook warm green grass over loam)
	_storybook_platform("StartTerrace", Vector3(16, 1, 16), Vector3(0, -0.5, 4), STORYBOOK_GREEN, STORYBOOK_LOAM)

	# 2. Path A (Mushroom canopy path)
	_storybook_platform("PathA", Vector3(8, 1, 26), Vector3(0, -0.5, -17), STORYBOOK_GREEN, STORYBOOK_LOAM)

	# 3. Lower Root Glade (falls from leaf bridge)
	_storybook_platform("LowerGlade", Vector3(10, 1, 14), Vector3(0, -4.0, -36), STORYBOOK_LOAM, STORYBOOK_WOOD)

	# 4. Ramp connecting lower glade back up to Path B
	var ramp := _solid_box("RampBack", Vector3(8, 0.5, 6.95), Vector3(0, -1.966, -46.126), STORYBOOK_WOOD)
	ramp.rotation.x = deg_to_rad(30.26)

	# 5. Path B (Wisteria forest run)
	_storybook_platform("PathB", Vector3(8, 1, 21), Vector3(0, -0.5, -59.5), STORYBOOK_GREEN, STORYBOOK_LOAM)

	# 6. Timber Vine Bridge
	_storybook_platform("VineBridge", Vector3(4.5, 1, 22), Vector3(0, -0.5, -81), STORYBOOK_WOOD, STORYBOOK_LOAM)

	# 7. Exit Terrace
	_storybook_platform("ExitTerrace", Vector3(12, 1, 12), Vector3(0, -0.5, -98), STORYBOOK_GREEN, STORYBOOK_LOAM)

	# Checkered lines and signs
	_build_checker_line(2.0, 8.0)
	_build_checker_line(-92.8, 8.0)
	_label("林间隐藏闯关 · 童话绘本漫游", Vector3(0, 2.4, 9), 26)
	_label("空格跳跃 / WASD 移动 / 识破童话迷雾", Vector3(0, 1.6, 1), 18)

func _build_checker_line(z: float, width: float) -> void:
	for row in 2:
		for i in int(width):
			var color := CREAM if (i + row) % 2 == 0 else DARK
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1, 0.06, 1)
			mesh.mesh = box
			mesh.position = Vector3(-width * 0.5 + 0.5 + i, 0.03, z - row)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 1.0
			mesh.material_override = mat
			add_child(mesh)

func _storybook_platform(node_name: String, size: Vector3, pos: Vector3, top_color: Color, sub_color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	_add_box_mesh(body, Vector3(size.x, size.y - 0.16, size.z), Vector3(0, -0.08, 0), sub_color)
	_add_box_mesh(body, Vector3(size.x + 0.2, 0.16, size.z), Vector3(0, size.y * 0.5 - 0.08, 0), top_color)
	add_child(body)
	return body

func _build_surroundings() -> void:
	# Storybook fairy trees and giant mushrooms framing the track
	for z in [4.0, -14.0, -32.0, -50.0, -68.0, -86.0]:
		for side in [-1.0, 1.0]:
			var tree_x: float = side * 10.0
			_build_storybook_tree(Vector3(tree_x, 0, z), side > 0)

	# Giant fairy mushrooms in the background
	_build_giant_bg_mushroom(Vector3(-14, -2, -22), Color("E74C3C"), 2.8)
	_build_giant_bg_mushroom(Vector3(14, -2, -45), Color("FBBF24"), 2.4)
	_build_giant_bg_mushroom(Vector3(-15, -2, -75), Color("A855F7"), 3.0)

	# Gentle floral lights along borders
	for z in [-6.0, -20.0, -48.0, -66.0, -90.0]:
		for side in [-1.0, 1.0]:
			var lamp := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.35
			sphere.height = 0.7
			lamp.mesh = sphere
			lamp.position = Vector3(side * 4.4, 0.8, z)
			var l_mat := StandardMaterial3D.new()
			l_mat.albedo_color = STORYBOOK_GOLD
			l_mat.emission_enabled = true
			l_mat.emission = STORYBOOK_GOLD * 0.8
			lamp.material_override = l_mat
			add_child(lamp)

func _build_storybook_tree(pos: Vector3, alternate: bool) -> void:
	var tree_root := Node3D.new()
	tree_root.position = pos
	_add_box_mesh(tree_root, Vector3(1.2, 3.6, 1.2), Vector3(0, 1.8, 0), STORYBOOK_WOOD)
	var foliage := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.4
	sphere.height = 3.6
	foliage.mesh = sphere
	foliage.position.y = 4.2
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = STORYBOOK_GREEN if not alternate else Color("78A75A")
	foliage.material_override = f_mat
	tree_root.add_child(foliage)
	add_child(tree_root)

func _build_giant_bg_mushroom(pos: Vector3, color: Color, scale_factor: float) -> void:
	var shroom := Node3D.new()
	shroom.position = pos
	var stalk := MeshInstance3D.new()
	var s_cyl := CylinderMesh.new()
	s_cyl.top_radius = 0.5 * scale_factor
	s_cyl.bottom_radius = 0.8 * scale_factor
	s_cyl.height = 3.0 * scale_factor
	stalk.mesh = s_cyl
	stalk.position.y = 1.5 * scale_factor
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = CREAM
	stalk.material_override = s_mat
	shroom.add_child(stalk)

	var cap := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.6 * scale_factor
	sphere.height = 1.4 * scale_factor
	sphere.is_hemisphere = true
	cap.mesh = sphere
	cap.position.y = 3.0 * scale_factor
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = color
	cap.material_override = c_mat
	shroom.add_child(cap)
	add_child(shroom)

func _build_mushrooms() -> void:
	# Bouncy Mushroom 1 (Coral Red)
	var m1 := BOUNCY_MUSHROOM.new()
	m1.name = "BouncyMushroom1"
	m1.position = Vector3(0, 0, -10)
	m1.bounce_direction = Vector3(0, 0, -1)
	m1.bounce_power = 8.5
	m1.bounce_up = 6.8
	m1.cap_color = STORYBOOK_CORAL
	m1.meme_id = "mushroom_bounce"
	add_child(m1)
	_label("▲ 弹力大蘑菇 ▲", Vector3(0, 2.2, -10), 18)

	# Super Golden Mushroom in Lower Glade
	var super_m := BOUNCY_MUSHROOM.new()
	super_m.name = "SuperGoldenMushroom"
	super_m.position = Vector3(0, -3.5, -40)
	super_m.bounce_direction = Vector3(0, 0, -1)
	super_m.bounce_power = 9.0
	super_m.bounce_up = 11.5
	super_m.cap_color = STORYBOOK_GOLD
	super_m.meme_id = "super_bounce"
	add_child(super_m)
	_label("★ 仙女黄金菇 · 弹跳重返 ★", Vector3(0, -1.8, -40), 20)

func _build_bumpers() -> void:
	# Floral Bumper Cluster on Path A
	var b1 := BUMPER_PILLAR.new()
	b1.name = "FloralBumper1"
	b1.position = Vector3(-2.2, 0, -14.0)
	b1.bumper_color = STORYBOOK_PURPLE
	b1.cap_color = STORYBOOK_GOLD
	add_child(b1)

	var b2 := BUMPER_PILLAR.new()
	b2.name = "FloralBumper2"
	b2.position = Vector3(2.2, 0, -14.0)
	b2.bumper_color = STORYBOOK_PURPLE
	b2.cap_color = STORYBOOK_GOLD
	add_child(b2)

	var b3 := BUMPER_PILLAR.new()
	b3.name = "FloralBumper3"
	b3.position = Vector3(0.0, 0, -16.8)
	b3.bumper_color = STORYBOOK_CORAL
	b3.cap_color = STORYBOOK_GOLD
	add_child(b3)
	_label("★ 童话花柱弹跳阵 ★", Vector3(0, 1.8, -15.4), 18)

func _build_pumpkin_trap() -> void:
	# Giant rolling pumpkin bowling down path
	var pumpkin_block := _solid_box("PumpkinGateBase", Vector3(1.2, 1.2, 1.2), Vector3(0, 2.8, -20.5), PUMPKIN_ORANGE)
	_label("?", Vector3(0, 0, 0.62), 60, pumpkin_block)
	_label("?", Vector3(0, 0, -0.62), 60, pumpkin_block)

	var pumpkin := ROLLING_HAY.new()
	pumpkin.name = "RollingPumpkin"
	pumpkin.position = Vector3(1.5, 3.6, -22.5)
	pumpkin.roll_direction = Vector3(-0.3, 0, 1)
	pumpkin.roll_impulse = 7.5
	pumpkin.meme_id = "pumpkin_hit"
	pumpkin.telegraph_meme_id = "pumpkin_telegraph"
	add_child(pumpkin)

	var bump := _area("PumpkinBump", "", Vector3(0, 2.0, -20.5), Vector3(1.5, 0.7, 1.5))
	bump.body_entered.connect(func(body: Node3D):
		if body is PigController:
			pumpkin.release()
			var tween := create_tween()
			tween.tween_property(pumpkin_block, "position:y", 3.1, 0.1)
			tween.tween_property(pumpkin_block, "position:y", 2.8, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func _build_door_dash() -> void:
	var door_gate := DOOR_DASH.new()
	door_gate.name = "FairytaleDoorGate"
	door_gate.position = Vector3(0, 0, -26.5)
	door_gate.breakable_index = 0 # Left door is breakable hollow fairy door
	door_gate.door_colors = [STORYBOOK_CORAL, STORYBOOK_GOLD, STORYBOOK_GREEN]
	add_child(door_gate)

func _build_fake_bridge() -> void:
	var leaf_tile := FAKE_FLOOR.new()
	leaf_tile.name = "LeafBridge"
	leaf_tile.position = Vector3(0, 0, -37)
	leaf_tile.tile_size = Vector3(8, 0.3, 12)
	leaf_tile.tile_color = STORYBOOK_GREEN
	leaf_tile.trigger_delay = 0.5
	leaf_tile.meme_id = "fake_bridge"
	leaf_tile.telegraph_meme_id = "fake_bridge_telegraph"
	add_child(leaf_tile)
	_label("落叶浮桥 · 稳健前行", Vector3(0, 1.6, -31.5), 20)

func _build_vine_sweepers() -> void:
	# Vine sweeper 1
	var sw1 := SPINNING_SWEEPER.new()
	sw1.name = "VineSweeper1"
	sw1.position = Vector3(0, 0, -74.0)
	sw1.rotate_speed = 2.0
	sw1.bar_length = 4.2
	sw1.bar_elevation = 0.35
	sw1.knockback_power = 6.5
	sw1.knockback_up = 3.0
	sw1.sweeper_color = STORYBOOK_GREEN
	sw1.meme_id = "vine_hit"
	add_child(sw1)

	# Vine sweeper 2
	var sw2 := SPINNING_SWEEPER.new()
	sw2.name = "VineSweeper2"
	sw2.position = Vector3(0, 0, -82.0)
	sw2.rotate_speed = -2.2
	sw2.bar_length = 4.2
	sw2.bar_elevation = 0.35
	sw2.knockback_power = 7.0
	sw2.knockback_up = 3.5
	sw2.sweeper_color = STORYBOOK_PURPLE
	sw2.meme_id = "vine_hit"
	add_child(sw2)
	_label("旋转花藤扫杆 · 空格跳跃！", Vector3(0, 2.2, -72.0), 20)

func _build_pendulums() -> void:
	var pendulum := PENDULUM_BALL.new()
	pendulum.name = "AcornPendulum"
	pendulum.position = Vector3(0, 0, -88.0)
	pendulum.swing_speed = 2.6
	pendulum.max_angle_deg = 45.0
	pendulum.knockback_power = 8.0
	pendulum.knockback_up = 4.0
	pendulum.ball_color = STORYBOOK_GOLD
	pendulum.meme_id = "pendulum_hit"
	add_child(pendulum)
	_label("★ 巨型黄金橡果钟摆 ★", Vector3(0, 3.8, -88.0), 18)

func _build_cheshire_illusion() -> void:
	# Cheshire cat fake door & phantom wall
	var wall_l := _solid_box("FairytaleWallL", Vector3(5, 3.4, 0.6), Vector3(-3.5, 1.7, -61), STORYBOOK_WOOD)
	var wall_r := _solid_box("FairytaleWallR", Vector3(5, 3.4, 0.6), Vector3(3.5, 1.7, -61), STORYBOOK_WOOD)

	# Painted decoy exit door
	var painted := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.8)
	painted.mesh = quad
	painted.position = Vector3(-3.5, 1.7, -60.6)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = STORYBOOK_PURPLE
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	painted.material_override = glow
	add_child(painted)
	_label("柴郡猫之门 EXIT", Vector3(-3.5, 2.6, -60.45), 36)

	var hint := _label("真出口 → 直走缺口", Vector3(0, 1.8, -60), 22)
	var decoy := DECOY_GOAL.new()
	decoy.name = "CheshireDecoy"
	decoy.position = Vector3(-3.5, 0, -60)
	decoy.meme_id = "cheshire_decoy"
	decoy.telegraph_meme_id = "cheshire_again"
	decoy.real_exit_hint_path = decoy.get_path_to(hint)
	add_child(decoy)

	# Discern Skill Golden Halo on real path (visible when sheep skill is possessed)
	_discern_halo = Node3D.new()
	_discern_halo.position = Vector3(0, 1.2, -60.0)
	var halo_mesh := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.0
	ring.outer_radius = 1.25
	halo_mesh.mesh = ring
	halo_mesh.rotation.x = PI * 0.5
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = STORYBOOK_GOLD
	h_mat.emission_enabled = true
	h_mat.emission = STORYBOOK_GOLD * 1.5
	h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mesh.material_override = h_mat
	_discern_halo.add_child(halo_mesh)
	_label("【洞察之眸】识破真途 →", Vector3(0, 2.2, -60.0), 20, _discern_halo)
	_discern_halo.visible = false
	add_child(_discern_halo)

func _build_decorations() -> void:
	# Flag garlands
	_build_flag_garland(Vector3(-4.0, 3.2, 0.0), Vector3(4.0, 3.2, 0.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -50.0), Vector3(4.0, 3.2, -50.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -68.0), Vector3(4.0, 3.2, -68.0))
	_build_flag_garland(Vector3(-5.0, 3.8, -94.0), Vector3(5.0, 3.8, -94.0))

	# Hazard warning stripes
	_build_hazard_stripes(Vector3(0, 0.05, -50.0), Vector3(8.0, 0.06, 1.2))
	_build_hazard_stripes(Vector3(0, 0.05, -71.5), Vector3(4.5, 0.06, 1.2))

	# Chevron arrows
	for z in [-4.0, -23.5, -51.0, -65.0, -92.0]:
		_build_chevron_arrow(Vector3(0, 0.06, z))

	# Victory finish floral archway
	var finish_arch := StaticBody3D.new()
	finish_arch.collision_layer = 1
	finish_arch.collision_mask = 0
	_add_box_mesh(finish_arch, Vector3(0.6, 4.2, 0.6), Vector3(-4.5, 2.1, -94.0), STORYBOOK_WOOD)
	_add_box_mesh(finish_arch, Vector3(0.6, 4.2, 0.6), Vector3(4.5, 2.1, -94.0), STORYBOOK_WOOD)
	_add_box_mesh(finish_arch, Vector3(9.6, 0.6, 0.6), Vector3(0, 4.2, -94.0), STORYBOOK_GREEN)
	add_child(finish_arch)
	_label("★ 童话绘本终点 · FINISH ★", Vector3(0, 5.0, -94.0), 30)

func _build_flag_garland(pos_a: Vector3, pos_b: Vector3) -> void:
	var count := 7
	var colors := [STORYBOOK_CORAL, STORYBOOK_GOLD, STORYBOOK_GREEN, STORYBOOK_PURPLE]
	for i in count:
		var t := (i + 0.5) / float(count)
		var p := pos_a.lerp(pos_b, t)
		p.y -= sin(t * PI) * 0.35
		var flag := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.45, 0.45, 0.04)
		flag.mesh = prism
		flag.rotation.x = PI
		flag.position = p
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		flag.material_override = mat
		add_child(flag)

func _build_hazard_stripes(pos: Vector3, size: Vector3) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	body.mesh = box
	body.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STORYBOOK_GOLD
	body.material_override = mat
	add_child(body)

func _build_chevron_arrow(pos: Vector3) -> void:
	var arrow := Label3D.new()
	arrow.text = "▲"
	arrow.font_size = 40
	arrow.position = pos
	arrow.rotation.x = -PI * 0.5
	arrow.modulate = STORYBOOK_GOLD
	arrow.outline_modulate = DARK
	arrow.outline_size = 4
	add_child(arrow)

func _build_exit() -> void:
	var lux_pipe := ASSETS.make("PROP_C1_PIPE")
	if lux_pipe:
		lux_pipe.position = Vector3(0, 0, -98)
		add_child(lux_pipe)
	else:
		var pipe := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.6
		cyl.bottom_radius = 1.6
		cyl.height = 2.4
		pipe.mesh = cyl
		pipe.rotation.x = deg_to_rad(90.0)
		pipe.position = Vector3(0, 1.4, -98)
		var pipe_mat := StandardMaterial3D.new()
		pipe_mat.albedo_color = Color("2E7D32")
		pipe.material_override = pipe_mat
		add_child(pipe)

	_solid_box("ExitPostL", Vector3(0.6, 3, 0.6), Vector3(-3, 1.5, -98), STORYBOOK_WOOD)
	_solid_box("ExitPostR", Vector3(0.6, 3, 0.6), Vector3(3, 1.5, -98), STORYBOOK_WOOD)
	_label("直通烈马赛道 · 胜利水管 ↑", Vector3(0, 3.4, -98), 28)
	_label("（冲入水管直达马场看台！）", Vector3(0, 2.6, -98), 18)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, -2), Vector3(8, 3, 2))
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -50), Vector3(0, 0.6, -50))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -68), Vector3(0, 0.6, -68))
	_area("CourseExit", "course_exit", Vector3(0, 1, -98), Vector3(8, 3, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 3))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	_label("◆ 童话检查点", pos + Vector3(0, 1.6, 0), 18)

func _solid_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_add_box_mesh(body, size, Vector3.ZERO, color)
	add_child(body)
	return body

func _add_box_mesh(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material_override = mat
	parent.add_child(mesh)

func _label(text: String, pos: Vector3, font_size: int, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.modulate = CREAM
	label.outline_modulate = DARK
	label.outline_size = 6
	(parent if parent else self).add_child(label)
	return label

func _area(node_name: String, group: String, pos: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	if not group.is_empty():
		area.add_to_group(group)
	add_child(area)
	return area
