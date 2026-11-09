extends CourseTrap
class_name SpinHammer

const ASSETS = preload("res://scripts/art/asset_library.gd")

@export var rotate_speed: float = 1.6
@export var arm_length: float = 3.2
@export var knockback_power: float = 8.0
@export var knockback_up: float = 5.0
@export var hit_cooldown: float = 0.8
@export var phase_offset: float = 0.0
@export var hammer_color: Color = Color("B85D3D")

var _pivot: Node3D
var _hit_timer := 0.0

func _ready() -> void:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.22
	cyl.height = 1.6
	post.mesh = cyl
	post.position.y = 0.8
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color("665A48")
	post_mat.roughness = 1.0
	post.material_override = post_mat
	add_child(post)
	_pivot = Node3D.new()
	_pivot.position.y = 1.1
	_pivot.rotation.y = phase_offset
	add_child(_pivot)
	var arm := MeshInstance3D.new()
	var arm_box := BoxMesh.new()
	arm_box.size = Vector3(arm_length, 0.22, 0.22)
	arm.mesh = arm_box
	arm.position.x = arm_length * 0.5
	arm.material_override = post_mat
	_pivot.add_child(arm)
	
	var lux_head := ASSETS.make("PROP_C1_HAMMER")
	if lux_head:
		lux_head.position.x = arm_length
		_pivot.add_child(lux_head)
	else:
		var head := MeshInstance3D.new()
		var head_box := BoxMesh.new()
		head_box.size = Vector3(0.85, 0.85, 0.85)
		head.mesh = head_box
		head.position.x = arm_length
		var head_mat := StandardMaterial3D.new()
		head_mat.albedo_color = hammer_color
		head_mat.roughness = 1.0
		head.material_override = head_mat
		_pivot.add_child(head)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75
	shape.shape = sphere
	area.add_child(shape)
	area.position.x = arm_length
	area.body_entered.connect(_on_head_body)
	_pivot.add_child(area)

func _physics_process(delta: float) -> void:
	_pivot.rotation.y += rotate_speed * delta
	_hit_timer = maxf(0.0, _hit_timer - delta)

func _on_head_body(body: Node3D) -> void:
	if _hit_timer > 0.0:
		return
	if _is_player(body):
		if body.has_method("is_knocked_back") and body.is_knocked_back():
			return
		_hit_timer = hit_cooldown
		var dir := _flat_dir(global_position, body.global_position)
		_knock(body, dir * knockback_power + Vector3.UP * knockback_up, 0.7)
		_meme(meme_id, body.global_position)
	elif _is_dog(body):
		_hit_timer = hit_cooldown
		var dir := _flat_dir(global_position, body.global_position)
		_hit_dog(body, 2.5, dir * 6.0)
		_meme("dog_bonk", body.global_position)