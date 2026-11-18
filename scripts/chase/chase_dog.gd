extends CharacterBody3D
class_name ChaseDog

signal caught_player
signal grapple_started(dog: ChaseDog)
# Phantom dogs announce their dissolve BEFORE the 0.4 s shrink tween: the
# chase manager drops its ref here (queue_free only lands later), so no
# consumer is left holding a freed dog in its roster.
signal dissolved(dog: ChaseDog)

@export var chase_speed: float = 5.4
@export var lunge_speed: float = 9.2
@export var windup_duration: float = 0.42
@export var recovery_duration: float = 0.50
@export var capture_radius: float = 1.45
# Which catalog model dresses the chaser. "CHAR_06" is the farm dog (default,
# every existing use); the nightmare prologue passes "CHAR_07" to play the
# dream-farmer with the stun prod - the chase behavior is identical.
@export var visual_asset_id: String = "CHAR_06"

var target: Node3D = null
var active: bool = false
var phase: String = "waiting"
var phase_time: float = 0.75
var is_phantom: bool = false
var is_discerned: bool = false
var _is_dissolving: bool = false
var _lunge_direction: Vector3 = Vector3.FORWARD
var _captured: bool = false
var _visual: Node3D
var _animator: Node = null
var _warning: MeshInstance3D
var _body_material: StandardMaterial3D
var course: Array[Vector3] = []
const LAYOUT = preload("res://scripts/levels/farm_layout.gd")

func _ready() -> void:
	add_to_group("chase_dogs")
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
	ring.inner_radius = 0.82
	ring.outer_radius = 1.05
	ring.rings = 28
	ring.ring_segments = 16
	_warning.mesh = ring
	_warning.position.y = 0.04
	_warning.scale = Vector3(1.0, 0.12, 1.0)
	var warning_material: StandardMaterial3D = StandardMaterial3D.new()
	warning_material.albedo_color = Color(1.0, 0.20, 0.12, 0.95)
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material = warning_material

	# Inner glowing danger disc for clear visual telegraph under the pig
	var inner_disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.82
	cyl.bottom_radius = 0.82
	cyl.height = 0.005
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(1.0, 0.22, 0.14, 0.28)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material = disc_mat
	inner_disc.mesh = cyl
	_warning.add_child(inner_disc)

	_warning.visible = false
	_warning.top_level = true
	add_child(_warning)
	preload("res://scripts/art/asset_library.gd").replace_visuals(_visual, visual_asset_id)

## Animation-first action helper: plays a skeletal clip when the dressed model
## has one (CHAR_06 dog / CHAR_07 dream-farmer), returns false so callers keep
## their procedural fallback.
func _resolve_animator() -> Node:
	if _animator == null and is_instance_valid(_visual):
		var found := _visual.find_children("ActorAnimation", "Node", true, false)
		_animator = found[0] if not found.is_empty() else null
	return _animator

func _play_action(clip: String) -> bool:
	var animator := _resolve_animator()
	if animator != null and animator.has_method("play_oneshot"):
		return animator.play_oneshot(clip, 1.25)
	return false

## Skeletal locomotion owns the run bounce when the model carries walk clips.
func _has_skeletal_locomotion() -> bool:
	var animator := _resolve_animator()
	return animator != null and animator.has_method("has_clip") and animator.has_clip("walk")

func _add_box(size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = material
	mesh_node.mesh = box
	mesh_node.position = offset
	_visual.add_child(mesh_node)

func set_phantom(phantom: bool) -> void:
	is_phantom = phantom
	if is_phantom:
		name = "PhantomDog_" + str(get_instance_id())
		_body_material.albedo_color = Color(0.28, 0.25, 0.38, 1.0)
	update_discern_state(is_discerned)

func update_discern_state(discerned: bool) -> void:
	is_discerned = discerned
	if not is_phantom:
		return
	if is_discerned:
		# Translucent phantom appearance for discern mode (Untitled Goose Game / low poly ghost feel)
		_apply_phantom_materials(self, true)
	else:
		_apply_phantom_materials(self, false)

func _apply_phantom_materials(node: Node, translucent: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if translucent:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.68, 0.65, 0.88, 0.42)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mesh_instance.material_override = mat
		else:
			mesh_instance.material_override = null
	for child in node.get_children():
		_apply_phantom_materials(child, translucent)

func stun(duration: float = 2.0, knockback: Vector3 = Vector3.ZERO) -> void:
	phase = "stun"
	phase_time = duration
	_captured = false
	velocity = knockback
	if is_instance_valid(_warning): _warning.visible = false

func dissolve_phantom() -> void:
	if _is_dissolving: return
	_is_dissolving = true
	active = false
	dissolved.emit(self)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()

func configure(player: Node3D, delay: float) -> void:
	target = player
	phase = "waiting"
	phase_time = delay
	_captured = false
	_is_dissolving = false
	active = true

func is_threatening_player() -> bool:
	if not active or not is_instance_valid(target):
		return false
	if phase == "windup" or phase == "lunge":
		var dist: float = global_position.distance_to(target.global_position)
		return dist <= 5.5 and _can_reach_player()
	return false

func set_active(enabled: bool) -> void:
	active = enabled
	velocity = Vector3.ZERO
	if not enabled and is_instance_valid(_warning):
		_warning.visible = false

func _exit_tree() -> void:
	if is_instance_valid(_warning):
		_warning.visible = false

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
			movement = _steer_around_obstacles(_course_direction(to_player)) * chase_speed
			if distance <= capture_radius and not _captured and _can_reach_player():
				if is_phantom and is_discerned:
					dissolve_phantom()
					return
				if target.has_method("is_dodging") and target.is_dodging():
					_on_dodge_whiff()
					return
				if _can_start_grapple():
					_captured = true
					phase = "grapple"
					# Grapple hold tracks the host QTE window (QTE_TIME_TOTAL + a beat):
					# with the 8-hits/2.2 s struggle clock the old 3.5 s hold outlived
					# the fail path and let the dog hang on doing nothing.
					phase_time = 2.4
					grapple_started.emit(self)
					return
			if distance < 3.5 and _can_reach_player():
				phase = "windup"
				phase_time = windup_duration
				_play_action("bark")
				_lunge_direction = to_player.normalized()
				_warning.visible = true
				if is_instance_valid(target):
					_warning.global_position = target.global_position + Vector3(0, 0.04, 0)
		"windup":
			# Dynamically track player angle during quick windup
			_lunge_direction = _lunge_direction.lerp(to_player.normalized(), minf(1.0, delta * 12.0)).normalized()
			# Keep charging forward with residual momentum during windup
			movement = _steer_around_obstacles(_lunge_direction) * (chase_speed * 0.6)
			if distance <= capture_radius and not _captured and _can_reach_player():
				if is_phantom and is_discerned:
					dissolve_phantom()
					return
				if target.has_method("is_dodging") and target.is_dodging():
					_on_dodge_whiff()
					return
				if _can_start_grapple():
					_captured = true
					phase = "grapple"
					# Grapple hold tracks the host QTE window (QTE_TIME_TOTAL + a beat):
					# with the 8-hits/2.2 s struggle clock the old 3.5 s hold outlived
					# the fail path and let the dog hang on doing nothing.
					phase_time = 2.4
					_warning.visible = false
					grapple_started.emit(self)
					return
			if phase_time <= 0.0:
				phase = "lunge"
				phase_time = 0.38
				_play_action("attack")
				_warning.visible = false
		"lunge":
			movement = _lunge_direction * lunge_speed
			if distance <= capture_radius and not _captured and _can_reach_player():
				if is_phantom and is_discerned:
					# Player has the sheep's power of discernment: phantom harmlessly dissipates!
					dissolve_phantom()
					return
				if target.has_method("is_dodging") and target.is_dodging():
					# Player dodged! Dog whiffs the lunge and skids into recovery
					_on_dodge_whiff()
					return
				if _can_start_grapple():
					_captured = true
					phase = "grapple"
					# Grapple hold tracks the host QTE window (QTE_TIME_TOTAL + a beat):
					# with the 8-hits/2.2 s struggle clock the old 3.5 s hold outlived
					# the fail path and let the dog hang on doing nothing.
					phase_time = 2.4
					grapple_started.emit(self)
					return
			if phase_time <= 0.0:
				phase = "recover"
				phase_time = recovery_duration
		"grapple":
			movement = Vector3.ZERO
			if is_instance_valid(target):
				global_position = global_position.lerp(target.global_position - _lunge_direction * 0.45, delta * 8.0)
				_visual.position.x = sin(Time.get_ticks_msec() * 0.04) * 0.07
			if phase_time <= 0.0:
				active = false
				caught_player.emit()
				return
		"recover":
			# Maintain residual momentum during brief recovery
			movement = _lunge_direction * (chase_speed * 0.35)
			if phase_time <= 0.0:
				phase = "seek"
		"stun":
			movement = Vector3.ZERO
			if phase_time <= 0.0:
				phase = "seek"
	if phase in ["seek", "windup", "lunge"]:
		_check_jump_obstacles(delta, movement)
	velocity.x = movement.x
	velocity.z = movement.z
	velocity.y = -0.2 if is_on_floor() and velocity.y <= 0.0 else velocity.y - 14.0 * delta
	move_and_slide()
	if movement.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-movement.x, -movement.z), minf(1.0, delta * 12.0))
		if not _has_skeletal_locomotion():
			_visual.position.y = absf(sin(Time.get_ticks_msec() * 0.019)) * 0.045
	else:
		_visual.position.y = 0.0
	if phase == "windup":
		var progress: float = 1.0 - (phase_time / maxf(0.01, windup_duration))
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.035) * 0.12
		var sz: float = lerpf(0.9, 1.45, progress) * pulse
		_warning.scale = Vector3(sz, 0.12, sz)
		if is_instance_valid(target):
			_warning.global_position = target.global_position + Vector3(0, 0.04, 0)
		else:
			_warning.global_position = global_position + Vector3(0, 0.05, 0) + _lunge_direction * 0.45

func _steer_around_obstacles(direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.001:
		return Vector3.ZERO
	var ray_from: Vector3 = global_position + Vector3.UP * 0.45
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_from + direction * 1.35, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return direction

	# Check if this is a low obstacle (e.g. log, cart, hurdle) that the dog can leap over
	var ray_high_from: Vector3 = global_position + Vector3.UP * 0.95
	var q_high: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_high_from, ray_high_from + direction * 1.5, 1)
	q_high.exclude = [get_rid()]
	var hit_high: Dictionary = get_world_3d().direct_space_state.intersect_ray(q_high)
	if hit_high.is_empty():
		# Head clearance is wide open -> don't deflect sideways, charge straight to jump!
		return direction

	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var tangent: Vector3 = direction.slide(normal)
	tangent.y = 0.0
	if tangent.length_squared() < 0.05:
		tangent = Vector3(-normal.z, 0.0, normal.x)
		if global_position.x > 0.0:
			tangent = -tangent
	return tangent.normalized()

func _course_direction(to_player: Vector3) -> Vector3:
	if course.is_empty(): return to_player.normalized()
	var here := LAYOUT.closest_on_path(global_position,course)
	var there := LAYOUT.closest_on_path(target.global_position,course)
	if here.index==there.index and _can_reach_player(): return to_player.normalized()
	var next_index: int = mini(here.index+1,course.size()-1) if there.progress>=here.progress else here.index
	var waypoint: Vector3 = course[next_index]
	if global_position.distance_to(waypoint)<1.2:
		next_index=clampi(next_index+(1 if there.progress>=here.progress else -1),0,course.size()-1)
		waypoint=course[next_index]
	var direction:=waypoint-global_position
	direction.y=0
	return direction.normalized()

func _can_reach_player() -> bool:
	# A nearby pig on the other side of cover must not be caught through it.
	if not is_instance_valid(target):
		return false
	var ray_from: Vector3 = global_position + Vector3.UP * 0.45
	var ray_to: Vector3 = target.global_position + Vector3.UP * 0.45
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _check_jump_obstacles(_delta: float, direction: Vector3) -> void:
	if not is_on_floor() or direction.length_squared() < 0.01:
		return
	var dir_norm := direction.normalized()
	# Low ray: detect obstacle at waist height (Y + 0.35)
	var ray_low_from := global_position + Vector3.UP * 0.35
	var ray_low_to := ray_low_from + dir_norm * 1.85
	var q_low := PhysicsRayQueryParameters3D.create(ray_low_from, ray_low_to, 1)
	q_low.exclude = [get_rid()]
	var hit_low := get_world_3d().direct_space_state.intersect_ray(q_low)

	if not hit_low.is_empty():
		# High ray: detect if head clearance (Y + 0.95) is open
		var ray_high_from := global_position + Vector3.UP * 0.95
		var ray_high_to := ray_high_from + dir_norm * 1.85
		var q_high := PhysicsRayQueryParameters3D.create(ray_high_from, ray_high_to, 1)
		q_high.exclude = [get_rid()]
		var hit_high := get_world_3d().direct_space_state.intersect_ray(q_high)

		# Low hits (like logs, hurdles, low crates) and head is clear -> LEAP!
		if hit_high.is_empty():
			velocity.y = 5.8
			velocity.x += dir_norm.x * 3.2
			velocity.z += dir_norm.z * 3.2
			return

	# Proximity check for logs defined on the course
	for log_entry in LAYOUT.LOGS:
		var log_pos: Vector3 = log_entry.a.lerp(log_entry.b, log_entry.t)
		if global_position.distance_to(log_pos) < 2.4 and dir_norm.dot((log_pos - global_position).normalized()) > 0.3:
			velocity.y = 5.8
			velocity.x += dir_norm.x * 3.0
			velocity.z += dir_norm.z * 3.0
			return

	# If player jumped up onto high ground/obstacle, dog leaps in pursuit
	if is_instance_valid(target) and target.global_position.y > global_position.y + 0.45 and global_position.distance_to(target.global_position) < 3.5:
		velocity.y = 5.8
		velocity.x += dir_norm.x * 2.8
		velocity.z += dir_norm.z * 2.8

func _on_dodge_whiff() -> void:
	phase = "recover"
	phase_time = 0.55
	if is_instance_valid(_warning):
		_warning.visible = false
	if is_instance_valid(target) and target.has_method("notify_dodge_success"):
		target.notify_dodge_success(self)

func _can_start_grapple() -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method("is_dodging") and target.is_dodging():
		return false
	var parent := get_parent()
	if is_instance_valid(parent) and parent.has_method("can_dog_grapple"):
		return parent.can_dog_grapple()
	return true
