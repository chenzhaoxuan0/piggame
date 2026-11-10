class_name RacingFinishGate
extends Node3D

signal finish_line_crossed(player: Node3D)

@export var gate_width: float = 12.0
@export var gate_height: float = 6.0

const COLOR_STEEL := Color("1E293B")
const COLOR_NEON_CYAN := Color("06B6D4")
const COLOR_NEON_YELLOW := Color("FACC15")

var is_finished: bool = false
var banner_label: Label3D
var timer_label: Label3D
var trigger_area: Area3D

func _ready() -> void:
	_setup_frame()
	_setup_banner()
	_setup_trigger()

func _setup_frame() -> void:
	# Left pillar
	_solid_pillar(Vector3(-gate_width * 0.5, gate_height * 0.5, 0))
	# Right pillar
	_solid_pillar(Vector3(gate_width * 0.5, gate_height * 0.5, 0))

	# Overhead beam
	var beam := MeshInstance3D.new()
	beam.name = "OverheadBeam"
	var box := BoxMesh.new()
	box.size = Vector3(gate_width + 1.6, 1.2, 1.2)
	beam.mesh = box
	beam.position = Vector3(0, gate_height + 0.6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_STEEL
	beam.material_override = mat
	add_child(beam)

	# Checkered line on the ground
	var line := MeshInstance3D.new()
	line.name = "CheckeredGround"
	var quad := BoxMesh.new()
	quad.size = Vector3(gate_width, 0.04, 1.4)
	line.mesh = quad
	line.position = Vector3(0, 0.02, 0)
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color("F8FAFC")
	line.material_override = line_mat
	add_child(line)

func _solid_pillar(pos: Vector3) -> void:
	var pillar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, gate_height, 1.2)
	pillar.mesh = box
	pillar.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_STEEL
	pillar.material_override = mat
	add_child(pillar)

func _setup_banner() -> void:
	timer_label = Label3D.new()
	timer_label.name = "TimerHUD"
	timer_label.text = "★ WORLD RECORD: 00:35.00 ★\nPIG RACER SPRINT: 00:34.88"
	timer_label.font_size = 28
	timer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	timer_label.position = Vector3(0, gate_height + 2.0, 0)
	timer_label.modulate = COLOR_NEON_YELLOW
	timer_label.outline_modulate = Color("0F172A")
	timer_label.outline_size = 8
	add_child(timer_label)

	banner_label = Label3D.new()
	banner_label.name = "VictoryBanner"
	banner_label.text = "🏁 RECORD BROKEN! 🏁\n00:34.88 新纪录诞生！直接击穿大门！"
	banner_label.font_size = 42
	banner_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner_label.position = Vector3(0, gate_height + 3.8, 0)
	banner_label.modulate = Color("38BDF8")
	banner_label.outline_modulate = Color("FFFFFF")
	banner_label.outline_size = 10
	banner_label.visible = false
	add_child(banner_label)

func _setup_trigger() -> void:
	trigger_area = Area3D.new()
	trigger_area.name = "FinishTriggerArea"
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = 2 # Player

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(gate_width, gate_height, 2.0)
	col.shape = box
	col.position.y = gate_height * 0.5
	trigger_area.add_child(col)

	trigger_area.body_entered.connect(_on_finish_entered)
	add_child(trigger_area)

func _on_finish_entered(player: Node3D) -> void:
	if is_finished:
		return
	if not player.is_in_group("player") and not player.name.to_lower().contains("pig"):
		return
	is_finished = true

	banner_label.visible = true
	var tween := create_tween()
	banner_label.scale = Vector3(0.5, 0.5, 0.5)
	tween.tween_property(banner_label, "scale", Vector3(1.3, 1.3, 1.3), 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(banner_label, "scale", Vector3.ONE, 0.1)

	finish_line_crossed.emit(player)
