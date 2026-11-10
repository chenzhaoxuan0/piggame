class_name VoxelObsidianWall
extends StaticBody3D

signal wall_demolished(wall: VoxelObsidianWall)

@export var wall_width: float = 6.0
@export var wall_height: float = 4.0
@export var wall_thickness: float = 1.0

const COLOR_OBSIDIAN := Color("1E1B4B") # Deep purple-black
const COLOR_ACCENT := Color("4C1D95") # Obsidian purple highlight

var is_demolished: bool = false
var mesh_instances: Array[MeshInstance3D] = []
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
