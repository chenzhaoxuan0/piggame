extends Node3D
## Gameplay roots and interaction state. Terrain is baked from farm_layout.gd.
signal chase_entered
signal chase_triggered(stage_id: String)
signal stage_chase_completed(gate_id: String)
signal secret_pipe_entered(course_id: String)
signal playground_event(kind: String, detail)
const ASSETS = preload("res://scripts/art/asset_library.gd")
const NPC_CLIPS = preload("res://scripts/art/npc_clips.gd")
const PUFF = preload("res://scripts/art/puff_emitter.gd")
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
	# 白盒清扫：圈门改挂 ENV_10_GATE_TIMBER（三扇分区门同款模型，缩到 4.4 m
	# 跨度）；烘焙栅栏插片与灰盒照旧隐藏，TimberGate 节点保留测试引用。
	# 离线兜底同上：模型缺失时白模照常显示。
	if ASSETS.make("ENV_10_GATE_TIMBER") != null:
		ASSETS.hide_procedural_visuals(_pigpen_gate)
		ASSETS.mount_visual(_pigpen_gate, "ENV_10_GATE_TIMBER", Vector3(4.4, 1.9, 0.42), "PigpenGateLux", true, "box")
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
	_build_sheep_meadow_extras()
	_build_ranch_race()
	_build_fence_apron()
	_begin_npc_life()
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
	_label(lever,"LeverLabel","F · 启动索道",Vector3(0,1.2,0),22)
	# 2026-11-15 实机反馈 #5：纪录牌迁到林间捷径出口旁的必经路口（出林间/
	# 进马场第一眼先见牌子再见马），同时它就是计时赛的启动台——对话开赛。
	var board := _interaction("RecordBoard","record_board",Vector3(24,8,-100),Vector3(1.7,2,.6))
	board.get_node("CollisionShape3D").position.y=1
	board.add_child(ASSETS.make("PROP_06"))
	_label(board,"BoardText","50 米直道 / 春季纪录 · 35 秒\n[ F ] 对话开赛！",Vector3(0,2.5,0),22)
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
		if environment.get_meta("layout_version",0)!=10:
			environment.free()
			environment=null
	if environment==null:
		environment=preload("res://scripts/art/mountain_environment.gd").new()
		add_child(environment)
		environment.build(self)
	else: add_child(environment)
	preload("res://scripts/art/dressing_batches.gd").restore(environment)
	_attach_apple_playthings()

## 牛耕地东侧的果园本来就是一片苹果树（烘进批次的 ENV_09_APPLE）——
## 2026-11-15 实机反馈：所有苹果树都该能撞出苹果雨，不该只有马场地标树
## 能玩。批次节点带着 placements 元数据（每棵树的世界变换），逐棵挂上与
## 地标树同一套的 APPLE_TREE 感应区：Shift 冲撞 → 苹果雨 → 当场吃三颗。
## 只接管烘好的装饰树；马场跑道旁的地标树与路口那棵手植树自带感应。
func _attach_apple_playthings() -> void:
	var attached := 0
	for batch in find_children("Dressing_ENV_09_APPLE_*", "MultiMeshInstance3D", true, false):
		for xf in batch.get_meta("placements", []):
			var trunk: Vector3 = (xf as Transform3D).origin
			var holder := Node3D.new()
			holder.name = "AppleTreeOrchard%d" % attached
			holder.add_to_group("apple_orchard")
			holder.position = trunk + Vector3.UP * 1.4
			add_child(holder)
			holder.add_child(_plaything(PLAYTHING.Kind.APPLE_TREE, Vector3(2.8, 3.4, 2.8), 1.0, true))
			attached += 1
	if attached > 0:
		_label(self, "OrchardLabel", "苹果园 · 冲刺撞树摇苹果！", Vector3(24, 26.8, 58), 20)

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

## Swap a white-box prop's flat VisualMesh for its Lux3D model. The fit
## contract (scale / base drop / offline box fallback) now lives once in
## FarmAssets.mount_visual so the courses and playthings share it too.
func _mount_lux(body: Node3D, asset_id: String, box_size: Vector3, lux_name := "", centered := true, fit_axis := "y") -> Node3D:
	return ASSETS.mount_visual(body, asset_id, box_size, lux_name, centered, fit_axis)

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
	_tick_ranch_race()
	_tick_horse_lap(delta)
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
	if id == "sheep" and _npc_tweens.has("sheep_sigh") and is_instance_valid(_npc_tweens["sheep_sigh"]):
		_npc_tweens["sheep_sigh"].kill()
	# 听完真相不再僵立：解除工作循环，当场欢呼一下再回到自由待机。
	var actor := _actor_of(id)
	if actor != null:
		actor.clear_force()
		actor.play_oneshot("celebrate", 1.0)
	if L.RESTS.has(id):
		var tween:=create_tween()
		tween.tween_property(_npcs[id],"position",L.RESTS[id],.8)
		_npc_tweens[id]=tween

func reset_world() -> void:
	for tween in _npc_tweens.values():
		if is_instance_valid(tween): tween.kill()
	_npc_tweens.clear()
	_horse_lapping = false
	for id in _npc_origins:
		_npcs[id].position=_npc_origins[id]
		_npcs[id].rotation=Vector3(0, PI, 0)
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
	# 世界复位后重启 NPC 生活感（上面的 kill 会把闲逛 tween 一并清掉）。
	_begin_npc_life()

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
	hide_safe_fences()  # 新追逐开始：上一轮的安全区栅栏收起
	if body.is_in_group("player"):
		chase_entered.emit()

func _on_stage_chase_trigger(body: Node3D, stage_id: String) -> void:
	if body.is_in_group("player"):
		chase_triggered.emit(stage_id)

func _build_all_gates() -> void:
	# Build Ox Gate at OxTerrace entrance
	_ox_gate = _create_timber_gate("ox", L.GATE_OX + Vector3.UP * 0.9, Vector3(4.8, 1.8, 0.4), "牛耕地门 · OX GATE")
	_named_gates["ox"] = _ox_gate
	# 触发区罩住门两侧的路面（旧版偏在门东 3.5 m、宽 3.5——从西沿路走来
	# 的猪根本进不了 x 31.75~35.25 的范围，安全区永不触发）。
	_area("GateOxTrigger", L.GATE_OX + Vector3.UP, Vector3(10.0, 3.0, 6.0), _on_gate_passed.bind("ox"))
	_label(self, "SafeSignOx", "恶犬止步 · 门内即安全区", L.GATE_OX + Vector3(0, 3.1, 0), 20)
	# 2026-11-18 实机反馈：安全区提示牌下面只有两块石头，什么门/栅栏都
	# 没有——建一道永久可见的矮木栅栏（1.1 m，无碰撞），标识「恶犬止步线」。
	_build_safe_fence("SafeFenceOx", L.GATE_OX, Vector3(1, 0, 0))

	# Build Sheep Gate at SheepMeadow entrance
	_sheep_gate = _create_timber_gate("sheep", L.GATE_SHEEP + Vector3.UP * 0.9, Vector3(4.8, 1.8, 0.4), "羊棚木门 · SHEEP GATE")
	_named_gates["sheep"] = _sheep_gate
	_area("GateSheepTrigger", L.GATE_SHEEP + Vector3.UP, Vector3(6.0, 3.0, 10.0), _on_gate_passed.bind("sheep"))
	_label(self, "SafeSignSheep", "恶犬止步 · 门内即安全区", L.GATE_SHEEP + Vector3(0, 3.1, 0), 20)
	_build_safe_fence("SafeFenceSheep", L.GATE_SHEEP, Vector3(0, 0, 1))

	# Build Horse Gate at HorsePasture entrance
	_horse_gate = _create_timber_gate("horse", L.GATE_HORSE + Vector3.UP * 0.9, Vector3(4.8, 1.8, 0.4), "马场围栏 · HORSE GATE")
	_named_gates["horse"] = _horse_gate
	_area("GateHorseTrigger", L.GATE_HORSE + Vector3.UP, Vector3(6.0, 3.0, 10.0), _on_gate_passed.bind("horse"))
	_label(self, "SafeSignHorse", "恶犬止步 · 门内即安全区", L.GATE_HORSE + Vector3(0, 3.1, 0), 20)
	_build_safe_fence("SafeFenceHorse", L.GATE_HORSE, Vector3(0, 0, 1))

## 安全区永久栅栏（2026-11-18 实机反馈）：提示牌下面只有石头没有结构。
## 一道矮木栅栏（4 根柱 + 双横梁，1.1 m，无碰撞纯视觉）横跨路面，永远
## 在那里——走到这里就看到「恶犬止步线」，追逐关门时门+门栓叠在上方。
## 安全区栅栏显示/隐藏：追逐在安全区结束时弹起（scale 弹入），新追逐
## 开始时收起。三个门口各一道，用节点名索引。
var _safe_fences: Dictionary = {}

func show_safe_fence(fence_name: String) -> void:
	var fence: Node3D = _safe_fences.get(fence_name, null)
	if fence == null or not is_instance_valid(fence):
		return
	fence.visible = true
	fence.scale = Vector3(1, 0.01, 1)
	var rise := create_tween()
	rise.tween_property(fence, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_safe_fences() -> void:
	for fence in _safe_fences.values():
		if fence is Node3D and is_instance_valid(fence):
			(fence as Node3D).visible = false

func _build_safe_fence(fence_name: String, centre: Vector3, road: Vector3) -> void:
	var side := road.cross(Vector3.UP).normalized() * 2.4
	var root := Node3D.new()
	root.name = fence_name
	add_child(root)
	# 默认隐藏：只在安全区触发（追逐结束）时弹起（2026-11-18 实机需求）。
	root.visible = false
	_safe_fences[fence_name] = root
	# 横梁长边须垂直于路方向：BoxMesh 长边默认沿 x，yaw 把它转到路的垂线。
	# road=(1,0,0) → 角度=PI/2（长边 x→z ✓）；road=(0,0,1) → 角度=PI（长边仍沿 x ✓）
	var yaw := road.signed_angle_to(Vector3.FORWARD, Vector3.UP)
	# 不走 _box（其 pastoral_surface 着色器会按地形规则雾化运行时 mesh）——
	# 栅栏用 StandardMaterial3D，永远实体可见。
	var make := func(n: String, sz: Vector3, p: Vector3, c: Color) -> Node3D:
		var node := Node3D.new()
		node.name = n
		node.position = p
		node.rotation.y = yaw
		root.add_child(node)
		var mi := MeshInstance3D.new()
		mi.name = "VisualMesh"
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 0.9
		mi.material_override = mat
		node.add_child(mi)
		return node
	for i in 3:
		make.call("Post%d" % i, Vector3(0.35, 1.5, 0.35), centre + side * (-1.0 + i) + Vector3(0, 0.75, 0), Color("5A4730"))
	for h in [0.3, 0.7, 1.1]:
		make.call("Beam%d" % int(h * 100), Vector3(5.2, 0.16, 0.12), centre + Vector3(0, h, 0), Color("7A6345"))
	# 中央 X 交叉——牧场栅栏的经典标志
	var ca: Node3D = make.call("CrossA", Vector3(5.0, 0.14, 0.1), centre + Vector3(0, 0.65, 0), Color("8B7355"))
	ca.rotation.z = 0.35
	var cb: Node3D = make.call("CrossB", Vector3(5.0, 0.14, 0.1), centre + Vector3(0, 0.65, 0), Color("8B7355"))
	cb.rotation.z = -0.35

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
	# 白盒清扫：门体由 ENV_10_GATE_TIMBER 模型绘制（门柱、横梁、双门扇一体
	# 生成，按碰撞盒整体适配）；程序柱梁与门扇保留结构但不再显示。开门时
	# 整扇门照旧整体隐藏（_set_barrier 的既有语义），门扇的开合转轴原样保留。
	# 离线兜底：先确认模型可用再隐藏白模——make 失败时灰盒照常显示（review 纠偏）。
	if ASSETS.make("ENV_10_GATE_TIMBER") != null:
		ASSETS.hide_procedural_visuals(gate)
		ASSETS.mount_visual(gate, "ENV_10_GATE_TIMBER", Vector3(size.x, size.y * 1.25, 0.4), "GateLux", true, "box")

	# 2026-11-17 实机反馈：关门（恶犬止步）后该有个门栓一样的横木表示
	# 「狗被挡在外面」——关门即显示、开门收起。斜跨双扇的一根粗闩木。
	# z=0.32：ENV_10_GATE_TIMBER 模型深度 0.4（z -0.2~0.2），旧 z=0.14 的
	# 门栓整根被模型几何包住（headless 实测 AABB 确认）——挪到模型前面。
	var bolt := _box(gate, "GateBolt", Vector3(size.x * 0.9, 0.22, 0.18), Vector3(0, size.y * 0.45, 0.32), Color("6B4F2E"), false)
	bolt.rotation.z = 0.18
	bolt.visible = false
	var label := _label(gate, "GateLabel_" + id, label_text + " / LOCKED", Vector3(0, size.y * 0.9, 0), 20)
	_gate_labels[id] = label
	return gate

func _build_road_obstacles() -> void:
	# Summit road logs aligned with L.LOGS[0]
	var log_pos_1: Vector3 = L.LOGS[0].a.lerp(L.LOGS[0].b, L.LOGS[0].t)
	var log1 := _box(self, "Log_Summit_1", Vector3(3.6, 0.55, 0.55), log_pos_1 + Vector3.UP * 0.25, Color("5A442E"), true)
	# 2026-11-15 实机反馈 #10：山顶倒木改成可动本体——烘焙共享网格里的横梁
	# 已从环境侧拆除（_summit_walls 跳过 LOGS[0]，layout_version 8→9），这根
	# 木头由 PROP_19_FALLEN_LOG 模型绘制（白盒长梁兜底），冲刺顶开时整体滚
	# 下坡，玩家看得见「第二条路开了」。
	_mount_lux(log1, "PROP_19_FALLEN_LOG", Vector3(3.6, 0.7, 0.7), "LogLux", true, "box")
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
	# 白盒清扫：林间倒木与山顶倒木穿同一件 PROP_19_FALLEN_LOG——环境侧的烘
	# 焙横梁已拆除（layout_version 9→10），碰撞盒照旧，模型贴盒装。
	_mount_lux(log2, "PROP_19_FALLEN_LOG", Vector3(3.6, 0.7, 0.7), "LogLux", true, "box")
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
	# 2026-11-15 实机反馈 #10：此前顶开后只有成就弹窗——可见的木头（曾烘在
	# 共享网格里）纹丝不动，玩家认不出发生了什么。现在木头本体滚下坡：沿
	# 坡向 ~6.5 m、翻滚两圈、落地扬起尘土圆环。
	log.collision_layer = 0
	for child in log.get_children():
		if child is CollisionShape3D:
			child.disabled = true
	var roll := Vector3(-3.0, -1.1, -5.4) # down-slope heading (west-south run)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(log, "position", log.position + roll, 1.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(log, "rotation:z", log.rotation.z - PI * 2.0, 1.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var landing: Vector3 = log.global_position + roll
	var settle := create_tween()
	settle.tween_interval(1.12)
	settle.tween_callback(func():
		if is_instance_valid(self):
			_dust_ring(landing + Vector3.UP * 0.1, 3.2)
	)
	_gag_at(log.global_position + Vector3.UP * 1.6, "轰隆隆——倒木翻着跟头滚下坡！第二条路，开了。", 2.6)
	AchievementManager.unlock("second_path")
	playground_event.emit("second_path", "")

## 尘土圆环：土色圆盘从落点扩散淡出（倒木落点等处共用，流星坑同款观感）。
func _dust_ring(pos: Vector3, max_r := 3.0) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "DustRing"
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
	ring.position = pos
	var puff := create_tween()
	puff.tween_property(disc, "top_radius", max_r, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	puff.parallel().tween_property(disc, "bottom_radius", max_r, 0.55)
	puff.parallel().tween_property(dust, "albedo_color:a", 0.0, 0.55)
	puff.tween_callback(ring.queue_free)

# ------------------------------------------------------------- sheep meadow
# 2026-11-15 实机反馈 #1/#2：羊矮棚旁的两样新玩场——真水池（原先是芦苇圈
# 里一块读不出来的异色地面）与除草挑战区。
const POND_CENTRE := Vector3(-14, 16, -45)
const WEEDING_CENTRE := Vector3(-47, 16.05, -49)
var _pond_slowed := false
var _pond_base_speed := 0.0
var _pond_medal_paid := false
var _weeds_total := 12
var _weeds_left := 12
var _weeding_label: Label3D

func _build_sheep_meadow_extras() -> void:
	_build_sheep_pond()
	_build_weeding_patch()

func _build_sheep_pond() -> void:
	# 真水池（2026-11-17 评测重做）：下沉池底 + 沙岸环 + 自定义水 shader
	# （顶点波/菲涅尔深浅/游走波光）+ 卵石收口 + 睡莲；入水溅水花与涟漪。
	# 水域感应契约不变：入水降速 55% + 扑通 gag + 首次点亮「落水猪」。
	var bed := MeshInstance3D.new()
	bed.name = "PondBed"
	var bed_disc := CylinderMesh.new()
	bed_disc.top_radius = 6.3
	bed_disc.bottom_radius = 5.4
	bed_disc.height = 0.5
	bed.mesh = bed_disc
	bed.material_override = _material(Color("2E4A44"))
	add_child(bed)
	bed.position = POND_CENTRE - Vector3.UP * 0.45
	var bank := MeshInstance3D.new()
	bank.name = "PondBank"
	var bank_ring := TorusMesh.new()
	bank_ring.inner_radius = 5.9
	bank_ring.outer_radius = 6.8
	bank_ring.rings = 28
	bank_ring.ring_segments = 10
	bank.mesh = bank_ring
	bank.material_override = _material(Color("B8A47E"))
	add_child(bank)
	bank.position = POND_CENTRE - Vector3.UP * 0.07
	var water := MeshInstance3D.new()
	water.name = "PondWater"
	var disc := CylinderMesh.new()
	disc.top_radius = 6.25
	disc.bottom_radius = 6.25
	disc.height = 0.08
	disc.radial_segments = 48
	water.mesh = disc
	var water_mat := ShaderMaterial.new()
	water_mat.shader = preload("res://scripts/art/pond_water.gdshader")
	water.material_override = water_mat
	add_child(water)
	water.position = POND_CENTRE - Vector3.UP * 0.12
	var breathe := create_tween().set_loops()
	breathe.tween_property(water, "position:y", POND_CENTRE.y - 0.09, 2.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(water, "position:y", POND_CENTRE.y - 0.15, 2.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in 9:
		var ang := TAU * i / 9.0
		var stone := _box(self, "PondStone%d" % i, Vector3(0.8, 0.4, 0.6),
			POND_CENTRE + Vector3(cos(ang) * 6.9, 0.0, sin(ang) * 6.0), Color("8D8073"), false)
		stone.rotation.y = ang
	for i in 3:
		var pad_ang := TAU * i / 3.0 + 0.5
		var pad := MeshInstance3D.new()
		pad.name = "LilyPad%d" % i
		var pad_disc := CylinderMesh.new()
		pad_disc.top_radius = 0.55
		pad_disc.bottom_radius = 0.55
		pad_disc.height = 0.04
		pad.mesh = pad_disc
		pad.material_override = _material(Color("4E8A4A"))
		add_child(pad)
		pad.position = POND_CENTRE + Vector3(cos(pad_ang) * 3.4, -0.06, sin(pad_ang) * 2.8)
		if i == 0:
			var flower := MeshInstance3D.new()
			flower.name = "LilyFlower"
			var bloom := SphereMesh.new()
			bloom.radius = 0.14
			bloom.height = 0.2
			flower.mesh = bloom
			flower.material_override = _material(Color("F2B8C6"))
			pad.add_child(flower)
			flower.position = Vector3(0.15, 0.12, 0.1)
	var ripple_loop := create_tween().set_loops()
	ripple_loop.tween_interval(2.4)
	ripple_loop.tween_callback(_pond_ambient_ripple)
	var pond := Area3D.new()
	pond.name = "PondWaterSense"
	pond.collision_layer = 0
	pond.collision_mask = 2
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 6.2
	cyl.height = 1.6
	shape.shape = cyl
	shape.position.y = 0.8
	pond.add_child(shape)
	add_child(pond)
	pond.position = POND_CENTRE
	pond.body_entered.connect(_on_pond_entered)
	pond.body_exited.connect(_on_pond_exited)

func _on_pond_entered(body: Node3D) -> void:
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	if not _pond_slowed and "move_speed" in body:
		_pond_slowed = true
		_pond_base_speed = body.move_speed
		body.move_speed = _pond_base_speed * 0.55
	_pond_splash(body.global_position)
	_gag_at(body.global_position + Vector3.UP * 1.4, "扑通！猪猪戏水～（水里走得慢）", 1.6)
	if not _pond_medal_paid:
		_pond_medal_paid = true
		AchievementManager.unlock("pig_paddle")
		playground_event.emit("pig_paddle", "")

func _on_pond_exited(body: Node3D) -> void:
	if not _pond_slowed:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	if "move_speed" in body and _pond_base_speed > 0.0:
		body.move_speed = _pond_base_speed
	_pond_slowed = false
	_pond_base_speed = 0.0

## 入水水花：一蓬水珠 + 两圈扩散涟漪（视觉-only，不碰碰撞）。
func _pond_splash(at: Vector3) -> void:
	var drops := PUFF.new()
	drops.name = "PondSplash"
	drops.tint = Color("BFE6F2")
	drops.puff_size = 0.07
	add_child(drops)
	drops.global_position = Vector3(at.x, POND_CENTRE.y - 0.05, at.z)
	drops.burst(24, 4.0)
	var cleanup := create_tween()
	cleanup.tween_interval(1.3)
	cleanup.tween_callback(drops.queue_free)
	_pond_ripple(at)
	_pond_ripple(at, 0.18)

func _pond_ambient_ripple() -> void:
	var ang := randf() * TAU
	var rad := randf_range(0.5, 4.5)
	_pond_ripple(POND_CENTRE + Vector3(cos(ang) * rad, 0, sin(ang) * rad))

func _pond_ripple(at: Vector3, delay := 0.0) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "PondRipple"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 20
	torus.ring_segments = 8
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("E8F7FB")
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	add_child(ring)
	ring.global_position = Vector3(at.x, POND_CENTRE.y - 0.05, at.z)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.9)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 0.9)
	tw.tween_callback(ring.queue_free)

func _build_weeding_patch() -> void:
	# 除草挑战：十二株灰绿杂草（与金黄嫩香草互为反差），啃一株少一株，
	# 全部啃光点亮「除草机」。草株复用 _herb_grass 建造器换杂草配色。
	_weeds_total = 12
	_weeds_left = _weeds_total
	var index := 0
	for row in 3:
		for col in 4:
			var weed := _herb_grass(WEEDING_CENTRE + Vector3(-3.3 + col * 2.2, 0, -2.0 + row * 2.0),
				Color("6B7F5A"), Color("9BB07C"))
			weed.name = "WeedPatch%d" % index
			var sense := Area3D.new()
			sense.name = "WeedSense"
			sense.collision_layer = 0
			sense.collision_mask = 2
			var shape := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 1.1
			shape.shape = sph
			shape.position.y = 0.5
			sense.add_child(shape)
			weed.add_child(sense)
			sense.body_entered.connect(_on_weed_eaten.bind(weed))
			index += 1
	_weeding_label = _label(self, "WeedingLabel", "除草挑战 · 吃光这片杂草！（0/%d）" % _weeds_total,
		WEEDING_CENTRE + Vector3(0, 2.6, 0), 18)

func _on_weed_eaten(body: Node3D, weed: Node3D) -> void:
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	if not is_instance_valid(weed) or weed.get_meta("eaten", false):
		return
	weed.set_meta("eaten", true)
	_weeds_left -= 1
	var munch := weed.create_tween()
	munch.tween_property(weed, "scale", Vector3(0.01, 0.01, 0.01), 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	munch.tween_callback(weed.queue_free)
	if _weeding_label != null:
		_weeding_label.text = "除草挑战 · 吃光这片杂草！（%d/%d）" % [_weeds_total - _weeds_left, _weeds_total]
	if _weeds_left <= 0:
		AchievementManager.unlock("lawn_mower")
		playground_event.emit("lawn_mower", "")
		_gag_at(WEEDING_CENTRE + Vector3.UP * 1.6, "绵羊欢呼：寸草不留！你是天生的除草机！", 2.4)

# ------------------------------------------------------------- ranch race
# 2026-11-15 实机反馈 #4/#5：马场计时赛。2026-11-16 重做成门架。2026-11-17
# 第三轮：门架/计分只在赛跑中出现；起点门 = 离纪录牌最近的检查门 1，逐门
# 1→6 回起点冲线；过门点亮身后跑道段。同日第四轮（实机反馈）：近道竞速
# 整套删除（内场门 / 抄近道章 / 解锁流），只保留原跑道一种竞速——进内场
# 即本轮取消，规则一眼看懂。
const RACE_TIMER_SCRIPT = preload("res://scripts/courses/components/race_timer.gd")
const RACE_TRACK_CENTRE := Vector3(40, 8, -120)
const RACE_GATES := [
	{"p": Vector3(27, 8, -109), "t": Vector3(1, 0, 0)},   # 1 北直道西段 = 起点/终点门（离纪录牌最近）
	{"p": Vector3(53, 8, -109), "t": Vector3(1, 0, 0)},   # 2 北直道东段
	{"p": Vector3(76, 8, -120), "t": Vector3(0, 0, -1)},  # 3 东弯顶（半圆心 65 + 半径 11）
	{"p": Vector3(53, 8, -131), "t": Vector3(-1, 0, 0)},  # 4 南直道东段
	{"p": Vector3(27, 8, -131), "t": Vector3(-1, 0, 0)},  # 5 南直道西段
	{"p": Vector3(4, 8, -120), "t": Vector3(0, 0, 1)},    # 6 西弯顶（15 - 11）
]
const RACE_FINISH := RACE_GATES[0].p  # 起点/终点门合一（检查门 1）
const RACE_SPAWN := Vector3(20, 8.35, -109)  # 起跑位：起点门西 7 m（判定圈外）
# 赛道中心线（与烘焙 ribbon 同一副数学：直道 2×50 m + 半圆 2×π×11 m），
# 段点亮砖沿它采样，砖心永远落在跑道上。参数 s∈[0,1) 从北直道西端出发
# 与比赛同向（向东）。
const RACE_RING_LEN := 100.0 + TAU * 11.0
const RACE_RECORD := 35.0
const RACE_CP_RADIUS := 6.0

# RaceTimer extends CanvasLayer but carries its own state/stop/format_time
# API - keep the reference untyped so those members resolve (a CanvasLayer-typed
# var would not compile against them).
var _race_timer = null
var _race_gantry: Label3D = null
var _race_running := false
var _race_next_out := 0        # 外圈六门按序指针
var _race_props: Array[Node3D] = []          # 门架/起点线/龙门/段砖——仅赛跑时可见
var _race_segment_tiles: Array[Node3D] = []  # 每段点亮的容器（过门即亮）
var _race_hint_msec := 0                     # 冲线提示冷却

func _build_ranch_race() -> void:
	_race_props.clear()
	_race_segment_tiles.clear()
	# 起点线贴在起点门下（与门架同组随赛跑显隐）。
	_race_props.append(_box(self, "RaceStartLine", Vector3(6.0, 0.08, 0.6), RACE_FINISH + Vector3(0, 0.06, 0), Color("FDE68A"), false))
	for i in RACE_GATES.size():
		_race_gate(i, RACE_GATES[i].p, RACE_GATES[i].t, Color("E74C3C"))
	_race_gantry = _label(self, "RaceGantry", "🏁 计时赛起点 🏁", RACE_FINISH + Vector3(0, 4.4, 0), 22)
	if _race_gantry is Node3D:
		_race_props.append(_race_gantry)
	_build_race_segments()
	_set_race_props_visible(false)

## 赛道中心线采样（与烘焙 ribbon 同一副数学）：s∈[0,1) 从北直道西端向东
## （比赛同向）走过 东弧 → 南直道（向西）→ 西弧 → 回北直道。返回位置与
## 行进切线角。2026-11-17 修复：旧砖用手估折线点，整圈黄砖与跑道模型错
## 位；现在砖心严格落在 ribbon 中心线上。
func _race_ring_pose(s: float) -> Dictionary:
	var centre := RACE_TRACK_CENTRE
	var d := fposmod(s, 1.0) * RACE_RING_LEN
	var straight := 50.0
	var arc := PI * 11.0
	if d < straight:  # 北直道，向东
		return {"p": Vector3(centre.x - 25.0 + d, centre.y + 0.055, centre.z + 11.0), "yaw": 0.0}
	d -= straight
	if d < arc:  # 东弧，angle 从 π/2 递减（北端 → 南端）
		var angle := PI * 0.5 - d / 11.0
		var pos := centre + Vector3(25.0 + cos(angle) * 11.0, 0.055, sin(angle) * 11.0)
		return {"p": pos, "yaw": -angle + PI * 0.5}
	d -= arc
	if d < straight:  # 南直道，向西
		return {"p": Vector3(centre.x + 25.0 - d, centre.y + 0.055, centre.z - 11.0), "yaw": PI}
	d -= straight
	var angle2 := -PI * 0.5 - (d - 0.0) / 11.0  # 西弧，南端 → 北端
	var pos2 := centre + Vector3(-25.0 + cos(angle2) * 11.0, 0.055, sin(angle2) * 11.0)
	return {"p": pos2, "yaw": -angle2 + PI * 0.5}

## 门位对应的赛道参数 s（比赛同向）。
func _race_gate_s(idx: int) -> float:
	var gate: Vector3 = RACE_GATES[idx].p
	var centre := RACE_TRACK_CENTRE
	# 北/南直道上的门按 x 线性；弯顶门在弧中点。
	# 2026-11-17 review P1-1 修复：两直道的条件与公式曾交叉配对（北门算出
	# 南门参数，段砖因此每段铺满 84% 整圈）。centre.z-11 = 南直道 z=-131，
	# 行进自东向西；centre.z+11 = 北直道 z=-109，自西向东。
	if absf(gate.z - (centre.z - 11.0)) < 0.5:  # 南直道 z = -131（自东向西）
		return (50.0 + PI * 11.0 + (centre.x + 25.0 - gate.x)) / RACE_RING_LEN
	if absf(gate.z - (centre.z + 11.0)) < 0.5:  # 北直道 z = -109（自西向东）
		return (gate.x - (centre.x - 25.0)) / RACE_RING_LEN
	if gate.x > centre.x:  # 东弯顶
		return (50.0 + PI * 11.0 * 0.5) / RACE_RING_LEN
	return (100.0 + PI * 11.0 * 1.5) / RACE_RING_LEN  # 西弯顶

## 赛道分段点亮：每段一串亮黄砖沿中心线采样（y 抬 5.5 cm 避开路面/白线
## 共面），默认全暗；过门 i 时点亮第 i 段（门 i 身后那段路）。
func _build_race_segments() -> void:
	for seg in RACE_GATES.size():
		var holder := Node3D.new()
		holder.name = "RaceSegment%d" % seg
		add_child(holder)
		var s0 := _race_gate_s(seg)
		var s1 := _race_gate_s((seg + 1) % RACE_GATES.size())
		if s1 <= s0:
			s1 += 1.0
		var length_m := (s1 - s0) * RACE_RING_LEN
		var tiles := maxi(1, ceili(length_m / 4.5))
		for i in tiles:
			var mid_s := s0 + (s1 - s0) * (i + 0.5) / tiles
			var pose := _race_ring_pose(mid_s)
			var tile := _box(holder, "RaceSeg%dTile%d" % [seg, i],
				Vector3(length_m / tiles + 1.1, 0.04, 4.2), pose.p, Color("FDE68A"), false)
			tile.rotation.y = pose.yaw
		holder.visible = false
		_race_segment_tiles.append(holder)
		_race_props.append(holder)

## 门架/起点线/龙门/段砖整组显隐——赛跑之外的牧场不摆这些。
func _set_race_props_visible(v: bool) -> void:
	for node in _race_props:
		if is_instance_valid(node):
			node.visible = v
	if not v:
		for tile in _race_segment_tiles:
			if is_instance_valid(tile):
				tile.visible = false

func _light_race_segment(seg: int) -> void:
	if seg >= 0 and seg < _race_segment_tiles.size() and is_instance_valid(_race_segment_tiles[seg]):
		_race_segment_tiles[seg].visible = true

## 检查门架：两柱 + 顶梁跨在跑道路径上（柱底微埋 0.15 防悬浮），顶梁沿
## 柱间连线，编号牌立在梁上。全部节点入 _race_props 随赛跑显隐。
func _race_gate(idx: int, centre: Vector3, tangent: Vector3, colour: Color) -> Label3D:
	var side := (tangent as Vector3).cross(Vector3.UP).normalized() * 3.3
	for tag in ["A", "B"]:
		var offset := side if tag == "A" else -side
		_race_props.append(_box(self, "RaceGate%dPost%s" % [idx, tag], Vector3(0.2, 2.7, 0.2), centre + offset + Vector3(0, 1.2, 0), colour, false))
	var beam := _box(self, "RaceGate%dBeam" % idx, Vector3(7.0, 0.22, 0.22), centre + Vector3(0, 2.62, 0), colour.lightened(0.18), false)
	beam.rotation.y = Vector3.RIGHT.signed_angle_to(side.normalized(), Vector3.UP)
	_race_props.append(beam)
	var label := _label(self, "RaceGate%dLabel" % idx, "检查门 %d" % (idx + 1), centre + Vector3(0, 3.15, 0), 15)
	_race_props.append(label)
	return label

## 纪录牌对话「开始计时赛」入口（office 的事件分发调用）。倒数期间猪被
## 锁在起点门前的起跑位，GO 一响解锁并开始计时；门架与段砖整组亮出。
func begin_race_trial(player: Node3D) -> bool:
	if _race_running:
		return false
	if not is_instance_valid(player) or player.control_mode != "explore":
		return false
	_race_next_out = 0
	player.reset_at(RACE_SPAWN)
	player.look_at(RACE_FINISH, Vector3.UP)
	if _race_timer != null and is_instance_valid(_race_timer):
		_race_timer.queue_free()
	_race_timer = RACE_TIMER_SCRIPT.new()
	_race_timer.name = "RanchRaceTimer"
	add_child(_race_timer)
	_set_race_props_visible(true)
	for tile in _race_segment_tiles:
		if is_instance_valid(tile):
			tile.visible = false
	player.set_control_mode("cinematic")
	_race_timer.countdown_finished.connect(func():
		if is_instance_valid(player):
			player.set_control_mode("explore")
		_race_running = true
		_gag_at(RACE_FINISH + Vector3.UP * 2.0, "跑！按序穿过检查门 1 到 6，回到检查门 1 冲线！", 2.2)
	)
	_race_timer.start_countdown(_race_gantry)
	return true

func _tick_ranch_race() -> void:
	if not _race_running or _race_timer == null or not is_instance_valid(_race_timer):
		return
	if _race_timer.state != "running" or not is_instance_valid(_player):
		return
	var p: Vector3 = _player.global_position
	# 越界保护：离赛道中心太远（进关/被传送）就取消这一轮。
	if p.distance_to(RACE_TRACK_CENTRE) > 60.0:
		_cancel_race("离场太远，本轮计时赛取消。")
		return
	# 内场检测（跑道内侧椭圆）：进内场即本轮取消——只有原跑道一种竞速。
	var oval := pow((p.x - 40.0) / 25.0, 2.0) + pow((p.z + 120.0) / 8.0, 2.0)
	if oval < 0.8:
		_cancel_race("计时赛要沿跑道跑——穿内场本轮作废，再来！")
		return
	# 外圈六门按序推进；过门即点亮身后的那段跑道。
	if _race_next_out < RACE_GATES.size():
		var gate: Vector3 = RACE_GATES[_race_next_out].p
		if p.distance_to(gate) < RACE_CP_RADIUS:
			_light_race_segment(_race_next_out)
			_race_next_out += 1
			if _race_next_out < RACE_GATES.size():
				_gag_at(RACE_GATES[_race_next_out].p + Vector3.UP * 2.2,
					"检查门 %d/%d ✓" % [_race_next_out, RACE_GATES.size()], 1.2)
	# 冲线判定：六门全过回到起点门即完赛停表。提示带 1.2 s 冷却防刷屏。
	if p.distance_to(RACE_FINISH) < RACE_CP_RADIUS:
		if _race_next_out >= RACE_GATES.size():
			_finish_race()
		else:
			var now := Time.get_ticks_msec()
			if now - _race_hint_msec > 1200:
				_race_hint_msec = now
				_gag_at(RACE_FINISH + Vector3.UP * 2.2,
					"还差 %d 道检查门——六门全过再回来冲线！" % (RACE_GATES.size() - _race_next_out), 1.8)

func _finish_race() -> void:
	_race_running = false
	var t: float = _race_timer.stop()
	_race_timer.fade_out(2.8)
	_set_race_props_visible(false)
	AchievementManager.unlock("steady_lap")
	var beat: bool = t >= 0.0 and t < RACE_RECORD
	if beat:
		AchievementManager.unlock("record_breaker")
	var verdict := "圈速：%s" % _race_timer.format_time(t)
	if beat:
		verdict += "——35 秒纪录，破了！"
	_gag_at(RACE_FINISH + Vector3.UP * 2.4, verdict, 2.6)
	playground_event.emit("race_finish", "%.2f" % t)

func _cancel_race(reason: String) -> void:
	_race_running = false
	if _race_timer != null and is_instance_valid(_race_timer):
		_race_timer.stop()
		_race_timer.fade_out(1.4)
	_set_race_props_visible(false)
	if is_instance_valid(_player):
		_gag_at(_player.global_position + Vector3.UP * 1.6, reason, 2.0)

# ------------------------------------------------------------- outside fence
# 2026-11-15 实机反馈 #19（A 期）：围栏开出缺口（烘焙侧 CROSSINGS 马场北/
# 西各一道），圈外贴崖加一圈可行走草带——猪真的能站到围栏外面去了，
# 首次出圈点亮「越狱惯犯」。坠落本身早已是软重生（回检查点），不再即死。
const APRON_TOP_Y := 7.70 # 条带顶面 7.95：压在牧场台面(8.0)与皮肤(7.95)之下 5cm，杜绝共面闪烁
var _fence_medal_paid := false

func _build_fence_apron() -> void:
	# 马场围栏外的崖边环带（北/南/东/西四条），顶面与牧场地面齐平。
	_box(self, "FenceApronN", Vector3(104, 0.5, 8), Vector3(40, APRON_TOP_Y, -147.4), Color("6F9D62"), true)
	_box(self, "FenceApronS", Vector3(104, 0.5, 8), Vector3(40, APRON_TOP_Y, -92.6), Color("6F9D62"), true)
	_box(self, "FenceApronE", Vector3(8, 0.5, 62.8), Vector3(94, APRON_TOP_Y, -120), Color("6F9D62"), true)
	_label(self, "FenceApronLabel", "围栏外 · 崖边野草带（缺口可以钻出去）", Vector3(40, 10.4, -147.4), 16)
	# 出圈判定：宽松——站上任意一条圈外草带即点亮。（西边没有环带：
	# 下山路的 approach 段贴着牧场西界走，不能盖路面。）
	for def in [["OutsideFenceN", Vector3(40, 8.9, -147.4), Vector3(104, 2.0, 8)],
			["OutsideFenceS", Vector3(40, 8.9, -92.6), Vector3(104, 2.0, 8)],
			["OutsideFenceE", Vector3(94, 8.9, -120), Vector3(8, 2.0, 62.8)]]:
		var sense := Area3D.new()
		sense.name = def[0]
		sense.collision_layer = 0
		sense.collision_mask = 2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = def[2]
		shape.shape = box
		sense.add_child(shape)
		add_child(sense)
		sense.position = def[1]
		sense.body_entered.connect(_on_outside_fence)

func _on_outside_fence(body: Node3D) -> void:
	if _fence_medal_paid:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_fence_medal_paid = true
	AchievementManager.unlock("fence_breaker")
	playground_event.emit("fence_breaker", "")
	_gag_at(body.global_position + Vector3.UP * 1.8, "越狱成功！围栏外的风，是自由的味道。", 2.4)

# ------------------------------------------------------------- npc life
# 2026-11-15 实机反馈 #18：对话前的 NPC 不再呆站——老牛在犁边缓缓踱步、
# 小羊在矮棚里蔫蔫地晃；追风从开机起就在跑道上跑圈（不再呆站在原地等
# 猪），猪进入牧场周边就全速奔回原点站定等对话，猪走开继续跑；听完真相
# 后照旧自由奔跑。追逐/对话期间马暂停（不抢戏、不挡路）。
var _horse_lapping := false
var _horse_waypoints: Array[Vector3] = []
var _horse_wp_index := 0
var _horse_home := Vector3(29, 8, -120)
var _horse_idle_time := 0.0
var _horse_halted := false

func _begin_npc_life() -> void:
	# 幂等：boot 时 reset_world 会清一遍 _npc_tweens（把这里的闲逛 tween 也
	# 杀掉），所以 reset_world 末尾会再次调用本函数重启生活感。
	for idle_key in ["ox", "sheep", "sheep_sigh"]:
		if _npc_tweens.has(idle_key) and is_instance_valid(_npc_tweens[idle_key]):
			(_npc_tweens[idle_key] as Tween).kill()
	# 追风：开机即沿跑道中心线跑圈——与段点亮砖同一套 ring 数学采样（直道
	# + 弯道弧），约 7 m 一个航点：折线近似弧的弓高 <0.6 m，全程落在半宽
	# 2.2 m 的跑道内。旧版六门+中点的十二边形在弯道上弦切进草地（2026-11-17
	# 实机反馈：马跑在跑道外）。
	_horse_waypoints.clear()
	var wp_count := roundi(RACE_RING_LEN / 7.0)
	for i in wp_count:
		_horse_waypoints.append(_race_ring_pose(float(i) / float(wp_count)).p)
	_horse_wp_index = 0
	_horse_lapping = true
	_horse_idle_time = 0.0
	# ---- 骨骼级生活感（2026-11-17 评测重做）：位移 tween 只负责走位，
	# 真正的「在干什么」由自定义骨夹表达——牛低头拉犁、羊耷拉脑袋、
	# 马奔跑步态、农场主拄棍环视。对话完成后 clear_force + celebrate。
	var ox_actor := _actor_of("ox")
	var ox_visual := _visual_of("ox")
	if ox_actor != null and ox_visual != null:
		var plow_clip: Animation = NPC_CLIPS.plow(ox_visual)
		if plow_clip != null:
			ox_actor.register_clip("plow", plow_clip, true)
			ox_actor.force_clip("plow", 0.85)
		if ox_visual.get_node_or_null("OxPlow") == null:
			ASSETS.attach_to_bone(ox_visual, "Body", _build_plow(), Vector3(0, 0.05, 1.05))
	var sheep_actor := _actor_of("sheep")
	var sheep_visual := _visual_of("sheep")
	if sheep_actor != null and sheep_visual != null:
		var mope_clip: Animation = NPC_CLIPS.mope(sheep_visual)
		if mope_clip != null:
			sheep_actor.register_clip("mope", mope_clip, true)
			sheep_actor.force_clip("mope", 1.0)
		var sigh_clip: Animation = NPC_CLIPS.sigh(sheep_visual)
		if sigh_clip != null:
			sheep_actor.register_clip("sigh", sigh_clip, false)
	var horse_actor := _actor_of("horse")
	var horse_visual := _visual_of("horse")
	if horse_actor != null and horse_visual != null:
		var stamp_clip: Animation = NPC_CLIPS.stamp(horse_visual)
		if stamp_clip != null:
			horse_actor.register_clip("stamp", stamp_clip, false)
		if horse_visual.get_node_or_null("HoofDust") == null:
			var hoof_dust := _make_dust("HoofDust", Color("C9B48A"), 14)
			hoof_dust.position = Vector3(0, 0.1, 0.3)
			horse_visual.add_child(hoof_dust)
	var farmer_actor := _actor_of("farmer")
	var farmer_visual := _visual_of("farmer")
	if farmer_actor != null and farmer_visual != null:
		var guard_clip: Animation = NPC_CLIPS.guard(farmer_visual)
		if guard_clip != null:
			farmer_actor.register_clip("guard", guard_clip, true)
			farmer_actor.force_clip("guard", 1.0)
	# 老牛：犁沟往返（±1.2m，慢速），到头转身再拉回来。首拍空等 1 秒：
	# reset_world 之后有「位置严格等于出生点」的钉子，第一帧不许有位移。
	var ox_origin: Vector3 = _npc_origins.get("ox", L.NPCS.ox)
	var ox_pace = create_tween().set_loops()
	ox_pace.tween_interval(1.0)
	ox_pace.tween_property(_npcs.ox, "position", ox_origin + Vector3(0, 0, 1.2), 4.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ox_pace.tween_property(_npcs.ox, "rotation:y", 0.0, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ox_pace.tween_property(_npcs.ox, "position", ox_origin - Vector3(0, 0, 1.2), 4.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ox_pace.tween_property(_npcs.ox, "rotation:y", PI, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_npc_tweens["ox"] = ox_pace
	# 小羊：蔫蔫地左右轻晃 + 每 7 秒叹一口气冒个「咩……」泡泡。
	var sheep_sway = create_tween().set_loops()
	sheep_sway.tween_property(_npcs.sheep, "rotation:z", 0.06, 2.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sheep_sway.tween_property(_npcs.sheep, "rotation:z", -0.06, 2.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_npc_tweens["sheep"] = sheep_sway
	var sheep_sigh = create_tween().set_loops()
	sheep_sigh.tween_interval(7.0)
	sheep_sigh.tween_callback(_sheep_sigh)
	_npc_tweens["sheep_sigh"] = sheep_sigh

func _tick_horse_lap(delta: float) -> void:
	if not _horse_lapping or not _npcs.has("horse") or not is_instance_valid(_npcs.horse):
		return
	# 独立 farm 测试架（无猪无相机）不跑马：生活感属于有关卡宿主的运行时。
	if not is_instance_valid(_player):
		return
	var horse: Node3D = _npcs.horse
	var actor := _actor_of("horse")
	var visual := _visual_of("horse")
	var dust: Node3D = visual.get_node_or_null("HoofDust") if visual != null else null
	# 2026-11-17 导演反馈：马完全自主跑圈训练，与猪的位置/朝向零绑定——
	# 猪站到身边也照跑。唯一截停 = 猪靠近按 F 进入与马的对话（office 置
	# _horse_halted），对话结束马从原地继续跑。马永远沿跑道环线跑（内场
	# 训练椭圆已删——两套环线共用索引曾让开赛瞬间马轨迹错乱）。
	var halted := _horse_halted and is_instance_valid(_player) and str(_player.control_mode) == "dialogue"
	if not halted:
		_horse_halted = false
	if halted:
		if actor != null:
			actor.clear_force()
			_horse_idle_time += delta
			if _horse_idle_time > 4.5:
				actor.play_oneshot("stamp", 1.0)
				_horse_idle_time = -randf_range(2.0, 5.0)
		if dust != null:
			dust.emitting = false
		return
	_horse_idle_time = 0.0
	# 2026-11-17 实机反馈：计时赛期间马曾被切去内场训练椭圆——航点索引在
	# 两套环线间错位，马的轨迹当场乱掉。马永远沿跑道中心线环线跑，赛跑
	# 期间也在原路线上（训练椭圆删除）。
	var waypoints := _horse_waypoints
	var target: Vector3 = waypoints[_horse_wp_index % waypoints.size()]
	var to := target - horse.global_position
	to.y = 0.0
	if to.length() < 1.2:
		_horse_wp_index = (_horse_wp_index + 1) % waypoints.size()
		return
	horse.global_position += to.normalized() * minf(5.2 * delta, to.length())
	_face_toward(horse, horse.global_position + to.normalized(), delta)
	if actor != null:
		actor.force_clip("run", 1.0)
	if dust != null:
		dust.emitting = true

## 对话截停开关：office 在与马开对话时置 true、close_dialogue 置 false。
func set_horse_halted(halted: bool) -> void:
	_horse_halted = halted

## 平滑转向：四元数球面插值代替 look_at 瞬移朝向（跑圈过弯不再「啪」地扭头）。
func _face_toward(body: Node3D, target: Vector3, delta: float) -> void:
	var dir := target - body.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01: return
	var goal := body.global_transform.looking_at(target, Vector3.UP)
	var cur := body.global_transform.basis.get_rotation_quaternion()
	body.global_transform.basis = Basis(cur.slerp(goal.basis.get_rotation_quaternion(), minf(1.0, 7.0 * delta)))

func _actor_of(id: String) -> Node:
	if not _npcs.has(id) or not is_instance_valid(_npcs[id]): return null
	var found: Array = _npcs[id].find_children("ActorAnimation", "Node", true, false)
	return found[0] if not found.is_empty() else null

func _visual_of(id: String) -> Node3D:
	if not _npcs.has(id) or not is_instance_valid(_npcs[id]): return null
	for child in _npcs[id].get_children():
		if child is Node3D and str(child.name).begins_with("CHAR_"):
			return child
	return null

func _make_dust(dust_name: String, tint: Color, count: int) -> Node3D:
	# tween-mesh 发射器（项目惯例）：CPUParticles3D 会让 headless dummy 渲染器
	# 随机 segfault，全量套件曾因此整轮崩溃。
	var dust := PUFF.new()
	dust.name = dust_name
	dust.tint = tint
	dust.rate = float(count)
	dust.puff_size = 0.09
	dust.speed = 0.7
	dust.emitting = false
	return dust

## 老牛的木犁：挂在 Body 骨上跟着步态起伏，犁刃处持续扬土。
func _build_plow() -> Node3D:
	var plow := Node3D.new()
	plow.name = "OxPlow"
	# 1.4×：原尺寸木色犁在牛身后读不出来，放大一档才像「在拉犁」。
	plow.scale = Vector3(1.4, 1.4, 1.4)
	# 挂骨 socket 的朝向使犁局部 +z 指向牛身后：梁/扶手朝 +z 伸才露在牛体外。
	_box_mesh(plow, Vector3(0.3, 0.26, 0.08), Vector3(0, 0.14, 0.05), _material(Color("515A5A"))).rotation.x = -0.4
	_box_mesh(plow, Vector3(0.1, 0.1, 1.1), Vector3(0, 0.42, 0.4), _material(Color("8F6A42"))).rotation.x = 0.35
	_box_mesh(plow, Vector3(0.06, 0.5, 0.06), Vector3(-0.2, 0.72, 0.1), _material(Color("9C805E"))).rotation.x = 0.3
	_box_mesh(plow, Vector3(0.06, 0.5, 0.06), Vector3(0.2, 0.72, 0.1), _material(Color("9C805E"))).rotation.x = 0.3
	var dust := _make_dust("PlowDust", Color("A8906B"), 10)
	dust.position = Vector3(0, 0.1, 0.15)
	dust.emitting = true
	plow.add_child(dust)
	return plow

func _sheep_sigh() -> void:
	var actor := _actor_of("sheep")
	if actor != null:
		actor.play_oneshot("sigh", 1.0)
	if not _npcs.has("sheep") or not is_instance_valid(_npcs.sheep): return
	var bubble := _label(self, "SheepSigh%d" % Time.get_ticks_msec(), "咩……",
		_npcs.sheep.global_position + Vector3(0, 2.7, 0), 20)
	bubble.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.4)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.6)
	tw.tween_callback(bubble.queue_free)

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
	# 2026-11-15 实机反馈 #6：取消林间分赛场（马场没有卷心菜、牛耕地的菜又
	# 太远，实战不可达成）——全满贯改为三门：联赛 + 猪圈 + 溪桥。
	_build_pitch_fence()

	# --- Tippables farm-wide (sprint to topple). Each keeps its box collision;
	# the Lux3D dressing draws the real object. 2026-11-15 实机反馈 #14：拆家
	# 小队从「下山路沿线的五件」扩成全农场——每个区域都有得撞，任意翻够
	# 五件即付（每件只能翻一次，计数天然按件数）。
	_tipple("Barrel_Zigzag", Vector3(-34, 25.8, 101), Vector3(0.9, 1.1, 0.9), Color("8F6A42"), "ENV_09_BARREL", "BarrelLux")
	_tipple("Bucket_Pen", Vector3(6, 32.15, 104), Vector3(0.7, 0.8, 0.7), Color("9C805E"), "ENV_09_BARREL", "BucketLux")
	_tipple("Crate_Fields", Vector3(20, 24.15, 25), Vector3(1.0, 1.0, 1.0), Color("B08968"), "ENV_06_CRATE", "CrateLux")
	_tipple("Wheelbarrow_Creek", Vector3(48, 24.15, 22), Vector3(1.4, 0.7, 0.9), Color("B0543F"), "ENV_09_WHEELBARROW", "WheelbarrowLux")
	_tipple("Wheelbarrow_Meadow", Vector3(-33, 16.6, -50), Vector3(1.4, 0.7, 0.9), Color("B0543F"), "ENV_09_WHEELBARROW", "WheelbarrowLux")
	_tipple("Crate_Meadow", Vector3(-57, 16.1, -46), Vector3(1.0, 1.0, 1.0), Color("B08968"), "ENV_06_CRATE", "CrateLux")
	_tipple("WoolBale_Meadow", Vector3(-45, 16.6, -30), Vector3(1.5, 0.9, 1.1), Color("E8E2CE"), "ENV_09_WOOL", "WoolBaleLux")
	_tipple("Barrel_Track", Vector3(58, 8.6, -132), Vector3(0.9, 1.1, 0.9), Color("8F6A42"), "ENV_09_BARREL", "BarrelLux")
	_tipple("Pump_Track", Vector3(70, 8.1, -124), Vector3(0.5, 1.2, 0.5), Color("7A8B99"), "ENV_09_PUMP", "PumpLux")
	_tipple("Barrel_GateCourt", Vector3(-77, 2.1, -219), Vector3(0.9, 1.1, 0.9), Color("8F6A42"), "ENV_09_BARREL", "BarrelLux")
	_build_scarecrow(Vector3(14, 24, 48))

	# --- Six nibble-grass tufts along the descent
	# 2026-11-15 实机反馈 #12：专属「嫩香草」——金黄三叶草束 + 奶油冠，与路边
	# 的绿蕨/绿芦苇一眼区分。2026-11-16 实机反馈两笔一并落地：①换 Lux3D
	# PROP_23 模型（文生 3D，土黄采样在线提亮成金黄）；②多丛落在台地外的
	# 山坡上根本走不到——六丛全部钉回路面/台地内，边走边啃不再绕圈外。
	var herb_marks := ["❶", "❷", "❸", "❹", "❺", "❻"]
	var herb_i := 0
	for grass_pos in [
		Vector3(0.0, 31.62, 83),  # ❶ 出门口正前路中央（路面插值 31.5 + 模型居中挂载的底探余量，旧 y=31.4 比 softmax 路面还低，半丛埋进地里）（旧位 2.5,84 紧贴圈墙被挡、5.0,80 落到路外——路中央、离门 5 m，避开 ChaseTrigger_1 区（z≤81）并给传送落地留 2 m 物理滑移余量）
		Vector3(-27.5, 26.4, 99), # ❷ zigzag 北弯内侧（原 -36,95 在 summit 台地外山坡）
		Vector3(14, 24.4, 58),    # ❸ 牛耕地石堆缺口内（台地内，保留）
		Vector3(36, 21.3, 10),    # ❹ 溪谷路东岸（原 44,14 在坡外）
		Vector3(-45, 16.3, -55),  # ❺ 羊棚草甸林间口（台地内，保留）
		Vector3(30, 8.3, -112),   # ❻ 马场围栏内（保留）
	]:
		var tuft := _herb_grass(grass_pos)
		tuft.name = "NibbleGrass"
		tuft.add_child(_plaything(PLAYTHING.Kind.GRASS, Vector3(2.6, 2.0, 2.6), 2.5))
		# 2026-11-17 实机反馈：玩家只找到 5 丛（成就却要 6 丛）——每丛头顶
		# 挂编号牌 ❶-❻，照着编号找齐。
		var mark: String = herb_marks[herb_i]
		herb_i += 1
		_label(tuft, "HerbTuftMark", mark, Vector3(0, 1.5, 0), 24)
	_label(self, "HerbGrassHint", "★ 嫩香草 ★ 下山路上一共六丛，猪猪的最爱", Vector3(0.0, 33.2, 83), 18)

	# --- Hay dive by the sheep-shed pond (2026-11-16 实机反馈：原西 zigzag 坡底
	# 的落点在圈外根本走不到——搬到羊矮棚水边：三级干草跳台在池塘东北岸，
	# 顺台阶登上顶、朝南一跃入垛，跳进溅草的水边画面里)。
	# Solid like the pen stack: the diving pig lands in it (and squashes it)
	# instead of ghosting through the visual.
	var hay := _box(self, "HayDiveStack", Vector3(2.8, 1.5, 2.8), Vector3(-6, 16.75, -40), Color("E8C86A"), true)
	_mount_lux(hay, "PROP_11_HAY_STACK", Vector3(2.8, 1.5, 2.8), "HaystackLux")
	var hay_thing: FarmPlaything = _plaything(PLAYTHING.Kind.HAYSTACK, Vector3(2.8, 2.6, 2.8), 0.8)
	hay.add_child(hay_thing)
	hay_thing.played.connect(_on_hay_dive.bind(hay, 0.75, hay.position.y))
	_label(self, "HayDiveLabel", "草垛跳水 · 从跳台跳进来！", Vector3(-6, 18.7, -40), 18)
	# 2026-11-15 实机反馈 #11：满分入坑看不出在哪完成——草垛顶立靶环，
	# 起跳点立牌 + 箭头，指明「从哪跳、朝哪跳」。
	var ring := MeshInstance3D.new()
	ring.name = "HayDiveTargetRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.22
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("E74C3C")
	ring.material_override = ring_mat
	hay.add_child(ring)
	ring.position = Vector3(0, 1.56, 0)
	# 三级干草台阶北低南高（每级 0.8 m 一跳即上），顶台面 y=18.4 正对草垛顶
	# (17.5)——起跳弧线叠加 0.9 m 落差，入垛下落速度稳过 4 m/s 的计分线。
	for i in 3:
		_box(self, "HayDiveStep%d" % i, Vector3(2.6, 0.8, 1.5), Vector3(-6, 16.4 + i * 0.8, -33.0 - i * 1.4), Color("D9B36A"), true)
	var launch := Vector3(-6.0, 18.4, -36.3)
	_label(self, "HayDiveLaunchLabel", "满分入坑 · 登上草阶，朝草垛起跳！", launch + Vector3(0, 1.7, 0), 18)
	# 指示牌立台侧地面（第一级台阶旁）——立台顶正前方会挡起跳视线与跳跃
	# 动线（验收截图实锤）；箭头贴顶台前沿面。
	_box(self, "HayDiveSignPost", Vector3(0.14, 1.2, 0.14), Vector3(-4.2, 16.6, -35.0), Color("8B6846"), false)
	_box(self, "HayDiveSignBoard", Vector3(1.3, 0.55, 0.08), Vector3(-4.2, 17.35, -35.0), Color("C9A35E"), false)
	var aim_yaw := (hay.global_position - launch).signed_angle_to(Vector3.FORWARD, Vector3.UP)
	for i in 2:
		var chev := _box(self, "HayDiveChevron%d" % i, Vector3(0.72, 0.05, 0.16), launch + Vector3(0, 0.06, -0.2), Color("FFFBEB"), false)
		chev.rotation.y = aim_yaw + (-0.7 if i == 0 else 0.7)

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

	# --- Shakeable apple trees (charged shove rains apples). The horse track
	# keeps its landmark tree; a second one in the ox terrace means 牛顿的苹果
	# is earnable where the potatoes already grow, not only by the far track
	# (2026-11-15 playtest #13). 树基 = 台地地面 + 1.3（盒子半高）。
	_build_apple_tree("AppleTree", Vector3(76, 9.3, -108))
	_build_apple_tree("AppleTreeOxField", Vector3(8, 25.3, 34))

## 嫩香草（2026-11-15 实机反馈 #12）：「食草动物的本分」的专用建模——
## 金黄三叶草束 + 奶油色小冠，无碰撞（plaything 感应即啃）、无发光。
## 与环境装饰的绿蕨/绿芦苇一眼可辨。配色可参数化：#1 除草挑战的杂草
## 复用同一建造器换灰绿杂草色。
## 2026-11-16 实机反馈：嫩香草换 Lux3D PROP_23_HERB_GRASS 模型（文生 3D +
## Blender 平涂，1200 面）。采样调色偏土黄/卡其——挂载后统一提亮并向暖金
## 推（_golden_tint），保住「与绿草一眼区分」的设计意图；离线（catalog 缺
## 失）时程序三叶草球仍是兜底。杂草走参数化配色，不挂模型。
func _herb_grass(pos: Vector3, leaf_color := Color("E9C46A"), crown_color := Color("FFF3C4")) -> Node3D:
	var tuft := Node3D.new()
	tuft.name = "HerbTuft"
	add_child(tuft)
	tuft.position = pos
	if leaf_color == Color("E9C46A") and _mount_lux(tuft, "PROP_23_HERB_GRASS", Vector3(1.0, 0.9, 1.0), "HerbLux", true, "y") != null:
		_golden_tint(tuft)
		return tuft
	# 2026-11-17 实机反馈：除草挑战的杂草同样换 Lux3D 模型（PROP_24 灰绿
	# 原色，垂叶病态感与嫩香草的饱满金黄一眼两分）；离线兜底仍走程序球。
	if leaf_color == Color("6B7F5A") and _mount_lux(tuft, "PROP_24_WEED", Vector3(0.9, 0.8, 0.9), "WeedLux", true, "y") != null:
		return tuft

	for i in 3:
		var leaf := MeshInstance3D.new()
		leaf.name = "HerbLeaf%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 0.32
		sphere.height = 0.64
		leaf.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = leaf_color.lightened(0.07 * i)
		mat.roughness = 0.95
		leaf.material_override = mat
		var ang := TAU * i / 3.0
		leaf.position = Vector3(cos(ang) * 0.26, 0.34, sin(ang) * 0.26)
		leaf.scale = Vector3(1.0, 0.72, 1.0)
		tuft.add_child(leaf)
	var crown := MeshInstance3D.new()
	crown.name = "HerbCrown"
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.18
	crown_mesh.height = 0.36
	crown.mesh = crown_mesh
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = crown_color
	crown_mat.roughness = 0.9
	crown.material_override = crown_mat
	crown.position = Vector3(0, 0.74, 0)
	tuft.add_child(crown)
	return tuft

## 嫩香草的金黄补偿：Lux3D 采样调色偏土黄/卡其，统一提亮并向暖金推。
## 材质逐实例 duplicate 后再改——_flat_materials 的平涂材质跨实例共享，
## 直接改会叠加提亮（六丛 ×1.16 直接过曝）。
func _golden_tint(root: Node3D) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_i := mesh as MeshInstance3D
		var mat := mesh_i.get_active_material(0)
		if mat is StandardMaterial3D:
			var flat := (mat as StandardMaterial3D).duplicate()
			var c: Color = flat.albedo_color
			flat.albedo_color = Color(minf(c.r * 1.16, 1.0), minf(c.g * 1.14, 1.0), c.b * 0.78)
			mesh_i.material_override = flat

func _build_apple_tree(tree_name: String, pos: Vector3) -> void:
	var tree := _box(self, tree_name, Vector3(0.5, 2.6, 0.5), pos, Color("665A48"), true)
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
		# 2026-11-15 实机反馈 #6：全满贯改三门——林间分赛场（马场草甸）已撤，
		# 那片场地没有卷心菜可踢，实战不可达成。
		var slam := true
		for net_id in ["cabbage_goal_pitch", "cabbage_goal_pen", "cabbage_goal_creek"]:
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
	var bolt := gate.find_child("GateBolt", true, false) as Node3D
	if bolt != null:
		bolt.visible = not open
	var leaf_l := gate.find_child("LeafL", true, false) as Node3D
	var leaf_r := gate.find_child("LeafR", true, false) as Node3D
	if leaf_l and leaf_r:
		var tween := create_tween().set_parallel(true)
		var angle := 1.45 if open else 0.0
		tween.tween_property(leaf_l, "rotation:y", angle, 0.5)
		tween.tween_property(leaf_r, "rotation:y", -angle, 0.5)

func _on_gate_passed(body: Node3D, gate_id: String) -> void:
	if body.is_in_group("player"):
		# 安全区栅栏无条件弹起（2026-11-18 实机反馈）：不管有没有追逐在跑，
		# 穿过安全区线 = 「狗被挡在外面了」——栅栏是这条线的视觉标记。
		show_safe_fence("SafeFence" + gate_id.capitalize())
		var main_loop := Engine.get_main_loop() as SceneTree
		var gm = main_loop.root.get_node_or_null("GameManager") if main_loop and main_loop.root else null
		var in_chase: bool = gm.is_in_chase() if gm and gm.has_method("is_in_chase") else false
		if in_chase:
			# When the player races across the gate during chase, slam it shut!
			set_named_gate_open(gate_id, false)
			stage_chase_completed.emit(gate_id)
			# 弃追反馈：狗在判定点（门）前刹住折返，玩家看得见为什么安全了。
			var gate: StaticBody3D = _named_gates.get(gate_id, null)
			if is_instance_valid(gate):
				_gag_at(gate.global_position + Vector3.UP * 2.4, "恶犬在门前刹住脚步，悻悻折返……", 2.4)
			show_safe_fence("SafeFence" + gate_id.capitalize())

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
