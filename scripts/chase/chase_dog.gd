extends CharacterBody3D
class_name ChaseDog

signal caught_player

@export var chase_speed: float = 3.35
@export var lunge_speed: float = 7.0
@export var windup_duration: float = 0.8
@export var recovery_duration: float = 1.15
@export var capture_radius: float = 0.85

var target: Node3D = null
var active: bool = false
var phase: String = "waiting"
var phase_time: float = 0.75
var _lunge_direction: Vector3 = Vector3.FORWARD
var _captured: bool = false
var _visual: Node3D
var _warning: MeshInstance3D
var _body_material: StandardMaterial3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 0.85
	shape_node.shape = shape
	shape_node.position.y = 0.45
	add_child(shape_node)
	_visual = Node3D.new()
	add_child(_visual)
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.25, 0.27, 0.3)
	_body_material.roughness = 1.0
	_add_box(Vector3(0.6, 0.55, 1.0), Vector3(0, 0.48, 0), _body_material)
	_add_box(Vector3(0.45, 0.42, 0.48), Vector3(0, 0.65, -0.53), _body_material)
	_add_box(Vector3(0.12, 0.3, 0.18), Vector3(-0.16, 0.96, -0.5), _body_material)
	_add_box(Vector3(0.12, 0.3, 0.18), Vector3(0.16, 0.96, -0.5), _body_material)
	var eyes: StandardMaterial3D = StandardMaterial3D.new()
	eyes.albedo_color = Color(1.0, 0.75, 0.3)
	_add_box(Vector3(0.1, 0.08, 0.02), Vector3(-0.12, 0.74, -0.78), eyes)
	_add_box(Vector3(0.1, 0.08, 0.02), Vector3(0.12, 0.74, -0.78), eyes)
	_warning = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 0.72
	ring.rings = 16
	ring.ring_segments = 8
	_warning.mesh = ring
	_warning.position.y = 0.045
	_warning.scale.y = 0.12
	var warning_material: StandardMaterial3D = StandardMaterial3D.new()
	warning_material.albedo_color = Color(1.0, 0.25, 0.16)
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material = warning_material
	_warning.visible = false
	add_child(_warning)

func _add_box(size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = material
	mesh_node.mesh = box
	mesh_node.position = offset
	_visual.add_child(mesh_node)

func configure(player: Node3D, delay: float) -> void:
	target = player
	phase = "waiting"
	phase_time = delay
	_captured = false
	active = true

func set_active(enabled: bool) -> void:
	active = enabled
	velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target):
		return
	var to_player: Vector3 = target.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var movement: Vector3 = Vector3.ZERO
	phase_time -= delta
	match phase:
		"waiting":
			if phase_time <= 0.0:
				phase = "seek"
		"seek":
			movement = _steer_around_obstacles(to_player.normalized()) * chase_speed
			if distance < 3.0:
				phase = "windup"
				phase_time = windup_duration
				_lunge_direction = to_player.normalized()
				_warning.visible = true
		"windup":
			# Lock direction at the start of the warning; side steps are effective.
			if phase_time <= 0.0:
				phase = "lunge"
				phase_time = 0.38
				_warning.visible = false
		"lunge":
			movement = _lunge_direction * lunge_speed
			if distance <= capture_radius and not _captured and _can_reach_player():
				_captured = true
				active = false
				caught_player.emit()
				return
			if phase_time <= 0.0:
				phase = "recover"
				phase_time = recovery_duration
		"recover":
			if phase_time <= 0.0:
				phase = "seek"
	velocity.x = movement.x
	velocity.z = movement.z
	velocity.y = -0.2 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	if movement.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-movement.x, -movement.z), minf(1.0, delta * 12.0))
		_visual.position.y = absf(sin(Time.get_ticks_msec() * 0.019)) * 0.045
	else:
		_visual.position.y = 0.0
	if phase == "windup":
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.025) * 0.1
		_warning.scale = Vector3(pulse, 0.12, pulse)

func _steer_around_obstacles(direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.001:
		return Vector3.ZERO
	var ray_from: Vector3 = global_position + Vector3.UP * 0.45
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_from + direction * 1.25, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return direction
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var tangent: Vector3 = direction.slide(normal)
	tangent.y = 0.0
	if tangent.length_squared() < 0.05:
		tangent = Vector3(-normal.z, 0.0, normal.x)
		if global_position.x > 0.0:
			tangent = -tangent
	return tangent.normalized()

func _can_reach_player() -> bool:
	# A nearby pig on the other side of cover must not be caught through it.
	if not is_instance_valid(target):
		return false
	var ray_from: Vector3 = global_position + Vector3.UP * 0.45
	var ray_to: Vector3 = target.global_position + Vector3.UP * 0.45
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
