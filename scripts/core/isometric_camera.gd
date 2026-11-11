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
@export var tp_pitch: float = 14.5 # Pitch down angle in degrees (constant, zero vertical jitter)
@export var tp_target_height: float = 0.65 # Height of pivot above the pig base
@export var tp_smooth_pos_xz: float = 12.0 # Responsive horizontal tracking
@export var tp_smooth_pos_y: float = 4.5 # Gentle vertical tracking (absorbs footstep/stair wobble)
@export var tp_smooth_yaw: float = 2.4 # Smooth turn follow rate
@export var tp_yaw_deadzone_deg: float = 24.0 # Angle deadzone: minor steering weaves cause 0 camera rotation
@export var tp_auto_follow_yaw: bool = true # Auto-turn yaw toward movement; disable on linear courses (strafe/backpedal would spin the camera)
@export var tp_fov_normal: float = 70.0 # Base FOV
@export var tp_fov_boost: float = 76.0 # Mild Nitro dynamic FOV

var _tp_yaw: float = 0.0 # Current camera yaw in radians (0.0 = looking North -Z)
var _tp_current_pitch: float = 14.5
var _tp_pivot: Vector3 = Vector3.ZERO # Smoothed center of focus
var _tp_current_dist: float = 5.2 # Smoothed collision spring-arm distance
var _rmb_dragging: bool = false
var _manual_look_timer: float = 0.0 # Grace period after mouse dragging before auto-follow resumes

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
	# Mode switches can happen mid-drag (e.g. crossing the finish line while
	# right-dragging); without this reset the stale drag state would keep rotating
	# the camera on the next THIRD_PERSON session.
	_rmb_dragging = false
	if mode == CameraMode.THIRD_PERSON:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = tp_fov_normal
		far = 350.0
		_tp_yaw = 0.0
		_tp_current_pitch = tp_pitch
		_tp_current_dist = tp_distance
		_manual_look_timer = 0.0
		if is_instance_valid(target):
			_tp_pivot = target.global_position + Vector3(0.0, tp_target_height, 0.0)
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
	if _manual_look_timer > 0.0:
		_manual_look_timer = maxf(0.0, _manual_look_timer - delta)

	var target_cb := target as CharacterBody3D
	var speed := 0.0
	var horiz_vel := Vector3.ZERO
	if target_cb != null:
		horiz_vel = Vector3(target_cb.velocity.x, 0.0, target_cb.velocity.z)
		speed = horiz_vel.length()

	# 1. Update smooth target pivot (separate horizontal tracking from vertical footstep damping)
	var raw_pivot := target.global_position + Vector3(0.0, tp_target_height, 0.0)
	if _tp_pivot == Vector3.ZERO:
		_tp_pivot = raw_pivot
	else:
		_tp_pivot.x = lerpf(_tp_pivot.x, raw_pivot.x, 1.0 - exp(-tp_smooth_pos_xz * delta))
		_tp_pivot.z = lerpf(_tp_pivot.z, raw_pivot.z, 1.0 - exp(-tp_smooth_pos_xz * delta))
		_tp_pivot.y = lerpf(_tp_pivot.y, raw_pivot.y, 1.0 - exp(-tp_smooth_pos_y * delta))

	# 2. Smooth yaw auto-follow with angular deadzone (eliminates swaying during minor steering)
	if tp_auto_follow_yaw and speed > 1.0 and not _rmb_dragging and _manual_look_timer <= 0.0:
		var move_angle := atan2(-horiz_vel.x, -horiz_vel.z)
		var angle_diff := wrapf(move_angle - _tp_yaw, -PI, PI)
		var deadzone_rad := deg_to_rad(tp_yaw_deadzone_deg)
		if absf(angle_diff) > deadzone_rad:
			var excess := angle_diff - signf(angle_diff) * deadzone_rad
			_tp_yaw = lerp_angle(_tp_yaw, _tp_yaw + excess, 1.0 - exp(-tp_smooth_yaw * delta))

	# 3. Dynamic Nitro FOV (gentle transition, max 76 deg)
	var target_fov := tp_fov_normal
	if speed > 7.0:
		target_fov = lerpf(tp_fov_normal, tp_fov_boost, clampf((speed - 7.0) / 10.0, 0.0, 1.0))
	fov = lerpf(fov, target_fov, 1.0 - exp(-3.0 * delta))

	# 4. Construct rock-solid orientation from (pitch, yaw) - strictly 0 roll, stable horizon
	var cam_rot := Basis.from_euler(Vector3(deg_to_rad(-_tp_current_pitch), _tp_yaw, 0.0), EULER_ORDER_YXZ)

	# 5. Spring-arm obstacle detection
	var desired_offset := cam_rot * Vector3(0.0, 0.0, tp_distance)
	var desired_cam_pos := _tp_pivot + desired_offset
	var target_dist := tp_distance

	var space := get_world_3d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters3D.create(_tp_pivot, desired_cam_pos, 1)
		if target_cb != null:
			query.exclude = [target_cb.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.get("position", desired_cam_pos)
			var hit_dist := _tp_pivot.distance_to(hit_pos)
			target_dist = clampf(hit_dist - 0.25, 1.2, tp_distance)

	_tp_current_dist = lerpf(_tp_current_dist, target_dist, 1.0 - exp(-10.0 * delta))

	# 6. Apply final position and basis directly without shaky look_at()
	global_basis = cam_rot
	global_position = _tp_pivot + cam_rot * Vector3(0.0, 0.0, _tp_current_dist)

func snap_to_target(yaw: float = NAN) -> void:
	_acquire_target()
	if not is_instance_valid(target):
		return
	if mode == CameraMode.THIRD_PERSON:
		if not is_nan(yaw):
			_tp_yaw = yaw
		_tp_pivot = target.global_position + Vector3(0.0, tp_target_height, 0.0)
		_tp_current_pitch = tp_pitch
		_tp_current_dist = tp_distance
		var cam_rot := Basis.from_euler(Vector3(deg_to_rad(-_tp_current_pitch), _tp_yaw, 0.0), EULER_ORDER_YXZ)
		global_basis = cam_rot
		global_position = _tp_pivot + cam_rot * Vector3(0.0, 0.0, _tp_current_dist)
		_initialized = true
		return

	_focus = target.global_position + Vector3(0, 0.5, -look_ahead_factor)
	global_position = _focus + camera_offset
	look_at(_focus, Vector3.UP)
	_initialized = true
	_update_foliage_cutout()

func smooth_turn_yaw(target_yaw: float, duration := 0.45) -> void:
	# For courses with corners (nightmare prologue serpentine): yaw stays locked
	# to the corridor axis, but a turn trigger rotates it along the new leg over
	# a beat instead of snapping 90 degrees in one frame.
	if mode != CameraMode.THIRD_PERSON:
		return
	var from := _tp_yaw
	var diff := wrapf(target_yaw - from, -PI, PI)
	if absf(diff) < 0.02:
		return
	var tween := create_tween()
	tween.tween_method(func(t: float):
		_tp_yaw = from + diff * t
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if mode != CameraMode.THIRD_PERSON:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rmb_dragging = event.pressed
		if not _rmb_dragging:
			_manual_look_timer = 1.0
	elif _rmb_dragging and event is InputEventMouseMotion:
		_tp_yaw -= event.relative.x * 0.004
		_tp_current_pitch = clampf(_tp_current_pitch - event.relative.y * 0.2, 5.0, 45.0)
		_manual_look_timer = 1.0

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
