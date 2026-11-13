extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("EXPORT_PACK_FAIL: " + message)

func _run() -> void:
	# Catalog must stay grouped: 18 core + 18 ENV_09 dressing + 13 course-1 props = 49.
	# NOTE: "production-only file excluded" checks moved to scripts/art/run_demo.ps1 -PackCheck,
	# which byte-scans the exported .pck (running this script against the source tree can
	# never prove pack exclusions because res:// falls back to the project directory).
	var assets = load("res://scripts/art/asset_library.gd")
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
	_check(core == 89, "89 core assets delivered (got %d)" % core)
	_check(dressing == 18, "18 diverse dressing modules delivered (got %d)" % dressing)
	_check(course == 13, "13 course-1 props delivered (got %d)" % course)
	_check(catalog.assets.size() == 120, "catalog holds 120 runtime models (got %d)" % catalog.assets.size())
	for id in catalog.assets:
		var visual: Node3D = assets.make(id)
		_check(visual != null, "packed model loads: " + id)
		if visual: visual.free()
	var art = load("res://scripts/art/art_2d.gd")
	for portrait in art.PORTRAITS.values(): _check(portrait != null and portrait.get_width() > 0, "packed portrait loads")
	for ending in art.ENDINGS.values(): _check(ending != null and ending.get_width() > 0, "packed ending loads")
	for course_scene in ["course_01_ox_field", "course_02_creek", "course_03_woodland", "course_04_courtyard"]:
		var packed = load("res://scenes/courses/%s.tscn" % course_scene)
		_check(packed != null, "course scene loads: " + course_scene)
	var game: Node3D = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	_check(game.get_node_or_null("Pig/VisualMesh/CHAR_01") != null, "packed player model mounted")
	_check(game.get_node("Farm/Gate").find_child("GateLeft", true, false) != null, "packed gate hinged")
	var environment: Node3D = game.get_node_or_null("Farm/PastoralEnvironment")
	_check(environment != null and environment.get_script() == null, "authored environment is baked into the pack")
	_check(environment.get_meta("layout_version",0)==6,"enriched mountain environment version packaged")
	_check(environment.get_meta("dressing_counts",{}).size()>=18,"dressing catalog survives export")
	for batch in environment.find_children("Dressing_*","MultiMeshInstance3D",true,false):
		_check(batch.multimesh.mesh!=null,"packed dressing mesh loads")
		var placements: Array=batch.get_meta("placements",[])
		_check(placements.size()==batch.multimesh.instance_count,"packed placements preserved")
		if DisplayServer.get_name()!="headless": _check(batch.multimesh.get_instance_transform(0).basis.determinant()>.001,"packed GPU instance transform restored")
	_check(game.camera.size==8 and not game.camera.test_high_view,"packed game starts with close gameplay camera")
	_check(ResourceLoader.exists("res://scripts/levels/farm_layout.gd"),"mountain layout packaged")
	_check(InputMap.has_action("action_jump"),"jump input packaged")
	_check(ResourceLoader.exists("res://scripts/art/pastoral_surface.gdshader"), "pastoral shader packaged")
	_check(game.get_node_or_null("Farm/PigpenGate/TimberGate") != null, "pigpen gate insert packaged")
	print("EXPORTED_ART_TEST failures=%d" % failures)
	quit(failures)
