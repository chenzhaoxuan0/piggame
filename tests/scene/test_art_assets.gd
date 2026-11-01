extends SceneTree
const ASSETS = preload("res://scripts/art/asset_library.gd")
const ART_2D = preload("res://scripts/art/art_2d.gd")
var failures := 0
var assertions := 0
var triangles := 0
var meshes := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(text)

func _scan(node: Node) -> void:
	_check(not node is CollisionObject3D and not node is CollisionShape3D, "import must not replace gameplay collision")
	_check(not node is Camera3D and not node is Light3D, "import must not change level lighting or camera")
	if node is MeshInstance3D:
		meshes += 1
		var mesh: Mesh = node.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size() / 3
			var material: StandardMaterial3D = node.get_active_material(surface)
			_check(material != null, "surface has authored material")
			_check(material.albedo_texture == null, "runtime palette has no baked texture noise")
			_check(material.metallic == 0 and material.roughness == 1, "matte material")
			_check(material.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "Toon diffuse")
	for child in node.get_children(): _scan(child)

func _run() -> void:
	var visual := ASSETS.make("PROP_01")
	_check(visual != null, "accepted cabin loads")
	if visual:
		_scan(visual)
		_check(meshes > 0 and triangles <= 4500, "cabin fits triangle budget")
		visual.free()
	_check(ASSETS.make("UNREVIEWED_ASSET") == null, "unreviewed asset cannot enter runtime")
	for texture in ART_2D.PORTRAITS.values():
		_check(texture != null and texture.get_width() > 0, "portrait loads")
	for texture in ART_2D.ENDINGS.values():
		_check(texture != null and texture.get_width() > 0, "ending illustration loads")
	var farm := load("res://scenes/levels/farm/farm_grounds.tscn").instantiate() as Node3D
	root.add_child(farm)
	await process_frame
	_check(farm.get_node("CableCarCabin").get_child_count() > 0, "cabin remains on moving root")
	_check(farm.get_node("CableCarCabin/PROP_01").visible, "accepted cabin visible")
	_check(not farm.get_node("CableCarCabin/Deck").visible, "duplicate placeholder cabin hidden")
	var ox_art := farm.get_node_or_null("NPC_ox/CHAR_03")
	_check(farm.get_node("NPC_ox/Body").visible == (ox_art == null), "ox fallback follows accepted model availability")
	_check(get_nodes_in_group("interactable").size() == 7, "art keeps interaction roots")
	farm.queue_free()
	await process_frame
	print("ART_ASSETS_TEST assertions=%d failures=%d triangles=%d" % [assertions, failures, triangles])
	quit(0 if failures == 0 else 1)
