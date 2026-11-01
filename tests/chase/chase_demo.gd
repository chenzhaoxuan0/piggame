extends Node3D

var _pig: PigController
var _chase: SimpleChase
var _status: Label

func _ready() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	add_child(floor_body)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(20, 0.4, 36)
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(0, -0.2, -12)
	floor_body.add_child(floor_mesh)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box.size
	collider.shape = shape
	collider.position = floor_mesh.position
	floor_body.add_child(collider)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(13, 22, 9)
	add_child(camera)
	camera.look_at(Vector3(0, 0, -12))
	camera.current = true
	var packed: PackedScene = load("res://scenes/characters/pig.tscn")
	_pig = packed.instantiate() as PigController
	add_child(_pig)
	_chase = SimpleChase.new()
	add_child(_chase)
	_chase.finished.connect(_on_finished)
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	_status = Label.new()
	_status.position = Vector2(25, 25)
	_status.add_theme_font_size_override("font_size", 22)
	canvas.add_child(_status)
	_restart()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart()
		elif event.keycode == KEY_H:
			_pig.set_dash_enabled(not _pig.dash_enabled)

func _restart() -> void:
	_pig.reset_at(Vector3(0, 0.1, -5))
	_pig.set_control_mode("chase")
	var spawns: Array[Vector3] = [Vector3(-3, 0.1, 0), Vector3(3, 0.1, 1)]
	_chase.start_chase(_pig, spawns, -23.0)
	_status.text = "WASD / click: move toward far end. R: retry. H: toggle horse skill. Shift: dash if unlocked."

func _on_finished(success: bool) -> void:
	_pig.set_control_mode("ending")
	_status.text = "Escaped! Press R to retry." if success else "Caught! Press R to retry."
