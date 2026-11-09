extends CourseTrap
class_name FakeFloor

const ASSETS = preload("res://scripts/art/asset_library.gd")

@export var trigger_delay: float = 0.45
@export var reset_time: float = 3.0
@export var tile_size: Vector3 = Vector3(4.0, 0.3, 4.0)
@export var tile_color: Color = Color("8D7B68")

var _shape: CollisionShape3D
var _mesh: Node3D
var _state := "solid"
var _timer := 0.0

func _ready() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tile_size
	_shape.shape = box
	body.add_child(_shape)
	add_child(body)
	var lux_bridge := ASSETS.make("PROP_C1_FAKEBRIDGE")
	if lux_bridge:
		_mesh = lux_bridge
		_mesh.scale = Vector3(tile_size.x / 8.0, tile_size.y / 0.3, tile_size.z / 12.0)
	else:
		var mesh_instance := MeshInstance3D.new()
		var mesh_box := BoxMesh.new()
		mesh_box.size = tile_size
		mesh_instance.mesh = mesh_box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tile_color
		mat.roughness = 1.0
		mesh_instance.material_override = mat
		_mesh = mesh_instance
	add_child(_mesh)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = Vector3(tile_size.x, 0.6, tile_size.z)
	area_shape.shape = area_box
	area_shape.position.y = tile_size.y * 0.5 + 0.3
	area.add_child(area_shape)
	area.body_entered.connect(_on_step)
	add_child(area)

func _on_step(body: Node3D) -> void:
	if not _is_player(body) or _state != "solid":
		return
	_state = "wobbling"
	_timer = trigger_delay
	_meme(telegraph_meme_id, global_position)
	var tween := create_tween()
	tween.tween_property(_mesh, "rotation:z", 0.05, trigger_delay * 0.4)
	tween.tween_property(_mesh, "rotation:z", -0.05, trigger_delay * 0.4)

func _physics_process(delta: float) -> void:
	if _state == "solid":
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _state == "wobbling":
		_collapse()
	elif _state == "fallen":
		_restore()

func _collapse() -> void:
	_state = "fallen"
	_timer = reset_time
	_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_mesh, "position:y", -4.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _mesh.visible = false)
	_meme(meme_id, global_position)

func _restore() -> void:
	_state = "solid"
	_shape.set_deferred("disabled", false)
	_mesh.position.y = 0.0
	_mesh.rotation = Vector3.ZERO
	_mesh.visible = true