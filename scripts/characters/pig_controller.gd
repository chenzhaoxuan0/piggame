extends CharacterBody3D

class_name PigController

# 主人公“老朱 (Mr. Pig)” - 2.5D 点击移动控制器 (Point & Click / Tap to Move)
# 风格特色：
# 1. 鼠标点击 / 手机触屏点击地面移动 (极乐迪斯科式操控)
# 2. 点击 NPC 或可交互道具，自动走近并触发深度交互
# 3. 沉稳优雅的踱步走姿与自然的物体物理碰撞推移 (碰翻歪斜杯子、推移椅子)

@export var move_speed: float = 4.5
@export var acceleration: float = 14.0
@export var rotation_speed: float = 10.0
@export var stopping_distance: float = 0.25

# 移动与目标状态
var target_destination: Vector3 = Vector3.ZERO
var is_moving: bool = false
var interact_target: Node3D = null
var interact_distance: float = 1.3

# 节点引用
@onready var visual_mesh: Node3D = $VisualMesh
var camera: Camera3D = null

signal moved_to_target(pos: Vector3)
signal reached_interactable(target: Node3D)

func _ready() -> void:
	target_destination = global_position
	# 寻找场景中的 2.5D 相机
	camera = get_viewport().get_camera_3d()

func _unhandled_input(event: InputEvent) -> void:
	# 支持鼠标左键点击与手机/平板屏幕触摸 (Point & Click / Tap)
	var screen_pos = Vector2.ZERO
	var is_click = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		screen_pos = event.position
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		screen_pos = event.position
		is_click = true

	if is_click and camera:
		handle_click_or_tap(screen_pos)

func handle_click_or_tap(screen_pos: Vector2) -> void:
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	var to = from + dir * 100.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# 排除自身
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		var hit_pos = result.position

		# 如果点击的是可交互对象 (NPC 或 道具)
		if collider.is_in_group("interactable") or collider.is_in_group("npc") or collider.is_in_group("elevator_button"):
			interact_target = collider
			# 移动到该物体稍前一点的位置
			var to_object = (global_position - collider.global_position).normalized()
			target_destination = collider.global_position + to_object * interact_distance
			target_destination.y = global_position.y
			is_moving = true
		else:
			# 点击的是普通地面，自由移动
			interact_target = null
			target_destination = Vector3(hit_pos.x, global_position.y, hit_pos.z)
			is_moving = true

		moved_to_target.emit(target_destination)

func _physics_process(delta: float) -> void:
	if is_moving:
		var flat_current = Vector3(global_position.x, 0, global_position.z)
		var flat_target = Vector3(target_destination.x, 0, target_destination.z)
		var distance = flat_current.distance_to(flat_target)

		if distance <= stopping_distance:
			# 已到达目的地
			is_moving = false
			velocity.x = 0
			velocity.z = 0
			
			# 如果目标是可交互对象，触发交互
			if interact_target:
				reached_interactable.emit(interact_target)
				interact_target = null
		else:
			# 朝目标方向平滑移动
			var move_dir = (flat_target - flat_current).normalized()
			velocity.x = move_toward(velocity.x, move_dir.x * move_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, move_dir.z * move_speed, acceleration * delta)

			# 沉稳的转向插值
			var target_angle = atan2(move_dir.x, move_dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

			# 红猪式绅士大叔的稳重踱步微摆动画
			if visual_mesh:
				var walk_step = sin(Time.get_ticks_msec() * 0.012)
				visual_mesh.position.y = abs(walk_step) * 0.05
				visual_mesh.rotation.z = walk_step * 0.04
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		if visual_mesh:
			visual_mesh.position.y = move_toward(visual_mesh.position.y, 0, delta * 2.0)
			visual_mesh.rotation.z = move_toward(visual_mesh.rotation.z, 0, delta * 2.0)

	# 简易重力
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0

	move_and_slide()

	# 物理碰撞推移 (Untitled Goose Game 式的物体物理互动)
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D:
			# 施加柔和的推力，将碰到的杯子撞倒或把办公椅推开
			var push_dir = -collision.get_normal()
			push_dir.y = 0.2 # 带有轻微上挑，杯子更容易翻倒
			collider.apply_impulse(push_dir.normalized() * 1.5, collision.get_position() - collider.global_position)
