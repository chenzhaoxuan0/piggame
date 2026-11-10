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

const SPAWN := Vector3(0, 0.6, 12)
const STORYBOOK_GREEN := Color("86A873") # Fairy green
const STORYBOOK_GOLD := Color("FDE68A") # Pastel cream gold
const STORYBOOK_CORAL := Color("E74C3C") # Mushroom red
const STORYBOOK_PURPLE := Color("A855F7") # Magic wisteria
const STORYBOOK_WOOD := Color("6D4C41") # Bark brown
const STORYBOOK_LOAM := Color("4E342E") # Warm soil
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

func _ready() -> void:
	_build_ground()
	_build_surroundings()
	_build_stealth_zone()
	_build_mimic_grove()
	_build_illusory_wall_puzzle()
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
	if gm:
		gm.set("has_struggle_skill", true)
		gm.set("has_discern_skill", true)
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
	cfg.title = "林间隐藏关卡 · 《潜龙谍影/魂系》潜行破幻"
	cfg.desc = "迷雾弥漫林间！套上纸箱躲避巡逻恶犬视锥、开启【洞察之眸】辨别宝箱怪与击碎幻影墙壁！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-35, -16, -115), Vector3(70, 40, 140))
	cfg.dog_count = 1
	cfg.dog_speed_min = 2.4
	cfg.dog_speed_max = 5.2
	cfg.memes = {
		"course_start": {"title": "步入迷雾古林！", "text": "童话森林雾气氤氲，恶犬在小径巡逻！请寻找掩护！", "duration": 3.0},
		"box_equip": {"title": "纸箱潜行模式！", "text": "【！】装备纸箱！静止不动时巡逻恶犬直接无视！按Shift可俯冲保龄撞狗！", "duration": 2.5},
		"pinecone_thrown": {"title": "声东击西！", "text": "金松果啪嗒落地！恶犬循声四处张望，视线被完全引开！", "duration": 2.5},
		"dog_alert": {"title": "【！】警报拉响！", "text": "恶犬察觉到了异动！快原地呆住或逃出视线！", "duration": 2.2},
		"dog_confused": {"title": "恶犬疑惑：？", "text": "……只是个普通的纸箱，好像是我看花眼了。", "duration": 2.2},
		"mimic_bite": {"title": "《魂系》经典宝箱怪！", "text": "嗷呜！小猪屁股被咬了一大口！开启洞察之眸才能看穿呼吸！", "duration": 2.5},
		"sweet_potato": {"title": "真实秘宝：黄金红薯！", "text": "香甜软糯！小猪士气大振，体力拉满！", "duration": 2.5},
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
	_fairytale_platform("EntranceMeadow", Vector3(14, 1, 14), Vector3(0, -0.5, 9), STORYBOOK_GREEN, STORYBOOK_LOAM)

	# 2. Narrow Stealth Path (Z = 2 to -24)
	_fairytale_platform("StealthPath", Vector3(8, 1, 28), Vector3(0, -0.5, -11), STORYBOOK_GREEN, STORYBOOK_LOAM)

	# 3. Mimic Grove Plaza (Z = -26 to -46)
	_fairytale_platform("MimicPlaza", Vector3(14, 1, 20), Vector3(0, -0.5, -36), STORYBOOK_GOLD, STORYBOOK_LOAM)

	# 4. Hidden Fairy Path behind Illusory Wall (Z = -48 to -78)
	_fairytale_platform("HiddenFairyPath", Vector3(10, 1, 30), Vector3(0, -0.5, -63), STORYBOOK_PURPLE, STORYBOOK_LOAM)

	# 5. Hollow Tree Exit Glade (Z = -79 to -94)
	_fairytale_platform("ExitGlade", Vector3(14, 1, 16), Vector3(0, -0.5, -86), STORYBOOK_GREEN, STORYBOOK_LOAM)

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

	# 3. Patrol Guard Dog with Vision Cone patrolling between Z = 0 and Z = -18
	patrol_dog = Node3D.new()
	patrol_dog.name = "PatrolDogGuard"
	patrol_dog.position = Vector3(0, 0.5, -6.0)
	patrol_dog.add_to_group("chase_dogs")
	patrol_dog.set_meta("drive_with_vision_cone", true) # The vision cone patrols the dog, not just itself

	var dog_mesh := MeshInstance3D.new()
	dog_mesh.name = "DogMesh"
	var cap := CylinderMesh.new()
	cap.top_radius = 0.5
	cap.bottom_radius = 0.5
	cap.height = 1.0
	dog_mesh.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("B91C1C")
	dog_mesh.material_override = mat
	patrol_dog.add_child(dog_mesh)

	var dog_lbl := _label("巡逻恶犬", Vector3(0, 1.8, 0), 18, patrol_dog)
	dog_lbl.name = "DogLabel"

	patrol_cone = PATROL_VISION_CONE.new()
	patrol_cone.name = "VisionCone"
	patrol_cone.cone_angle_deg = 65.0
	patrol_cone.cone_range = 9.0
	patrol_cone.patrol_speed = 3.0
	var pts: Array[Vector3] = [
		Vector3(-2.5, 0.5, -4.0),
		Vector3(2.5, 0.5, -4.0),
		Vector3(0.0, 0.5, -14.0)
	]
	patrol_cone.patrol_points = pts
	patrol_dog.add_child(patrol_cone)
	add_child(patrol_dog)

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

func _build_mimic_grove() -> void:
	# Chests in the grove at Z = -36
	# Left: Mimic chest (Dangerous)
	mimic_chest_fake = MIMIC_CHEST.new()
	mimic_chest_fake.name = "MimicChestFake"
	mimic_chest_fake.is_mimic = true
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
	mimic_chest_real.position = Vector3(2.8, 0, -36.0)
	add_child(mimic_chest_real)

	mimic_chest_real.chest_opened.connect(func(_c, is_m):
		if not is_m and meme_layer:
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

func _build_decorations() -> void:
	# Mushroom clusters
	_mushroom_prop(Vector3(-4, 0, 8), 0.8)
	_mushroom_prop(Vector3(4, 0, 8), 0.6)
	_mushroom_prop(Vector3(-5, 0, -28), 1.2)
	_mushroom_prop(Vector3(5, 0, -68), 1.0)

func _storybook_tree(pos: Vector3) -> void:
	_solid_box("TreeTrunk", Vector3(1.2, 5.0, 1.2), pos + Vector3(0, 2.5, 0), STORYBOOK_WOOD)
	_solid_box("TreeFoliage", Vector3(4.0, 4.0, 4.0), pos + Vector3(0, 5.5, 0), STORYBOOK_GREEN)

func _mushroom_prop(pos: Vector3, scale_f: float) -> void:
	var m := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 0.1 * scale_f
	cap.bottom_radius = 0.9 * scale_f
	cap.height = 0.6 * scale_f
	m.mesh = cap
	m.position = pos + Vector3(0, 0.3 * scale_f, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STORYBOOK_CORAL
	m.material_override = mat
	add_child(m)

func _build_exit() -> void:
	var portal_pos := Vector3(0, 0, -88.0)

	# Hollow ancient tree arch
	_solid_box("ArchL", Vector3(1.4, 6.0, 1.4), portal_pos + Vector3(-2.6, 3.0, 0), STORYBOOK_WOOD)
	_solid_box("ArchR", Vector3(1.4, 6.0, 1.4), portal_pos + Vector3(2.6, 3.0, 0), STORYBOOK_WOOD)
	_solid_box("ArchTop", Vector3(6.6, 1.4, 1.4), portal_pos + Vector3(0, 6.6, 0), STORYBOOK_WOOD)

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

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, 10), Vector3(16, 3, 2)) # Full platform width: no side bypass
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -18), Vector3(0, 0.6, -18))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -50), Vector3(0, 0.6, -50))
	_area("CourseExit", "course_exit", Vector3(0, 2, -88), Vector3(8, 5, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 3))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	_label("◆ 童话萤火重生点", pos + Vector3(0, 1.6, 0), 18)

func _fairytale_platform(node_name: String, size: Vector3, pos: Vector3, top_color: Color, side_color: Color) -> StaticBody3D:
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
	top_box.size = Vector3(size.x, 0.25, size.z)
	top_mesh.mesh = top_box
	top_mesh.position = Vector3(0, size.y * 0.5 - 0.125, 0)
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = top_color
	top_mat.roughness = 0.9
	top_mesh.material_override = top_mat
	body.add_child(top_mesh)

	var base_mesh := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(size.x, size.y - 0.25, size.z)
	base_mesh.mesh = base_box
	base_mesh.position = Vector3(0, -0.125, 0)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = side_color
	base_mesh.material_override = base_mat
	body.add_child(base_mesh)

	add_child(body)
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
