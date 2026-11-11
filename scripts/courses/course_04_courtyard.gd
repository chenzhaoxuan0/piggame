extends Node3D

const RUNNER_SCRIPT = preload("res://scripts/courses/course_runner.gd")
const MEME_SCRIPT = preload("res://scripts/courses/meme_layer.gd")
const CONFIG_SCRIPT = preload("res://scripts/courses/course_config.gd")

const BOOST_PAD = preload("res://scripts/courses/components/boost_pad.gd")
const WATERMELON_PEEL = preload("res://scripts/courses/components/watermelon_peel.gd")
const RACING_FINISH_GATE = preload("res://scripts/courses/components/racing_finish_gate.gd")
const MYSTERY_ITEM_BOX = preload("res://scripts/courses/components/mystery_item_box.gd")
const STUNT_JUMP_RAMP = preload("res://scripts/courses/components/stunt_jump_ramp.gd")
const NEON_BUMPER = preload("res://scripts/courses/components/neon_bumper.gd")
const PENDULUM_BALL = preload("res://scripts/courses/components/pendulum_ball.gd")
const ROLLING_HAY = preload("res://scripts/courses/components/rolling_hay.gd")
const SPINNING_SWEEPER = preload("res://scripts/courses/components/spinning_sweeper.gd")
const RACE_TIMER = preload("res://scripts/courses/components/race_timer.gd")
const MUD_PATCH = preload("res://scripts/courses/components/mud_patch.gd")
const ZONE_ENVIRONMENT = preload("res://scripts/courses/components/zone_environment.gd")

const SPAWN := Vector3(0, 0.6, 12)
const RECORD_TIME := 35.0 # The farm's standing record (the horse's 35 s): beating it is the course's goal
# Boost pad kick for this course (component default is 18). Seven pads at 18
# let even a clumsy dash lap beat the record by ~9 s; see the lap-time note in
# _build_track_ground for the measured tuning.
const BOOST_SPEED := 13.0
const RACING_ASPHALT := Color("1E293B") # Dark asphalt
const RACING_CURB_RED := Color("DC2626") # Red curb
const RACING_CURB_WHITE := Color("F8FAFC") # White curb
const NEON_CYAN := Color("00E5FF")
const NEON_YELLOW := Color("FACC15")
const NEON_PINK := Color("F472B6")
const GRAVEL_SAND := Color("C2A878")
const GRAVEL_SAND_DARK := Color("9C8257")
const TIRE_BLACK := Color("111827")
const CREAM := Color("FFFFFF")
const DARK := Color("0F172A")

var runner: CourseRunner
var meme_layer: MemeLayer
var race_timer: Node

var boost_pad_1: Node3D
var boost_pad_2: Node3D
var boost_pad_3: Node3D
var boost_pads: Array[Node3D] = []
var watermelon_peel: Node3D
var finish_gate: Node3D
var traffic_lights: Node3D
var start_light_label: Label3D
var start_barrier: StaticBody3D
var mud_patch: Node3D
var gravel_traps: Array[Node3D] = []
var stunt_ramp: Node3D
var rolling_tire: Node3D
var sign_pendulum: Node3D
var guardrails: Array[StaticBody3D] = []

var _curb_red_mat: StandardMaterial3D
var _curb_white_mat: StandardMaterial3D
var _final_straight_triggered := false

func _ready() -> void:
	ZONE_ENVIRONMENT.apply(self, "neon_courtyard")
	_build_track_ground()
	_build_guardrails()
	_build_start_grid()
	_build_boost_pads()
	_build_hazards()
	_build_watermelon_trap()
	_build_mystery_item_boxes()
	_build_stunt_ramp()
	_build_neon_bumpers()
	_build_finish_gate()
	_build_decorations()
	_build_markers()

	meme_layer = MEME_SCRIPT.new()
	meme_layer.name = "MemeLayer"
	add_child(meme_layer)

	race_timer = RACE_TIMER.new()
	race_timer.name = "RaceTimer"
	add_child(race_timer)
	race_timer.countdown_finished.connect(_on_race_go)

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
	if gm != null and gm.has_method("grant_course_skills"):
		# Course-scoped loans (dash for the whole race, struggle for grapples):
		# the farm story's horse/ox quests stay unfinished until really done.
		gm.grant_course_skills(["struggle", "dash"])
	runner.setup(player, SPAWN)
	# Lights out and away we go: the boom barrier holds the grid until GO, and
	# the race clock only starts then, so there is no head start to farm.
	race_timer.start_countdown(start_light_label)

func _on_race_go() -> void:
	if not is_instance_valid(start_barrier):
		return
	for child in start_barrier.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	var tween := start_barrier.create_tween()
	tween.tween_property(start_barrier, "position:y", start_barrier.position.y + 4.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(start_barrier.queue_free)

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_4"
	cfg.title = "大院隐藏关卡 · 《马车极速狂飙》打破35秒纪录！"
	cfg.desc = "终极街机竞速赛道！踩上黄色加速带极速喷火、扔西瓜皮滑倒恶犬、凭借【疾风之步】打破世界纪录冲破大门！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-40, -16, -190), Vector3(80, 40, 220))
	cfg.dog_count = 1
	cfg.dog_speed_min = 3.2
	cfg.dog_speed_max = 6.8
	cfg.memes = {
		"course_start": {"title": "3... 2... 1... 起跑！", "text": "切换极速街机赛道！踩加速带漂移过弯，冲刺打破世界纪录！", "duration": 3.0},
		"boost_pad": {"title": "屁股喷火！极速加速！", "text": "踩中加速带！氮气爆发，瞬间拉开身后恶犬十个身位！", "duration": 2.2},
		"mystery_box": {"title": "❓ 撞碎问号道具箱！", "text": "道具抽取成功！火箭喷射/后置西瓜皮/无敌金猪！", "duration": 2.2},
		"stunt_jump": {"title": "🏁 360° 空中特技！", "text": "一口猪飞跃霓虹大跳台！完美落地获得迷你涡轮加速！", "duration": 2.5},
		"landing_turbo": {"title": "🔥 完美落地迷你涡轮！", "text": "四蹄着地贴地飞行！氮气直接续上！", "duration": 2.0},
		"neon_bumper": {"title": "🎯 霓虹弹珠台反弹！", "text": "BOING！撞击霓虹缓冲柱，极限折线弹射过弯！", "duration": 2.0},
		"watermelon_slip": {"title": "恶犬踩中西瓜皮！", "text": "汪汪汪？！恶犬原地狂转3圈！摔了个狗吃屎！", "duration": 2.5},
		"tire_incoming": {"title": "⚠ 滚胎来袭！", "text": "巨型轮胎咕噜噜迎面滚来！快往两边闪！", "duration": 2.0},
		"tire_roll": {"title": "被轮胎创飞！", "text": "一口猪：我只是路过……轮胎：我也是。", "duration": 2.0},
		"mud_splash": {"title": "哼哧哼哧……陷进泥潭！", "text": "赛车小猪秒变泥猪！极速变龟速，贴边才能绕开！", "duration": 2.2},
		"gravel_trap": {"title": "想抄近道？沙坑欢迎你！", "text": "内场是减速沙坑！偷鸡不成，恶犬的口水都滴到屁股上了！", "duration": 2.5},
		"sweeper_hit": {"title": "霓虹扫堂腿！", "text": "呼——啪！起跳慢了半拍，小猪被扫成了陀螺！", "duration": 2.0},
		"signboard_wham": {"title": "招牌摆锤大摆荡！", "text": "哐！被霓虹招牌一巴掌拍飞！看准节奏再冲！", "duration": 2.0},
		"horse_dash": {"title": "野马【疾风之步】全开！", "text": "终点直道体力回满！按住 Shift 冲刺，打破 35 秒纪录的唯一机会！", "duration": 2.5},
		"record_broken": {"title": "🏁 新世界纪录诞生！ 🏁", "text": "一口猪成功打破农场 35 秒纪录！欢呼声中一头撞破大门！", "duration": 3.5},
		"record_miss": {"title": "🏁 完赛！差一点点！", "text": "没能跑进 35 秒……恶犬在终点线笑出了声，下次哼哼！", "duration": 3.5},
		"dog_bonk": {"title": "恶犬扑空", "text": "恶犬被甩在身后吃尾气！", "duration": 2.0},
		"qte_success": {"title": "疾风甩尾挣脱！", "text": "野马疾风：漂移甩尾，甩开恶犬！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "被甩飞了……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "赛道复活", "text": "赛车小猪换上新轮胎，重回跑道！", "duration": 2.2},
	}
	return cfg

func _build_track_ground() -> void:
	# A double-S circuit instead of one straight corridor. Every piece is an
	# axis-aligned slab (clean collision) and the whole lap still heads -Z, which
	# matches the track-locked third-person camera:
	#   start straight (x=0) -> right bend -> east lane (x=10)
	#   -> left bend -> mid straight -> left bend -> west lane (x=-10)
	#   -> right bend -> final gauntlet straight (x=0) -> finish -> arena.
	# The two rectangles between lanes are open gravel infields, not voids, and
	# cutting across them costs 60% speed (the dog is not slowed).
	# Lap-time tuning, measured by test_course_04_traversal (a bot that takes a
	# clean line but dodges nothing, eating 3-5 knockbacks per lap):
	#   plain running  ~37-43 s  -> misses the 35 s record
	#   dash-managed   ~36-41 s  -> the bot wastes its dash eating sweepers
	# A player who avoids the sweepers and pendulum keeps the dash payoff and
	# lands well under 35 s - 疾风之步 is how the record falls, as the design
	# doc intends. BOOST_SPEED is the tuning knob (18 gave free wins).
	_track_segment("StraightA", Vector3(10, 1, 36), Vector3(0, -0.5, 2))      # x -5..5,   z -16..20
	_track_segment("CurveB", Vector3(20, 1, 10), Vector3(5, -0.5, -21))       # x -5..15,  z -26..-16
	_track_segment("OuterB", Vector3(10, 1, 30), Vector3(10, -0.5, -41))      # x 5..15,   z -56..-26
	_track_segment("HairpinC", Vector3(20, 1, 10), Vector3(5, -0.5, -61))     # x -5..15,  z -66..-56
	_track_segment("MidC", Vector3(10, 1, 14), Vector3(0, -0.5, -73))         # x -5..5,   z -80..-66
	_track_segment("CurveD", Vector3(20, 1, 10), Vector3(-5, -0.5, -85))      # x -15..5,  z -90..-80
	_track_segment("OuterD", Vector3(10, 1, 30), Vector3(-10, -0.5, -105))    # x -15..-5, z -120..-90
	_track_segment("HairpinE", Vector3(20, 1, 10), Vector3(-5, -0.5, -125))   # x -15..5,  z -130..-120
	_track_segment("StraightC", Vector3(10, 1, 30), Vector3(0, -0.5, -145))   # x -5..5,   z -160..-130
	_track_segment("ExitArena", Vector3(14, 1, 14), Vector3(0, -0.5, -167))   # x -7..7,   z -174..-160
	_gravel_infield("InfieldGravel", Vector3(0, -0.5, -41))                   # x -5..5,   z -56..-26
	_gravel_infield("InfieldGravel2", Vector3(0, -0.5, -105))                 # x -5..5,   z -120..-90

	# Red/white racing curbs along the racing line and around the gravel infields.
	_curb_run(Vector3(-4.4, 0, 20), Vector3(-4.4, 0, -26))
	_curb_run(Vector3(4.4, 0, 20), Vector3(4.4, 0, -16))
	_curb_run(Vector3(14.4, 0, -16), Vector3(14.4, 0, -66))
	_curb_run(Vector3(5.0, 0, -26), Vector3(5.0, 0, -56))
	_curb_run(Vector3(-5.0, 0, -26), Vector3(5.0, 0, -26))
	_curb_run(Vector3(-5.0, 0, -56), Vector3(5.0, 0, -56))
	_curb_run(Vector3(-4.4, 0, -56), Vector3(-4.4, 0, -80))
	_curb_run(Vector3(4.4, 0, -66), Vector3(4.4, 0, -90))
	_curb_run(Vector3(-14.4, 0, -80), Vector3(-14.4, 0, -130))
	_curb_run(Vector3(-5.0, 0, -90), Vector3(-5.0, 0, -120))
	_curb_run(Vector3(-5.0, 0, -90), Vector3(5.0, 0, -90))
	_curb_run(Vector3(-5.0, 0, -120), Vector3(5.0, 0, -120))
	_curb_run(Vector3(4.4, 0, -120), Vector3(4.4, 0, -160))
	_curb_run(Vector3(-4.4, 0, -130), Vector3(-4.4, 0, -160))

func _gravel_infield(node_name: String, pos: Vector3) -> void:
	_track_segment(node_name, Vector3(10, 1, 30), pos, GRAVEL_SAND)
	var trap: Node3D = MUD_PATCH.new()
	trap.name = node_name + "Trap"
	trap.position = pos + Vector3(0, 0.5, 0)
	trap.patch_size = Vector2(10.0, 30.0)
	trap.mud_speed_factor = 0.4
	trap.surface_color = GRAVEL_SAND
	trap.blob_color = GRAVEL_SAND_DARK
	add_child(trap)
	trap.mud_entered.connect(func(_b):
		if meme_layer:
			meme_layer.play("gravel_trap")
	)
	gravel_traps.append(trap)

func _track_segment(node_name: String, size: Vector3, pos: Vector3, surface: Color = RACING_ASPHALT) -> StaticBody3D:
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

	var tarmac := MeshInstance3D.new()
	var tarmac_box := BoxMesh.new()
	tarmac_box.size = size
	tarmac.mesh = tarmac_box
	var tarmac_mat := StandardMaterial3D.new()
	tarmac_mat.albedo_color = surface
	tarmac_mat.roughness = 0.8
	tarmac.material_override = tarmac_mat
	body.add_child(tarmac)

	add_child(body)
	return body

func _curb_run(from: Vector3, to: Vector3) -> void:
	# Alternating red/white curb blocks laid along an axis-aligned run.
	if _curb_red_mat == null:
		_curb_red_mat = StandardMaterial3D.new()
		_curb_red_mat.albedo_color = RACING_CURB_RED
		_curb_white_mat = StandardMaterial3D.new()
		_curb_white_mat.albedo_color = RACING_CURB_WHITE
	var span := to - from
	var length := span.length()
	if length < 0.01:
		return
	var dir := span / length
	var count := int(ceil(length / 2.0))
	var seg := length / float(count)
	var along_z := absf(dir.z) > absf(dir.x)
	for i in count:
		var curb := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.06, seg) if along_z else Vector3(seg, 0.06, 0.6)
		curb.mesh = box
		curb.position = from + dir * (seg * (float(i) + 0.5)) + Vector3(0, 0.03, 0)
		curb.material_override = _curb_red_mat if i % 2 == 0 else _curb_white_mat
		add_child(curb)

func _build_guardrails() -> void:
	# Outer barriers only. The infields have no inner wall on purpose: the gravel
	# is the deterrent, and nobody can ever get boxed in behind a barrier.
	_rail_along_x("RailStartCap", 20.0, -5.0, 5.0, NEON_YELLOW)
	_rail_along_z("RailWestA", -5.0, -80.0, 20.0, NEON_CYAN)
	_rail_along_z("RailEastA", 5.0, -16.0, 20.0, NEON_PINK)
	_rail_along_x("RailNorthCapB", -16.0, 5.0, 15.0, NEON_YELLOW)
	_rail_along_z("RailEastOuter", 15.0, -66.0, -16.0, NEON_PINK)
	_rail_along_x("RailSouthCapC", -66.0, 5.0, 15.0, NEON_YELLOW)
	_rail_along_z("RailEastLong", 5.0, -160.0, -66.0, NEON_PINK)
	_rail_along_x("RailNorthCapD", -80.0, -15.0, -5.0, NEON_YELLOW)
	_rail_along_z("RailWestOuter", -15.0, -130.0, -80.0, NEON_CYAN)
	_rail_along_x("RailSouthCapE", -130.0, -15.0, -5.0, NEON_YELLOW)
	_rail_along_z("RailWestC", -5.0, -160.0, -130.0, NEON_CYAN)
	_rail_along_z("RailArenaWest", -7.0, -174.0, -160.0, NEON_CYAN)
	_rail_along_z("RailArenaEast", 7.0, -174.0, -160.0, NEON_CYAN)
	_rail_along_x("RailArenaSouth", -174.0, -7.0, 7.0, NEON_YELLOW)
	_rail_along_x("RailArenaShoulderW", -160.0, -7.0, -5.0, NEON_YELLOW)
	_rail_along_x("RailArenaShoulderE", -160.0, 5.0, 7.0, NEON_YELLOW)

func _rail_along_z(node_name: String, x: float, z_from: float, z_to: float, color: Color) -> void:
	_guardrail(node_name, Vector3(0.4, 1.2, absf(z_to - z_from)), Vector3(x, 0.6, (z_from + z_to) * 0.5), color)

func _rail_along_x(node_name: String, z: float, x_from: float, x_to: float, color: Color) -> void:
	_guardrail(node_name, Vector3(absf(x_to - x_from), 1.2, 0.4), Vector3((x_from + x_to) * 0.5, 0.6, z), color)

func _guardrail(node_name: String, size: Vector3, pos: Vector3, color: Color) -> void:
	# 1.2 m neon barrier: taller than the pig's 0.93 m jump, so only a launch clears it.
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
	mat.albedo_color = DARK
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.9
	mesh.material_override = mat
	body.add_child(mesh)

	add_child(body)
	guardrails.append(body)

func _build_start_grid() -> void:
	# Starting line gantry: its label is driven by RaceTimer's 3-2-1-GO countdown.
	traffic_lights = Node3D.new()
	traffic_lights.name = "TrafficLights"
	traffic_lights.position = Vector3(0, 0, 8.0)

	var frame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10.0, 0.6, 0.6)
	frame.mesh = box
	frame.position = Vector3(0, 4.0, 0)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = DARK
	frame.material_override = frame_mat
	traffic_lights.add_child(frame)

	start_light_label = _label("准备……", Vector3(0, 4.9, 0), 64, traffic_lights)
	start_light_label.name = "StartLightLabel"
	start_light_label.modulate = Color("22C55E")
	add_child(traffic_lights)

	# Boom barrier holding the grid until GO (opened by _on_race_go).
	start_barrier = StaticBody3D.new()
	start_barrier.name = "StartBarrier"
	start_barrier.position = Vector3(0, 0.6, 10.9)
	start_barrier.collision_layer = 1
	start_barrier.collision_mask = 0
	var barrier_shape := CollisionShape3D.new()
	var barrier_box := BoxShape3D.new()
	barrier_box.size = Vector3(10.0, 1.2, 0.3)
	barrier_shape.shape = barrier_box
	start_barrier.add_child(barrier_shape)
	var barrier_mesh := MeshInstance3D.new()
	var barrier_mesh_box := BoxMesh.new()
	barrier_mesh_box.size = Vector3(10.0, 0.35, 0.3)
	barrier_mesh.mesh = barrier_mesh_box
	barrier_mesh.position.y = 0.2
	var barrier_mat := StandardMaterial3D.new()
	barrier_mat.albedo_color = NEON_YELLOW
	barrier_mat.emission_enabled = true
	barrier_mat.emission = NEON_YELLOW
	barrier_mat.emission_energy_multiplier = 1.2
	barrier_mesh.material_override = barrier_mat
	start_barrier.add_child(barrier_mesh)
	add_child(start_barrier)

	_label("【大院金牌杯】栏杆抬起就冲！跑进 35 秒打破农场纪录！", Vector3(0, 6.2, 8.0), 24)

func _build_boost_pads() -> void:
	# Section A launch, rewards for taking each lane, and the nitro tunnel.
	boost_pad_1 = _boost_pad("BoostPad1", Vector3(0, 0, 2.0))     # Start straight
	boost_pad_2 = _boost_pad("BoostPad2", Vector3(10, 0, -30.0))  # East lane entry
	boost_pad_3 = _boost_pad("BoostPad3", Vector3(10, 0, -51.0))  # East lane exit
	_boost_pad("BoostPad4", Vector3(0, 0, -73.0))                 # Mid straight
	_boost_pad("BoostPad5", Vector3(-10, 0, -94.0))               # Nitro tunnel 1
	_boost_pad("BoostPad6", Vector3(-10, 0, -104.0))              # Nitro tunnel 2
	_boost_pad("BoostPad7", Vector3(-10, 0, -114.0))              # Nitro tunnel 3
	_label("【加速带】踩中黄色箭头直接爆发极速！", Vector3(0, 2.5, 2.0), 22)
	_label("【氮气隧道】三连加速带全速冲！小心扫堂腿！", Vector3(-10, 2.6, -92.0), 22)

func _boost_pad(node_name: String, pos: Vector3) -> Node3D:
	var pad: Node3D = BOOST_PAD.new()
	pad.name = node_name
	pad.position = pos
	pad.boost_speed = BOOST_SPEED
	add_child(pad)
	pad.boost_activated.connect(func(_p):
		if meme_layer:
			meme_layer.play("boost_pad")
	)
	boost_pads.append(pad)
	return pad

func _build_hazards() -> void:
	# Every hazard is telegraphed and non-lethal: a knockback, a slowdown, a laugh.

	# 1. Giant tire rolling up the start straight toward the incoming pig.
	rolling_tire = ROLLING_HAY.new()
	rolling_tire.name = "RollingTire"
	rolling_tire.position = Vector3(0, 0.75, -10.0)
	rolling_tire.use_lux_model = false # Neon zone: no ox-field hay bale model here
	rolling_tire.hay_color = TIRE_BLACK
	rolling_tire.roll_direction = Vector3(0, 0, 1)
	rolling_tire.roll_impulse = 9.0
	rolling_tire.auto_trigger_radius = 9.0
	rolling_tire.meme_id = "tire_roll"
	rolling_tire.telegraph_meme_id = "tire_incoming"
	add_child(rolling_tire)
	_label("⚠ 滚胎出没 · 往两边闪！", Vector3(0, 2.6, -6.0), 20)

	# 2. Traffic-cone slalom on the east lane: light props that go flying.
	for cone_pos in [Vector3(8.0, 0, -33.0), Vector3(12.0, 0, -34.2), Vector3(9.4, 0, -35.4), Vector3(11.2, 0, -36.6), Vector3(7.6, 0, -37.4)]:
		_traffic_cone(cone_pos)

	# 3. Mud puddle mid-lane: 2 m of clean tarmac on either side to skirt it.
	mud_patch = MUD_PATCH.new()
	mud_patch.name = "MudPatch"
	mud_patch.position = Vector3(10, 0, -42.5)
	mud_patch.patch_size = Vector2(6.0, 5.0)
	mud_patch.mud_speed_factor = 0.5
	add_child(mud_patch)
	mud_patch.mud_entered.connect(func(_b):
		if meme_layer:
			meme_layer.play("mud_splash")
	)
	_label("⚠ 前方泥潭！贴边绕行！", Vector3(10, 2.6, -38.5), 22)

	# 4. Nitro tunnel sweepers (west lane): low neon bars to JUMP at full boost.
	# They sweep the dog too - luring it through here is a real tactic.
	_tunnel_sweeper("NeonSweeper1", Vector3(-10, 0, -99.0), 1.8, 0.0)
	_tunnel_sweeper("NeonSweeper2", Vector3(-10, 0, -109.0), -1.8, PI * 0.5)
	_label("⚠ 霓虹扫堂腿 · 起跳！", Vector3(-10, 2.2, -97.5), 20)

	# 5. Swinging neon signboard across the final straight.
	sign_pendulum = PENDULUM_BALL.new()
	sign_pendulum.name = "NeonSignPendulum"
	sign_pendulum.position = Vector3(0, 0, -135.5)
	sign_pendulum.use_lux_model = false # Neon zone: no ox-field wrecking ball model here
	sign_pendulum.ball_color = NEON_PINK
	sign_pendulum.gantry_color = Color("334155")
	sign_pendulum.gantry_half_width = 5.0 # Posts stand in the guardrail line: no pocket to get wedged into
	sign_pendulum.swing_speed = 2.2
	sign_pendulum.max_angle_deg = 50.0
	sign_pendulum.meme_id = "signboard_wham"
	add_child(sign_pendulum)

func _tunnel_sweeper(node_name: String, pos: Vector3, speed: float, phase: float) -> void:
	var sweeper: Node3D = SPINNING_SWEEPER.new()
	sweeper.name = node_name
	sweeper.position = pos
	sweeper.use_lux_model = false # Neon zone: no ox-field padded beam model here
	sweeper.sweeper_color = NEON_PINK if speed > 0.0 else NEON_CYAN
	sweeper.rotate_speed = speed
	sweeper.phase_offset = phase
	sweeper.meme_id = "sweeper_hit"
	add_child(sweeper)

func _traffic_cone(pos: Vector3) -> void:
	# Pure slapstick prop: the pig runs straight through and the cone goes flying.
	# CharacterBody3D never pushes rigid bodies on its own, so a cone on the world
	# layer would just be a tiny roadblock. It lives on its own layer (16), which
	# neither the pig nor the dogs collide with, and a kick area supplies the launch.
	var cone := RigidBody3D.new()
	cone.name = "TrafficCone"
	cone.position = pos + Vector3(0, 0.35, 0)
	cone.collision_layer = 16
	cone.collision_mask = 1
	cone.mass = 0.35
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.24
	cyl.height = 0.7
	shape.shape = cyl
	cone.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.05
	cone_mesh.bottom_radius = 0.26
	cone_mesh.height = 0.7
	mesh.mesh = cone_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("F97316")
	mat.emission_enabled = true
	mat.emission = Color("EA580C")
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
	cone.add_child(mesh)

	var kick := Area3D.new()
	kick.name = "KickArea"
	kick.collision_layer = 0
	kick.collision_mask = 2 # Player
	var kick_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	kick_shape.shape = sphere
	kick.add_child(kick_shape)
	kick.body_entered.connect(func(body: Node3D):
		var away := cone.global_position - body.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
		var carry := Vector3.ZERO
		if body is CharacterBody3D:
			carry = (body as CharacterBody3D).velocity * 0.35
			carry.y = 0.0
		cone.apply_central_impulse((away * 2.2 + carry) * cone.mass + Vector3.UP * 1.6)
		cone.apply_torque_impulse(Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2)))
	)
	cone.add_child(kick)
	add_child(cone)

func _build_watermelon_trap() -> void:
	# Sits exactly on the dog's racing line through the second bend.
	watermelon_peel = WATERMELON_PEEL.new()
	watermelon_peel.name = "WatermelonPeelItem"
	watermelon_peel.position = Vector3(4.6, 0, -61.0)
	add_child(watermelon_peel)

	watermelon_peel.peel_slipped.connect(func(_victim):
		if meme_layer:
			meme_layer.play("watermelon_slip")
	)

	_label("【西瓜皮陷阱】身后恶犬踩中会原地打转3圈！", Vector3(4.6, 2.5, -59.0), 20)

func _build_mystery_item_boxes() -> void:
	_mystery_box("MysteryItemBox1", Vector3(-2.0, 0, -4.0))   # Start straight
	_mystery_box("MysteryItemBox2", Vector3(12.5, 0, -47.5))  # East lane, past the mud
	_mystery_box("MysteryItemBox3", Vector3(-12.5, 0, -104.0)) # Nitro tunnel
	_label("【马车问号道具箱】撞碎抽取火箭推进、后置西瓜皮或无敌金猪！", Vector3(0, 3.4, -3.0), 20)

func _mystery_box(node_name: String, pos: Vector3) -> void:
	var item_box = MYSTERY_ITEM_BOX.new()
	item_box.name = node_name
	item_box.position = pos
	add_child(item_box)
	item_box.item_collected.connect(func(_item, _p):
		if meme_layer:
			meme_layer.play("mystery_box")
	)

func _build_stunt_ramp() -> void:
	# The finish leap: launches down the final straight, and a clean touchdown
	# pays out the mini-turbo the banner always promised.
	stunt_ramp = STUNT_JUMP_RAMP.new()
	stunt_ramp.name = "StuntMegaRamp"
	stunt_ramp.position = Vector3(0, 0, -141.0)
	stunt_ramp.launch_vertical = 10.0
	stunt_ramp.launch_forward = 20.0
	add_child(stunt_ramp)

	stunt_ramp.ramp_jumped.connect(func(_r, _p):
		if meme_layer:
			meme_layer.play("stunt_jump")
	)
	stunt_ramp.landing_turbo.connect(func(_p):
		if meme_layer:
			meme_layer.play("landing_turbo")
	)

	_label("【特技大跳台】飞跃终点线！落地迷你涡轮！", Vector3(0, 3.8, -139.0), 22)

func _build_neon_bumpers() -> void:
	# Pinball bumpers in the outside corner of each bend: run wide and you get
	# ricocheted back onto the racing line.
	_neon_bumper("NeonBumper1", Vector3(12.5, 0, -18.5))
	_neon_bumper("NeonBumper2", Vector3(12.5, 0, -63.5))
	_neon_bumper("NeonBumper3", Vector3(-12.5, 0, -82.5))
	_neon_bumper("NeonBumper4", Vector3(-12.5, 0, -127.5))
	_label("➡ 右弯并入外道 · 弹力柱帮你折线过弯", Vector3(5.0, 2.8, -19.0), 20)
	_label("⬅ 左弯进入氮气隧道", Vector3(-5.0, 2.8, -78.0), 20)
	_label("➡ 右弯回主道 · 冲刺终点！", Vector3(-8.0, 2.8, -123.0), 20)

func _neon_bumper(node_name: String, pos: Vector3) -> void:
	var bumper = NEON_BUMPER.new()
	bumper.name = node_name
	bumper.position = pos
	add_child(bumper)
	bumper.bumper_hit.connect(func(_b, _target):
		if meme_layer:
			meme_layer.play("neon_bumper")
	)

func _build_finish_gate() -> void:
	finish_gate = RACING_FINISH_GATE.new()
	finish_gate.name = "RacingFinishGate"
	finish_gate.gate_width = 10.0
	finish_gate.gate_height = 5.5
	finish_gate.record_time = RECORD_TIME
	finish_gate.position = Vector3(0, 0, -156.0)
	add_child(finish_gate)

	# The gate pulls the clock itself when the pig crosses, independent of
	# signal order; stop() freezes the timer at that instant.
	finish_gate.time_provider = func() -> float:
		return race_timer.stop() if race_timer != null else -1.0
	finish_gate.finish_line_crossed.connect(_on_finish_line_crossed)

func _on_finish_line_crossed(player: Node3D) -> void:
	if meme_layer:
		meme_layer.play("record_broken" if finish_gate.record_broken else "record_miss")
	runner._on_exit(player)

func _build_decorations() -> void:
	# Neon floodlights mounted on the outside of the barriers.
	for light_pos in [Vector3(-6.5, 0, 4), Vector3(6.5, 0, 4), Vector3(16.5, 0, -30), Vector3(16.5, 0, -52), Vector3(6.5, 0, -73), Vector3(-16.5, 0, -98), Vector3(-16.5, 0, -116), Vector3(-6.5, 0, -145), Vector3(6.5, 0, -145)]:
		_stadium_light(light_pos)
	# Tire stacks marking the gravel infields.
	for stack_pos in [Vector3(-2.5, 0, -33), Vector3(2.0, 0, -41), Vector3(-1.5, 0, -49), Vector3(2.5, 0, -97), Vector3(-2.0, 0, -105), Vector3(1.5, 0, -113)]:
		_tire_stack(stack_pos)

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
	lamp_mat.albedo_color = NEON_YELLOW
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("FEF08A")
	lamp_mat.emission_energy_multiplier = 2.0
	lamp.material_override = lamp_mat
	add_child(lamp)

func _tire_stack(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "TireStack"
	body.position = pos + Vector3(0, 0.6, 0)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 1.2
	shape.shape = cyl
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.7
	cyl_mesh.bottom_radius = 0.7
	cyl_mesh.height = 1.2
	mesh.mesh = cyl_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TIRE_BLACK
	mat.roughness = 0.9
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)

func _build_markers() -> void:
	# The start trigger sits behind the boom barrier, so the dogs only wake on GO.
	_area("CourseStart", "course_start", Vector3(0, 1, 9.5), Vector3(10, 3, 2))
	# Trigger gates span the full lane; the respawn positions double as the dog's
	# route waypoints, so each leg between them stays on the tarmac through the bends.
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -12), Vector3(0, 0.6, -14))
	_checkpoint("Checkpoint2", 2, Vector3(10, 1, -28), Vector3(10, 0.6, -28))
	_checkpoint("Checkpoint3", 3, Vector3(10, 1, -54), Vector3(10, 0.6, -54))
	_checkpoint("Checkpoint4", 4, Vector3(0, 1, -68), Vector3(0, 0.6, -67))
	_checkpoint("Checkpoint5", 5, Vector3(0, 1, -78), Vector3(0, 0.6, -78))
	_checkpoint("Checkpoint6", 6, Vector3(-10, 1, -92), Vector3(-10, 0.6, -92))
	_checkpoint("Checkpoint7", 7, Vector3(-10, 1, -118), Vector3(-10, 0.6, -118))
	_checkpoint("Checkpoint8", 8, Vector3(0, 1, -132), Vector3(0, 0.6, -131))
	_area("CourseExit", "course_exit", Vector3(0, 2, -167), Vector3(8, 5, 3))

	var final_straight := _area("FinalStraightTrigger", "", Vector3(0, 1, -131.5), Vector3(10, 3, 1.5))
	final_straight.body_entered.connect(_on_final_straight_entered)
	_label("【终点直道】疾风之步全开！躲摆锤、飞跳台、冲线！", Vector3(0, 3.2, -131.5), 22)

func _on_final_straight_entered(body: Node3D) -> void:
	if _final_straight_triggered:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_final_straight_triggered = true
	# Horse dash payoff: a full stamina bar for the sprint to the line.
	if "stamina" in body and "max_stamina" in body:
		body.stamina = body.max_stamina
	if meme_layer:
		meme_layer.play("horse_dash")

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(10, 3, 2))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	area.set_meta("respawn_yaw", 0.0) # Every lane heads -Z: respawn looking down it, not at the next bend
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
