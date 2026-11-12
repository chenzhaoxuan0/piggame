class_name MimicChest
extends Node3D

signal chest_opened(chest: MimicChest, is_mimic: bool)

const ASSETS = preload("res://scripts/art/asset_library.gd")

@export var is_mimic: bool = false
# Optional zone dressing (woodland fairytale): the storybook chest model
# replaces the procedural base+lid pair; the mimic breathing tell becomes a
# subtle model squish and opening becomes a tip-back + gold sparkle burst.
@export var lux_asset_id: String = ""

const COLOR_WOOD := Color("78350F") # Rich mahogany
const COLOR_GOLD := Color("FBBF24")
const COLOR_MIMIC_PURPLE := Color("7E22CE")

var is_triggered: bool = false
var chest_mesh: MeshInstance3D
var lid_mesh: MeshInstance3D
var _lux_visual: Node3D = null
var hint_label: Label3D
var trigger_area: Area3D

func _ready() -> void:
	_setup_visual()
	_setup_trigger_area()

func _setup_visual() -> void:
	chest_mesh = MeshInstance3D.new()
	chest_mesh.name = "ChestBase"
	var base_box := BoxMesh.new()
	base_box.size = Vector3(1.4, 0.8, 1.0)
	chest_mesh.mesh = base_box
	chest_mesh.position.y = 0.4
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = COLOR_WOOD
	chest_mesh.material_override = base_mat
	add_child(chest_mesh)

	lid_mesh = MeshInstance3D.new()
	lid_mesh.name = "ChestLid"
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(1.44, 0.4, 1.04)
	lid_mesh.mesh = lid_box
	lid_mesh.position = Vector3(0, 0.9, 0)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = COLOR_GOLD if not is_mimic else COLOR_WOOD
	lid_mesh.material_override = lid_mat
	add_child(lid_mesh)

	# Zone dressing: the storybook chest replaces the box pair.
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			_lux_visual = lux
			lux.position.y = -0.4
			chest_mesh.mesh = null
			lid_mesh.visible = false
			chest_mesh.add_child(lux)

	hint_label = Label3D.new()
	hint_label.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	hint_label.name = "ChestLabel"
	hint_label.font_size = 20
	hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint_label.position = Vector3(0, 1.8, 0)
	hint_label.visible = false
	add_child(hint_label)

func _setup_trigger_area() -> void:
	trigger_area = Area3D.new()
	trigger_area.name = "TriggerArea"
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = 2 # Player

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.8, 2.2)
	col.shape = box
	col.position.y = 0.9
	trigger_area.add_child(col)

	trigger_area.body_entered.connect(_on_player_entered)
	add_child(trigger_area)

func _process(_delta: float) -> void:
	if is_triggered:
		return
	var game_manager := get_tree().root.get_node_or_null("GameManager")
	var has_discern: bool = false
	if game_manager != null and "has_discern_skill" in game_manager:
		has_discern = game_manager.has_discern_skill

	var t := Time.get_ticks_msec() * 0.003
	if is_mimic:
		# Subtle Souls-like breathing tell: lid slowly rises and drops (or the
		# dressed model squishes by a couple of percent)
		if _lux_visual != null:
			_lux_visual.scale.y = 1.0 + sin(t) * 0.025
		lid_mesh.position.y = 0.9 + sin(t) * 0.04
		if has_discern:
			hint_label.visible = true
			hint_label.text = "【⚠ 宝箱怪】\n在诡异地呼吸，切勿触碰！"
			hint_label.modulate = Color("F43F5E")
		else:
			hint_label.visible = true
			hint_label.text = "zZz..."
			hint_label.font_size = 16
			hint_label.modulate = Color("A855F788")
	else:
		lid_mesh.position.y = 0.9
		if has_discern:
			hint_label.visible = true
			hint_label.text = "【★ 真实秘宝】\n散发着诱人的红薯香气！"
			hint_label.modulate = COLOR_GOLD
		else:
			hint_label.visible = true
			hint_label.text = "✨ 秘宝箱 ✨"
			hint_label.font_size = 16
			hint_label.modulate = Color("FDE047AA")

func _on_player_entered(player: Node3D) -> void:
	if is_triggered:
		return
	if not player.is_in_group("player") and not player.name.to_lower().contains("pig"):
		return
	is_triggered = true

	if is_mimic:
		_trigger_mimic_bite(player)
	else:
		_trigger_real_treasure(player)

func _trigger_mimic_bite(player: Node3D) -> void:
	# Snap lid wide open (dressed chest: the whole chest lunges and snaps back)
	var tween := create_tween()
	if _lux_visual != null:
		var lunge_dir := (player.global_position - global_position).normalized()
		tween.tween_property(_lux_visual, "position", _lux_visual.position + lunge_dir * 0.7, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_lux_visual, "position", _lux_visual.position, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(lid_mesh, "rotation:x", -deg_to_rad(75.0), 0.1)
		tween.tween_property(lid_mesh, "rotation:x", 0.0, 0.1)

	# Slapstick bite & knockback
	if player.has_method("apply_knockback"):
		var knock_dir := (player.global_position - global_position).normalized()
		player.apply_knockback(knock_dir * 14.0 + Vector3(0, 5.0, 0))

	chest_opened.emit(self, true)

func _trigger_real_treasure(player: Node3D) -> void:
	var tween := create_tween()
	if _lux_visual != null:
		# Dressed chest: tip back over 0.3 s and burst gold sparkles.
		tween.tween_property(_lux_visual, "rotation:x", -deg_to_rad(100.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_spawn_gold_sparkles()
	else:
		tween.tween_property(lid_mesh, "rotation:x", -deg_to_rad(90.0), 0.3)

	# Pop the golden sweet-potato toast; the COURSE owns the speed buff from
	# here (a wall-clock timer here could outlive the course into the farm, and
	# its save/restore could strand a stacked multiplier for good).
	var buff_lbl := Label3D.new()
	buff_lbl.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	buff_lbl.text = "🍠 获得黄金红薯！\n【移动速度提升！】"
	buff_lbl.font_size = 24
	buff_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	buff_lbl.modulate = Color("FACC15")
	buff_lbl.outline_modulate = Color("78350F")
	buff_lbl.outline_size = 6
	buff_lbl.position = Vector3(0, 2.2, 0)
	player.add_child(buff_lbl)
	var lbl_tween := buff_lbl.create_tween()
	lbl_tween.tween_property(buff_lbl, "position:y", buff_lbl.position.y + 1.0, 1.8)
	lbl_tween.tween_callback(buff_lbl.queue_free)

	chest_opened.emit(self, false)

func _spawn_gold_sparkles() -> void:
	# Gold sparkle burst for the dressed real chest (tween-driven, headless-safe).
	var fx := Node3D.new()
	fx.name = "ChestSparkles"
	add_child(fx)
	for i in 10:
		var mote := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var s := 0.08 + randf() * 0.07
		sphere.radius = s
		sphere.height = s * 2.0
		mote.mesh = sphere
		mote.position = Vector3(randf_range(-0.4, 0.4), 0.6, randf_range(-0.3, 0.3))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR_GOLD
		mat.emission_enabled = true
		mat.emission = COLOR_GOLD
		mat.emission_energy_multiplier = 1.8
		mote.material_override = mat
		fx.add_child(mote)
		var tw := fx.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mote, "position", mote.position + Vector3(randf_range(-0.8, 0.8), 1.2 + randf() * 0.8, randf_range(-0.8, 0.8)), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mote, "scale", Vector3.ONE * 0.05, 0.6)
	var cleanup := fx.create_tween()
	cleanup.tween_interval(0.8)
	cleanup.tween_callback(fx.queue_free)
