extends Node3D

const ASSETS = preload("res://scripts/art/asset_library.gd")
const RUNNER_SCRIPT = preload("res://scripts/courses/course_runner.gd")
const MEME_SCRIPT = preload("res://scripts/courses/meme_layer.gd")
const CONFIG_SCRIPT = preload("res://scripts/courses/course_config.gd")
const LAUNCH_PAD = preload("res://scripts/courses/components/launch_pad.gd")
const SPIN_HAMMER = preload("res://scripts/courses/components/spin_hammer.gd")
const FAKE_FLOOR = preload("res://scripts/courses/components/fake_floor.gd")
const DECOY_GOAL = preload("res://scripts/courses/components/decoy_goal.gd")
const SPINNING_SWEEPER = preload("res://scripts/courses/components/spinning_sweeper.gd")
const BUMPER_PILLAR = preload("res://scripts/courses/components/bumper_pillar.gd")
const DOOR_DASH = preload("res://scripts/courses/components/door_dash_gate.gd")
const PENDULUM_BALL = preload("res://scripts/courses/components/pendulum_ball.gd")
const SEESAW = preload("res://scripts/courses/components/seesaw_platform.gd")

const SPAWN := Vector3(0, 0.6, 6)
const NEON_PINK := Color("FF1493") # Hot pink
const NEON_YELLOW := Color("FDE047") # Bright yellow
const NEON_PURPLE := Color("8B5CF6") # Bright purple
const NEON_CYAN := Color("00E5FF") # Electric cyan
const NEON_ORANGE := Color("FB923C") # Orange candy
const GOLD_CROWN := Color("F59E0B") # Golden crown
const ARENA_DARK := Color("1E1B4B") # Deep indigo floor
const CREAM := Color("FFFFFF")

var runner: CourseRunner
var meme_layer: MemeLayer
var _crown: Node3D

func _ready() -> void:
	_build_ground()
	_build_surroundings()
	_build_launch_pads()
	_build_bumpers()
	_build_seesaw()
	_build_door_dash()
	_build_double_sweepers()
	_build_pendulums()
	_build_decoy_wall()
	_build_crown()
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

func _process(delta: float) -> void:
	if is_instance_valid(_crown):
		_crown.rotation.y += delta * 1.5

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_4"
	cfg.title = "大院隐藏闯关 · 糖豆人终极试炼"
	cfg.desc = "荧光霓虹狂欢！双层旋转大扫荡、倾斜平衡跷跷板、终极飞天夺冠！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-35, -16, -115), Vector3(70, 40, 135))
	cfg.dog_count = 1
	cfg.dog_speed_min = 3.0
	cfg.dog_speed_max = 6.4
	cfg.memes = {
		"course_start": {"title": "终极综艺擂台开启！", "text": "画风突变！糖豆人压轴狂欢！全速冲刺夺冠！", "duration": 3.0},
		"launch_pad": {"title": "飞天大弹射！", "text": "超高弹跳！直接飞越霓虹障碍！", "duration": 2.2},
		"super_bounce": {"title": "综艺大逆袭！", "text": "跌落深渊？强力弹簧瞬间将你送回跑道顶端！", "duration": 2.5},
		"bumper_hit": {"title": "疯狂弹珠！", "text": "高弹性充气柱连环反弹！根本停不下来！", "duration": 2.0},
		"seesaw_tilt": {"title": "天平倾斜！", "text": "跷跷板失去平衡！开动疾风冲刺快速通过！", "duration": 2.2},
		"double_sweeper_hit": {"title": "上下夹击！", "text": "双层反向横木！起跳时机要把握好！", "duration": 2.2},
		"pendulum_hit": {"title": "霓虹巨锤砸落！", "text": "被超级大摆锤轰出了跑道！", "duration": 2.2},
		"door_bonk": {"title": "硬核焊死！", "text": "这扇门是实心铁板！快换旁边的门撞！", "duration": 2.0},
		"door_dash_break": {"title": "欧皇本皇！", "text": "一头撞碎糖豆人薄皮门！势不可挡！", "duration": 2.4},
		"decoy_goal": {"title": "假皇冠假门！", "text": "画饼充不了饥！真出口是正前方直行！", "duration": 3.0},
		"decoy_again": {"title": "还想撞假门？", "text": "别被霓虹灯晃花了眼！直走才是真路！", "duration": 2.0},
		"crown_grab": {"title": "抢夺金色皇冠！", "text": "抓住终极皇冠！你就是金牌农场的终极先驱！", "duration": 3.0},
		"dog_bonk": {"title": "恶犬扑空", "text": "综艺舞台上，狗子也成了气氛组！", "duration": 2.0},
		"qte_success": {"title": "金牌挣脱！", "text": "阿牛之力爆发：狂暴挣脱，绝地反超！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "滑稽翻滚……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "综艺复活", "text": "礼花绽放！从检查点再次发起冲刺！", "duration": 2.2},
	}
	return cfg

func _build_ground() -> void:
	# 1. Start Terrace (Vibrant yellow with neon pink rim)
	_neon_platform("StartTerrace", Vector3(16, 1, 16), Vector3(0, -0.5, 4), NEON_YELLOW, NEON_PINK)

	# 2. Path A (Neon Cyan runner with purple center)
	_neon_platform("PathA", Vector3(8, 1, 26), Vector3(0, -0.5, -17), NEON_CYAN, NEON_PURPLE)

	# 3. Lower Ball Pit / Recovery Path
	_neon_platform("LowerBallPit", Vector3(10, 1, 14), Vector3(0, -4.0, -36), NEON_PURPLE, NEON_PINK)

	# 4. Ramp Back
	var ramp := _solid_box("RampBack", Vector3(8, 0.5, 6.95), Vector3(0, -1.966, -46.126), NEON_ORANGE)
	ramp.rotation.x = deg_to_rad(30.26)

	# 5. Path B (Neon Pink track)
	_neon_platform("PathB", Vector3(8, 1, 21), Vector3(0, -0.5, -59.5), NEON_PINK, NEON_YELLOW)

	# 6. Gauntlet Hammer Bridge
	_neon_platform("GauntletBridge", Vector3(4.5, 1, 22), Vector3(0, -0.5, -81), NEON_CYAN, NEON_PURPLE)

	# 7. Exit Terrace (Victory Platform)
	_neon_platform("ExitTerrace", Vector3(12, 1, 12), Vector3(0, -0.5, -98), NEON_YELLOW, NEON_PINK)

	# Checkered lines and signs
	_build_checker_line(2.0, 8.0)
	_build_checker_line(-92.8, 8.0)
	_label("大院隐藏闯关 · 糖豆人终极试炼", Vector3(0, 2.4, 9), 26)
	_label("空格跳跃 / Shift 冲刺 / WASD 移动 / 勇夺终极皇冠", Vector3(0, 1.6, 1), 18)

func _build_checker_line(z: float, width: float) -> void:
	for row in 2:
		for i in int(width):
			var color := CREAM if (i + row) % 2 == 0 else ARENA_DARK
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

func _neon_platform(node_name: String, size: Vector3, pos: Vector3, top_color: Color, rim_color: Color) -> StaticBody3D:
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

	_add_box_mesh(body, Vector3(size.x, size.y - 0.16, size.z), Vector3(0, -0.08, 0), rim_color)
	_add_box_mesh(body, Vector3(size.x + 0.2, 0.16, size.z), Vector3(0, size.y * 0.5 - 0.08, 0), top_color)
	add_child(body)
	return body

func _build_surroundings() -> void:
	# Gameshow arena grandstands & neon floodlight towers
	for z in [4.0, -14.0, -32.0, -50.0, -68.0, -86.0]:
		for side in [-1.0, 1.0]:
			var tower_x: float = side * 10.0
			_build_floodlight_tower(Vector3(tower_x, 0, z))

	# Giant floating neon balloons
	_build_balloon(Vector3(-14, 12, -25), NEON_PINK, 2.5)
	_build_balloon(Vector3(14, 14, -45), NEON_CYAN, 2.8)
	_build_balloon(Vector3(-15, 13, -75), NEON_YELLOW, 2.2)

func _build_floodlight_tower(pos: Vector3) -> void:
	var tower := Node3D.new()
	tower.position = pos
	_add_box_mesh(tower, Vector3(0.8, 6.0, 0.8), Vector3(0, 3.0, 0), ARENA_DARK)
	var light := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.8, 1.2)
	light.mesh = box
	light.position = Vector3(0, 6.0, 0)
	var l_mat := StandardMaterial3D.new()
	l_mat.albedo_color = NEON_YELLOW
	l_mat.emission_enabled = true
	l_mat.emission = NEON_YELLOW * 1.5
	light.material_override = l_mat
	tower.add_child(light)
	add_child(tower)

func _build_balloon(pos: Vector3, color: Color, radius: float) -> void:
	var balloon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.2
	balloon.mesh = sphere
	balloon.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = color * 0.4
	balloon.material_override = mat
	add_child(balloon)

func _build_launch_pads() -> void:
	# Launch pad 1 on Path A
	var pad := LAUNCH_PAD.new()
	pad.name = "NeonLaunchPad"
	pad.position = Vector3(0, 0, -10)
	pad.launch_direction = Vector3(0, 0, -1)
	pad.launch_power = 9.0
	pad.launch_up = 6.5
	pad.pad_color = NEON_PINK
	pad.meme_id = "launch_pad"
	add_child(pad)
	_label("▲ 荧光弹射垫 ▲", Vector3(0, 1.6, -10), 18)

	# Super bounce pad in lower ball pit
	var super_pad := LAUNCH_PAD.new()
	super_pad.name = "SuperArenaPad"
	super_pad.position = Vector3(0, -3.5, -40)
	super_pad.launch_direction = Vector3(0, 0, -1)
	super_pad.launch_power = 9.5
	super_pad.launch_up = 12.0
	super_pad.pad_color = NEON_YELLOW
	super_pad.meme_id = "super_bounce"
	add_child(super_pad)
	_label("★ 超级大逆袭 · 强力重返 ★", Vector3(0, -1.8, -40), 20)

func _build_bumpers() -> void:
	# Diamond Bumper Pinball cluster on Path A
	var b1 := BUMPER_PILLAR.new()
	b1.name = "ArenaBumper1"
	b1.position = Vector3(-2.4, 0, -13.5)
	b1.bumper_color = NEON_PINK
	b1.cap_color = NEON_YELLOW
	add_child(b1)

	var b2 := BUMPER_PILLAR.new()
	b2.name = "ArenaBumper2"
	b2.position = Vector3(2.4, 0, -13.5)
	b2.bumper_color = NEON_PINK
	b2.cap_color = NEON_YELLOW
	add_child(b2)

	var b3 := BUMPER_PILLAR.new()
	b3.name = "ArenaBumper3"
	b3.position = Vector3(0.0, 0, -16.5)
	b3.bumper_color = NEON_CYAN
	b3.cap_color = NEON_PINK
	add_child(b3)
	_label("★ 霓虹充气立柱阵 ★", Vector3(0, 1.8, -15.0), 18)

func _build_seesaw() -> void:
	var seesaw := SEESAW.new()
	seesaw.name = "ArenaSeesaw"
	seesaw.position = Vector3(0, 0, -37.0)
	seesaw.plank_size = Vector3(7.5, 0.4, 12.0)
	seesaw.plank_color = NEON_CYAN
	seesaw.edge_color = NEON_PINK
	seesaw.meme_id = "seesaw_tilt"
	add_child(seesaw)
	_label("疯狂跷跷板 · 注意平衡！", Vector3(0, 1.6, -31.5), 20)

func _build_door_dash() -> void:
	var door_gate := DOOR_DASH.new()
	door_gate.name = "NeonDoorGate"
	door_gate.position = Vector3(0, 0, -26.5)
	door_gate.breakable_index = 1 # Center door is breakable
	door_gate.door_colors = [NEON_CYAN, NEON_PINK, NEON_YELLOW]
	add_child(door_gate)

func _build_double_sweepers() -> void:
	# Low sweeper 1
	var sw1 := SPINNING_SWEEPER.new()
	sw1.name = "DoubleSweeperLow"
	sw1.position = Vector3(0, 0, -74.0)
	sw1.rotate_speed = 2.4
	sw1.bar_length = 4.2
	sw1.bar_elevation = 0.35 # Jump over
	sw1.knockback_power = 7.0
	sw1.knockback_up = 3.2
	sw1.sweeper_color = NEON_PINK
	sw1.meme_id = "double_sweeper_hit"
	add_child(sw1)

	# High counter-rotating sweeper 2
	var sw2 := SPINNING_SWEEPER.new()
	sw2.name = "DoubleSweeperHigh"
	sw2.position = Vector3(0, 0, -82.0)
	sw2.rotate_speed = -2.6
	sw2.bar_length = 4.2
	sw2.bar_elevation = 0.45
	sw2.knockback_power = 7.5
	sw2.knockback_up = 3.6
	sw2.sweeper_color = NEON_CYAN
	sw2.meme_id = "double_sweeper_hit"
	add_child(sw2)
	_label("双层反向扫荡机 · 空格起跳！", Vector3(0, 2.2, -72.0), 20)

func _build_pendulums() -> void:
	var pendulum := PENDULUM_BALL.new()
	pendulum.name = "DiscoPendulum"
	pendulum.position = Vector3(0, 0, -88.0)
	pendulum.swing_speed = 2.8
	pendulum.max_angle_deg = 45.0
	pendulum.knockback_power = 8.5
	pendulum.knockback_up = 4.2
	pendulum.ball_color = NEON_PINK
	pendulum.meme_id = "pendulum_hit"
	add_child(pendulum)
	_label("★ 霓虹迪斯科巨摆 ★", Vector3(0, 3.8, -88.0), 18)

func _build_decoy_wall() -> void:
	var wall_l := _solid_box("NeonWallL", Vector3(5, 3.4, 0.6), Vector3(-3.5, 1.7, -61), ARENA_DARK)
	var wall_r := _solid_box("NeonWallR", Vector3(5, 3.4, 0.6), Vector3(3.5, 1.7, -61), ARENA_DARK)

	var painted := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.8)
	painted.mesh = quad
	painted.position = Vector3(-3.5, 1.7, -60.6)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = NEON_PINK
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	painted.material_override = glow
	add_child(painted)
	_label("冠军之门 EXIT", Vector3(-3.5, 2.6, -60.45), 36)

	var hint := _label("真出口 → 直走缺口", Vector3(0, 1.8, -60), 22)
	var decoy := DECOY_GOAL.new()
	decoy.name = "DecoyArenaGate"
	decoy.position = Vector3(-3.5, 0, -60)
	decoy.meme_id = "decoy_goal"
	decoy.telegraph_meme_id = "decoy_again"
	decoy.real_exit_hint_path = decoy.get_path_to(hint)
	add_child(decoy)

func _build_crown() -> void:
	# Floating victory golden crown at z=-92
	_crown = Node3D.new()
	_crown.position = Vector3(0, 2.2, -92.0)
	var torus := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.75
	torus.mesh = ring
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = GOLD_CROWN
	c_mat.metallic = 0.8
	c_mat.roughness = 0.2
	c_mat.emission_enabled = true
	c_mat.emission = GOLD_CROWN * 0.8
	torus.material_override = c_mat
	_crown.add_child(torus)

	# Crown spikes
	for i in 5:
		var angle := i * (PI * 2.0 / 5.0)
		var spike := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.25, 0.45, 0.1)
		spike.mesh = prism
		spike.position = Vector3(cos(angle) * 0.65, 0.25, sin(angle) * 0.65)
		spike.rotation.y = -angle
		spike.material_override = c_mat
		_crown.add_child(spike)

	var crown_area := Area3D.new()
	crown_area.collision_layer = 0
	crown_area.collision_mask = 2
	var c_shape := CollisionShape3D.new()
	var c_box := BoxShape3D.new()
	c_box.size = Vector3(2.5, 2.5, 2.5)
	c_shape.shape = c_box
	crown_area.add_child(c_shape)
	crown_area.body_entered.connect(func(body: Node3D):
		if body is PigController and meme_layer:
			meme_layer.play("crown_grab", body.global_position)
	)
	_crown.add_child(crown_area)
	add_child(_crown)
	_label("👑 抢夺终极金皇冠 👑", Vector3(0, 3.4, -92.0), 22)

func _build_decorations() -> void:
	# Flag garlands
	_build_flag_garland(Vector3(-4.0, 3.2, 0.0), Vector3(4.0, 3.2, 0.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -50.0), Vector3(4.0, 3.2, -50.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -68.0), Vector3(4.0, 3.2, -68.0))
	_build_flag_garland(Vector3(-5.0, 3.8, -94.0), Vector3(5.0, 3.8, -94.0))

	# Hazard warning stripes
	_build_hazard_stripes(Vector3(0, 0.05, -50.0), Vector3(8.0, 0.06, 1.2))
	_build_hazard_stripes(Vector3(0, 0.05, -71.5), Vector3(4.5, 0.06, 1.2))

	# Chevrons
	for z in [-4.0, -23.5, -51.0, -65.0, -92.0]:
		_build_chevron_arrow(Vector3(0, 0.06, z))

	# Victory archway
	var finish_arch := StaticBody3D.new()
	finish_arch.collision_layer = 1
	finish_arch.collision_mask = 0
	_add_box_mesh(finish_arch, Vector3(0.6, 4.4, 0.6), Vector3(-4.5, 2.2, -94.0), NEON_PINK)
	_add_box_mesh(finish_arch, Vector3(0.6, 4.4, 0.6), Vector3(4.5, 2.2, -94.0), NEON_PINK)
	_add_box_mesh(finish_arch, Vector3(9.6, 0.6, 0.6), Vector3(0, 4.4, -94.0), NEON_YELLOW)
	add_child(finish_arch)
	_label("★ 夺冠终点 · VICTORY ★", Vector3(0, 5.2, -94.0), 32)

func _build_flag_garland(pos_a: Vector3, pos_b: Vector3) -> void:
	var count := 7
	var colors := [NEON_PINK, NEON_YELLOW, NEON_CYAN, NEON_PURPLE, NEON_ORANGE]
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
	mat.albedo_color = NEON_YELLOW
	body.material_override = mat
	add_child(body)

func _build_chevron_arrow(pos: Vector3) -> void:
	var arrow := Label3D.new()
	arrow.text = "▲"
	arrow.font_size = 40
	arrow.position = pos
	arrow.rotation.x = -PI * 0.5
	arrow.modulate = NEON_YELLOW
	arrow.outline_modulate = ARENA_DARK
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

	_solid_box("ExitPostL", Vector3(0.6, 3, 0.6), Vector3(-3, 1.5, -98), ARENA_DARK)
	_solid_box("ExitPostR", Vector3(0.6, 3, 0.6), Vector3(3, 1.5, -98), ARENA_DARK)
	_label("直通终极对决大铁门 · 胜利水管 ↑", Vector3(0, 3.4, -98), 28)
	_label("（冲入水管直达农场主对决台！）", Vector3(0, 2.6, -98), 18)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, -2), Vector3(8, 3, 2))
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -50), Vector3(0, 0.6, -50))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -68), Vector3(0, 0.6, -68))
	_area("CourseExit", "course_exit", Vector3(0, 1, -98), Vector3(8, 3, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 3))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	_label("◆ 冠军检查点", pos + Vector3(0, 1.6, 0), 18)

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
	mat.roughness = 0.5
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
	label.outline_modulate = ARENA_DARK
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
