extends Node3D

# 序章 · 噩梦屠宰场（course_0）。
# 猪在梦里回到屠宰场：圈栏困雾逃窜 → 蛇形转折的流水线车间（右转-左转-右转-
# 左转，最终朝向仍是出口 -Z）→ 装卸月台被"农场主"追逐，冲出铁门即惊醒。
# 这是机制教学关：不借出任何技能——被抓全是滑稽逃脱，教非致死循环本身。
# 铁钩走廊只有 8 米宽（钩扫 ±3.2 米，贴墙缝不足 1 米）——钩子是真阻碍，必须
# 掐时机。画风是"运转中的写实屠宰工厂"而非地狱：灰白混凝土、磨损钢材、冷白灯。
# 序章是五关画风的起点（写实 photorealistic），与后续体素/童话/霓虹区反差开
# （docs/ZONE_STYLE_ASSET_PLAN.md）；全部场地要素为 Lux3D 写实资产，只换视觉，
# 碰撞与机关参数不动（AGENTS.md §5 分区画风制）。

const ASSETS = preload("res://scripts/art/asset_library.gd")
const RUNNER_SCRIPT = preload("res://scripts/courses/course_runner.gd")
const MEME_SCRIPT = preload("res://scripts/courses/meme_layer.gd")
const CONFIG_SCRIPT = preload("res://scripts/courses/course_config.gd")

const PATROL_GUARD_DOG = preload("res://scripts/courses/components/patrol_guard_dog.gd")
const DROWSY_FOG = preload("res://scripts/courses/components/drowsy_fog.gd")
const CONVEYOR_BELT = preload("res://scripts/courses/components/conveyor_belt.gd")
const PENDULUM_BALL = preload("res://scripts/courses/components/pendulum_ball.gd")
const LAUNCH_PAD = preload("res://scripts/courses/components/launch_pad.gd")
const BUMPER_PILLAR = preload("res://scripts/courses/components/bumper_pillar.gd")
const DECOY_GOAL = preload("res://scripts/courses/components/decoy_goal.gd")
const ZONE_ENVIRONMENT = preload("res://scripts/courses/components/zone_environment.gd")

const SPAWN := Vector3(0, 0.6, 12)
# Factory palette: light grey concrete, cool steel, hazard amber. The unease
# comes from the machinery, not from darkness.
const FLOOR_CONCRETE := Color("8A9099")
const WALL_STEEL := Color("5D6570")
const CAGE_STEEL := Color("7A8593")
const STEEL := Color("8C99A8")
const EMBER := Color("8C2B2B")
const HAZARD_AMBER := Color("FFB300")
const WAKE_LIGHT := Color("FFF3E0")
const CREAM := Color("FFFFFF")
const DARK := Color("2A2E33")

var runner: CourseRunner
var meme_layer: MemeLayer

var drowsy_fog: Node3D
var sleeping_dog: Node3D
var belt_a: Node3D
var belt_b: Node3D
var belt_c: Node3D
var belt_d: Node3D
var fake_sun_door: Node3D
var exit_hint_label: Label3D
var _dock_chase_triggered := false
var _door_slammed := false
# Tutorial beats, one-shot each.
var _dash_taught := false
# Drowsy-fog proximity toasts, edge-triggered with hysteresis (reset once the
# fog has fallen well behind again after a jolt).
var _fog_warn_stage := 0
var _turn_shots: Dictionary = {} # camera-turn trigger name -> already fired

func _ready() -> void:
	ZONE_ENVIRONMENT.apply(self, "nightmare_plant")
	_build_ground()
	_build_holding_pins()
	_build_processing_floor()
	_build_loading_dock()
	_build_exit()
	_build_markers()

	meme_layer = MEME_SCRIPT.new()
	meme_layer.name = "MemeLayer"
	add_child(meme_layer)

	runner = RUNNER_SCRIPT.new()
	runner.name = "CourseRunner"
	runner.config = _make_config()
	add_child(runner)

func _process(_delta: float) -> void:
	_update_fog_pressure()

func _update_fog_pressure() -> void:
	# Escalating dream-pressure toasts as the fog closes in; the camera faces
	# forward, so the wall itself is only visible at the last moment - the
	# toasts ARE the rear-view mirror.
	if drowsy_fog == null or not is_instance_valid(drowsy_fog) or meme_layer == null:
		return
	if not runner or not is_instance_valid(runner.player):
		return
	var dist: float = drowsy_fog.global_position.z - runner.player.global_position.z
	var stage := 0
	if dist < 3.0:
		stage = 3
	elif dist < 6.0:
		stage = 2
	elif dist < 10.0:
		stage = 1
	if stage > _fog_warn_stage:
		match stage:
			1: meme_layer.play("fog_wake")
			2: meme_layer.play("fog_closer")
			3: meme_layer.play("fog_very_close")
		_fog_warn_stage = stage
	elif stage == 0 and _fog_warn_stage > 0 and dist > 13.0:
		_fog_warn_stage = 0

func setup(player: Node3D) -> void:
	player.reset_at(SPAWN)
	player.set_meta("in_stealth_box", false)
	for child in player.find_children("*", "CardboardBoxProp", true, false):
		child.queue_free()
	# Deliberately NO course skill loans: the dream pig knows nothing yet, so
	# every dog grapple resolves as a slapstick escape - that IS the tutorial.
	runner.setup(player, SPAWN)

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_0"
	cfg.title = "序幕 · 噩梦"
	cfg.desc = "困意浓雾在身后漫过来。沿流水线一路转折，在被追上之前冲出月台铁门——从这场梦里醒来！"
	cfg.kill_y = -12.0
	# The serpentine sprawls east: legs live between x -6 and x 52, z 20..-88.
	cfg.bounds = AABB(Vector3(-15, -16, -100), Vector3(75, 40, 130))
	cfg.dog_count = 1
	cfg.dog_speed_min = 3.6
	cfg.dog_speed_max = 5.6
	# The dream butcher is the farmer himself (stun prod and all).
	cfg.dog_visual_asset_id = "CHAR_07"
	cfg.memes = {
		# Progressive reveal: the opening is pure confusion (no location named);
		# suspicion grows in the pens, the hooks land the first real dread in
		# the plant, and the word 屠宰场 only drops at the mid-factory corner.
		"course_start": {"title": "醒一醒——先离开这里！", "text": "头顶的灯管白得发亮，空气里有铁锈和消毒水的味道……用 W/A/S/D 移动。身后有困意浓雾在漫过来——快跑！", "duration": 4.5},
		"reveal_plant": {"title": "这里是——屠宰场！！", "text": "一车间、二车间……挂在铁钩上的是肉。活物被运进来，然后——别想了。找到月台，冲出去，醒来！", "duration": 3.5},
		"dash_learned": {"title": "梦里的本能觉醒了！", "text": "按住【Shift】冲刺！下方体力条会用尽——逆着传送带冲过去！", "duration": 3.5},
		"dodge_learned": {"title": "红圈预警！", "text": "屠夫扑击前脚下会亮起红圈——看准时机按【Shift】闪避！", "duration": 3.5},
		"fog_wake": {"title": "困意……", "text": "身后有什么东西漫过来了。别回头，跑。", "duration": 2.0},
		"fog_closer": {"title": "困意更近了！", "text": "眼皮好沉……不行！这是梦里的困意，被追上会在梦里睡着的！", "duration": 2.2},
		"fog_very_close": {"title": "快跑！！", "text": "睫毛只剩一条缝了！！", "duration": 1.8},
		"fog_caught": {"title": "眼皮一沉……", "text": "你在原地睡着了——梦把你摇回上一个亮着灯的角落。别停下！", "duration": 2.5},
		"door_slam": {"title": "砰！", "text": "你甩上铁门。困意在门外撞了两下，没跟进来。", "duration": 2.5},
		"sleeping_dog": {"title": "Zzz……", "text": "别碰睡着的狗。碰了你就会知道为什么。", "duration": 2.0},
		"belt_ride": {"title": "流水线全速运转！", "text": "整条路都是传送带！逆流冲刺，别被送回上一间车间！", "duration": 2.5},
		"belt_side": {"title": "横移转移带！", "text": "带子往墙边甩！稳住——它要把你甩向那扇画出来的门！", "duration": 2.5},
		"hook_wham": {"title": "哐！铁钩摆荡！", "text": "挂肉的钩子把你当成了货……车间窄，掐着摆动节奏过！", "duration": 2.0},
		"steam_pop": {"title": "嘶——！蒸汽喷口！", "text": "白色蒸汽把你顶上天！落地记得继续跑！", "duration": 2.0},
		"prod_zap": {"title": "滋啦！电击棍！", "text": "浑身酥麻原地跳了一段舞……离黄色立柱远点！", "duration": 2.2},
		"fake_sun": {"title": "这扇门上画着太阳……", "text": "你一头撞上去——是墙。画出来的太阳不发光。", "duration": 2.5},
		"fake_sun_again": {"title": "（还是那扇画着太阳的门）", "text": "它还是墙。真正的出口在月台尽头的铁门。", "duration": 2.0},
		"butcher_chase": {"title": "梦里的农场主出现了！", "text": "他手里的电击棍闪着光——别回头，冲向月台铁门！！", "duration": 3.0},
		"dog_bonk": {"title": "滋啦——！", "text": "被电得浑身抽搐……但你还在跑！梦里的疼不算数！", "duration": 2.0},
		"respawn": {"title": "噩梦重演……", "text": "你回到上一个亮着灯的地方。深呼吸，再来。", "duration": 2.2},
	}
	return cfg

# ------------------------------------------------------------------
# Ground plan: a serpentine factory. Floors are unions of leg slabs; walls
# bound each leg's outer edges; corners are the slab overlaps.
#   L1 pens     x -6..6    z 20..-34   runs -Z (12 m wide; fog lives here)
#   L2 lines    x 6..34    z -34..-26  runs +X (8 m: hooks actually block)
#   L3 transfer x 26..34   z -58..-34  runs -Z (8 m: line + lateral belt)
#   L4 link     x 34..46   z -58..-50  runs +X (8 m; steam gauntlet)
#   L5 dock     x 40..52   z -50..-88  runs -Z (12 m; butcher sprint)
# Net turns: right, left, right, left - the exit still faces -Z.
# ------------------------------------------------------------------
func _build_ground() -> void:
	_floor_slab("FloorL1", Vector3(12, 1, 54), Vector3(0, -0.5, -7))
	_floor_slab("FloorL2", Vector3(28, 1, 8), Vector3(20, -0.5, -30))
	_floor_slab("FloorL3", Vector3(8, 1, 24), Vector3(30, -0.5, -46))
	_floor_slab("FloorL4", Vector3(12, 1, 8), Vector3(40, -0.5, -54))
	_floor_slab("FloorL5", Vector3(12, 1, 38), Vector3(46, -0.5, -69))

	# Outer walls (0.4 thick). Every corner sealed, every leg mouth open.
	_wall_z("W1West", -6.2, -34.0, 20.0)      # pens west
	_wall_x("W1North", 20.2, -6.0, 6.0)       # pens back cap
	_wall_z("W1East", 6.2, -26.0, 20.0)       # pens east, above the L2 mouth
	_wall_x("W2North", -25.8, 6.0, 34.0)      # L2 north
	_wall_z("W23East", 34.2, -50.0, -26.0)    # L2 east cap + L3 east
	_wall_x("WSouth", -34.2, -6.0, 26.0)      # pens south + L2 south (L3 mouth open)
	_wall_z("W3West", 25.8, -58.0, -34.0)     # L3 west
	_wall_x("W3South", -58.2, 26.0, 40.0)     # L3 south + L4 south-west stub
	_wall_x("W45North", -49.8, 34.0, 52.0)    # L4 north + L5 north-east
	_wall_x("W4South", -58.2, 46.0, 52.0)     # L4 south-east stub (below corner)
	_wall_z("W4East", 46.2, -58.0, -50.0)     # L4 east cap
	_wall_z("W5East", 52.2, -88.0, -50.0)     # dock east
	_wall_z("W5West", 39.8, -88.0, -58.0)     # dock west (south of the corner)
	_wall_x("W5South", -88.2, 40.0, 52.0)     # dock far cap

func _floor_slab(node_name: String, size: Vector3, pos: Vector3) -> void:
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
	mat.albedo_color = FLOOR_CONCRETE
	mat.roughness = 0.95
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	# Realistic concrete tile dressing over the slab (collision unchanged).
	ASSETS.tile_slab_top(body, "ENV_C0_FLOOR", size, Vector3(4, 0.2, 4), size.y * 0.5)

func _wall_z(node_name: String, x: float, z_from: float, z_to: float) -> void:
	var body := _solid_box(node_name, Vector3(0.4, 4.2, absf(z_to - z_from)), Vector3(x, 2.1, (z_from + z_to) * 0.5), WALL_STEEL)
	# Wall panel segments run along Z: yaw the X-long panel 90 degrees. The
	# body origin sits at mid-height, so the segment base goes to local -2.1.
	# The procedural box hides: same footprint as the model run, z-fight risk.
	ASSETS.tile_run(body, "ENV_C0_WALL", Vector3(0.4, 4.2, absf(z_to - z_from)), Vector3(4, 0.4, 4.2), 90.0, -2.1)
	ASSETS.hide_procedural_visuals(body)

func _wall_x(node_name: String, z: float, x_from: float, x_to: float) -> void:
	var body := _solid_box(node_name, Vector3(absf(x_to - x_from), 4.2, 0.4), Vector3((x_from + x_to) * 0.5, 2.1, z), WALL_STEEL)
	ASSETS.tile_run(body, "ENV_C0_WALL", Vector3(absf(x_to - x_from), 4.2, 0.4), Vector3(4, 0.4, 4.2), 0.0, -2.1)
	ASSETS.hide_procedural_visuals(body)

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
	mat.roughness = 0.9
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body

# ------------------------------------------------------------------
# L1: 圈栏 - drowsy fog chase + cage weave (the dream's antagonist is
# falling asleep again).
# ------------------------------------------------------------------
func _build_holding_pins() -> void:
	_label("【W / A / S / D  移动】", Vector3(0, 2.0, 10.5), 34)
	_label("【这里是……圈栏？】铁栏杆，铁链——这里关着好多活物。\n身后有困意浓雾在追！绕开笼架、别碰睡着的狗，\n冲进尽头的铁门甩掉它——然后右转！", Vector3(0, 2.8, 8.0), 20)

	for cage in [
		{"pos": Vector3(-2.5, 0.8, 4.0), "name": "CagePenA"},
		{"pos": Vector3(2.5, 0.8, -2.0), "name": "CagePenB"},
		{"pos": Vector3(-2.5, 0.8, -8.0), "name": "CagePenC"},
		{"pos": Vector3(2.5, 0.8, -14.0), "name": "CagePenD"},
	]:
		var pen := _solid_box(cage["name"], Vector3(5.0, 1.6, 2.4), cage["pos"], CAGE_STEEL)
		# Realistic steel livestock cage (model carries its own bars; the
		# procedural box + bar dressing hides, collision unchanged). The body
		# origin sits at mid-height, so sink the model half a height down.
		ASSETS.replace_visuals(pen, "PROP_C0_CAGE", Vector3(0, -0.8, 0))

	sleeping_dog = PATROL_GUARD_DOG.new()
	sleeping_dog.name = "SleepingPenDog"
	sleeping_dog.position = Vector3(2.2, 0, -11.0)
	sleeping_dog.body_color = Color("6B5D52")
	sleeping_dog.display_name = "Zzz……"
	add_child(sleeping_dog)
	sleeping_dog.guard_nipped.connect(func(_p):
		if meme_layer:
			meme_layer.play("sleeping_dog")
	)
	var zzz := _label("Zzz……", Vector3(0, 1.9, 0), 24, sleeping_dog)
	zzz.name = "SleepZzz"

	drowsy_fog = DROWSY_FOG.new()
	drowsy_fog.name = "DrowsyFog"
	drowsy_fog.position = Vector3(0, 0, 20.0)
	drowsy_fog.fog_speed = 2.6
	add_child(drowsy_fog)
	drowsy_fog.fog_touched.connect(_on_fog_caught)

	_solid_box("PensDoorPostL", Vector3(0.5, 4.2, 0.5), Vector3(-5.4, 2.1, -19.5), STEEL)
	_solid_box("PensDoorPostR", Vector3(0.5, 4.2, 0.5), Vector3(5.4, 2.1, -19.5), STEEL)
	_solid_box("PensDoorTop", Vector3(11.3, 0.5, 0.5), Vector3(0, 4.45, -19.5), STEEL)
	_label("铁门就在前面！", Vector3(0, 3.2, -17.0), 20)

	var slam := _area("PensDoorTrigger", "", Vector3(0, 1, -19.5), Vector3(12, 4, 1.2))
	slam.body_entered.connect(_on_pens_door_entered)

	# Tutorial hurdle 1: full corridor width, 0.55 m tall - walking is blocked,
	# the pig's 0.93 m jump clears it. Space is taught on the calm strip right
	# after the fog door, before the plant needs jumping again.
	_hurdle("TutorialHurdle1", Vector3(11.2, 0.55, 0.5), Vector3(0, 0.275, -23.5))

func _on_fog_caught(player: Node3D) -> void:
	if drowsy_fog == null or not is_instance_valid(drowsy_fog):
		return
	if player.has_method("is_knocked_back") and player.is_knocked_back():
		return # Already being thrown around - no double-dip on one mistake.
	# Caught by drowsiness is the standard non-lethal failure loop (like the
	# creek sweeping the pig back to shore): wake up at the last checkpoint
	# and the fog falls back behind it. The old forward-jolt looked fun but
	# pinned the pig against cage faces, trading a stumble for a grind.
	var respawn_pos: Vector3 = runner.last_checkpoint if runner != null else SPAWN
	if player.has_method("reset_at"):
		player.reset_at(respawn_pos)
	drowsy_fog.retreat_to_behind(respawn_pos.z)
	_fog_warn_stage = 0
	if meme_layer:
		meme_layer.play("fog_caught")

func _on_pens_door_entered(body: Node3D) -> void:
	if _door_slammed:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_door_slammed = true
	if drowsy_fog != null and is_instance_valid(drowsy_fog):
		drowsy_fog.stop_and_fade()
	if meme_layer:
		meme_layer.play("door_slam")

# ------------------------------------------------------------------
# L2+L3+L4: 流水线车间 - the conveyor escape, now with corners. Belt
# corridors are 8 m wide: hooks sweep +-3.2 m, wall lanes are under a metre -
# the hooks ARE the obstacle; you time them or eat steel.
# ------------------------------------------------------------------
func _build_processing_floor() -> void:
	_label("【流水线一车间】头顶挂着的是……挂肉的铁钩？！\n脚下的路全是传送带——掐着铁钩的节奏过！", Vector3(0, 3.0, -23.5), 19)
	_label("踏上皮带——【按住 Shift 冲刺】逆流冲过去！", Vector3(8.0, 2.4, -30.0), 22)

	# L2 (eastbound, z -34..-26): two westbound lines with a prod crossing.
	belt_a = _belt("BeltA", Vector3(13, -0.35, -30), Vector3(10, 0.35, 7.2), Vector3(-1, 0, 0), 2.8)
	belt_a.belt_entered.connect(_on_first_belt_entered)
	belt_b = _belt("BeltB", Vector3(26, -0.35, -30), Vector3(12, 0.35, 7.2), Vector3(-1, 0, 0), 3.4)
	_stun_prod("StunProdStrip1", Vector3(19.0, 0, -30.0))

	# Hooks on eastbound legs swing ACROSS the corridor: the gantry is rotated
	# to span the 8 m width, posts hug the walls (no pocket, no wide lane).
	_hook("MeatHook1", Vector3(13.0, 0, -30.0), true, 2.7, 0.0)
	_hook("MeatHook2", Vector3(26.0, 0, -30.0), true, 3.0, PI * 0.6)
	_steam_vent(Vector3(11.0, 0, -28.5), Vector3(-0.45, 0, 0))
	_steam_vent(Vector3(23.0, 0, -31.5), Vector3(-0.45, 0, 0))

	_label("← 左转，二车间", Vector3(32.5, 2.6, -30.0), 20)

	# L3 (southbound, x 26..34): one more line under a hook, then the lateral
	# transfer belt flinging you east into the painted-sun wall.
	belt_c = _belt("BeltC", Vector3(30, -0.35, -42), Vector3(7.2, 0.35, 8), Vector3(0, 0, 1), 3.2)
	_stun_prod("StunProdStrip2", Vector3(30.0, 0, -47.0))
	_hook("MeatHook3", Vector3(30.0, 0, -42.0), false, 3.2, PI * 0.3)

	belt_d = _belt("BeltD", Vector3(29.8, -0.35, -50.5), Vector3(7.2, 0.35, 5), Vector3(1, 0, 0), 3.0)
	var door_frame := _solid_box("FakeSunDoorFrame", Vector3(0.4, 3.2, 2.4), Vector3(33.7, 1.6, -50.5), EMBER)
	# The painted fake door: flaking oil paint on a wall panel (the sun label
	# stays, the procedural frame box hides). Body origin at mid-height again.
	ASSETS.replace_visuals(door_frame, "PROP_C0_PAINTED_DOOR", Vector3(0, -1.6, 0))
	var sun_label := _label("☀\n（出口？）", Vector3(-0.35, 0.6, 0), 40, door_frame)
	sun_label.rotation.y = -PI * 0.5
	fake_sun_door = DECOY_GOAL.new()
	fake_sun_door.name = "FakeSunDoor"
	fake_sun_door.position = Vector3(32.9, 0, -50.5)
	fake_sun_door.meme_id = "fake_sun"
	fake_sun_door.telegraph_meme_id = "fake_sun_again"
	add_child(fake_sun_door)
	exit_hint_label = _label("【真正的出口】右转 → 走廊尽头 → 左转，月台铁门！", Vector3(30, 3.4, -56.5), 20)
	exit_hint_label.visible = false
	exit_hint_label.name = "RealExitHint"
	fake_sun_door.real_exit_hint_path = fake_sun_door.get_path_to(exit_hint_label)

	_label("右转，连接走廊 →", Vector3(31.0, 2.6, -55.5), 20)

	# L4 (eastbound link, x 34..46): a jump hurdle, steam and one hook.
	_hurdle("TutorialHurdle2", Vector3(0.5, 0.55, 7.2), Vector3(38.5, 0.275, -54.0))
	_hook("MeatHook4", Vector3(42.0, 0, -54.0), true, 2.8, PI)
	_steam_vent(Vector3(38.0, 0, -52.5), Vector3(-0.45, 0, 0))
	_steam_vent(Vector3(43.0, 0, -55.5), Vector3(-0.45, 0, 0))

	_label("← 左转，装卸月台！", Vector3(44.5, 2.8, -54.0), 20)

	_build_camera_turns()
	_build_plant_dressing()

func _belt(node_name: String, pos: Vector3, size: Vector3, dir: Vector3, speed: float) -> Node3D:
	var belt: Node3D = CONVEYOR_BELT.new()
	belt.name = node_name
	belt.position = pos
	belt.belt_size = size
	belt.belt_direction = dir
	belt.belt_speed = speed
	belt.lux_asset_id = "PROP_C0_CONVEYOR" # Realistic line dressing; stripes keep scrolling
	add_child(belt)
	belt.belt_entered.connect(func(_b):
		if meme_layer:
			meme_layer.play("belt_ride")
	)
	return belt

func _hurdle(node_name: String, size: Vector3, pos: Vector3) -> void:
	# Low amber fence blocking the full corridor width: walking stops, the
	# pig's 0.93 m jump clears it. This is where Space gets taught.
	var hurdle := _solid_box(node_name, size, pos, HAZARD_AMBER)
	var hint := _label("【空格 跳跃！】", Vector3(0, 1.4, 0), 30, hurdle)
	hint.name = "JumpHint"
	hint.modulate = Color("FFF59D")

func _on_first_belt_entered(body: Node3D) -> void:
	# The sprint lesson: the belt outruns walking pace, so in the dream the
	# pig's instinct wakes - a course-scoped dash loan (cleared on waking; the
	# farm story still teaches nothing). The stamina gauge appears with it.
	if _dash_taught:
		return
	_dash_taught = true
	var gm := get_tree().root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("grant_course_skills"):
		gm.grant_course_skills(["dash"])
	if body.has_method("set_dash_enabled"):
		body.set_dash_enabled(true)
	if meme_layer:
		meme_layer.play("dash_learned")

func _hook(node_name: String, pos: Vector3, across_z: bool, speed: float, phase: float) -> void:
	var hook: Node3D = PENDULUM_BALL.new()
	hook.name = node_name
	hook.position = pos
	hook.use_lux_model = true
	hook.lux_asset_id = "PROP_C0_MEATHOOK" # Zone-realistic hook, not the ox-field ball
	hook.ball_color = STEEL
	hook.gantry_color = Color("4A545E")
	# Dream hooks: arm 3.6, swing 30 -> sweep +-2.66 m. In the 8 m corridors
	# the mid-band (5.3 m) is a timing gate players must read, while the 1.3 m
	# wall lanes are the slow-but-safe line (the belt is full width either way).
	# Eastbound legs rotate the gantry 90 deg so the hook swings ACROSS the
	# belt instead of along it.
	hook.rotation.y = PI * 0.5 if across_z else 0.0
	hook.gantry_half_width = 3.6
	hook.swing_speed = speed
	hook.phase_offset = phase
	hook.arm_length = 3.6
	hook.max_angle_deg = 30.0
	hook.knockback_power = 4.5
	hook.knockback_up = 3.2
	hook.meme_id = "hook_wham"
	add_child(hook)

func _stun_prod(node_name: String, pos: Vector3) -> void:
	var pillar: Node3D = BUMPER_PILLAR.new()
	pillar.name = node_name
	pillar.position = pos
	pillar.bumper_color = HAZARD_AMBER
	pillar.cap_color = Color("FFF59D")
	pillar.star_color = Color("00E5FF")
	pillar.lux_asset_id = "PROP_C0_STUN_PROD" # Realistic hazard-striped shocker pillar
	pillar.meme_id = "prod_zap" # The written zap toast never fired without this
	add_child(pillar)

func _steam_vent(pos: Vector3, back_dir: Vector3) -> void:
	var steam: Node3D = LAUNCH_PAD.new()
	steam.name = "SteamVent"
	steam.position = pos
	steam.use_lux_model = true
	steam.lux_asset_id = "PROP_C0_STEAM_VENT" # Realistic cast-iron floor grate
	steam.pad_color = WAKE_LIGHT
	steam.launch_direction = back_dir
	steam.launch_power = 5.0
	steam.launch_up = 6.5
	steam.meme_id = "steam_pop"
	add_child(steam)

func _build_camera_turns() -> void:
	# Corner triggers: the third-person camera stays yaw-locked to the leg
	# axis (free yaw would spin on strafe/backpedal), so each corner smoothly
	# rotates it to the next leg's heading. -90 deg faces +X, 0 faces -Z.
	# Turn 2 doubles as the nightmare's mid-factory reveal beat (one-shot).
	_turn_trigger("CameraTurn1", Vector3(8.0, 1.5, -30.0), Vector3(3, 3, 8), -90.0)
	_turn_trigger("CameraTurn2", Vector3(30.0, 1.5, -36.5), Vector3(8, 3, 3), 0.0, "reveal_plant")
	_turn_trigger("CameraTurn3", Vector3(36.0, 1.5, -54.0), Vector3(3, 3, 8), -90.0)
	_turn_trigger("CameraTurn4", Vector3(43.0, 1.5, -56.0), Vector3(8, 3, 3), 0.0)

func _turn_trigger(node_name: String, pos: Vector3, size: Vector3, yaw_deg: float, meme: String = "") -> void:
	var area := _area(node_name, "", pos, size)
	area.set_meta("turn_yaw_deg", yaw_deg)
	area.set_meta("turn_meme", meme)
	area.body_entered.connect(_on_turn_entered.bind(area))

func _on_turn_entered(body: Node3D, area: Area3D) -> void:
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	if _turn_shots.get(area.name, false):
		return
	_turn_shots[area.name] = true
	var meme: String = area.get_meta("turn_meme", "")
	if not meme.is_empty() and meme_layer:
		meme_layer.play(meme)
	var office_root := get_parent()
	if office_root == null:
		return
	var camera = office_root.get("camera")
	if camera != null and camera.has_method("smooth_turn_yaw"):
		camera.smooth_turn_yaw(deg_to_rad(float(area.get_meta("turn_yaw_deg", 0.0))))

func _build_plant_dressing() -> void:
	# Overhead hook rails along each belt leg - the line feels alive without
	# adding a single new collider.
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = STEEL
	rail_mat.metallic = 0.4
	for rail in [
		{"center": Vector3(20, 4.1, -30), "size": Vector3(26, 0.25, 0.25)},
		{"center": Vector3(30, 4.1, -46), "size": Vector3(0.25, 0.25, 20)},
		{"center": Vector3(40, 4.1, -54), "size": Vector3(10, 0.25, 0.25)},
	]:
		var beam := MeshInstance3D.new()
		beam.name = "HookRail"
		var beam_box := BoxMesh.new()
		beam_box.size = rail["size"]
		beam.mesh = beam_box
		beam.position = rail["center"]
		beam.material_override = rail_mat
		add_child(beam)

	# Hazard checker strips at the crossings.
	for strip_pos in [Vector3(19, 0.02, -30), Vector3(30, 0.02, -47)]:
		for i in 5:
			var checker := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.55, 0.02, 1.2)
			checker.mesh = box
			checker.position = strip_pos + Vector3(0, 0, -0.6 + 0.3 * float(i))
			var mat := StandardMaterial3D.new()
			mat.albedo_color = HAZARD_AMBER if i % 2 == 0 else Color("ECEFF1")
			checker.material_override = mat
			add_child(checker)

	_label("流水线 03 · 运行中", Vector3(5.7, 2.6, -30.0), 18)
	_label("注意：上方挂钩区域", Vector3(34.0, 2.6, -30.0), 18)

	# Realistic factory dressing: wall machinery clusters, hanging warning
	# signs and fluorescent tube fixtures. Pure visuals - zero new colliders.
	for machine in [
		{"pos": Vector3(-5.5, 0, 10.0), "yaw": 90.0},
		{"pos": Vector3(5.5, 0, 6.0), "yaw": -90.0},
		{"pos": Vector3(12.0, 0, -25.4), "yaw": 0.0},
		{"pos": Vector3(33.8, 0, -42.0), "yaw": -90.0},
		{"pos": Vector3(26.2, 0, -46.0), "yaw": 90.0},
		{"pos": Vector3(44.0, 0, -49.4), "yaw": 180.0},
		{"pos": Vector3(51.8, 0, -62.0), "yaw": -90.0},
		{"pos": Vector3(40.2, 0, -74.0), "yaw": 90.0},
	]:
		var machine_dressing := ASSETS.make("ENV_C0_MACHINERY")
		if machine_dressing != null:
			machine_dressing.position = machine["pos"]
			machine_dressing.rotation.y = deg_to_rad(machine["yaw"])
			add_child(machine_dressing)
	for sign_pos in [Vector3(13, 3.4, -30), Vector3(26, 3.4, -30), Vector3(30, 3.4, -46), Vector3(42, 3.4, -54), Vector3(0, 3.4, -17)]:
		var hazard_sign := ASSETS.make("PROP_C0_HAZARD_SIGN")
		if hazard_sign != null:
			hazard_sign.position = sign_pos
			hazard_sign.rotation.y = deg_to_rad(90.0 if sign_pos.z < -20.0 and sign_pos.x > 25.0 else 0.0)
			add_child(hazard_sign)
	for light_def in [
		{"pos": Vector3(0, 3.6, 0), "yaw": 0.0},
		{"pos": Vector3(0, 3.6, -12), "yaw": 0.0},
		{"pos": Vector3(13, 3.6, -30), "yaw": 0.0},
		{"pos": Vector3(26, 3.6, -30), "yaw": 0.0},
		{"pos": Vector3(30, 3.6, -46), "yaw": 90.0},
		{"pos": Vector3(40, 3.6, -54), "yaw": 0.0},
		{"pos": Vector3(46, 3.6, -62), "yaw": 90.0},
		{"pos": Vector3(46, 3.6, -76), "yaw": 90.0},
	]:
		var tube := ASSETS.make("PROP_C0_LIGHT")
		if tube != null:
			tube.position = light_def["pos"]
			tube.rotation.y = deg_to_rad(light_def["yaw"])
			add_child(tube)

# ------------------------------------------------------------------
# L5: 装卸月台 - the dream butcher chase
# ------------------------------------------------------------------
func _build_loading_dock() -> void:
	_label("【装卸月台】尽头就是铁门——跑！！", Vector3(46, 2.8, -52.0), 22)

	for crate in [
		{"pos": Vector3(43.0, 0.8, -63.0), "name": "DockCrateA"},
		{"pos": Vector3(49.0, 0.8, -63.0), "name": "DockCrateB"},
		{"pos": Vector3(43.0, 0.8, -71.0), "name": "DockCrateC"},
		{"pos": Vector3(49.0, 0.8, -71.0), "name": "DockCrateD"},
	]:
		var crate_body := _solid_box(crate["name"], Vector3(2.0, 1.6, 2.0), crate["pos"], CAGE_STEEL)
		ASSETS.replace_visuals(crate_body, "PROP_C0_CRATE", Vector3(0, -0.8, 0))

	_label("【红圈 = 扑击预警！看准时机按 Shift 闪避！】", Vector3(46, 2.4, -59.0), 24)
	var dock_trigger := _area("DockChaseTrigger", "", Vector3(46, 1, -61.0), Vector3(12, 3, 1.5))
	dock_trigger.body_entered.connect(_on_dock_entered)

func _on_dock_entered(body: Node3D) -> void:
	if _dock_chase_triggered:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_dock_chase_triggered = true
	if meme_layer:
		meme_layer.play("butcher_chase")
		meme_layer.play("dodge_learned")

func _build_exit() -> void:
	var door_pos := Vector3(46, 0, -86.0)
	# Steel doorframe: collision boxes keep the 4 m doorway open; the wall
	# panel model dresses each side and the lintel (shutter door scenery sits
	# on the dock's back wall below).
	var door_l := _solid_box("RollerDoorL", Vector3(3.0, 4.2, 0.5), door_pos + Vector3(-3.5, 2.1, 0), STEEL)
	ASSETS.tile_run(door_l, "ENV_C0_WALL", Vector3(3.0, 4.2, 0.5), Vector3(4, 0.4, 4.2), 0.0, -2.1)
	var door_r := _solid_box("RollerDoorR", Vector3(3.0, 4.2, 0.5), door_pos + Vector3(3.5, 2.1, 0), STEEL)
	ASSETS.tile_run(door_r, "ENV_C0_WALL", Vector3(3.0, 4.2, 0.5), Vector3(4, 0.4, 4.2), 0.0, -2.1)
	# RollerDoorTop stays procedural: a 1 m steel lintel above a 4.2 m tall
	# wall model would need a 4x squash that reads wrong at eye level.
	_solid_box("RollerDoorTop", Vector3(10.0, 1.0, 0.5), door_pos + Vector3(0, 3.7, 0), STEEL)

	# Closed shutter scenery on the far dock wall (pure dressing, no collider).
	var shutter := ASSETS.make("PROP_C0_ROLLER_DOOR")
	if shutter != null:
		shutter.position = Vector3(46, 0, -87.7)
		add_child(shutter)

	var light_mesh := MeshInstance3D.new()
	light_mesh.name = "WakingLight"
	var quad := BoxMesh.new()
	quad.size = Vector3(4.0, 3.2, 0.1)
	light_mesh.mesh = quad
	light_mesh.position = door_pos + Vector3(0, 1.7, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WAKE_LIGHT
	mat.emission_enabled = true
	mat.emission = WAKE_LIGHT
	mat.emission_energy_multiplier = 2.2
	light_mesh.material_override = mat
	add_child(light_mesh)

	_label("◆ 铁门 · 醒来 ◆", door_pos + Vector3(0, 4.6, 0), 28)
	_label("（冲进门里的光，梦就结束了）", door_pos + Vector3(0, 3.9, 0), 16)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, 10), Vector3(12, 3, 2))
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -18), Vector3(0, 0.6, -18), 0.0)
	_checkpoint("Checkpoint2", 2, Vector3(19, 1, -30), Vector3(19, 0.6, -30), -90.0) # L2 eastbound
	_checkpoint("Checkpoint3", 3, Vector3(30, 1, -55.5), Vector3(30, 0.6, -55.5), 0.0) # L3 southbound
	_area("CourseExit", "course_exit", Vector3(46, 2, -85.5), Vector3(8, 5, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3, yaw_deg: float) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 2))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	area.set_meta("respawn_yaw", deg_to_rad(yaw_deg))
	_label("◆ 亮灯的角落", pos + Vector3(0, 1.6, 0), 18)

func _label(text: String, pos: Vector3, font_size: int, parent: Node3D = null) -> Label3D:
	var ui := preload("res://scripts/ui/ui_kit.gd")
	var label := ui.world_label(text, font_size, CREAM, DARK)
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
