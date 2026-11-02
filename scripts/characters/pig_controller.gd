extends CharacterBody3D
class_name PigController

signal moved_to_target(pos: Vector3)
signal reached_interactable(target: Node3D)
signal dash_state_changed(remaining: float, cooldown: float)

@export var move_speed: float = 4.5
@export var acceleration: float = 20.0
@export var rotation_speed: float = 12.0
@export var stopping_distance: float = 0.25
@export var interact_distance: float = 2.1
@export var dash_multiplier: float = 1.65
@export var dash_duration: float = 2.0
@export var dash_cooldown: float = 5.0

var target_destination: Vector3 = Vector3.ZERO
var is_moving: bool = false
var interact_target: Node3D = null
var camera: Camera3D = null
var control_mode: String = "explore"
var dash_enabled: bool = false
var dash_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var _stuck_time: float = 0.0
var _pending_click: Vector2 = Vector2.ZERO
var _has_pending_click: bool = false
var _pending_interact: bool = false
var _pending_dash: bool = false
var _jump_buffer := 0.0
var _coyote_time := 0.0
var jumps := 0
var _click_route: Array[Vector3] = []
const JUMP_SPEED := 5.8
const GRAVITY := 18.0

@onready var visual_mesh: Node3D = $VisualMesh

func _ready() -> void:
	preload("res://scripts/art/asset_library.gd").replace_visuals(visual_mesh, "CHAR_01")
	target_destination = global_position
	camera = get_viewport().get_camera_3d()
	floor_snap_length = 0.3

func set_control_mode(mode: String) -> void:
	control_mode = mode
	_cancel_destination()
	_has_pending_click = false
	_pending_interact = false
	_pending_dash = false
	_jump_buffer = 0.0
	_coyote_time = 0.0
	velocity = Vector3.ZERO
	if not _can_move():
		dash_remaining = 0.0

func reset_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_cancel_destination()
	target_destination = pos
	_has_pending_click = false
	_pending_interact = false
	_pending_dash = false
	_jump_buffer = 0.0
	_coyote_time = 0.0
	dash_remaining = 0.0
	cooldown_remaining = 0.0
	if is_instance_valid(visual_mesh):
		visual_mesh.position.y = 0.0
		visual_mesh.rotation.z = 0.0
	dash_state_changed.emit(dash_remaining, cooldown_remaining)

func set_dash_enabled(enabled: bool) -> void:
	dash_enabled = enabled
	if not enabled:
		dash_remaining = 0.0
		cooldown_remaining = 0.0
	dash_state_changed.emit(dash_remaining, cooldown_remaining)

func _can_move() -> bool:
	return control_mode == "explore" or control_mode == "chase"

func _unhandled_input(event: InputEvent) -> void:
	if not _can_move():
		return
	if event.is_action_pressed("action_interact") and not event.is_echo():
		_pending_interact = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action_dash") and not event.is_echo():
		_pending_dash = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action_jump") and not event.is_echo():
		_jump_buffer = .16
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pending_click = event.position
		_has_pending_click = true
	elif event is InputEventScreenTouch and event.pressed:
		_pending_click = event.position
		_has_pending_click = true

# Perform ray queries in the physics step, not in an input callback.
func handle_click_or_tap(screen_pos: Vector2) -> void:
	if not _can_move():
		return
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var ray_from: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_to: Vector3 = ray_from + camera.project_ray_normal(screen_pos) * 200.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Node3D = hit.get("collider") as Node3D
	if collider == null:
		return
	if collider.is_in_group("interactable") and control_mode == "explore":
		interact_target = collider
		var offset: Vector3 = global_position - collider.global_position
		offset.y = 0.0
		if offset.length_squared() < 0.01:
			offset = Vector3.BACK
		target_destination = collider.global_position + offset.normalized() * (interact_distance * 0.75)
	else:
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		# Side faces are not walkable destinations. A blocked top-face target
		# still expires below instead of pushing into the obstacle forever.
		if normal.y < 0.6:
			return
		interact_target = null
		var position_hit: Vector3 = hit.get("position", global_position)
		target_destination = position_hit
	_click_route.clear()
	var world := get_tree().get_first_node_in_group("farm_world")
	if world and world.has_method("click_path"):
		_click_route = world.click_path(global_position, target_destination)
		if not _click_route.is_empty(): target_destination = _click_route.pop_front()
	is_moving = true
	_stuck_time = 0.0
	moved_to_target.emit(target_destination)

func get_nearest_interactable() -> Node3D:
	if control_mode != "explore" or not is_inside_tree():
		return null
	var nearest: Node3D = null
	var best_distance: float = interact_distance
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		var candidate: Node3D = node as Node3D
		if candidate == null or not candidate.is_visible_in_tree():
			continue
		if bool(candidate.get_meta("interaction_disabled", false)):
			continue
		var offset: Vector3 = candidate.global_position - global_position
		if absf(offset.y) > 2.0:
			continue
		offset.y = 0.0
		if offset.length() <= best_distance and _has_line_of_sight(candidate):
			nearest = candidate
			best_distance = offset.length()
	return nearest

func _has_line_of_sight(target: Node3D) -> bool:
	var ray_from: Vector3 = global_position + Vector3.UP * 0.6
	var ray_to: Vector3 = target.global_position + Vector3.UP * 0.3
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Node = hit.get("collider") as Node
	return collider == target or (collider != null and target.is_ancestor_of(collider))

func _try_interact(target: Node3D) -> bool:
	if not is_instance_valid(target) or control_mode != "explore":
		return false
	var offset: Vector3 = target.global_position - global_position
	if absf(offset.y) > 2.0:
		return false
	offset.y = 0.0
	if offset.length() > interact_distance or not _has_line_of_sight(target):
		return false
	_cancel_destination()
	velocity.x = 0.0
	velocity.z = 0.0
	reached_interactable.emit(target)
	return true

func _cancel_destination() -> void:
	_click_route.clear()
	is_moving = false
	interact_target = null
	_stuck_time = 0.0
	var marker: Node3D = get_node_or_null("ClickIndicator") as Node3D
	if marker != null:
		marker.visible = false

func _keyboard_direction() -> Vector3:
	var axis: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if axis.length_squared() < 0.001:
		return Vector3.ZERO
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(axis.x, 0.0, axis.y)
	var right: Vector3 = camera.global_basis.x
	var backward: Vector3 = camera.global_basis.z
	right.y = 0.0
	backward.y = 0.0
	return (right.normalized() * axis.x + backward.normalized() * axis.y).limit_length(1.0)

func _physics_process(delta: float) -> void:
	if not _can_move():
		velocity = Vector3.ZERO
		_update_pose(Vector3.ZERO, delta)
		return
	if _has_pending_click:
		_has_pending_click = false
		handle_click_or_tap(_pending_click)
	if _pending_interact:
		_pending_interact = false
		_try_interact(get_nearest_interactable())
		if not _can_move():
			return
	if _pending_dash:
		_pending_dash = false
		if dash_enabled and cooldown_remaining <= 0.0:
			dash_remaining = dash_duration
			cooldown_remaining = dash_duration + dash_cooldown
	dash_remaining = maxf(0.0, dash_remaining - delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	var move_direction: Vector3 = _keyboard_direction()
	if move_direction.length_squared() > 0.001:
		_cancel_destination()
	elif is_moving:
		if is_instance_valid(interact_target) and _try_interact(interact_target):
			if not _can_move():
				return
		else:
			var offset: Vector3 = target_destination - global_position
			offset.y = 0.0
			if offset.length() <= stopping_distance:
				if not _click_route.is_empty(): target_destination = _click_route.pop_front()
				else: _cancel_destination()
			else:
				move_direction = offset.normalized()
	var speed: float = move_speed * (dash_multiplier if dash_remaining > 0.0 else 1.0)
	velocity.x = move_toward(velocity.x, move_direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * speed, acceleration * delta)
	_coyote_time = .1 if is_on_floor() else maxf(0.0, _coyote_time-delta)
	_jump_buffer = maxf(0.0, _jump_buffer-delta)
	if _jump_buffer>0 and _coyote_time>0:
		velocity.y=JUMP_SPEED
		_jump_buffer=0
		_coyote_time=0
		jumps+=1
	else:
		velocity.y = -0.2 if is_on_floor() else velocity.y - GRAVITY * delta
	var previous_position: Vector3 = global_position
	move_and_slide()
	if is_moving:
		var travelled: Vector3 = global_position - previous_position
		travelled.y = 0.0
		if travelled.length() < move_speed * delta * 0.12:
			_stuck_time += delta
		else:
			_stuck_time = 0.0
		if _stuck_time > 0.55:
			_cancel_destination()
			velocity.x = 0.0
			velocity.z = 0.0
	_update_pose(move_direction, delta)
	dash_state_changed.emit(dash_remaining, cooldown_remaining)

func _update_pose(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.001:
		# The existing pig mesh faces -Z, so atan2 needs the negated vector.
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, rotation_speed * delta))
		var walk_step: float = sin(Time.get_ticks_msec() * 0.014)
		visual_mesh.position.y = absf(walk_step) * 0.045
		visual_mesh.rotation.z = walk_step * 0.035
	else:
		visual_mesh.position.y = move_toward(visual_mesh.position.y, 0.0, delta * 0.8)
		visual_mesh.rotation.z = move_toward(visual_mesh.rotation.z, 0.0, delta * 0.8)
