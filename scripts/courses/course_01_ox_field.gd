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

const SPAWN := Vector3(0, 0.6, 6)
const CREAM := Color("E1DDC5")
const GRASS := Color("74A87C")
const LOAM := Color("3E2723")
const WOOD := Color("8D7B68")
const STRAW := Color("F59E0B")
const PIPE_GREEN := Color("2E7D32")
const HAZARD_YELLOW := Color("F1C40F")
const HAZARD_DARK := Color("2C3E50")

var runner: CourseRunner
var meme_layer: MemeLayer

func _ready() -> void:
	_build_ground()
	_build_ox_npc()
	_build_launch_pads()
	_build_bumpers()
	_build_question_block()
	_build_door_dash()
	_build_fake_floor_bridge()
	_build_sweepers()
	_build_pendulums()
	_build_decoy_wall()
	_build_hammer_bridge()
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
	cfg.course_id = "course_1"
	cfg.title = "牛耕地隐藏闯关 · 糖豆人试炼"
	cfg.desc = "飞越弹簧垫、顶问号砖、撞开幸运门、躲避扫堂腿与大摆锤！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-30, -16, -112), Vector3(60, 40, 132))
	cfg.dog_count = 1
	cfg.dog_speed_min = 2.6
	cfg.dog_speed_max = 6.0
	cfg.memes = {
		"course_start": {"title": "隐藏赛道开启！", "text": "阿牛：你居然发现了秘密管道！往前冲！", "duration": 3.0},
		"launch_pad": {"title": "芜湖起飞！", "text": "糖豆人弹簧弹射！飞越泥潭！", "duration": 2.2},
		"super_bounce": {"title": "绝处逢生！", "text": "跌落谷底？强力弹簧直接送你重回跑道！", "duration": 2.5},
		"bumper_hit": {"title": "Duang！", "text": "弹力充气柱！弹飞旋转！", "duration": 2.0},
		"question_block_telegraph": {"title": "问号砖", "text": "顶一下，必有惊喜（确信）", "duration": 2.0},
		"question_block": {"title": "鸡汤来咯！", "text": "草垛出笼！快跳开！", "duration": 2.8},
		"door_bonk": {"title": "哎呀！", "text": "这扇门是焊死的！换一扇撞！", "duration": 2.0},
		"door_dash_break": {"title": "欧皇附体！", "text": "一头撞开脆皮门！冲冲冲！", "duration": 2.4},
		"fake_floor_telegraph": {"title": "康庄大道", "text": "这路又宽又平，稳得很", "duration": 2.0},
		"fake_floor": {"title": "宫崎英高的微笑", "text": "前方绝景，敬请见证", "duration": 2.8},
		"sweeper_hit": {"title": "扫堂腿！", "text": "低空横木扫过来啦！记得按空格跳！", "duration": 2.2},
		"pendulum_hit": {"title": "大摆锤八十！", "text": "左右摇摆的大铁球！抓准时机冲！", "duration": 2.2},
		"decoy_goal": {"title": "我信你个鬼", "text": "这出口是画上去的！真出口是直走的缺口！", "duration": 3.0},
		"decoy_again": {"title": "还想撞？", "text": "画饼充不了饥，假门进不去", "duration": 2.0},
		"hammer_rhythm": {"title": "大锤节奏阵", "text": "跟着节奏走位！", "rhythm": ["退！", "退！", "退！"], "interval": 0.55, "cooldown": 4.0},
		"hammer_hit": {"title": "大锤八十！", "text": "大锤八十，小锤四十！", "duration": 2.0},
		"dog_bonk": {"title": "恶犬扑空", "text": "没技能？那就滚一圈再说", "duration": 2.0},
		"qte_success": {"title": "坚韧挣脱！", "text": "阿牛之力：咬紧牙关，震退恶犬！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "被甩出去了……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "摔了个猪啃泥", "text": "没事，检查点重来，猪没事", "duration": 2.2},
	}
	return cfg

func _build_ground() -> void:
	_solid_box("StartTerrace", Vector3(16, 1, 16), Vector3(0, -0.5, 4), GRASS)
	_solid_box("PathA", Vector3(8, 1, 26), Vector3(0, -0.5, -17), GRASS)
	_solid_box("LowerPath", Vector3(10, 1, 18), Vector3(0, -4.0, -38), LOAM)
	var ramp := _solid_box("RampBack", Vector3(8, 0.5, 9.0), Vector3(0, -2.0, -46), WOOD)
	ramp.rotation.x = deg_to_rad(30.0)
	_solid_box("PathB", Vector3(8, 1, 22), Vector3(0, -0.5, -60), GRASS)
	_solid_box("HammerBridge", Vector3(4, 1, 22), Vector3(0, -0.5, -81), WOOD)
	_solid_box("ExitTerrace", Vector3(12, 1, 14), Vector3(0, -0.5, -97), GRASS)
	_label("牛耕地隐藏闯关 · 糖豆人试炼", Vector3(0, 2.4, 9), 26)
	_label("空格跳跃 / WASD 移动 / Shift 闪避", Vector3(0, 1.6, 1), 18)

func _build_ox_npc() -> void:
	var body := StaticBody3D.new()
	body.name = "NPC_ox"
	body.position = Vector3(-4, 0, 6)
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("interaction_id", "ox")
	body.add_to_group("interactable")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.85, 1.2, 0.85)
	shape.shape = box
	shape.position.y = 0.6
	body.add_child(shape)
	body.add_child(ASSETS.make("CHAR_03"))
	body.rotation.y = PI
	_label("阿牛 · 卸下重负传你力气", Vector3(0, 2.2, 0), 22, body)
	add_child(body)

func _build_launch_pads() -> void:
	# Launch pad on PathA
	var pad := LAUNCH_PAD.new()
	pad.name = "PathALaunchPad"
	pad.position = Vector3(0, 0, -10)
	pad.launch_direction = Vector3(0, 0, -1)
	pad.launch_power = 8.5
	pad.launch_up = 6.0
	pad.meme_id = "launch_pad"
	add_child(pad)
	_label("▲ 弹力跳板 ▲", Vector3(0, 1.6, -10), 18)

	# Super bounce pad on LowerPath (falls from FakeFloor)
	var super_pad := LAUNCH_PAD.new()
	super_pad.name = "SuperBouncePad"
	super_pad.position = Vector3(0, -3.5, -40)
	super_pad.launch_direction = Vector3(0, 0, -1)
	super_pad.launch_power = 9.0
	super_pad.launch_up = 11.5
	super_pad.pad_color = Color("FF3366")
	super_pad.meme_id = "super_bounce"
	add_child(super_pad)
	_label("★ 超级弹簧 · 逆袭重返 ★", Vector3(0, -1.8, -40), 20)

func _build_bumpers() -> void:
	# Bumper Pinball cluster on PathA
	var b1 := BUMPER_PILLAR.new()
	b1.name = "Bumper1"
	b1.position = Vector3(-2.2, 0, -13.5)
	b1.bumper_color = Color("FF1493")
	add_child(b1)

	var b2 := BUMPER_PILLAR.new()
	b2.name = "Bumper2"
	b2.position = Vector3(2.2, 0, -13.5)
	b2.bumper_color = Color("FF1493")
	add_child(b2)

	var b3 := BUMPER_PILLAR.new()
	b3.name = "Bumper3"
	b3.position = Vector3(0.0, 0, -16.2)
	b3.bumper_color = Color("00E5FF")
	b3.cap_color = Color("FF007F")
	add_child(b3)
	_label("★ 弹力充气柱阵 ★", Vector3(0, 1.8, -14.8), 18)

	# Tricky bumper right in front of the decoy painted door
	var b_decoy := BUMPER_PILLAR.new()
	b_decoy.name = "DecoyBumper"
	b_decoy.position = Vector3(-3.5, 0, -58.2)
	b_decoy.bumper_color = Color("FF3838")
	add_child(b_decoy)

func _build_question_block() -> void:
	var block := _solid_box("QuestionBlock", Vector3(1.2, 1.2, 1.2), Vector3(0, 2.8, -20.5), STRAW)
	_label("?", Vector3(0, 0, 0.62), 64, block)
	_label("?", Vector3(0, 0, -0.62), 64, block)
	var hay := ROLLING_HAY.new()
	hay.name = "QuestionHay"
	hay.position = Vector3(1.5, 3.6, -22.5)
	hay.roll_direction = Vector3(-0.3, 0, 1)
	hay.roll_impulse = 7.0
	hay.meme_id = "question_block"
	hay.telegraph_meme_id = "question_block_telegraph"
	add_child(hay)
	var bump := _area("BlockBump", "", Vector3(0, 2.0, -20.5), Vector3(1.5, 0.7, 1.5))
	bump.body_entered.connect(func(body: Node3D):
		if body is PigController:
			hay.release()
			var tween := create_tween()
			tween.tween_property(block, "position:y", 3.1, 0.1)
			tween.tween_property(block, "position:y", 2.8, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func _build_door_dash() -> void:
	var door_gate := DOOR_DASH.new()
	door_gate.name = "DoorDashGate"
	door_gate.position = Vector3(0, 0, -26.5)
	door_gate.breakable_index = 1 # Center door is breakable
	add_child(door_gate)

func _build_fake_floor_bridge() -> void:
	var floor_tile := FAKE_FLOOR.new()
	floor_tile.name = "FakeBridge"
	floor_tile.position = Vector3(0, 0, -38)
	floor_tile.tile_size = Vector3(8, 0.3, 12)
	floor_tile.tile_color = WOOD
	floor_tile.trigger_delay = 0.5
	floor_tile.meme_id = "fake_floor"
	floor_tile.telegraph_meme_id = "fake_floor_telegraph"
	add_child(floor_tile)
	_label("康庄大道 · 直通对面", Vector3(0, 1.6, -32), 20)

func _build_sweepers() -> void:
	# Sweeper 1
	var sweeper1 := SPINNING_SWEEPER.new()
	sweeper1.name = "Sweeper1"
	sweeper1.position = Vector3(0, 0, -51.5)
	sweeper1.rotate_speed = 2.0
	sweeper1.bar_length = 7.6
	sweeper1.bar_elevation = 0.35
	sweeper1.knockback_power = 6.5
	sweeper1.knockback_up = 3.0
	sweeper1.meme_id = "sweeper_hit"
	add_child(sweeper1)

	# Sweeper 2 (counter-rotating)
	var sweeper2 := SPINNING_SWEEPER.new()
	sweeper2.name = "Sweeper2"
	sweeper2.position = Vector3(0, 0, -57.5)
	sweeper2.rotate_speed = -2.2
	sweeper2.bar_length = 7.6
	sweeper2.bar_elevation = 0.35
	sweeper2.knockback_power = 7.0
	sweeper2.knockback_up = 3.5
	sweeper2.sweeper_color = Color("E74C3C")
	sweeper2.meme_id = "sweeper_hit"
	add_child(sweeper2)

	_label("糖豆人扫腿机 · 空格起跳越过！", Vector3(0, 2.2, -49), 20)

func _build_pendulums() -> void:
	var pendulum := PENDULUM_BALL.new()
	pendulum.name = "Pendulum1"
	pendulum.position = Vector3(0, 0, -54.5)
	pendulum.swing_speed = 2.6
	pendulum.max_angle_deg = 45.0
	pendulum.knockback_power = 8.0
	pendulum.knockback_up = 4.0
	pendulum.meme_id = "pendulum_hit"
	add_child(pendulum)
	_label("★ 悬挂大摆锤 ★", Vector3(0, 3.8, -54.5), 18)

func _build_decoy_wall() -> void:
	_solid_box("DecoyWallLeft", Vector3(5, 3, 0.5), Vector3(-3.5, 1.5, -61), WOOD)
	_solid_box("DecoyWallRight", Vector3(5, 3, 0.5), Vector3(3.5, 1.5, -61), WOOD)
	var painted := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.6)
	painted.mesh = quad
	painted.position = Vector3(-3.5, 1.5, -60.7)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("52B788")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	painted.material_override = glow
	add_child(painted)
	_label("出口 EXIT", Vector3(-3.5, 2.4, -60.6), 40)
	var hint := _label("真出口 → 直走缺口", Vector3(0, 1.8, -60), 22)
	var decoy := DECOY_GOAL.new()
	decoy.name = "PaintedDoor"
	decoy.position = Vector3(-3.5, 0, -60)
	decoy.meme_id = "decoy_goal"
	decoy.telegraph_meme_id = "decoy_again"
	decoy.real_exit_hint_path = decoy.get_path_to(hint)
	add_child(decoy)

func _build_hammer_bridge() -> void:
	_solid_box("HammerRailL", Vector3(0.3, 0.9, 22), Vector3(-2.2, 0.45, -81), WOOD)
	_solid_box("HammerRailR", Vector3(0.3, 0.9, 22), Vector3(2.2, 0.45, -81), WOOD)
	
	# 4 Rhythmic hammers with alternating directions
	var hammer_configs = [
		{"z": -75.0, "speed": 1.8, "phase": 0.0},
		{"z": -79.0, "speed": -2.0, "phase": PI * 0.5},
		{"z": -83.0, "speed": 2.2, "phase": PI},
		{"z": -87.0, "speed": -2.0, "phase": PI * 1.5},
	]
	for i in hammer_configs.size():
		var cfg = hammer_configs[i]
		var hammer := SPIN_HAMMER.new()
		hammer.name = "RhythmHammer%d" % i
		hammer.position = Vector3(0, 0, cfg["z"])
		hammer.arm_length = 2.6
		hammer.rotate_speed = cfg["speed"]
		hammer.phase_offset = cfg["phase"]
		hammer.knockback_power = 6.0
		hammer.knockback_up = 2.5
		hammer.hammer_color = Color("E67E22") if i % 2 == 0 else Color("E74C3C")
		hammer.meme_id = "hammer_hit"
		add_child(hammer)

	var rhythm_trigger := _area("RhythmTrigger", "", Vector3(0, 1, -72), Vector3(4, 3, 2))
	rhythm_trigger.body_entered.connect(func(body: Node3D):
		if body is PigController and meme_layer:
			meme_layer.play("hammer_rhythm", body.global_position)
	)
	_label("大锤节奏阵 · 听节奏走位", Vector3(0, 2.6, -73), 20)

func _build_decorations() -> void:
	# 1. Bunting flag garlands (三角彩旗链)
	_build_flag_garland(Vector3(-4.0, 3.2, 0.0), Vector3(4.0, 3.2, 0.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -50.0), Vector3(4.0, 3.2, -50.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -68.0), Vector3(4.0, 3.2, -68.0))
	_build_flag_garland(Vector3(-5.0, 3.8, -94.0), Vector3(5.0, 3.8, -94.0))

	# 2. Hazard warning stripes on floor before danger zones
	_build_hazard_stripes(Vector3(0, 0.01, -48.5), Vector3(8.0, 0.02, 1.2))
	_build_hazard_stripes(Vector3(0, 0.01, -71.5), Vector3(4.0, 0.02, 1.2))

	# 3. Ground directional chevron arrows pointing forward
	var arrow_z = [-4.0, -23.5, -47.0, -65.0, -92.0]
	for z in arrow_z:
		_build_chevron_arrow(Vector3(0, 0.02, z))

	# 4. Cheering spectator stands on the sides
	_build_spectator_stand(Vector3(-5.5, 0, -22.0), "加油！冲鸭！")
	_build_spectator_stand(Vector3(5.5, 0, -22.0), "别回头！狗在后面！")
	_build_spectator_stand(Vector3(-5.5, 0, -93.0), "★ 终点在眼前 ★")
	_build_spectator_stand(Vector3(5.5, 0, -93.0), "太强了！糖豆猪！")

	# 5. Victory finish archway
	var finish_arch := StaticBody3D.new()
	finish_arch.collision_layer = 1
	finish_arch.collision_mask = 0
	_add_box_mesh(finish_arch, Vector3(0.4, 4.0, 0.4), Vector3(-4.5, 2.0, -94.0), Color("F39C12"))
	_add_box_mesh(finish_arch, Vector3(0.4, 4.0, 0.4), Vector3(4.5, 2.0, -94.0), Color("F39C12"))
	_add_box_mesh(finish_arch, Vector3(9.4, 0.5, 0.5), Vector3(0, 4.0, -94.0), Color("E74C3C"))
	add_child(finish_arch)
	_label("★ FINISH · 胜利大冲刺 ★", Vector3(0, 4.6, -94.0), 30)

func _build_flag_garland(pos_a: Vector3, pos_b: Vector3) -> void:
	var count := 7
	var colors := [Color("E74C3C"), Color("F1C40F"), Color("2ECC71"), Color("3498DB"), Color("9B59B6"), Color("E67E22")]
	for i in count:
		var t := (i + 0.5) / float(count)
		var p := pos_a.lerp(pos_b, t)
		p.y -= sin(t * PI) * 0.4
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
	mat.albedo_color = HAZARD_YELLOW
	mat.roughness = 0.9
	body.material_override = mat
	add_child(body)

func _build_chevron_arrow(pos: Vector3) -> void:
	var arrow := Label3D.new()
	arrow.text = "▲"
	arrow.font_size = 40
	arrow.position = pos
	arrow.rotation.x = -PI * 0.5
	arrow.modulate = HAZARD_YELLOW
	arrow.outline_modulate = HAZARD_DARK
	arrow.outline_size = 4
	add_child(arrow)

func _build_spectator_stand(pos: Vector3, cheer_text: String) -> void:
	var stand := _solid_box("SpectatorStand", Vector3(2.4, 1.2, 2.4), pos + Vector3(0, 0.6, 0), WOOD)
	var banner := Label3D.new()
	banner.text = cheer_text
	banner.font_size = 20
	banner.position = Vector3(0, 2.2, 0)
	banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner.modulate = Color("FFF275")
	banner.outline_modulate = Color("3A3630")
	banner.outline_size = 5
	stand.add_child(banner)

func _add_box_mesh(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	parent.add_child(mesh)

func _build_exit() -> void:
	# Pipe archway
	var pipe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.6
	cyl.height = 2.4
	pipe.mesh = cyl
	pipe.rotation.x = deg_to_rad(90.0)
	pipe.position = Vector3(0, 1.4, -98)
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = PIPE_GREEN
	pipe_mat.roughness = 0.6
	pipe.material_override = pipe_mat
	add_child(pipe)

	_solid_box("ExitPostL", Vector3(0.4, 3, 0.4), Vector3(-3, 1.5, -98), WOOD)
	_solid_box("ExitPostR", Vector3(0.4, 3, 0.4), Vector3(3, 1.5, -98), WOOD)
	_label("直通牛耕地 · 胜利大水管 ↑", Vector3(0, 3.4, -98), 28)
	_label("（冲入水管直达牛耕地大门入口！）", Vector3(0, 2.6, -98), 18)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, -2), Vector3(8, 3, 2))
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -50), Vector3(0, 0.6, -50))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -68), Vector3(0, 0.6, -68))
	_area("CourseExit", "course_exit", Vector3(0, 1, -98), Vector3(8, 3, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 3))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	_label("◆ 检查点", pos + Vector3(0, 1.6, 0), 18)

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
	var mesh := MeshInstance3D.new()
	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	mesh.mesh = mesh_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body

func _label(text: String, pos: Vector3, font_size: int, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.modulate = CREAM
	label.outline_modulate = Color("3A3630")
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
