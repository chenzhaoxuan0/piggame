class_name RacingFinishGate
extends Node3D

signal finish_line_crossed(player: Node3D)

const ASSETS = preload("res://scripts/art/asset_library.gd")

@export var gate_width: float = 12.0
@export var gate_height: float = 6.0
@export var record_time: float = 35.0 # The farm's standing record to beat (seconds)
# Optional zone dressing (courtyard neon): the finish arch model (normalized to
# 10 x 5.5) replaces the pillar/beam pair; labels and checkered line stay.
@export var lux_asset_id: String = ""

const COLOR_STEEL := Color("1E293B")
const COLOR_NEON_CYAN := Color("06B6D4")
const COLOR_NEON_YELLOW := Color("FACC15")

var is_finished: bool = false
var record_broken: bool = false
var final_time: float = -1.0 # Real race time; < 0 means "no clock" (plain FINISH banner)
# Optional clock hook: called once when the pig crosses the line and expected to
# return the race time in seconds. Pulling the time here (instead of the course
# pushing it from a second body_entered handler) keeps it independent of signal
# connection order.
var time_provider: Callable
var banner_label: Label3D
var timer_label: Label3D
var trigger_area: Area3D

func _ready() -> void:
	_setup_frame()
	_setup_banner()
	_setup_trigger()

func _setup_frame() -> void:
	# Left pillar
	_solid_pillar(Vector3(-gate_width * 0.5, gate_height * 0.5, 0), "PillarL")
	# Right pillar
	_solid_pillar(Vector3(gate_width * 0.5, gate_height * 0.5, 0), "PillarR")

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

	# Zone dressing: the neon finish arch replaces the steel pillar/beam pair.
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			lux.scale = Vector3(gate_width / 10.0, gate_height / 5.5, 1.0)
			add_child(lux)
			get_node("OverheadBeam").visible = false
			get_node("PillarL").visible = false
			get_node("PillarR").visible = false

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

func _solid_pillar(pos: Vector3, pillar_name: String) -> void:
	var pillar := MeshInstance3D.new()
	pillar.name = pillar_name
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
	timer_label.text = "★ WORLD RECORD: %s ★" % format_time(record_time)
	timer_label.font_size = 28
	timer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	timer_label.position = Vector3(0, gate_height + 2.0, 0)
	timer_label.modulate = COLOR_NEON_YELLOW
	timer_label.outline_modulate = Color("0F172A")
	timer_label.outline_size = 8
	add_child(timer_label)

	banner_label = Label3D.new()
	banner_label.name = "VictoryBanner"
	banner_label.text = "🏁 FINISH! 🏁"
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

func set_finish_time(seconds: float) -> void:
	final_time = seconds

func format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := fmod(t, 60.0)
	return "%02d:%05.2f" % [minutes, seconds]

func _on_finish_entered(player: Node3D) -> void:
	if is_finished:
		return
	if not player.is_in_group("player") and not player.name.to_lower().contains("pig"):
		return
	is_finished = true
	if time_provider.is_valid():
		final_time = float(time_provider.call())

	# The banner now reports the pig's real time: beating record_time is earned,
	# and a slower run gets a consolation line instead of a free "RECORD BROKEN".
	record_broken = final_time >= 0.0 and final_time < record_time
	if record_broken:
		banner_label.text = "🏁 RECORD BROKEN! 🏁\n%s 新纪录诞生！直接击穿大门！" % format_time(final_time)
		banner_label.modulate = Color("38BDF8")
	elif final_time >= 0.0:
		banner_label.text = "🏁 FINISH! %s 🏁\n离 %s 的纪录就差一点点……下次哼哼！" % [format_time(final_time), format_time(record_time)]
		banner_label.modulate = Color("FB923C")
	banner_label.visible = true
	var tween := create_tween()
	banner_label.scale = Vector3(0.5, 0.5, 0.5)
	tween.tween_property(banner_label, "scale", Vector3(1.3, 1.3, 1.3), 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(banner_label, "scale", Vector3.ONE, 0.1)

	finish_line_crossed.emit(player)
