extends CourseTrap
class_name RollingHay

const ASSETS = preload("res://scripts/art/asset_library.gd")

@export var roll_impulse: float = 9.0
@export var roll_direction: Vector3 = Vector3(0, 0, -1)
@export var knockback_power: float = 7.0
@export var knockback_up: float = 5.0
@export var reset_time: float = 4.0
@export var auto_trigger_radius: float = 0.0
@export var hay_color: Color = Color("F59E0B")
# Zone art styles must not mix: the Lux3D hay bale is the ox-field (course 1)
# look by default, so other zones point `lux_asset_id` at their own zone model
# (course 4 giant tire) or opt out and recolor the procedural cylinder instead.
@export var use_lux_model: bool = true
@export var lux_asset_id: String = "PROP_C1_HAYBALE"

var _bale: RigidBody3D
var _start_pos: Vector3
var _state := "armed"
var _timer := 0.0
var _hit_timer := 0.0

func _ready() -> void:
	_bale = RigidBody3D.new()
	_bale.collision_layer = 1
	_bale.collision_mask = 1 | 2
	_bale.freeze = true
	_bale.mass = 2.0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 1.2
	shape.shape = cyl
	shape.rotation.z = PI * 0.5
	_bale.add_child(shape)
	var lux_bale: Node3D = ASSETS.make(lux_asset_id) if use_lux_model else null
	if lux_bale:
		_bale.add_child(lux_bale)
	else:
		var mesh := MeshInstance3D.new()
		var mesh_cyl := CylinderMesh.new()
		mesh_cyl.top_radius = 0.7
		mesh_cyl.bottom_radius = 0.7
		mesh_cyl.height = 1.2
		mesh.mesh = mesh_cyl
		mesh.rotation.z = PI * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = hay_color
		mat.roughness = 1.0
		mesh.material_override = mat
		_bale.add_child(mesh)
	var contact := Area3D.new()
	contact.collision_layer = 0
	contact.collision_mask = 2
	var contact_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.95
	contact_shape.shape = sphere
	contact.add_child(contact_shape)
	contact.body_entered.connect(_on_contact)
	_bale.add_child(contact)
	add_child(_bale)
	_start_pos = _bale.position
	if auto_trigger_radius > 0.0:
		var trigger := Area3D.new()
		trigger.collision_layer = 0
		trigger.collision_mask = 2
		var trigger_shape := CollisionShape3D.new()
		var trigger_sphere := SphereShape3D.new()
		trigger_sphere.radius = auto_trigger_radius
		trigger_shape.shape = trigger_sphere
		trigger.add_child(trigger_shape)
		trigger.body_entered.connect(_on_trigger)
		add_child(trigger)

func release() -> void:
	if _state != "armed":
		return
	_state = "rolling"
	_timer = reset_time
	_bale.freeze = false
	_bale.apply_central_impulse(roll_direction.normalized() * roll_impulse + Vector3.UP * 1.5)
	_meme(telegraph_meme_id, global_position)

func _on_trigger(body: Node3D) -> void:
	if _is_player(body):
		release()

func _on_contact(body: Node3D) -> void:
	if not _is_player(body) or _state != "rolling" or _hit_timer > 0.0:
		return
	_hit_timer = 0.8
	var dir := _flat_dir(_bale.global_position, body.global_position)
	_knock(body, dir * knockback_power + Vector3.UP * knockback_up, 0.7)
	_meme(meme_id, body.global_position)

func _physics_process(delta: float) -> void:
	_hit_timer = maxf(0.0, _hit_timer - delta)
	if _state != "rolling":
		return
	_timer -= delta
	if _timer <= 0.0 or _bale.global_position.y < -15.0:
		_reset()

func _reset() -> void:
	_state = "armed"
	_bale.freeze = true
	_bale.position = _start_pos
	_bale.rotation = Vector3.ZERO
	_bale.linear_velocity = Vector3.ZERO
	_bale.angular_velocity = Vector3.ZERO