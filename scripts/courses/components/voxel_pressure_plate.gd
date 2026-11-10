class_name VoxelPressurePlate
extends Area3D

signal plate_pressed(plate: Node3D, trigger_body: Node3D)
signal plate_released(plate: Node3D)

@export var plate_size: Vector3 = Vector3(1.4, 0.12, 1.4)
@export var is_stone: bool = false
@export var target_wall: Node3D

const COLOR_WOOD := Color("A16207") # Oak wood plate
const COLOR_STONE := Color("64748B") # Stone plate
const COLOR_REDSTONE_ACTIVE := Color("EF4444")

var is_pressed: bool = false
var plate_mesh: MeshInstance3D
var redstone_wire: MeshInstance3D
var initial_y: float = 0.0

func _ready() -> void:
	collision_mask = 2 # Player layer; push blocks will be checked by method
	_setup_collision()
	_setup_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "PlateCol"
	var box := BoxShape3D.new()
	box.size = Vector3(plate_size.x, 0.4, plate_size.z)
	col.shape = box
	col.position.y = 0.2
	add_child(col)

func _setup_visual() -> void:
	plate_mesh = MeshInstance3D.new()
	plate_mesh.name = "PlateMesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = plate_size
	plate_mesh.mesh = box_mesh
	plate_mesh.position.y = plate_size.y * 0.5
	initial_y = plate_mesh.position.y

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_STONE if is_stone else COLOR_WOOD
	plate_mesh.material_override = mat
	add_child(plate_mesh)

	# Redstone wire trail connecting to target
	redstone_wire = MeshInstance3D.new()
	redstone_wire.name = "RedstoneWire"
	var wire_mesh := BoxMesh.new()
	wire_mesh.size = Vector3(0.3, 0.04, 3.0)
	redstone_wire.mesh = wire_mesh
	redstone_wire.position = Vector3(0, 0.02, -1.8)

	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color("7F1D1D") # Dim red
	redstone_wire.material_override = wire_mat
	add_child(redstone_wire)

func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("push") and not body.is_in_group("player") and not body.name.to_lower().contains("pig") and not body.name.to_lower().contains("tnt"):
		return
	if is_pressed:
		return
	is_pressed = true

	# Click down
	var tween := create_tween()
	tween.tween_property(plate_mesh, "position:y", initial_y - 0.06, 0.08)

	# Light up redstone
	var active_mat := StandardMaterial3D.new()
	active_mat.albedo_color = COLOR_REDSTONE_ACTIVE
	active_mat.emission_enabled = true
	active_mat.emission = COLOR_REDSTONE_ACTIVE
	redstone_wire.material_override = active_mat

	plate_pressed.emit(self, body)

	# If triggering body is TNT, ignite TNT and blow up target wall
	if body.has_method("ignite_and_explode"):
		if target_wall != null and is_instance_valid(target_wall) and target_wall.has_method("demolish"):
			target_wall.demolish()
		body.ignite_and_explode()

func _on_body_exited(_body: Node3D) -> void:
	var overlapping := get_overlapping_bodies()
	if overlapping.is_empty():
		is_pressed = false
		var tween := create_tween()
		tween.tween_property(plate_mesh, "position:y", initial_y, 0.1)

		var dim_mat := StandardMaterial3D.new()
		dim_mat.albedo_color = Color("7F1D1D")
		redstone_wire.material_override = dim_mat
		plate_released.emit(self)
