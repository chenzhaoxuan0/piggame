class_name MimicChest
extends Node3D

signal chest_opened(chest: MimicChest, is_mimic: bool)

@export var is_mimic: bool = false

const COLOR_WOOD := Color("78350F") # Rich mahogany
const COLOR_GOLD := Color("FBBF24")
const COLOR_MIMIC_PURPLE := Color("7E22CE")

var is_triggered: bool = false
var chest_mesh: MeshInstance3D
var lid_mesh: MeshInstance3D
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

	hint_label = Label3D.new()
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

	if has_discern:
		hint_label.visible = true
		if is_mimic:
			hint_label.text = "【⚠ 宝箱怪】\n在诡异地呼吸，切勿触碰！"
			hint_label.modulate = Color("F43F5E")
			# Breathing animation
			var t := Time.get_ticks_msec() / 300.0
			lid_mesh.position.y = 0.9 + sin(t) * 0.08
		else:
			hint_label.text = "【★ 真实秘宝】\n散发着诱人的红薯香气！"
			hint_label.modulate = COLOR_GOLD
	else:
		hint_label.visible = false

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
	# Snap lid wide open
	var tween := create_tween()
	tween.tween_property(lid_mesh, "rotation:x", -deg_to_rad(75.0), 0.1)
	tween.tween_property(lid_mesh, "rotation:x", 0.0, 0.1)

	# Slapstick bite & knockback
	if player.has_method("apply_knockback"):
		var knock_dir := (player.global_position - global_position).normalized()
		player.apply_knockback(knock_dir * 14.0 + Vector3(0, 5.0, 0))

	chest_opened.emit(self, true)

func _trigger_real_treasure(_player: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(lid_mesh, "rotation:x", -deg_to_rad(90.0), 0.3)
	chest_opened.emit(self, false)
