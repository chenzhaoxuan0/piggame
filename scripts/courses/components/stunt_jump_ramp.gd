class_name StuntJumpRamp
extends Node3D

signal ramp_jumped(ramp: StuntJumpRamp, player: Node3D)
signal landing_turbo(player: Node3D)

@export var ramp_size: Vector3 = Vector3(4.5, 1.8, 4.0)
@export var launch_vertical: float = 9.5
@export var launch_forward: float = 22.0
@export var landing_turbo_speed: float = 8.0 # Forward kick on touchdown ("落地迷你涡轮")

const COLOR_NEON_CYAN := Color("06B6D4")
const COLOR_NEON_YELLOW := Color("FACC15")
const LANDING_WATCH_TIMEOUT := 4.0

var _trigger_area: Area3D
var _airborne_body: CharacterBody3D = null # Launched pig we owe a landing turbo
var _airborne_time: float = 0.0
var _left_floor: bool = false

func _ready() -> void:
	_setup_ramp_structure()
	_setup_launch_trigger()

func _physics_process(delta: float) -> void:
	if _airborne_body == null:
		return
	if not is_instance_valid(_airborne_body):
		_airborne_body = null
		return
	_airborne_time += delta
	if not _airborne_body.is_on_floor():
		_left_floor = true
	elif _left_floor:
		_grant_landing_turbo(_airborne_body)
		_airborne_body = null
		return
	if _airborne_time >= LANDING_WATCH_TIMEOUT:
		_airborne_body = null

func _grant_landing_turbo(cb: CharacterBody3D) -> void:
	var forward_dir := -global_transform.basis.z.normalized()
	if forward_dir.length_squared() < 0.001:
		forward_dir = Vector3(0, 0, -1)
	cb.velocity += forward_dir * landing_turbo_speed

	var turbo_lbl := Label3D.new()
	turbo_lbl.text = "🔥 落地迷你涡轮！"
	turbo_lbl.font_size = 26
	turbo_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	turbo_lbl.modulate = Color("FB923C")
	turbo_lbl.outline_modulate = Color("0F172A")
	turbo_lbl.outline_size = 6
	turbo_lbl.position = Vector3(0, 2.4, 0)
	cb.add_child(turbo_lbl)
	var lbl_tween := turbo_lbl.create_tween()
	lbl_tween.tween_property(turbo_lbl, "position:y", turbo_lbl.position.y + 1.0, 1.0)
	lbl_tween.tween_callback(turbo_lbl.queue_free)

	landing_turbo.emit(cb)

func _setup_ramp_structure() -> void:
	# Static angled ramp body
	var body := StaticBody3D.new()
	body.name = "RampBody"
	body.collision_layer = 1
	body.collision_mask = 0

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ramp_size
	col.shape = box
	var tilt := deg_to_rad(20.0)
	col.rotation.x = tilt
	# Sink the box so the front lip sits ~5cm above the ground and the ramp is
	# walkable without a jump. The old y*0.4 offset left a 0.88m step at the front
	# edge — nearly the pig's full jump height (0.934m).
	col.position.y = 0.05 - (ramp_size.y * 0.5) * cos(tilt) + (ramp_size.z * 0.5) * sin(tilt)
	body.add_child(col)
	add_child(body)

	# Visual wedge
	var mesh := MeshInstance3D.new()
	var box_m := BoxMesh.new()
	box_m.size = ramp_size
	mesh.mesh = box_m
	mesh.rotation.x = deg_to_rad(20.0)
	mesh.position = col.position

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_NEON_CYAN
	mat.emission_enabled = true
	mat.emission = COLOR_NEON_CYAN
	mat.emission_energy_multiplier = 1.2
	mesh.material_override = mat
	add_child(mesh)

	# Neon chevron arrows
	var chevron := Label3D.new()
	chevron.text = "▲ ▲ ▲\nSTUNT JUMP"
	chevron.font_size = 32
	chevron.rotation.x = deg_to_rad(-70.0)
	chevron.position = Vector3(0, ramp_size.y * 0.8 + 0.1, 0)
	chevron.modulate = COLOR_NEON_YELLOW
	chevron.outline_modulate = Color("0F172A")
	chevron.outline_size = 6
	add_child(chevron)

func _setup_launch_trigger() -> void:
	_trigger_area = Area3D.new()
	_trigger_area.name = "LaunchTrigger"
	_trigger_area.collision_layer = 0
	_trigger_area.collision_mask = 2 # Player

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ramp_size.x * 0.95, 1.2, 1.8)
	shape.shape = box
	shape.position = Vector3(0, ramp_size.y + 0.4, -ramp_size.z * 0.3)
	_trigger_area.add_child(shape)

	_trigger_area.body_entered.connect(_on_player_crest)
	add_child(_trigger_area)

func _on_player_crest(body: Node3D) -> void:
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	if not (body is CharacterBody3D):
		return

	var cb := body as CharacterBody3D
	var forward_dir := -global_transform.basis.z.normalized()
	if forward_dir.length_squared() < 0.001:
		forward_dir = Vector3(0, 0, -1)

	cb.velocity = Vector3(forward_dir.x * launch_forward, launch_vertical, forward_dir.z * launch_forward)

	# Owe this pig a mini-turbo the moment it touches down again.
	_airborne_body = cb
	_airborne_time = 0.0
	_left_floor = false

	# 360-degree aerial stunt flip
	var v_mesh: Node3D = null
	if "visual_mesh" in cb and is_instance_valid(cb.visual_mesh):
		v_mesh = cb.visual_mesh
	elif cb.has_node("VisualMesh"):
		v_mesh = cb.get_node("VisualMesh")

	if v_mesh != null:
		var tween := v_mesh.create_tween()
		tween.tween_property(v_mesh, "rotation:x", deg_to_rad(360.0), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func():
			if is_instance_valid(v_mesh):
				v_mesh.rotation.x = 0.0
		)

	# Celebratory Stunt Popup
	var stunt_lbl := Label3D.new()
	stunt_lbl.text = "🏁 360° 空中特技！\n【落地迷你涡轮加速！】"
	stunt_lbl.font_size = 28
	stunt_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stunt_lbl.modulate = Color("FACC15")
	stunt_lbl.outline_modulate = Color("0F172A")
	stunt_lbl.outline_size = 6
	stunt_lbl.position = Vector3(0, 2.8, 0)
	cb.add_child(stunt_lbl)

	var lbl_tween := stunt_lbl.create_tween()
	lbl_tween.tween_property(stunt_lbl, "position:y", stunt_lbl.position.y + 1.2, 1.5)
	lbl_tween.tween_callback(stunt_lbl.queue_free)

	ramp_jumped.emit(self, body)
