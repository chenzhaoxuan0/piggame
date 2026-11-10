extends Node3D

const ASSETS = preload("res://scripts/art/asset_library.gd")
const RUNNER_SCRIPT = preload("res://scripts/courses/course_runner.gd")
const MEME_SCRIPT = preload("res://scripts/courses/meme_layer.gd")
const CONFIG_SCRIPT = preload("res://scripts/courses/course_config.gd")

const BOOST_PAD = preload("res://scripts/courses/components/boost_pad.gd")
const WATERMELON_PEEL = preload("res://scripts/courses/components/watermelon_peel.gd")
const RACING_FINISH_GATE = preload("res://scripts/courses/components/racing_finish_gate.gd")

const SPAWN := Vector3(0, 0.6, 12)
const RACING_ASPHALT := Color("1E293B") # Dark asphalt
const RACING_CURB_RED := Color("DC2626") # Red curb
const RACING_CURB_WHITE := Color("F8FAFC") # White curb
const NEON_CYAN := Color("00E5FF")
const NEON_YELLOW := Color("FACC15")
const CREAM := Color("FFFFFF")
const DARK := Color("0F172A")

var runner: CourseRunner
var meme_layer: MemeLayer

var boost_pad_1: Node3D
var boost_pad_2: Node3D
var boost_pad_3: Node3D
var watermelon_peel: Node3D
var finish_gate: Node3D
var traffic_lights: Node3D

func _ready() -> void:
	_build_track_ground()
	_build_start_grid()
	_build_boost_pads()
	_build_watermelon_trap()
	_build_finish_gate()
	_build_decorations()
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
	player.set_meta("in_stealth_box", false)
	for child in player.find_children("*", "CardboardBoxProp", true, false):
		child.queue_free()
	var gm := get_tree().root.get_node_or_null("GameManager")
	if gm != null:
		if "has_dash_skill" in gm:
			gm.has_dash_skill = true
		if "has_struggle_skill" in gm:
			gm.has_struggle_skill = true
	runner.setup(player, SPAWN)

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_4"
	cfg.title = "大院隐藏关卡 · 《马车极速狂飙》打破35秒纪录！"
	cfg.desc = "终极街机竞速赛道！踩上黄色加速带极速喷火、扔西瓜皮滑倒恶犬、凭借【疾风之步】打破世界纪录冲破大门！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-35, -16, -115), Vector3(70, 40, 140))
	cfg.dog_count = 1
	cfg.dog_speed_min = 3.2
	cfg.dog_speed_max = 6.8
	cfg.memes = {
		"course_start": {"title": "3... 2... 1... 起跑！", "text": "切换极速街机赛道！踩加速带漂移过弯，冲刺打破世界纪录！", "duration": 3.0},
		"boost_pad": {"title": "屁股喷火！极速加速！", "text": "踩中加速带！氮气爆发，瞬间拉开身后恶犬十个身位！", "duration": 2.2},
		"watermelon_slip": {"title": "恶犬踩中西瓜皮！", "text": "汪汪汪？！恶犬原地狂转3圈！摔了个狗吃屎！", "duration": 2.5},
		"horse_dash": {"title": "野马【疾风之步】全开！", "text": "终点直道极速冲刺！打破 35 秒世界纪录的唯一机会！", "duration": 2.5},
		"record_broken": {"title": "🏁 00:34.88！新世界纪录！ 🏁", "text": "一口猪成功打破农场纪录！欢呼声中一头撞破办公室大门！", "duration": 3.5},
		"dog_bonk": {"title": "恶犬扑空", "text": "恶犬被甩在身后吃尾气！", "duration": 2.0},
		"qte_success": {"title": "疾风甩尾挣脱！", "text": "野马疾风：漂移甩尾，甩开恶犬！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "被甩飞了……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "赛道复活", "text": "赛车小猪换上新轮胎，重回跑道！", "duration": 2.2},
	}
	return cfg

func _build_track_ground() -> void:
	# Main straightaway A (Z = 14 to -22)
	_track_segment("StraightA", Vector3(10, 1, 36), Vector3(0, -0.5, -4))

	# Hairpin curve B (Z = -22 to -48)
	_track_segment("CurveB", Vector3(12, 1, 26), Vector3(0, -0.5, -35))

	# Final sprint straight C (Z = -48 to -88)
	_track_segment("StraightC", Vector3(12, 1, 40), Vector3(0, -0.5, -68))

	# Exit arena (Z = -88 to -98)
	_track_segment("ExitArena", Vector3(14, 1, 10), Vector3(0, -0.5, -93))

func _track_segment(node_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
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

	# Asphalt tarmac
	var tarmac := MeshInstance3D.new()
	var tarmac_box := BoxMesh.new()
	tarmac_box.size = Vector3(size.x - 1.6, 0.1, size.z)
	tarmac.mesh = tarmac_box
	tarmac.position = Vector3(0, size.y * 0.5 - 0.05, 0)
	var tarmac_mat := StandardMaterial3D.new()
	tarmac_mat.albedo_color = RACING_ASPHALT
	tarmac_mat.roughness = 0.8
	tarmac.material_override = tarmac_mat
	body.add_child(tarmac)

	# Left red-white racing curb
	_curb_strip(body, Vector3(-size.x * 0.5 + 0.4, size.y * 0.5, 0), size.z)
	# Right red-white racing curb
	_curb_strip(body, Vector3(size.x * 0.5 - 0.4, size.y * 0.5, 0), size.z)

	add_child(body)
	return body

func _curb_strip(parent: Node3D, pos: Vector3, length: float) -> void:
	var curb := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.15, length)
	curb.mesh = box
	curb.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = RACING_CURB_RED
	curb.material_override = mat
	parent.add_child(curb)

func _build_start_grid() -> void:
	# Starting line gantry with 3-2-1 lights
	traffic_lights = Node3D.new()
	traffic_lights.name = "TrafficLights"
	traffic_lights.position = Vector3(0, 0, 8.0)

	var frame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 0.6, 0.6)
	frame.mesh = box
	frame.position = Vector3(0, 4.0, 0)
	traffic_lights.add_child(frame)

	var light_label := _label("● ● ● 3... 2... 1... GO!", Vector3(0, 4.8, 0), 32, traffic_lights)
	light_label.modulate = Color("22C55E")
	add_child(traffic_lights)

func _build_boost_pads() -> void:
	# Boost Pad 1 on Straight A (Z = 2.0)
	boost_pad_1 = BOOST_PAD.new()
	boost_pad_1.name = "BoostPad1"
	boost_pad_1.position = Vector3(0, 0, 2.0)
	add_child(boost_pad_1)
	boost_pad_1.boost_activated.connect(func(_p):
		if meme_layer:
			meme_layer.play("boost_pad")
	)

	# Boost Pad 2 on Straight A (Z = -14.0)
	boost_pad_2 = BOOST_PAD.new()
	boost_pad_2.name = "BoostPad2"
	boost_pad_2.position = Vector3(0, 0, -14.0)
	add_child(boost_pad_2)
	boost_pad_2.boost_activated.connect(func(_p):
		if meme_layer:
			meme_layer.play("boost_pad")
	)

	# Boost Pad 3 on Final Straight C (Z = -64.0)
	boost_pad_3 = BOOST_PAD.new()
	boost_pad_3.name = "BoostPad3"
	boost_pad_3.position = Vector3(0, 0, -64.0)
	add_child(boost_pad_3)
	boost_pad_3.boost_activated.connect(func(_p):
		if meme_layer:
			meme_layer.play("boost_pad")
	)

	_label("【加速带】踩中黄色箭头直接爆发极速！", Vector3(0, 2.5, 2.0), 22)

func _build_watermelon_trap() -> void:
	# Watermelon peel sitting at the apex of Hairpin Turn B (Z = -36.0)
	watermelon_peel = WATERMELON_PEEL.new()
	watermelon_peel.name = "WatermelonPeelItem"
	watermelon_peel.position = Vector3(0, 0, -36.0)
	add_child(watermelon_peel)

	watermelon_peel.peel_slipped.connect(func(_victim):
		if meme_layer:
			meme_layer.play("watermelon_slip")
	)

	_label("【西瓜皮陷阱】身后恶犬踩中会原地打转3圈！", Vector3(0, 2.5, -34.0), 20)

func _build_finish_gate() -> void:
	# Racing finish gantry at Z = -85.0
	finish_gate = RACING_FINISH_GATE.new()
	finish_gate.name = "RacingFinishGate"
	finish_gate.gate_width = 10.0
	finish_gate.gate_height = 5.5
	finish_gate.position = Vector3(0, 0, -85.0)
	add_child(finish_gate)

	finish_gate.finish_line_crossed.connect(func(player):
		if meme_layer:
			meme_layer.play("record_broken")
		runner._on_exit(player)
	)

func _build_decorations() -> void:
	# Neon grandstand floodlights
	_stadium_light(Vector3(-7, 0, 4))
	_stadium_light(Vector3(7, 0, 4))
	_stadium_light(Vector3(-7, 0, -35))
	_stadium_light(Vector3(7, 0, -35))
	_stadium_light(Vector3(-7, 0, -75))
	_stadium_light(Vector3(7, 0, -75))

func _stadium_light(pos: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 6.0, 0.4)
	pole.mesh = box
	pole.position = pos + Vector3(0, 3.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("475569")
	pole.material_override = mat
	add_child(pole)

	var lamp := MeshInstance3D.new()
	var lamp_box := BoxMesh.new()
	lamp_box.size = Vector3(1.2, 0.6, 0.8)
	lamp.mesh = lamp_box
	lamp.position = pos + Vector3(0, 6.2, 0)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color("FACC15")
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("FEF08A")
	lamp_mat.emission_energy_multiplier = 2.0
	lamp.material_override = lamp_mat
	add_child(lamp)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, 10), Vector3(8, 3, 2))
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -22), Vector3(0, 0.6, -22))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -50), Vector3(0, 0.6, -50))
	_area("CourseExit", "course_exit", Vector3(0, 2, -85), Vector3(8, 5, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 3))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	_label("◆ 赛道维修检查点", pos + Vector3(0, 1.6, 0), 18)

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
