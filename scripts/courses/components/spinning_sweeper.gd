extends CourseTrap
class_name SpinningSweeper

@export var rotate_speed: float = 2.2
@export var bar_length: float = 7.5
@export var bar_radius: float = 0.18
@export var bar_elevation: float = 0.32
@export var knockback_power: float = 7.0
@export var knockback_up: float = 3.5
@export var hit_cooldown: float = 0.8
@export var phase_offset: float = 0.0
@export var sweeper_color: Color = Color("E67E22")

var _pivot: Node3D
var _hit_timer := 0.0

func _ready() -> void:
	# Center post
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.28
	cyl.height = 1.0
	post.mesh = cyl
	post.position.y = 0.5
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color("5D6D7E")
	post_mat.roughness = 1.0
	post.material_override = post_mat
	add_child(post)

	# Rotating assembly
	_pivot = Node3D.new()
	_pivot.position.y = bar_elevation
	_pivot.rotation.y = phase_offset
	add_child(_pivot)

	# Sweeper bar mesh (double-sided arm)
	var bar_mesh := MeshInstance3D.new()
	var bar_box := BoxMesh.new()
	bar_box.size = Vector3(bar_length, bar_radius * 2.0, bar_radius * 2.0)
	bar_mesh.mesh = bar_box
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = sweeper_color
	bar_mat.roughness = 0.8
	bar_mesh.material_override = bar_mat
	_pivot.add_child(bar_mesh)

	# Sweeper collision area
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(bar_length, bar_radius * 2.2, bar_radius * 2.2)
	shape.shape = box_shape
	area.add_child(shape)
	area.body_entered.connect(_on_bar_body)
	_pivot.add_child(area)

func _physics_process(delta: float) -> void:
	_pivot.rotation.y += rotate_speed * delta
	_hit_timer = maxf(0.0, _hit_timer - delta)

func _on_bar_body(body: Node3D) -> void:
	if _hit_timer > 0.0:
		return

	# Knock direction: tangential velocity of the sweeping bar at contact
	var rel_pos: Vector3 = body.global_position - global_position
	rel_pos.y = 0.0
	var tangent := Vector3(-rel_pos.z, 0, rel_pos.x).normalized()
	if rotate_speed < 0:
		tangent = -tangent
	var knock_dir := (tangent * 0.75 + _flat_dir(global_position, body.global_position) * 0.25).normalized()

	if _is_player(body):
		if body.has_method("is_knocked_back") and body.is_knocked_back():
			return
		_hit_timer = hit_cooldown
		_knock(body, knock_dir * knockback_power + Vector3.UP * knockback_up, 0.75)
		_meme(meme_id, body.global_position)
	elif _is_dog(body):
		_hit_timer = hit_cooldown
		_hit_dog(body, 2.0, knock_dir * 5.0)
		_meme("dog_bonk", body.global_position)
