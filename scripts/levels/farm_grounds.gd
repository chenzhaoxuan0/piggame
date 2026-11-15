extends Node3D
## Gameplay roots and interaction state. Terrain is baked from farm_layout.gd.
signal chase_entered
signal chase_triggered(stage_id: String)
signal stage_chase_completed(gate_id: String)
signal secret_pipe_entered(course_id: String)
signal playground_event(kind: String, detail)
const ASSETS = preload("res://scripts/art/asset_library.gd")
const PLAYTHING = preload("res://scripts/levels/farm_plaything.gd")
const L = preload("res://scripts/levels/farm_layout.gd")
const SPAWN := L.SPAWN
const RETRY_POSITION := L.RETRY
const CABLECAR_TRAVEL := L.TRAVEL
const CREAM := Color("E1DDC5")
const NPC_TITLES := {"goat": "老岩羊", "ox": "老牛", "sheep": "小羊", "horse": "追风", "farmer": "农场主"}
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
var _player_on_pipe := false
var _pipe_entering := false
var _current_pipe_id := "course_1"
var _current_pipe_node: Node3D = null
var _current_hint_label: Label3D = null
var _pipe_hint_label: Label3D

func _ready() -> void:
	add_to_group("farm_world")
	_install_environment()
	var titles := NPC_TITLES
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

	# The pigpen trough: the tutorial's one true interactable (拱食槽 gag +
	# trough_sniff achievement - it used to live in the floating boot pen).
	var trough := _interaction("PigpenTrough", "trough", Vector3(3.6, 32.35, 96.5), Vector3(1.8, 0.7, 0.9))
	trough.get_node("CollisionShape3D").position.y = 0.35
	var trough_mesh := MeshInstance3D.new()
	var trough_box := BoxMesh.new()
	trough_box.size = Vector3(1.8, 0.7, 0.9)
	trough_mesh.mesh = trough_box
	var trough_mat := StandardMaterial3D.new()
	trough_mat.albedo_color = Color("8F6A42")
	trough_mat.roughness = 0.9
	trough_mesh.material_override = trough_mat
	trough_mesh.position.y = 0.35
	trough.add_child(trough_mesh)
	# The stone trough model (ENV_01_TROUGH, 1.8 x 0.9 x 0.42 m) is the visual;
	# the box keeps the collision. Same model the art line tagged 猪圈和赛道复用.
	var trough_art := ASSETS.make("ENV_01_TROUGH")
	if trough_art != null:
		trough_mesh.visible = false
		trough.add_child(trough_art)
	_label(trough, "TroughLabel", "食槽 · 按 F / E / K 拱一下", Vector3(0, 1.5, 0), 20)

	_build_all_gates()
	_build_road_obstacles()
	_build_playground()
	_build_cabbage_field()
	_cabin=Node3D.new()
	_cabin.name="CableCarCabin"
	add_child(_cabin)
	_cabin.position=L.STATION
	_cabin.add_child(ASSETS.make("PROP_01"))
	var lever := _interaction("CablecarLever","cablecar",L.LEVER+Vector3.UP*.4,Vector3(.65,.8,.65))
	_box(lever,"LeverPost",Vector3(.2,.8,.2),Vector3.ZERO,Color("9C805E"))
	_box(lever,"LeverHandle",Vector3(.6,.12,.12),Vector3.UP*.45,Color("A96550"))
	# Lux3D PROP_22_CABLECAR_LEVER draws post + brake arm as one model.
	if _mount_lux(lever, "PROP_22_CABLECAR_LEVER", Vector3(0.65, 0.8, 0.65), "LeverLux") != null:
		lever.get_node("LeverPost/VisualMesh").visible = false
		lever.get_node("LeverHandle/VisualMesh").visible = false
	_label(lever,"LeverLabel","E · 启动索道",Vector3(0,1.2,0),22)
	# Record board faces the horse track from the north-east (the old spot stood
	# in the middle of the gate-to-court walking lane).
	var board := _interaction("RecordBoard","record_board",Vector3(55,8,-103),Vector3(1.7,2,.6))
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
	# Trail signs stand clear of the roadside fences (the jump-log and cablecar
	# signs used to skewer the summit/escape fence lines). The last two mark the
	# rocky fence gaps into the ox terrace: the descent road and the terrace
	# share ground there, so the broken fence section reads as a real shortcut.
	var signs := [[Vector3(2,32,89),"沿山路下行 → 牛的耕地"],[Vector3(-58.5,25,100),"空格 · 跳过倒木"],[Vector3(54,22,2),"溪桥缺口 · 空格跳跃"],[Vector3(72,24,23),"下坡 → 羊棚草甸"],[Vector3(-63,16,-59),"林间山路 → 马场"],[Vector3(-4,8,-134),"前方犬队巡逻 · 顺路突围"],[Vector3(-77.2,2,-236.6),"索道在林后 · 沿路转弯"],[Vector3(7.5,24.1,60.5),"石堆缺了个口 · 踩石翻进牛耕地"],[Vector3(26.5,24.1,58.5),"栅栏的豁口 · 直通卷心菜联赛"]]
	for sign_data in signs:
		var post := _box(self,"TrailSignPost",Vector3(.14,1.3,.14),sign_data[0]+Vector3.UP*.65,Color("665A48"))
		# ENV_09_SIGN (arrow-board signpost) draws the marker; the box keeps a
		# minimal collision so the roadside stand-up spot stays unchanged.
		_mount_lux(post, "ENV_09_SIGN", Vector3(.9, 1.3, .3), "TrailSignLux")
		_label(self,"TrailSign",sign_data[1],sign_data[0]+Vector3.UP*1.7,21)
	for i in range(1,L.path("chase").size()-1):
		var point: Vector3=L.path("chase")[i]
		_label(self,"EscapeMarker","◆ 突围 %d" % i,point+Vector3(0,2.4,0),20)
	_build_secret_mario_pipe()
	_build_secret_mario_pipe_exit()
	_build_all_course_pipes()
	reset_world()

func _install_environment() -> void:
	var environment: Node3D
	if not "--rebuild-environment" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://assets/environments/pastoral_farm.scn"):
		environment=load("res://assets/environments/pastoral_farm.scn").instantiate()
		if environment.get_meta("layout_version",0)!=7:
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

## Swap a white-box prop's flat VisualMesh for its Lux3D model: the body keeps
## its collision, scripts and playthings, and the model is scaled uniformly to
## the replaced box height with its base dropped onto the box bottom, so every
## transform gag (tip / squash / kick) keeps driving the same root. No-ops
## without the asset - offline runs keep the box (same contract as the
## NibbleGrass tufts). `centered` matches how the body root was placed: true
## for _box/_sphere roots (origin at box centre), false for ground-level roots.
func _mount_lux(body: Node3D, asset_id: String, box_size: Vector3, lux_name := "", centered := true, fit_axis := "y") -> Node3D:
	var art := ASSETS.make(asset_id)
	if art == null:
		return null
	var mesh := body.get_node_or_null("VisualMesh")
	if mesh != null:
		mesh.visible = false
	var aabb := _model_aabb(art)
	# fit_axis picks the fitted dimension: height for standing props, width for
	# wide-assembled props, or the full per-axis box when the art's aspect
	# differs from its collider (the low hurdle's posts stay put while its
	# poles and feet stretch along the road - all X-aligned prisms).
	var scale_vec := Vector3.ONE
	if fit_axis == "box" and aabb.size.x > 0.001 and aabb.size.y > 0.001:
		scale_vec = Vector3(
			box_size.x / aabb.size.x,
			box_size.y / aabb.size.y,
			box_size.z / maxf(aabb.size.z, 0.001))
	else:
		var target: float = box_size.y if fit_axis == "y" else box_size.x
		var authored: float = aabb.size.y if fit_axis == "y" else aabb.size.x
		var fit := target / authored if authored > 0.001 else 1.0
		scale_vec = Vector3.ONE * fit
	art.scale = scale_vec
	# Models are metre-normalized with the base at the origin; drop the scaled
	# base onto the bottom face of the collision box it dresses.
	art.position = Vector3(0, (-box_size.y * 0.5 if centered else 0.0) - aabb.position.y * scale_vec.y, 0)
	if lux_name != "":
		art.name = lux_name
	body.add_child(art)
	return art

func _model_aabb(node: Node3D) -> AABB:
	# Merged local-space bounds of every mesh under a freshly made (still out
	# of tree) model, in the model's own coordinates.
	var found := false
	var merged := AABB()
	if node is VisualInstance3D:
		merged = (node as VisualInstance3D).get_aabb()
		found = true
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var child_box: AABB = (child as Node3D).transform * _model_aabb(child)
		if child_box.size == Vector3.ZERO:
			continue
		merged = merged.merge(child_box) if found else child_box
		found = true
	return merged

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

func _physics_process(delta: float) -> void:
	if _cabbage_goal_cool > 0.0:
		_cabbage_goal_cool = maxf(0.0, _cabbage_goal_cool - delta)
	if not is_instance_valid(_player): _player=get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player) or not _player.control_mode in ["explore","chase"]: return
	var closest := L.closest_on_path(_player.global_position, L.journey())
	if _player.global_position.distance_to(closest.point) < 14.0:
		_checkpoint = closest.point + Vector3.UP * 0.1
	if not _pipe_entering:
		if _player.global_position.y < closest.point.y - 7.5 or _player.global_position.y < -5.0:
			recoveries += 1
			_player.reset_at(_checkpoint)
	if _player_on_pipe and not _pipe_entering and is_instance_valid(_player):
		var pipe_node: Node3D = _current_pipe_node if is_instance_valid(_current_pipe_node) else get_node_or_null("SecretMarioPipe")
		var on_top: bool = _player.is_on_floor() and (pipe_node == null or _player.global_position.y >= pipe_node.global_position.y + 0.55)
		var stationary: bool = _player.velocity.length() < 0.8
		if on_top and stationary and (Input.is_action_pressed("move_down") or Input.is_action_just_pressed("action_interact")):
			_trigger_pipe_enter(_current_pipe_id if not _current_pipe_id.is_empty() else "course_1", pipe_node)

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

## Play a skeletal one-shot clip (e.g. "talk") on the NPC whose display title
## matches the dialogue speaker. Returns true when a rigged NPC animated.
func play_npc_action(speaker: String, clip: String) -> bool:
	var id := ""
	for key in NPC_TITLES:
		if NPC_TITLES[key] == speaker:
			id = key
			break
	if id == "" or not _npcs.has(id): return false
	var found: Array = _npcs[id].find_children("ActorAnimation", "Node", true, false)
	if not found.is_empty() and found[0].has_method("play_oneshot"):
		return found[0].play_oneshot(clip, 1.0)
	return false

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
	label.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
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
	# The baked JumpLog beam already draws this barrier in the environment's
	# shared mesh (the JumpLog body is collision-only) - the box here was only
	# ever its duplicate. Keep the collider, drop the twin visual. PROP_19
	# FALLEN_LOG stays catalogued for future 1.2 m-scale log dressing.
	log1.get_node("VisualMesh").visible = false
	var hay1 := _box(self, "Hay_Summit_Side", Vector3(1.6, 0.75, 1.6), Vector3(-49, 24.3, 85), Color("C9A35E"), true)
	_mount_lux(hay1, "PROP_11_HAY_STACK", Vector3(1.6, 0.75, 1.6), "HaystackLux")

	# Creek road logs aligned with creek bridge / L.LOGS. The hurdle model is
	# authored knee-height; its poles and feet are X-aligned prisms, so the
	# per-axis box fit stretches the span across the 2.5 m jump-bar collider
	# while posts keep their height.
	var hurdle1 := _box(self, "Hurdle_Creek_Side", Vector3(2.5, 0.65, 0.25), Vector3(48, 22.2, 3), Color("8B6846"), true)
	_mount_lux(hurdle1, "PROP_21_LOW_HURDLE", Vector3(2.5, 0.65, 0.25), "HurdleLux", true, "box")
	var rock1 := _box(self, "Rock_Creek_Side", Vector3(2.2, 0.6, 0.8), Vector3(14, 20.2, 6), Color("6C7A72"), true)
	_mount_lux(rock1, "ENV_09_ROCK", Vector3(2.2, 0.6, 0.8), "RockLux")

	# Woodland road logs aligned with L.LOGS[1]
	var log_pos_2: Vector3 = L.LOGS[1].a.lerp(L.LOGS[1].b, L.LOGS[1].t)
	var log2 := _box(self, "Log_Woodland_1", Vector3(3.6, 0.55, 0.55), log_pos_2 + Vector3.UP * 0.25, Color("4D3A27"), true)
	# Same baked-beam duplicate as the summit log - collider stays, twin box goes.
	log2.get_node("VisualMesh").visible = false
	# Woodland road cart: the old miter-bulge spot wedged it into the roadside
	# fence; it now rests on the shoulder south of the woodland road.
	var cart1 := _box(self, "Cart_Woodland_Side", Vector3(1.8, 0.7, 1.2), Vector3(-43.2, 13.85, -79.2), Color("6B523A"), true)
	_mount_lux(cart1, "ENV_09_CART", Vector3(1.8, 0.7, 1.2), "CartLux")
	# The summit log is also a playground prop: a sprinting pig can shove it
	# down the slope and open a walkable second path (jumping stays valid).
	var charge := Area3D.new()
	charge.name = "LogChargeSense"
	charge.collision_layer = 0
	charge.collision_mask = 2
	charge.position = log_pos_1 + Vector3.UP * 0.6
	var charge_shape := CollisionShape3D.new()
	var charge_box := BoxShape3D.new()
	charge_box.size = Vector3(4.8, 2.2, 2.8)
	charge_shape.shape = charge_box
	charge.add_child(charge_shape)
	add_child(charge)
	charge.body_entered.connect(_on_log_charge.bind(log1))

var _log_shoved := false

func _on_log_charge(body: Node3D, log: Node3D) -> void:
	if _log_shoved:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	if not (body.get("is_sprinting") or body.get("dodge_timer") > 0.0):
		return
	_log_shoved = true
	# Roll the gameplay log down-slope and kill both colliders (this box and
	# the baked JumpLog convex from the environment scene).
	log.collision_layer = 0
	for child in log.get_children():
		if child is CollisionShape3D:
			child.disabled = true
	var env := get_node_or_null("PastoralEnvironment")
	if env != null:
		for baked in env.find_children("JumpLog", "StaticBody3D", true, false):
			if baked.global_position.distance_to(log.global_position) < 4.0:
				baked.visible = false
				for shape in baked.get_children():
					if shape is CollisionShape3D:
						shape.disabled = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(log, "position", log.position + Vector3(-2.2, -0.6, -3.4), 0.7)
	tween.tween_property(log, "rotation:z", log.rotation.z + PI * 0.5, 0.7)
	_gag_at(log.global_position + Vector3.UP * 1.6, "轰隆——倒木被顶得滚下坡！第二条路，开了。", 2.6)
	AchievementManager.unlock("second_path")
	playground_event.emit("second_path", "")

# ------------------------------------------------------------- playground
# Ten kinds of body-driven easter eggs down the whole mountain road. Every
# collider here sits well off the road lanes (raycast/journey-bot red lines).
const PLAYTIP_TARGET := 5
const PLAYGRASS_TARGET := 6
const PLAYPOTATO_TARGET := 5
# Ball-only containment: invisible StaticBodies on this layer bounce the rigid
# cabbage balls back (their collision_mask includes it) while the pig, dogs and
# NPCs ignore it entirely (nobody else's mask lists layer 8). Used for the
# pigpen gate gap and the boards around the ox-terrace pitch, so a punted
# cabbage can never roll out of its field and get lost.
const BALL_FENCE_LAYER := 8
var _play_counts := {"tippable": 0, "grass": 0, "potato": 0}
var _cabbage_goal_cool := 0.0
# The goal-side cabbage field: planted plot cabbages start frozen in their
# beds; a kick harvests them into free balls FOREVER for the session - the
# freed cabbage stays wherever it rolls, even across course round-trips (the
# whole farm parks untouched while the pig runs a course). The meteor button
# is the one deliberate restock path for the beds.
var _plot_cabbages: Array[RigidBody3D] = []

func _plaything(kind: int, sense: Vector3, cool: float,
		charge_only := false, gags: Array[String] = []):
	var thing: Node3D = PLAYTHING.new()
	thing.name = "Plaything"
	thing.kind = kind
	thing.sense_size = sense
	thing.cooldown = cool
	thing.need_charge = charge_only
	thing.gag_lines = gags
	thing.played.connect(_on_plaything_played)
	# gag 台词同步走 playground_event("gag")：世界小字之外，
	# 由关卡宿主在屏幕右下角弹统一通知（地图上的字拉远后不可读）。
	thing.noticed.connect(func(text: String): playground_event.emit("gag", text))
	return thing

# ------------------------------------------------------------- pigpen play
# The tutorial pen's own playground: three messable props (tippable bucket,
# kickable cabbage, hay dive) plus the red meteor button near the north wall -
# a hoof on the button drops a meteor that snaps the whole pen back to its
# built state. Reset targets are registered at build time; the meteor itself
# is a level-side visual so every prop resets in one boom.
var _pen_playthings: Array[Node] = []
var _meteor_falling := false

func _register_pen_prop(body: Node3D) -> void:
	_pen_playthings.append(body.get_node("Plaything"))

func _build_pigpen_play() -> void:
	# Tippable bucket by the trough wall (no charge needed - the tutorial pig
	# has dash, but a plain walk-by knock is funnier in a pen). Lux3D
	# PROP_10_WATER_BUCKET draws the bucket; the box under it stays collision.
	var bucket := _box(self, "PenBucket", Vector3(0.5, 0.5, 0.5), Vector3(-4.5, 32.25, 96), Color("8FA3AD"), true)
	_mount_lux(bucket, "PROP_10_WATER_BUCKET", Vector3(0.5, 0.5, 0.5), "BucketLux")
	bucket.add_child(_plaything(PLAYTHING.Kind.TIPPABLE, Vector3(2.0, 2.2, 2.0), 1.0, false,
		["咣当！水桶滚出去老远。", "哗啦——桶里还真有水。"]))
	_register_pen_prop(bucket)

	# Kickable cabbage ball: the pitch ball's little sibling, a real rigid body
	# punted by impulse (see _sphere / farm_plaything._react_cabbage). Spawned a
	# hair above rest height so the fresh body never starts half-inside the
	# floor. Contained by the pen walls plus the ball-only gate-gap fence below.
	# PROP_08_CABBAGE is the pitch ball's look - the pen ball is its 0.7 m twin.
	var pen_ball := _sphere(self, "PenCabbageBall", 0.35, Vector3(-3, 32.36, 102), Color("7DB874"), true)
	# 同一张进球门票：猪圈球必须和联赛球/菜地球一样进 cabbage_ball 组，
	# 否则 _on_cabbage_goal 第一行分组检查就把它退回——踢进自家分赛场
	# 的网连 GOOOAL 都不响（2026-11-15 实机反馈的猪圈点球王不触发）。
	pen_ball.add_to_group("cabbage_ball")
	_mount_lux(pen_ball, "PROP_08_CABBAGE", Vector3(0.7, 0.7, 0.7), "CabbageLux")
	pen_ball.add_child(_plaything(PLAYTHING.Kind.CABBAGE, Vector3(2.0, 1.8, 2.0), 0.45))
	_register_pen_prop(pen_ball)

	# Hay-stack dive against the east wall: jump off the fence-side rise. Solid
	# since 2026-11 - the pig used to fall straight through the visual, so the
	# dive gag never had a landing. Now it lands ON the stack and squashes it
	# (_on_hay_dive); the gag/score lines still come from the plaything.
	var stack := _box(self, "PenHaystack", Vector3(1.8, 0.9, 1.8), Vector3(5, 32.45, 104.5), Color("D9B45A"), true)
	_mount_lux(stack, "PROP_11_HAY_STACK", Vector3(1.8, 0.9, 1.8), "HaystackLux")
	var stack_thing: FarmPlaything = _plaything(PLAYTHING.Kind.HAYSTACK, Vector3(2.4, 2.6, 2.4), 1.2)
	stack.add_child(stack_thing)
	stack_thing.played.connect(_on_hay_dive.bind(stack, 0.45, stack.position.y))
	_label(stack, "HaystackLabel", "从高处跳下 · 草垛跳水！", Vector3(0, 1.5, 0), 18)
	_register_pen_prop(stack)

	# The red reset button by the north wall. The cooldown covers exactly one
	# meteor cycle (1.1 s fall + dust), so the button re-arms right after the
	# impact and can be pressed again indefinitely - one meteor at a time, but
	# never a dead button.
	var button := _box(self, "MeteorButton", Vector3(1.0, 0.3, 1.0), Vector3(0, 32.15, 106.5), Color("8B3A2E"), true)
	_box(button, "ButtonCap", Vector3(0.7, 0.14, 0.7), Vector3(0, 0.22, 0), Color("E4573D"), false)
	# Lux3D PROP_12_METEOR_BUTTON draws base + dome as one 0.44 m model (the old
	# base+cap silhouette); the cap node stays for the offline fallback press
	# tween - farm_plaything prefers squashing the model when it is mounted.
	if _mount_lux(button, "PROP_12_METEOR_BUTTON", Vector3(1.0, 0.44, 1.0), "ButtonLux") != null:
		button.get_node("ButtonCap/VisualMesh").visible = false
	button.add_child(_plaything(PLAYTHING.Kind.METEOR_BUTTON, Vector3(1.6, 1.8, 1.6), 1.8))
	_label(button, "MeteorButtonLabel", "危险按钮 · 踩上去召唤陨石重置猪圈", Vector3(0, 1.5, 0), 18)

	# Ball-only fence across the pigpen gate gap: the stone walls already stop
	# the ball on three sides, but the story later opens this gate and a punted
	# cabbage must not escape down the mountain road.
	_ball_fence("PenBallFence", Vector3(0, 32.9, 88), Vector3(4.6, 2.6, 0.3))

func _launch_meteor_reset() -> void:
	# One meteor at a time: a second press mid-fall just clicks the cap.
	if _meteor_falling:
		return
	_meteor_falling = true
	var centre := Vector3(0, 32.2, 100)
	# The rock: fire-lit sphere with a smoke tail, falling dead-centre in the pen.
	var meteor := MeshInstance3D.new()
	meteor.name = "Meteor"
	var rock := SphereMesh.new()
	rock.radius = 0.9
	rock.height = 1.8
	meteor.mesh = rock
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("D96C2E")
	mat.emission_enabled = true
	mat.emission = Color("E8762C")
	mat.emission_energy_multiplier = 1.6
	meteor.material_override = mat
	add_child(meteor)
	meteor.position = centre + Vector3(6, 42, -6)
	var fall := create_tween()
	fall.tween_property(meteor, "position", centre, 1.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(func():
		if not is_instance_valid(self):
			return
		meteor.queue_free()
		# Impact: a dust ring rolls out from the crater and everything the
		# pig wrecked snaps home the same frame.
		var ring := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.06
		ring.mesh = disc
		var dust := StandardMaterial3D.new()
		dust.albedo_color = Color("C8B49A")
		dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = dust
		add_child(ring)
		ring.position = centre
		var puff := create_tween()
		puff.tween_property(disc, "top_radius", 9.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		puff.parallel().tween_property(disc, "bottom_radius", 9.0, 0.55)
		puff.parallel().tween_property(dust, "albedo_color:a", 0.0, 0.55)
		puff.tween_callback(ring.queue_free)
		_reset_pen_props()
	)
	fall.finished.connect(func():
		_meteor_falling = false
		playground_event.emit("gag", "轰！！陨石把猪圈和菜地砸回了出厂设置。")
	)

func _reset_pen_props() -> void:
	# The meteor is the farm's one deliberate "tidy up": pen props AND the
	# cabbage beds snap home. Everything else the pig kicked stays put (session
	# permanence) - this button is the only restock path the field has left.
	for thing in _pen_playthings:
		if not is_instance_valid(thing):
			continue
		# Kill an in-flight hay squash before the snap-home - a live tween would
		# re-squash the stack a frame later (reset_prop kills topple tweens the
		# same way). The rigid cabbage's momentum is zeroed inside reset_prop.
		var prop := thing.get_parent() as Node3D
		if prop != null:
			var squash = prop.get_meta("squash_tween", null)
			if squash is Tween and squash.is_valid():
				squash.kill()
		thing.reset_prop()
	# Plot cabbages: back into their beds, frozen and growing again.
	for body in _plot_cabbages:
		if not is_instance_valid(body):
			continue
		var bed_thing := body.get_node_or_null("Plaything")
		if bed_thing != null and bed_thing.has_method("reset_prop"):
			bed_thing.reset_prop()
		body.freeze = true # state 1 again: growing in the bed until the next kick

func _on_hay_dive(kind: String, _score, stack: Node3D, half_h: float, home_y: float) -> void:
	# A scored hay dive drives the level-side visual: the stack compresses
	# under the pig and springs back. The dive score/gag lines stay in the
	# plaything (they reach the HUD via playground_event as before).
	if kind == "dive" or kind == "perfect_dive":
		_squash_haystack(stack, half_h, home_y)

func _squash_haystack(stack: Node3D, half_h: float, home_y: float) -> void:
	if not is_instance_valid(stack):
		return
	var prev = stack.get_meta("squash_tween", null)
	if prev is Tween and prev.is_valid():
		prev.kill()
	# The bottom stays planted while the stack compresses: the origin drops by
	# exactly the amount the half-height shrinks, so the box never floats.
	var t := create_tween()
	stack.set_meta("squash_tween", t)
	t.set_parallel(true)
	t.tween_property(stack, "scale:y", 0.55, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(stack, "position:y", home_y - 0.45 * half_h, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_property(stack, "scale:y", 1.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(stack, "position:y", home_y, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _ball_fence(node_name: String, center: Vector3, size: Vector3) -> void:
	# Invisible ball-only wall (BALL_FENCE_LAYER): bounces the rigid cabbages,
	# lets the pig, dogs and NPCs walk straight through.
	var wall := StaticBody3D.new()
	wall.name = node_name
	wall.collision_layer = BALL_FENCE_LAYER
	wall.collision_mask = 0
	wall.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)

func _build_playground() -> void:
	_build_pigpen_play()
	# --- Ox terrace: the cabbage pitch beside the (relocated) vegetable field
	var ball := _sphere(self, "CabbageBall", 0.4, Vector3(46, 24.41, 30), Color("7DB874"), true)
	# Lux3D PROP_08_CABBAGE (flat leaf palette) replaces the plain green sphere
	# visual; the RigidBody3D sphere collision keeps driving the kicks.
	_mount_lux(ball, "PROP_08_CABBAGE", Vector3(0.8, 0.8, 0.8), "CabbageLux")
	ball.add_child(_plaything(PLAYTHING.Kind.CABBAGE, Vector3(2.4, 2.0, 2.4), 0.45))
	# The goal mouth accepts any cabbage ball (this one and the field plot
	# cabbages alike) - group membership, not a single magic name.
	ball.add_to_group("cabbage_ball")
	# Four goals now bait the whole farm: the league pitch plus three branch
	# nets (pen east wall, creek bridge, ranch meadow at the woodland road's
	# end), so a punted cabbage always has a net worth chasing wherever it
	# rolls. Placements stay clear of the journey/chase corridors - the pen
	# net must not stand between the pig spawn and the Old Goat, and the
	# woodland net sits by the road's terminal waypoint, not across it.
	_build_cabbage_goal("CabbageGoal", Vector3(46, 24, 24.6), "牛耕地球会 · 卷心菜联赛", 0.0, "cabbage_goal_pitch")
	_build_cabbage_goal("CabbageGoal_Pen", Vector3(4.0, 32.0, 93.5), "猪圈分赛场 · 后院点球大战", -90.0, "cabbage_goal_pen")
	# 溪桥网立在路中间（2026-11-15 实机反馈"位置偏了"）：探针实测此段路面
	# 为 z∈[-1,3]、y≈22.2 的沿 x 轴通道（z=5 是 23.7 的路肩高地，z≥7 落空）。
	# 几何中心 z=1；yaw 90 让网口朝东（+x），迎着下游来球与来路——立柱落在
	# z≈-0.7/2.7，走廊中心的 z≈1 从网口正中穿过，不挡路。
	_build_cabbage_goal("CabbageGoal_Creek", Vector3(54.0, 22.2, 1.0), "溪桥分赛场 · 卷心菜漂流终点", 90.0, "cabbage_goal_creek")
	_build_cabbage_goal("CabbageGoal_Woodland", Vector3(18.0, 8.0, -86.0), "林间分赛场 · 卷心菜远征终点", 180.0, "cabbage_goal_woodland")
	_build_pitch_fence()

	# --- Five tippables scattered down the mountain (sprint to topple). Each
	# keeps its box collision; the Lux3D dressing draws the real object.
	_tipple("Barrel_Zigzag", Vector3(-34, 25.8, 101), Vector3(0.9, 1.1, 0.9), Color("8F6A42"), "ENV_09_BARREL", "BarrelLux")
	_tipple("Wheelbarrow_Meadow", Vector3(-33, 16.6, -50), Vector3(1.4, 0.7, 0.9), Color("B0543F"), "ENV_09_WHEELBARROW", "WheelbarrowLux")
	_tipple("WoolBale_Meadow", Vector3(-45, 16.6, -30), Vector3(1.5, 0.9, 1.1), Color("E8E2CE"), "ENV_09_WOOL", "WoolBaleLux")
	_tipple("Barrel_Track", Vector3(58, 8.6, -132), Vector3(0.9, 1.1, 0.9), Color("8F6A42"), "ENV_09_BARREL", "BarrelLux")
	_build_scarecrow(Vector3(14, 24, 48))

	# --- Six nibble-grass tufts along the descent
	for def in [
		[Vector3(-5, 31.4, 82), "ENV_09_FERN"],
		[Vector3(-36, 26.4, 95), "ENV_09_REEDS"],
		[Vector3(14, 24.4, 58), "ENV_09_FERN"],
		[Vector3(44, 21.3, 14), "ENV_09_REEDS"],
		[Vector3(-45, 16.3, -55), "ENV_09_FERN"],
		[Vector3(30, 8.3, -112), "ENV_09_REEDS"],
	]:
		var tuft := ASSETS.make(def[1])
		if tuft == null:
			tuft = _box(self, "GrassTuft", Vector3(0.9, 0.6, 0.9), def[0], Color("7DB874"), false)
			add_child(tuft)
			tuft.position = def[0]
		else:
			add_child(tuft)
			tuft.position = def[0]
		tuft.name = "NibbleGrass"
		tuft.add_child(_plaything(PLAYTHING.Kind.GRASS, Vector3(2.6, 2.0, 2.6), 2.5))

	# --- Hay dive at the bottom of the west zigzag (clear of the roadside fence)
	# Solid like the pen stack: the diving pig lands in it (and squashes it)
	# instead of ghosting through the visual.
	var hay := _box(self, "HayDiveStack", Vector3(2.8, 1.5, 2.8), Vector3(-60.5, 23.9, 72.5), Color("E8C86A"), true)
	_mount_lux(hay, "PROP_11_HAY_STACK", Vector3(2.8, 1.5, 2.8), "HaystackLux")
	var hay_thing: FarmPlaything = _plaything(PLAYTHING.Kind.HAYSTACK, Vector3(2.8, 2.6, 2.8), 2.0)
	hay.add_child(hay_thing)
	hay_thing.played.connect(_on_hay_dive.bind(hay, 0.75, hay.position.y))
	_label(self, "HayDiveLabel", "草垛跳水 · 跳进来！", Vector3(-60.5, 26.1, 72.5), 18)

	# --- Beehive by the orchard (sting = speed)
	var hive_stand := _box(self, "Beehive", Vector3(0.7, 1.1, 0.7), Vector3(68, 24.55, 50), Color("D9A441"), true)
	_mount_lux(hive_stand, "PROP_14_BEEHIVE", Vector3(0.7, 1.1, 0.7), "BeehiveLux")
	hive_stand.add_child(_plaything(PLAYTHING.Kind.BEEHIVE, Vector3(2.2, 2.2, 2.2), 6.0))

	# --- Mailbox at the ox gate (nose it open). The old roadside spot skewered
	# the summit road's north fence; it now stands on the terrace south of the
	# road, east of the gate posts.
	var mailbox := _box(self, "MailboxPost", Vector3(0.18, 1.0, 0.18), Vector3(32.5, 24.26, 59.5), Color("665A48"), true)
	var box_body := _box(mailbox, "MailboxBody", Vector3(0.5, 0.35, 0.8), Vector3(0, 0.55, 0), Color("A96550"), false)
	var flag := _box(mailbox, "MailFlag", Vector3(0.08, 0.3, 0.08), Vector3(0.28, 0.75, 0), Color("E4573D"), false)
	# Lux3D PROP_15_MAILBOX (post + arched box, no flag) replaces the two boxes;
	# MailFlag stays procedural - the nose-it-open tween drives the flag.
	if _mount_lux(mailbox, "PROP_15_MAILBOX", Vector3(0.5, 1.0, 0.8), "MailboxLux") != null:
		mailbox.get_node("MailboxBody/VisualMesh").visible = false
	mailbox.add_child(_plaything(PLAYTHING.Kind.MAILBOX, Vector3(1.6, 2.4, 1.8), 1.0))

	# --- Broadcast horn at the ox gate
	var horn_pole := _box(self, "BroadcastHorn", Vector3(0.2, 2.6, 0.2), Vector3(34, 25.3, 59), Color("665A48"), true)
	_box(horn_pole, "HornCone", Vector3(0.5, 0.5, 0.9), Vector3(0, 1.5, 0.4), Color("B0543F"), false)
	# Lux3D PROP_16_BROADCAST_HORN (pole + horn cone) replaces both boxes.
	if _mount_lux(horn_pole, "PROP_16_BROADCAST_HORN", Vector3(0.5, 2.6, 0.5), "HornLux") != null:
		horn_pole.get_node("HornCone/VisualMesh").visible = false
	horn_pole.add_child(_plaything(PLAYTHING.Kind.HORN, Vector3(2.0, 3.4, 2.4), 8.0))

	# --- Mud pit by the pigpen (roll!)
	var mud := _box(self, "MudPit", Vector3(3.4, 0.12, 3.4), Vector3(7, 32.05, 95), Color("6B5D52"), false)
	mud.add_child(_plaything(PLAYTHING.Kind.MUDPIT, Vector3(3.4, 1.6, 3.4), 5.0))

	# --- Hen nest behind the barn
	var nest := _box(self, "HenNest", Vector3(1.1, 0.45, 1.1), Vector3(24, 24.2, 36), Color("C9A35E"), false)
	_mount_lux(nest, "PROP_17_HEN_NEST", Vector3(1.1, 0.45, 1.1), "HenNestLux")
	nest.add_child(_plaything(PLAYTHING.Kind.NEST, Vector3(2.0, 1.8, 2.0), 1.2))

	# --- Potato mounds in the furrow field (one nose-dig each). Unique names:
	# a duplicate name at add_child time is dropped to @Node3D@N, breaking
	# lookups (unlike a post-add rename, which gets a numeric suffix).
	var mound_index := 0
	for mound_pos in [
		Vector3(12, 24.15, 40), Vector3(17, 24.15, 43.5),
		Vector3(22, 24.15, 46.5), Vector3(26, 24.15, 49.5),
		Vector3(14, 24.15, 50.5),
	]:
		var mound := _box(self, "PotatoMound%d" % mound_index, Vector3(0.9, 0.22, 0.9), mound_pos, Color("7A5C3E"), false)
		_mount_lux(mound, "PROP_18_POTATO_MOUND", Vector3(0.9, 0.22, 0.9), "MoundLux")
		mound.add_child(_plaything(PLAYTHING.Kind.POTATO, Vector3(2.0, 1.6, 2.0), 1.0))
		mound_index += 1

	# --- Shakeable apple tree by the horse track (charged shove rains apples)
	var tree := _box(self, "AppleTree", Vector3(0.5, 2.6, 0.5), Vector3(76, 9.3, -108), Color("665A48"), true)
	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	var canopy_sphere := SphereMesh.new()
	canopy_sphere.radius = 1.6
	canopy_sphere.height = 3.2
	canopy.mesh = canopy_sphere
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color("5E8C4A")
	canopy_mat.roughness = 0.95
	canopy.material_override = canopy_mat
	canopy.position = Vector3(0, 2.2, 0)
	tree.add_child(canopy)
	# Lux3D ENV_09_APPLE (the orchard apple tree, 4.2 m authored) replaces the
	# trunk box + sphere canopy, fitted to the old ~3.4 m silhouette.
	if _mount_lux(tree, "ENV_09_APPLE", Vector3(1.6, 3.4, 1.6), "AppleTreeLux") != null:
		canopy.visible = false
	_label(tree, "AppleTreeLabel", "冲刺撞树 · 摇苹果！", Vector3(0, 4.3, 0), 18) # above the canopy sphere
	tree.add_child(_plaything(PLAYTHING.Kind.APPLE_TREE, Vector3(2.8, 3.4, 2.8), 1.0, true))

func _build_cabbage_field() -> void:
	# The vegetable beds right of the pitch goal (baked dressing rows at
	# x 55..61, z 23..29) grow real cabbages now. State 1 is planted - a frozen
	# rigid body standing in the soil; state 2 kicks off into a free cabbage
	# ball, the same light football as the pitch ball, punt-able into the goal.
	# A kick is PERMANENT for the session - the freed cabbage stays wherever it
	# rolls; only the meteor button restocks the beds (player's choice).
	for row in 3:
		var x := 55.0 + row * 3.0
		for slot in 4:
			var pos := Vector3(x + (0.15 if slot % 2 == 1 else -0.15), 24.45, 23.4 + slot * 1.6)
			var body := _sphere(self, "PlotCabbage_%d" % (row * 4 + slot), 0.4, pos, Color("7DB874"), true)
			# Plot balls ignore the pitch's ball-only fences (layer 8): their
			# home is outside the east board and their way to the goal runs
			# straight through where that board hangs. The pitch ball keeps
			# its containment - only the field cabbages roam.
			body.collision_mask = 1
			var lux := ASSETS.make("PROP_08_CABBAGE")
			if lux != null:
				var mesh := body.get_node_or_null("VisualMesh")
				if mesh != null:
					mesh.visible = false
				lux.name = "CabbageLux"
				lux.position = Vector3(0, -0.4, 0) # model pivot is bottom-centre, ball origin is centre
				body.add_child(lux)
			body.add_child(_plaything(PLAYTHING.Kind.CABBAGE, Vector3(2.2, 1.9, 2.2), 0.45))
			body.freeze = true # state 1: growing in the bed until a hoof frees it
			body.add_to_group("cabbage_ball")
			_plot_cabbages.append(body)

func _tipple(node_name: String, pos: Vector3, size: Vector3, color: Color, asset_id := "", lux_name := "") -> void:
	var body := _box(self, node_name, size, pos, color, true)
	if asset_id != "":
		_mount_lux(body, asset_id, size, lux_name)
	body.add_child(_plaything(PLAYTHING.Kind.TIPPABLE, Vector3(2.6, 2.4, 2.6), 1.0, true))

func _build_scarecrow(pos: Vector3) -> void:
	var scare := Node3D.new()
	scare.name = "Scarecrow_Field"
	scare.position = pos
	add_child(scare)
	_box(scare, "Pole", Vector3(0.16, 2.4, 0.16), Vector3(0, 1.2, 0), Color("665A48"), true)
	_box(scare, "Arms", Vector3(1.7, 0.16, 0.16), Vector3(0, 1.7, 0), Color("665A48"), false)
	_box(scare, "Head", Vector3(0.5, 0.5, 0.5), Vector3(0, 2.1, 0), Color("E8C86A"), false)
	_box(scare, "Hat", Vector3(0.8, 0.12, 0.8), Vector3(0, 2.4, 0), Color("B0543F"), false)
	# Lux3D PROP_13_SCARECROW draws the whole figure (the root sits at ground
	# level); the pole body keeps the collision the tipping gag rides on.
	if _mount_lux(scare, "PROP_13_SCARECROW", Vector3(1.7, 2.6, 0.8), "ScarecrowLux", false) != null:
		for part in ["Pole", "Arms", "Head", "Hat"]:
			var mesh := scare.get_node_or_null(NodePath("%s/VisualMesh" % part))
			if mesh != null:
				mesh.visible = false
	scare.add_child(_plaything(PLAYTHING.Kind.TIPPABLE, Vector3(2.6, 3.0, 2.6), 1.0, true,
		["麻雀四散！衣服里藏着……另一件更破的衣服。"]))

func _on_plaything_played(kind: String, _detail) -> void:
	if kind == "tippable":
		_play_counts["tippable"] += 1
		if _play_counts["tippable"] >= PLAYTIP_TARGET:
			AchievementManager.unlock("demolition_crew")
			playground_event.emit("demolition_crew", "")
	elif kind == "grass":
		_play_counts["grass"] += 1
		if _play_counts["grass"] >= PLAYGRASS_TARGET:
			AchievementManager.unlock("grass_gourmet")
			playground_event.emit("grass_gourmet", "")
	elif kind == "potato":
		_play_counts["potato"] += 1
		if _play_counts["potato"] >= PLAYPOTATO_TARGET:
			AchievementManager.unlock("potato_harvest")
			playground_event.emit("potato_harvest", "")
	elif kind == "apples_all":
		AchievementManager.unlock("apple_rain")
		playground_event.emit("apple_rain", "")
	elif kind == "perfect_dive":
		AchievementManager.unlock("perfect_dive")
		playground_event.emit("perfect_dive", _detail)
	elif kind == "meteor":
		_launch_meteor_reset()
	else:
		playground_event.emit(kind, _detail)

func _build_cabbage_goal(node_name: String, pos: Vector3, title: String, yaw_deg := 0.0,
		achievement_id := "") -> Node3D:
	# One cabbage goal, wherever the farm wants a net: the Lux3D PROP_09_GOAL
	# frame over procedural colliders, a title label, and the mouth Area that
	# scores any cabbage_ball. The area's handler receives this goal root and
	# this net's achievement id, so the shake, the gag and the per-net medal
	# all land on the net that scored.
	var goal := Node3D.new()
	goal.name = node_name
	goal.position = pos
	goal.rotation.y = deg_to_rad(yaw_deg)
	add_child(goal)
	# Lux3D PROP_09_GOAL (netless frame, 2.406 m wide / 1.55 m tall) is the
	# visual; the procedural posts stay on as colliders, rescaled to hug the
	# stretched frame so the ball bounces where the goal looks like it ends.
	var goal_post_h := 1.5
	var goal_frame := ASSETS.make("PROP_09_GOAL")
	if goal_frame != null:
		goal_post_h = 1.55 * (3.4 / 2.406)
	_box(goal, "PostL", Vector3(0.22, goal_post_h, 0.22), Vector3(-1.7, goal_post_h / 2, 0), Color("5A442E"), true)
	_box(goal, "PostR", Vector3(0.22, goal_post_h, 0.22), Vector3(1.7, goal_post_h / 2, 0), Color("5A442E"), true)
	_box(goal, "CrossBar", Vector3(3.6, 0.22, 0.22), Vector3(0, goal_post_h, 0), Color("5A442E"), true)
	# No back panel: the old cream-white NetBack slab read as a whiteboard
	# behind the mouth (playtest feedback). The Lux frame is the whole goal -
	# a scored ball rolls straight through, which the pitch's ball fences and
	# the free-roaming plot cabbages both take in stride.
	if goal_frame != null:
		goal_frame.name = "GoalFrameLux"
		goal_frame.scale = Vector3.ONE * (3.4 / 2.406)
		# Model pivot sits at depth-middle; shift back so the post plane (the
		# +z face after export) lands on the procedural collider plane at z=0.
		goal_frame.position = Vector3(0, 0, -0.616 * (3.4 / 2.406))
		goal.add_child(goal_frame)
		# The frame now draws the goal; the procedural boxes keep only their collision.
		for post_name in ["PostL", "PostR", "CrossBar"]:
			var post_mesh := goal.get_node_or_null(NodePath("%s/VisualMesh" % post_name))
			if post_mesh != null:
				post_mesh.visible = false
	_label(goal, "GoalTitle", title, Vector3(0, goal_post_h + 0.7, 0), 20)
	var goal_area := Area3D.new()
	goal_area.name = "CabbageGoalArea"
	goal_area.collision_layer = 0
	goal_area.collision_mask = 1 # statics: the cabbage ball itself (layer 1)
	goal_area.position = Vector3(0, 0.8, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 1.0, 1.4)
	shape.shape = box
	goal_area.add_child(shape)
	goal.add_child(goal_area)
	goal_area.body_entered.connect(func(body: Node3D): _on_cabbage_goal(body, goal, achievement_id))
	return goal

func _on_cabbage_goal(body: Node3D, goal: Node3D, goal_ach_id := "") -> void:
	# Any cabbage ball scores in any of the farm's nets - the pitch ball, the
	# pen ball and the field plot cabbages alike (they join the cabbage_ball
	# group at build time), from the league pitch to the woodland branch goal.
	# The goal's own posts/net also overlap the mouth Area at build time; the
	# group check sends them straight back out.
	if not body.is_in_group("cabbage_ball"):
		return
	if _cabbage_goal_cool > 0.0:
		return
	_cabbage_goal_cool = 5.0
	var cheer_at := Vector3(46, 26.4, 24.6)
	if goal != null and is_instance_valid(goal):
		cheer_at = goal.global_position + Vector3(0, 2.4, 0)
		var tween := create_tween()
		tween.tween_property(goal, "position:x", goal.position.x + 0.25, 0.07)
		tween.tween_property(goal, "position:x", goal.position.x - 0.25, 0.07)
		tween.tween_property(goal, "position:x", goal.position.x, 0.1)
	_gag_at(cheer_at, "GOOOAL！卷心菜应声入网！", 2.4)
	# Immediate reward on every goal: the pig celebrates and oinks on the
	# spot, so the toast, the world gag and (first time only) the achievement
	# popup all land on the same beat - scoring feels answered, not just
	# noticed on a repeat kick.
	if is_instance_valid(_player):
		if _player.has_method("play_victory_animation"):
			_player.play_victory_animation()
		var pv = _player.get("voice")
		if pv != null and pv.has_method("oink"):
			pv.oink()
	AchievementManager.unlock("cabbage_striker")
	# Per-net medals + the grand slam: every net has its own achievement, and
	# collecting all four pays the big one (state check, same pattern as the
	# all_courses chase achievement).
	if not goal_ach_id.is_empty():
		AchievementManager.unlock(goal_ach_id)
		var slam := true
		for net_id in ["cabbage_goal_pitch", "cabbage_goal_pen", "cabbage_goal_creek", "cabbage_goal_woodland"]:
			slam = slam and AchievementManager.is_unlocked(net_id)
		if slam:
			AchievementManager.unlock("cabbage_grand_slam")
	playground_event.emit("cabbage_goal", "")

func _sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color, solid: bool) -> Node3D:
	var root: Node3D
	if solid:
		# 真刚体卷心菜：轻质足球手感——低质量让猪蹄一碰就走，阻尼只留一点
		# 兜底（旧值 0.7 的线性阻尼一秒就把速度掐剩三成，球像被吸在地上）。
		# 踢球是冲量（见 farm_plaything._react_cabbage）。mask 含
		# BALL_FENCE_LAYER：猪圈门口和球场四周的隐形球闸把球留在场内，
		# 猪/狗/NPC 不受影响照旧穿行。
		var body := RigidBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1 | BALL_FENCE_LAYER
		body.mass = 0.4
		body.physics_material_override = _cabbage_material()
		body.linear_damp = 0.45
		body.angular_damp = 0.15
		body.continuous_cd = true
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		body.add_child(shape)
		root = body
	else:
		root = Node3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)
	var mesh := MeshInstance3D.new()
	mesh.name = "VisualMesh"
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	mesh.mesh = sphere_mesh
	mesh.material_override = _material(color)
	root.add_child(mesh)
	return root

func _cabbage_material() -> PhysicsMaterial:
	# Football feel: lively bounce so punts rebound off posts and boards,
	# moderate friction so it grips and rolls without sticking to the turf.
	var material := PhysicsMaterial.new()
	material.bounce = 0.5
	material.friction = 0.6
	return material

func _build_pitch_fence() -> void:
	# Invisible ball-only boards around the cabbage pitch (x 39.5..52.5,
	# z 22.8..36.5): the ox terrace is a huge open meadow, and without boards
	# one hard punt sends the ball rolling off across it forever. Tall enough
	# (3 m) that even a lofted punt stays in; the goal and its posts sit inside.
	_ball_fence("PitchBallFenceN", Vector3(46.0, 25.5, 22.8), Vector3(13.3, 3.0, 0.3))
	_ball_fence("PitchBallFenceS", Vector3(46.0, 25.5, 36.5), Vector3(13.3, 3.0, 0.3))
	_ball_fence("PitchBallFenceW", Vector3(39.5, 25.5, 29.65), Vector3(0.3, 3.0, 14.0))
	_ball_fence("PitchBallFenceE", Vector3(52.5, 25.5, 29.65), Vector3(0.3, 3.0, 14.0))

func _gag_at(world_pos: Vector3, text: String, life := 2.0) -> void:
	var label := preload("res://scripts/ui/ui_kit.gd").world_label(text, 24, Color("FFFDF6"), Color("2C6E7A"))
	label.position = world_pos
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", world_pos.y + 0.8, life)
	t.parallel().tween_property(label, "modulate:a", 0.0, life * 0.9)
	t.tween_callback(label.queue_free)

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
	# Positioned right in the middle of the dirt road after the final summit corner before Ox's gate!
	# Placed after basic tutorial training (WASD movement, fallen logs, dog ambushes, and struggle).
	# Located right at the final summit corner bend (Vector3(16.0, 24.0, 66.0)), prominently visible before Ox's gate.
	var pipe_pos := Vector3(16.0, 24.0, 66.0)
	pipe_root.position = pipe_pos
	add_child(pipe_root)

	# Solid Pipe Body (pig can jump onto it with Space)
	var pipe_body := StaticBody3D.new()
	pipe_body.name = "PipeBody"
	pipe_body.collision_layer = 1
	pipe_body.collision_mask = 0
	var body_shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 1.05
	cyl_shape.height = 0.70
	body_shape.shape = cyl_shape
	body_shape.position.y = 0.35
	pipe_body.add_child(body_shape)

	# Visuals: Lux3D model or procedural cylinder fallback
	var lux_pipe := ASSETS.make("PROP_C1_PIPE")
	if lux_pipe:
		pipe_body.add_child(lux_pipe)
	else:
		var pipe_mat := StandardMaterial3D.new()
		pipe_mat.albedo_color = Color("2E7D32")
		pipe_mat.roughness = 0.45

		var body_mesh := MeshInstance3D.new()
		var body_cyl := CylinderMesh.new()
		body_cyl.top_radius = 1.0
		body_cyl.bottom_radius = 1.0
		body_cyl.height = 0.65
		body_mesh.mesh = body_cyl
		body_mesh.position.y = 0.325
		body_mesh.material_override = pipe_mat
		pipe_body.add_child(body_mesh)

		# Pipe rim flange
		var rim_mesh := MeshInstance3D.new()
		var rim_cyl := CylinderMesh.new()
		rim_cyl.top_radius = 1.2
		rim_cyl.bottom_radius = 1.2
		rim_cyl.height = 0.2
		rim_mesh.mesh = rim_cyl
		rim_mesh.position.y = 0.58
		rim_mesh.material_override = pipe_mat
		pipe_body.add_child(rim_mesh)

		# Dark interior hole
		var hole_mesh := MeshInstance3D.new()
		var hole_cyl := CylinderMesh.new()
		hole_cyl.top_radius = 0.88
		hole_cyl.bottom_radius = 0.88
		hole_cyl.height = 0.04
		hole_mesh.mesh = hole_cyl
		hole_mesh.position.y = 0.67
		var hole_mat := StandardMaterial3D.new()
		hole_mat.albedo_color = Color("0A150A")
		hole_mesh.material_override = hole_mat
		pipe_body.add_child(hole_mesh)

	pipe_root.add_child(pipe_body)

	# Dynamic Hint Label above the pipe
	_pipe_hint_label = _label(pipe_root, "PipeSign", "★ 超级绿水管 ★\n[ 跳上管顶按 S 钻入 ]", Vector3(0, 2.2, 0), 22)

	# Pipe Top Stance Area (detects pig standing on the rim)
	var top_area := Area3D.new()
	top_area.name = "PipeTopArea"
	top_area.collision_layer = 0
	top_area.collision_mask = 2
	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.45, 1.8)
	area_shape.shape = box
	area_shape.position.y = 0.8
	top_area.add_child(area_shape)
	top_area.body_entered.connect(_on_pipe_top_entered)
	top_area.body_exited.connect(_on_pipe_top_exited)
	pipe_root.add_child(top_area)

func _on_pipe_top_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_on_pipe = true
		_current_pipe_id = "course_1"
		_current_pipe_node = get_node_or_null("SecretMarioPipe")
		_current_hint_label = _pipe_hint_label
		if _pipe_hint_label:
			_pipe_hint_label.text = "▼ 按 S 键钻入地下隐藏关！▼"
			_pipe_hint_label.modulate = Color("FFE066")

func _on_pipe_top_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_on_pipe = false
		if _pipe_hint_label:
			_pipe_hint_label.text = "★ 超级绿水管 ★\n[ 跳上管顶按 S 钻入 ]"
			_pipe_hint_label.modulate = CREAM

func _on_generic_pipe_top_entered(body: Node3D, course_id: String, hint_label: Label3D, pipe_node: Node3D) -> void:
	if body.is_in_group("player"):
		_player_on_pipe = true
		_current_pipe_id = course_id
		_current_pipe_node = pipe_node
		_current_hint_label = hint_label
		if hint_label:
			hint_label.text = "▼ 按 S 键钻入隐藏关！▼"
			hint_label.modulate = Color("FFE066")

func _on_generic_pipe_top_exited(body: Node3D, hint_label: Label3D, default_text: String, hint_suffix: String) -> void:
	if body.is_in_group("player"):
		_player_on_pipe = false
		if hint_label:
			hint_label.text = default_text + "\n" + hint_suffix
			hint_label.modulate = CREAM

func _trigger_pipe_enter(course_id: String = "course_1", pipe_node: Node3D = null) -> void:
	if _pipe_entering or not is_instance_valid(_player): return
	_pipe_entering = true
	var hint: Label3D = _current_hint_label if is_instance_valid(_current_hint_label) else _pipe_hint_label
	if hint:
		hint.text = "▶ 咕噜噜……钻入隐藏关！◀"
		hint.modulate = Color("52B788")
	if _player.has_method("set_control_mode"):
		_player.set_control_mode("cinematic")
	var target_node: Node3D = pipe_node if is_instance_valid(pipe_node) else (_current_pipe_node if is_instance_valid(_current_pipe_node) else get_node_or_null("SecretMarioPipe"))
	var target_x: float = target_node.global_position.x if target_node else _player.global_position.x
	var target_z: float = target_node.global_position.z if target_node else _player.global_position.z
	var tween := create_tween()
	# Center onto pipe then smoothly drop down inside (Mario pipe sound/feel)
	tween.tween_property(_player, "global_position:x", target_x, 0.12)
	tween.parallel().tween_property(_player, "global_position:z", target_z, 0.12)
	tween.tween_property(_player, "global_position:y", _player.global_position.y - 1.1, 0.28)
	tween.parallel().tween_property(_player, "scale:y", 0.4, 0.28)
	tween.tween_callback(func():
		_player.scale.y = 1.0
		_pipe_entering = false
		_player_on_pipe = false
		secret_pipe_entered.emit(course_id)
	)

func _on_secret_pipe_body_entered(body: Node3D) -> void:
	# Test compatibility helper
	if body.is_in_group("player"):
		secret_pipe_entered.emit("course_1")

func _build_secret_mario_pipe_exit() -> void:
	var exit_root := Node3D.new()
	exit_root.name = "SecretMarioPipeExit"
	# Positioned right at the entrance of the Ox field level (just past the gate outside GateOxTrigger)!
	var exit_pos := Vector3(38.0, 24.0, 52.0)
	exit_root.position = exit_pos
	add_child(exit_root)

	var pipe_body := StaticBody3D.new()
	pipe_body.name = "ExitPipeBody"
	pipe_body.collision_layer = 1
	pipe_body.collision_mask = 0
	var body_shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 1.05
	cyl_shape.height = 0.35
	body_shape.shape = cyl_shape
	body_shape.position.y = 0.175
	pipe_body.add_child(body_shape)

	# Visuals: Lux3D model or procedural cylinder fallback
	var lux_pipe := ASSETS.make("PROP_C1_PIPE")
	if lux_pipe:
		lux_pipe.scale = Vector3(1.0, 0.65, 1.0)
		pipe_body.add_child(lux_pipe)
	else:
		var pipe_mat := StandardMaterial3D.new()
		pipe_mat.albedo_color = Color("2E7D32")
		pipe_mat.roughness = 0.45

		var body_mesh := MeshInstance3D.new()
		var body_cyl := CylinderMesh.new()
		body_cyl.top_radius = 1.0
		body_cyl.bottom_radius = 1.0
		body_cyl.height = 0.35
		body_mesh.mesh = body_cyl
		body_mesh.position.y = 0.175
		body_mesh.material_override = pipe_mat
		pipe_body.add_child(body_mesh)

		var rim_mesh := MeshInstance3D.new()
		var rim_cyl := CylinderMesh.new()
		rim_cyl.top_radius = 1.2
		rim_cyl.bottom_radius = 1.2
		rim_cyl.height = 0.15
		rim_mesh.mesh = rim_cyl
		rim_mesh.position.y = 0.3
		rim_mesh.material_override = pipe_mat
		pipe_body.add_child(rim_mesh)

		var hole_mesh := MeshInstance3D.new()
		var hole_cyl := CylinderMesh.new()
		hole_cyl.top_radius = 0.88
		hole_cyl.bottom_radius = 0.88
		hole_cyl.height = 0.04
		hole_mesh.mesh = hole_cyl
		hole_mesh.position.y = 0.37
		var hole_mat := StandardMaterial3D.new()
		hole_mat.albedo_color = Color("0A150A")
		hole_mesh.material_override = hole_mat
		pipe_body.add_child(hole_mesh)

	exit_root.add_child(pipe_body)
	_label(exit_root, "ExitPipeSign", "★ 地下隐藏关 · 出口 ★", Vector3(0, 1.8, 0), 20)

func _build_all_course_pipes() -> void:
	# Hidden-course entrances live at the END of each downhill chase (mirroring the
	# course-1 Mario pipe at the final summit corner before Ox's gate), so entering
	# a secret never skips the chase content. Each entrance is themed to its course:
	# creek = pixel whirlpool, woodland = fairy-tale tree hollow, courtyard = neon
	# game-show launchpad. Every entrance tucks against a road shoulder (pad edge
	# >= ~0.6 m off the roadside fence; the old C2/C4 spots skewered the fence)
	# and every exit lands deep inside the next meadow — >= 26 m from its entrance
	# so the pop-out never drops the pig back on top of the portal it dove into.
	# Course 2 (Creek): tucked on the last creek-chase straight's shoulder before
	# Sheep's gate -> exit inside the sheep meadow, on the way to 小羊.
	_build_custom_pipe_entrance("SecretCreekPipe", "course_2", Vector3(-27.0, 16.0, -15.0), "★ 像素溪流漩涡 ★", "漩涡边缘", "whirlpool")
	_build_custom_pipe_exit("SecretCreekPipeExit", Vector3(-44.0, 16.0, -37.0), "★ 溪流捷径 · 出口 ★", "whirlpool")

	# Course 3 (Woodland): road shoulder on the final woodland stretch before
	# Horse's gate -> exit inside the horse pasture short of the record board.
	_build_custom_pipe_entrance("SecretWoodlandPipe", "course_3", Vector3(8.2, 8.95, -85.3), "★ 童话林间树洞 ★", "树洞边", "treehollow")
	_build_custom_pipe_exit("SecretWoodlandPipeExit", Vector3(27.0, 8.0, -103.5), "★ 林间捷径 · 出口 ★", "treehollow")

	# Course 4 (Courtyard): west shoulder of the breakout straight before the final
	# corner (the old spot sat 0.4 m inside the chase fence) -> exit on the gate
	# court beside the farmer.
	_build_custom_pipe_entrance("SecretCourtyardPipe", "course_4", Vector3(-48.0, 2.0, -197.0), "★ 荧光综艺弹射台 ★", "弹射台", "launchpad")
	_build_custom_pipe_exit("SecretCourtyardPipeExit", Vector3(-75.5, 2.0, -223.5), "★ 终极大院 · 出口 ★", "launchpad")

func _build_custom_pipe_entrance(pipe_name: String, course_id: String, pos: Vector3, label_text: String, stand_word: String, style: String) -> Node3D:
	var pipe_root := Node3D.new()
	pipe_root.name = pipe_name
	pipe_root.position = pos
	add_child(pipe_root)

	var pipe_body := StaticBody3D.new()
	pipe_body.name = "PipeBody"
	pipe_body.collision_layer = 1
	pipe_body.collision_mask = 0
	var body_shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 1.05
	cyl_shape.height = 0.70
	body_shape.shape = cyl_shape
	body_shape.position.y = 0.35
	pipe_body.add_child(body_shape)
	match style:
		"whirlpool":
			_build_whirlpool_visuals(pipe_body)
		"treehollow":
			_build_treehollow_visuals(pipe_body)
		"launchpad":
			_build_launchpad_visuals(pipe_body)
	pipe_root.add_child(pipe_body)

	var hint_suffix := "[ 跳上%s按 S 钻入 ]" % stand_word
	var hint := _label(pipe_root, "PipeSign", label_text + "\n" + hint_suffix, Vector3(0, 2.2, 0), 22)

	var top_area := Area3D.new()
	top_area.name = "PipeTopArea"
	top_area.collision_layer = 0
	top_area.collision_mask = 2
	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.45, 1.8)
	area_shape.shape = box
	area_shape.position.y = 0.8
	top_area.add_child(area_shape)
	top_area.body_entered.connect(func(body: Node3D):
		_on_generic_pipe_top_entered(body, course_id, hint, pipe_root)
	)
	top_area.body_exited.connect(func(body: Node3D):
		_on_generic_pipe_top_exited(body, hint, label_text, hint_suffix)
	)
	pipe_root.add_child(top_area)
	return pipe_root

func _flat_mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _cyl(parent: Node3D, radius: float, height: float, y: float, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh.mesh = cyl
	mesh.position.y = y
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

func _box_mesh(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

func _build_whirlpool_visuals(pipe_body: Node3D) -> void:
	# Creek course: a pixel/voxel-styled stone ring around a spinning water vortex.
	var water_mat := _flat_mat(Color("38BDF8"))
	var deep_mat := _flat_mat(Color("0E7490"))
	var stone_mat := _flat_mat(Color("78716C"))
	_cyl(pipe_body, 1.0, 0.65, 0.325, water_mat)
	_cyl(pipe_body, 0.62, 0.04, 0.665, deep_mat)
	# Voxel stepping stones ringing the pool (pixel style = chunky boxes). Ring
	# stays inside the pad's roadside clearance so no stone pokes through the fence.
	for i in range(8):
		var angle := TAU * i / 8.0
		var ring_pos := Vector3(cos(angle) * 1.1, 0.5, sin(angle) * 1.1)
		_box_mesh(pipe_body, Vector3(0.55, 0.5, 0.55), ring_pos, stone_mat)
	# Spinning foam cross on the water so the vortex reads as alive.
	var foam := Node3D.new()
	foam.name = "VortexFoam"
	pipe_body.add_child(foam)
	foam.position.y = 0.63
	var foam_mat := _flat_mat(Color("BAE6FD"))
	_box_mesh(foam, Vector3(1.5, 0.06, 0.3), Vector3.ZERO, foam_mat)
	_box_mesh(foam, Vector3(0.3, 0.06, 1.5), Vector3.ZERO, foam_mat)
	var tween := pipe_body.create_tween()
	tween.set_loops()
	tween.tween_property(foam, "rotation:y", TAU, 2.4).as_relative()

func _build_treehollow_visuals(pipe_body: Node3D) -> void:
	# Woodland course: a fairy-tale tree stump with a dark hollow mouth.
	var bark_mat := _flat_mat(Color("A9746B"))
	var bark_dark := _flat_mat(Color("7C5A52"))
	var leaf_mat := _flat_mat(Color("9DC183"))
	var hole_mat := _flat_mat(Color("1C1410"))
	_cyl(pipe_body, 1.1, 0.85, 0.425, bark_mat)
	_cyl(pipe_body, 0.92, 0.06, 0.86, bark_dark)
	_cyl(pipe_body, 0.78, 0.04, 0.885, hole_mat)
	# Storybook trunk + canopy behind the stump so the hollow reads as a tree.
	var trunk := _cyl(pipe_body, 0.42, 2.6, 1.3, bark_mat)
	trunk.position = Vector3(1.0, 1.3, -1.0)
	var canopy := Node3D.new()
	canopy.name = "Canopy"
	pipe_body.add_child(canopy)
	canopy.position = Vector3(1.0, 2.9, -1.0)
	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.05
	sphere.height = 1.6
	blob.mesh = sphere
	blob.material_override = leaf_mat
	canopy.add_child(blob)
	var blob2 := MeshInstance3D.new()
	blob2.mesh = sphere
	blob2.scale = Vector3(0.7, 0.6, 0.7)
	blob2.position = Vector3(0.75, 0.35, 0.35)
	blob2.material_override = leaf_mat
	canopy.add_child(blob2)

func _build_launchpad_visuals(pipe_body: Node3D) -> void:
	# Courtyard course: a neon game-show podium with glowing chevrons.
	var podium_mat := _flat_mat(Color("FF1493"), 0.8)
	var ring_mat := _flat_mat(Color("22D3EE"), 1.4)
	var dark_mat := _flat_mat(Color("2B0A1E"))
	_cyl(pipe_body, 1.0, 0.65, 0.325, podium_mat)
	_cyl(pipe_body, 1.25, 0.12, 0.06, ring_mat)
	_cyl(pipe_body, 0.8, 0.04, 0.665, dark_mat)
	# Glowing chevron arrows pointing down into the pad.
	for i in range(4):
		var angle := TAU * i / 4.0 + PI / 4.0
		var chev := _box_mesh(pipe_body, Vector3(0.42, 0.1, 0.2), Vector3(cos(angle) * 1.15, 0.68, sin(angle) * 1.15), ring_mat)
		chev.rotation.y = -angle

func _build_custom_pipe_exit(exit_name: String, pos: Vector3, label_text: String, style: String) -> Node3D:
	# Exit stubs share the entrance's course-themed look, squashed to stub height
	# (the pig pops back out of the same kind of portal it dove into).
	var exit_root := Node3D.new()
	exit_root.name = exit_name
	exit_root.position = pos
	add_child(exit_root)

	var pipe_body := StaticBody3D.new()
	pipe_body.name = "ExitPipeBody"
	pipe_body.collision_layer = 1
	pipe_body.collision_mask = 0
	var body_shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 1.05
	cyl_shape.height = 0.35
	body_shape.shape = cyl_shape
	body_shape.position.y = 0.175
	pipe_body.add_child(body_shape)

	var deco := Node3D.new()
	deco.name = "ExitDeco"
	deco.scale = Vector3(1.0, 0.55, 1.0)
	pipe_body.add_child(deco)
	match style:
		"whirlpool":
			_build_whirlpool_visuals(deco)
		"treehollow":
			_build_treehollow_visuals(deco)
		"launchpad":
			_build_launchpad_visuals(deco)

	exit_root.add_child(pipe_body)
	_label(exit_root, "ExitPipeSign", label_text, Vector3(0, 1.8, 0), 20)
	return exit_root
