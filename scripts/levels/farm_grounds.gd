extends Node3D
## Gameplay roots and interaction state. Terrain is baked from farm_layout.gd.
signal chase_entered
signal chase_triggered(stage_id: String)
signal stage_chase_completed(gate_id: String)
signal secret_pipe_entered(course_id: String)
const ASSETS = preload("res://scripts/art/asset_library.gd")
const L = preload("res://scripts/levels/farm_layout.gd")
const SPAWN := L.SPAWN
const RETRY_POSITION := L.RETRY
const CABLECAR_TRAVEL := L.TRAVEL
const CREAM := Color("E1DDC5")
var _gate: StaticBody3D
var _pigpen_gate: StaticBody3D
var _ox_gate: StaticBody3D
var _sheep_gate: StaticBody3D
var _horse_gate: StaticBody3D
var _named_gates: Dictionary = {}
var _gate_labels: Dictionary = {}
var _cabin: Node3D
var _npcs: Dictionary = {}
var _npc_origins: Dictionary = {}
var _npc_tweens: Dictionary = {}
var _gate_label: Label3D
var _gate_art: Node3D
var _gate_tween: Tween
var _sheep_tag: Node3D
var _farmer_baton: Node3D
var _checkpoint := SPAWN
var recoveries := 0
var _player: Node3D

func _ready() -> void:
	add_to_group("farm_world")
	_install_environment()
	var titles := {"goat":"老岩羊", "ox":"老牛", "sheep":"小羊", "horse":"追风", "farmer":"农场主"}
	var assets := {"goat":"CHAR_02", "ox":"CHAR_03", "sheep":"CHAR_04", "horse":"CHAR_05", "farmer":"CHAR_07"}
	for id in L.NPCS:
		var body := _interaction("NPC_"+id,id,L.NPCS[id],Vector3(.85,1.2,.85))
		body.get_node("CollisionShape3D").position.y = .6
		body.add_child(ASSETS.make(assets[id]))
		body.rotation.y = PI
		_label(body,"NameLabel",titles[id],Vector3(0,2.2,0),24)
		_npcs[id]=body
		_npc_origins[id]=body.position
	_gate = _box(self,"Gate",Vector3(4.9,2.6,.65),L.GATE+Vector3.UP*1.3,Color("515A5A"),true)
	_gate_art = ASSETS.replace_visuals(_gate,"PROP_02",Vector3(0,-1.3,0))
	_gate_label = _label(_gate,"GateLabel","铁门 / LOCKED",Vector3(0,1.6,0),24)
	_named_gates["final"] = _gate
	_gate_labels["final"] = _gate_label

	_pigpen_gate = _box(self,"PigpenGate",Vector3(4.4,1.5,.3),L.PIG_GATE+Vector3.UP*.75,Color("9C805E"),true)
	var insert := get_node("PastoralEnvironment/PigpenGateInsert") as MeshInstance3D
	var timber := MeshInstance3D.new()
	timber.name="TimberGate"
	timber.mesh=insert.mesh
	timber.position.y=-.15
	_pigpen_gate.add_child(timber)
	_pigpen_gate.get_node("VisualMesh").hide()
	_named_gates["pigpen"] = _pigpen_gate

	_build_all_gates()
	_build_road_obstacles()
	_cabin=Node3D.new()
	_cabin.name="CableCarCabin"
	add_child(_cabin)
	_cabin.position=L.STATION
	_cabin.add_child(ASSETS.make("PROP_01"))
	var lever := _interaction("CablecarLever","cablecar",L.LEVER+Vector3.UP*.4,Vector3(.65,.8,.65))
	_box(lever,"LeverPost",Vector3(.2,.8,.2),Vector3.ZERO,Color("9C805E"))
	_box(lever,"LeverHandle",Vector3(.6,.12,.12),Vector3.UP*.45,Color("A96550"))
	_label(lever,"LeverLabel","E · 启动索道",Vector3(0,1.2,0),22)
	var board := _interaction("RecordBoard","record_board",Vector3(24,8,-106),Vector3(1.7,2,.6))
	board.get_node("CollisionShape3D").position.y=1
	board.add_child(ASSETS.make("PROP_06"))
	_label(board,"BoardText","50 米直道 / 春季纪录 · 35 秒",Vector3(0,2.5,0),22)
	_prop("PROP_04",Vector3(38,24,37.5))
	_prop("ENV_06_TRACTOR",Vector3(-54,2,-170))
	_sheep_tag=ASSETS.make("PROP_05")
	_npcs.sheep.add_child(_sheep_tag)
	_sheep_tag.position=Vector3(0,.35,-.86)
	ASSETS.attach_to_bone(_npcs.sheep.get_node("CHAR_04"),"Head",_sheep_tag,_sheep_tag.position)
	_farmer_baton=ASSETS.make("PROP_07")
	_npcs.farmer.add_child(_farmer_baton)
	_farmer_baton.position=Vector3(.43,.83,-.1)
	ASSETS.attach_to_bone(_npcs.farmer.get_node("CHAR_07"),"ArmL",_farmer_baton,_farmer_baton.position)
	_area("ChaseEntry",L.path("chase")[0]+Vector3.UP,Vector3(7,3,6),_on_chase_entered)
	_area("ChaseTrigger_1", Vector3(0, 31, 78) + Vector3.UP, Vector3(6, 4, 6), _on_stage_chase_trigger.bind("chase_1"))
	_area("ChaseTrigger_2", Vector3(72, 23, 8) + Vector3.UP, Vector3(6, 4, 6), _on_stage_chase_trigger.bind("chase_2"))
	_area("ChaseTrigger_3", Vector3(-66, 15, -76) + Vector3.UP, Vector3(6, 4, 6), _on_stage_chase_trigger.bind("chase_3"))
	for point in L.journey():
		_area("TrailCheckpoint", point + Vector3.UP * 1.5, Vector3(14, 6, 14), _on_checkpoint.bind(point))
	var signs := [[Vector3(2,32,89),"沿山路下行 → 牛的耕地"],[Vector3(-50,25,101),"空格 · 跳过倒木"],[Vector3(54,22,2),"溪桥缺口 · 空格跳跃"],[Vector3(72,24,23),"下坡 → 羊棚草甸"],[Vector3(-63,16,-59),"林间山路 → 马场"],[Vector3(-4,8,-134),"前方犬队巡逻 · 顺路突围"],[Vector3(-79,2,-237),"索道在林后 · 沿路转弯"]]
	for sign_data in signs:
		_box(self,"TrailSignPost",Vector3(.14,1.3,.14),sign_data[0]+Vector3.UP*.65,Color("665A48"))
		_label(self,"TrailSign",sign_data[1],sign_data[0]+Vector3.UP*1.7,21)
	for i in range(1,L.path("chase").size()-1):
		var point: Vector3=L.path("chase")[i]
		_label(self,"EscapeMarker","◆ 突围 %d" % i,point+Vector3(0,2.4,0),20)
	_build_secret_mario_pipe()
	reset_world()

func _install_environment() -> void:
	var environment: Node3D
	if not "--rebuild-environment" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://assets/environments/pastoral_farm.scn"):
		environment=load("res://assets/environments/pastoral_farm.scn").instantiate()
		if environment.get_meta("layout_version",0)!=4:
			environment.free()
			environment=null
	if environment==null:
		environment=preload("res://scripts/art/mountain_environment.gd").new()
		add_child(environment)
		environment.build(self)
	else: add_child(environment)
	preload("res://scripts/art/dressing_batches.gd").restore(environment)

func _interaction(node_name: String,id: String,p: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.name=node_name
	body.position=p
	body.collision_layer=1
	body.collision_mask=0
	body.set_meta("interaction_id",id)
	body.add_to_group("interactable")
	var shape:=CollisionShape3D.new()
	shape.name="CollisionShape3D"
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	add_child(body)
	return body

func _prop(id: String,p: Vector3) -> void:
	var art:=ASSETS.make(id)
	if art:
		add_child(art)
		art.position=p

func _area(label: String,p: Vector3,size: Vector3,callback: Callable) -> void:
	var area:=Area3D.new()
	area.name=label
	area.position=p
	area.collision_layer=0
	area.collision_mask=2
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(callback)

func _on_checkpoint(body: Node3D,point: Vector3) -> void:
	if body.is_in_group("player") and body.control_mode in ["explore","chase"]:
		_checkpoint=point+Vector3.UP*.1

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player): _player=get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player) or not _player.control_mode in ["explore","chase"]: return
	var closest := L.closest_on_path(_player.global_position, L.journey())
	if _player.global_position.distance_to(closest.point) < 14.0:
		_checkpoint = closest.point + Vector3.UP * 0.1
	if _player.global_position.y < closest.point.y - 7.5 or _player.global_position.y < -5.0:
		recoveries += 1
		_player.reset_at(_checkpoint)

func get_spawn_position() -> Vector3: return to_global(SPAWN)
func get_cablecar() -> Node3D: return _cabin

func click_path(from: Vector3,to: Vector3) -> Array[Vector3]:
	# Inside a meadow the player can choose their own line. Between terraces,
	# follow the road graph so a click never sends the pig through a cliff.
	for terrace in L.TERRACES:
		var c: Vector3=terrace.center
		var half: Vector2=terrace.half
		if absf(from.y-c.y)<2 and absf(to.y-c.y)<2 and absf(from.x-c.x)<half.x and absf(to.x-c.x)<half.x and absf(from.z-c.z)<half.y and absf(to.z-c.z)<half.y:
			return [to]
	var trail:=L.journey()
	# Remove duplicated connection points before projecting onto segments.
	var points: Array[Vector3]=[]
	for p in trail:
		if points.is_empty() or points[-1].distance_to(p)>.1: points.append(p)
	var a:=L.closest_on_path(from,points)
	var b:=L.closest_on_path(to,points)
	var result: Array[Vector3]=[]
	if a.index==b.index: return [to]
	result.append(a.point)
	if a.progress<b.progress:
		for i in range(a.index+1,b.index+1): result.append(points[i])
	else:
		for i in range(a.index,b.index,-1): result.append(points[i])
	result.append(b.point)
	result.append(to)
	return result

func set_npc_completed(id: String) -> void:
	if not _npcs.has(id): return
	if id=="sheep": _sheep_tag.hide()
	if _npc_tweens.has(id) and is_instance_valid(_npc_tweens[id]): _npc_tweens[id].kill()
	if L.RESTS.has(id):
		var tween:=create_tween()
		tween.tween_property(_npcs[id],"position",L.RESTS[id],.8)
		_npc_tweens[id]=tween

func reset_world() -> void:
	for tween in _npc_tweens.values():
		if is_instance_valid(tween): tween.kill()
	_npc_tweens.clear()
	for id in _npc_origins: _npcs[id].position=_npc_origins[id]
	_sheep_tag.show()
	_farmer_baton.show()
	set_gate_open(false)
	set_pigpen_open(false)
	set_named_gate_open("ox", true)
	set_named_gate_open("sheep", true)
	set_named_gate_open("horse", true)
	_cabin.position=L.STATION
	_checkpoint=SPAWN
	recoveries=0

func _material(color: Color) -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=preload("res://scripts/art/pastoral_surface.gdshader")
	material.set_shader_parameter("vertex_palette",false)
	material.set_shader_parameter("pigment",color)
	return material

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

func _on_stage_chase_trigger(body: Node3D, stage_id: String) -> void:
	if body.is_in_group("player"):
		chase_triggered.emit(stage_id)

func _build_all_gates() -> void:
	# Build Ox Gate at OxTerrace entrance
	_ox_gate = _create_timber_gate("ox", L.GATE_OX + Vector3.UP * 0.9, Vector3(4.8, 1.8, 0.4), "牛耕地门 · OX GATE")
	_named_gates["ox"] = _ox_gate
	_area("GateOxTrigger", L.GATE_OX + Vector3(3.5, 1.0, 0), Vector3(3.5, 3.0, 3.5), _on_gate_passed.bind("ox"))

	# Build Sheep Gate at SheepMeadow entrance
	_sheep_gate = _create_timber_gate("sheep", L.GATE_SHEEP + Vector3.UP * 0.9, Vector3(4.8, 1.8, 0.4), "羊棚木门 · SHEEP GATE")
	_named_gates["sheep"] = _sheep_gate
	_area("GateSheepTrigger", L.GATE_SHEEP + Vector3(-3.5, 1.0, 0), Vector3(3.5, 3.0, 3.5), _on_gate_passed.bind("sheep"))

	# Build Horse Gate at HorsePasture entrance
	_horse_gate = _create_timber_gate("horse", L.GATE_HORSE + Vector3.UP * 0.9, Vector3(4.8, 1.8, 0.4), "马场围栏 · HORSE GATE")
	_named_gates["horse"] = _horse_gate
	_area("GateHorseTrigger", L.GATE_HORSE + Vector3(3.5, 1.0, 0), Vector3(3.5, 3.0, 3.5), _on_gate_passed.bind("horse"))

func _create_timber_gate(id: String, pos: Vector3, size: Vector3, label_text: String) -> StaticBody3D:
	var gate := _box(self, "Gate_" + id, size, pos, Color("7A6345"), true) as StaticBody3D
	# Posts on both sides
	var post_color := Color("5A4730")
	var post_left := _box(gate, "PostL", Vector3(0.35, size.y * 1.25, 0.35), Vector3(-size.x * 0.5, 0, 0), post_color)
	var post_right := _box(gate, "PostR", Vector3(0.35, size.y * 1.25, 0.35), Vector3(size.x * 0.5, 0, 0), post_color)
	# Upper crossbeam
	var beam := _box(gate, "BeamTop", Vector3(size.x * 1.05, 0.2, 0.25), Vector3(0, size.y * 0.6, 0), post_color)
	
	# Gate leaves (turnable)
	var leaf_l := _box(gate, "LeafL", Vector3(size.x * 0.46, size.y * 0.85, 0.12), Vector3(-size.x * 0.24, 0, 0), Color("91744C"))
	var leaf_r := _box(gate, "LeafR", Vector3(size.x * 0.46, size.y * 0.85, 0.12), Vector3(size.x * 0.24, 0, 0), Color("876B46"))
	leaf_l.get_node("VisualMesh").position.z = 0.05
	leaf_r.get_node("VisualMesh").position.z = 0.05
	
	var label := _label(gate, "GateLabel_" + id, label_text + " / LOCKED", Vector3(0, size.y * 0.9, 0), 20)
	_gate_labels[id] = label
	return gate

func _build_road_obstacles() -> void:
	# Summit road logs aligned with L.LOGS[0]
	var log_pos_1: Vector3 = L.LOGS[0].a.lerp(L.LOGS[0].b, L.LOGS[0].t)
	var log1 := _box(self, "Log_Summit_1", Vector3(3.6, 0.55, 0.55), log_pos_1 + Vector3.UP * 0.25, Color("5A442E"), true)
	var hay1 := _box(self, "Hay_Summit_Side", Vector3(1.6, 0.75, 1.6), Vector3(-49, 24.3, 85), Color("C9A35E"), true)

	# Creek road logs aligned with creek bridge / L.LOGS
	var hurdle1 := _box(self, "Hurdle_Creek_Side", Vector3(2.5, 0.65, 0.25), Vector3(48, 22.2, 3), Color("8B6846"), true)
	var rock1 := _box(self, "Rock_Creek_Side", Vector3(2.2, 0.6, 0.8), Vector3(14, 20.2, 6), Color("6C7A72"), true)

	# Woodland road logs aligned with L.LOGS[1]
	var log_pos_2: Vector3 = L.LOGS[1].a.lerp(L.LOGS[1].b, L.LOGS[1].t)
	var log2 := _box(self, "Log_Woodland_1", Vector3(3.6, 0.55, 0.55), log_pos_2 + Vector3.UP * 0.25, Color("4D3A27"), true)
	var cart1 := _box(self, "Cart_Woodland_Side", Vector3(1.8, 0.7, 1.2), Vector3(-44, 14.2, -84), Color("6B523A"), true)

func set_named_gate_open(gate_id: String, open: bool) -> void:
	var gate: StaticBody3D = _named_gates.get(gate_id, null)
	if not is_instance_valid(gate): return
	_set_barrier(gate, open)
	var label: Label3D = _gate_labels.get(gate_id, null)
	if is_instance_valid(label):
		label.text = label.text.split(" / ")[0] + (" / OPEN" if open else " / LOCKED")
	var leaf_l := gate.find_child("LeafL", true, false) as Node3D
	var leaf_r := gate.find_child("LeafR", true, false) as Node3D
	if leaf_l and leaf_r:
		var tween := create_tween().set_parallel(true)
		var angle := 1.45 if open else 0.0
		tween.tween_property(leaf_l, "rotation:y", angle, 0.5)
		tween.tween_property(leaf_r, "rotation:y", -angle, 0.5)

func _on_gate_passed(body: Node3D, gate_id: String) -> void:
	if body.is_in_group("player"):
		var main_loop := Engine.get_main_loop() as SceneTree
		var gm = main_loop.root.get_node_or_null("GameManager") if main_loop and main_loop.root else null
		var in_chase: bool = gm.is_in_chase() if gm and gm.has_method("is_in_chase") else false
		if in_chase:
			# When the player races across the gate during chase, slam it shut!
			set_named_gate_open(gate_id, false)
			stage_chase_completed.emit(gate_id)

func _build_secret_mario_pipe() -> void:
	var pipe_root := Node3D.new()
	pipe_root.name = "SecretMarioPipe"
	# Placed off-trail on the scenic northern cliff branch (leaves main trail unobstructed)
	var pipe_pos := Vector3(-6, 30.2, 64)
	pipe_root.position = pipe_pos
	add_child(pipe_root)

	# Branch walkway connecting trail to the scenic pipe overlook
	_box(pipe_root, "BranchWalkway", Vector3(2.6, 0.35, 7.0), Vector3(-1.5, 0.18, 4.5), Color("8D7B68"), true)
	# Platform under the pipe
	_box(pipe_root, "PipePlatform", Vector3(3.6, 0.4, 3.6), Vector3(0, 0.2, 0), Color("8D7B68"), true)
	_label(self, "BranchSign", "▶ 悬崖支路：神秘绿水管", Vector3(-9.5, 31.6, 73), 18)

	# Green pipe body
	var body_mesh := MeshInstance3D.new()
	var body_cyl := CylinderMesh.new()
	body_cyl.top_radius = 1.05
	body_cyl.bottom_radius = 1.05
	body_cyl.height = 1.3
	body_mesh.mesh = body_cyl
	body_mesh.position.y = 0.85
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color("2E7D32")
	pipe_mat.roughness = 0.5
	body_mesh.material_override = pipe_mat
	pipe_root.add_child(body_mesh)

	# Pipe rim flange
	var rim_mesh := MeshInstance3D.new()
	var rim_cyl := CylinderMesh.new()
	rim_cyl.top_radius = 1.25
	rim_cyl.bottom_radius = 1.25
	rim_cyl.height = 0.35
	rim_mesh.mesh = rim_cyl
	rim_mesh.position.y = 1.45
	rim_mesh.material_override = pipe_mat
	pipe_root.add_child(rim_mesh)

	# Dark interior hole
	var hole_mesh := MeshInstance3D.new()
	var hole_cyl := CylinderMesh.new()
	hole_cyl.top_radius = 0.95
	hole_cyl.bottom_radius = 0.95
	hole_cyl.height = 0.05
	hole_mesh.mesh = hole_cyl
	hole_mesh.position.y = 1.62
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_color = Color("0A150A")
	hole_mesh.material_override = hole_mat
	pipe_root.add_child(hole_mesh)

	# Floating sign & labels
	_label(pipe_root, "PipeSign", "★ 神秘绿水管 · 隐藏捷径 ★", Vector3(0, 3.2, 0), 24)
	_label(pipe_root, "PipeHint", "（按空格跳入 · 糖豆人试炼）", Vector3(0, 2.5, 0), 18)

	# Pipe Trigger Area
	var pipe_area := Area3D.new()
	pipe_area.name = "SecretPipeArea"
	pipe_area.collision_layer = 0
	pipe_area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.2, 2.4)
	shape.shape = box
	shape.position.y = 1.6
	pipe_area.add_child(shape)
	pipe_area.body_entered.connect(_on_secret_pipe_body_entered)
	pipe_root.add_child(pipe_area)

func _on_secret_pipe_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		secret_pipe_entered.emit("course_1")
