extends CourseTrap
class_name PendulumBall

const ASSETS = preload("res://scripts/art/asset_library.gd")

@export var swing_speed: float = 2.4
@export var max_angle_deg: float = 46.0
@export var arm_length: float = 4.0
@export var ball_radius: float = 0.75
@export var knockback_power: float = 7.5
@export var knockback_up: float = 3.8
@export var phase_offset: float = 0.0
@export var hit_cooldown: float = 0.6
@export var ball_color: Color = Color("34495E")
# Zone art styles must not mix: the Lux3D pendulum is the ox-field (course 1)
# look by default, so other zones point `lux_asset_id` at their own zone model
# (course 0 meat hook, course 4 neon sign) or opt out entirely.
@export var use_lux_model: bool = true
@export var lux_asset_id: String = "PROP_C1_PENDULUM"
@export var gantry_color: Color = Color("795548")
# Post offset from the centre line. On a walled lane set it to the wall offset:
# posts standing inside the lane leave a pocket between post and wall that is
# narrower than the pig, and a pig knocked in there by the ball is stuck.
@export var gantry_half_width: float = 3.8

var _pivot: Node3D
var _ball_mesh: Node3D
var _time := 0.0
var _hit_timer := 0.0

func _ready() -> void:
	_build_gantry()
	_build_pendulum()

func _build_gantry() -> void:
	var gantry := StaticBody3D.new()
	gantry.collision_layer = 1
	gantry.collision_mask = 0

	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = gantry_color
	beam_mat.roughness = 0.9

	_add_beam(gantry, Vector3(0.4, arm_length + 1.2, 0.4), Vector3(-gantry_half_width, (arm_length + 1.2) * 0.5, 0), beam_mat)
	_add_beam(gantry, Vector3(0.4, arm_length + 1.2, 0.4), Vector3(gantry_half_width, (arm_length + 1.2) * 0.5, 0), beam_mat)
	_add_beam(gantry, Vector3(gantry_half_width * 2.0 + 0.4, 0.45, 0.45), Vector3(0, arm_length + 1.0, 0), beam_mat)
	add_child(gantry)

func _build_pendulum() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, arm_length + 0.9, 0)
	add_child(_pivot)

	# Hanging cable
	var chain := MeshInstance3D.new()
	var chain_box := BoxMesh.new()
	chain_box.size = Vector3(0.08, arm_length, 0.08)
	chain.mesh = chain_box
	chain.position.y = -arm_length * 0.5
	var chain_mat := StandardMaterial3D.new()
	chain_mat.albedo_color = Color("95A5A6")
	chain.material_override = chain_mat
	_pivot.add_child(chain)

	# Wrecking ball at bottom (Lux3D model or procedural sphere fallback)
	var lux_ball: Node3D = ASSETS.make(lux_asset_id) if use_lux_model else null
	if lux_ball:
		lux_ball.position.y = -arm_length
		_ball_mesh = lux_ball
		_pivot.add_child(lux_ball)
	else:
		var s_mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = ball_radius
		sphere.height = ball_radius * 2.0
		s_mesh.mesh = sphere
		s_mesh.position.y = -arm_length
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ball_color
		mat.metallic = 0.6
		mat.roughness = 0.4
		s_mesh.material_override = mat
		_ball_mesh = s_mesh
		_pivot.add_child(s_mesh)

	# Collision area at ball
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	var shape := CollisionShape3D.new()
	var c_sphere := SphereShape3D.new()
	c_sphere.radius = ball_radius * 1.15
	shape.shape = c_sphere
	area.add_child(shape)
	area.position.y = -arm_length
	area.body_entered.connect(_on_ball_body)
	_pivot.add_child(area)

func _physics_process(delta: float) -> void:
	_time += delta
	_hit_timer = maxf(0.0, _hit_timer - delta)
	var angle := deg_to_rad(max_angle_deg) * sin(_time * swing_speed + phase_offset)
	_pivot.rotation.z = angle

func _on_ball_body(body: Node3D) -> void:
	if _hit_timer > 0.0:
		return
	# Knock direction: tangential velocity of the swinging ball, measured along
	# the PIVOT'S OWN swing axis (its local X), so a hook rotated to swing
	# across an eastbound corridor also knocks you across it - the old
	# world-X LEFT/RIGHT knocked along the corridor on rotated copies.
	var swing_axis: Vector3 = global_transform.basis.x.normalized()
	var swing_vel := cos(_time * swing_speed + phase_offset)
	var lateral_dir: Vector3 = swing_axis * (1.0 if swing_vel > 0 else -1.0)

	if _is_player(body):
		if body.has_method("is_knocked_back") and body.is_knocked_back():
			return
		_hit_timer = hit_cooldown
		_knock(body, lateral_dir * knockback_power + Vector3.UP * knockback_up, 0.7)
		_meme(meme_id if not meme_id.is_empty() else "pendulum_hit", body.global_position)
	elif _is_dog(body):
		_hit_timer = hit_cooldown
		_hit_dog(body, 2.5, lateral_dir * 5.5 + Vector3.UP * 2.0)
		_meme("dog_bonk", body.global_position)

func _add_beam(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	parent.add_child(shape)
	var mesh := MeshInstance3D.new()
	var mbox := BoxMesh.new()
	mbox.size = size
	mesh.mesh = mbox
	mesh.position = pos
	mesh.material_override = mat
	parent.add_child(mesh)
