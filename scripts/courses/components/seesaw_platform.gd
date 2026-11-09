extends CourseTrap
class_name SeesawPlatform

@export var plank_size: Vector3 = Vector3(6.0, 0.4, 12.0)
@export var max_tilt_deg: float = 24.0
@export var tilt_speed: float = 2.5
@export var return_speed: float = 1.8
@export var plank_color: Color = Color("00E5FF") # Neon cyan
@export var edge_color: Color = Color("FF1493") # Hot pink

var _plank_body: AnimatableBody3D
var _current_tilt := 0.0 # Radians
var _target_tilt := 0.0
var _bodies_on_plank: Array[Node3D] = []
var _meme_cooldown := 0.0

func _ready() -> void:
	# Central pivot base (static triangle / wedge)
	var fulcrum := StaticBody3D.new()
	fulcrum.collision_layer = 1
	fulcrum.collision_mask = 0
	var f_shape := CollisionShape3D.new()
	var f_box := BoxShape3D.new()
	f_box.size = Vector3(plank_size.x * 0.9, 0.8, 1.2)
	f_shape.shape = f_box
	f_shape.position.y = -0.4
	fulcrum.add_child(f_shape)
	var f_mesh := MeshInstance3D.new()
	var f_prism := PrismMesh.new()
	f_prism.size = Vector3(1.4, 0.9, plank_size.x * 0.9)
	f_mesh.mesh = f_prism
	f_mesh.rotation.y = PI * 0.5
	f_mesh.position.y = -0.45
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color("37474F")
	f_mesh.material_override = f_mat
	fulcrum.add_child(f_mesh)
	add_child(fulcrum)

	# Tilting plank body
	_plank_body = AnimatableBody3D.new()
	_plank_body.name = "Plank"
	_plank_body.collision_layer = 1
	_plank_body.collision_mask = 0
	_plank_body.sync_to_physics = true

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = plank_size
	shape.shape = box_shape
	_plank_body.add_child(shape)

	# Main deck mesh
	var deck_mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = plank_size
	deck_mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = plank_color
	mat.roughness = 0.5
	deck_mesh.material_override = mat
	_plank_body.add_child(deck_mesh)

	# Side guide rails
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_box := BoxMesh.new()
		rail_box.size = Vector3(0.2, 0.5, plank_size.z)
		rail.mesh = rail_box
		rail.position = Vector3(side * (plank_size.x * 0.5 - 0.1), 0.35, 0)
		var r_mat := StandardMaterial3D.new()
		r_mat.albedo_color = edge_color
		rail.material_override = r_mat
		_plank_body.add_child(rail)

	# Weight detection area
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	var area_shape := CollisionShape3D.new()
	var a_box := BoxShape3D.new()
	a_box.size = Vector3(plank_size.x, 1.0, plank_size.z)
	area_shape.shape = a_box
	area_shape.position.y = 0.5
	area.add_child(area_shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_plank_body.add_child(area)

	add_child(_plank_body)

func _on_body_entered(body: Node3D) -> void:
	if not _bodies_on_plank.has(body):
		_bodies_on_plank.append(body)

func _on_body_exited(body: Node3D) -> void:
	_bodies_on_plank.erase(body)

func _physics_process(delta: float) -> void:
	_meme_cooldown = maxf(0.0, _meme_cooldown - delta)

	# Calculate torque / weight bias from bodies on the plank
	var weight_torque := 0.0
	for body in _bodies_on_plank:
		if is_instance_valid(body):
			# Local Z distance from pivot
			var local_pos := _plank_body.to_local(body.global_position)
			# Positive local Z tilts down in front (+X rot or -X rot depending on axis)
			var weight := 1.5 if _is_player(body) else 1.0
			weight_torque += (local_pos.z / (plank_size.z * 0.5)) * weight

	var max_rad := deg_to_rad(max_tilt_deg)
	if _bodies_on_plank.is_empty():
		_target_tilt = move_toward(_target_tilt, 0.0, return_speed * delta)
	else:
		_target_tilt = clampf(weight_torque * max_rad, -max_rad, max_rad)

	_current_tilt = move_toward(_current_tilt, _target_tilt, tilt_speed * delta)
	_plank_body.rotation.x = _current_tilt

	if absf(_current_tilt) > deg_to_rad(15.0) and _meme_cooldown <= 0.0:
		_meme_cooldown = 3.5
		_meme(meme_id, global_position)
