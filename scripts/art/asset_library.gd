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
	for child in parent.get_children():
		if child is Node3D and not child is CollisionObject3D and not child is CollisionShape3D and not child is Label3D:
			child.hide()
	parent.add_child(visual)
	visual.position = offset
	visual.rotation.y += yaw
	return visual
