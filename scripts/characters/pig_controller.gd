extends CharacterBody3D

class_name PigController

# 特立独行的猪 - 角色控制器 (2.5D Isometric Perspective)
# 灵感来源：Untitled Goose Game (大鹅模拟器)
# 技能：
# 1. 敏捷碎步走 (Walk)
# 2. 猪叫惊扰 (Oink / Honk - Space)
# 3. 职场拱撞 / 冲刺 (Dash - Shift / J)
# 4. 拱翻 / 互动 (Interact - E / K)

@export var move_speed: float = 6.0
@export var dash_speed: float = 14.0
@export var acceleration: float = 18.0
@export var rotation_speed: float = 12.0

# 状态变量
var is_dashing: bool = false
var dash_timer: float = 0.0
@export var dash_duration: float = 0.28
var dash_cooldown: float = 0.0
@export var dash_cooldown_max: float = 0.8

# 猪叫状态
var is_oinking: bool = false
var oink_cooldown: float = 0.0

# 携带物 (如工牌)
var carried_item: Node3D = null

# 节点引用
@onready var visual_mesh: Node3D = $VisualMesh
@onready var oink_area: Area3D = $OinkArea
@onready var interact_raycast: RayCast3D = $InteractRayCast

signal oink_triggered(position: Vector3)
signal dashed()
signal interacted_with(target: Node)

func _physics_process(delta: float) -> void:
	# 冷却计时
	if dash_cooldown > 0.0:
		dash_cooldown -= delta
	if oink_cooldown > 0.0:
		oink_cooldown -= delta
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

	# 处理输入
	handle_actions()
	handle_movement(delta)

func handle_movement(delta: float) -> void:
	# 获取基础输入
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	
	input_dir = input_dir.normalized()

	# 2.5D Isometric 视角角度映射 (45度斜向投影校正)
	# W 对应向屏幕左上方走，D 对应向屏幕右上方走，符合大鹅模拟器手感
	var iso_dir = Vector3(
		input_dir.x - input_dir.y,
		0,
		input_dir.x + input_dir.y
	).normalized()

	var target_speed = dash_speed if is_dashing else move_speed
	var target_velocity_xz = iso_dir * target_speed

	velocity.x = move_toward(velocity.x, target_velocity_xz.x, acceleration * delta * 5.0)
	velocity.z = move_toward(velocity.z, target_velocity_xz.z, acceleration * delta * 5.0)

	# 重力模拟
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0

	move_and_slide()

	# 转向动画与面向
	if iso_dir.length() > 0.1:
		var target_angle = atan2(iso_dir.x, iso_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		
		# 跑步小摇摆（未挂载骨骼时的Q弹程序化摆动）
		if visual_mesh:
			var bounce = sin(Time.get_ticks_msec() * 0.018) * 0.08
			visual_mesh.position.y = abs(bounce)
			visual_mesh.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.08

func handle_actions() -> void:
	# 冲撞 (Dash)
	if Input.is_action_just_pressed("action_dash") and dash_cooldown <= 0.0 and not is_dashing:
		trigger_dash()

	# 叫唤 (Oink)
	if Input.is_action_just_pressed("action_oink") and oink_cooldown <= 0.0:
		trigger_oink()

	# 交互 (Interact)
	if Input.is_action_just_pressed("action_interact"):
		trigger_interact()

func trigger_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown = dash_cooldown_max
	dashed.emit()
	print("[Pig] 猪突猛进！冲撞前方！")
	
	# 撞击判定：检测前方的可推人物品并施加冲量
	if interact_raycast and interact_raycast.is_colliding():
		var collider = interact_raycast.get_collider()
		if collider is RigidBody3D:
			var push_dir = -global_transform.basis.z
			collider.apply_central_impulse(push_dir * 12.0)
			print("[Pig] 撞飞了物品: ", collider.name)

func trigger_oink() -> void:
	oink_cooldown = 0.5
	oink_triggered.emit(global_position)
	print("[Pig] 哼哧！(Oink!) 发出反叛的猪叫！")
	
	# 视觉微放大
	if visual_mesh:
		var tween = create_tween()
		tween.tween_property(visual_mesh, "scale", Vector3(1.25, 0.85, 1.25), 0.08)
		tween.tween_property(visual_mesh, "scale", Vector3.ONE, 0.12)

func trigger_interact() -> void:
	if interact_raycast and interact_raycast.is_colliding():
		var target = interact_raycast.get_collider()
		interacted_with.emit(target)
		print("[Pig] 拱了一下目标: ", target.name)

