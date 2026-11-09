extends CourseTrap
class_name VoxelTNT

@export var tnt_size: Vector3 = Vector3(1.2, 1.2, 1.2)
@export var blast_power: float = 8.5
@export var blast_up: float = 6.5
@export var fuse_time: float = 0.35
@export var cooldown: float = 2.0

var _is_exploding := false
var _cooldown_timer := 0.0
var _mesh_root: Node3D
var _tnt_mesh: MeshInstance3D
var _plate: MeshInstance3D

func _ready() -> void:
	# Solid base box
	var base := StaticBody3D.new()
	base.collision_layer = 1
	base.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tnt_size
	shape.shape = box
	shape.position.y = tnt_size.y * 0.5
	base.add_child(shape)
	add_child(base)

	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	# Voxel TNT block body
	_tnt_mesh = MeshInstance3D.new()
	var tnt_box := BoxMesh.new()
	tnt_box.size = tnt_size
	_tnt_mesh.mesh = tnt_box
	_tnt_mesh.position.y = tnt_size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("D32F2F") # Minecraft red
	mat.roughness = 0.9
	_tnt_mesh.material_override = mat
	_mesh_root.add_child(_tnt_mesh)

	# White belly stripe
	var stripe := MeshInstance3D.new()
	var stripe_box := BoxMesh.new()
	stripe_box.size = Vector3(tnt_size.x * 1.01, tnt_size.y * 0.35, tnt_size.z * 1.01)
	stripe.mesh = stripe_box
	stripe.position.y = tnt_size.y * 0.5
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color("FFFFFF")
	stripe_mat.roughness = 1.0
	stripe.material_override = stripe_mat
	_mesh_root.add_child(stripe)

	# TNT labels on sides
	for side in [0, 90, 180, 270]:
		var label := Label3D.new()
		label.text = "TNT"
		label.font_size = 32
		label.modulate = Color("1A1A1A")
		label.rotation.y = deg_to_rad(side)
		var rad: float = tnt_size.x * 0.52
		match side:
			0: label.position = Vector3(0, tnt_size.y * 0.5, rad)
			90: label.position = Vector3(rad, tnt_size.y * 0.5, 0)
			180: label.position = Vector3(0, tnt_size.y * 0.5, -rad)
			270: label.position = Vector3(-rad, tnt_size.y * 0.5, 0)
		_mesh_root.add_child(label)

	# Top pressure plate
	_plate = MeshInstance3D.new()
	var plate_box := BoxMesh.new()
	plate_box.size = Vector3(tnt_size.x * 0.7, 0.08, tnt_size.z * 0.7)
	_plate.mesh = plate_box
	_plate.position.y = tnt_size.y + 0.04
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color("424242")
	_plate.material_override = plate_mat
	_mesh_root.add_child(_plate)

	# Step detection area on top
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	var area_shape := CollisionShape3D.new()
	var trigger_box := BoxShape3D.new()
	trigger_box.size = Vector3(tnt_size.x * 0.8, 0.4, tnt_size.z * 0.8)
	area_shape.shape = trigger_box
	area_shape.position.y = tnt_size.y + 0.2
	area.add_child(area_shape)
	area.body_entered.connect(_on_step)
	add_child(area)

func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

func _on_step(body: Node3D) -> void:
	if _is_exploding or _cooldown_timer > 0.0:
		return
	if not _is_player(body) and not _is_dog(body):
		return
	_trigger_fuse(body)

func _trigger_fuse(target: Node3D) -> void:
	_is_exploding = true
	_meme(telegraph_meme_id, global_position)
	
	# Press plate down
	var tween := create_tween()
	tween.tween_property(_plate, "position:y", tnt_size.y + 0.01, 0.06)
	# Flash block white and scale swell
	tween.tween_property(_mesh_root, "scale", Vector3(1.15, 1.15, 1.15), fuse_time)
	await tween.finished

	# Explode!
	_blast(target)

func _blast(target: Node3D) -> void:
	var blast_tween := create_tween()
	blast_tween.tween_property(_mesh_root, "scale", Vector3(1.4, 0.4, 1.4), 0.08)
	blast_tween.tween_property(_mesh_root, "scale", Vector3(1.0, 1.0, 1.0), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_plate.position.y = tnt_size.y + 0.04

	if is_instance_valid(target):
		var dir := _flat_dir(global_position, target.global_position, Vector3.FORWARD)
		if _is_player(target):
			_knock(target, dir * blast_power + Vector3.UP * blast_up, 0.8)
		elif _is_dog(target):
			_hit_dog(target, 2.5, dir * blast_power)

	_meme(meme_id, global_position)
	_cooldown_timer = cooldown
	_is_exploding = false
