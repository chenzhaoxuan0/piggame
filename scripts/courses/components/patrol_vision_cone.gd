class_name PatrolVisionCone
extends Node3D

signal player_detected(player: Node3D)
signal player_lost()

@export var cone_angle_deg: float = 60.0
@export var cone_range: float = 8.5
@export var patrol_speed: float = 2.0
@export var patrol_points: Array[Vector3] = []

const COLOR_NORMAL := Color("FBBF2455") # Translucent amber
const COLOR_ALERT := Color("EF4444AA") # Bright red alert

var is_alert: bool = false
var current_patrol_idx: int = 0
var alert_billboard: Label3D
var cone_mesh: MeshInstance3D
var target_player: Node3D

func _ready() -> void:
	_setup_cone_visual()
	_setup_alert_billboard()

func _setup_cone_visual() -> void:
	cone_mesh = MeshInstance3D.new()
	cone_mesh.name = "VisionMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = tan(deg_to_rad(cone_angle_deg * 0.5)) * cone_range
	cyl.bottom_radius = 0.2
	cyl.height = cone_range
	cone_mesh.mesh = cyl
	cone_mesh.rotation.x = deg_to_rad(90.0)
	cone_mesh.position = Vector3(0, 0.1, -cone_range * 0.5)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = COLOR_NORMAL
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	cone_mesh.material_override = mat
	add_child(cone_mesh)

func _setup_alert_billboard() -> void:
	alert_billboard = Label3D.new()
	alert_billboard.name = "AlertBillboard"
	alert_billboard.text = "！"
	alert_billboard.font_size = 54
	alert_billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert_billboard.modulate = Color("EF4444")
	alert_billboard.outline_modulate = Color("FFFFFF")
	alert_billboard.outline_size = 8
	alert_billboard.position = Vector3(0, 2.2, 0)
	alert_billboard.visible = false
	add_child(alert_billboard)

func _physics_process(delta: float) -> void:
	_patrol_movement(delta)
	_scan_for_player()

func _patrol_movement(delta: float) -> void:
	if patrol_points.is_empty() or is_alert:
		return
	var target_pos := patrol_points[current_patrol_idx]
	var dir := (target_pos - global_position)
	dir.y = 0
	if dir.length() < 0.6:
		current_patrol_idx = (current_patrol_idx + 1) % patrol_points.size()
	else:
		global_position += dir.normalized() * patrol_speed * delta
		look_at(global_position + dir.normalized(), Vector3.UP)

func _scan_for_player() -> void:
	if target_player == null:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target_player = players[0] as Node3D
	if target_player == null or not is_instance_valid(target_player):
		return

	var diff := target_player.global_position - global_position
	diff.y = 0
	var dist := diff.length()
	if dist > cone_range or dist < 0.1:
		_set_alert(false)
		return

	# Angle check
	var forward := -global_transform.basis.z.normalized()
	var angle := rad_to_deg(forward.angle_to(diff.normalized()))
	if angle > cone_angle_deg * 0.5:
		_set_alert(false)
		return

	# Player is inside cone!
	# Check stealth box
	var in_box: bool = target_player.get_meta("in_stealth_box", false)
	var player_speed: float = 0.0
	if target_player is CharacterBody3D:
		player_speed = (target_player as CharacterBody3D).velocity.length()

	if in_box and player_speed < 0.3:
		# Camouflaged in stationary box! Dog misses pig!
		_set_alert(false)
		return

	# Detected!
	_set_alert(true)
	player_detected.emit(target_player)

func _set_alert(alert: bool) -> void:
	if is_alert == alert:
		return
	is_alert = alert

	if cone_mesh and cone_mesh.material_override is StandardMaterial3D:
		var mat := cone_mesh.material_override as StandardMaterial3D
		mat.albedo_color = COLOR_ALERT if is_alert else COLOR_NORMAL

	if alert_billboard:
		alert_billboard.visible = is_alert
		if is_alert:
			var tween := create_tween()
			alert_billboard.scale = Vector3(0.5, 1.8, 0.5)
			tween.tween_property(alert_billboard, "scale", Vector3(1.2, 1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
			tween.tween_property(alert_billboard, "scale", Vector3.ONE, 0.1)
		else:
			player_lost.emit()
