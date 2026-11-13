extends Node3D

const ASSETS = preload("res://scripts/art/asset_library.gd")
const RUNNER_SCRIPT = preload("res://scripts/courses/course_runner.gd")
const MEME_SCRIPT = preload("res://scripts/courses/meme_layer.gd")
const CONFIG_SCRIPT = preload("res://scripts/courses/course_config.gd")

const CARDBOARD_BOX = preload("res://scripts/courses/components/cardboard_box_prop.gd")
const PINECONE_PROP = preload("res://scripts/courses/components/pinecone_prop.gd")
const PATROL_VISION_CONE = preload("res://scripts/courses/components/patrol_vision_cone.gd")
const ILLUSORY_WALL = preload("res://scripts/courses/components/illusory_wall.gd")
const MIMIC_CHEST = preload("res://scripts/courses/components/mimic_chest.gd")
const BOUNCY_MUSHROOM = preload("res://scripts/courses/components/bouncy_mushroom.gd")
const PATROL_GUARD_DOG = preload("res://scripts/courses/components/patrol_guard_dog.gd")
const ZONE_ENVIRONMENT = preload("res://scripts/courses/components/zone_environment.gd")

const SPAWN := Vector3(0, 0.6, 12)
# Real-chest speed buff: course-owned and course-scoped (same rule as the
# creek's potatoes - see course_02_creek.gd). No wall-clock timer on the pig.
const CHEST_SPEED_FACTOR := 1.45
const CHEST_DURATION := 6.0
const STORYBOOK_GREEN := Color("86A873") # Fairy green
const STORYBOOK_GOLD := Color("FDE68A") # Pastel cream gold
const STORYBOOK_CORAL := Color("E74C3C") # Mushroom red
const STORYBOOK_PURPLE := Color("A855F7") # Magic wisteria
const STORYBOOK_WOOD := Color("6D4C41") # Bark brown
const STORYBOOK_LOAM := Color("4E342E") # Warm soil
const STORYBOOK_STONE := Color("8D8073") # Mossy maze stone
const MAZE_WALL_H := 2.4
const CREAM := Color("FFFBEB")
const DARK := Color("292524")

var runner: CourseRunner
var meme_layer: MemeLayer
var _discern_halo: Node3D

var stealth_box: Node3D
var patrol_dog: Node3D
var patrol_cone: Node3D
var mimic_chest_fake: Node3D
var mimic_chest_real: Node3D
var illusory_wall: Node3D
var maze_wall_a: Node3D
var maze_illusory_wall: Node3D
var maze_chest_real: Node3D
var maze_chest_mimic: Node3D
var zigzag_dog: Node3D
var _chest_boost_active: bool = false
var _chest_boost_until_msec: int = 0

func _process(_delta: float) -> void:
	if _chest_boost_active and Time.get_ticks_msec() >= _chest_boost_until_msec:
		_end_chest_boost()

func _exit_tree() -> void:
	# Leaving the woodland settles the chest buff on the spot.
	_end_chest_boost()

func _apply_chest_boost() -> void:
	if not _chest_boost_active:
		_chest_boost_active = true
		var p := runner.player if runner != null else null
		if is_instance_valid(p) and "move_speed" in p:
			p.move_speed = p.move_speed * CHEST_SPEED_FACTOR
	_chest_boost_until_msec = Time.get_ticks_msec() + int(CHEST_DURATION * 1000.0)

func _end_chest_boost() -> void:
	if not _chest_boost_active:
		return
	_chest_boost_active = false
	var p := runner.player if runner != null else null
	if is_instance_valid(p) and "move_speed" in p:
		p.move_speed = p.move_speed / CHEST_SPEED_FACTOR

func _ready() -> void:
	ZONE_ENVIRONMENT.apply(self, "fairy_woodland")
	_build_ground()
	_build_surroundings()
	_build_stealth_zone()
	_build_mimic_grove()
	_build_illusory_wall_puzzle()
	_build_illusion_maze()
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
	player.set_meta("in_stealth_box", false)
	for child in player.find_children("*", "CardboardBoxProp", true, false):
		child.queue_free()
	var gm := _gm()
	if gm and gm.has_method("grant_course_skills"):
		# Course-scoped loans: discern/struggle work inside the woodland, while
		# the farm story's sheep/ox quests stay unfinished until really done.
		gm.grant_course_skills(["struggle", "discern"])
	runner.setup(player, SPAWN)
	_update_discern_visuals()

func _update_discern_visuals() -> void:
	var gm := _gm()
	var has_discern: bool = bool(gm.get("has_discern_skill")) if gm else false
	if is_instance_valid(_discern_halo):
		_discern_halo.visible = has_discern

func _gm() -> Node:
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_3"
	cfg.title = "第三章 · 迷雾林间寻路"
	cfg.desc = "用破妄明眸看穿幻象！套纸箱躲避巡逻恶犬、辨出宝箱怪、击碎幻影墙壁——穿过童话迷雾，马场的灯就在林后！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-35, -16, -115), Vector3(70, 40, 140))
	cfg.dog_count = 1
	cfg.dog_speed_min = 3.0
	cfg.dog_speed_max = 5.8
	cfg.memes = {
		"course_start": {"title": "看穿幻象，奔向马场！", "text": "迷雾森林，恶犬巡逻——纸箱隐匿、洞察辨伪，穿过林子就是马场！", "duration": 3.0},
		"box_equip": {"title": "纸箱潜行模式！", "text": "【！】装备纸箱！静止不动时巡逻恶犬直接无视！按Shift可俯冲保龄撞狗！", "duration": 2.5},
		"pinecone_thrown": {"title": "声东击西！", "text": "金松果啪嗒落地！恶犬循声四处张望，视线被完全引开！", "duration": 2.5},
		"dog_alert": {"title": "【！】警报拉响！", "text": "恶犬察觉到了异动！快原地呆住或逃出视线！", "duration": 2.2},
		"dog_confused": {"title": "恶犬疑惑：？", "text": "……只是个普通的纸箱，好像是我看花眼了。", "duration": 2.2},
		"mimic_bite": {"title": "《魂系》经典宝箱怪！", "text": "嗷呜！小猪屁股被咬了一大口！开启洞察之眸才能看穿呼吸！", "duration": 2.5},
		"sweet_potato": {"title": "真实秘宝：黄金红薯！", "text": "香甜软糯！小猪士气大振，体力拉满！", "duration": 2.5},
		"guard_nip": {"title": "被巡逻恶犬咬了屁股！", "text": "嗷！守卫恶犬一口闷！躲进树后或纸箱里再走！", "duration": 2.2},
		"guard_bowled": {"title": "🎳 纸箱保龄全中！", "text": "巡逻恶犬被撞得眼冒金星，原地转圈晕了好几秒！", "duration": 2.5},
		"illusory_shatter": {"title": "前有隐藏道路！", "text": "【洞察之眸】看破假象，看似死胡同的幻影石壁碎裂一地！", "duration": 2.5},
		"mushroom_bounce": {"title": "童话弹力蘑菇！", "text": "波点蘑菇超级大弹射！飞跃树林树冠！", "duration": 2.2},
		"dog_bonk": {"title": "恶犬扑空", "text": "恶犬一头撞在树干上！", "duration": 2.0},
		"qte_success": {"title": "老牛力量震退！", "text": "奋力甩开恶犬！小猪再次脱险！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "被甩飞了……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "重生点复活", "text": "小猪抖抖身上的落叶，整装出发！", "duration": 2.2},
	}
	return cfg

func _build_ground() -> void:
	# 1. Entrance Meadow
	_fairytale_platform("EntranceMeadow", Vector3(14, 1, 14), Vector3(0, -0.5, 9), STORYBOOK_GREEN, STORYBOOK_LOAM, "ENV_C3_MEADOW_TILE")

	# 2. Narrow Stealth Path (Z = 2 to -26, flush with the meadow and the grove:
	# the old -25/-26 seam left a 1 m pit on the main walking line - the pig fell
	# in, respawned, and fell in again, forever)
	_fairytale_platform("StealthPath", Vector3(8, 1, 28), Vector3(0, -0.5, -12), STORYBOOK_GREEN, STORYBOOK_LOAM, "ENV_C3_MEADOW_TILE")

	# 3. Mimic Grove Plaza (Z = -26 to -46)
	_fairytale_platform("MimicPlaza", Vector3(14, 1, 20), Vector3(0, -0.5, -36), STORYBOOK_GOLD, STORYBOOK_LOAM, "ENV_C3_GOLD_TILE")

	# 4. Illusion maze strip behind the entry wall (Z = -46 to -78; used to start
	# at -48, leaving a 2 m pit between the grove and the fairy path)
	_fairytale_platform("HiddenFairyPath", Vector3(10, 1, 32), Vector3(0, -0.5, -62), STORYBOOK_PURPLE, STORYBOOK_LOAM, "ENV_C3_PURPLE_TILE")

	# 5. Hollow Tree Exit Glade (Z = -79 to -94)
	_fairytale_platform("ExitGlade", Vector3(14, 1, 16), Vector3(0, -0.5, -86), STORYBOOK_GREEN, STORYBOOK_LOAM, "ENV_C3_MEADOW_TILE")

func _build_surroundings() -> void:
	# Dense fairytale tree line
	for z in [-10, -20, -35, -55, -70]:
		_storybook_tree(Vector3(-7, 0, z))
		_storybook_tree(Vector3(7, 0, z))

func _build_stealth_zone() -> void:
	# 1. Cardboard Box placed at the trail entrance (Left)
	stealth_box = CARDBOARD_BOX.new()
	stealth_box.name = "StealthCardboardBox"
	stealth_box.position = Vector3(-1.8, 0, 5.0)
	add_child(stealth_box)

	stealth_box.box_equipped.connect(func(_p):
		if meme_layer:
			meme_layer.play("box_equip")
	)

	# 2. Golden Pinecone placed at trail entrance (Right)
	var pinecone = PINECONE_PROP.new()
	pinecone.name = "GoldenPinecone"
	pinecone.position = Vector3(1.8, 0, 5.0)
	add_child(pinecone)

	pinecone.pinecone_thrown.connect(func(_pos):
		if meme_layer:
			meme_layer.play("pinecone_thrown")
	)

	_label("【林间潜行双路线】\n左：[E] 穿上纸箱隐匿与 [Shift] 俯冲保龄撞狗！\n右：[F] 拾取金松果投掷，声东击西引开恶犬视线！", Vector3(0, 2.5, 5.0), 22)

	# 3. Patrol Guard Dog with Vision Cone patrolling between Z = 0 and Z = -18.
	# A real solid body (blocks the path, nips trespassers, can be bowled over by
	# the cardboard box dive) instead of the old label-and-cylinder dummy.
	var zone_pts: Array[Vector3] = [
		Vector3(-2.5, 0, -4.0),
		Vector3(2.5, 0, -4.0),
		Vector3(0.0, 0, -14.0),
	]
	patrol_dog = _make_patrol_guard("PatrolDogGuard", Vector3(0, 0, -6.0), zone_pts)
	patrol_cone = patrol_dog.get_node("VisionCone")

	patrol_cone.player_detected.connect(func(p):
		# Stealth now has teeth: being spotted enlists the rubber-band dog.
		if runner != null:
			runner.alert_dogs(4.0)
		if meme_layer:
			meme_layer.play("dog_alert")
	)
	patrol_cone.player_lost.connect(func():
		if meme_layer:
			meme_layer.play("dog_confused")
	)

func _make_patrol_guard(node_name: String, pos: Vector3, patrol_points: Array[Vector3]) -> Node3D:
	var guard: Node3D = PATROL_GUARD_DOG.new()
	guard.name = node_name
	guard.position = pos
	guard.set_meta("drive_with_vision_cone", true) # The vision cone patrols the dog, not just itself
	add_child(guard)

	var cone = PATROL_VISION_CONE.new()
	cone.name = "VisionCone"
	cone.cone_angle_deg = 70.0
	cone.cone_range = 10.5
	cone.patrol_speed = 3.4
	cone.patrol_points = patrol_points
	guard.add_child(cone)

	guard.guard_nipped.connect(func(_p):
		if meme_layer:
			meme_layer.play("guard_nip")
	)
	guard.guard_stunned.connect(func(_d):
		if meme_layer:
			meme_layer.play("guard_bowled")
	)
	return guard

func _build_mimic_grove() -> void:
	# Chests in the grove at Z = -36
	# Left: Mimic chest (Dangerous)
	mimic_chest_fake = MIMIC_CHEST.new()
	mimic_chest_fake.name = "MimicChestFake"
	mimic_chest_fake.is_mimic = true
	mimic_chest_fake.lux_asset_id = "PROP_C3_CHEST"
	mimic_chest_fake.position = Vector3(-2.8, 0, -36.0)
	add_child(mimic_chest_fake)

	mimic_chest_fake.chest_opened.connect(func(_c, is_m):
		if is_m and meme_layer:
			meme_layer.play("mimic_bite")
	)

	# Right: Real treasure chest (Sweet Potato)
	mimic_chest_real = MIMIC_CHEST.new()
	mimic_chest_real.name = "MimicChestReal"
	mimic_chest_real.is_mimic = false
	mimic_chest_real.lux_asset_id = "PROP_C3_CHEST"
	mimic_chest_real.position = Vector3(2.8, 0, -36.0)
	add_child(mimic_chest_real)

	mimic_chest_real.chest_opened.connect(func(_c, is_m):
		if not is_m:
			_apply_chest_boost()
			if meme_layer:
				meme_layer.play("sweet_potato")
	)

	_label("【童话秘宝岔路】开启【洞察之眸】可分辨呼吸的宝箱怪！", Vector3(0, 2.8, -32.0), 22)

	# Optional shortcut bouncy mushroom beside the plaza
	var mushroom = BOUNCY_MUSHROOM.new()
	mushroom.name = "FairytaleMushroom"
	mushroom.position = Vector3(5.0, 0, -36.0)
	mushroom.bounce_up = 12.0
	add_child(mushroom)
	mushroom.triggered.connect(func(_trap, _p):
		if meme_layer:
			meme_layer.play("mushroom_bounce")
	)

func _build_illusory_wall_puzzle() -> void:
	# Illusory Wall blocking the path at Z = -47.5
	illusory_wall = ILLUSORY_WALL.new()
	illusory_wall.name = "IllusoryWall"
	illusory_wall.wall_width = 10.0
	illusory_wall.wall_height = 4.5
	illusory_wall.lux_asset_id = "PROP_C3_ILLUSORY_WALL"
	illusory_wall.position = Vector3(0, 0, -47.5)
	add_child(illusory_wall)

	illusory_wall.wall_shattered.connect(func(_w):
		if meme_layer:
			meme_layer.play("illusory_shatter")
	)

	# Discern halo guide
	_discern_halo = Node3D.new()
	_discern_halo.name = "DiscernHaloGuide"
	var halo_ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.6
	tor.outer_radius = 2.0
	halo_ring.mesh = tor
	halo_ring.position = Vector3(0, 1.2, -47.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("C084FC")
	mat.emission_enabled = true
	mat.emission = Color("A855F7")
	mat.emission_energy_multiplier = 2.0
	halo_ring.material_override = mat
	_discern_halo.add_child(halo_ring)
	add_child(_discern_halo)

func _build_illusion_maze() -> void:
	# The back 40% of the course used to be an empty corridor; the design doc's
	# 破幻迷宫 lives here now. Zigzag stone rows (A/B/D/E/F) with one row made of
	# an illusory wall (C) hiding the true passage, a bonus chest chamber sealed
	# behind C's left span, and a golden-lit dead end baited with a mimic.
	# All rows leave a 3-4 m gap; the fixed -Z camera keeps every gap readable.
	var y := MAZE_WALL_H * 0.5

	# Row A (z=-52): solid left, gap on the right
	maze_wall_a = _maze_wall("MazeWallA", Vector3(6.0, MAZE_WALL_H, 0.8), Vector3(-2.0, y, -52.0))
	# Row B (z=-56): solid right, gap on the left
	_maze_wall("MazeWallB", Vector3(4.0, MAZE_WALL_H, 0.8), Vector3(3.0, y, -56.0))
	# Row C (z=-61): the illusory row. Its left span is walk-through (shatters on
	# touch with insight), and behind it hides the real treasure chamber.
	_maze_wall("MazeWallCSolid", Vector3(3.5, MAZE_WALL_H, 0.8), Vector3(3.25, y, -61.0))
	maze_illusory_wall = ILLUSORY_WALL.new()
	maze_illusory_wall.name = "MazeIllusoryWallC"
	maze_illusory_wall.wall_width = 6.5
	maze_illusory_wall.wall_height = 2.6
	maze_illusory_wall.lux_asset_id = "PROP_C3_ILLUSORY_WALL"
	maze_illusory_wall.position = Vector3(-1.75, 0, -61.0)
	add_child(maze_illusory_wall)
	maze_illusory_wall.wall_shattered.connect(func(_w):
		if meme_layer:
			meme_layer.play("illusory_shatter")
	)
	# Row D (z=-65): seals the chamber on the left, gap on the right
	_maze_wall("MazeWallD", Vector3(4.5, MAZE_WALL_H, 0.8), Vector3(-2.75, y, -65.0))
	# Row E (z=-70): solid left, narrow gap on the right
	_maze_wall("MazeWallE", Vector3(7.0, MAZE_WALL_H, 0.8), Vector3(-1.5, y, -70.0))
	# Row F (z=-74): solid right (the mimic pocket's back), gap on the left
	_maze_wall("MazeWallF", Vector3(3.0, MAZE_WALL_H, 0.8), Vector3(3.5, y, -74.0))

	# Bonus chamber (x -5..-0.5, z -65..-61, entered only through the fake wall):
	# the real golden chest whose sweet-potato boost helps shake the dog.
	maze_chest_real = MIMIC_CHEST.new()
	maze_chest_real.name = "MazeChestReal"
	maze_chest_real.is_mimic = false
	maze_chest_real.lux_asset_id = "PROP_C3_CHEST"
	maze_chest_real.position = Vector3(-2.8, 0, -63.0)
	add_child(maze_chest_real)
	maze_chest_real.chest_opened.connect(func(_c, is_m):
		if not is_m:
			_apply_chest_boost()
			if meme_layer:
				meme_layer.play("sweet_potato")
	)
	_label("…石壁之后，红薯微香…", Vector3(-2.8, 3.2, -63.0), 16)

	# Golden dead end (x 2..5, z -74..-70): warm light, tempting, and it bites.
	maze_chest_mimic = MIMIC_CHEST.new()
	maze_chest_mimic.name = "MazeChestMimic"
	maze_chest_mimic.is_mimic = true
	maze_chest_mimic.lux_asset_id = "PROP_C3_CHEST"
	maze_chest_mimic.position = Vector3(3.5, 0, -72.0)
	add_child(maze_chest_mimic)
	maze_chest_mimic.chest_opened.connect(func(_c, is_m):
		if is_m and meme_layer:
			meme_layer.play("mimic_bite")
	)
	var gold_glow := MeshInstance3D.new()
	gold_glow.name = "GoldenLure"
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(2.4, 0.08, 2.4)
	gold_glow.mesh = glow_box
	gold_glow.position = Vector3(3.5, 0.04, -72.0)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = STORYBOOK_GOLD
	glow_mat.emission_enabled = true
	glow_mat.emission = STORYBOOK_GOLD
	glow_mat.emission_energy_multiplier = 0.9
	gold_glow.material_override = glow_mat
	add_child(gold_glow)
	_label("…金光耀眼处，似有呼吸…", Vector3(3.5, 3.2, -70.6), 16)

	_label("【破幻迷宫】石墙为实，幻墙可破：\n假墙微光脉动 = 洞察之眸的提示！", Vector3(0, 3.4, -49.5), 20)

	# A second patrolling guard in the zigzag rows: stealth matters to the end.
	# Patrol legs are straight lines, so the route is L-shaped on purpose: every
	# leg is verified to clear each stone row's z-band inside its gap (a diagonal
	# would clip a row's corner - the wall boxes span z ±0.4 around each row).
	var zigzag_pts: Array[Vector3] = [
		Vector3(3.0, 0, -50.0),  # corridor 1
		Vector3(3.0, 0, -53.5),  # south through A's right gap (x = 3)
		Vector3(-1.0, 0, -53.5), # west along corridor 2, clear of both rows
		Vector3(-1.0, 0, -59.0), # south through B's left gap (x = -1)
	]
	zigzag_dog = _make_patrol_guard("ZigzagDogGuard", Vector3(3.0, 0, -53.5), zigzag_pts)
	var zigzag_cone = zigzag_dog.get_node("VisionCone")
	zigzag_cone.cone_range = 7.0
	zigzag_cone.patrol_speed = 2.7
	zigzag_cone.player_detected.connect(func(_p):
		if runner != null:
			runner.alert_dogs(4.0)
		if meme_layer:
			meme_layer.play("dog_alert")
	)

	# Fireflies: soft motes marking the safe line through the maze.
	for wisp_pos in [Vector3(3, 1.1, -50), Vector3(-2, 1.1, -58), Vector3(1, 1.1, -66), Vector3(-2, 1.1, -76)]:
		_firefly(wisp_pos)

func _build_decorations() -> void:
	# Mushroom clusters + storybook bushes along the path (visual-only dressing)
	_mushroom_prop(Vector3(-4, 0, 8), 0.8)
	_mushroom_prop(Vector3(4, 0, 8), 0.6)
	_mushroom_prop(Vector3(-5, 0, -28), 1.2)
	_mushroom_prop(Vector3(5, 0, -68), 1.0)
	for bush_pos in [Vector3(-6.2, 0, 2), Vector3(6.2, 0, -4), Vector3(-6.2, 0, -18), Vector3(6.2, 0, -24),
		Vector3(-6.2, 0, -30), Vector3(6.2, 0, -44), Vector3(-6.2, 0, -80), Vector3(6.2, 0, -84)]:
		var bush := ASSETS.make("ENV_C3_BUSH")
		if bush != null:
			bush.position = bush_pos
			bush.rotation.y = randf() * TAU
			add_child(bush)

func _storybook_tree(pos: Vector3) -> void:
	var trunk := _solid_box("TreeTrunk", Vector3(1.2, 5.0, 1.2), pos + Vector3(0, 2.5, 0), STORYBOOK_WOOD)
	var foliage := _solid_box("TreeFoliage", Vector3(4.0, 4.0, 4.0), pos + Vector3(0, 5.5, 0), STORYBOOK_GREEN)
	# Whole whimsical storybook tree dressed on the trunk body; both procedural
	# boxes hide, collisions stay.
	ASSETS.replace_visuals(trunk, "ENV_C3_TREE", Vector3(0, -2.5, 0))
	ASSETS.hide_procedural_visuals(foliage)

func _mushroom_prop(pos: Vector3, scale_f: float) -> void:
	# Spotted toadstool dressing, scaled per cluster.
	var m := ASSETS.make("PROP_C3_TOADSTOOL")
	if m == null: return
	m.position = pos
	m.scale = Vector3.ONE * scale_f
	m.rotation.y = randf() * TAU
	add_child(m)

func _maze_wall(node_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	# Mossy stone maze wall with the model run along its length; the body
	# origin sits at mid-height so the segment base sinks to local -1.2. The
	# procedural box hides: it sits at the exact same footprint and would
	# z-fight with the model segments otherwise.
	var body := _solid_box(node_name, size, pos, STORYBOOK_STONE)
	ASSETS.tile_run(body, "PROP_C3_MAZE_WALL", size, Vector3(6, 0.8, 2.4), 0.0, -MAZE_WALL_H * 0.5)
	return body

func _build_exit() -> void:
	var portal_pos := Vector3(0, 0, -88.0)

	# Hollow ancient tree arch (collision stays; the giant hollow-trunk model
	# replaces the three procedural boxes and wraps the glowing doorway)
	var arch_l := _solid_box("ArchL", Vector3(1.4, 6.0, 1.4), portal_pos + Vector3(-2.6, 3.0, 0), STORYBOOK_WOOD)
	var arch_r := _solid_box("ArchR", Vector3(1.4, 6.0, 1.4), portal_pos + Vector3(2.6, 3.0, 0), STORYBOOK_WOOD)
	var arch_top := _solid_box("ArchTop", Vector3(6.6, 1.4, 1.4), portal_pos + Vector3(0, 6.6, 0), STORYBOOK_WOOD)
	for arch in [arch_l, arch_r, arch_top]:
		ASSETS.hide_procedural_visuals(arch)
	var hollow_tree := ASSETS.make("PROP_C3_HOLLOW_TREE")
	if hollow_tree != null:
		hollow_tree.position = portal_pos
		add_child(hollow_tree)

	# Green fairy portal interior
	var portal_mesh := MeshInstance3D.new()
	portal_mesh.name = "FairyPortalMesh"
	var quad := BoxMesh.new()
	quad.size = Vector3(3.8, 5.2, 0.3)
	portal_mesh.mesh = quad
	portal_mesh.position = portal_pos + Vector3(0, 3.2, 0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("22C55EAA")
	mat.emission_enabled = true
	mat.emission = Color("4ADE80")
	portal_mesh.material_override = mat
	add_child(portal_mesh)

	_label("◆ 空心神木 · 胜利出口 ◆", portal_pos + Vector3(0, 7.6, 0), 28)
	_label("（穿过树洞光幕，前往野马牧场！）", portal_pos + Vector3(0, 6.6, 0), 18)

func _firefly(pos: Vector3) -> void:
	var wisp := MeshInstance3D.new()
	wisp.name = "Firefly"
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	wisp.mesh = sphere
	wisp.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STORYBOOK_GOLD
	mat.emission_enabled = true
	mat.emission = STORYBOOK_GOLD
	mat.emission_energy_multiplier = 1.6
	wisp.material_override = mat
	add_child(wisp)
	var tween := wisp.create_tween()
	tween.set_loops()
	tween.tween_property(wisp, "position:y", pos.y + 0.35, 1.1 + randf() * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(wisp, "position:y", pos.y, 1.1 + randf() * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, 10), Vector3(16, 3, 2)) # Full platform width: no side bypass
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -18), Vector3(0, 0.6, -18))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -50), Vector3(0, 0.6, -50))
	_checkpoint("Checkpoint3", 3, Vector3(0, 1, -72.5), Vector3(0, 0.6, -72.4))
	_area("CourseExit", "course_exit", Vector3(0, 2, -88), Vector3(8, 5, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 3))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	area.set_meta("respawn_yaw", 0.0) # The maze runs -Z: respawn facing into it
	_label("◆ 童话萤火重生点", pos + Vector3(0, 1.6, 0), 18)

func _fairytale_platform(node_name: String, size: Vector3, pos: Vector3, top_color: Color, side_color: Color, dress_id := "") -> StaticBody3D:
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

	var top_mesh := MeshInstance3D.new()
	var top_box := BoxMesh.new()
	# Turf top 0.06 under the tile tops, footprint 0.06 inside them; dirt base
	# insets further (same anti-coplanar contract as course_02's platforms).
	top_box.size = Vector3(size.x - 0.12, 0.25, size.z - 0.12)
	top_mesh.mesh = top_box
	top_mesh.position = Vector3(0, size.y * 0.5 - 0.185, 0)
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = top_color
	top_mat.roughness = 0.9
	top_mesh.material_override = top_mat
	body.add_child(top_mesh)

	var base_mesh := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(size.x - 0.24, size.y - 0.25, size.z - 0.24)
	base_mesh.mesh = base_box
	base_mesh.position = Vector3(0, -0.125, 0)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = side_color
	base_mesh.material_override = base_mat
	body.add_child(base_mesh)

	add_child(body)
	# Hand-painted meadow tile dressing over the slab (collision unchanged).
	if not dress_id.is_empty():
		ASSETS.tile_slab_top(body, dress_id, size, Vector3(4, 1, 4), size.y * 0.5)
	return body

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
