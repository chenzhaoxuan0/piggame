extends Camera3D

class_name IsometricCamera

# Orthographic pastoral view: enough side view to read roofs, stonework and cliffs.

@export var target_path: NodePath
@export var smooth_speed: float = 5.0
const NORMAL_OFFSET := Vector3(5.0, 5.25, 7.0)
const TEST_OFFSET := Vector3(10.0, 10.5, 14.0)
const NORMAL_SIZE := 8.0
const TEST_SIZE := 16.0
@export var camera_offset: Vector3 = NORMAL_OFFSET
@export var look_ahead_factor: float = 0.75
var test_high_view := false

var target: Node3D = null
var follow_enabled: bool = true
var _focus: Vector3 = Vector3.ZERO
var _initialized: bool = false
var _canopy_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = NORMAL_SIZE
	near = 0.1
	far = 300.0
	current = true
	_acquire_target()
	if is_instance_valid(target):
		snap_to_target()

func set_test_high_view(enabled: bool) -> void:
	test_high_view = enabled
	camera_offset = TEST_OFFSET if enabled else NORMAL_OFFSET
	size = TEST_SIZE if enabled else NORMAL_SIZE
	look_ahead_factor = 1.5 if enabled else .75
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
	_update_foliage_cutout()

func snap_to_target() -> void:
	_acquire_target()
	if not is_instance_valid(target):
		return
	_focus = target.global_position + Vector3(0, 0.5, -look_ahead_factor)
	global_position = _focus + camera_offset
	look_at(_focus, Vector3.UP)
	_initialized = true
	_update_foliage_cutout()

func _update_foliage_cutout() -> void:
	if _canopy_materials.is_empty():
		var farm:=get_tree().get_first_node_in_group("farm_world")
		if farm:
			for mesh in farm.find_children("TreeCanopies*","MeshInstance3D",true,false):
				var material:=mesh.material_override as ShaderMaterial
				if material and not _canopy_materials.has(material): _canopy_materials.append(material)
	for material in _canopy_materials:
		material.set_shader_parameter("player_focus",target.global_position+Vector3.UP*.65)
		material.set_shader_parameter("player_camera",global_position)

func _acquire_target() -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
