extends Camera3D

class_name IsometricCamera

enum CameraMode {
	ISOMETRIC,
	THIRD_PERSON
}

@export var mode: CameraMode = CameraMode.ISOMETRIC
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

# Third-person chase camera parameters (Fall Guys / Mario Kart perspective)
@export var tp_distance: float = 5.2 # Follow distance behind the pig
@export var tp_height: float = 2.4 # Height above the pig
@export var tp_smooth_pos: float = 8.0 # Position follow responsiveness
@export var tp_smooth_yaw: float = 4.0 # Turn tracking responsiveness
@export var tp_fov_normal: float = 70.0 # Base FOV
@export var tp_fov_boost: float = 82.0 # Nitro boost dynamic FOV
var _tp_yaw: float = 0.0 # Yaw angle in radians (0.0 = looking North -Z)
var _rmb_dragging: bool = false

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	_apply_mode_settings()
	near = 0.1
	current = true
	_acquire_target()
	if is_instance_valid(target):
		snap_to_target()

func set_camera_mode(new_mode: CameraMode) -> void:
	mode = new_mode
	_apply_mode_settings()
	snap_to_target()

func _apply_mode_settings() -> void:
	if mode == CameraMode.THIRD_PERSON:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = tp_fov_normal
		far = 350.0
		_tp_yaw = 0.0
	else:
		projection = Camera3D.PROJECTION_ORTHOGONAL
		size = TEST_SIZE if test_high_view else NORMAL_SIZE
		far = 300.0
		camera_offset = TEST_OFFSET if test_high_view else NORMAL_OFFSET

func set_test_high_view(enabled: bool) -> void:
	test_high_view = enabled
	if mode == CameraMode.ISOMETRIC:
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

	if mode == CameraMode.THIRD_PERSON:
		_process_third_person(delta)
	else:
		_process_isometric(delta)

func _process_isometric(delta: float) -> void:
	var desired_focus := target.global_position + Vector3(0, 0.5, -look_ahead_factor)
	_focus = _focus.lerp(desired_focus, 1.0 - exp(-smooth_speed * delta))
	global_position = _focus + camera_offset
	look_at(_focus, Vector3.UP)
	_update_foliage_cutout()

func _process_third_person(delta: float) -> void:
	# 1. Update yaw to track pig's horizontal movement direction
	var target_cb := target as CharacterBody3D
	var speed := 0.0
	if target_cb != null:
		var horiz_vel := Vector3(target_cb.velocity.x, 0.0, target_cb.velocity.z)
		speed = horiz_vel.length()
		if speed > 0.4:
			# Direction from target to camera should be opposite of movement
			var target_yaw := atan2(-horiz_vel.x, -horiz_vel.z)
			_tp_yaw = lerp_angle(_tp_yaw, target_yaw, tp_smooth_yaw * delta)

	# 2. Dynamic Nitro FOV
	var target_fov := tp_fov_normal
	if speed > 7.0:
		target_fov = lerpf(tp_fov_normal, tp_fov_boost, clampf((speed - 7.0) / 12.0, 0.0, 1.0))
	fov = lerpf(fov, target_fov, 4.0 * delta)

	# 3. Position camera behind target along _tp_yaw
	var cam_dir := Vector3(sin(_tp_yaw), 0.0, cos(_tp_yaw))
	var target_pos := target.global_position
	var desired_cam_pos := target_pos + cam_dir * tp_distance + Vector3(0.0, tp_height, 0.0)

	# Simple obstacle/ground clearance raycast
	var space := get_world_3d().direct_space_state
	if space != null:
		var ray_from := target_pos + Vector3(0.0, 1.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(ray_from, desired_cam_pos, 1)
		if target_cb != null:
			query.exclude = [target_cb.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.get("position", desired_cam_pos)
			var hit_norm: Vector3 = hit.get("normal", Vector3.UP)
			desired_cam_pos = hit_pos + hit_norm * 0.25

	global_position = global_position.lerp(desired_cam_pos, 1.0 - exp(-tp_smooth_pos * delta))

	# 4. Aim camera at target upper body and forward sightline
	var look_target := target_pos + Vector3(0.0, 0.9, 0.0) - cam_dir * 1.5
	look_at(look_target, Vector3.UP)

func snap_to_target() -> void:
	_acquire_target()
	if not is_instance_valid(target):
		return
	if mode == CameraMode.THIRD_PERSON:
		var cam_dir := Vector3(sin(_tp_yaw), 0.0, cos(_tp_yaw))
		global_position = target.global_position + cam_dir * tp_distance + Vector3(0.0, tp_height, 0.0)
		var look_target := target.global_position + Vector3(0.0, 0.9, 0.0) - cam_dir * 1.5
		look_at(look_target, Vector3.UP)
		_initialized = true
		return

	_focus = target.global_position + Vector3(0, 0.5, -look_ahead_factor)
	global_position = _focus + camera_offset
	look_at(_focus, Vector3.UP)
	_initialized = true
	_update_foliage_cutout()

func _unhandled_input(event: InputEvent) -> void:
	if mode != CameraMode.THIRD_PERSON:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rmb_dragging = event.pressed
	elif _rmb_dragging and event is InputEventMouseMotion:
		_tp_yaw -= event.relative.x * 0.005

func _update_foliage_cutout() -> void:
	if _canopy_materials.is_empty():
		var farm := get_tree().get_first_node_in_group("farm_world")
		if farm:
			for mesh in farm.find_children("*", "GeometryInstance3D", true, false):
				var material := mesh.material_override as ShaderMaterial
				if material and material.get_shader_parameter("canopy_cutout") == true and not _canopy_materials.has(material):
					_canopy_materials.append(material)
	for material in _canopy_materials:
		material.set_shader_parameter("player_focus", target.global_position + Vector3.UP * 0.65)
		material.set_shader_parameter("player_camera", global_position)

func _acquire_target() -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
