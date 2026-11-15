class_name PlungerProp
extends Node3D

# One toilet-plunger round for the woodland armory: walk close, press F/E,
# and the plunger joins the pig's ammo count (PlungerLauncher keeps the tally).
# Same pickup contract as PineconeProp; the launcher listens via `collected`.

signal collected

@export var lux_asset_id: String = "PROP_C3_PLUNGER" # slot ready, procedural fallback ships

const ASSETS = preload("res://scripts/art/asset_library.gd")
# 2026-11-15 实机反馈：搋子可以重复拾取——收走后地里冷却一会儿再长出来。
# 实时长可覆写（测试用短冷却验证再生）。
var respawn_seconds := 18.0

const CUP_RED := Color("C0392B")
const HANDLE_WOOD := Color("8B5A2B")

var _collected := false
var _player_near: Node3D = null
var _cup_mesh: MeshInstance3D
var _prompt_lbl: Label3D
var _pickup_area: Area3D
var _visuals: Array[Node3D] = []

func _ready() -> void:
	_setup_visual()
	_setup_pickup_area()

func _setup_visual() -> void:
	var rig := Node3D.new()
	rig.name = "PlungerRig"
	rig.position.y = 0.18
	add_child(rig)

	_cup_mesh = MeshInstance3D.new()
	_cup_mesh.name = "PlungerMesh"
	var cup := CylinderMesh.new()
	cup.top_radius = 0.16
	cup.bottom_radius = 0.24
	cup.height = 0.22
	_cup_mesh.mesh = cup
	var cup_mat := StandardMaterial3D.new()
	cup_mat.albedo_color = CUP_RED
	cup_mat.roughness = 0.55
	_cup_mesh.material_override = cup_mat
	_cup_mesh.position.y = 0.11
	rig.add_child(_cup_mesh)

	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.035
	stick_mesh.bottom_radius = 0.035
	stick_mesh.height = 0.5
	stick.mesh = stick_mesh
	var stick_mat := StandardMaterial3D.new()
	stick_mat.albedo_color = HANDLE_WOOD
	stick_mat.roughness = 0.85
	stick.material_override = stick_mat
	stick.position.y = 0.45
	rig.add_child(stick)
	rig.rotation.z = 0.5 # lying on its side, ready to grab
	_visuals.append(rig)

	# Zone dressing slot: a Lux3D plunger replaces the procedural rig once minted.
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			rig.visible = false
			lux.position.y = 0.25
			lux.rotation.z = 0.5
			add_child(lux)
			_visuals.append(lux)

	_prompt_lbl = Label3D.new()
	_prompt_lbl.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	_prompt_lbl.name = "PromptLabel"
	_prompt_lbl.text = "[F] 拾取马桶搋子"
	_prompt_lbl.font_size = 20
	_prompt_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_lbl.modulate = Color("FEF08A")
	_prompt_lbl.outline_modulate = Color("451A03")
	_prompt_lbl.outline_size = 4
	_prompt_lbl.position = Vector3(0, 1.1, 0)
	_prompt_lbl.visible = false
	add_child(_prompt_lbl)

func _setup_pickup_area() -> void:
	_pickup_area = Area3D.new()
	_pickup_area.name = "PickupArea"
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask = 2 # Player

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	shape.shape = sphere
	shape.position.y = 0.5
	_pickup_area.add_child(shape)

	_pickup_area.body_entered.connect(_on_player_entered)
	_pickup_area.body_exited.connect(_on_player_exited)
	add_child(_pickup_area)

func _on_player_entered(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("player") or body.name.to_lower().contains("pig"):
		_player_near = body
		_prompt_lbl.visible = true
		_prompt_lbl.modulate = Color("FDE047")

func _on_player_exited(body: Node3D) -> void:
	if body == _player_near:
		_player_near = null
		_prompt_lbl.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _collected or _player_near == null:
		return
	if event.is_action_pressed("action_interact") and not event.is_echo():
		_collect()
		get_viewport().set_input_as_handled()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	_prompt_lbl.visible = false
	var impact := Label3D.new()
	impact.font = _prompt_lbl.font
	# 2026-11-15 实机反馈 #3：拾取瞬间就地教会用法——只说「到手」不说
	# 怎么用，玩家会揣着一兜搋子走完整条林间（马桶骑士就此锁死）。
	impact.text = "🪠 搋子到手！按 [Q] 朝恶犬发射！"
	impact.font_size = 22
	impact.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact.modulate = Color("86EFAC")
	impact.outline_modulate = Color("14532D")
	impact.outline_size = 5
	impact.global_position = global_position + Vector3(0, 1.3, 0)
	get_tree().root.add_child(impact)
	var t := impact.create_tween()
	t.tween_property(impact, "global_position:y", impact.global_position.y + 0.8, 0.9)
	t.parallel().tween_property(impact, "modulate:a", 0.0, 0.9)
	t.tween_callback(impact.queue_free)
	collected.emit()
	_begin_respawn()

## 2026-11-15 实机反馈：搋子可以重复拾取——收走后隐藏并关掉感应，冷却
## 到点再弹出来（掉落补充同款逻辑），弹药永远不会永久枯竭。
func _begin_respawn() -> void:
	_set_pickup_active(false)
	await get_tree().create_timer(respawn_seconds).timeout
	if not is_inside_tree():
		return # 赛道退出时随树释放；等待到点的协程到这里就自灭
	_collected = false
	_player_near = null
	_set_pickup_active(true)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector3.ONE, 0.25) \
		.from(Vector3(0.01, 0.01, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_pickup_active(on: bool) -> void:
	for visual in _visuals:
		if is_instance_valid(visual):
			visual.visible = on
	_prompt_lbl.visible = false
	_pickup_area.set_deferred("monitoring", on)
