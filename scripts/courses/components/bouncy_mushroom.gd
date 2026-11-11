extends CourseTrap
class_name BouncyMushroom

signal triggered(trap: Node3D, target: Node3D)
signal mushroom_bounced(mushroom: Node3D, target: Node3D)

@export var mushroom_radius: float = 1.3
@export var mushroom_height: float = 1.2
@export var bounce_direction: Vector3 = Vector3(0, 0, -1)
@export var bounce_power: float = 7.5
@export var bounce_up: float = 9.0
@export var cap_color: Color = Color("E74C3C") # Fairytale coral red
@export var stalk_color: Color = Color("FDF6E2") # Cream stem
@export var spot_color: Color = Color("FFFFFF") # White spots
@export var cooldown: float = 0.6
# Optional zone dressing (woodland fairytale): the big toadstool model replaces
# the procedural stalk+cap+spots; the squash & stretch keeps working on the cap.
@export var lux_asset_id: String = "PROP_C3_BOUNCY_MUSHROOM"

const ASSETS = preload("res://scripts/art/asset_library.gd")

var _cooldown_timer := 0.0
var _cap: Node3D

func _ready() -> void:
	# Stalk static body
	var base := StaticBody3D.new()
	base.collision_layer = 1
	base.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = mushroom_radius * 0.45
	cyl.height = mushroom_height * 0.7
	shape.shape = cyl
	shape.position.y = mushroom_height * 0.35
	base.add_child(shape)
	add_child(base)

	# Stalk mesh
	var stalk_mesh := MeshInstance3D.new()
	var stalk_cyl := CylinderMesh.new()
	stalk_cyl.top_radius = mushroom_radius * 0.35
	stalk_cyl.bottom_radius = mushroom_radius * 0.5
	stalk_cyl.height = mushroom_height * 0.75
	stalk_mesh.mesh = stalk_cyl
	stalk_mesh.position.y = mushroom_height * 0.375
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = stalk_color
	s_mat.roughness = 0.9
	stalk_mesh.material_override = s_mat
	add_child(stalk_mesh)

	# Cap root for bounce squash & stretch
	_cap = Node3D.new()
	_cap.position.y = mushroom_height * 0.7
	add_child(_cap)

	# Mushroom cap hemisphere
	var cap_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = mushroom_radius
	sphere.height = mushroom_radius * 0.9
	sphere.is_hemisphere = true
	cap_mesh.mesh = sphere
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = cap_color
	c_mat.roughness = 0.6
	cap_mesh.material_override = c_mat
	_cap.add_child(cap_mesh)

	# White polka dots around the cap
	for i in 5:
		var angle := i * (PI * 2.0 / 5.0)
		var spot := MeshInstance3D.new()
		var spot_sphere := SphereMesh.new()
		spot_sphere.radius = mushroom_radius * 0.18
		spot_sphere.height = mushroom_radius * 0.08
		spot.mesh = spot_sphere
		spot.position = Vector3(cos(angle) * mushroom_radius * 0.65, mushroom_radius * 0.35, sin(angle) * mushroom_radius * 0.65)
		var spot_mat := StandardMaterial3D.new()
		spot_mat.albedo_color = spot_color
		spot.material_override = spot_mat
		_cap.add_child(spot)

	# Center top spot
	var top_spot := MeshInstance3D.new()
	var top_sphere := SphereMesh.new()
	top_sphere.radius = mushroom_radius * 0.22
	top_sphere.height = mushroom_radius * 0.08
	top_spot.mesh = top_sphere
	top_spot.position = Vector3(0, mushroom_radius * 0.82, 0)
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = spot_color
	top_spot.material_override = t_mat
	_cap.add_child(top_spot)

	# Bounce detection area on top
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	var area_shape := CollisionShape3D.new()
	var trigger_cyl := CylinderShape3D.new()
	trigger_cyl.radius = mushroom_radius * 0.95
	trigger_cyl.height = 0.5
	area_shape.shape = trigger_cyl
	area_shape.position.y = mushroom_height * 0.7 + mushroom_radius * 0.45
	area.add_child(area_shape)
	area.body_entered.connect(_on_cap_step)
	add_child(area)

	# Zone dressing: the whole toadstool rides the cap root so the squash &
	# stretch plays around its middle.
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			for node in [stalk_mesh, cap_mesh]:
				node.visible = false
			for spot in _cap.get_children():
				if spot is MeshInstance3D:
					spot.visible = false
			lux.position.y = -_cap.position.y
			_cap.add_child(lux)

func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

func _on_cap_step(body: Node3D) -> void:
	if _cooldown_timer > 0.0:
		return
	if not _is_player(body) and not _is_dog(body):
		return
	_cooldown_timer = cooldown

	# Squash & Stretch tween
	var tween := create_tween()
	tween.tween_property(_cap, "scale", Vector3(1.3, 0.4, 1.3), 0.08)
	tween.tween_property(_cap, "scale", Vector3(0.85, 1.3, 0.85), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_cap, "scale", Vector3(1.0, 1.0, 1.0), 0.2)

	var dir: Vector3 = bounce_direction.normalized()
	triggered.emit(self, body)
	mushroom_bounced.emit(self, body)
	if _is_player(body):
		_knock(body, dir * bounce_power + Vector3.UP * bounce_up, 0.75)
		_meme(meme_id, global_position)
	elif _is_dog(body):
		_hit_dog(body, 2.0, dir * (bounce_power * 0.8) + Vector3.UP * 4.0)
