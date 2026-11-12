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
	_build_playground()
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
	_build_secret_mario_pipe_exit()
	_build_all_course_pipes()
	reset_world()

func _install_environment() -> void:
	var environment: Node3D
	if not "--rebuild-environment" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://assets/environments/pastoral_farm.scn"):
		environment=load("res://assets/environments/pastoral_farm.scn").instantiate()
		if environment.get_meta("layout_version",0)!=5:
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
	var hay1 := _box(self, "Hay_Summit_Side", Vector3(1.6, 0.75, 1.6), Vector3(-49, 24.3, 85), Color("C9A35E"), true)

	# Creek road logs aligned with creek bridge / L.LOGS
	var hurdle1 := _box(self, "Hurdle_Creek_Side", Vector3(2.5, 0.65, 0.25), Vector3(48, 22.2, 3), Color("8B6846"), true)
	var rock1 := _box(self, "Rock_Creek_Side", Vector3(2.2, 0.6, 0.8), Vector3(14, 20.2, 6), Color("6C7A72"), true)

	# Woodland road logs aligned with L.LOGS[1]
	var log_pos_2: Vector3 = L.LOGS[1].a.lerp(L.LOGS[1].b, L.LOGS[1].t)
	var log2 := _box(self, "Log_Woodland_1", Vector3(3.6, 0.55, 0.55), log_pos_2 + Vector3.UP * 0.25, Color("4D3A27"), true)
	var cart1 := _box(self, "Cart_Woodland_Side", Vector3(1.8, 0.7, 1.2), Vector3(-44, 14.2, -84), Color("6B523A"), true)
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
var _play_counts := {"tippable": 0, "grass": 0, "potato": 0}
var _cabbage_goal_cool := 0.0

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
	return thing

func _build_playground() -> void:
	# --- Ox terrace: the cabbage pitch beside the (relocated) vegetable field
	var ball := _sphere(self, "CabbageBall", 0.4, Vector3(46, 24.4, 30), Color("7DB874"), true)
	ball.add_child(_plaything(PLAYTHING.Kind.CABBAGE, Vector3(2.4, 2.0, 2.4), 0.45))
	var goal := Node3D.new()
	goal.name = "CabbageGoal"
	goal.position = Vector3(46, 24, 24.6)
	add_child(goal)
	_box(goal, "PostL", Vector3(0.22, 1.5, 0.22), Vector3(-1.7, 0.75, 0), Color("5A442E"), true)
	_box(goal, "PostR", Vector3(0.22, 1.5, 0.22), Vector3(1.7, 0.75, 0), Color("5A442E"), true)
	_box(goal, "CrossBar", Vector3(3.6, 0.22, 0.22), Vector3(0, 1.5, 0), Color("5A442E"), true)
	_box(goal, "NetBack", Vector3(3.4, 1.3, 0.12), Vector3(0, 0.7, -0.7), Color("E8E2CE"), false)
	_label(goal, "GoalTitle", "牛耕地球会 · 卷心菜联赛", Vector3(0, 2.2, 0), 20)
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
	goal_area.body_entered.connect(_on_cabbage_goal)

	# --- Five tippables scattered down the mountain (sprint to topple)
	_tipple("Barrel_Zigzag", Vector3(-34, 25.8, 101), Vector3(0.9, 1.1, 0.9), Color("8F6A42"))
	_tipple("Wheelbarrow_Meadow", Vector3(-33, 16.6, -50), Vector3(1.4, 0.7, 0.9), Color("B0543F"))
	_tipple("WoolBale_Meadow", Vector3(-45, 16.6, -30), Vector3(1.5, 0.9, 1.1), Color("E8E2CE"))
	_tipple("Barrel_Track", Vector3(58, 8.6, -132), Vector3(0.9, 1.1, 0.9), Color("8F6A42"))
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

	# --- Hay dive at the bottom of the west zigzag
	var hay := _box(self, "HayDiveStack", Vector3(2.8, 1.5, 2.8), Vector3(-57.5, 23.4, 74.5), Color("E8C86A"), false)
	hay.add_child(_plaything(PLAYTHING.Kind.HAYSTACK, Vector3(2.8, 2.6, 2.8), 2.0))
	_label(self, "HayDiveLabel", "草垛跳水 · 跳进来！", Vector3(-57.5, 25.6, 74.5), 18)

	# --- Beehive by the orchard (sting = speed)
	var hive_stand := _box(self, "Beehive", Vector3(0.7, 1.1, 0.7), Vector3(68, 24.55, 50), Color("D9A441"), true)
	hive_stand.add_child(_plaything(PLAYTHING.Kind.BEEHIVE, Vector3(2.2, 2.2, 2.2), 6.0))

	# --- Mailbox at the ox gate (nose it open)
	var mailbox := _box(self, "MailboxPost", Vector3(0.18, 1.0, 0.18), Vector3(25, 24.5, 62), Color("665A48"), true)
	var box_body := _box(mailbox, "MailboxBody", Vector3(0.5, 0.35, 0.8), Vector3(0, 0.55, 0), Color("A96550"), false)
	var flag := _box(mailbox, "MailFlag", Vector3(0.08, 0.3, 0.08), Vector3(0.28, 0.75, 0), Color("E4573D"), false)
	mailbox.add_child(_plaything(PLAYTHING.Kind.MAILBOX, Vector3(1.6, 2.4, 1.8), 1.0))

	# --- Broadcast horn at the ox gate
	var horn_pole := _box(self, "BroadcastHorn", Vector3(0.2, 2.6, 0.2), Vector3(34, 25.3, 59), Color("665A48"), true)
	_box(horn_pole, "HornCone", Vector3(0.5, 0.5, 0.9), Vector3(0, 1.5, 0.4), Color("B0543F"), false)
	horn_pole.add_child(_plaything(PLAYTHING.Kind.HORN, Vector3(2.0, 3.4, 2.4), 8.0))

	# --- Mud pit by the pigpen (roll!)
	var mud := _box(self, "MudPit", Vector3(3.4, 0.12, 3.4), Vector3(7, 32.05, 95), Color("6B5D52"), false)
	mud.add_child(_plaything(PLAYTHING.Kind.MUDPIT, Vector3(3.4, 1.6, 3.4), 5.0))

	# --- Hen nest behind the barn
	var nest := _box(self, "HenNest", Vector3(1.1, 0.45, 1.1), Vector3(24, 24.2, 36), Color("C9A35E"), false)
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
	_label(tree, "AppleTreeLabel", "冲刺撞树 · 摇苹果！", Vector3(0, 4.3, 0), 18) # above the canopy sphere
	tree.add_child(_plaything(PLAYTHING.Kind.APPLE_TREE, Vector3(2.8, 3.4, 2.8), 1.0, true))

func _tipple(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := _box(self, node_name, size, pos, color, true)
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
	else:
		playground_event.emit(kind, _detail)

func _on_cabbage_goal(body: Node3D) -> void:
	if body.name != "CabbageBall":
		return
	if _cabbage_goal_cool > 0.0:
		return
	_cabbage_goal_cool = 5.0
	var goal := get_node_or_null("CabbageGoal")
	if goal != null:
		var tween := create_tween()
		tween.tween_property(goal, "position:x", goal.position.x + 0.25, 0.07)
		tween.tween_property(goal, "position:x", goal.position.x - 0.25, 0.07)
		tween.tween_property(goal, "position:x", goal.position.x, 0.1)
	_gag_at(Vector3(46, 26.4, 24.6), "GOOOAL！卷心菜应声入网！", 2.4)
	AchievementManager.unlock("cabbage_striker")
	playground_event.emit("cabbage_goal", "")

func _sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color, solid: bool) -> Node3D:
	var root: Node3D
	if solid:
		var body := AnimatableBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		# Tweens move this body (the cabbage ball); physics sync would fight
		# them every frame and rewind the kick to a fraction of its hop.
		body.sync_to_physics = false
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

func _on_generic_pipe_top_exited(body: Node3D, hint_label: Label3D, default_text: String) -> void:
	if body.is_in_group("player"):
		_player_on_pipe = false
		if hint_label:
			hint_label.text = default_text + "\n[ 跳上管顶按 S 钻入 ]"
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
	# Course 2 (Creek): Ox terrace heading into creek -> exits at Sheep meadow entrance
	_build_custom_pipe_entrance("SecretCreekPipe", "course_2", Vector3(70.0, 24.0, 24.0), "★ 像素溪流管道 ★", Color("38BDF8"))
	_build_custom_pipe_exit("SecretCreekPipeExit", Vector3(-38.0, 16.0, -20.0), "★ 溪流捷径 · 出口 ★", Color("38BDF8"))

	# Course 3 (Woodland): Sheep meadow heading into woodland -> exits at Horse pasture entrance
	_build_custom_pipe_entrance("SecretWoodlandPipe", "course_3", Vector3(-64.0, 16.0, -58.0), "★ 童话林间树洞 ★", Color("86A873"))
	_build_custom_pipe_exit("SecretWoodlandPipeExit", Vector3(16.0, 8.0, -88.0), "★ 林间捷径 · 出口 ★", Color("86A873"))

	# Course 4 (Courtyard): Horse pasture approach -> exits at final Showdown Gate
	_build_custom_pipe_entrance("SecretCourtyardPipe", "course_4", Vector3(-22.0, 4.0, -164.0), "★ 终极综艺管道 ★", Color("FF1493"))
	_build_custom_pipe_exit("SecretCourtyardPipeExit", Vector3(-78.0, 2.0, -220.0), "★ 终极大院 · 出口 ★", Color("FF1493"))

func _build_custom_pipe_entrance(pipe_name: String, course_id: String, pos: Vector3, label_text: String, pipe_color: Color) -> Node3D:
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

	var lux_pipe := ASSETS.make("PROP_C1_PIPE")
	if lux_pipe:
		pipe_body.add_child(lux_pipe)
	else:
		var pipe_mat := StandardMaterial3D.new()
		pipe_mat.albedo_color = pipe_color
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

		var rim_mesh := MeshInstance3D.new()
		var rim_cyl := CylinderMesh.new()
		rim_cyl.top_radius = 1.2
		rim_cyl.bottom_radius = 1.2
		rim_cyl.height = 0.2
		rim_mesh.mesh = rim_cyl
		rim_mesh.position.y = 0.58
		rim_mesh.material_override = pipe_mat
		pipe_body.add_child(rim_mesh)

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
	var hint := _label(pipe_root, "PipeSign", label_text + "\n[ 跳上管顶按 S 钻入 ]", Vector3(0, 2.2, 0), 22)

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
		_on_generic_pipe_top_exited(body, hint, label_text)
	)
	pipe_root.add_child(top_area)
	return pipe_root

func _build_custom_pipe_exit(exit_name: String, pos: Vector3, label_text: String, pipe_color: Color) -> Node3D:
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

	var lux_pipe := ASSETS.make("PROP_C1_PIPE")
	if lux_pipe:
		lux_pipe.scale = Vector3(1.0, 0.65, 1.0)
		pipe_body.add_child(lux_pipe)
	else:
		var pipe_mat := StandardMaterial3D.new()
		pipe_mat.albedo_color = pipe_color
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
	_label(exit_root, "ExitPipeSign", label_text, Vector3(0, 1.8, 0), 20)
	return exit_root
