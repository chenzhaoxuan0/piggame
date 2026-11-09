extends CourseTrap
class_name BumperPillar

@export var bumper_radius: float = 0.65
@export var bumper_height: float = 1.1
@export var knockback_power: float = 8.5
@export var knockback_up: float = 3.5
@export var hit_cooldown: float = 0.35
@export var bumper_color: Color = Color("FF1493") # Deep neon pink
@export var cap_color: Color = Color("FFD700") # Gold yellow
@export var star_color: Color = Color("00FFFF") # Cyan

var _hit_timer := 0.0
var _mesh_root: Node3D

func _ready() -> void:
	# Solid base cylinder so pig cannot walk through it when idle
	var base := StaticBody3D.new()
	base.collision_layer = 1
	base.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = bumper_radius * 0.85
	cyl_shape.height = bumper_height
	shape.shape = cyl_shape
	shape.position.y = bumper_height * 0.5
	base.add_child(shape)
	add_child(base)

	# Visual root for squash & stretch tween
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	# Bumper Body Mesh
	var body_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = bumper_radius
	cyl.bottom_radius = bumper_radius * 1.15
	cyl.height = bumper_height
	body_mesh.mesh = cyl
	body_mesh.position.y = bumper_height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = bumper_color
	mat.roughness = 0.4
	mat.metallic = 0.2
	body_mesh.material_override = mat
	_mesh_root.add_child(body_mesh)

	# Bumper Cap Mesh (domed top)
	var cap := MeshInstance3D.new()
	var cap_sphere := SphereMesh.new()
	cap_sphere.radius = bumper_radius * 0.95
	cap_sphere.height = bumper_radius * 0.7
	cap.mesh = cap_sphere
	cap.position.y = bumper_height
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = cap_color
	cap_mat.roughness = 0.3
	cap_mat.emission_enabled = true
	cap_mat.emission = cap_color * 0.4
	cap.material_override = cap_mat
	_mesh_root.add_child(cap)

	# Star / Target Label on both sides
	var label_f := Label3D.new()
	label_f.text = "★"
	label_f.font_size = 36
	label_f.position = Vector3(0, bumper_height * 0.55, bumper_radius * 1.05)
	label_f.modulate = star_color
	_mesh_root.add_child(label_f)

	var label_b := Label3D.new()
	label_b.text = "★"
	label_b.font_size = 36
	label_b.position = Vector3(0, bumper_height * 0.55, -bumper_radius * 1.05)
	label_b.rotation.y = PI
	label_b.modulate = star_color
	_mesh_root.add_child(label_b)

	# Trigger area for collision detection
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	var area_shape := CollisionShape3D.new()
	var trigger_cyl := CylinderShape3D.new()
	trigger_cyl.radius = bumper_radius * 1.25
	trigger_cyl.height = bumper_height * 1.2
	area_shape.shape = trigger_cyl
	area_shape.position.y = bumper_height * 0.5
	area.add_child(area_shape)
	area.body_entered.connect(_on_body)
	add_child(area)

func _physics_process(delta: float) -> void:
	_hit_timer = maxf(0.0, _hit_timer - delta)

func _on_body(body: Node3D) -> void:
	if _hit_timer > 0.0:
		return

	var dir := _flat_dir(global_position, body.global_position)
	if _is_player(body):
		if body.has_method("is_knocked_back") and body.is_knocked_back():
			return
		_hit_timer = hit_cooldown
		_play_squash()
		_knock(body, dir * knockback_power + Vector3.UP * knockback_up, 0.6)
		_meme(meme_id if not meme_id.is_empty() else "bumper_hit", body.global_position)
	elif _is_dog(body):
		_hit_timer = hit_cooldown
		_play_squash()
		_hit_dog(body, 2.0, dir * 5.0)
		_meme("dog_bonk", body.global_position)

func _play_squash() -> void:
	if not is_instance_valid(_mesh_root):
		return
	var tw := create_tween()
	tw.tween_property(_mesh_root, "scale", Vector3(1.35, 0.65, 1.35), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mesh_root, "scale", Vector3(0.9, 1.15, 0.9), 0.09)
	tw.tween_property(_mesh_root, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
