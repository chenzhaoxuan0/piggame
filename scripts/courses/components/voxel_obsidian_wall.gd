class_name VoxelObsidianWall
extends StaticBody3D

signal wall_demolished(wall: VoxelObsidianWall)

const ASSETS = preload("res://scripts/art/asset_library.gd")

@export var wall_width: float = 6.0
@export var wall_height: float = 4.0
@export var wall_thickness: float = 1.0
# Optional zone dressing (creek voxel): the Lux3D obsidian wall replaces the
# cube grid; demolition flies the whole model off and spawns a voxel debris
# burst so the shatter keeps its Minecraft punch.
@export var lux_asset_id: String = ""

const COLOR_OBSIDIAN := Color("1E1B4B") # Deep purple-black
const COLOR_ACCENT := Color("4C1D95") # Obsidian purple highlight

var is_demolished: bool = false
var mesh_instances: Array[MeshInstance3D] = []
var _lux_visual: Node3D = null
var collision_shape: CollisionShape3D

func _ready() -> void:
	_setup_collision()
	_setup_visual()

func _setup_collision() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "WallCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(wall_width, wall_height, wall_thickness)
	collision_shape.shape = box
	collision_shape.position.y = wall_height * 0.5
	add_child(collision_shape)

func _setup_visual() -> void:
	# Zone dressing: the voxel obsidian wall model replaces the cube grid.
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			_lux_visual = lux
			add_child(lux)
			return
	var blocks_x := int(ceil(wall_width / 1.0))
	var blocks_y := int(ceil(wall_height / 1.0))

	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = COLOR_OBSIDIAN
	mat_a.roughness = 0.8

	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = COLOR_ACCENT
	mat_b.roughness = 0.7

	for x in range(blocks_x):
		for y in range(blocks_y):
			var cube := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.96, 0.96, wall_thickness * 0.96)
			cube.mesh = box
			var offset_x := (float(x) - float(blocks_x - 1) * 0.5) * 1.0
			var offset_y := float(y) * 1.0 + 0.5
			cube.position = Vector3(offset_x, offset_y, 0)
			cube.material_override = mat_a if (x + y) % 2 == 0 else mat_b
			add_child(cube)
			mesh_instances.append(cube)

func demolish() -> void:
	if is_demolished:
		return
	is_demolished = true

	if collision_shape != null:
		collision_shape.disabled = true

	if _lux_visual != null:
		_demolish_lux()
		return

	# Shatter explosion animation
	var tween := create_tween()
	for i in range(mesh_instances.size()):
		var cube := mesh_instances[i]
		var scatter_dir := Vector3(
			randf_range(-3.0, 3.0),
			randf_range(1.0, 4.0),
			randf_range(-3.0, 3.0)
		)
		tween.parallel().tween_property(cube, "global_position", cube.global_position + scatter_dir, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(cube, "scale", Vector3.ZERO, 0.4).set_delay(0.1)

	tween.tween_callback(func():
		wall_demolished.emit(self)
		queue_free()
	)

func _demolish_lux() -> void:
	# The dressed wall shatters as one chunk flying apart plus a burst of
	# voxel debris cubes, keeping the Minecraft demolition punch.
	_spawn_debris_burst()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_lux_visual, "position", _lux_visual.position + Vector3(randf_range(-2, 2), 3.0, randf_range(-2, 2)), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lux_visual, "rotation", Vector3(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2), randf_range(-1.2, 1.2)), 0.4)
	tween.tween_property(_lux_visual, "scale", Vector3.ZERO, 0.42).set_delay(0.08)
	tween.tween_callback(func():
		wall_demolished.emit(self)
		queue_free()
	)

func _spawn_debris_burst() -> void:
	# Voxel debris cubes scatter out of the blast (tween-driven so it plays
	# headless; same trick as the TNT explosion).
	var fx := Node3D.new()
	fx.name = "WallDebris"
	add_child(fx)
	for i in 12:
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := 0.3 + randf() * 0.3
		box.size = Vector3(s, s, s)
		cube.mesh = box
		cube.position = Vector3(randf_range(-wall_width * 0.4, wall_width * 0.4), randf_range(0.5, wall_height), 0)
		var cube_mat := StandardMaterial3D.new()
		cube_mat.albedo_color = COLOR_OBSIDIAN if i % 2 == 0 else COLOR_ACCENT
		cube.material_override = cube_mat
		fx.add_child(cube)
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.4), randf_range(-1.0, 1.0)).normalized()
		var tw := fx.create_tween()
		tw.set_parallel(true)
		tw.tween_property(cube, "position", cube.position + dir * (2.0 + randf() * 1.5), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cube, "scale", Vector3.ONE * 0.03, 0.5)
	var cleanup := fx.create_tween()
	cleanup.tween_interval(0.7)
	cleanup.tween_callback(fx.queue_free)
