extends Node3D
## Gameplay roots and interaction state. Terrain is baked from farm_layout.gd.
signal chase_entered
const ASSETS = preload("res://scripts/art/asset_library.gd")
const L = preload("res://scripts/levels/farm_layout.gd")
const SPAWN := L.SPAWN
const RETRY_POSITION := L.RETRY
const CABLECAR_TRAVEL := L.TRAVEL
const CREAM := Color("E1DDC5")
var _gate: StaticBody3D
var _pigpen_gate: StaticBody3D
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
	_pigpen_gate = _box(self,"PigpenGate",Vector3(4.4,1.5,.3),L.PIG_GATE+Vector3.UP*.75,Color("9C805E"),true)
	var insert := get_node("PastoralEnvironment/PigpenGateInsert") as MeshInstance3D
	var timber := MeshInstance3D.new()
	timber.name="TimberGate"
	timber.mesh=insert.mesh
	timber.position.y=-.15
	_pigpen_gate.add_child(timber)
	_pigpen_gate.get_node("VisualMesh").hide()
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
	for point in L.journey():
		_area("TrailCheckpoint",point+Vector3.UP,Vector3(4,3,4),_on_checkpoint.bind(point))
	var signs := [[Vector3(2,32,89),"沿山路下行 → 牛的耕地"],[Vector3(-50,25,101),"空格 · 跳过倒木"],[Vector3(54,22,2),"溪桥缺口 · 空格跳跃"],[Vector3(72,24,23),"下坡 → 羊棚草甸"],[Vector3(-63,16,-59),"林间山路 → 马场"],[Vector3(-4,8,-134),"前方犬队巡逻 · 顺路突围"],[Vector3(-79,2,-237),"索道在林后 · 沿路转弯"]]
	for sign_data in signs:
		_box(self,"TrailSignPost",Vector3(.14,1.3,.14),sign_data[0]+Vector3.UP*.65,Color("665A48"))
		_label(self,"TrailSign",sign_data[1],sign_data[0]+Vector3.UP*1.7,21)
	for i in range(1,L.path("chase").size()-1):
		var point: Vector3=L.path("chase")[i]
		_label(self,"EscapeMarker","◆ 突围 %d" % i,point+Vector3(0,2.4,0),20)
	reset_world()

func _install_environment() -> void:
	var environment: Node3D
	if not "--rebuild-environment" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://assets/environments/pastoral_farm.scn"):
		environment=load("res://assets/environments/pastoral_farm.scn").instantiate()
		if environment.get_meta("layout_version",0)!=3:
			environment.free()
			environment=null
	if environment==null:
		environment=preload("res://scripts/art/mountain_environment.gd").new()
		add_child(environment)
		environment.build(self)
	else: add_child(environment)

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
	if _player.global_position.y < _checkpoint.y-4.5:
		if _player.control_mode=="chase":
			var level:=get_parent()
			if level.get("chase"): level.chase.fail_course()
		else:
			recoveries+=1
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
