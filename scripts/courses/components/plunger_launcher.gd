class_name PlungerLauncher
extends Node3D

# The woodland plunger armory: keeps the pig's plunger ammo, fires on
# action_shoot (Q) with soft aim-assist, and knocks dogs down through the
# same stun contract the cardboard box dive uses (group "chase_dogs" +
# has_method("stun")). Patrol guard dogs take the full knockdown; rubber-band
# chasers just get a shorter stun so a hit buys an escape window.

signal ammo_changed(count: int)
signal dog_knocked_down(dog: Node3D)

const UI = preload("res://scripts/ui/ui_kit.gd")
const ASSETS = preload("res://scripts/art/asset_library.gd")
const PLUNGER_PROP_SCRIPT = preload("res://scripts/courses/components/plunger_prop.gd")

const RANGE := 11.0
const AIM_CONE_DEG := 40.0
const FLIGHT_TIME := 0.38
const PLUNGER_SPEED := 24.0
const ARC_HEIGHT := 0.9
const HIT_RADIUS := 1.6
const PATROL_STUN := 4.5
const CHASER_STUN := 2.2
const ACHIEVEMENT_GOAL := 3

const CUP_RED := Color("C0392B")
const HANDLE_WOOD := Color("8B5A2B")

var ammo: int = 0
var player: Node3D
var _knockdowns: int = 0
var _counter: Label
var _flights: Array[Dictionary] = []

func setup(p: Node3D, start_ammo: int) -> void:
	player = p
	ammo = start_ammo
	_build_counter()
	_refresh()

func _exit_tree() -> void:
	# The counter lives on a CanvasLayer child; it dies with us.
	if is_instance_valid(_counter) and is_instance_valid(_counter.get_parent()):
		_counter.get_parent().queue_free()

func _build_counter() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PlungerCounterLayer"
	add_child(layer)
	var panel := UI.patch_panel(14, Color("FFFBEB"), Color("86A873"), Vector2(14, 8))
	panel.name = "PlungerCounter"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 24
	panel.offset_top = 18
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	_counter = UI.label("🪠 × %d" % ammo, 22, Color("292524"), true)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_counter)
	# 2026-11-15 实机反馈 #3：玩家捡了搋子却不知道怎么用——按键提示原本
	# 只有军械库位置一条世界标签。计数面板常驻副标题，把「按 Q 发射」
	# 这堂课跟着弹药走。
	var hint := UI.label("按 Q 发射", 13, Color("57534E"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hint)

func _refresh() -> void:
	if is_instance_valid(_counter):
		_counter.text = "🪠 × %d" % ammo
	ammo_changed.emit(ammo)

func add_ammo(n: int) -> void:
	ammo += n
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action_shoot") and not event.is_echo():
		fire()
		get_viewport().set_input_as_handled()
		return
	# 2026-11-15 实机反馈：搋子也吃鼠标——左键发射，弹道跟着鼠标指向；
	# 键盘 Q 仍按猪头朝向做辅助瞄准。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and not event.is_echo():
		fire(true)
		get_viewport().set_input_as_handled()

func fire(from_mouse: bool = false) -> bool:
	if ammo <= 0:
		if is_instance_valid(player):
			_world_gag(player.global_position + Vector3(0, 1.6, 0), "搋子用完了！找地上的补给！")
		return false
	if not is_instance_valid(player):
		return false
	if player.control_mode not in ["explore", "chase"]:
		return false
	ammo -= 1
	_refresh()

	var aim := _aim_target(_mouse_aim() if from_mouse else _facing())
	var origin: Vector3 = player.global_position + Vector3(0, 1.1, 0)
	var target: Vector3 = aim.get("point", origin + _facing() * RANGE)
	target.y = maxf(target.y, 0.3)

	var visual := _build_plunger_visual()
	get_tree().root.add_child(visual)
	visual.global_position = origin
	# Homing flight: chasers close ~2 m during the flight, so a tween to the
	# captured point would land behind a moving dog. The plunger tracks its
	# victim every frame (comic accuracy), or flies to the captured point
	# when fired into the void.
	_flights.append({
		"visual": visual,
		"dog": aim.get("dog"),
		"point": target,
		"elapsed": 0.0,
	})
	return true

func _physics_process(delta: float) -> void:
	for flight in _flights.duplicate():
		var visual: Node3D = flight["visual"]
		if not is_instance_valid(visual) or not visual.is_inside_tree():
			_flights.erase(flight)
			continue
		flight["elapsed"] = float(flight["elapsed"]) + delta
		var target: Vector3 = flight["point"]
		if is_instance_valid(flight["dog"]):
			target = flight["dog"].global_position + Vector3(0, 0.8, 0)
			flight["point"] = target
		var pos: Vector3 = visual.global_position
		var to := target - pos
		var step: float = PLUNGER_SPEED * delta
		# Comedic arc: a sine lift that peaks mid-flight, on top of the steer.
		var progress: float = clampf(float(flight["elapsed"]) / FLIGHT_TIME, 0.0, 1.0)
		var lift: float = ARC_HEIGHT * (1.0 - absf(progress * 2.0 - 1.0))
		if to.length() <= step + 0.35 or float(flight["elapsed"]) > 1.2:
			_on_plunger_arrived(flight["dog"], target, visual)
			_flights.erase(flight)
		else:
			visual.global_position += to.normalized() * step + Vector3.UP * lift * 6.0 * delta
			visual.rotation.x -= 9.0 * delta # tumbling suction-first flight

func _facing() -> Vector3:
	var dir := -player.global_transform.basis.z.normalized()
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD

## 鼠标指向的瞄准方向：相机射线与发射口等高平面的交点折成水平向量。
## 射线近乎平行或指向身后时退回猪头朝向（永远给一个合理弹道）。
func _mouse_aim() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(player):
		return _facing()
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse)
	var plane_y: float = player.global_position.y + 1.1
	if absf(ray_dir.y) < 0.001:
		return _facing()
	var t: float = (plane_y - ray_origin.y) / ray_dir.y
	if t <= 0.0:
		return _facing()
	var point: Vector3 = ray_origin + ray_dir * t
	var flat: Vector3 = point - (player.global_position + Vector3(0, 1.1, 0))
	flat.y = 0.0
	return flat.normalized() if flat.length_squared() > 0.001 else _facing()

## Soft aim-assist: nearest non-stunned dog inside the facing cone.
func _aim_target(facing: Vector3) -> Dictionary:
	var origin: Vector3 = player.global_position + Vector3(0, 1.1, 0)
	var best: Node3D = null
	var best_dist: float = RANGE
	var cos_limit: float = cos(deg_to_rad(AIM_CONE_DEG))
	for dog in get_tree().get_nodes_in_group("chase_dogs"):
		if not is_instance_valid(dog) or _is_dog_stunned(dog):
			continue
		if "active" in dog and not dog.active:
			continue # rubber-band chasers sleep until the course start gate
		var to: Vector3 = dog.global_position + Vector3(0, 0.7, 0) - origin
		to.y = 0.0
		var dist: float = to.length()
		if dist > RANGE or dist < 0.3:
			continue
		if to.normalized().dot(facing) < cos_limit:
			continue
		if dist < best_dist:
			best = dog
			best_dist = dist
	if best != null:
		return {"dog": best, "point": best.global_position + Vector3(0, 0.8, 0)}
	return {}

func _is_dog_stunned(dog: Node3D) -> bool:
	if "is_stunned" in dog and dog.is_stunned:
		return true
	if "phase" in dog and str(dog.phase) == "stun":
		return true
	return false

func _on_plunger_arrived(target_dog: Node3D, landing: Vector3, visual: Node3D) -> void:
	# Whatever dog stands at the splash zone takes the hit - the aimed dog may
	# have wandered during the flight, a closer one may have walked in.
	var hit_dog: Node3D = null
	var best_dist: float = HIT_RADIUS
	for dog in get_tree().get_nodes_in_group("chase_dogs"):
		if not is_instance_valid(dog):
			continue
		var offset: Vector3 = dog.global_position - landing
		offset.y = 0.0
		if offset.length() < best_dist:
			hit_dog = dog
			best_dist = offset.length()
	if hit_dog != null:
		_apply_hit(hit_dog, visual)
	else:
		_drop_on_ground(visual, landing)

func _apply_hit(dog: Node3D, visual: Node3D) -> void:
	var is_patrol: bool = "is_stunned" in dog
	dog.stun(PATROL_STUN if is_patrol else CHASER_STUN)
	_knockdowns += 1
	if _knockdowns >= ACHIEVEMENT_GOAL:
		var am := get_tree().root.get_node_or_null("AchievementManager")
		if am != null:
			am.unlock("plunger_knight")
	_world_gag(dog.global_position + Vector3(0, 1.9, 0), "搋子正中面门！恶犬被吸住了！")
	if is_instance_valid(visual):
		# The plunger rides the dizzy spin with its victim, then pops off.
		dog.add_child(visual)
		visual.position = Vector3(0, 0.9, 0.4)
		var t := visual.create_tween()
		t.tween_interval(0.9)
		t.tween_property(visual, "position:y", 0.2, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_callback(visual.queue_free)
	dog_knocked_down.emit(dog)

func _drop_on_ground(visual: Node3D, landing: Vector3) -> void:
	_world_gag(landing + Vector3(0, 1.2, 0), "啪嗒——搋子落了地，还能捡回来。")
	# A fresh pickup grows where it landed (its _ready builds rig + prompt):
	# misses cost range, not the plunger forever.
	var pickup := PLUNGER_PROP_SCRIPT.new()
	pickup.lux_asset_id = "" # keep the dropped one procedural - the model stays with the armory
	get_tree().root.add_child(pickup)
	pickup.global_position = landing
	if is_instance_valid(visual):
		visual.queue_free()

func _build_plunger_visual() -> Node3D:
	var rig := Node3D.new()
	rig.name = "PlungerProjectile"
	var lux := ASSETS.make("PROP_C3_PLUNGER")
	if lux != null:
		rig.add_child(lux)
		return rig
	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.16
	cup_mesh.bottom_radius = 0.24
	cup_mesh.height = 0.22
	cup.mesh = cup_mesh
	var cup_mat := StandardMaterial3D.new()
	cup_mat.albedo_color = CUP_RED
	cup_mat.roughness = 0.55
	cup.material_override = cup_mat
	cup.position.y = -0.14
	rig.add_child(cup)
	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.035
	stick_mesh.bottom_radius = 0.035
	stick_mesh.height = 0.5
	stick.mesh = stick_mesh
	var stick_mat := StandardMaterial3D.new()
	stick_mat.albedo_color = HANDLE_WOOD
	stick_mat.roughness = 0.85
	stick.material_override = stick_mat
	stick.position.y = 0.14
	rig.add_child(stick)
	return rig

func _world_gag(world_pos: Vector3, text: String) -> void:
	if not is_inside_tree():
		return
	var label := UI.world_label(text, 22, Color("FFFDF6"), Color("2C6E7A"))
	label.position = world_pos
	get_tree().root.add_child(label)
	var t := label.create_tween()
	t.tween_property(label, "position:y", label.position.y + 0.8, 1.4)
	t.parallel().tween_property(label, "modulate:a", 0.0, 1.4)
	t.tween_callback(label.queue_free)
