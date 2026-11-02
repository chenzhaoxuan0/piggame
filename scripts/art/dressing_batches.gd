extends RefCounted
## Consolidate each accepted Lux3D asset to one vertex-color surface, then instance
## it in 24 m cells. Nearby copies share meshes, materials and a draw call.
const A = preload("res://scripts/art/asset_library.gd")
var _meshes: Dictionary = {}
var _instances: Dictionary = {}
var counts: Dictionary = {}

func place(id: String, p: Vector3, scale_value: Vector3 = Vector3.ONE, yaw: float = 0) -> void:
	var key := "%s_%d_%d" % [id,floori(p.x/24),floori(p.z/24)]
	if not _instances.has(key): _instances[key]={"id":id,"transforms":[]}
	_instances[key].transforms.append(Transform3D(Basis(Vector3.UP,yaw).scaled(scale_value),p))
	counts[id]=int(counts.get(id,0))+1

func _append(node: Node, parent_transform: Transform3D, surface: SurfaceTool) -> void:
	var transform := parent_transform
	if node is Node3D: transform=parent_transform*node.transform
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(i)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var mat:=node.get_active_material(i) as ShaderMaterial
			var color: Color=mat.get_shader_parameter("pigment") if mat else Color.WHITE
			for j in indices.size() if indices.size() else vertices.size():
				var index: int=indices[j] if indices.size() else j
				surface.set_normal((transform.basis*normals[index]).normalized())
				surface.set_color(color)
				surface.add_vertex(transform*vertices[index])
	for child in node.get_children(): _append(child,transform,surface)

func flush(parent: Node3D) -> void:
	var material:=ShaderMaterial.new()
	material.shader=preload("res://scripts/art/pastoral_surface.gdshader")
	var canopy:=material.duplicate() as ShaderMaterial
	canopy.set_shader_parameter("canopy_cutout",true)
	for key in _instances:
		var data: Dictionary=_instances[key]
		var id: String=data.id
		if not _meshes.has(id):
			var source:=A.make(id)
			if source==null:
				push_error("Dressing asset not accepted: "+id)
				continue
			var surface:=SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			_append(source,Transform3D.IDENTITY,surface)
			surface.index()
			_meshes[id]=surface.commit()
			source.free()
		var batch:=MultiMeshInstance3D.new()
		batch.name="Dressing_"+key
		batch.multimesh=MultiMesh.new()
		batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=_meshes[id]
		batch.multimesh.instance_count=data.transforms.size()
		for i in data.transforms.size(): batch.multimesh.set_instance_transform(i,data.transforms[i])
		batch.material_override=canopy if id in ["ENV_09_OAK","ENV_09_BIRCH","ENV_09_PINE","ENV_09_APPLE","ENV_09_HAWTHORN"] else material
		batch.set_meta("asset_id",id)
		batch.set_meta("source","Aholo Lux3D")
		# The dummy renderer used by headless baking cannot round-trip GPU buffers.
		# Persist CPU transforms as Variant data and restore once when loading.
		batch.set_meta("placements",data.transforms)
		parent.add_child(batch)
	parent.set_meta("dressing_counts",counts)

static func restore(parent: Node) -> void:
	for batch in parent.find_children("Dressing_*","MultiMeshInstance3D",true,false):
		var placements: Array=batch.get_meta("placements",[])
		for i in placements.size(): batch.multimesh.set_instance_transform(i,placements[i])
