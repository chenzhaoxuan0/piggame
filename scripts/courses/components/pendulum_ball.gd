extends CourseTrap
class_name PendulumBall

@export var swing_speed: float = 2.4
@export var max_angle_deg: float = 46.0
@export var arm_length: float = 4.0
@export var ball_radius: float = 0.75
@export var knockback_power: float = 7.5
@export var knockback_up: float = 3.8
@export var phase_offset: float = 0.0
@export var hit_cooldown: float = 0.6
@export var ball_color: Color = Color("34495E")

var _pivot: Node3D
var _ball_mesh: MeshInstance3D
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
	beam_mat.albedo_color = Color("795548")
	beam_mat.roughness = 0.9

	_add_beam(gantry, Vector3(0.4, arm_length + 1.2, 0.4), Vector3(-3.8, (arm_length + 1.2) * 0.5, 0), beam_mat)
	_add_beam(gantry, Vector3(0.4, arm_length + 1.2, 0.4), Vector3(3.8, (arm_length + 1.2) * 0.5, 0), beam_mat)
	_add_beam(gantry, Vector3(8.0, 0.45, 0.45), Vector3(0, arm_length + 1.0, 0), beam_mat)
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

	# Wrecking ball at bottom
	_ball_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = ball_radius
	sphere.height = ball_radius * 2.0
	_ball_mesh.mesh = sphere
	_ball_mesh.position.y = -arm_length
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ball_color
	mat.metallic = 0.6
	mat.roughness = 0.4
	_ball_mesh.material_override = mat
	_pivot.add_child(_ball_mesh)

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
	var swing_vel := cos(_time * swing_speed + phase_offset)
	var lateral_dir := Vector3.RIGHT if swing_vel > 0 else Vector3.LEFT

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
