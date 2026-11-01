extends Camera3D

class_name IsometricCamera

# Orthographic greybox camera. Geometry and gameplay stay legible before final art.

@export var target_path: NodePath
@export var smooth_speed: float = 5.0
@export var camera_offset: Vector3 = Vector3(9.0, 15.0, 12.0)
@export var look_ahead_factor: float = 1.5

var target: Node3D = null
var follow_enabled: bool = true
var _focus: Vector3 = Vector3.ZERO
var _initialized: bool = false

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 19.0
	near = 0.1
	far = 180.0
	current = true
	_acquire_target()
	if is_instance_valid(target):
		snap_to_target()

func _physics_process(delta: float) -> void:
	if not follow_enabled:
		return
	_acquire_target()
	if not is_instance_valid(target):
		return
	if not _initialized:
		snap_to_target()
	var desired_focus := target.global_position + Vector3(0, 0.5, -look_ahead_factor)
	_focus = _focus.lerp(desired_focus, 1.0 - exp(-smooth_speed * delta))
	global_position = _focus + camera_offset
	look_at(_focus, Vector3.UP)

func snap_to_target() -> void:
	_acquire_target()
	if not is_instance_valid(target):
		return
	_focus = target.global_position + Vector3(0, 0.5, -look_ahead_factor)
	global_position = _focus + camera_offset
	look_at(_focus, Vector3.UP)
	_initialized = true

func _acquire_target() -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
