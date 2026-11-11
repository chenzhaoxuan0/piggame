extends Node3D

# 序章 · 噩梦屠宰场（course_0）。
# 猪在梦里回到屠宰场：圈栏潜行 → 加工车间机关 → 装卸月台被"农场主"追逐，
# 冲出铁门即惊醒（衔接由 office_level_1 的 intro 分支完成）。
# 这是机制教学关：不借出任何技能——被抓全是滑稽逃脱，教非致死循环本身。
# 画风为玩法线程序化暂定（暗红工业 + 角色恒定大鹅平涂），不加载任何 C1
# 农场风 Lux3D 道具（AGENTS.md §5 分区画风铁律），正式画风待美术线定稿。

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
# Dream palette: cold concrete, rusted steel, hazard amber, ember red.
const FLOOR_CONCRETE := Color("312A28")
const WALL_RUST := Color("241D1B")
const CAGE_STEEL := Color("4A423E")
const STEEL := Color("6B7B8C")
const EMBER := Color("8C2B2B")
const HAZARD_AMBER := Color("FFB300")
const WAKE_LIGHT := Color("FFF3E0")
const CREAM := Color("FFF8E7")
const DARK := Color("120C0B")

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
# Drowsy-fog proximity toasts, edge-triggered with hysteresis (reset once the
# fog has fallen well behind again after a jolt).
var _fog_warn_stage := 0

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
	cfg.title = "噩梦 · 屠宰场之夜"
	cfg.desc = "冰冷的地面、铁锈与消毒水味……贴着笼架躲开看门犬，逆着传送带跑，在被追上之前冲出月台铁门！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-30, -16, -100), Vector3(60, 40, 130))
	cfg.dog_count = 1
	cfg.dog_speed_min = 3.0
	cfg.dog_speed_max = 5.0
	# The dream butcher is the farmer himself (stun prod and all).
	cfg.dog_visual_asset_id = "CHAR_07"
	cfg.memes = {
		"course_start": {"title": "……（入梦）", "text": "冰冷的地面，铁锈味，远处有铁链声。这里是——屠宰场？！", "duration": 4.0},
		"fog_wake": {"title": "困意……", "text": "身后有什么东西漫过来了。别回头，跑。", "duration": 2.0},
		"fog_closer": {"title": "困意更近了！", "text": "眼皮好沉……不行！这是梦里的困意，被追上会在梦里睡着的！", "duration": 2.2},
		"fog_very_close": {"title": "快跑！！", "text": "睫毛只剩一条缝了！！", "duration": 1.8},
		"fog_caught": {"title": "一个激灵！", "text": "你在梦里的梦里差点睡着——猛地惊醒，弹了出去！", "duration": 2.2},
		"door_slam": {"title": "砰！", "text": "你甩上铁门。困意在门外撞了两下，没跟进来。", "duration": 2.5},
		"sleeping_dog": {"title": "Zzz……", "text": "别碰睡着的狗。碰了你就会知道为什么。", "duration": 2.0},
		"belt_ride": {"title": "流水线全速运转！", "text": "整条路都是传送带！逆流冲刺，别被送回起点！", "duration": 2.5},
		"belt_side": {"title": "横移转移带！", "text": "带子往墙边甩！稳住——斜着冲向南边出口！", "duration": 2.5},
		"hook_wham": {"title": "哐！铁钩摆荡！", "text": "挂肉的钩子把你当成了货……看准摆动节奏再过！", "duration": 2.0},
		"steam_pop": {"title": "嘶——！蒸汽喷口！", "text": "白色蒸汽把你顶上天！落地记得继续跑！", "duration": 2.0},
		"prod_zap": {"title": "滋啦！电击棍！", "text": "浑身酥麻原地跳了一段舞……离黄色立柱远点！", "duration": 2.2},
		"fake_sun": {"title": "这扇门上画着太阳……", "text": "你一头撞上去——是墙。画出来的太阳不发光。", "duration": 2.5},
		"fake_sun_again": {"title": "（还是那扇画着太阳的门）", "text": "它还是墙。真正的出口在月台尽头的铁门。", "duration": 2.0},
		"butcher_chase": {"title": "梦里的农场主出现了！", "text": "他手里的电击棍闪着光——别回头，冲向月台铁门！！", "duration": 3.0},
		"dog_bonk": {"title": "滋啦——！", "text": "被电得浑身抽搐……但你还在跑！梦里的疼不算数！", "duration": 2.0},
		"respawn": {"title": "噩梦重演……", "text": "你回到上一个亮着灯的地方。深呼吸，再来。", "duration": 2.2},
	}
	return cfg

func _build_ground() -> void:
	# One contiguous 12 m corridor (x -6..6) from the pens to the dock; the
	# walls run its full length so nothing falls into the void mid-dream. The
	# pens floor extends to z = 20: the runner spawns its dog one stride NORTH
	# of the pig (z ~18), which used to be outside the walls.
	_floor_slab("PensFloor", Vector3(12, 1, 42), Vector3(0, -0.5, -1))     # z 20..-22
	_floor_slab("PlantFloor", Vector3(12, 1, 36), Vector3(0, -0.5, -40))   # z -22..-58
	_floor_slab("DockFloor", Vector3(12, 1, 30), Vector3(0, -0.5, -73))    # z -58..-88
	_wall_z("WallWest", -6.2, -88.0, 20.0)
	_wall_z("WallEast", 6.2, -88.0, 20.0)
	_wall_x("WallNorth", 20.2, -6.0, 6.0)

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

func _wall_z(node_name: String, x: float, z_from: float, z_to: float) -> void:
	_solid_box(node_name, Vector3(0.4, 4.2, absf(z_to - z_from)), Vector3(x, 2.1, (z_from + z_to) * 0.5), WALL_RUST)

func _wall_x(node_name: String, z: float, x_from: float, x_to: float) -> void:
	_solid_box(node_name, Vector3(absf(x_to - x_from), 4.2, 0.4), Vector3((x_from + x_to) * 0.5, 2.1, z), WALL_RUST)

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
# S1: 圈栏区 - drowsy fog chase + cage weave (the old vision-cone stealth
# section taught nothing the woodland doesn't teach better, and the cones
# read as searchlights; the dream's own antagonist is falling asleep again)
# ------------------------------------------------------------------
func _build_holding_pins() -> void:
	_label("【噩梦 · 圈栏】身后有困意在追！绕开笼架、别碰睡着的狗，
冲进尽头的铁门甩掉它！", Vector3(0, 2.8, 8.0), 20)

	# Cage pens widened into alternating weave blocks: each leaves one side
	# open, consecutive pens swap sides, so the natural line is an S-curve.
	for cage in [
		{"pos": Vector3(-2.5, 0.8, 4.0), "name": "CagePenA"},
		{"pos": Vector3(2.5, 0.8, -2.0), "name": "CagePenB"},
		{"pos": Vector3(-2.5, 0.8, -8.0), "name": "CagePenC"},
		{"pos": Vector3(2.5, 0.8, -14.0), "name": "CagePenD"},
	]:
		var pen := _solid_box(cage["name"], Vector3(5.0, 1.6, 2.4), cage["pos"], CAGE_STEEL)
		# Bars on top so it reads as a pen, not a crate.
		for bar_idx in 6:
			var bar := MeshInstance3D.new()
			var bar_box := BoxMesh.new()
			bar_box.size = Vector3(0.08, 0.9, 0.08)
			bar.mesh = bar_box
			bar.position = Vector3(-2.0 + 0.8 * float(bar_idx), 1.2, 0)
			var bar_mat := StandardMaterial3D.new()
			bar_mat.albedo_color = STEEL
			bar.material_override = bar_mat
			pen.add_child(bar)

	# One fat dog asleep across the natural cut-through between pens C and D.
	# No vision cone, no chase: it only bites if you actually step on it.
	sleeping_dog = PATROL_GUARD_DOG.new()
	sleeping_dog.name = "SleepingPenDog"
	sleeping_dog.position = Vector3(2.2, 0, -11.0)
	sleeping_dog.body_color = Color("4E4038")
	sleeping_dog.display_name = "Zzz……"
	add_child(sleeping_dog)
	sleeping_dog.guard_nipped.connect(func(_p):
		if meme_layer:
			meme_layer.play("sleeping_dog")
	)
	var zzz := _label("Zzz……", Vector3(0, 1.9, 0), 24, sleeping_dog)
	zzz.name = "SleepZzz"

	# The drowsy fog: starts behind the spawn (and behind the rubber-band
	# dog, so the butcher steps OUT of it) and creeps south at fog_speed.
	drowsy_fog = DROWSY_FOG.new()
	drowsy_fog.name = "DrowsyFog"
	drowsy_fog.position = Vector3(0, 0, 20.0)
	drowsy_fog.fog_speed = 2.0
	add_child(drowsy_fog)
	drowsy_fog.fog_touched.connect(_on_fog_caught)

	# The slam-door at the end of the pens: crossing it stops the fog for
	# good (dream logic - the door blocks the fog, not the butcher).
	var door_frame := Node3D.new()
	door_frame.name = "PensDoorFrame"
	_solid_box("PensDoorPostL", Vector3(0.5, 4.2, 0.5), Vector3(-5.4, 2.1, -19.5), STEEL)
	_solid_box("PensDoorPostR", Vector3(0.5, 4.2, 0.5), Vector3(5.4, 2.1, -19.5), STEEL)
	_solid_box("PensDoorTop", Vector3(11.3, 0.5, 0.5), Vector3(0, 4.45, -19.5), STEEL)
	add_child(door_frame)
	_label("铁门就在前面！", Vector3(0, 3.2, -17.0), 20)

	var slam := _area("PensDoorTrigger", "", Vector3(0, 1, -19.5), Vector3(12, 4, 1.2))
	slam.body_entered.connect(_on_pens_door_entered)

func _on_fog_caught(player: Node3D) -> void:
	# Non-lethal, non-resetting: a sleeping-jolt lurch FORWARD, and the fog
	# falls back. Repeated catches keep shoving the pig onward, so the fog can
	# never trap anyone.
	if drowsy_fog == null or not is_instance_valid(drowsy_fog):
		return
	if player.has_method("apply_knockback"):
		player.apply_knockback(Vector3(0, 0, -6.0) + Vector3.UP * 3.5, 0.6)
	drowsy_fog.retreat(6.0)
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
# S2: 加工车间 - the conveyor escape. The OLD layout kept side floor open
# between the belt and the hook lane (a free middle bypass around both); now
# the belts ARE the road: three full-width lines to wade against, hooks
# hanging over the belts themselves, steam vents guarding the wall lanes, and
# a lateral transfer belt at the end that flings you at the painted-sun wall.
# ------------------------------------------------------------------
func _build_processing_floor() -> void:
	_label("【流水线车间】脚下的路全是传送带！\n逆流冲刺 · 躲头顶铁钩 · 防蒸汽——终点是横移转移带！", Vector3(0, 3.0, -23.5), 19)

	# Three full-width (11.2 m) northbound lines with rest strips between.
	belt_a = _build_line_belt("BeltA", -30.0, 2.2)   # z -26..-34
	belt_b = _build_line_belt("BeltB", -39.0, 2.6)   # z -35..-43
	belt_c = _build_line_belt("BeltC", -48.0, 3.0)   # z -44..-52
	for belt in [belt_a, belt_b, belt_c]:
		belt.belt_entered.connect(func(_b):
			if meme_layer:
				meme_layer.play("belt_ride")
		)

	# Rest strips get a stun-prod each so they are crossings, not camp sites.
	for prod in [{"pos": Vector3(2.0, 0, -34.5), "name": "StunProdStrip1"}, {"pos": Vector3(-2.0, 0, -43.5), "name": "StunProdStrip2"}]:
		var pillar: Node3D = BUMPER_PILLAR.new()
		pillar.name = prod["name"]
		pillar.position = prod["pos"]
		pillar.bumper_color = HAZARD_AMBER
		pillar.cap_color = Color("FFF59D")
		pillar.star_color = Color("00E5FF")
		add_child(pillar)

	# Meathooks hang OVER the belts (posts flush with the walls - no pockets
	# and nothing for the belt drift to pin the pig against mid-line).
	for hook_cfg in [
		{"pos": Vector3(0, 0, -28.5), "speed": 2.2, "phase": 0.0, "name": "MeatHook1"},
		{"pos": Vector3(0, 0, -37.5), "speed": 2.5, "phase": PI * 0.55, "name": "MeatHook2"},
		{"pos": Vector3(0, 0, -41.0), "speed": 2.7, "phase": PI * 1.1, "name": "MeatHook3"},
		{"pos": Vector3(0, 0, -47.5), "speed": 2.9, "phase": PI * 0.3, "name": "MeatHook4"},
	]:
		var hook: Node3D = PENDULUM_BALL.new()
		hook.name = hook_cfg["name"]
		hook.position = hook_cfg["pos"]
		hook.use_lux_model = false
		hook.ball_color = STEEL
		hook.gantry_color = Color("3A3230")
		hook.gantry_half_width = 6.0 # Posts land flush in the walls
		hook.swing_speed = hook_cfg["speed"]
		hook.phase_offset = hook_cfg["phase"]
		# Dream hooks are gentler than the courtyard's sign: shorter arm and
		# swing (sweep +-3.1 m leaves 2.9 m safe wall lanes) and half-strength
		# knockback, so a hit bounces you beside the hook instead of flinging
		# you across the belt into the next swing.
		hook.arm_length = 3.6
		hook.max_angle_deg = 38.0
		hook.knockback_power = 4.5
		hook.knockback_up = 3.2
		hook.meme_id = "hook_wham"
		add_child(hook)

	# Steam vents ON the lines, alternating wall lanes: riding the edges is
	# slower traffic but not free of consequences.
	for vent in [Vector3(-2.5, 0, -46.5), Vector3(2.5, 0, -50.5)]:
		var steam: Node3D = LAUNCH_PAD.new()
		steam.name = "SteamVent"
		steam.position = vent
		steam.use_lux_model = false # Nightmare zone: no ox-field props here
		steam.pad_color = WAKE_LIGHT
		steam.launch_direction = Vector3(0, 0, 0.45)
		steam.launch_power = 5.0
		steam.launch_up = 6.5
		steam.meme_id = "steam_pop"
		add_child(steam)

	# The lateral transfer belt: runs +X toward the east wall, flinging the
	# pig at the painted-sun door. It stops short of the wall (Area ends at
	# x = 3.6, wall at 6.0) so the drift can never shove the pig through
	# geometry; the east ledge is a trap, not a bypass.
	belt_d = CONVEYOR_BELT.new()
	belt_d.name = "BeltD"
	belt_d.position = Vector3(-1.0, -0.35, -55.0)
	belt_d.belt_size = Vector3(9.2, 0.35, 4.0)   # x -5.6..3.6, z -53..-57
	belt_d.belt_direction = Vector3(1, 0, 0)
	belt_d.belt_speed = 2.6
	add_child(belt_d)
	belt_d.belt_entered.connect(func(_b):
		if meme_layer:
			meme_layer.play("belt_side")
	)

	# The painted-sun door now sits exactly where the transfer belt throws you.
	var door_frame := _solid_box("FakeSunDoorFrame", Vector3(0.4, 3.2, 2.4), Vector3(5.7, 1.6, -55.0), EMBER)
	var sun_label := _label("☀\n（出口？）", Vector3(-0.35, 0.6, 0), 40, door_frame)
	sun_label.rotation.y = -PI * 0.5
	fake_sun_door = DECOY_GOAL.new()
	fake_sun_door.name = "FakeSunDoor"
	fake_sun_door.position = Vector3(4.9, 0, -55.0)
	fake_sun_door.meme_id = "fake_sun"
	fake_sun_door.telegraph_meme_id = "fake_sun_again"
	add_child(fake_sun_door)
	exit_hint_label = _label("【真正的出口】月台尽头的铁门 →", Vector3(0, 3.4, -60.0), 22)
	exit_hint_label.visible = false
	exit_hint_label.name = "RealExitHint"
	fake_sun_door.real_exit_hint_path = fake_sun_door.get_path_to(exit_hint_label)

	_build_plant_dressing()

func _build_line_belt(node_name: String, z_center: float, speed: float) -> Node3D:
	# One full-corridor northbound line, deck flush with the floor (a proud
	# lip would be an unjumpable step) - there is NO side floor to bypass on.
	var belt: Node3D = CONVEYOR_BELT.new()
	belt.name = node_name
	belt.position = Vector3(0, -0.35, z_center)
	belt.belt_size = Vector3(11.2, 0.35, 8.0)
	belt.belt_direction = Vector3(0, 0, 1)
	belt.belt_speed = speed
	add_child(belt)
	return belt

func _build_plant_dressing() -> void:
	# Overhead hook rail: a running beam with empty hooks - the line feels
	# alive without adding a single new collider.
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = STEEL
	rail_mat.metallic = 0.4
	var rail := MeshInstance3D.new()
	rail.name = "HookRail"
	var rail_box := BoxMesh.new()
	rail_box.size = Vector3(0.25, 0.25, 30.0)
	rail.mesh = rail_box
	rail.position = Vector3(0, 4.1, -39.0)
	rail.material_override = rail_mat
	add_child(rail)
	for i in range(10):
		var chain := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		cyl.height = 0.7
		chain.mesh = cyl
		chain.position = Vector3(0, 3.62, -53.0 + 2.6 * float(i))
		chain.material_override = rail_mat
		add_child(chain)
		var hook_glyph := _label("J", Vector3(0, 3.15, -53.0 + 2.6 * float(i)), 26)
		hook_glyph.modulate = Color("9AA7B5")

	# Hazard checker strips on the three rest strips (crossing marks).
	for strip_z in [-34.5, -43.5, -52.5]:
		for i in 8:
			var checker := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.3, 0.02, 0.55)
			checker.mesh = box
			checker.position = Vector3(-4.9 + 1.4 * float(i), 0.015, strip_z + (0.3 if i % 2 == 0 else -0.3))
			var mat := StandardMaterial3D.new()
			mat.albedo_color = HAZARD_AMBER if i % 2 == 0 else Color("ECEFF1")
			checker.material_override = mat
			add_child(checker)

	# Wall machinery: visual-only blocks in the belt-free margin (x 5.7..6.0).
	var machine_mat := StandardMaterial3D.new()
	machine_mat.albedo_color = Color("2E2724")
	for machine in [
		Vector3(-5.82, 0.9, -28.0), Vector3(5.82, 0.9, -33.0), Vector3(-5.82, 0.9, -40.0),
		Vector3(5.82, 0.9, -46.0), Vector3(-5.82, 0.9, -51.0),
	]:
		var block := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.35, 1.8, 2.6)
		block.mesh = box
		block.position = machine
		block.material_override = machine_mat
		add_child(block)
		var stripe := MeshInstance3D.new()
		var stripe_box := BoxMesh.new()
		stripe_box.size = Vector3(0.37, 0.25, 2.62)
		stripe.mesh = stripe_box
		stripe.position = machine + Vector3(0, 0.75, 0)
		var stripe_mat := StandardMaterial3D.new()
		stripe_mat.albedo_color = HAZARD_AMBER
		stripe_mat.emission_enabled = true
		stripe_mat.emission = HAZARD_AMBER
		stripe_mat.emission_energy_multiplier = 0.5
		stripe.material_override = stripe_mat
		add_child(stripe)

	_label("流水线 03 · 运行中", Vector3(-5.7, 2.6, -36.0), 18)
	_label("注意：上方挂钩区域", Vector3(5.7, 2.6, -45.0), 18)

# ------------------------------------------------------------------
# S3: 装卸月台 - the dream butcher chase
# ------------------------------------------------------------------
func _build_loading_dock() -> void:
	_label("【装卸月台】尽头就是铁门——跑！！", Vector3(0, 2.8, -60.5), 22)

	# Crates to weave through while the butcher closes in.
	for crate in [
		{"pos": Vector3(-4.2, 0.8, -64.0), "name": "DockCrateA"},
		{"pos": Vector3(4.2, 0.8, -64.0), "name": "DockCrateB"},
		{"pos": Vector3(-4.2, 0.8, -72.0), "name": "DockCrateC"},
		{"pos": Vector3(4.2, 0.8, -72.0), "name": "DockCrateD"},
	]:
		_solid_box(crate["name"], Vector3(2.0, 1.6, 2.0), crate["pos"], CAGE_STEEL)

	# One-shot alarm the moment the pig steps onto the dock.
	var dock_trigger := _area("DockChaseTrigger", "", Vector3(0, 1, -60.0), Vector3(12, 3, 1.5))
	dock_trigger.body_entered.connect(_on_dock_entered)

func _on_dock_entered(body: Node3D) -> void:
	if _dock_chase_triggered:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_dock_chase_triggered = true
	if meme_layer:
		meme_layer.play("butcher_chase")

func _build_exit() -> void:
	# The roller door at the end of the dock, with cold morning light beyond.
	var door_pos := Vector3(0, 0, -86.0)
	_solid_box("RollerDoorL", Vector3(3.0, 4.2, 0.5), door_pos + Vector3(-3.5, 2.1, 0), STEEL)
	_solid_box("RollerDoorR", Vector3(3.0, 4.2, 0.5), door_pos + Vector3(3.5, 2.1, 0), STEEL)
	_solid_box("RollerDoorTop", Vector3(10.0, 1.0, 0.5), door_pos + Vector3(0, 3.7, 0), STEEL)

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
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -18), Vector3(0, 0.6, -18))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -52.5), Vector3(0, 0.6, -52.5))
	_area("CourseExit", "course_exit", Vector3(0, 2, -85.5), Vector3(8, 5, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(10, 3, 2))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	area.set_meta("respawn_yaw", 0.0)
	_label("◆ 亮灯的角落", pos + Vector3(0, 1.6, 0), 18)

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
