extends CourseTrap
class_name LaunchPad

@export var launch_direction: Vector3 = Vector3(0, 0, -1)
@export var launch_power: float = 9.0
@export var launch_up: float = 7.5
@export var cooldown: float = 1.0
@export var pad_color: Color = Color("F59E0B")

var _cooldown_timer := 0.0
var _top: MeshInstance3D

func _ready() -> void:
	var base := StaticBody3D.new()
	base.collision_layer = 1
	base.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 0.3, 1.7)
	shape.shape = box
	shape.position.y = 0.15
	base.add_child(shape)
	add_child(base)
	var base_mesh := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(1.7, 0.3, 1.7)
	base_mesh.mesh = base_box
	base_mesh.position.y = 0.15
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color("665A48")
	base_mat.roughness = 1.0
	base_mesh.material_override = base_mat
	add_child(base_mesh)
	_top = MeshInstance3D.new()
	var top_box := BoxMesh.new()
	top_box.size = Vector3(1.5, 0.22, 1.5)
	_top.mesh = top_box
	_top.position.y = 0.42
	var mat := StandardMaterial3D.new()
	mat.albedo_color = pad_color
	mat.roughness = 1.0
	_top.material_override = mat
	add_child(_top)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = Vector3(1.5, 0.5, 1.5)
	area_shape.shape = area_box
	area_shape.position.y = 0.7
	area.add_child(area_shape)
	area.body_entered.connect(_on_body)
	add_child(area)

func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

func _on_body(body: Node3D) -> void:
	if not _is_player(body) or _cooldown_timer > 0.0:
		return
	_cooldown_timer = cooldown
	var tween := create_tween()
	tween.tween_property(_top, "scale:y", 0.35, 0.08)
	tween.tween_property(_top, "scale:y", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_knock(body, launch_direction.normalized() * launch_power + Vector3.UP * launch_up, 0.8)
	_meme(meme_id, global_position)