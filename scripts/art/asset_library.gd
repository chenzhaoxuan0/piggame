class_name FarmAssets
extends RefCounted
## Runtime visuals only. Existing bodies own collision, interactions and state.
const DIRECTORY := "res://assets/models/aholo/"
static var _cache: Dictionary = {}
static var _catalog: Dictionary = {}

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
	return visual

static func _flat_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		for i in mesh.mesh.get_surface_count() if mesh.mesh else 0:
			var source := mesh.get_active_material(i) as StandardMaterial3D
			if source:
				var material := source.duplicate() as StandardMaterial3D
				material.roughness = 1.0
				material.metallic = 0.0
				material.metallic_specular = 0.0
				material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				mesh.set_surface_override_material(i, material)
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
