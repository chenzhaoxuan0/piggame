extends Node3D

const ASSETS = preload("res://scripts/art/asset_library.gd")
const PASTORAL_ENV = preload("res://scripts/art/pastoral_environment.gd")
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
const MUD := Color("5D4037")
const STRAW := Color("F59E0B")
const PIPE_GREEN := Color("2E7D32")
const HAZARD_YELLOW := Color("F1C40F")
const HAZARD_DARK := Color("2C3E50")

var runner: CourseRunner
var meme_layer: MemeLayer
# 剧情节拍一次性闸门：疑心桥 / 大锤节奏阵各只播一次。
var _bridge_beat_fired := false
var _hammer_beat_fired := false

func _ready() -> void:
	_build_ground()
	_build_dressing()
	_build_surroundings()
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
	# 进场对话节拍：体素牛耕地的「入口消化」——出了什么事 / 在哪 / 干什么。
	# 出生点在起点 marker 之外，节拍结束玩家迈步才触发 marker → course_started。
	runner.begin_beat({
		"id": "course_1_intro",
		"title": "第一章 · 隐藏试炼 · 牛耕地",
		"lines": [
			"哗啦——水管把你吐进了另一个世界：草是方的，云也是方的。",
			"这是牛耕地里的隐藏试炼道，叼着铜插销逃跑的路上钻进来的——身后的阴影也追进来了！",
			"跑赢这条糖豆人赛道：弹簧垫、问号砖、大摆锤——出口水管直通牛耕地！",
		],
		"line_time": 2.5,
		"accent": STRAW,
	})

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_1"
	cfg.title = "第一章 · 甩掉阴影，冲进牛耕地"
	cfg.desc = "身后的过往阴影紧追不放！飞越弹簧垫、顶问号砖、撞开幸运门——跑赢这条糖豆人试炼，就到阿牛的耕地！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-30, -16, -112), Vector3(60, 40, 132))
	cfg.dog_count = 1
	cfg.dog_speed_min = 3.2
	cfg.dog_speed_max = 6.6
	cfg.memes = {
		"course_start": {"title": "阴影追进管道了！", "text": "跑赢这条试炼道，出口就是牛耕地！弹簧垫、问号砖、大摆锤——冲！", "duration": 3.0},
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
		"hammer_hit": {"title": "大锤八十！", "text": "大锤八十，小锤四十！", "duration": 2.0},
		"dog_bonk": {"title": "恶犬扑空", "text": "没技能？那就滚一圈再说", "duration": 2.0},
		"qte_success": {"title": "坚韧挣脱！", "text": "阿牛之力：咬紧牙关，震退恶犬！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "被甩出去了……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "摔了个猪啃泥", "text": "没事，检查点重来，猪没事", "duration": 2.2},
	}
	return cfg

func _build_ground() -> void:
	# Platforms abut edge-to-edge; overlapping coplanar tops z-fight.
	_grass_platform("StartTerrace", Vector3(16, 1, 16), Vector3(0, -0.5, 4))
	_grass_platform("PathA", Vector3(8, 1, 26), Vector3(0, -0.5, -17))
	_platform("LowerPath", Vector3(10, 1, 14), Vector3(0, -4.0, -36), MUD)
	# Ramp top surface runs exactly from LowerPath edge (-43, -3.5) to PathB edge (-49, 0).
	var ramp := _solid_box("RampBack", Vector3(8, 0.5, 6.95), Vector3(0, -1.966, -46.126), WOOD)
	ramp.rotation.x = deg_to_rad(30.26)
	var ramp_deck := ASSETS.replace_visuals(ramp, "PROP_C1_FAKEBRIDGE", Vector3(0, 0.15, 0))
	if ramp_deck:
		ramp_deck.scale = Vector3(1.0, 1.0, 6.95 / 12.0)
	_grass_platform("PathB", Vector3(8, 1, 21), Vector3(0, -0.5, -59.5))
	var bridge := _solid_box("HammerBridge", Vector3(4, 1, 22), Vector3(0, -0.5, -81), WOOD)
	var bridge_deck := ASSETS.replace_visuals(bridge, "PROP_C1_FAKEBRIDGE", Vector3(0, 0.41, 0))
	if bridge_deck:
		bridge_deck.scale = Vector3(0.5, 1.0, 22.0 / 12.0)
	_grass_platform("ExitTerrace", Vector3(12, 1, 12), Vector3(0, -0.5, -98))
	_build_checker_line(2.0, 8.0)
	_build_checker_line(-92.8, 8.0)
	_label("牛耕地隐藏闯关 · 糖豆人试炼", Vector3(0, 2.4, 9), 26)
	_label("空格跳跃 / WASD 移动 / Shift 闪避", Vector3(0, 1.6, 1), 18)

func _grass_platform(node_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := _platform(node_name, size, pos, GRASS)
	var grass := ASSETS.replace_visuals(body, "PROP_C1_GRASS", Vector3(0, -size.y * 0.5, 0))
	if grass:
		grass.scale = Vector3(size.x / 4.0, size.y * 2.0, size.z / 4.0)
	return body

func _build_surroundings() -> void:
	# Scenery-only pastoral modules: a rocky back-mountain spur under the floating
	# track, trees and rocks framing the terraces, and distant haze peaks.
	var env := PASTORAL_ENV.new()
	env.name = "CourseSurroundings"
	env._material = ShaderMaterial.new()
	env._material.shader = preload("res://scripts/art/pastoral_surface.gdshader")
	env._rng.seed = 20261110
	add_child(env)
	var rock := Color("777F8D")
	var stone := Color("8B9093")
	var stone_light := Color("A5A69F")
	# Mountain body sits well below the track (tops ~-4.4) and outboard, so it
	# reads as cliffs dropping away without occluding the racing surface.
	env._district = "MountainSlopes"
	for z in [4.0, -10.0, -24.0, -38.0, -52.0, -66.0, -80.0, -94.0]:
		for side in [-1.0, 1.0]:
			var shade := rock.lerp(stone, 0.3 + 0.2 * sin(z))
			env._boulder(Vector3(side * 7.0, -9.0, z), Vector3(10, 8, 13), shade, z * 0.1)
	env._boulder(Vector3(0, -9.5, -36), Vector3(12, 9, 16), rock, 0.7)
	# Distant peaks faded by the shader's valley haze.
	for p in [Vector3(-48, -16, -30), Vector3(50, -17, -70), Vector3(-44, -18, -95)]:
		env._boulder(p, Vector3(30, 22, 40), stone_light, p.x)
	# Trees and boulders grounded on the wide terraces.
	env._district = "CourseTrees"
	env._tree(Vector3(-7, 0, 11), 0.9)
	env._tree(Vector3(7, 0, 11), 1.0)
	env._tree(Vector3(-5, 0, -103), 0.9)
	env._tree(Vector3(5, 0, -103), 1.0)
	env._district = "CourseRocks"
	env._boulder(Vector3(7.2, 0.1, -2), Vector3(1.6, 1.3, 1.5), stone, 0.3)
	env._boulder(Vector3(-7.0, 0.1, 6), Vector3(1.3, 1.0, 1.2), rock, 1.1)
	env._boulder(Vector3(5.2, 0.1, -95), Vector3(1.4, 1.1, 1.3), stone, 2.0)
	# Grass tufts and flowers scattered over the terrace ground for detail.
	env._district = "Ground_Detail"
	for p in [Vector3(-5, 0.02, 2), Vector3(4, 0.02, 0), Vector3(-2, 0.02, 10), Vector3(6, 0.02, 8),
		Vector3(-6, 0.02, -96), Vector3(3, 0.02, -100), Vector3(0, 0.02, -90), Vector3(-4, 0.02, -102)]:
		env._tuft(p, 0.5)
	env._flowers(Vector3(-4, 0.02, 8), 4)
	env._flowers(Vector3(4, 0.02, -99), 4)
	env._flush()

func _platform(node_name: String, size: Vector3, pos: Vector3, top_color: Color) -> StaticBody3D:
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
	# Soil body + grass rim slab flush with the collision top; x-only overhang
	# hides the seam without overlapping the next platform's slab.
	# Soil sides stay 0.06 inside the grass-model sides and the rim top sits
	# 0.06 under the model top (was flush at 0.0003 m -> full-platform flicker).
	_add_box_mesh(body, Vector3(size.x - 0.12, size.y - 0.14, size.z - 0.12), Vector3(0, -0.07, 0), LOAM)
	_add_box_mesh(body, Vector3(size.x + 0.24, 0.14, size.z), Vector3(0, size.y * 0.5 - 0.13, 0), top_color)
	add_child(body)
	return body

func _build_checker_line(z: float, width: float) -> void:
	for row in 2:
		for i in int(width):
			var color := Color("FFF8E7") if (i + row) % 2 == 0 else HAZARD_DARK
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

func _build_dressing() -> void:
	_prop("ENV_06_HAY", Vector3(-6, 0, 9), 15, Vector3(1.7, 0.9, 1.15))
	_prop("ENV_06_HAY", Vector3(6, 0, 9), -12, Vector3(1.7, 0.9, 1.15))
	_prop("ENV_09_STUMP", Vector3(6.6, 0, 5.5), 0, Vector3(1.1, 0.75, 1.1))
	for side in [-1.0, 1.0]:
		for z in [0.5, 2.3, 4.1, 5.9, 7.7]:
			_prop("ENV_09_RAIL", Vector3(side * 7.6, 0, z), 90, Vector3(1.75, 1.2, 0.25))
	_prop("ENV_06_HAY", Vector3(-4.8, 0, -101), 20, Vector3(1.7, 0.9, 1.15))
	_prop("ENV_06_HAY", Vector3(4.8, 0, -101), -15, Vector3(1.7, 0.9, 1.15))
	_prop("ENV_09_ROCK", Vector3(4.2, -3.5, -31), 30, Vector3(1.8, 1.4, 1.8))
	_prop("ENV_09_STUMP", Vector3(-4.2, -3.5, -33), 0, Vector3(1.1, 0.75, 1.1))

func _prop(asset_id: String, pos: Vector3, yaw_deg: float, col_size: Vector3) -> void:
	var visual := ASSETS.make(asset_id)
	if visual == null:
		return
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = deg_to_rad(yaw_deg)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = col_size
	shape.shape = box
	shape.position.y = col_size.y * 0.5
	body.add_child(shape)
	body.add_child(visual)
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
	if ASSETS.replace_visuals(block, "PROP_C1_QUESTIONBLOCK") == null:
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
	floor_tile.position = Vector3(0, 0, -37)
	floor_tile.tile_size = Vector3(8, 0.3, 12)
	floor_tile.tile_color = WOOD
	floor_tile.trigger_delay = 0.5
	floor_tile.meme_id = "fake_floor"
	floor_tile.telegraph_meme_id = "fake_floor_telegraph"
	add_child(floor_tile)
	_label("康庄大道 · 直通对面", Vector3(0, 1.6, -31.5), 20)
	# 剧情点节拍 ①：踏上「康庄大道」前的疑心停顿（实心 PathA 地面上的触发器，
	# 锁定期不站在会塌的桥上）。塌桥本身的教学 toast 照旧由组件播。
	var suspicion := _area("FakeBridgeBeatTrigger", "", Vector3(0, 1, -28.5), Vector3(8, 3, 1))
	suspicion.body_entered.connect(_on_suspicion_entered)

func _on_suspicion_entered(body: Node3D) -> void:
	if _bridge_beat_fired:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_bridge_beat_fired = true
	if runner != null:
		runner.begin_beat({
			"id": "course_1_fake_bridge",
			"title": "这条桥平得可疑……",
			"lines": [
				"这条『康庄大道』又宽又平——前面明明是断崖。",
				"（真塌了也别慌：谷底的超级弹簧会把你弹回跑道。）",
			],
			"line_time": 1.3,
			"accent": HAZARD_YELLOW,
		})

func _build_sweepers() -> void:
	# Sweeper 1
	var sweeper1 := SPINNING_SWEEPER.new()
	sweeper1.name = "Sweeper1"
	sweeper1.position = Vector3(0, 0, -51.5)
	sweeper1.rotate_speed = 2.4
	sweeper1.bar_length = 7.6
	sweeper1.bar_elevation = 0.35
	sweeper1.knockback_power = 7.5
	sweeper1.knockback_up = 3.0
	sweeper1.meme_id = "sweeper_hit"
	add_child(sweeper1)

	# Sweeper 2 (counter-rotating)
	var sweeper2 := SPINNING_SWEEPER.new()
	sweeper2.name = "Sweeper2"
	sweeper2.position = Vector3(0, 0, -57.5)
	sweeper2.rotate_speed = -2.6
	sweeper2.bar_length = 7.6
	sweeper2.bar_elevation = 0.35
	sweeper2.knockback_power = 8.0
	sweeper2.knockback_up = 3.5
	sweeper2.sweeper_color = Color("E74C3C")
	sweeper2.meme_id = "sweeper_hit"
	add_child(sweeper2)

	_label("糖豆人扫腿机 · 空格起跳越过！", Vector3(0, 2.2, -49), 20)

func _build_pendulums() -> void:
	var pendulum := PENDULUM_BALL.new()
	pendulum.name = "Pendulum1"
	pendulum.position = Vector3(0, 0, -54.5)
	pendulum.swing_speed = 3.0
	pendulum.max_angle_deg = 45.0
	pendulum.knockback_power = 8.0
	pendulum.knockback_up = 4.0
	pendulum.meme_id = "pendulum_hit"
	add_child(pendulum)
	_label("★ 悬挂大摆锤 ★", Vector3(0, 3.8, -54.5), 18)

func _build_decoy_wall() -> void:
	var wall_l := _solid_box("DecoyWallLeft", Vector3(5, 3, 0.5), Vector3(-3.5, 1.5, -61), WOOD)
	var wall_r := _solid_box("DecoyWallRight", Vector3(5, 3, 0.5), Vector3(3.5, 1.5, -61), WOOD)
	ASSETS.replace_visuals(wall_l, "PROP_C1_WALL", Vector3(0, -1.5, 0))
	ASSETS.replace_visuals(wall_r, "PROP_C1_WALL", Vector3(0, -1.5, 0))
	var painted := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.6)
	painted.mesh = quad
	painted.position = Vector3(-3.5, 1.5, -60.55)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("52B788")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	painted.material_override = glow
	add_child(painted)
	_label("出口 EXIT", Vector3(-3.5, 2.4, -60.3), 40)
	var hint := _label("真出口 → 直走缺口", Vector3(0, 1.8, -60), 22)
	var decoy := DECOY_GOAL.new()
	decoy.name = "PaintedDoor"
	decoy.position = Vector3(-3.5, 0, -60)
	decoy.meme_id = "decoy_goal"
	decoy.telegraph_meme_id = "decoy_again"
	decoy.real_exit_hint_path = decoy.get_path_to(hint)
	add_child(decoy)

func _build_hammer_bridge() -> void:
	_solid_box("HammerRailL", Vector3(0.3, 0.9, 22), Vector3(-1.95, 0.45, -81), WOOD)
	_solid_box("HammerRailR", Vector3(0.3, 0.9, 22), Vector3(1.95, 0.45, -81), WOOD)
	
	# 4 Rhythmic hammers with alternating directions
	var hammer_configs = [
		{"z": -75.0, "speed": 2.2, "phase": 0.0},
		{"z": -79.0, "speed": -2.4, "phase": PI * 0.5},
		{"z": -83.0, "speed": 2.6, "phase": PI},
		{"z": -87.0, "speed": -2.4, "phase": PI * 1.5},
	]
	for i in hammer_configs.size():
		var cfg = hammer_configs[i]
		var hammer := SPIN_HAMMER.new()
		hammer.name = "RhythmHammer%d" % i
		hammer.position = Vector3(0, 0, cfg["z"])
		hammer.arm_length = 2.6
		hammer.rotate_speed = cfg["speed"]
		hammer.phase_offset = cfg["phase"]
		hammer.knockback_power = 7.0
		hammer.knockback_up = 2.5
		hammer.hammer_color = Color("E67E22") if i % 2 == 0 else Color("E74C3C")
		hammer.meme_id = "hammer_hit"
		add_child(hammer)

	var rhythm_trigger := _area("RhythmTrigger", "", Vector3(0, 1, -72), Vector3(4, 3, 2))
	rhythm_trigger.body_entered.connect(_on_hammer_bridge_entered)
	_label("大锤节奏阵 · 听节奏走位", Vector3(0, 2.6, -73), 20)

func _on_hammer_bridge_entered(body: Node3D) -> void:
	# 剧情点节拍 ②（升级自 hammer_rhythm toast）：末段大锤节奏阵。触发器在
	# 桥头的实心木板上、距第一把大锤 3 m（臂长 2.6 m 扫不到），锁定期安全。
	if _hammer_beat_fired:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_hammer_beat_fired = true
	if runner != null:
		runner.begin_beat({
			"id": "course_1_hammer_bridge",
			"title": "大锤节奏阵 · 八十——八十——",
			"lines": [
				"四把大锤排着节奏砸！退——进——退——进！",
				"桥那头的水管直通牛耕地，冲！",
			],
			"line_time": 1.25,
			"accent": HAZARD_DARK,
		})

func _build_decorations() -> void:
	# 1. Bunting flag garlands (三角彩旗链)
	_build_flag_garland(Vector3(-4.0, 3.2, 0.0), Vector3(4.0, 3.2, 0.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -50.0), Vector3(4.0, 3.2, -50.0))
	_build_flag_garland(Vector3(-4.0, 3.2, -68.0), Vector3(4.0, 3.2, -68.0))
	_build_flag_garland(Vector3(-5.0, 3.8, -94.0), Vector3(5.0, 3.8, -94.0))

	# 2. Hazard warning stripes on floor before danger zones
	_build_hazard_stripes(Vector3(0, 0.05, -50.0), Vector3(8.0, 0.06, 1.2))
	_build_hazard_stripes(Vector3(0, 0.05, -71.5), Vector3(4.0, 0.06, 1.2))

	# 3. Ground directional chevron arrows pointing forward
	var arrow_z = [-4.0, -23.5, -52.0, -65.0, -92.0]
	for z in arrow_z:
		_build_chevron_arrow(Vector3(0, 0.06, z))

	# 4. Victory finish archway
	var finish_arch := StaticBody3D.new()
	finish_arch.collision_layer = 1
	finish_arch.collision_mask = 0
	var lux_arch := ASSETS.make("PROP_C1_FINISHARCH")
	if lux_arch:
		lux_arch.position = Vector3(0, 0, -94.0)
		finish_arch.add_child(lux_arch)
	else:
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
	# Lux3D Warp Pipe model or procedural pipe archway fallback
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
		pipe_mat.albedo_color = PIPE_GREEN
		pipe_mat.roughness = 0.6
		pipe.material_override = pipe_mat
		add_child(pipe)

	_solid_box("ExitPostL", Vector3(0.4, 3, 0.4), Vector3(-3, 1.5, -98), WOOD)
	_solid_box("ExitPostR", Vector3(0.4, 3, 0.4), Vector3(3, 1.5, -98), WOOD)
	_label("直通牛耕地 · 胜利大水管 ↑", Vector3(0, 3.4, -98), 28)
	_label("（冲入水管直达牛耕地大门入口！）", Vector3(0, 2.6, -98), 18)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, -2), Vector3(16, 3, 2)) # Full platform width: no side bypass
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
	var ui := preload("res://scripts/ui/ui_kit.gd")
	var label := ui.world_label(text, font_size, CREAM, Color("3A3630"))
	label.position = pos
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
