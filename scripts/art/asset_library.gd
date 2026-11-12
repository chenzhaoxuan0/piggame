class_name FarmAssets
extends RefCounted
## Runtime visuals only. Existing bodies own collision, interactions and state.
const DIRECTORY := "res://assets/models/aholo/"
static var _cache: Dictionary = {}
static var _catalog: Dictionary = {}
static var _materials: Dictionary = {}

static func make(asset_id: String) -> Node3D:
	if _catalog.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "runtime_catalog.json"))
		if data is Dictionary: _catalog = data.get("assets", {})
	var entry: Dictionary = _catalog.get(asset_id, {})
	if not entry.get("accepted", false): return null
	var path: String = entry.get("path", "")
	if not ResourceLoader.exists(path): return null
	if not _cache.has(asset_id): _cache[asset_id] = load(path)
	var scene := _cache[asset_id] as PackedScene
	if scene == null: return null
	var visual := scene.instantiate() as Node3D
	visual.name = asset_id
	visual.set_meta("asset_id", asset_id)
	visual.set_meta("source", "Aholo Lux3D")
	visual.rotation.y = deg_to_rad(float(entry.get("yaw_degrees", 0)))
	# Zone art styles (docs/ZONE_STYLE_ASSET_PLAN.md): flat = pastoral toon
	# (courses 1/2/3), pbr = keep the GLB's own PBR materials (course 0
	# realistic), neon = flat base plus glow extracted from the albedo texture
	# (course 4 neon arena).
	match String(entry.get("style", "flat")):
		"pbr":
			pass
		"neon":
			_neon_materials(visual)
		_:
			_flat_materials(visual)
	if asset_id.begins_with("CHAR_"):
		var animator := Node.new()
		animator.name = "ActorAnimation"
		animator.set_script(preload("res://scripts/art/actor_animation.gd"))
		visual.add_child(animator)
	return visual

static func attach_to_bone(visual: Node3D, bone_name: String, prop: Node3D, rest_position: Vector3, rest_rotation := Vector3.ZERO) -> bool:
	if visual == null or prop == null: return false
	for skeleton in visual.find_children("*", "Skeleton3D", true, false):
		var index: int = skeleton.find_bone(bone_name)
		if index < 0: continue
		var socket := BoneAttachment3D.new()
		socket.name = bone_name + "PropSocket"
		socket.bone_name = bone_name
		skeleton.add_child(socket)
		if prop.get_parent(): prop.get_parent().remove_child(prop)
		socket.add_child(prop)
		var rest := Transform3D(Basis.from_euler(rest_rotation), rest_position)
		var relative: Transform3D = visual.global_transform.affine_inverse() * skeleton.global_transform
		prop.transform = (relative * skeleton.get_bone_global_rest(index)).affine_inverse() * rest
		return true
	return false

## Neon arena look: same flat base as pastoral, plus EMISSION extracted from the
## bright parts of the albedo texture so neon strips glow under the zone's
## bloom-enabled environment.
static func _neon_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		for i in mesh.mesh.get_surface_count() if mesh.mesh else 0:
			var source := mesh.get_active_material(i) as StandardMaterial3D
			if source:
				var key := "neon_%d" % source.get_instance_id()
				if not _materials.has(key):
					var material := ShaderMaterial.new()
					material.shader = preload("res://scripts/art/pastoral_surface.gdshader")
					material.set_shader_parameter("vertex_palette", false)
					material.set_shader_parameter("pigment", source.albedo_color)
					if source.albedo_texture != null:
						material.set_shader_parameter("use_texture", true)
						material.set_shader_parameter("albedo_texture", source.albedo_texture)
					else:
						material.set_shader_parameter("use_texture", false)
					material.set_shader_parameter("emission_from_texture", true)
					material.set_shader_parameter("emission_boost", 1.6)
					_materials[key] = material
				mesh.set_surface_override_material(i, _materials[key])
	for child in node.get_children(): _neon_materials(child)

static func _flat_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		for i in mesh.mesh.get_surface_count() if mesh.mesh else 0:
			var source := mesh.get_active_material(i) as StandardMaterial3D
			if source:
				var key := source.get_instance_id()
				if not _materials.has(key):
					var material := ShaderMaterial.new()
					material.shader = preload("res://scripts/art/pastoral_surface.gdshader")
					material.set_shader_parameter("vertex_palette", false)
					material.set_shader_parameter("pigment", source.albedo_color)
					if source.albedo_texture != null:
						material.set_shader_parameter("use_texture", true)
						material.set_shader_parameter("albedo_texture", source.albedo_texture)
					else:
						material.set_shader_parameter("use_texture", false)
					_materials[key] = material
				mesh.set_surface_override_material(i, _materials[key])
	for child in node.get_children(): _flat_materials(child)

static func replace_visuals(parent: Node3D, asset_id: String, offset := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var visual := make(asset_id)
	if visual == null: return null
	hide_procedural_visuals(parent)
	parent.add_child(visual)
	visual.position = offset
	visual.rotation.y += yaw
	return visual

## Hide the procedural dressing under a body but keep colliders, labels and
## script-driven effect nodes alive (the replace_visuals contract).
static func hide_procedural_visuals(parent: Node3D) -> void:
	for child in parent.get_children():
		if child is Node3D and not child is CollisionObject3D and not child is CollisionShape3D and not child is Label3D:
			child.hide()

## Cover a slab's top with a grid of one ground asset (zone floors/meadows).
## The tile asset is Blender-normalized to `tile_size` (X,Y,Z metres); copies
## sink `sink` metres into the slab so seams never z-fight. Tiles stretch on
## X/Z by at most one grid step - keep `slab_size` a near multiple of the tile.
static func tile_slab_top(parent: Node3D, asset_id: String, slab_size: Vector3, tile_size: Vector3, top_y: float, sink := 0.02) -> int:
	var cols := maxi(1, int(round(slab_size.x / tile_size.x)))
	var rows := maxi(1, int(round(slab_size.z / tile_size.z)))
	var step_x := slab_size.x / float(cols)
	var step_z := slab_size.z / float(rows)
	var count := 0
	for cx in cols:
		for cz in rows:
			var tile := make(asset_id)
			if tile == null: return count
			parent.add_child(tile)
			tile.scale = Vector3(step_x / tile_size.x, 1.0, step_z / tile_size.z)
			tile.position = Vector3(
				-slab_size.x * 0.5 + step_x * (float(cx) + 0.5),
				top_y - tile_size.y + sink,
				-slab_size.z * 0.5 + step_z * (float(cz) + 0.5))
			count += 1
	return count

## Line a wall/rail run with copies of one segment asset. The segment is
## Blender-normalized to `seg_size` (its length along local X); the run axis
## (the larger of X/Z in `run_size`) is covered by ceil(len/seg_len) copies,
## each stretched on its local length axis to close the seams. `yaw_degrees`
## must align the segment's length with the run axis (0 for X runs, 90 for Z).
## `base_y` is the segment BASE height in parent-local space (pass the body
## origin's height above ground negated when the body origin sits mid-height).
static func tile_run(parent: Node3D, asset_id: String, run_size: Vector3, seg_size: Vector3, yaw_degrees := 0.0, base_y := 0.0) -> int:
	var along_x := run_size.x >= run_size.z
	var length: float = run_size.x if along_x else run_size.z
	var segs := maxi(1, int(ceil(length / seg_size.x)))
	var seg_span := length / float(segs)
	var count := 0
	for i in segs:
		var seg := make(asset_id)
		if seg == null: return count
		parent.add_child(seg)
		seg.rotation.y = deg_to_rad(yaw_degrees)
		var along := -length * 0.5 + seg_span * (float(i) + 0.5)
		seg.scale = Vector3(seg_span / seg_size.x, 1.0, 1.0)
		if along_x:
			seg.position = Vector3(along, base_y, 0)
		else:
			seg.position = Vector3(0, base_y, along)
		count += 1
	return count
