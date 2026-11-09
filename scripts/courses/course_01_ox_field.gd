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

const SPAWN := Vector3(0, 0.6, 6)
const CREAM := Color("E1DDC5")
const GRASS := Color("74A87C")
const LOAM := Color("3E2723")
const WOOD := Color("8D7B68")
const STRAW := Color("F59E0B")

var runner: CourseRunner
var meme_layer: MemeLayer

func _ready() -> void:
	_build_ground()
	_build_ox_npc()
	_build_question_block()
	_build_fake_floor_bridge()
	_build_decoy_wall()
	_build_hammer_bridge()
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
	cfg.title = "牛耕地闯关 · 过去的阴影"
	cfg.desc = "顶问号砖、过假地板、识破画中门、跟着大锤节奏走位！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-30, -16, -112), Vector3(60, 40, 132))
	cfg.dog_count = 1
	cfg.dog_speed_min = 2.6
	cfg.dog_speed_max = 6.0
	cfg.memes = {
		"course_start": {"title": "牛耕地闯关", "text": "阿牛说了：被咬住就狂按空格挣脱！冲！", "duration": 3.0},
		"question_block_telegraph": {"title": "问号砖", "text": "顶一下，必有奖励（确信）", "duration": 2.0},
		"question_block": {"title": "鸡汤来咯！", "text": "说好的金币呢？怎么是草垛！", "duration": 2.8},
		"fake_floor_telegraph": {"title": "康庄大道", "text": "这路又宽又平，稳得很", "duration": 2.0},
		"fake_floor": {"title": "宫崎英高的微笑", "text": "前方绝景，敬请见证", "duration": 2.8},
		"decoy_goal": {"title": "我信你个鬼", "text": "这出口是画上去的！真出口是直走的缺口！", "duration": 3.0},
		"decoy_again": {"title": "还想撞？", "text": "画饼充不了饥，假门进不去", "duration": 2.0},
		"hammer_rhythm": {"title": "大锤节奏阵", "text": "跟着节奏走位！", "rhythm": ["退！", "退！", "退！"], "interval": 0.55, "cooldown": 4.0},
		"hammer_hit": {"title": "大锤八十！", "text": "大锤八十，小锤四十", "duration": 2.0},
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
	_solid_box("PathB", Vector3(8, 1, 20), Vector3(0, -0.5, -60), GRASS)
	_solid_box("HammerBridge", Vector3(4, 1, 20), Vector3(0, -0.5, -80), WOOD)
	_solid_box("ExitTerrace", Vector3(12, 1, 14), Vector3(0, -0.5, -97), GRASS)
	_label("牛耕地闯关 · 先跟阿牛聊聊再出发", Vector3(0, 2.4, 9), 26)
	_label("空格跳跃 / WASD 移动 / Shift 闪避（解锁后）", Vector3(0, 1.6, 1), 18)

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

func _build_question_block() -> void:
	var block := _solid_box("QuestionBlock", Vector3(1.2, 1.2, 1.2), Vector3(0, 2.8, -18), STRAW)
	_label("?", Vector3(0, 0, 0.62), 64, block)
	_label("?", Vector3(0, 0, -0.62), 64, block)
	var hay := ROLLING_HAY.new()
	hay.name = "QuestionHay"
	hay.position = Vector3(1.5, 3.6, -20)
	hay.roll_direction = Vector3(-0.3, 0, 1)
	hay.roll_impulse = 7.0
	hay.meme_id = "question_block"
	hay.telegraph_meme_id = "question_block_telegraph"
	add_child(hay)
	var bump := _area("BlockBump", "", Vector3(0, 2.0, -18), Vector3(1.5, 0.7, 1.5))
	bump.body_entered.connect(func(body: Node3D):
		if body is PigController:
			hay.release()
			var tween := create_tween()
			tween.tween_property(block, "position:y", 3.1, 0.1)
			tween.tween_property(block, "position:y", 2.8, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

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

func _build_decoy_wall() -> void:
	# Real exit is the straight-ahead gap (x=0); the glowing painted "EXIT" on the
	# left is a tempting fake shortcut that bounces greedy pigs back.
	_solid_box("DecoyWallLeft", Vector3(5, 3, 0.5), Vector3(-3.5, 1.5, -60), WOOD)
	_solid_box("DecoyWallRight", Vector3(5, 3, 0.5), Vector3(3.5, 1.5, -60), WOOD)
	var painted := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.6)
	painted.mesh = quad
	painted.position = Vector3(-3.5, 1.5, -59.7)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("52B788")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	painted.material_override = glow
	add_child(painted)
	_label("出口 EXIT", Vector3(-3.5, 2.4, -59.6), 40)
	var hint := _label("真出口 → 直走缺口", Vector3(0, 1.8, -59), 22)
	var decoy := DECOY_GOAL.new()
	decoy.name = "PaintedDoor"
	decoy.position = Vector3(-3.5, 0, -59)
	decoy.meme_id = "decoy_goal"
	decoy.telegraph_meme_id = "decoy_again"
	decoy.real_exit_hint_path = decoy.get_path_to(hint)
	add_child(decoy)

func _build_hammer_bridge() -> void:
	_solid_box("HammerRailL", Vector3(0.3, 0.9, 20), Vector3(-2.2, 0.45, -80), WOOD)
	_solid_box("HammerRailR", Vector3(0.3, 0.9, 20), Vector3(2.2, 0.45, -80), WOOD)
	for i in 3:
		var hammer := SPIN_HAMMER.new()
		hammer.name = "RhythmHammer%d" % i
		hammer.position = Vector3(0, 0, -76 - i * 4)
		hammer.arm_length = 2.6
		hammer.rotate_speed = 1.8
		hammer.phase_offset = i * (PI * 2.0 / 3.0)
		hammer.knockback_power = 5.0
		hammer.knockback_up = 2.0
		hammer.meme_id = "hammer_hit"
		add_child(hammer)
	var rhythm_trigger := _area("RhythmTrigger", "", Vector3(0, 1, -72), Vector3(4, 3, 2))
	rhythm_trigger.body_entered.connect(func(body: Node3D):
		if body is PigController and meme_layer:
			meme_layer.play("hammer_rhythm", body.global_position)
	)
	_label("大锤节奏阵 · 听节奏走位", Vector3(0, 2.6, -73), 20)

func _build_exit() -> void:
	_solid_box("ExitPostL", Vector3(0.4, 3, 0.4), Vector3(-3, 1.5, -98), WOOD)
	_solid_box("ExitPostR", Vector3(0.4, 3, 0.4), Vector3(3, 1.5, -98), WOOD)
	_label("溪流区入口 →", Vector3(0, 3.2, -98), 30)
	_label("（下一关开发中，先回农场）", Vector3(0, 2.4, -98), 16)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, -2), Vector3(8, 3, 2))
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -50), Vector3(0, 0.6, -50))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -68), Vector3(0, 0.6, -68))
	_area("CourseExit", "course_exit", Vector3(0, 1, -98), Vector3(10, 3, 3))

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