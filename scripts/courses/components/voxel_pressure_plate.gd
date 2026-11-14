class_name VoxelPressurePlate
extends Area3D

signal plate_pressed(plate: Node3D, trigger_body: Node3D)
signal plate_released(plate: Node3D)

@export var plate_size: Vector3 = Vector3(1.4, 0.12, 1.4)
@export var is_stone: bool = false
@export var target_wall: Node3D
# Redstone strip: how far the powered wire runs from the plate's front edge
# toward -Z (toward the wall it serves). Every TNT sitting anywhere ON the
# wire ignites when the plate is pressed - Minecraft semantics, not just the
# block under the pig's hooves.
@export var redstone_length := 6.0
# Limited blast range: only a TNT within this distance of the wall cracks it.
# The intended solve is to push the TNT down the wire to its far end - as
# close to the wall as the wire allows - and THEN press the plate.
@export var blast_range := 4.5
# False = a bare button: no wire visual, no redstone ignition (the creek's
# TNT reset plate reuses the press look without pretending to be a circuit).
@export var is_redstone_plate := true
# Optional zone dressing (creek voxel): the Lux3D pressure plate replaces the
# flat slab; the press/release tween keeps working on the plate node.
@export var lux_asset_id: String = ""

const ASSETS = preload("res://scripts/art/asset_library.gd")

const COLOR_WOOD := Color("A16207") # Oak wood plate
const COLOR_STONE := Color("64748B") # Stone plate
const COLOR_REDSTONE_DIM := Color("7F1D1D") # Unpowered redstone dust
const COLOR_REDSTONE_ACTIVE := Color("EF4444")

var is_pressed: bool = false
var plate_mesh: MeshInstance3D
var redstone_wire: Node3D
var redstone_tiles: Array[MeshInstance3D] = []
var initial_y: float = 0.0

func _ready() -> void:
	collision_mask = 1 | 2 # Player (layer 2) AND push blocks/TNT (layer 1): a mask of 2 made the "push TNT onto the plate" solution undetectable
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

	# Zone dressing: the voxel plate replaces the flat slab.
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			plate_mesh.mesh = null
			lux.position.y = -plate_size.y * 0.5
			plate_mesh.add_child(lux)

	# Redstone wire: metre tiles from the plate's front edge toward the wall -
	# the powered zone the ignition logic below actually checks, so the wire
	# you see is the wire that fires.
	if is_redstone_plate:
		redstone_wire = Node3D.new()
		redstone_wire.name = "RedstoneWire"
		add_child(redstone_wire)
		for i in int(ceil(redstone_length)):
			var tile := MeshInstance3D.new()
			tile.name = "RedstoneTile%d" % i
			var tile_mesh := BoxMesh.new()
			tile_mesh.size = Vector3(0.9, 0.04, 1.0)
			tile.mesh = tile_mesh
			tile.position = Vector3(0, 0.02, -1.0 - i - 0.5)
			var wire_mat := StandardMaterial3D.new()
			wire_mat.albedo_color = COLOR_REDSTONE_DIM # Dim red dust
			tile.material_override = wire_mat
			redstone_wire.add_child(tile)
			redstone_tiles.append(tile)

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
	for tile in redstone_tiles:
		tile.material_override = active_mat

	plate_pressed.emit(self, body)

	# Any press - pig hoof or a block shoved onto the plate - fires one pulse
	# down the whole wire (see _ignite_redstone). TNT merely crossing or
	# resting on the plate's own cell does NOT count as "on the wire".
	if is_redstone_plate:
		_ignite_redstone()

func _on_body_exited(_body: Node3D) -> void:
	# Only bodies the plate reacts to keep it pressed. The world floor sits
	# flush beneath the plate and reports as "overlapping" forever; counting it
	# pinned is_pressed after the first press and swallowed every later trigger
	# (pushing the TNT onto the plate stopped demolishing the wall).
	for overlapping in get_overlapping_bodies():
		if overlapping.has_method("push") or overlapping.is_in_group("player") \
			or overlapping.name.to_lower().contains("pig") or overlapping.name.to_lower().contains("tnt"):
			return
	is_pressed = false
	var tween := create_tween()
	tween.tween_property(plate_mesh, "position:y", initial_y, 0.1)

	var dim_mat := StandardMaterial3D.new()
	dim_mat.albedo_color = COLOR_REDSTONE_DIM
	for tile in redstone_tiles:
		tile.material_override = dim_mat
	plate_released.emit(self)

func _ignite_redstone() -> void:
	# Minecraft semantics with a blast-range twist: the pulse ignites every
	# TNT sitting anywhere ON the powered wire (not just at the plate), and
	# the wall only cracks when a blast actually reaches it - a TNT beyond
	# blast_range explodes harmlessly and the puzzle's reset plate respawns
	# it for another try. The solve: push the TNT to the wire's far end, as
	# close to the wall as the circuit allows, THEN press the plate.
	var host := get_parent()
	if host == null or not is_instance_valid(host):
		return
	var wall: Node3D = target_wall if target_wall != null and is_instance_valid(target_wall) else null
	var ignited := 0
	var cracked := false
	var last_blast_pos := global_position
	for child in host.find_children("*", "CharacterBody3D", true, false):
		if not child.has_method("ignite_and_explode"):
			continue
		if not _on_powered_wire(child.global_position):
			continue
		ignited += 1
		last_blast_pos = child.global_position
		if wall != null and wall.has_method("demolish") \
				and child.global_position.distance_to(wall.global_position) <= blast_range:
			wall.demolish()
			cracked = true
		child.ignite_and_explode()
	if ignited > 0 and not cracked and wall != null:
		_blast_miss_feedback(last_blast_pos)

func _on_powered_wire(world_pos: Vector3) -> bool:
	# The powered zone is the wire itself - one tile wide (|x| <= 0.9), from
	# just past the plate's own cell to the wire's far end. The plate cell is
	# deliberately excluded: the push path crosses it, and a TNT pausing there
	# between pushes must not self-detonate.
	var local := to_local(world_pos)
	return absf(local.x) <= 0.9 and local.z <= -1.2 and local.z >= -(redstone_length + 0.6)

func _blast_miss_feedback(blast_pos: Vector3) -> void:
	# Out-of-range blast: say so where it happened, then fade - the wall wants
	# the TNT pushed right up against the wire's far end.
	var lbl := Label3D.new()
	lbl.name = "BlastMissLabel"
	lbl.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	lbl.text = "距离太远，墙毫发无伤！把 TNT 推到红石线路尽头再引爆"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 26
	lbl.modulate = Color("FCA5A5")
	lbl.outline_modulate = Color("1E293B")
	lbl.outline_size = 6
	add_child(lbl)
	lbl.global_position = blast_pos + Vector3(0, 2.6, 0)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)
