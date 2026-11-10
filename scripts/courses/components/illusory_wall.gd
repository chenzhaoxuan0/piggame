class_name IllusoryWall
extends StaticBody3D

signal wall_shattered(wall: IllusoryWall)

@export var wall_width: float = 6.0
@export var wall_height: float = 4.2
@export var wall_depth: float = 1.0

const COLOR_SOLID := Color("475569") # Mossy slate
const COLOR_ILLUSORY := Color("A78BFA88") # Shimmering ghost purple-white

var is_shattered: bool = false
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var touch_area: Area3D
var hint_label: Label3D
var _resist_timer: Timer

func _ready() -> void:
	_setup_collision()
	_setup_visual()
	_setup_touch_area()

func _setup_collision() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "WallCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(wall_width, wall_height, wall_depth)
	collision_shape.shape = box
	collision_shape.position.y = wall_height * 0.5
	add_child(collision_shape)

func _setup_visual() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "WallMesh"
	var box := BoxMesh.new()
	box.size = Vector3(wall_width, wall_height, wall_depth)
	mesh_instance.mesh = box
	mesh_instance.position.y = wall_height * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_SOLID
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	hint_label = Label3D.new()
	hint_label.name = "IllusoryHint"
	hint_label.text = "【洞察之眸已看破假象】\n一撞即穿！"
	hint_label.font_size = 22
	hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint_label.modulate = Color("C4B5FD")
	hint_label.outline_modulate = Color("1E1B4B")
	hint_label.outline_size = 6
	hint_label.position = Vector3(0, wall_height + 0.8, 0)
	hint_label.visible = false
	add_child(hint_label)

func _setup_touch_area() -> void:
	touch_area = Area3D.new()
	touch_area.name = "TouchArea"
	touch_area.collision_layer = 0
	touch_area.collision_mask = 2 # Player

	var area_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(wall_width + 0.6, wall_height, wall_depth + 1.6)
	area_col.shape = box
	area_col.position.y = wall_height * 0.5
	touch_area.add_child(area_col)

	touch_area.body_entered.connect(_on_touch_entered)
	touch_area.body_exited.connect(_on_touch_exited)
	add_child(touch_area)

	# Without the sheep's insight the illusion resists briefly; lean on the wall
	# for this long and it gives way. With the skill it shatters on contact.
	_resist_timer = Timer.new()
	_resist_timer.name = "ResistTimer"
	_resist_timer.one_shot = true
	_resist_timer.wait_time = 1.2
	_resist_timer.timeout.connect(shatter)
	add_child(_resist_timer)

func _process(_delta: float) -> void:
	if is_shattered:
		return
	_set_illusory_state(_has_discern_skill())

func _has_discern_skill() -> bool:
	var game_manager := get_tree().root.get_node_or_null("GameManager")
	return game_manager != null and bool(game_manager.get("has_discern_skill"))

func _set_illusory_state(active: bool) -> void:
	if hint_label:
		hint_label.visible = active
	if mesh_instance and mesh_instance.material_override is StandardMaterial3D:
		var mat := mesh_instance.material_override as StandardMaterial3D
		if active:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = COLOR_ILLUSORY
			mat.emission_enabled = true
			mat.emission = Color("8B5CF6")
			mat.emission_energy_multiplier = 0.8
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = COLOR_SOLID
			mat.emission_enabled = false

func _on_touch_entered(body: Node3D) -> void:
	if is_shattered:
		return
	if not (body.is_in_group("player") or body.name.to_lower().contains("pig")):
		return
	if _has_discern_skill():
		shatter() # 【洞察之眸】看破假象：一撞即穿
		return
	# No insight yet: the illusion holds for a moment, then gives way. This keeps
	# the skill meaningful without soft-locking players who entered the pipe early.
	if hint_label:
		hint_label.text = "幻影在抵御小猪……\n顶着它坚持一下！"
		hint_label.visible = true
	if _resist_timer and _resist_timer.is_stopped():
		_resist_timer.start()

func _on_touch_exited(body: Node3D) -> void:
	if is_shattered or _resist_timer == null:
		return
	if body.is_in_group("player") or body.name.to_lower().contains("pig"):
		_resist_timer.stop()

func shatter() -> void:
	if is_shattered:
		return
	is_shattered = true

	if collision_shape:
		collision_shape.disabled = true

	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3(1.1, 0.05, 1.1), 0.25).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(hint_label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		wall_shattered.emit(self)
		queue_free()
	)
