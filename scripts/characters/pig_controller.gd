extends CharacterBody3D
class_name PigController

signal moved_to_target(pos: Vector3)
signal reached_interactable(target: Node3D)
signal dash_state_changed(remaining: float, cooldown: float)
signal dodge_succeeded(dog: Node3D)
signal qte_tapped

@export var move_speed: float = 4.5
@export var acceleration: float = 20.0
@export var rotation_speed: float = 12.0
@export var stopping_distance: float = 0.25
@export var interact_distance: float = 2.1
@export var dash_multiplier: float = 1.65
@export var dash_duration: float = 2.0
@export var dash_cooldown: float = 5.0

# Horse sprint stamina system: hold Shift to sprint, drains stamina over time, recovers when released
@export var max_stamina: float = 3.0
@export var stamina_drain_rate: float = 1.0
@export var stamina_recovery_rate: float = 0.95
@export var stamina_recovery_delay: float = 0.25
var stamina: float = 3.0
var is_sprinting: bool = false
var _recovery_timer: float = 0.0

# Dodge / Sidestep maneuver: tap Shift to dodge dog pounce with i-frames
@export var dodge_duration: float = 0.38
@export var dodge_speed_multiplier: float = 1.85
@export var dodge_cooldown: float = 0.50
var dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_direction: Vector3 = Vector3.FORWARD
var _successful_dodges: int = 0

# Slapstick knockback: traps launch the pig, input is overridden until it expires
@export var knockback_friction: float = 5.0
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_timer: float = 0.0

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
var _idle_snuffle_time := 0.0
var jumps := 0
var voice: PigVoice = null
var _click_route: Array[Vector3] = []
const JUMP_SPEED := 5.8
const GRAVITY := 18.0

@onready var visual_mesh: Node3D = $VisualMesh

# Animation-first wiring: when the dressed CHAR_01 model carries a skeletal
# clip the script plays it and skips the procedural stand-in pose. The
# animator is resolved once and cached (the visual is dressed in _ready).
var _animator: Node = null
var _dodge_animated := false
var _hit_animated := false

func _resolve_animator() -> Node:
	if _animator == null and is_instance_valid(visual_mesh):
		var found := visual_mesh.find_children("ActorAnimation", "Node", true, false)
		_animator = found[0] if not found.is_empty() else null
	return _animator

func _play_action(clip: String, rate := 1.15) -> bool:
	var animator := _resolve_animator()
	if animator != null and animator.has_method("play_oneshot"):
		return animator.play_oneshot(clip, rate)
	return false

## True when the dressed model owns skeletal locomotion clips - its own
## legwork/bounce IS the walk, so the procedural bob stands down (fallback
## only for models without them).
func _has_skeletal_locomotion() -> bool:
	var animator := _resolve_animator()
	return animator != null and animator.has_method("has_clip") and animator.has_clip("walk")

func _ready() -> void:
	preload("res://scripts/art/asset_library.gd").replace_visuals(visual_mesh, "CHAR_01")
	var animator := _resolve_animator()
	# 骨夹轨道路径相对 AnimationPlayer 的 root（CHAR_01），不是 VisualMesh。
	var char_visual := visual_mesh.get_node_or_null("CHAR_01") as Node3D
	if animator != null and char_visual != null:
		var snuffle_clip: Animation = preload("res://scripts/art/npc_clips.gd").snuffle(char_visual)
		if snuffle_clip != null:
			animator.register_clip("snuffle", snuffle_clip, false)
	target_destination = global_position
	camera = get_viewport().get_camera_3d()
	floor_snap_length = 0.3
	voice = PigVoice.new()
	voice.name = "PigVoice"
	add_child(voice)

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
		is_sprinting = false
		dodge_timer = 0.0
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
	stamina = max_stamina
	is_sprinting = false
	dodge_timer = 0.0
	_dodge_cooldown_timer = 0.0
	knockback_timer = 0.0
	knockback_velocity = Vector3.ZERO
	dash_remaining = 0.0
	cooldown_remaining = 0.0
	_dodge_animated = false
	_hit_animated = false
	_kill_sleep_pose_tween()
	_sleep_pose_active = false
	show_zzz(false)
	if is_instance_valid(visual_mesh):
		visual_mesh.position.y = 0.0
		visual_mesh.rotation.z = 0.0
		visual_mesh.rotation.x = 0.0
	dash_state_changed.emit(stamina, cooldown_remaining)

func set_dash_enabled(enabled: bool) -> void:
	dash_enabled = enabled
	if not enabled:
		is_sprinting = false
		dash_remaining = 0.0
		cooldown_remaining = 0.0
	else:
		stamina = max_stamina
	dash_state_changed.emit(stamina, cooldown_remaining)

func is_dodging() -> bool:
	return dodge_timer > 0.0

func is_knocked_back() -> bool:
	return knockback_timer > 0.0

func apply_knockback(impulse: Vector3, duration: float = 0.65) -> void:
	if not _can_move():
		return
	knockback_velocity = impulse
	knockback_timer = duration
	_hit_animated = _play_action("hit", 1.1)
	velocity = impulse
	_cancel_destination()
	is_sprinting = false
	dodge_timer = 0.0

func is_under_dog_threat() -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group("chase_dogs"):
		var dog := node as ChaseDog
		if is_instance_valid(dog) and dog.is_threatening_player():
			return true
	return false

func can_dodge() -> bool:
	# 2026-11-17 实机反馈：翻滚是猪的常驻机动——探索赶路、竞速提速都要它。
	# 旧门槛「只在犬威胁下开放」，而 reset_at（坠落重生/开竞速都走它）会清
	# 掉教学期的豁免标记，之后 Shift 翻滚彻底失灵。现在只剩冷却限制。
	if not _can_move():
		return false
	return _dodge_cooldown_timer <= 0.0

func notify_dodge_success(dog: Node3D = null) -> void:
	_successful_dodges += 1
	dodge_succeeded.emit(dog)

## Victory flourish for endings/settlement beats: plays the skeletal
## celebrate clip when the dressed model has one.
func play_victory_animation() -> void:
	_play_action("celebrate", 1.0)

# ------------------------------------------------------------- sleep pose
# 开场入梦/梦醒的可见姿态：趴下（侧倾+下沉）与起身（反向弹回）。tween 写的是
# VisualMesh 的变换（与被击飞时的 rotation.x 同一层），期间程序化姿态
# _update_pose 让位，两套系统不抢同一组属性；reset_at 会撤掉姿态并清标记，
# 所以赛道 setup 的 reset_at 之后猪一定是站着的。
const SLEEP_TILT_Z := 1.25
const SLEEP_SINK_Y := -0.10

var _sleep_pose_active := false
var _sleep_pose_tween: Tween = null
var _zzz_label: Label3D = null

func play_sleep_pose(duration := 0.85) -> Tween:
	# 趴下：就地侧倾下沉。返回 tween 供关卡 await / 快进。
	if not is_instance_valid(visual_mesh):
		return null
	_kill_sleep_pose_tween()
	_sleep_pose_active = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual_mesh, "rotation:z", SLEEP_TILT_Z, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(visual_mesh, "position:y", SLEEP_SINK_Y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_sleep_pose_tween = tween
	return tween

func play_wake_pose(duration := 0.55) -> Tween:
	# 起身（梦醒弹起）：趴姿反向弹回站姿，BACK 缓动给出「弹」的感觉。
	if not is_instance_valid(visual_mesh):
		return null
	_kill_sleep_pose_tween()
	_sleep_pose_active = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual_mesh, "rotation:z", 0.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_mesh, "position:y", 0.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sleep_pose_tween = tween
	return tween

func snap_sleep_pose() -> void:
	# 瞬间摆成趴姿（不做 tween）：梦醒「弹起身」的起始帧用它落位。
	_kill_sleep_pose_tween()
	_sleep_pose_active = false
	if is_instance_valid(visual_mesh):
		visual_mesh.rotation.z = SLEEP_TILT_Z
		visual_mesh.position.y = SLEEP_SINK_Y

func show_zzz(on: bool) -> void:
	# 「Z z z」悬浮字：趴下打呼期间挂在猪身上（BILLBOARD 保证面向镜头）。
	if on and is_instance_valid(visual_mesh) and not is_instance_valid(_zzz_label):
		_zzz_label = Label3D.new()
		_zzz_label.name = "SleepZzz"
		_zzz_label.text = "Z z z"
		_zzz_label.font_size = 44
		_zzz_label.outline_size = 10
		_zzz_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_zzz_label.no_depth_test = true
		_zzz_label.modulate = Color(1.0, 0.98, 0.85, 0.95)
		_zzz_label.position = Vector3(0.3, 1.05, 0)
		visual_mesh.add_child(_zzz_label)
	if is_instance_valid(_zzz_label):
		_zzz_label.visible = on

func _kill_sleep_pose_tween() -> void:
	if _sleep_pose_tween != null and _sleep_pose_tween.is_valid():
		_sleep_pose_tween.kill()
	_sleep_pose_tween = null

func _perform_dodge() -> void:
	dodge_timer = dodge_duration
	_dodge_cooldown_timer = dodge_cooldown
	dash_remaining = dodge_duration
	_dodge_animated = _play_action("dodge", 1.3)
	
	var dir := _keyboard_direction()
	if dir.length_squared() > 0.01:
		_dodge_direction = dir.normalized()
	elif is_moving:
		var off := target_destination - global_position
		off.y = 0.0
		if off.length_squared() > 0.01:
			_dodge_direction = off.normalized()
		else:
			_dodge_direction = -global_transform.basis.z.normalized()
	else:
		_dodge_direction = -global_transform.basis.z.normalized()
	
	_dodge_direction.y = 0.0
	if _dodge_direction.length_squared() < 0.001:
		_dodge_direction = Vector3.FORWARD
	else:
		_dodge_direction = _dodge_direction.normalized()

	if dash_enabled:
		stamina = maxf(0.0, stamina - 0.30)
		_recovery_timer = stamina_recovery_delay

func _can_move() -> bool:
	return control_mode == "explore" or control_mode == "chase"

func _unhandled_input(event: InputEvent) -> void:
	if control_mode == "qte":
		var is_tap: bool = (event.is_action_pressed("action_jump") or event.is_action_pressed("action_interact") or event.is_action_pressed("ui_accept")) and not event.is_echo()
		if not is_tap and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_tap = true
		if is_tap:
			if is_instance_valid(voice):
				voice.struggle_grunt()
			qte_tapped.emit()
			get_viewport().set_input_as_handled()
		return
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
	# 2026-11-17 实机反馈第三轮：这里也曾 explore-only——追逐中 F 键找不
	# 到任何可交互对象（连 null 都传不出去）。与 _try_interact 同步放行
	# chase 模式，墙缺口路径的牛对话才真正通了。
	if (control_mode != "explore" and control_mode != "chase") or not is_inside_tree():
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
	# 2026-11-17 实机反馈：追逐中也允许 F 交互——从墙缺口进牛耕地的人绕过
	# 了门口安全区，追逐不结束就永远说不上话；office 侧的 open_dialogue
	# 会在对话打开时停狗脱险。对话/暂停/演出态依旧不可交互。
	if not is_instance_valid(target) or (control_mode != "explore" and control_mode != "chase"):
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
	# Snuffling at the trough deserves the snort (the interaction_id survives
	# across the opening pen and the farm pigpen tutorial).
	if is_instance_valid(voice) and str(target.get_meta("interaction_id", "")).find("trough") >= 0:
		voice.oink()
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
	var mcm: Node = get_node_or_null("/root/MobileControlManager")
	if mcm != null and mcm.joystick_vector.length_squared() > 0.001:
		axis = mcm.joystick_vector.limit_length(1.0)
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

## 站太久自己拱地嗅嗅：玩家放下键盘时猪也不该变成雕像。
func _process(delta: float) -> void:
	if control_mode != "explore":
		_idle_snuffle_time = 0.0
		return
	if velocity.length() < 0.3 and is_on_floor():
		_idle_snuffle_time += delta
		if _idle_snuffle_time > 7.0:
			_play_action("snuffle", 1.0)
			_idle_snuffle_time = -randf_range(3.0, 6.0)
	else:
		_idle_snuffle_time = 0.0

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
		if can_dodge():
			_perform_dodge()

	if knockback_timer > 0.0:
		knockback_timer = maxf(0.0, knockback_timer - delta)
		knockback_velocity.x = move_toward(knockback_velocity.x, 0.0, knockback_friction * delta)
		knockback_velocity.z = move_toward(knockback_velocity.z, 0.0, knockback_friction * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		velocity.y = -0.2 if is_on_floor() and velocity.y <= 0.0 else velocity.y - GRAVITY * delta
		move_and_slide()
		if is_instance_valid(visual_mesh) and not _hit_animated:
			visual_mesh.rotation.x += delta * 10.0
		if knockback_timer <= 0.0:
			knockback_velocity = Vector3.ZERO
			if is_instance_valid(visual_mesh):
				visual_mesh.rotation.x = 0.0
		dash_state_changed.emit(stamina, cooldown_remaining)
		return

	# Sustained Sprint (Hold Shift with Horse Skill)
	var dash_held: bool = Input.is_action_pressed("action_dash")
	var move_direction: Vector3 = _keyboard_direction()
	var has_movement_input: bool = move_direction.length_squared() > 0.001 or is_moving

	if dash_enabled and dash_held and _can_move() and has_movement_input and stamina > 0.0:
		is_sprinting = true
		stamina = maxf(0.0, stamina - stamina_drain_rate * delta)
		_recovery_timer = stamina_recovery_delay
		dash_remaining = maxf(dodge_timer, stamina)
		if stamina <= 0.0:
			is_sprinting = false
	else:
		is_sprinting = false
		if _recovery_timer > 0.0:
			_recovery_timer = maxf(0.0, _recovery_timer - delta)
		else:
			stamina = minf(max_stamina, stamina + stamina_recovery_rate * delta)
		dash_remaining = dodge_timer

	dodge_timer = maxf(0.0, dodge_timer - delta)
	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	cooldown_remaining = maxf(0.0, (max_stamina - stamina) if stamina <= 0.0 else 0.0)

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

	var speed: float = move_speed
	var current_dir := move_direction

	if dodge_timer > 0.0:
		speed = move_speed * dodge_speed_multiplier
		current_dir = _dodge_direction
	elif is_sprinting and move_direction.length_squared() > 0.001:
		speed = move_speed * dash_multiplier

	var accel_factor: float = 1.8 if dodge_timer > 0.0 else 1.0
	velocity.x = move_toward(velocity.x, current_dir.x * speed, acceleration * delta * accel_factor)
	velocity.z = move_toward(velocity.z, current_dir.z * speed, acceleration * delta * accel_factor)
	_coyote_time = .1 if is_on_floor() else maxf(0.0, _coyote_time-delta)
	_jump_buffer = maxf(0.0, _jump_buffer-delta)
	if _jump_buffer>0 and _coyote_time>0:
		velocity.y=JUMP_SPEED
		_jump_buffer=0
		_coyote_time=0
		jumps+=1
		_play_action("jump", 1.2)
		# Voice: plain hop = oink, Shift-held hop = the dramatic scream jump.
		if is_instance_valid(voice):
			if Input.is_action_pressed("action_dash"):
				voice.squeal()
			else:
				voice.oink()
	else:
		# Mirror the knockback-branch guard: an upward impulse written by a trap
		# (slime block, launch ramp) on an on-floor frame must not be zeroed.
		velocity.y = -0.2 if is_on_floor() and velocity.y <= 0.0 else velocity.y - GRAVITY * delta
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
	dash_state_changed.emit(stamina, cooldown_remaining)

func _update_pose(direction: Vector3, delta: float) -> void:
	if _sleep_pose_active:
		return # 趴下中：姿态归入睡 tween，程序化 bob 让位
	var skeletal := _has_skeletal_locomotion()
	if direction.length_squared() > 0.001 or dodge_timer > 0.0:
		var dir := _dodge_direction if dodge_timer > 0.0 else direction
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, rotation_speed * delta * (1.6 if dodge_timer > 0.0 else 1.0)))
		# Skeletal locomotion/dodge clip owns the body motion; keep facing only.
		if skeletal or (_dodge_animated and dodge_timer > 0.0):
			return
		var is_dashing := is_sprinting or dodge_timer > 0.0
		var freq: float = 0.030 if dodge_timer > 0.0 else (0.024 if is_dashing else 0.014)
		var walk_step: float = sin(Time.get_ticks_msec() * freq)
		visual_mesh.position.y = absf(walk_step) * (0.08 if is_dashing else 0.045)
		visual_mesh.rotation.z = walk_step * (0.07 if is_dashing else 0.035)
		visual_mesh.rotation.x = -0.22 if dodge_timer > 0.0 else (-0.12 if is_dashing else 0.0)
	else:
		if skeletal: return
		visual_mesh.position.y = move_toward(visual_mesh.position.y, 0.0, delta * 0.8)
		visual_mesh.rotation.x = move_toward(visual_mesh.rotation.x, 0.0, delta * 0.8)
		visual_mesh.rotation.z = move_toward(visual_mesh.rotation.z, 0.0, delta * 0.8)
