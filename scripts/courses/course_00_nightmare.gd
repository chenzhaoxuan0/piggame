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
const PATROL_VISION_CONE = preload("res://scripts/courses/components/patrol_vision_cone.gd")
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

var guard_dog_1: Node3D
var guard_dog_2: Node3D
var main_belt: Node3D
var fake_sun_door: Node3D
var exit_hint_label: Label3D
var _dock_chase_triggered := false

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
		"pen_alert": {"title": "【！】看门犬看见你了！", "text": "汪！汪汪！快躲到笼架后面，等它转过头！", "duration": 2.2},
		"pen_nip": {"title": "被一口咬住耳朵！", "text": "嗷！看门犬把你拖回圈栏……下次贴着笼架走！", "duration": 2.2},
		"belt_ride": {"title": "传送带在往回送你！", "text": "带子把你送回来时的路！逆着跑，或者从右侧通道绕！", "duration": 2.5},
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
# S1: 圈栏区 - stealth tutorial (vision cones, cage cover)
# ------------------------------------------------------------------
func _build_holding_pins() -> void:
	_label("【噩梦 · 圈栏】贴着笼架走，别让看门犬看见你。\n（静止不动时，犬也会看走眼）", Vector3(0, 2.8, 8.0), 20)

	# Cage pens hugging the walls: real cover for the vision-cone raycasts.
	for cage in [
		{"pos": Vector3(-4.6, 0.8, 4.0), "name": "CagePenA"},
		{"pos": Vector3(4.6, 0.8, -2.0), "name": "CagePenB"},
		{"pos": Vector3(-4.6, 0.8, -8.0), "name": "CagePenC"},
		{"pos": Vector3(4.6, 0.8, -14.0), "name": "CagePenD"},
	]:
		var pen := _solid_box(cage["name"], Vector3(2.4, 1.6, 2.4), cage["pos"], CAGE_STEEL)
		# Bars on top so it reads as a pen, not a crate.
		for bar_idx in 4:
			var bar := MeshInstance3D.new()
			var bar_box := BoxMesh.new()
			bar_box.size = Vector3(0.08, 0.9, 0.08)
			bar.mesh = bar_box
			bar.position = Vector3(-0.9 + 0.6 * float(bar_idx), 1.2, 0)
			var bar_mat := StandardMaterial3D.new()
			bar_mat.albedo_color = STEEL
			bar.material_override = bar_mat
			pen.add_child(bar)

	guard_dog_1 = _make_pen_guard("PenGuardDog1", Vector3(2.6, 0, -2.0), [
		Vector3(2.6, 0, 2.0),
		Vector3(2.6, 0, -8.0),
		Vector3(-2.6, 0, -8.0),
		Vector3(-2.6, 0, 2.0),
	])
	guard_dog_2 = _make_pen_guard("PenGuardDog2", Vector3(2.6, 0, -14.0), [
		Vector3(2.6, 0, -12.0),
		Vector3(-2.6, 0, -12.0),
		Vector3(-2.6, 0, -18.0),
		Vector3(2.6, 0, -18.0),
	])

func _make_pen_guard(node_name: String, pos: Vector3, patrol_points: Array[Vector3]) -> Node3D:
	var guard: Node3D = PATROL_GUARD_DOG.new()
	guard.name = node_name
	guard.position = pos
	guard.body_color = Color("3E2F2C")
	guard.display_name = "看门犬"
	guard.set_meta("drive_with_vision_cone", true)
	add_child(guard)

	var cone = PATROL_VISION_CONE.new()
	cone.name = "VisionCone"
	cone.cone_angle_deg = 62.0
	cone.cone_range = 7.0
	cone.patrol_speed = 2.4
	cone.patrol_points = patrol_points
	guard.add_child(cone)

	cone.player_detected.connect(func(_p):
		if runner != null:
			runner.alert_dogs(4.0)
		if meme_layer:
			meme_layer.play("pen_alert")
	)
	guard.guard_nipped.connect(func(_p):
		if meme_layer:
			meme_layer.play("pen_nip")
	)
	return guard

# ------------------------------------------------------------------
# S2: 加工车间 - hazard gauntlet (conveyor wade vs hook lane)
# ------------------------------------------------------------------
func _build_processing_floor() -> void:
	_label("【加工车间】左：逆流传送带（慢而稳）。右：铁钩通道（快而痛）。\n小心蒸汽喷口与黄色电击棍立柱！", Vector3(0, 3.0, -24.5), 18)

	# The belt carries you BACK the way you came (+Z): wading costs belt speed.
	# Sunk 0.35 m so its deck top sits flush with the floor - a proud lip would
	# be an unjumpable step for walking pigs.
	main_belt = CONVEYOR_BELT.new()
	main_belt.name = "MainBelt"
	main_belt.position = Vector3(-2.6, -0.35, -42.0)
	main_belt.belt_size = Vector3(4.2, 0.35, 24.0)
	main_belt.belt_direction = Vector3(0, 0, 1)
	main_belt.belt_speed = 2.2
	add_child(main_belt)
	main_belt.belt_entered.connect(func(_b):
		if meme_layer:
			meme_layer.play("belt_ride")
	)

	# Steam vents ON the belt: riding it is slow AND occasionally airborne.
	for vent_pos in [Vector3(-2.6, 0, -36.0), Vector3(-2.6, 0, -48.0)]:
		var vent: Node3D = LAUNCH_PAD.new()
		vent.name = "SteamVent"
		vent.position = vent_pos
		vent.use_lux_model = false # Nightmare zone: no ox-field props here
		vent.pad_color = WAKE_LIGHT
		vent.launch_direction = Vector3(0, 0, 0.45)
		vent.launch_power = 5.0
		vent.launch_up = 6.5
		vent.meme_id = "steam_pop"
		add_child(vent)

	# Hook lane on the right: three swinging meathooks across the walkway.
	for hook_cfg in [
		{"pos": Vector3(3.0, 0, -34.0), "speed": 2.2, "phase": 0.0, "name": "MeatHook1"},
		{"pos": Vector3(3.0, 0, -41.0), "speed": 2.5, "phase": PI * 0.5, "name": "MeatHook2"},
		{"pos": Vector3(3.0, 0, -48.0), "speed": 2.8, "phase": PI, "name": "MeatHook3"},
	]:
		var hook: Node3D = PENDULUM_BALL.new()
		hook.name = hook_cfg["name"]
		hook.position = hook_cfg["pos"]
		hook.use_lux_model = false
		hook.ball_color = STEEL
		hook.gantry_color = Color("3A3230")
		hook.gantry_half_width = 1.2 # Posts stay clear of the walls: no pockets
		hook.swing_speed = hook_cfg["speed"]
		hook.phase_offset = hook_cfg["phase"]
		hook.meme_id = "hook_wham"
		add_child(hook)

	# Stun-prod pillars along the right edge.
	for prod_pos in [Vector3(5.0, 0, -38.0), Vector3(5.0, 0, -52.0)]:
		var prod: Node3D = BUMPER_PILLAR.new()
		prod.name = "StunProdPillar"
		prod.position = prod_pos
		prod.bumper_color = HAZARD_AMBER
		prod.cap_color = Color("FFF59D")
		prod.star_color = Color("00E5FF")
		add_child(prod)

	# The painted-on sun door: a dream bait. First bounce reveals the real exit.
	var door_frame := _solid_box("FakeSunDoorFrame", Vector3(0.4, 3.2, 2.4), Vector3(5.7, 1.6, -45.0), EMBER)
	var sun_label := _label("☀\n（出口？）", Vector3(-0.35, 0.6, 0), 40, door_frame)
	sun_label.rotation.y = -PI * 0.5
	fake_sun_door = DECOY_GOAL.new()
	fake_sun_door.name = "FakeSunDoor"
	fake_sun_door.position = Vector3(4.9, 0, -45.0)
	fake_sun_door.meme_id = "fake_sun"
	fake_sun_door.telegraph_meme_id = "fake_sun_again"
	add_child(fake_sun_door)
	exit_hint_label = _label("【真正的出口】月台尽头的铁门 →", Vector3(0, 3.4, -60.0), 22)
	exit_hint_label.visible = false
	exit_hint_label.name = "RealExitHint"
	fake_sun_door.real_exit_hint_path = fake_sun_door.get_path_to(exit_hint_label)

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
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -56), Vector3(0, 0.6, -56))
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
