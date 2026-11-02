extends Node3D
## Art pass two: a journey layout. The pig travels a linear route through
## distinct districts — pigpen, ox fields, sheep shearing shed, mud racetrack,
## open field chase, iron gate showdown, cable car over the wilderness.
## Districts are enclosed by fence lines with one gap each; travel routes are
## narrow fenced corridors between them, so route and area read differently.
## The whitebox contract API (spawn, gates, npc targets, cablecar, chase
## trigger) is preserved.

signal chase_entered

const ASSETS = preload("res://scripts/art/asset_library.gd")

const SPAWN := Vector3(0, 0.1, 93)
const CHASE_EXIT_Z := -84.0
const RETRY_POSITION := Vector3(0, 0.1, -52)
const CABLECAR_TRAVEL := Vector3(0, 2.0, -22)

const MAP_HALF_X := 46.0
# Zone edges along z: pigpen 102..86, R1 85..70, ox fields 70..38,
# R2 38..24, shearing shed 24..-2, R3 -2..-16, racetrack -16..-40,
# R4 -40..-54, open field -54..-84, gate courtyard -84..-92, cable car -92..-108.
const BOUNDARY_ZS := [70.0, 38.0, 24.0, -2.0, -16.0, -40.0, -54.0]

# Palette: sunlit storybook farm, matte surfaces, no specular.
const GRASS := Color("74A87C")
const GRASS_LIGHT := Color("91B88A")
const GRASS_DRY := Color(0.62, 0.70, 0.40)
const WORN := Color(0.68, 0.67, 0.43)
const DIRT := Color(0.68, 0.54, 0.36)
const MUD := Color(0.50, 0.41, 0.30)
const MUD_TRACK := Color(0.47, 0.36, 0.25)
const PATH := Color(0.82, 0.70, 0.48)
const SOIL := Color("3E2723")
const WOOD := Color(0.74, 0.56, 0.36)
const WOOD_DARK := Color(0.56, 0.41, 0.26)
const BARN_RED := Color(0.79, 0.32, 0.25)
const BARN_ROOF := Color(0.52, 0.36, 0.29)
const WHITE := Color(0.96, 0.95, 0.90)
const CREAM := Color(0.94, 0.90, 0.78)
const LEAF := Color(0.37, 0.60, 0.31)
const LEAF_LIGHT := Color(0.48, 0.68, 0.35)
const LEAF_DARK := Color(0.30, 0.50, 0.26)
const HAY := Color(0.89, 0.74, 0.34)
const STONE := Color(0.66, 0.63, 0.56)
const IRON := Color(0.32, 0.35, 0.38)
const WATER := Color(0.44, 0.68, 0.74)
const INK := Color(0.24, 0.27, 0.20)
const ACCENT := Color(0.93, 0.72, 0.30)
const FLOWER_RED := Color(0.88, 0.36, 0.32)
const FLOWER_YELLOW := Color(0.95, 0.80, 0.32)
const FLOWER_WHITE := Color(0.97, 0.97, 0.92)

var _gate: StaticBody3D
var _pigpen_gate: StaticBody3D
var _cabin: Node3D
var _npcs: Dictionary = {}
var _npc_origins: Dictionary = {}
var _npc_tweens: Dictionary = {}
var _gate_label: Label3D
var _windmill_blades: Node3D
var _gate_art: Node3D
var _gate_tween: Tween
var _sheep_tag: Node3D
var _farmer_baton: Node3D

func _ready() -> void:
	_build_ground()
	_build_boundaries()
	_build_pigpen()
	_build_routes()
	_build_ox_zone()
	_build_sheep_zone()
	_build_track_zone()
	_build_open_field()
	_build_gate_area()
	_build_exit()
	_install_art()
	_install_environment()

func _install_environment() -> void:
	# Retain gameplay roots and accepted imported models. Replace the blockout
	# environment as one coherent architectural pass, including every boundary.
	for child in get_children():
		var title := String(child.get_meta("blockout_name", child.name))
		var keep := false
		for prefix in ["ArtCable", "CableCarLever", "Lantern", "Barrel", "CartBed", "Scarecrow", "Windmill", "Blades", "SignPost", "SignBoard", "TroughWater"]:
			if title.begins_with(prefix): keep = true
		_retire_environment_meshes(child, keep)
	var environment: Node3D
	var packed_path := "res://assets/environments/pastoral_farm.scn"
	if ResourceLoader.exists(packed_path) and not "--rebuild-environment" in OS.get_cmdline_user_args():
		environment = load(packed_path).instantiate()
	else:
		environment = preload("res://scripts/art/pastoral_environment.gd").new()
		environment.build(self)
	add_child(environment)
	var gate_insert := environment.get_node("PigpenGateInsert").duplicate() as MeshInstance3D
	gate_insert.name = "TimberGate"
	gate_insert.show()
	_pigpen_gate.add_child(gate_insert)

func _retire_environment_meshes(node: Node, keep: bool = false) -> void:
	if node.has_meta("asset_id"): return
	if node is MeshInstance3D and not keep: node.hide()
	if node is Label3D:
		if node.name == "NameLabel":
			node.scale = Vector3.ONE * 0.72
			node.visibility_range_end = 24.0
		elif node.name == "BoardText":
			node.text = "35 秒\n春季纪录"
			node.position = Vector3(0.2, 0.42, 0)
			node.font_size = 24
			node.pixel_size = 0.009
			node.no_depth_test = true
			node.outline_size = 2
			node.modulate = Color("394837")
			node.outline_modulate = Color("E1DDC5")
		else: node.hide()
	for child in node.get_children(): _retire_environment_meshes(child, keep)

func _install_art() -> void:
	var cabin_art := ASSETS.replace_visuals(_cabin, "PROP_01")
	if cabin_art:
		# Pulley axis follows the sloping cable through the full cinematic travel.
		get_node("CableLine").hide()
		var direction := CABLECAR_TRAVEL.normalized()
		var cable_start := _cabin.position + Vector3(0, 4.1, 0) - direction * 21.0
		var cable_end := _cabin.position + Vector3(0, 4.1, 0) + direction * 36.0
		var cable := _box(self, "ArtCable", Vector3(0.07, 0.07, cable_start.distance_to(cable_end)), (cable_start + cable_end) * 0.5, INK)
		cable.look_at(cable_end, Vector3.UP)
		for post_name in ["CablePostL", "CablePostR", "CableCross"]:
			get_node(post_name).hide()
		_box(self, "ArtCablePostL", Vector3(0.24, 3.37, 0.24), Vector3(-1.7, 1.685, -96), WOOD_DARK)
		_box(self, "ArtCablePostR", Vector3(0.24, 3.37, 0.24), Vector3(1.7, 1.685, -96), WOOD_DARK)
		_box(self, "ArtCableCross", Vector3(3.65, 0.18, 0.18), Vector3(0, 3.37, -96), WOOD_DARK)
	var characters := {"goat": "CHAR_02", "ox": "CHAR_03", "sheep": "CHAR_04", "horse": "CHAR_05", "farmer": "CHAR_07"}
	for id in characters:
		ASSETS.replace_visuals(_npcs[id], characters[id])
	_gate_art = ASSETS.replace_visuals(_gate, "PROP_02", Vector3(0, -0.9, 0))
	ASSETS.replace_visuals(get_node("RecordBoard"), "PROP_06", Vector3(0, -1, 0), PI * 0.5)
	var plow := ASSETS.make("PROP_04")
	if plow:
		get_node("PlowBeam/VisualMesh").hide()
		get_node("PlowHandle").hide()
		get_node("PlowBlade").hide()
		add_child(plow)
		plow.position = Vector3(-12, 0, 51.5)
	_sheep_tag = ASSETS.make("PROP_05")
	if _sheep_tag:
		_npcs["sheep"].add_child(_sheep_tag)
		_sheep_tag.position = Vector3(0, 0.35, -0.86)
		ASSETS.attach_to_bone(_npcs["sheep"].get_node_or_null("CHAR_04"), "Head", _sheep_tag, _sheep_tag.position)
		_label(_sheep_tag, "GradeText", "三等残次", Vector3(0, 0.15, -0.035), 24)
	_farmer_baton = ASSETS.make("PROP_07")
	if _farmer_baton:
		_npcs["farmer"].add_child(_farmer_baton)
		_farmer_baton.position = Vector3(0.43, 0.83, -0.10)
		_farmer_baton.rotation.x = -0.6
		ASSETS.attach_to_bone(_npcs["farmer"].get_node_or_null("CHAR_07"), "ArmL", _farmer_baton, _farmer_baton.position, _farmer_baton.rotation)
	var tractor := ASSETS.make("ENV_06_TRACTOR")
	if tractor:
		add_child(tractor)
		tractor.position = Vector3(-17, 0, -69)
		tractor.rotation.y = -0.6
		# This dressing is outside the established chase lane.
		var body := StaticBody3D.new()
		tractor.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 1.7, 3.5)
		shape.shape = box
		shape.position.y = 0.85
		body.add_child(shape)
		body.collision_layer = 1

func _process(delta: float) -> void:
	if is_instance_valid(_windmill_blades):
		_windmill_blades.rotate_z(delta * 0.45)

func get_spawn_position() -> Vector3:
	return to_global(SPAWN)

func set_gate_open(open: bool) -> void:
	_set_barrier(_gate, open)
	if is_instance_valid(_gate_art):
		if is_instance_valid(_gate_tween): _gate_tween.kill()
		var left := _gate_art.find_child("GateLeft", true, false) as Node3D
		var right := _gate_art.find_child("GateRight", true, false) as Node3D
		# Unsplit imports use the proven disappear/open behavior until hinges are authored.
		_gate.visible = not open or (left != null and right != null)
		if left and right: _gate_tween = create_tween().set_parallel(true)
		for leaf_name in ["GateLeft", "GateRight"]:
			var leaf := _gate_art.find_child(leaf_name, true, false) as Node3D
			if left and right and leaf:
				var angle := (1.5 if leaf_name == "GateLeft" else -1.5) if open else 0.0
				_gate_tween.tween_property(leaf, "rotation:y", angle, 0.65)
	if is_instance_valid(_farmer_baton): _farmer_baton.visible = not open
	if is_instance_valid(_gate_label):
		_gate_label.text = "铁门已开 / OPEN" if open else "铁门 / LOCKED"

func set_pigpen_open(open: bool) -> void:
	_set_barrier(_pigpen_gate, open)

func set_npc_completed(id: String) -> void:
	if not _npcs.has(id):
		return
	if id == "sheep" and is_instance_valid(_sheep_tag): _sheep_tag.hide()
	if _npc_tweens.has(id) and is_instance_valid(_npc_tweens[id]):
		_npc_tweens[id].kill()
	var targets := {"ox": Vector3(-24.5, 0, 40), "sheep": Vector3(8, 0, 4), "horse": Vector3(7.5, 0, -28)}
	if targets.has(id):
		var tween := create_tween()
		tween.tween_property(_npcs[id], "position", targets[id], 0.8)
		_npc_tweens[id] = tween
	var label := _npcs[id].get_node_or_null("NameLabel") as Label3D
	if label:
		var names := {"ox": "老牛 · 饮水", "sheep": "小羊 · 晒太阳", "horse": "追风 · 嚼野草"}
		label.text = names.get(id, id)

func get_cablecar() -> Node3D:
	return _cabin

func reset_world() -> void:
	if is_instance_valid(_sheep_tag): _sheep_tag.show()
	if is_instance_valid(_farmer_baton): _farmer_baton.show()
	for tween in _npc_tweens.values():
		if is_instance_valid(tween):
			tween.kill()
	_npc_tweens.clear()
	for id in _npc_origins:
		_npcs[id].position = _npc_origins[id]
	var labels := {"ox": "老牛 / OX", "sheep": "小羊 / SHEEP", "horse": "追风 / HORSE"}
	for id in labels:
		_npcs[id].get_node("NameLabel").text = labels[id]
	set_gate_open(false)
	set_pigpen_open(false)
	_cabin.position = Vector3(0, 0, -104)

# ---------------------------------------------------------------- ground

func _build_ground() -> void:
	_box(self, "Ground", Vector3(94, 0.6, 212), Vector3(0, -0.3, -3), GRASS, true)
	# District tints: each zone gets its own ground color, like painted dioramas.
	_box(self, "PigpenDirt", Vector3(19, 0.04, 16), Vector3(0, 0.02, 93), DIRT)
	_box(self, "OxTint", Vector3(92, 0.035, 32), Vector3(0, 0.018, 54), GRASS_LIGHT)
	_box(self, "Barnyard", Vector3(16, 0.04, 12), Vector3(-30, 0.02, 46), DIRT)
	_box(self, "SheepTint", Vector3(92, 0.035, 26), Vector3(0, 0.018, 11), GRASS_LIGHT)
	_box(self, "ShedFloor", Vector3(12, 0.04, 9), Vector3(-15, 0.02, 10), MUD)
	_box(self, "TrackTint", Vector3(92, 0.035, 24), Vector3(0, 0.018, -28), Color(0.60, 0.72, 0.39))
	_box(self, "OpenDry", Vector3(92, 0.035, 30), Vector3(0, 0.018, -69), GRASS_DRY)
	_box(self, "Courtyard", Vector3(92, 0.04, 8), Vector3(0, 0.02, -88), Color(0.70, 0.67, 0.60))
	_box(self, "CliffRock", Vector3(50, 0.04, 16), Vector3(0, 0.02, -100), Color(0.60, 0.56, 0.49))
	_label(self, "StartTitle", "01  山顶猪圈", Vector3(0, 2.2, 96.5), 26)
	_signpost("耕作区 · 老牛", Vector3(4.5, 0, 66.5))
	_signpost("剪毛棚 · 小羊", Vector3(4.5, 0, 20.5))
	_signpost("泥圈赛道 · 追风", Vector3(4.5, 0, -17.5))
	_signpost("农场开阔地", Vector3(5, 0, -56))

func _build_boundaries() -> void:
	# Tall invisible walls keep everything in; white picket fences sell the farm look.
	_boundary_wall("WestBoundary", Vector3(-MAP_HALF_X - 0.75, 0, -3), Vector3(0.5, 6, 212.5))
	_boundary_wall("EastBoundary", Vector3(MAP_HALF_X + 0.75, 0, -3), Vector3(0.5, 6, 212.5))
	_boundary_wall("StartBoundary", Vector3(0, 0, 103.25), Vector3(94.5, 6, 0.5))
	_boundary_wall("EndBoundary", Vector3(0, 0, -109.25), Vector3(94.5, 6, 0.5))
	_fence(self, Vector3(-45.8, 0, 102.5), Vector3(-45.8, 0, -108), true)
	_fence(self, Vector3(45.8, 0, 102.5), Vector3(45.8, 0, -108), true)
	_fence(self, Vector3(-45.8, 0, 102.5), Vector3(45.8, 0, 102.5), true)
	# District boundary fence lines with a gap where the route passes through.
	for z in BOUNDARY_ZS:
		_boundary_line(z)
	# Distant scenery outside the fences.
	_scenery_hill(Vector3(-28, -1.5, 118), 14)
	_scenery_hill(Vector3(24, -1.0, 122), 12)
	_scenery_hill(Vector3(-56, -1, 60), 11)
	_scenery_hill(Vector3(58, -1, 20), 12)
	_scenery_hill(Vector3(-58, -1, -30), 12)
	for pos in [Vector3(-52, 0, 90), Vector3(52, 0, 80), Vector3(-50, 0, 20), Vector3(54, 0, 44), Vector3(-54, 0, -60), Vector3(52, 0, -70)]:
		_tree(pos, 1.2)

func _boundary_wall(node_name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)

func _boundary_line(z: float) -> void:
	_fence(self, Vector3(-MAP_HALF_X, 0, z), Vector3(-2.5, 0, z), true)
	_fence(self, Vector3(2.5, 0, z), Vector3(MAP_HALF_X, 0, z), true)
	_gate_post(Vector3(-2.5, 0, z))
	_gate_post(Vector3(2.5, 0, z))

func _gate_post(pos: Vector3) -> void:
	_box(self, "GatePost", Vector3(0.5, 1.5, 0.5), pos + Vector3(0, 0.75, 0), WHITE, true)
	_box(self, "GatePostCap", Vector3(0.66, 0.16, 0.66), pos + Vector3(0, 1.58, 0), BARN_RED)

# ---------------------------------------------------------------- pigpen

func _build_pigpen() -> void:
	_npc("goat", "老岩羊 / GOAT", Vector3(-3, 0, 83.5), 1.4)
	_box(self, "MudPatch", Vector3(6, 0.03, 5), Vector3(0.5, 0.03, 91), MUD)
	_fence(self, Vector3(-9, 0, 100), Vector3(9, 0, 100), true)
	_fence(self, Vector3(-9, 0, 86), Vector3(-9, 0, 100), true)
	_fence(self, Vector3(9, 0, 86), Vector3(9, 0, 100), true)
	_fence(self, Vector3(-9, 0, 86), Vector3(-2.2, 0, 86), true)
	_fence(self, Vector3(2.2, 0, 86), Vector3(9, 0, 86), true)
	_pigpen_gate = _box(self, "PigpenGate", Vector3(4.4, 1.2, 0.4), Vector3(0, 0.6, 86), BARN_RED, true) as StaticBody3D
	_label(self, "PigpenGateLabel", "出口 / EXIT", Vector3(0, 1.9, 86), 24)
	_trough(Vector3(-4.5, 0, 96.5))
	_hay_bale(Vector3(3.8, 0, 96.5))
	_hay_bale(Vector3(2.4, 0, 97.4), 0.8)

# ---------------------------------------------------------------- routes

func _build_routes() -> void:
	# Corridor ends overlap the district boundary lines so no side gap remains.
	_route_corridor(86.3, 69.7)
	_route_decor_r1()
	_route_corridor(38.3, 23.7)
	_route_decor_r2()
	_route_corridor(-1.7, -16.3)
	_route_decor_r3()
	_route_corridor(-39.7, -54.3)
	_route_decor_r4()

func _route_corridor(z_north: float, z_south: float) -> void:
	var length := z_north - z_south
	var mid_z := (z_north + z_south) * 0.5
	_fence(self, Vector3(-6, 0, z_north), Vector3(-6, 0, z_south), true)
	_fence(self, Vector3(6, 0, z_north), Vector3(6, 0, z_south), true)
	_box(self, "RouteTint", Vector3(12.6, 0.03, length + 1), Vector3(0, 0.018, mid_z), WORN)
	_box(self, "RoutePath", Vector3(3.6, 0.035, length + 1), Vector3(0, 0.025, mid_z), PATH)

func _route_decor_r1() -> void:
	# Pigpen to ox fields: young trees and shrubs line the hedge corridor.
	_tree(Vector3(-9.5, 0, 78), 1.0)
	_tree(Vector3(9.5, 0, 74), 0.95)
	_bush(Vector3(-8.5, 0, 82), 1.0)
	_bush(Vector3(8.5, 0, 71.5), 0.9)
	_flower_patch(Vector3(9, 0, 80))

func _route_decor_r2() -> void:
	# Ox fields to shearing shed: wildflowers and a rest stop with hay.
	_flower_patch(Vector3(-8.5, 0, 36))
	_flower_patch(Vector3(8.5, 0, 26.5))
	_flower_patch(Vector3(-9, 0, 28))
	_bush(Vector3(-8.5, 0, 31), 1.0)
	_hay_bale(Vector3(8.5, 0, 34))
	_barrel(Vector3(9, 0, 32.5))

func _route_decor_r3() -> void:
	# Shearing shed to racetrack: work props stacked along the hedge.
	_barrel(Vector3(-8.5, 0, -6))
	_barrel(Vector3(-9, 0, -7.6))
	_crate(Vector3(8.5, 0, -4), 1.2)
	_bush(Vector3(8.5, 0, -11), 1.0)
	_bush(Vector3(-8.5, 0, -12.5), 0.9)
	_flower_patch(Vector3(9, 0, -8))

func _route_decor_r4() -> void:
	# Racetrack to the open field: the farm thins out toward the run.
	_tree(Vector3(-9.5, 0, -44), 1.1)
	_tree(Vector3(9.5, 0, -50), 1.0)
	_crate(Vector3(8.5, 0, -43), 1.3)
	_bush(Vector3(-8.5, 0, -51), 1.1)

# ---------------------------------------------------------------- ox zone

func _build_ox_zone() -> void:
	_npc("ox", "老牛 / OX", Vector3(-9, 0, 51), 1.7)
	_barn(Vector3(-33, 0, 46))
	_silo(Vector3(-41.5, 0, 38))
	_windmill(Vector3(32, 0, 60))
	_crop_field()
	_trough(Vector3(-26, 0, 40))
	_plow(Vector3(-12, 0, 51.5))
	_scarecrow(Vector3(-10, 0, 63))
	_hay_bale(Vector3(7, 0, 62))
	_hay_bale(Vector3(8.5, 0, 60.5), 0.85)
	_farm_cart(Vector3(12, 0, 42))
	_crate(Vector3(-6, 0, 43), 1.2)
	_barrel(Vector3(-27, 0, 51.5))
	_flower_patch(Vector3(4.5, 0, 58))
	_flower_patch(Vector3(-4.5, 0, 44))
	_flower_patch(Vector3(3.5, 0, 50))
	_bush(Vector3(18, 0, 52), 1.2)
	_bush(Vector3(-18, 0, 36.5), 1.0)
	_tree(Vector3(24, 0, 64), 1.2)
	_tree(Vector3(30, 0, 52), 1.1)
	_tree(Vector3(38, 0, 46), 1.2)
	_tree(Vector3(26, 0, 42), 1.0)
	_tree(Vector3(36, 0, 64), 1.15)
	_tree(Vector3(-42, 0, 58), 1.2)
	_tree(Vector3(-40, 0, 30), 1.1)
	_signpost("老牛的水槽", Vector3(-22.5, 0, 42.5))

func _barn(pos: Vector3) -> void:
	_box(self, "BarnBody", Vector3(11, 5, 8), pos + Vector3(0, 2.5, 0), BARN_RED, true)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(12.4, 2.6, 9)
	roof.mesh = prism
	roof.material_override = _material(BARN_ROOF)
	roof.position = pos + Vector3(0, 6.3, 0)
	add_child(roof)
	_box(self, "BarnTrimTop", Vector3(0.3, 0.3, 8.4), pos + Vector3(5.55, 5.1, 0), WHITE)
	_box(self, "BarnTrimLeft", Vector3(0.3, 5, 0.3), pos + Vector3(5.55, 2.5, -3.9), WHITE)
	_box(self, "BarnTrimRight", Vector3(0.3, 5, 0.3), pos + Vector3(5.55, 2.5, 3.9), WHITE)
	_box(self, "BarnDoor", Vector3(0.18, 3.2, 3.2), pos + Vector3(5.62, 1.6, 0), WOOD_DARK)
	_box(self, "BarnLoft", Vector3(0.18, 0.9, 0.9), pos + Vector3(5.62, 4.2, 0), WHITE)

func _silo(pos: Vector3) -> void:
	_cylinder(self, "Silo", 2.1, 2.5, 9, pos + Vector3(0, 4.5, 0), Color(0.70, 0.74, 0.77), true)
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.2
	sphere.height = 2.6
	dome.mesh = sphere
	dome.material_override = _material(Color(0.58, 0.62, 0.66))
	dome.position = pos + Vector3(0, 9.4, 0)
	add_child(dome)

func _windmill(pos: Vector3) -> void:
	_cylinder(self, "WindmillTower", 1.0, 2.2, 10, pos + Vector3(0, 5, 0), CREAM, true)
	_cylinder(self, "WindmillCap", 0.02, 1.35, 1.5, pos + Vector3(0, 10.7, 0), BARN_RED)
	_box(self, "WindmillDoor", Vector3(0.9, 1.6, 0.2), pos + Vector3(0, 0.8, -1.9), WOOD_DARK)
	_windmill_blades = Node3D.new()
	_windmill_blades.name = "Blades"
	_windmill_blades.position = pos + Vector3(0, 9.2, -1.8)
	add_child(_windmill_blades)
	for index in 4:
		var blade := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 5.0, 0.09)
		blade.mesh = box
		blade.material_override = _material(WOOD)
		blade.rotation.z = index * PI * 0.5
		_windmill_blades.add_child(blade)
	var hub := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.5
	hub.mesh = sphere
	hub.material_override = _material(WOOD_DARK)
	_windmill_blades.add_child(hub)

func _crop_field() -> void:
	_box(self, "FieldSoil", Vector3(26, 0.05, 18), Vector3(-22, 0.025, 59), SOIL)
	for row in 7:
		var z := 53.0 + row * 2.0
		_box(self, "Ridge_%d" % row, Vector3(24, 0.12, 0.9), Vector3(-22, 0.06, z), Color(0.36, 0.26, 0.17))
		for clump in 11:
			var x := -33.0 + clump * 2.2
			var plant := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.3
			sphere.height = 0.62
			plant.mesh = sphere
			plant.material_override = _material(LEAF if (row + clump) % 2 == 0 else LEAF_LIGHT)
			plant.position = Vector3(x + (0.25 if row % 2 == 0 else -0.25), 0.28, z)
			plant.scale = Vector3(1, 1.25, 1)
			add_child(plant)
	for pos in [Vector3(-34, 0, 52.2), Vector3(-30, 0, 55.4), Vector3(-35, 0, 60.2), Vector3(-31, 0, 63.4), Vector3(-8.4, 0, 56.6), Vector3(-8.8, 0, 62.4)]:
		_sphere(self, "Pumpkin", 0.3, pos + Vector3(0, 0.22, 0), Color(0.86, 0.48, 0.18))

# ---------------------------------------------------------------- sheep zone

func _build_sheep_zone() -> void:
	_npc("sheep", "小羊 / SHEEP", Vector3(-12, 0, 9.5), 1.15)
	_shearing_shed(Vector3(-16, 0, 10))
	_pond(Vector3(26, 0, 6))
	_sun_patch(Vector3(8, 0, 4), 3.0)
	_wool_bale(Vector3(-18, 0, 11.5))
	_wool_bale(Vector3(-19, 0, 8), 0.85)
	_wool_bale(Vector3(-15, 0, 7.8), 0.9)
	_wool_bale(Vector3(-10.5, 0, 13.5))
	_wool_bale(Vector3(-11.8, 0, 14.6), 0.8)
	_signpost("剪毛台", Vector3(-13, 0, 5.2))
	_flower_patch(Vector3(4.5, 0, 16))
	_flower_patch(Vector3(-4, 0, -0.5))
	_flower_patch(Vector3(6, 0, -1))
	_bush(Vector3(-24, 0, 20), 1.2)
	_bush(Vector3(14, 0, 18), 1.0)
	_tree(Vector3(20, 0, 16), 1.1)
	_tree(Vector3(35, 0, 14), 1.2)
	_tree(Vector3(38, 0, 0), 1.1)
	_tree(Vector3(12, 0, 20.5), 1.0)
	_tree(Vector3(-30, 0, 20), 1.2)
	_tree(Vector3(-36, 0, 2), 1.1)
	_tree(Vector3(-40, 0, 14), 1.0)
	_tree(Vector3(34, 0, -5), 1.15)

func _shearing_shed(pos: Vector3) -> void:
	# Low open-front shed facing the path: back wall west, sides north/south.
	_box(self, "ShedBack", Vector3(0.5, 2.2, 7), pos + Vector3(-5, 1.1, 0), WOOD, true)
	_box(self, "ShedSideN", Vector3(10, 2.2, 0.5), pos + Vector3(0, 1.1, -3.25), WOOD, true)
	_box(self, "ShedSideS", Vector3(10, 2.2, 0.5), pos + Vector3(0, 1.1, 3.25), WOOD, true)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	# A cutaway near roof keeps the sheep and interaction readable from the game camera.
	prism.size = Vector3(4.8, 1.2, 7.8)
	roof.name = "ShearingRoof"
	roof.mesh = prism
	roof.material_override = _material(WOOD_DARK)
	roof.position = pos + Vector3(-3, 2.8, 0)
	add_child(roof)
	for z in [-3.1, 3.1]:
		_box(self, "ShedFrontPost", Vector3(0.18, 2.5, 0.18), pos + Vector3(4.5, 1.25, z), WOOD_DARK)
	_box(self, "ShedFrontBeam", Vector3(0.18, 0.18, 6.4), pos + Vector3(4.5, 2.5, 0), WOOD_DARK)
	_box(self, "ShearingStand", Vector3(1.4, 0.8, 0.9), pos + Vector3(-2.5, 0.4, 1.6), WOOD_DARK, true)

func _wool_bale(pos: Vector3, scale_factor: float = 1.0) -> void:
	_sphere(self, "WoolBale", 0.55 * scale_factor, pos + Vector3(0, 0.42 * scale_factor, 0), WHITE)
	_sphere(self, "WoolBaleTop", 0.38 * scale_factor, pos + Vector3(0.2 * scale_factor, 0.82 * scale_factor, 0.1), CREAM)

func _pond(pos: Vector3) -> void:
	_cylinder(self, "PondSand", 7.1, 7.1, 0.07, pos + Vector3(0, 0.035, 0), Color(0.83, 0.76, 0.58))
	_cylinder(self, "PondWater", 6.5, 6.5, 0.16, pos + Vector3(0, 0.08, 0), WATER)
	for index in 9:
		var angle := TAU * float(index) / 9.0
		var rock_pos := pos + Vector3(cos(angle), 0, sin(angle)) * 7.0
		_sphere(self, "PondRock_%d" % index, 0.25 + 0.1 * (index % 3), rock_pos + Vector3(0, 0.12, 0), STONE)
	for index in 6:
		var reed_angle := TAU * float(index) / 6.0 + 0.4
		var reed_pos := pos + Vector3(cos(reed_angle), 0, sin(reed_angle)) * 5.6
		_cylinder(self, "ReedStem_%d" % index, 0.03, 0.035, 1.2, reed_pos + Vector3(0, 0.7, 0), LEAF_DARK)
		_cylinder(self, "ReedTip_%d" % index, 0.05, 0.05, 0.3, reed_pos + Vector3(0, 1.35, 0), Color(0.52, 0.38, 0.22))
	for index in 3:
		var lily_angle := TAU * float(index) / 3.0 + 1.1
		var lily_pos := pos + Vector3(cos(lily_angle), 0, sin(lily_angle)) * 2.8
		_cylinder(self, "LilyPad_%d" % index, 0.32, 0.32, 0.02, lily_pos + Vector3(0, 0.17, 0), LEAF_LIGHT)

# ---------------------------------------------------------------- racetrack zone

func _build_track_zone() -> void:
	_npc("horse", "追风 / HORSE", Vector3(16, 0, -28), 2.1)
	_racetrack(Vector3(16, 0, -28))
	_record_board(Vector3(3, 0, -20))
	_trough(Vector3(18.5, 0, -25.5))
	_hay_bale(Vector3(20, 0, -31))
	_hay_bale(Vector3(21.4, 0, -30.2), 0.8)
	_barrel(Vector3(-6, 0, -24))
	_barrel(Vector3(-7, 0, -25.6))
	_crate(Vector3(-6.5, 0, -34), 1.3)
	_flower_patch(Vector3(-4.5, 0, -20))
	_flower_patch(Vector3(4.5, 0, -37))
	_bush(Vector3(30, 0, -22), 1.1)
	_bush(Vector3(-14, 0, -30), 1.0)
	_tree(Vector3(34, 0, -20), 1.2)
	_tree(Vector3(38, 0, -30), 1.1)
	_tree(Vector3(33, 0, -38), 1.2)
	_tree(Vector3(-20, 0, -22), 1.1)
	_tree(Vector3(-28, 0, -34), 1.2)
	_tree(Vector3(-36, 0, -24), 1.0)

func _racetrack(center: Vector3) -> void:
	# Elliptical mud ring: outer mud disc, grass island on top, fence between.
	var mud := _cylinder(self, "TrackMud", 8.8, 8.8, 0.1, center + Vector3(0, 0.05, 0), MUD_TRACK)
	mud.scale = Vector3(1.5, 1, 1)
	var island := _cylinder(self, "TrackIsland", 7.2, 7.2, 0.1, center + Vector3(0, 0.055, 0), GRASS_LIGHT)
	island.scale = Vector3(1.5, 1, 1)
	# Dodecagon fence ring with one opening on the west side toward the path.
	var radius_x := 11.9
	var radius_z := 7.9
	for index in 12:
		if index == 6:
			continue
		var a1 := TAU * float(index) / 12.0 - TAU / 24.0
		var a2 := TAU * float(index) / 12.0 + TAU / 24.0
		var from := center + Vector3(cos(a1) * radius_x, 0, sin(a1) * radius_z)
		var to := center + Vector3(cos(a2) * radius_x, 0, sin(a2) * radius_z)
		_fence(self, from, to, true)

func _record_board(pos: Vector3) -> void:
	var body := _box(self, "RecordBoard", Vector3(0.22, 2.0, 1.9), pos + Vector3(0, 1.0, 0), WOOD, true) as StaticBody3D
	_box(body, "BoardFace", Vector3(0.06, 1.3, 1.6), Vector3(-0.14, 0.1, 0), CREAM)
	_interactable(body, "record_board")
	_label(body, "BoardText", "41 秒 → 35 秒\n纪录榜 / RECORD", Vector3(-0.3, 0.3, 0), 24)

# ---------------------------------------------------------------- open field (chase)

func _build_open_field() -> void:
	_box(self, "ChaseStartStripe", Vector3(92, 0.05, 0.35), Vector3(0, 0.045, -54.5), ACCENT)
	_box(self, "ChaseExitStripe", Vector3(92, 0.05, 0.35), Vector3(0, 0.045, CHASE_EXIT_Z), Color(0.52, 0.76, 0.46))
	_label(self, "ChaseWarning", "犬队出没！沿土路向前跑到铁门", Vector3(5.5, 2.4, -57), 26)
	# Obstacles flank a generous center lane; nothing forces a skill move.
	_hay_bale(Vector3(-7, 0, -60))
	_crate(Vector3(7, 0, -58), 1.4)
	_hay_bale(Vector3(8, 0, -64))
	_barrel(Vector3(14, 0, -68))
	_hay_bale(Vector3(-10, 0, -70))
	_barrel(Vector3(-15, 0, -60))
	_crate(Vector3(-9, 0, -78), 1.3)
	_hay_bale(Vector3(12, 0, -75))
	_scarecrow(Vector3(-6, 0, -72))
	_farm_cart(Vector3(10, 0, -80))
	_tree(Vector3(-22, 0, -60), 1.2)
	_tree(Vector3(24, 0, -66), 1.1)
	_tree(Vector3(-28, 0, -76), 1.0)
	_tree(Vector3(20, 0, -78), 1.2)
	_tree(Vector3(30, 0, -58), 1.1)
	_tree(Vector3(-34, 0, -70), 1.0)
	_flower_patch(Vector3(-4, 0, -62))
	_bush(Vector3(16, 0, -58), 1.0)
	_box(self, "OpenPath", Vector3(3.4, 0.035, 30), Vector3(0, 0.02, -69), PATH)
	var trigger := Area3D.new()
	trigger.name = "ChaseStart"
	trigger.position = Vector3(0, 1, -54.5)
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	add_child(trigger)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(94, 2.4, 1.0)
	collider.shape = shape
	trigger.add_child(collider)
	trigger.body_entered.connect(_on_chase_entered)

# ---------------------------------------------------------------- gate & showdown

func _build_gate_area() -> void:
	_npc("farmer", "农场主 / FARMER", Vector3(5, 0, -87.5), 1.9)
	_box(self, "GateWallLeft", Vector3(42.7, 1.8, 0.7), Vector3(-24.55, 0.9, -90), STONE, true)
	_box(self, "GateWallRight", Vector3(42.7, 1.8, 0.7), Vector3(24.55, 0.9, -90), STONE, true)
	_box(self, "GatePillarLeft", Vector3(0.9, 2.6, 0.9), Vector3(-2.85, 1.3, -90), Color(0.58, 0.55, 0.48), true)
	_box(self, "GatePillarRight", Vector3(0.9, 2.6, 0.9), Vector3(2.85, 1.3, -90), Color(0.58, 0.55, 0.48), true)
	_box(self, "GateFlagLeft", Vector3(0.55, 0.4, 0.05), Vector3(-2.85, 2.85, -90), BARN_RED)
	_box(self, "GateFlagRight", Vector3(0.55, 0.4, 0.05), Vector3(2.85, 2.85, -90), BARN_RED)
	_gate = _box(self, "Gate", Vector3(4.8, 1.8, 0.5), Vector3(0, 0.9, -90), IRON, true) as StaticBody3D
	_gate_label = _label(self, "GateLabel", "铁门 / LOCKED", Vector3(0, 3.2, -90), 30)
	_lantern(Vector3(-4, 0, -87))
	_lantern(Vector3(4, 0, -87))
	_box(self, "GatePath", Vector3(3.4, 0.035, 10), Vector3(0, 0.02, -86.5), PATH)

func _lantern(pos: Vector3) -> void:
	_cylinder(self, "LanternPost", 0.06, 0.08, 2.2, pos + Vector3(0, 1.1, 0), WOOD_DARK)
	_box(self, "LanternLamp", Vector3(0.3, 0.35, 0.3), pos + Vector3(0, 2.35, 0), ACCENT)

# ---------------------------------------------------------------- cable car & wilderness

func _build_exit() -> void:
	_label(self, "CliffTitle", "05  索道 / 旷野", Vector3(0, 2.6, -97), 26)
	_label(self, "CliffWarning", "悬崖止步", Vector3(5, 1.8, -102), 20)
	_box(self, "CablePath", Vector3(3.2, 0.035, 12), Vector3(-0.5, 0.02, -97), PATH)
	var lever := _box(self, "CableCarLever", Vector3(0.9, 0.75, 0.9), Vector3(-2, 0.375, -98), STONE, true) as StaticBody3D
	_box(lever, "LeverSlot", Vector3(0.5, 0.18, 0.18), Vector3(0, 0.46, 0), ACCENT)
	_interactable(lever, "cablecar")
	_label(lever, "LeverLabel", "插入铜插销\nE  启动", Vector3(0, 1.55, 0), 24)
	# Cable line from behind the gate, over the cliff, out toward the wilderness.
	_box(self, "CableLine", Vector3(0.09, 0.09, 58), Vector3(0, 4.4, -112), INK)
	_box(self, "CablePostL", Vector3(0.22, 4.4, 0.22), Vector3(-1.7, 2.2, -96), WOOD_DARK)
	_box(self, "CablePostR", Vector3(0.22, 4.4, 0.22), Vector3(1.7, 2.2, -96), WOOD_DARK)
	_box(self, "CableCross", Vector3(3.6, 0.14, 0.14), Vector3(0, 4.33, -96), WOOD_DARK)
	_cabin = Node3D.new()
	_cabin.name = "CableCarCabin"
	_cabin.position = Vector3(0, 0, -104)
	add_child(_cabin)
	_box(_cabin, "Deck", Vector3(3.2, 0.2, 2.6), Vector3(0, 0.12, 0), WOOD)
	for x in [-1.5, 1.5]:
		_box(_cabin, "Rail_%s" % str(x), Vector3(0.12, 0.8, 2.6), Vector3(x, 0.6, 0), WOOD_DARK)
	# Open frame instead of an opaque roof, so the isometric camera can see the passenger.
	_box(_cabin, "RoofFront", Vector3(3.3, 0.12, 0.12), Vector3(0, 2.25, 1.3), WOOD_DARK)
	_box(_cabin, "RoofBack", Vector3(3.3, 0.12, 0.12), Vector3(0, 2.25, -1.3), WOOD_DARK)
	for x in [-1.4, 1.4]:
		_box(_cabin, "Post_%s" % str(x), Vector3(0.10, 2.1, 0.10), Vector3(x, 1.15, -1), WOOD_DARK)
	_box(_cabin, "Hanger", Vector3(0.14, 2.05, 0.14), Vector3(0, 3.3, 0), IRON)
	# The cliff and the wilderness beyond: rock face, hills, far mountains.
	_box(self, "CliffFace", Vector3(94, 9, 6), Vector3(0, -4.5, -112), Color(0.55, 0.47, 0.38))
	_box(self, "CliffFaceDark", Vector3(94, 8, 6), Vector3(0, -12, -113.5), Color(0.44, 0.38, 0.31))
	_scenery_hill(Vector3(-30, -6, -122), 18)
	_scenery_hill(Vector3(28, -7, -128), 20)
	_scenery_hill(Vector3(0, -10, -140), 24)
	_tree(Vector3(-30, 2.1, -122), 1.2)
	_tree(Vector3(28, 2.0, -128), 1.3)
	_tree(Vector3(0, 0.8, -140), 1.4)
	_mountain(Vector3(-42, 0, -138), 16, 22)
	_mountain(Vector3(40, 0, -145), 18, 24)
	_mountain(Vector3(10, 0, -155), 20, 26)

func _mountain(pos: Vector3, radius: float, height: float) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Mountain"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = radius
	cone.height = height
	mesh_node.mesh = cone
	mesh_node.material_override = _material(Color(0.47, 0.55, 0.46))
	mesh_node.position = pos + Vector3(0, height * 0.5, 0)
	add_child(mesh_node)
	var cap := MeshInstance3D.new()
	var cap_cone := CylinderMesh.new()
	cap_cone.top_radius = 0.2
	cap_cone.bottom_radius = radius * 0.35
	cap_cone.height = height * 0.22
	cap.mesh = cap_cone
	cap.material_override = _material(Color(0.92, 0.94, 0.95))
	cap.position = pos + Vector3(0, height * 0.92, 0)
	add_child(cap)

# ---------------------------------------------------------------- npcs

func _npc(id: String, title: String, pos: Vector3, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "NPC_" + id
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_interactable(body, id)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = height
	collider.shape = shape
	collider.position.y = height * 0.5
	body.add_child(collider)
	match id:
		"goat": _build_goat(body)
		"ox": _build_ox(body)
		"sheep": _build_sheep(body)
		"horse": _build_horse(body)
		"farmer": _build_farmer(body)
	body.rotation.y = PI if id != "horse" else PI * 0.5
	_label(body, "NameLabel", title, Vector3(0, height + 0.7, 0), 24)
	_npcs[id] = body
	_npc_origins[id] = pos

func _build_ox(body: Node3D) -> void:
	var hide := Color(0.55, 0.38, 0.25)
	var dark := Color(0.42, 0.28, 0.18)
	_box(body, "Body", Vector3(1.15, 0.95, 1.8), Vector3(0, 1.02, 0), hide)
	_box(body, "Head", Vector3(0.55, 0.58, 0.55), Vector3(0, 1.28, -1.1), hide)
	_box(body, "Snout", Vector3(0.4, 0.28, 0.18), Vector3(0, 1.14, -1.42), Color(0.84, 0.72, 0.62))
	_box(body, "HornL", Vector3(0.09, 0.34, 0.09), Vector3(-0.28, 1.62, -1.0), CREAM)
	_box(body, "HornR", Vector3(0.09, 0.34, 0.09), Vector3(0.28, 1.62, -1.0), CREAM)
	_box(body, "EarL", Vector3(0.2, 0.09, 0.14), Vector3(-0.4, 1.5, -0.95), dark)
	_box(body, "EarR", Vector3(0.2, 0.09, 0.14), Vector3(0.4, 1.5, -0.95), dark)
	for pos in [Vector3(-0.42, 0.29, -0.62), Vector3(0.42, 0.29, -0.62), Vector3(-0.42, 0.29, 0.62), Vector3(0.42, 0.29, 0.62)]:
		_box(body, "Leg", Vector3(0.26, 0.58, 0.26), pos, dark)
	_box(body, "Tail", Vector3(0.1, 0.7, 0.1), Vector3(0, 1.0, 0.95), dark)

func _build_sheep(body: Node3D) -> void:
	var wool := Color(0.94, 0.93, 0.88)
	var face := Color(0.35, 0.32, 0.30)
	_sphere(body, "Wool", 0.52, Vector3(0, 0.72, 0), wool)
	_sphere(body, "Head", 0.24, Vector3(0, 0.98, -0.58), face)
	_box(body, "EarL", Vector3(0.2, 0.07, 0.12), Vector3(-0.22, 1.08, -0.56), face)
	_box(body, "EarR", Vector3(0.2, 0.07, 0.12), Vector3(0.22, 1.08, -0.56), face)
	for pos in [Vector3(-0.22, 0.18, -0.3), Vector3(0.22, 0.18, -0.3), Vector3(-0.22, 0.18, 0.3), Vector3(0.22, 0.18, 0.3)]:
		_box(body, "Leg", Vector3(0.13, 0.36, 0.13), pos, face)

func _build_horse(body: Node3D) -> void:
	var coat := Color(0.38, 0.27, 0.19)
	var mane := Color(0.24, 0.17, 0.12)
	_box(body, "Body", Vector3(0.85, 0.85, 1.65), Vector3(0, 1.18, 0), coat)
	var neck := _box(body, "Neck", Vector3(0.34, 0.85, 0.38), Vector3(0, 1.75, -0.68), coat)
	neck.rotation.x = 0.45
	_box(body, "Head", Vector3(0.3, 0.36, 0.66), Vector3(0, 2.25, -1.0), coat)
	_box(body, "Mane", Vector3(0.12, 0.85, 0.2), Vector3(0, 1.85, -0.52), mane)
	_box(body, "Tail", Vector3(0.16, 0.75, 0.16), Vector3(0, 1.15, 0.9), mane)
	for pos in [Vector3(-0.3, 0.38, -0.55), Vector3(0.3, 0.38, -0.55), Vector3(-0.3, 0.38, 0.55), Vector3(0.3, 0.38, 0.55)]:
		_box(body, "Leg", Vector3(0.18, 0.76, 0.18), pos, coat)

func _build_goat(body: Node3D) -> void:
	var coat := Color(0.80, 0.79, 0.74)
	var horn := Color(0.62, 0.55, 0.42)
	_sphere(body, "Wool", 0.46, Vector3(0, 0.78, 0), coat)
	_sphere(body, "Head", 0.22, Vector3(0, 1.18, -0.52), coat)
	_box(body, "Beard", Vector3(0.1, 0.22, 0.1), Vector3(0, 1.0, -0.62), Color(0.7, 0.69, 0.64))
	var horn_l := _cylinder(body, "HornL", 0.02, 0.06, 0.4, Vector3(-0.13, 1.42, -0.42), horn)
	horn_l.rotation.x = -0.6
	var horn_r := _cylinder(body, "HornR", 0.02, 0.06, 0.4, Vector3(0.13, 1.42, -0.42), horn)
	horn_r.rotation.x = -0.6
	for pos in [Vector3(-0.2, 0.2, -0.28), Vector3(0.2, 0.2, -0.28), Vector3(-0.2, 0.2, 0.28), Vector3(0.2, 0.2, 0.28)]:
		_box(body, "Leg", Vector3(0.12, 0.4, 0.12), pos, Color(0.68, 0.67, 0.62))

func _build_farmer(body: Node3D) -> void:
	var denim := Color(0.32, 0.40, 0.52)
	var skin := Color(0.90, 0.72, 0.58)
	_box(body, "Legs", Vector3(0.52, 0.62, 0.34), Vector3(0, 0.31, 0), denim)
	_box(body, "Torso", Vector3(0.64, 0.66, 0.4), Vector3(0, 0.94, 0), denim)
	_box(body, "ArmL", Vector3(0.16, 0.5, 0.16), Vector3(-0.42, 0.98, 0), Color(0.62, 0.42, 0.30))
	_box(body, "ArmR", Vector3(0.16, 0.5, 0.16), Vector3(0.42, 0.98, 0), Color(0.62, 0.42, 0.30))
	_sphere(body, "Head", 0.25, Vector3(0, 1.52, 0), skin)
	_cylinder(body, "HatBrim", 0.30, 0.44, 0.07, Vector3(0, 1.7, 0), HAY)
	_cylinder(body, "HatTop", 0.24, 0.26, 0.24, Vector3(0, 1.84, 0), HAY)
	var prod := _cylinder(body, "Prod", 0.035, 0.035, 1.35, Vector3(0.46, 0.95, -0.2), Color(0.25, 0.27, 0.3))
	prod.rotation.x = -0.35

# ---------------------------------------------------------------- props & helpers

func _tree(pos: Vector3, scale_factor: float) -> void:
	var root := Node3D.new()
	root.name = "Tree"
	root.set_meta("environment_type", "tree")
	root.position = pos
	add_child(root)
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.18 * scale_factor
	cylinder.bottom_radius = 0.28 * scale_factor
	cylinder.height = 1.5 * scale_factor
	trunk.mesh = cylinder
	trunk.material_override = _material(Color(0.48, 0.35, 0.23))
	trunk.position.y = 0.75 * scale_factor
	root.add_child(trunk)
	if scale_factor > 0.9:
		var trunk_body := StaticBody3D.new()
		trunk_body.collision_layer = 1
		trunk_body.collision_mask = 0
		var trunk_col := CollisionShape3D.new()
		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = 0.3 * scale_factor
		trunk_shape.height = 1.6 * scale_factor
		trunk_col.shape = trunk_shape
		trunk_col.position.y = 0.8 * scale_factor
		trunk_body.add_child(trunk_col)
		root.add_child(trunk_body)
	var blob_positions := [
		Vector3(0, 1.9, 0), Vector3(0.5, 1.55, 0.25), Vector3(-0.45, 1.6, -0.2), Vector3(0.1, 2.3, -0.3),
	]
	for index in blob_positions.size():
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var radius := (0.75 - index * 0.09) * scale_factor
		sphere.radius = radius
		sphere.height = radius * 1.8
		blob.mesh = sphere
		blob.material_override = _material(LEAF if index % 2 == 0 else LEAF_LIGHT)
		blob.position = blob_positions[index] * scale_factor
		root.add_child(blob)
		# Apples on the bigger canopies.
		if index < 3 and scale_factor > 0.9:
			var apple := MeshInstance3D.new()
			var apple_sphere := SphereMesh.new()
			apple_sphere.radius = 0.1
			apple_sphere.height = 0.2
			apple.mesh = apple_sphere
			apple.material_override = _material(FLOWER_RED)
			apple.position = blob_positions[index] * scale_factor + Vector3(radius * 0.7, -radius * 0.2, radius * 0.5)
			root.add_child(apple)

func _bush(pos: Vector3, scale_factor: float) -> void:
	_sphere(self, "Bush", 0.55 * scale_factor, pos + Vector3(0, 0.42 * scale_factor, 0), LEAF_LIGHT)
	_sphere(self, "Bush2", 0.4 * scale_factor, pos + Vector3(0.35 * scale_factor, 0.3 * scale_factor, 0.15), LEAF)

func _flower_patch(pos: Vector3) -> void:
	var colors := [FLOWER_RED, FLOWER_YELLOW, FLOWER_WHITE]
	for index in 4:
		var angle := TAU * float(index) / 4.0 + pos.x
		var stem_pos := pos + Vector3(cos(angle) * 0.55, 0, sin(angle) * 0.55)
		_cylinder(self, "Stem", 0.02, 0.025, 0.26, stem_pos + Vector3(0, 0.13, 0), LEAF)
		_sphere(self, "Bloom", 0.08, stem_pos + Vector3(0, 0.3, 0), colors[index % 3])

func _sun_patch(pos: Vector3, size: float) -> void:
	_box(self, "SunPatch", Vector3(size, 0.025, size), Vector3(pos.x, 0.035, pos.z), Color(0.87, 0.83, 0.55))

func _hay_bale(pos: Vector3, scale_factor: float = 1.0) -> void:
	var body := _box(self, "HayBale", Vector3(1.7 * scale_factor, 0.9 * scale_factor, 1.15 * scale_factor), pos + Vector3(0, 0.45 * scale_factor, 0), HAY, true)
	_box(body, "Band", Vector3(1.74 * scale_factor, 0.12, 0.2), Vector3(0, 0.1, 0), Color(0.78, 0.62, 0.24))
	var art := ASSETS.replace_visuals(body, "ENV_06_HAY", Vector3(0, -0.45 * scale_factor, 0))
	if art: art.scale *= scale_factor

func _crate(pos: Vector3, size: float) -> void:
	var body := _box(self, "Crate", Vector3(size, size, size), pos + Vector3(0, size * 0.5, 0), WOOD, true)
	var art := ASSETS.replace_visuals(body, "ENV_06_CRATE", Vector3(0, -size * 0.5, 0))
	if art: art.scale *= size
	else: _box(self, "CrateLid", Vector3(size + 0.08, 0.1, size + 0.08), pos + Vector3(0, size + 0.02, 0), WOOD_DARK)

func _barrel(pos: Vector3) -> void:
	_cylinder(self, "Barrel", 0.42, 0.48, 1.1, pos + Vector3(0, 0.55, 0), WOOD_DARK, true)
	_cylinder(self, "BarrelBand", 0.5, 0.5, 0.08, pos + Vector3(0, 0.55, 0), IRON)

func _scarecrow(pos: Vector3) -> void:
	_box(self, "ScarecrowPole", Vector3(0.24, 1.9, 0.24), pos + Vector3(0, 0.95, 0), WOOD_DARK, true)
	_box(self, "ScarecrowArms", Vector3(1.3, 0.12, 0.12), pos + Vector3(0, 1.45, 0), WOOD)
	_box(self, "ScarecrowShirt", Vector3(0.7, 0.6, 0.3), pos + Vector3(0, 1.25, 0), Color(0.62, 0.42, 0.30))
	_sphere(self, "ScarecrowHead", 0.24, pos + Vector3(0, 1.95, 0), HAY)
	_cylinder(self, "ScarecrowHat", 0.02, 0.3, 0.32, pos + Vector3(0, 2.25, 0), BARN_RED)

func _farm_cart(pos: Vector3) -> void:
	var body := _box(self, "CartBed", Vector3(2.5, 0.35, 1.6), pos + Vector3(0, 0.7, 0), WOOD, true)
	_box(body, "CartSideL", Vector3(0.1, 0.45, 1.6), Vector3(0, 0.4, -0.75), WOOD_DARK)
	_box(body, "CartSideR", Vector3(0.1, 0.45, 1.6), Vector3(0, 0.4, 0.75), WOOD_DARK)
	_box(body, "CartSideB", Vector3(2.5, 0.45, 0.1), Vector3(0, 0.4, 0), WOOD_DARK)
	for x in [-1.25, 1.25]:
		var wheel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.55
		cylinder.bottom_radius = 0.55
		cylinder.height = 0.14
		wheel.mesh = cylinder
		wheel.material_override = _material(WOOD_DARK)
		wheel.rotation.z = PI * 0.5
		wheel.position = Vector3(x, -0.15, 0.45)
		body.add_child(wheel)
	_box(body, "CartLoad", Vector3(1.8, 0.5, 1.2), Vector3(0, 0.45, 0), HAY)

func _trough(pos: Vector3) -> void:
	var body := _box(self, "Trough", Vector3(1.8, 0.42, 0.9), pos + Vector3(0, 0.21, 0), Color(0.52, 0.60, 0.62), true)
	ASSETS.replace_visuals(body, "ENV_01_TROUGH", Vector3(0, -0.21, 0))
	_box(self, "TroughWater", Vector3(1.4, 0.03, 0.53), pos + Vector3(0, 0.32, 0), WATER)

func _build_wilderness_wheat() -> void:
	# One instanced mesh supplies the golden horizon below the cablecar route.
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.02
	stalk.bottom_radius = 0.04
	stalk.height = 1.25
	stalk.radial_segments = 5
	stalk.rings = 1
	stalk.material = _material(Color("F5BE52"))
	var ears := CylinderMesh.new()
	ears.top_radius = 0.04
	ears.bottom_radius = 0.11
	ears.height = 0.38
	ears.radial_segments = 5
	ears.rings = 1
	ears.material = _material(Color("F59E0B"))
	var terrain := SurfaceTool.new()
	terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 24:
		for column in 40:
			var x := -48.0 + column * 2.4
			var z := -116.0 - row * 1.8
			var corners := [Vector2(x, z), Vector2(x + 2.4, z), Vector2(x, z - 1.8), Vector2(x + 2.4, z - 1.8)]
			terrain.set_color(Color("DDAA4B") if row % 5 < 2 else Color("E8BA59"))
			for index in [0, 1, 2, 2, 1, 3]:
				var point: Vector2 = corners[index]
				terrain.add_vertex(Vector3(point.x, _wheat_surface_height(point.x, point.y), point.y))
	terrain.generate_normals()
	var field := MeshInstance3D.new()
	field.name = "GoldenFields"
	field.mesh = terrain.commit()
	var field_material := _material(Color.WHITE)
	field_material.vertex_color_use_as_albedo = true
	field_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	field.material_override = field_material
	add_child(field)
	var count := 3200
	for mesh in [stalk, ears]:
		var batch := MultiMeshInstance3D.new()
		batch.name = "GoldenWheat"
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = count
		batch.multimesh = multimesh
		add_child(batch)
		for i in count:
			var x := -46.0 + float(i % 80) * 1.16
			var z := -117.0 - float(i / 80) * 1.02
			var wave := sin(x * 0.11 + z * 0.1)
			var y := _wheat_surface_height(x, z) + 0.6 + (0.78 if mesh == ears else 0.0)
			var tilt := Basis.from_euler(Vector3(0, float(i) * 0.7, 0.08 * wave))
			multimesh.set_instance_transform(i, Transform3D(tilt, Vector3(x, y, z)))

func _wheat_surface_height(x: float, z: float) -> float:
	var height := -7.0
	for hill in [Vector4(-30, -6, -122, 18), Vector4(28, -7, -128, 20), Vector4(0, -10, -140, 24)]:
		var radius: float = hill.w * 1.4
		var distance_squared := (Vector2(x, z) - Vector2(hill.x, hill.z)).length_squared() / (radius * radius)
		if distance_squared < 1.0:
			height = maxf(height, hill.y + sqrt(1.0 - distance_squared) * hill.w * 0.225)
	return height + 0.06

func _plow(pos: Vector3) -> void:
	_box(self, "PlowBeam", Vector3(0.22, 0.22, 1.9), pos + Vector3(0, 0.5, 0), WOOD, true)
	_box(self, "PlowHandle", Vector3(0.14, 1.1, 0.14), pos + Vector3(0, 0.85, 0.8), WOOD)
	_box(self, "PlowBlade", Vector3(0.5, 0.55, 0.16), pos + Vector3(0, 0.3, -0.95), Color(0.45, 0.47, 0.5))

func _signpost(text: String, pos: Vector3) -> void:
	_cylinder(self, "SignPost", 0.07, 0.09, 1.3, pos + Vector3(0, 0.65, 0), WOOD)
	_box(self, "SignBoard", Vector3(0.08, 0.55, 1.15), pos + Vector3(0, 1.25, 0), WOOD_DARK)
	_label(self, "SignLabel", text, pos + Vector3(0, 1.95, 0), 20)

func _interactable(body: StaticBody3D, id: String) -> void:
	body.add_to_group("interactable")
	body.set_meta("interaction_id", id)

func _fence(parent: Node3D, from: Vector3, to: Vector3, solid: bool = false) -> void:
	var run := to - from
	run.y = 0
	var length := Vector2(run.x, run.z).length()
	if length < 0.1:
		return
	var mid := (from + to) * 0.5
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root = body
	else:
		root = Node3D.new()
	root.name = "Fence"
	root.set_meta("environment_type", "fence")
	root.position = Vector3(mid.x, 0, mid.z)
	root.rotation.y = atan2(run.x, run.z)
	parent.add_child(root)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.35, 1.3, length)
		collider.shape = shape
		collider.position.y = 0.65
		root.add_child(collider)
	var posts := maxi(2, int(ceil(length / 2.6)) + 1)
	for index in posts:
		var z := -length * 0.5 + length * float(index) / float(posts - 1)
		_box(root, "Post", Vector3(0.16, 0.95, 0.16), Vector3(0, 0.475, z), WHITE)
	for y in [0.34, 0.72]:
		_box(root, "Rail", Vector3(0.07, 0.12, length), Vector3(0, y, 0), WHITE)

func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color, solid: bool = false) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root = body
	else:
		root = Node3D.new()
	root.name = node_name
	root.set_meta("blockout_name", node_name)
	root.position = pos
	parent.add_child(root)
	var mesh := MeshInstance3D.new()
	mesh.name = "VisualMesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	root.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root

func _cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color, solid: bool = false) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root = body
	else:
		root = Node3D.new()
	root.name = node_name
	root.set_meta("blockout_name", node_name)
	root.position = pos
	parent.add_child(root)
	var mesh := MeshInstance3D.new()
	mesh.name = "VisualMesh"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	mesh.mesh = cylinder
	mesh.material_override = _material(color)
	root.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := CylinderShape3D.new()
		shape.radius = (top_radius + bottom_radius) * 0.5
		shape.height = height
		collision.shape = shape
		root.add_child(collision)
	return root

func _sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.set_meta("blockout_name", node_name)
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = _material(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _scenery_hill(pos: Vector3, radius: float) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Hill"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius
	sphere.radial_segments = 24
	sphere.rings = 12
	mesh_node.mesh = sphere
	mesh_node.material_override = _material(Color(0.43, 0.55, 0.35))
	mesh_node.scale = Vector3(1.4, 0.45, 1.4)
	mesh_node.position = pos
	add_child(mesh_node)

func _label(parent: Node3D, node_name: String, text: String, pos: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = CREAM
	label.outline_modulate = Color(0.26, 0.30, 0.22)
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)
	return label

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic_specular = 0.0
	return material

func _set_barrier(body: StaticBody3D, open: bool) -> void:
	if not is_instance_valid(body):
		return
	body.visible = not open
	body.set_deferred("collision_layer", 0 if open else 1)
	var collision := body.get_node("CollisionShape3D") as CollisionShape3D
	collision.set_deferred("disabled", open)

func _on_chase_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		chase_entered.emit()
