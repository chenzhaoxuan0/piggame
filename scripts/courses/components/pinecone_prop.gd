class_name PineconeProp
extends Node3D

signal pinecone_thrown(landing_pos: Vector3)
signal dog_distracted(dog: Node3D, landing_pos: Vector3)

@export var throw_distance: float = 8.0
@export var prompt_text: String = "[F] 拾取/投掷金松果 (声东击西引开恶犬)"
# Optional zone dressing (woodland fairytale): the golden pinecone model
# replaces the amber cylinder; it travels with the mesh node when held/thrown.
@export var lux_asset_id: String = "PROP_C3_GOLDEN_PINECONE"

const ASSETS = preload("res://scripts/art/asset_library.gd")

const COLOR_CONE := Color("D97706") # Amber pinecone
const COLOR_GOLD := Color("FDE68A")

var is_held: bool = false
var is_spent: bool = false
var _player: Node3D = null
var _cone_mesh: MeshInstance3D
var _prompt_lbl: Label3D
var _pickup_area: Area3D

func _ready() -> void:
	_setup_visual()
	_setup_pickup_area()

func _setup_visual() -> void:
	_cone_mesh = MeshInstance3D.new()
	_cone_mesh.name = "PineconeMesh"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.35
	cone.height = 0.6
	_cone_mesh.mesh = cone
	_cone_mesh.position.y = 0.3

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CONE
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = COLOR_GOLD
	mat.emission_energy_multiplier = 0.5
	_cone_mesh.material_override = mat
	add_child(_cone_mesh)

	# Zone dressing: the golden pinecone replaces the amber cylinder.
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			_cone_mesh.mesh = null
			lux.position.y = -0.3
			_cone_mesh.add_child(lux)

	_prompt_lbl = Label3D.new()
	_prompt_lbl.name = "PromptLabel"
	_prompt_lbl.text = prompt_text
	_prompt_lbl.font_size = 20
	_prompt_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_lbl.modulate = Color("FEF08A")
	_prompt_lbl.outline_modulate = Color("451A03")
	_prompt_lbl.outline_size = 4
	_prompt_lbl.position = Vector3(0, 1.2, 0)
	add_child(_prompt_lbl)

func _setup_pickup_area() -> void:
	_pickup_area = Area3D.new()
	_pickup_area.name = "PickupArea"
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask = 2 # Player

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	shape.shape = sphere
	shape.position.y = 0.5
	_pickup_area.add_child(shape)

	_pickup_area.body_entered.connect(_on_player_entered)
	_pickup_area.body_exited.connect(_on_player_exited)
	add_child(_pickup_area)

func _on_player_entered(body: Node3D) -> void:
	if is_spent or is_held:
		return
	if body.is_in_group("player") or body.name.to_lower().contains("pig"):
		_player = body
		_prompt_lbl.text = "[F] / [E] 拾取金松果投掷！"
		_prompt_lbl.modulate = Color("FDE047")

func _on_player_exited(body: Node3D) -> void:
	if body == _player and not is_held:
		_player = null
		_prompt_lbl.text = prompt_text
		_prompt_lbl.modulate = Color("FEF08A")

func _unhandled_input(event: InputEvent) -> void:
	if is_spent:
		return

	if not is_held and _player != null:
		if event.is_action_pressed("action_interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F or event.keycode == KEY_E)):
			pickup(_player)
			get_viewport().set_input_as_handled()
	elif is_held:
		if (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F or event.keycode == KEY_E or event.keycode == KEY_SPACE)) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			throw_cone()
			get_viewport().set_input_as_handled()

func pickup(player: Node3D) -> void:
	if is_spent or is_held:
		return
	is_held = true
	_player = player
	_prompt_lbl.text = "【已持金松果】按 [F] / [鼠标左键] 朝前方掷出！"
	_prompt_lbl.modulate = Color("86EFAC")

	# Reparent cone mesh visually above player head
	if is_instance_valid(_cone_mesh):
		var prev_global := _cone_mesh.global_position
		_cone_mesh.get_parent().remove_child(_cone_mesh)
		player.add_child(_cone_mesh)
		_cone_mesh.position = Vector3(0, 1.4, 0)
		_cone_mesh.scale = Vector3(0.8, 0.8, 0.8)

func throw_cone() -> void:
	if not is_held or is_spent:
		return
	is_held = false
	is_spent = true
	_prompt_lbl.visible = false

	var throw_origin := _player.global_position + Vector3(0, 1.2, 0)
	var throw_dir := -_player.global_transform.basis.z.normalized()
	if throw_dir.length_squared() < 0.001:
		throw_dir = Vector3(0, 0, -1)

	var landing_target := throw_origin + throw_dir * throw_distance
	landing_target.y = 0.2

	# Move cone to world root for arc tween
	_cone_mesh.get_parent().remove_child(_cone_mesh)
	get_tree().root.add_child(_cone_mesh)
	_cone_mesh.global_position = throw_origin

	# The tween is bound to this prop, not to the cone mesh: the mesh now lives on
	# the scene root and would outlive us, and its landing callback captures self.
	# Freeing the prop mid-flight (course exit) used to fire that callback on a
	# freed object whose memory had already been reused by another node.
	var tween := create_tween()
	var mid_point := (throw_origin + landing_target) * 0.5 + Vector3(0, 3.2, 0)
	tween.tween_property(_cone_mesh, "global_position", mid_point, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_cone_mesh, "global_position", landing_target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_on_cone_landed(landing_target)
	)

func _exit_tree() -> void:
	# A held cone hangs off the pig and a thrown one off the scene root; neither
	# is our descendant, so take it with us instead of leaving it in the world.
	if is_instance_valid(_cone_mesh) and not is_ancestor_of(_cone_mesh):
		_cone_mesh.queue_free()

func _on_cone_landed(pos: Vector3) -> void:
	pinecone_thrown.emit(pos)

	# Clatter impact label
	var impact_lbl := Label3D.new()
	impact_lbl.text = "💥 啪嗒！\n【恶犬被声音引开了！】"
	impact_lbl.font_size = 24
	impact_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact_lbl.modulate = Color("FACC15")
	impact_lbl.outline_modulate = Color("78350F")
	impact_lbl.outline_size = 6
	impact_lbl.global_position = pos + Vector3(0, 1.5, 0)
	get_tree().root.add_child(impact_lbl)

	var lbl_tween := impact_lbl.create_tween()
	lbl_tween.tween_property(impact_lbl, "position:y", impact_lbl.position.y + 1.0, 1.5)
	lbl_tween.tween_callback(impact_lbl.queue_free)

	# Distract nearby patrol dogs / vision cones
	var cones := get_tree().get_nodes_in_group("patrol_vision_cones")
	for cone in cones:
		if cone.has_method("distract_towards"):
			cone.distract_towards(pos)

	# Also search PatrolDogGuard
	var dogs := get_tree().get_nodes_in_group("chase_dogs")
	for d in dogs:
		if d.global_position.distance_to(pos) < 16.0:
			dog_distracted.emit(d, pos)

	if is_instance_valid(_cone_mesh):
		_cone_mesh.queue_free()
