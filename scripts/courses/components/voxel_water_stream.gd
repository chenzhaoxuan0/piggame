class_name VoxelWaterStream
extends Area3D

signal player_swept(stream: Node3D, shore_pos: Vector3)
signal bridge_completed(stream: Node3D, slot_idx: int)

@export var stream_size: Vector3 = Vector3(8.0, 1.0, 6.0)
@export var shore_point: Vector3 = Vector3(0, 0.5, 4.0)
@export var bridge_slots_count: int = 2
@export var slot_spacing: float = 2.4

const COLOR_WATER := Color("38BDF8AA")
const COLOR_DIRT := Color("5A3E28")

var slots_filled: Array[bool] = []
var bridge_colliders: Array[StaticBody3D] = []
var mesh_instance: MeshInstance3D

func _ready() -> void:
	collision_mask = 2 | 1 # Player and PushBlocks
	_setup_collision()
	_setup_visual()
	_setup_slots()
	body_entered.connect(_on_body_entered)

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "WaterCol"
	var box := BoxShape3D.new()
	box.size = stream_size
	col.shape = box
	col.position.y = -stream_size.y * 0.5
	add_child(col)

func _setup_visual() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "WaterMesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = stream_size
	mesh_instance.mesh = box_mesh
	mesh_instance.position.y = -stream_size.y * 0.5

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = COLOR_WATER
	mat.roughness = 0.1
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _setup_slots() -> void:
	slots_filled.clear()
	for i in range(bridge_slots_count):
		slots_filled.append(false)

func get_slot_position(idx: int) -> Vector3:
	var offset_x := (float(idx) - float(bridge_slots_count - 1) * 0.5) * slot_spacing
	return global_position + Vector3(offset_x, 0, 0)

func is_all_bridged() -> bool:
	for filled in slots_filled:
		if not filled:
			return false
	return true

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("push"):
		_handle_block_drop(body)
	elif body.is_in_group("player") or body.name.to_lower().contains("pig"):
		_handle_player_entered(body)

func _handle_block_drop(block: Node3D) -> void:
	if block.get("has_bridged") == true:
		return

	# Find closest empty slot
	var closest_idx := -1
	var min_dist := 999.0
	for i in range(bridge_slots_count):
		if not slots_filled[i]:
			var slot_pos := get_slot_position(i)
			var dist := block.global_position.distance_to(slot_pos)
			if dist < min_dist:
				min_dist = dist
				closest_idx = i

	if closest_idx != -1 and min_dist < 4.5:
		slots_filled[closest_idx] = true
		block.has_bridged = true
		block.can_be_pushed = false

		# Snap block into bridge slot flush with grass bank (Y = 0.0)
		var target_slot := get_slot_position(closest_idx)
		target_slot.y = 0.0
		var tween := block.create_tween()
		tween.tween_property(block, "global_position", target_slot, 0.25).set_trans(Tween.TRANS_BOUNCE)
		tween.tween_callback(func():
			# Turn into permanent bridge platform
			_create_bridge_platform(target_slot, block.block_size)
			bridge_completed.emit(self, closest_idx)
		)

func _create_bridge_platform(pos: Vector3, size: float) -> void:
	var bridge_body := StaticBody3D.new()
	bridge_body.name = "BridgePlatform"
	bridge_body.global_position = pos

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size * 1.3, 0.6, stream_size.z + 0.8)
	col.shape = box
	col.position.y = -0.3
	bridge_body.add_child(col)

	# Visible wooden bridge walkway spanning the creek
	var bridge_mesh := MeshInstance3D.new()
	bridge_mesh.name = "BridgeMesh"
	var mesh_box := BoxMesh.new()
	mesh_box.size = Vector3(size * 1.25, 0.35, stream_size.z + 0.6)
	bridge_mesh.mesh = mesh_box
	bridge_mesh.position.y = -0.175
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8D6E63") # Sturdy wooden plank
	mat.roughness = 0.85
	bridge_mesh.material_override = mat
	bridge_body.add_child(bridge_mesh)

	add_child(bridge_body)
	bridge_colliders.append(bridge_body)

func _handle_player_entered(player: Node3D) -> void:
	# 1. Stepping stones lane check: X around 3.6m
	if abs(player.global_position.x - 3.6) < 1.6:
		return

	# 2. If player is walking across on a valid bridged section, safe!
	for i in range(bridge_slots_count):
		if slots_filled[i]:
			var slot_pos := get_slot_position(i)
			if abs(player.global_position.x - slot_pos.x) < slot_spacing * 0.85:
				return # Safe on bridge

	# 3. Player fell into rushing water -> sweep back to shore!
	player_swept.emit(self, shore_point)
	if player.has_method("reset_at"):
		player.reset_at(shore_point)
	if player.has_method("apply_knockback"):
		var sweep_dir := (shore_point - player.global_position).normalized()
		player.apply_knockback(sweep_dir * 6.0 + Vector3(0, 2.0, 0))
	else:
		player.global_position = shore_point
