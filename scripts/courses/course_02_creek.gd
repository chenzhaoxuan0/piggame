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
const VOXEL_TNT = preload("res://scripts/courses/components/voxel_tnt.gd")

const SPAWN := Vector3(0, 0.6, 6)
const VOXEL_BLUE := Color("38BDF8") # Water cyan
const VOXEL_GREEN := Color("4ADE80") # Pixel grass
const VOXEL_DIRT := Color("5A3E28") # Pixel dirt
const VOXEL_STONE := Color("78909C") # Cobblestone
const VOXEL_ICE := Color("93C5FD") # Slippery ice
const VOXEL_WOOD := Color("795548") # Oak log
const VOXEL_LEAF := Color("16A34A") # Leaf canopy
const VOXEL_PURPLE := Color("8B5CF6") # Nether portal
const VOXEL_GOLD := Color("FBBF24") # Gold block
const CREAM := Color("FFF8E7")
const DARK := Color("1E293B")

var runner: CourseRunner
var meme_layer: MemeLayer

func _ready() -> void:
	_build_ground()
	_build_surroundings()
	_build_launch_pads()
	_build_bumpers()
	_build_tnt_traps()
	_build_door_dash()
	_build_sand_collapse()
	_build_piston_sweepers()
	_build_pendulums()
	_build_decoy_portal()
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

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_2"
	cfg.title = "溪流隐藏闯关 · 像素方块大冒险"
	cfg.desc = "像素水流奔涌！小心踩空重力沙、躲避苦力怕TNT与红石活塞！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-35, -16, -115), Vector3(70, 40, 135))
	cfg.dog_count = 1
	cfg.dog_speed_min = 2.8
	cfg.dog_speed_max = 6.2
	cfg.memes = {
		"course_start": {"title": "像素世界加载完毕！", "text": "画风突变！欢迎来到方块溪谷，前方小心脚下！", "duration": 3.0},
		"launch_pad": {"title": "红石弹射！", "text": "高弹性方块！瞬间起跳越过水坑！", "duration": 2.2},
		"super_bounce": {"title": "史莱姆方块！", "text": "跌落谷底？超强黏性史莱姆送你重回跑道！", "duration": 2.5},
		"bumper_hit": {"title": "方块弹击！", "text": "撞上像素充气柱！弹飞两米远！", "duration": 2.0},
		"sand_telegraph": {"title": "沙子没有支撑！", "text": "脚下方块发出沙沙声……快跳开！", "duration": 2.0},
		"sand_collapse": {"title": "垂直向下挖的代价！", "text": "MC第一定律：千万别在脚下直接挖！", "duration": 2.8},
		"tnt_telegraph": {"title": "嘶嘶嘶……？", "text": "等等，脚下什么东西在冒烟点火？！", "duration": 2.0},
		"tnt_boom": {"title": "苦力怕之拥！", "text": "轰！非致死像素冲击波！芜湖起飞！", "duration": 2.6},
		"piston_hit": {"title": "红石活塞推击！", "text": "活塞节奏打点，直接横扫出局！", "duration": 2.2},
		"pendulum_hit": {"title": "体素铁砧巨摆！", "text": "左右摇摆的巨型体素钟摆！看准间隙冲！", "duration": 2.2},
		"door_bonk": {"title": "铁门紧锁！", "text": "没有红石信号！这扇门打不开！换一扇撞！", "duration": 2.0},
		"door_dash_break": {"title": "木门粉碎！", "text": "一头撞开脆皮橡木门！冲冲冲！", "duration": 2.4},
		"decoy_portal": {"title": "下界门未点火！", "text": "缺少打火石！充值 64 绿宝石才能进入下界！", "duration": 3.0},
		"decoy_again": {"title": "还想钻紫门？", "text": "真出口在正前方的绿色管道！", "duration": 2.0},
		"dog_bonk": {"title": "恶犬扑空", "text": "像素狗咬到了方块空气！", "duration": 2.0},
		"qte_success": {"title": "黑曜石挣脱！", "text": "阿牛坚忍：硬如黑曜石，震退恶犬！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "被甩飞了……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "重生点复活", "text": "像素猪毫发无损，重新整装出发！", "duration": 2.2},
	}
	return cfg

func _build_ground() -> void:
	# 1. Start Terrace (Voxel Green over Voxel Dirt)
	_voxel_platform("StartTerrace", Vector3(16, 1, 16), Vector3(0, -0.5, 4), VOXEL_GREEN, VOXEL_DIRT)

	# 2. Path A (Voxel Stream Track with central water flume)
	_voxel_platform("PathA", Vector3(8, 1, 26), Vector3(0, -0.5, -17), VOXEL_GREEN, VOXEL_DIRT)
	# Center blue water stream strip along Path A
	_voxel_box("WaterFlumeA", Vector3(3.2, 0.2, 24), Vector3(0, 0.02, -17), VOXEL_BLUE)

	# 3. Lower water canal path (below sand collapse)
	_voxel_platform("LowerCanal", Vector3(10, 1, 14), Vector3(0, -4.0, -36), VOXEL_BLUE, VOXEL_STONE)

	# 4. Ramp connecting lower canal back up to Path B
	var ramp := _solid_box("RampBack", Vector3(8, 0.5, 6.95), Vector3(0, -1.966, -46.126), VOXEL_WOOD)
	ramp.rotation.x = deg_to_rad(30.26)

	# 5. Path B (Ice & Cobblestone Path)
	_voxel_platform("PathB", Vector3(8, 1, 21), Vector3(0, -0.5, -59.5), VOXEL_ICE, VOXEL_STONE)

	# 6. Piston Bridge
	_voxel_platform("PistonBridge", Vector3(4.5, 1, 22), Vector3(0, -0.5, -81), VOXEL_STONE, VOXEL_DIRT)

	# 7. Exit Terrace
	_voxel_platform("ExitTerrace", Vector3(12, 1, 12), Vector3(0, -0.5, -98), VOXEL_GREEN, VOXEL_DIRT)

	# Checkered lines and signs
	_build_checker_line(2.0, 8.0)
	_build_checker_line(-92.8, 8.0)
	_label("溪流隐藏闯关 · 像素方块大冒险", Vector3(0, 2.4, 9), 26)
	_label("空格跳跃 / WASD 移动 / 躲避方块陷阱", Vector3(0, 1.6, 1), 18)

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

func _voxel_platform(node_name: String, size: Vector3, pos: Vector3, top_color: Color, sub_color: Color) -> StaticBody3D:
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

	# Sub soil/stone layer
	_add_box_mesh(body, Vector3(size.x, size.y - 0.2, size.z), Vector3(0, -0.1, 0), sub_color)
	# Stepped pixel top surface
	_add_box_mesh(body, Vector3(size.x, 0.2, size.z), Vector3(0, size.y * 0.5 - 0.1, 0), top_color)
	add_child(body)
	return body

func _voxel_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	return _solid_box(node_name, size, pos, color)

func _build_surroundings() -> void:
	# Voxel stepped terrain framing the track
	for z in [4.0, -12.0, -28.0, -44.0, -60.0, -76.0, -92.0]:
		for side in [-1.0, 1.0]:
			var cliff_x: float = side * 11.0
			# Stepped cubic cliffs
			_solid_box("VoxelCliff_%d_%d" % [int(z), int(side)], Vector3(8, 12, 12), Vector3(cliff_x, -4.0, z), VOXEL_STONE)
			_solid_box("VoxelCliffTop_%d_%d" % [int(z), int(side)], Vector3(8, 0.4, 12), Vector3(cliff_x, 2.2, z), VOXEL_GREEN)

	# Voxel Pine Trees on terrace perimeters
	_build_voxel_tree(Vector3(-7, 0, 11))
	_build_voxel_tree(Vector3(7, 0, 11))
	_build_voxel_tree(Vector3(-5, 0, -103))
	_build_voxel_tree(Vector3(5, 0, -103))
	_build_voxel_tree(Vector3(-11, 2.4, -40))
	_build_voxel_tree(Vector3(11, 2.4, -65))

	# Floating voxel clouds overhead
	_build_voxel_cloud(Vector3(-16, 12, -20))
	_build_voxel_cloud(Vector3(14, 14, -55))
	_build_voxel_cloud(Vector3(-12, 13, -80))

func _build_voxel_tree(pos: Vector3) -> void:
	var tree_root := Node3D.new()
	tree_root.position = pos
	# Trunk (wood block)
	_add_box_mesh(tree_root, Vector3(0.8, 2.4, 0.8), Vector3(0, 1.2, 0), VOXEL_WOOD)
	# Stepped pyramid leaf layers
	_add_box_mesh(tree_root, Vector3(3.2, 0.8, 3.2), Vector3(0, 2.4, 0), VOXEL_LEAF)
	_add_box_mesh(tree_root, Vector3(2.4, 0.8, 2.4), Vector3(0, 3.2, 0), VOXEL_LEAF)
	_add_box_mesh(tree_root, Vector3(1.4, 0.8, 1.4), Vector3(0, 4.0, 0), VOXEL_LEAF)
	add_child(tree_root)

func _build_voxel_cloud(pos: Vector3) -> void:
	var cloud := Node3D.new()
	cloud.position = pos
	_add_box_mesh(cloud, Vector3(10, 1.6, 6), Vector3(0, 0, 0), Color("FFFFFF"))
	_add_box_mesh(cloud, Vector3(6, 1.2, 4), Vector3(1.5, 1.0, 0), Color("F8FAFC"))
	add_child(cloud)

func _build_launch_pads() -> void:
	# Launch pad on Path A leaping over water hazard
	var pad := LAUNCH_PAD.new()
	pad.name = "PathALaunchPad"
	pad.position = Vector3(0, 0, -10)
	pad.launch_direction = Vector3(0, 0, -1)
	pad.launch_power = 8.5
	pad.launch_up = 6.2
	pad.pad_color = VOXEL_GOLD
	pad.meme_id = "launch_pad"
	add_child(pad)
	_label("▲ 红石弹射板 ▲", Vector3(0, 1.6, -10), 18)

	# Super Slime bounce pad in Lower Canal
	var super_pad := LAUNCH_PAD.new()
	super_pad.name = "SuperSlimePad"
	super_pad.position = Vector3(0, -3.5, -40)
	super_pad.launch_direction = Vector3(0, 0, -1)
	super_pad.launch_power = 9.0
	super_pad.launch_up = 11.5
	super_pad.pad_color = Color("22C55E") # Green slime
	super_pad.meme_id = "super_bounce"
	add_child(super_pad)
	_label("★ 黏性史莱姆块 · 弹射归队 ★", Vector3(0, -1.8, -40), 20)

func _build_bumpers() -> void:
	# Voxel Bumper Cluster on Path A
	var b1 := BUMPER_PILLAR.new()
	b1.name = "VoxelBumper1"
	b1.position = Vector3(-2.2, 0, -14.0)
	b1.bumper_color = VOXEL_BLUE
	b1.cap_color = VOXEL_GOLD
	add_child(b1)

	var b2 := BUMPER_PILLAR.new()
	b2.name = "VoxelBumper2"
	b2.position = Vector3(2.2, 0, -14.0)
	b2.bumper_color = VOXEL_BLUE
	b2.cap_color = VOXEL_GOLD
	add_child(b2)

	var b3 := BUMPER_PILLAR.new()
	b3.name = "VoxelBumper3"
	b3.position = Vector3(0.0, 0, -16.8)
	b3.bumper_color = VOXEL_GREEN
	b3.cap_color = Color("EF4444")
	add_child(b3)
	_label("★ 像素充气立柱 ★", Vector3(0, 1.8, -15.4), 18)

func _build_tnt_traps() -> void:
	# Voxel TNT trap 1
	var tnt1 := VOXEL_TNT.new()
	tnt1.name = "VoxelTNT1"
	tnt1.position = Vector3(-1.8, 0, -52.0)
	tnt1.meme_id = "tnt_boom"
	tnt1.telegraph_meme_id = "tnt_telegraph"
	add_child(tnt1)

	# Voxel TNT trap 2
	var tnt2 := VOXEL_TNT.new()
	tnt2.name = "VoxelTNT2"
	tnt2.position = Vector3(1.8, 0, -56.0)
	tnt2.meme_id = "tnt_boom"
	tnt2.telegraph_meme_id = "tnt_telegraph"
	add_child(tnt2)
	_label("⚠ 危险：苦力怕 TNT 压力板 ⚠", Vector3(0, 2.2, -54.0), 18)

func _build_door_dash() -> void:
	var door_gate := DOOR_DASH.new()
	door_gate.name = "VoxelDoorGate"
	door_gate.position = Vector3(0, 0, -26.5)
	door_gate.breakable_index = 2 # Right door is breakable oak door
	door_gate.door_colors = [VOXEL_WOOD, VOXEL_STONE, VOXEL_GREEN]
	add_child(door_gate)

func _build_sand_collapse() -> void:
	var sand_tile := FAKE_FLOOR.new()
	sand_tile.name = "VoxelSandBridge"
	sand_tile.position = Vector3(0, 0, -37)
	sand_tile.tile_size = Vector3(8, 0.3, 12)
	sand_tile.tile_color = Color("FDE047") # Sand yellow
	sand_tile.trigger_delay = 0.45
	sand_tile.meme_id = "sand_collapse"
	sand_tile.telegraph_meme_id = "sand_telegraph"
	add_child(sand_tile)
	_label("重力沙桥 · 前方小心下坠", Vector3(0, 1.6, -31.5), 20)

func _build_piston_sweepers() -> void:
	# Piston sweeper 1
	var sw1 := SPINNING_SWEEPER.new()
	sw1.name = "PistonSweeper1"
	sw1.position = Vector3(0, 0, -74.0)
	sw1.rotate_speed = 2.1
	sw1.bar_length = 4.2
	sw1.bar_elevation = 0.35
	sw1.knockback_power = 6.8
	sw1.knockback_up = 3.2
	sw1.sweeper_color = Color("EF4444") # Redstone red
	sw1.meme_id = "piston_hit"
	add_child(sw1)

	# Piston sweeper 2
	var sw2 := SPINNING_SWEEPER.new()
	sw2.name = "PistonSweeper2"
	sw2.position = Vector3(0, 0, -82.0)
	sw2.rotate_speed = -2.3
	sw2.bar_length = 4.2
	sw2.bar_elevation = 0.35
	sw2.knockback_power = 7.0
	sw2.knockback_up = 3.5
	sw2.sweeper_color = Color("EF4444")
	sw2.meme_id = "piston_hit"
	add_child(sw2)
	_label("红石活塞横木 · 跳跃躲避！", Vector3(0, 2.2, -72.0), 20)

func _build_pendulums() -> void:
	var pendulum := PENDULUM_BALL.new()
	pendulum.name = "VoxelAnvilPendulum"
	pendulum.position = Vector3(0, 0, -88.0)
	pendulum.swing_speed = 2.7
	pendulum.max_angle_deg = 42.0
	pendulum.knockback_power = 8.5
	pendulum.knockback_up = 4.0
	pendulum.ball_color = Color("475569") # Iron anvil slate
	pendulum.meme_id = "pendulum_hit"
	add_child(pendulum)
	_label("★ 像素巨锤钟摆 ★", Vector3(0, 3.8, -88.0), 18)

func _build_decoy_portal() -> void:
	# Nether portal decoy wall
	var wall_l := _solid_box("NetherWallL", Vector3(5, 3.4, 0.6), Vector3(-3.5, 1.7, -61), Color("1E1B4B"))
	var wall_r := _solid_box("NetherWallR", Vector3(5, 3.4, 0.6), Vector3(3.5, 1.7, -61), Color("1E1B4B"))

	# Glowing purple portal quad
	var portal_mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.8)
	portal_mesh.mesh = quad
	portal_mesh.position = Vector3(-3.5, 1.7, -60.6)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = VOXEL_PURPLE
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	portal_mesh.material_override = glow
	add_child(portal_mesh)
	_label("下界传送门 EXIT", Vector3(-3.5, 2.6, -60.45), 36)

	var hint := _label("真出口 → 直走缺口", Vector3(0, 1.8, -60), 22)
	var decoy := DECOY_GOAL.new()
	decoy.name = "NetherPortalDecoy"
	decoy.position = Vector3(-3.5, 0, -60)
	decoy.meme_id = "decoy_portal"
	decoy.telegraph_meme_id = "decoy_again"
	decoy.real_exit_hint_path = decoy.get_path_to(hint)
	add_child(decoy)

func _build_decorations() -> void:
	# Pixel flag garlands
	_build_flag_garland(Vector3(-4.0, 3.2, 0.0), Vector3(4.0, 3.2, 0.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -50.0), Vector3(4.0, 3.2, -50.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -68.0), Vector3(4.0, 3.2, -68.0))
	_build_flag_garland(Vector3(-5.0, 3.8, -94.0), Vector3(5.0, 3.8, -94.0))

	# Hazard warning tiles
	_build_hazard_stripes(Vector3(0, 0.05, -50.0), Vector3(8.0, 0.06, 1.2))
	_build_hazard_stripes(Vector3(0, 0.05, -71.5), Vector3(4.5, 0.06, 1.2))

	# Pixel arrows on ground
	for z in [-4.0, -23.5, -51.0, -65.0, -92.0]:
		_build_chevron_arrow(Vector3(0, 0.06, z))

	# Finish archway
	var finish_arch := StaticBody3D.new()
	finish_arch.collision_layer = 1
	finish_arch.collision_mask = 0
	_add_box_mesh(finish_arch, Vector3(0.8, 4.2, 0.8), Vector3(-4.5, 2.1, -94.0), VOXEL_WOOD)
	_add_box_mesh(finish_arch, Vector3(0.8, 4.2, 0.8), Vector3(4.5, 2.1, -94.0), VOXEL_WOOD)
	_add_box_mesh(finish_arch, Vector3(9.8, 0.8, 0.8), Vector3(0, 4.2, -94.0), VOXEL_GOLD)
	add_child(finish_arch)
	_label("★ 像素关卡通关 · FINISH ★", Vector3(0, 5.0, -94.0), 30)

func _build_flag_garland(pos_a: Vector3, pos_b: Vector3) -> void:
	var count := 7
	var colors := [Color("38BDF8"), Color("4ADE80"), Color("FBBF24"), Color("EF4444"), Color("8B5CF6")]
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
	mat.albedo_color = Color("F59E0B")
	body.material_override = mat
	add_child(body)

func _build_chevron_arrow(pos: Vector3) -> void:
	var arrow := Label3D.new()
	arrow.text = "▲"
	arrow.font_size = 40
	arrow.position = pos
	arrow.rotation.x = -PI * 0.5
	arrow.modulate = Color("F59E0B")
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

	_solid_box("ExitPostL", Vector3(0.6, 3, 0.6), Vector3(-3, 1.5, -98), VOXEL_WOOD)
	_solid_box("ExitPostR", Vector3(0.6, 3, 0.6), Vector3(3, 1.5, -98), VOXEL_WOOD)
	_label("直通小羊矮棚 · 胜利水管 ↑", Vector3(0, 3.4, -98), 28)
	_label("（冲入水管直达小羊草甸！）", Vector3(0, 2.6, -98), 18)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, -2), Vector3(8, 3, 2))
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -50), Vector3(0, 0.6, -50))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -68), Vector3(0, 0.6, -68))
	_area("CourseExit", "course_exit", Vector3(0, 1, -98), Vector3(8, 3, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 3))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	_label("◆ 像素重生点", pos + Vector3(0, 1.6, 0), 18)

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
