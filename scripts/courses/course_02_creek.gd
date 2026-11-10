extends Node3D

const ASSETS = preload("res://scripts/art/asset_library.gd")
const RUNNER_SCRIPT = preload("res://scripts/courses/course_runner.gd")
const MEME_SCRIPT = preload("res://scripts/courses/meme_layer.gd")
const CONFIG_SCRIPT = preload("res://scripts/courses/course_config.gd")

const VOXEL_PUSH_BLOCK = preload("res://scripts/courses/components/voxel_push_block.gd")
const VOXEL_WATER_STREAM = preload("res://scripts/courses/components/voxel_water_stream.gd")
const VOXEL_PRESSURE_PLATE = preload("res://scripts/courses/components/voxel_pressure_plate.gd")
const VOXEL_OBSIDIAN_WALL = preload("res://scripts/courses/components/voxel_obsidian_wall.gd")

const SPAWN := Vector3(0, 0.6, 12)
const VOXEL_BLUE := Color("38BDF8") # Water cyan
const VOXEL_GREEN := Color("4ADE80") # Pixel grass
const VOXEL_DIRT := Color("5A3E28") # Pixel dirt
const VOXEL_STONE := Color("78909C") # Cobblestone
const VOXEL_SAND := Color("FBBF24") # Gravity sand
const VOXEL_PURPLE := Color("8B5CF6") # Nether portal
const CREAM := Color("FFF8E7")
const DARK := Color("1E293B")

var runner: CourseRunner
var meme_layer: MemeLayer

var water_stream: Node3D
var dirt_block_1: Node3D
var dirt_block_2: Node3D
var sand_block: Node3D
var tnt_block: Node3D
var pressure_plate: Node3D
var obsidian_wall: Node3D
var canyon_dog: Node3D

func _ready() -> void:
	_build_ground_and_structures()
	_build_creek_puzzle()
	_build_sand_canyon_puzzle()
	_build_tnt_obsidian_puzzle()
	_build_nether_portal_exit()
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
	runner.setup(player, SPAWN)

func _make_config() -> CourseConfig:
	var cfg := CONFIG_SCRIPT.new()
	cfg.course_id = "course_2"
	cfg.title = "溪流隐藏关卡 · 《我的世界》体素解谜"
	cfg.desc = "像素水流奔涌！推动方块填河架桥、推落重力沙砸晕恶犬、引爆红石TNT炸穿黑曜石！"
	cfg.kill_y = -12.0
	cfg.bounds = AABB(Vector3(-35, -16, -115), Vector3(70, 40, 140))
	cfg.dog_count = 1
	cfg.dog_speed_min = 2.4
	cfg.dog_speed_max = 5.2
	cfg.memes = {
		"course_start": {"title": "进入《我的世界》体素次元！", "text": "画风与玩法突变！小猪化身体素工匠，前方水流急促！", "duration": 3.0},
		"water_splash": {"title": "小猪落水！", "text": "湍急的体素溪流！被冲回岸边狗刨中……", "duration": 2.2},
		"bridge_built": {"title": "方块架桥成功！", "text": "《我的世界》基础技巧：把方块垫入急流铺路！", "duration": 2.5},
		"sand_drop": {"title": "重力沙下坠！", "text": "物理定律生效！沙子方块垂直砸落！", "duration": 2.2},
		"dog_buried": {"title": "恶犬被活埋！", "text": "重力沙盖顶！恶犬懵逼打喷嚏，峡谷道路畅通！", "duration": 3.0},
		"plate_click": {"title": "红石信号触发！", "text": "压力板咔哒一响！TNT开始急促膨胀！", "duration": 2.2},
		"tnt_blast": {"title": "艺术就是爆炸！", "text": "轰！黑曜石碎裂！通向下界传送门的道路打开了！", "duration": 3.0},
		"portal_enter": {"title": "穿过下界之门！", "text": "嗡……紫光闪烁，小猪成功打破次元离开溪流！", "duration": 2.5},
		"dog_bonk": {"title": "恶犬扑空", "text": "像素狗咬到了方块空气！", "duration": 2.0},
		"qte_success": {"title": "黑曜石挣脱！", "text": "老牛力量：硬如黑曜石，震退恶犬！", "duration": 2.2},
		"qte_fail": {"title": "挣脱失败", "text": "被甩飞了……下次狂按空格！", "duration": 2.2},
		"respawn": {"title": "重生点复活", "text": "像素猪毫发无损，重新整装出发！", "duration": 2.2},
	}
	return cfg

func _build_ground_and_structures() -> void:
	# 1. Start bank (Grassy voxel terrace)
	_voxel_platform("StartBank", Vector3(14, 1, 14), Vector3(0, -0.5, 9), VOXEL_GREEN, VOXEL_DIRT)

	# 2. Island between creek and cliff
	_voxel_platform("MidIsland", Vector3(12, 1, 14), Vector3(0, -0.5, -12), VOXEL_GREEN, VOXEL_DIRT)

	# 3. High cliff ledge overlooking canyon (Y = 3.0)
	_voxel_platform("HighCliff", Vector3(10, 4, 12), Vector3(0, 1.0, -26), VOXEL_STONE, VOXEL_DIRT)
	# Ramp up to high cliff
	_voxel_ramp("CliffRamp", Vector3(6, 4, 8), Vector3(0, -0.5, -18), 3.0)

	# 4. Lower Canyon floor (Y = 0.0)
	_voxel_platform("CanyonFloor", Vector3(12, 1, 36), Vector3(0, -0.5, -50), VOXEL_STONE, VOXEL_DIRT)

	# Canyon walls
	_solid_box("CanyonWallL", Vector3(2, 6, 36), Vector3(-6, 2.5, -50), VOXEL_STONE)
	_solid_box("CanyonWallR", Vector3(2, 6, 36), Vector3(6, 2.5, -50), VOXEL_STONE)

	# 5. Exit Plaza (Y = 0.0)
	_voxel_platform("ExitPlaza", Vector3(14, 1, 18), Vector3(0, -0.5, -80), VOXEL_GREEN, VOXEL_DIRT)

func _build_creek_puzzle() -> void:
	# Creek water stream at Z = -2.5, spanning between start bank and mid island
	water_stream = VOXEL_WATER_STREAM.new()
	water_stream.name = "CreekWaterStream"
	water_stream.stream_size = Vector3(10.0, 1.2, 5.0)
	water_stream.shore_point = Vector3(0, 0.6, 3.5)
	water_stream.position = Vector3(0, -0.1, -2.5)
	water_stream.bridge_slots_count = 2
	water_stream.slot_spacing = 2.4
	add_child(water_stream)

	water_stream.player_swept.connect(func(_st, _pos):
		if meme_layer:
			meme_layer.play("water_splash")
	)
	water_stream.bridge_completed.connect(func(_st, _idx):
		if meme_layer:
			meme_layer.play("bridge_built")
	)

	# Pushable Dirt Blocks on the starting bank
	dirt_block_1 = VOXEL_PUSH_BLOCK.new()
	dirt_block_1.name = "DirtBlock1"
	dirt_block_1.block_type = VOXEL_PUSH_BLOCK.BlockType.DIRT
	dirt_block_1.position = Vector3(-1.2, 0.0, 2.0)
	add_child(dirt_block_1)

	dirt_block_2 = VOXEL_PUSH_BLOCK.new()
	dirt_block_2.name = "DirtBlock2"
	dirt_block_2.block_type = VOXEL_PUSH_BLOCK.BlockType.DIRT
	dirt_block_2.position = Vector3(1.2, 0.0, 2.0)
	add_child(dirt_block_2)

	_label("【猪拱推箱】向前推泥土方块填河架桥！", Vector3(0, 2.2, 5.0), 22)

func _build_sand_canyon_puzzle() -> void:
	# Sand block positioned on high cliff edge (Z = -30, Y = 3.0)
	sand_block = VOXEL_PUSH_BLOCK.new()
	sand_block.name = "GravitySandBlock"
	sand_block.block_type = VOXEL_PUSH_BLOCK.BlockType.SAND
	sand_block.position = Vector3(0, 3.0, -29.0)
	sand_block.is_gravity_affected = true
	add_child(sand_block)

	_label("【重力沙】将沙子推下悬崖砸晕下方恶犬！", Vector3(0, 5.2, -26.0), 22)

	# Patrol dog / dummy guard waiting below in the canyon
	canyon_dog = Node3D.new()
	canyon_dog.name = "CanyonDogGuard"
	canyon_dog.position = Vector3(0, 0.5, -35.0)

	var dog_mesh := MeshInstance3D.new()
	dog_mesh.name = "DogMesh"
	var cap := CylinderMesh.new()
	cap.top_radius = 0.5
	cap.bottom_radius = 0.5
	cap.height = 1.0
	dog_mesh.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("991B1B")
	dog_mesh.material_override = mat
	canyon_dog.add_child(dog_mesh)

	var dog_col := Area3D.new()
	dog_col.name = "DogArea"
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.8, 1.8)
	col_shape.shape = box
	dog_col.add_child(col_shape)
	canyon_dog.add_child(dog_col)

	var dog_lbl := _label("恶犬守卫", Vector3(0, 1.5, 0), 18, canyon_dog)
	dog_lbl.name = "DogLabel"
	add_child(canyon_dog)

	# Connect sand land on dog
	sand_block.block_pushed.connect(func(_b, _dir):
		if meme_layer:
			meme_layer.play("sand_drop")
	)

	sand_block.block_landed_on_target.connect(func(_b, _target):
		_bury_dog(dog_lbl, dog_mesh)
	)

func _bury_dog(lbl: Label3D, mesh: MeshInstance3D) -> void:
	if canyon_dog == null or not is_instance_valid(canyon_dog):
		return
	lbl.text = "✖ 已被沙子活埋 (晕厥中)"
	lbl.modulate = Color("FBBF24")

	var tween := canyon_dog.create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.4, 0.2, 1.4), 0.2)
	tween.tween_callback(func():
		if meme_layer:
			meme_layer.play("dog_buried")
	)

func _build_tnt_obsidian_puzzle() -> void:
	# Obsidian Wall sealing the canyon at Z = -66
	obsidian_wall = VOXEL_OBSIDIAN_WALL.new()
	obsidian_wall.name = "VoxelObsidianWall"
	obsidian_wall.wall_width = 8.0
	obsidian_wall.wall_height = 4.0
	obsidian_wall.position = Vector3(0, 0, -66.0)
	add_child(obsidian_wall)

	obsidian_wall.wall_demolished.connect(func(_w):
		if meme_layer:
			meme_layer.play("tnt_blast")
	)

	# Pressure plate at Z = -56
	pressure_plate = VOXEL_PRESSURE_PLATE.new()
	pressure_plate.name = "VoxelPressurePlate"
	pressure_plate.target_wall = obsidian_wall
	pressure_plate.position = Vector3(0, 0, -56.0)
	add_child(pressure_plate)

	pressure_plate.plate_pressed.connect(func(_p, _body):
		if meme_layer:
			meme_layer.play("plate_click")
	)

	# TNT Block ready to be pushed onto plate
	tnt_block = VOXEL_PUSH_BLOCK.new()
	tnt_block.name = "VoxelTNTBlock"
	tnt_block.block_type = VOXEL_PUSH_BLOCK.BlockType.TNT
	tnt_block.position = Vector3(-2.2, 0, -54.0)
	add_child(tnt_block)

	_label("【黑曜石之壁】将 TNT 方块推上压力板引爆！", Vector3(0, 4.5, -64.0), 22)

func _build_nether_portal_exit() -> void:
	var portal_pos := Vector3(0, 0, -82.0)

	# Obsidian frame
	_solid_box("PortalFrameL", Vector3(1.2, 6.0, 1.2), portal_pos + Vector3(-2.4, 3.0, 0), Color("1E1B4B"))
	_solid_box("PortalFrameR", Vector3(1.2, 6.0, 1.2), portal_pos + Vector3(2.4, 3.0, 0), Color("1E1B4B"))
	_solid_box("PortalFrameTop", Vector3(6.0, 1.2, 1.2), portal_pos + Vector3(0, 6.6, 0), Color("1E1B4B"))
	_solid_box("PortalFrameBottom", Vector3(6.0, 0.6, 1.2), portal_pos + Vector3(0, 0.3, 0), Color("1E1B4B"))

	# Swirling purple portal curtain
	var portal_mesh := MeshInstance3D.new()
	portal_mesh.name = "NetherCurtain"
	var quad := BoxMesh.new()
	quad.size = Vector3(3.6, 5.4, 0.3)
	portal_mesh.mesh = quad
	portal_mesh.position = portal_pos + Vector3(0, 3.3, 0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("8B5CF6DD")
	mat.emission_enabled = true
	mat.emission = Color("A855F7")
	mat.emission_energy_multiplier = 1.5
	portal_mesh.material_override = mat
	add_child(portal_mesh)

	_label("◆ 下界传送门 · 胜利出口 ◆", portal_pos + Vector3(0, 7.5, 0), 28)
	_label("（步入紫光完成溪流关卡，返回小羊草甸！）", portal_pos + Vector3(0, 6.6, 0), 18)

func _build_decorations() -> void:
	# Voxel trees (Oak Wood trunk + Leaf cube canopy)
	_voxel_tree(Vector3(-6, 0, 8))
	_voxel_tree(Vector3(6, 0, 8))
	_voxel_tree(Vector3(-7, 0, -12))
	_voxel_tree(Vector3(7, 0, -12))
	_voxel_tree(Vector3(-7, 0, -78))
	_voxel_tree(Vector3(7, 0, -78))

func _voxel_tree(pos: Vector3) -> void:
	_solid_box("Trunk", Vector3(1.0, 4.0, 1.0), pos + Vector3(0, 2.0, 0), Color("795548"))
	_solid_box("Leaves", Vector3(3.2, 3.2, 3.2), pos + Vector3(0, 4.8, 0), Color("16A34A"))

func _build_markers() -> void:
	_area("CourseStart", "course_start", Vector3(0, 1, 10), Vector3(8, 3, 2))
	_checkpoint("Checkpoint1", 1, Vector3(0, 1, -12), Vector3(0, 0.6, -12))
	_checkpoint("Checkpoint2", 2, Vector3(0, 1, -45), Vector3(0, 0.6, -45))
	_area("CourseExit", "course_exit", Vector3(0, 2, -82), Vector3(4, 5, 3))

func _checkpoint(node_name: String, index: int, pos: Vector3, respawn: Vector3) -> void:
	var area := _area(node_name, "course_checkpoint", pos, Vector3(8, 3, 3))
	area.set_meta("checkpoint_index", index)
	area.set_meta("respawn_pos", respawn)
	_label("◆ 像素重生点", pos + Vector3(0, 1.6, 0), 18)

func _voxel_platform(node_name: String, size: Vector3, pos: Vector3, top_color: Color, side_color: Color) -> StaticBody3D:
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

	# Top turf
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

	# Dirt base
	var base_mesh := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(size.x, size.y - 0.25, size.z)
	base_mesh.mesh = base_box
	base_mesh.position = Vector3(0, -0.125, 0)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = side_color
	base_mat.roughness = 0.95
	base_mesh.material_override = base_mat
	body.add_child(base_mesh)

	add_child(body)
	return body

func _voxel_ramp(node_name: String, size: Vector3, pos: Vector3, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1

	var steps := 4
	for i in range(steps):
		var step_col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var step_depth := size.z / float(steps)
		var step_h := height / float(steps) * float(i + 1)
		box.size = Vector3(size.x, step_h, step_depth)
		step_col.shape = box
		step_col.position = Vector3(0, step_h * 0.5, -size.z * 0.5 + step_depth * (float(i) + 0.5))
		body.add_child(step_col)

		var mesh := MeshInstance3D.new()
		var mesh_box := BoxMesh.new()
		mesh_box.size = box.size
		mesh.mesh = mesh_box
		mesh.position = step_col.position
		var mat := StandardMaterial3D.new()
		mat.albedo_color = VOXEL_STONE
		mesh.material_override = mat
		body.add_child(mesh)

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
