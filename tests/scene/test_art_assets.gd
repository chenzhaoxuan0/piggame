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
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/aholo/runtime_catalog.json"))
	_check(catalog.assets.size() == 18, "14 core assets and 4 environment modules delivered")
	for id in catalog.assets:
		var visual := ASSETS.make(id)
		_check(visual != null, "accepted model loads: " + id)
		if visual == null: continue
		var before := triangles
		_scan(visual)
		_check(triangles - before <= (8000 if id.begins_with("CHAR_") else 6000), "model fits triangle budget: " + id)
		if id.begins_with("CHAR_"):
			root.add_child(visual)
			await process_frame
			var players := visual.find_children("*", "AnimationPlayer", true, false)
			var skeletons := visual.find_children("*", "Skeleton3D", true, false)
			_check(players.size() == 1 and skeletons.size() == 1, "character has one skeleton and animation player: " + id)
			if players.size() == 1 and skeletons.size() == 1:
				var player := players[0] as AnimationPlayer
				var skeleton := skeletons[0] as Skeleton3D
				_check(skeleton.get_bone_count() >= 7, "usable articulated skeleton: " + id)
				for clip in ["idle", "walk", "run", "celebrate"]: _check(player.has_animation(clip), "required clip " + id + "/" + clip)
				visual.get_node("ActorAnimation").set_process(false)
				player.play("walk")
				player.pause()
				player.seek(0, true)
				await process_frame
				var bone := skeleton.find_bone("LegL" if id == "CHAR_07" else "LegLF")
				var pose := skeleton.get_bone_pose_rotation(bone)
				player.seek(0.25, true)
				await process_frame
				_check(not pose.is_equal_approx(skeleton.get_bone_pose_rotation(bone)), "walk actually articulates leg: " + id)
		visual.queue_free()
		await process_frame
		await process_frame
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
	var gate := farm.get_node("Gate")
	var left := gate.find_child("GateLeft", true, false) as Node3D
	var right := gate.find_child("GateRight", true, false) as Node3D
	_check(left != null and right != null, "gate has separate hinges")
	farm.set_gate_open(true)
	await create_timer(0.75).timeout
	_check(gate.get_node("CollisionShape3D").disabled, "open gate collision disabled")
	_check(left.rotation.y > 1.4 and right.rotation.y < -1.4, "both gate leaves swing open")
	_check(not farm._farmer_baton.visible, "farmer baton hidden after showdown")
	farm.set_npc_completed("sheep")
	_check(not farm._sheep_tag.visible, "sheep sheds grade tag")
	farm.reset_world()
	await create_timer(0.75).timeout
	_check(farm._sheep_tag.visible and farm._farmer_baton.visible, "reset restores removable props")
	_check(absf(left.rotation.y) < 0.01 and absf(right.rotation.y) < 0.01, "reset closes gate hinges")
	farm.queue_free()
	await process_frame
	print("ART_ASSETS_TEST assertions=%d failures=%d triangles=%d" % [assertions, failures, triangles])
	quit(0 if failures == 0 else 1)
