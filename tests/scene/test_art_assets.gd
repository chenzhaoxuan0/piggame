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

func _scan(node: Node, style: String) -> void:
	_check(not node is CollisionObject3D and not node is CollisionShape3D, "import must not replace gameplay collision")
	_check(not node is Camera3D and not node is Light3D, "import must not change level lighting or camera")
	if node is MeshInstance3D:
		meshes += 1
		var mesh: Mesh = node.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size() / 3
			var material: Material = node.get_active_material(surface)
			if style == "pbr":
				# 分区画风制（AGENTS.md §5 / asset_library "pbr"）：序章噩梦工厂
				# 走照相写实，保留 GLB 自带的 PBR 材质，不套田园卡通 shader。
				# 契约从「全部田园」改为「按目录 style 各归各位」。
				_check(material != null and material is StandardMaterial3D,
					"pbr surface keeps its authored StandardMaterial3D (no flat-paint wash)")
				continue
			var shader_material := material as ShaderMaterial
			_check(shader_material != null, "surface has authored material")
			if shader_material == null: continue
			_check(shader_material.shader.resource_path == "res://scripts/art/pastoral_surface.gdshader", "actors and scenery share pastoral lighting")
			_check(shader_material.get_shader_parameter("vertex_palette") == false, "model retains authored pigment")
			var pigment: Color = shader_material.get_shader_parameter("pigment")
			_check(pigment.a == 1.0 and pigment.r >= 0 and pigment.r <= 1, "opaque bounded pigment without texture noise")
	for child in node.get_children(): _scan(child, style)

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/aholo/runtime_catalog.json"))
	var core := 0
	var dressing := 0
	var course := 0
	for id in catalog.assets:
		if id.begins_with("ENV_09_"):
			dressing += 1
		elif id.begins_with("PROP_C1_"):
			course += 1
		else:
			core += 1
	_check(core == 75, "75 core assets delivered (got %d)" % core)
	_check(dressing == 18, "18 diverse dressing modules delivered (got %d)" % dressing)
	_check(course == 13, "13 course-1 props delivered (got %d)" % course)
	_check(catalog.assets.size() == 106, "catalog total 106 (got %d)" % catalog.assets.size())
	for id in catalog.assets:
		var visual := ASSETS.make(id)
		_check(visual != null, "accepted model loads: " + id)
		if visual == null: continue
		var before := triangles
		_scan(visual, str(catalog.assets[id].get("style", "flat")))
		var budget:=90000 if id.begins_with("CHAR_") else (7000 if id=="ENV_09_WOOL" else 6000)
		_check(triangles - before <= budget, "model fits triangle budget: " + id)
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
	_check(farm.get_node_or_null("CableCarCabin/Deck") == null, "placeholder cabin removed")
	var ox_art := farm.get_node_or_null("NPC_ox/CHAR_03")
	_check(ox_art != null and ox_art.visible, "accepted ox model mounted on story body")
	_check(get_nodes_in_group("interactable").size() == 8, "art keeps interaction roots (incl. the pigpen trough)")
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
