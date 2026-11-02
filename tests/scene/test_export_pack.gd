extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var assets = load("res://scripts/art/asset_library.gd")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/aholo/runtime_catalog.json"))
	_check(catalog.assets.size() == 18, "all runtime models packaged")
	for id in catalog.assets:
		var visual: Node3D = assets.make(id)
		_check(visual != null, "packed model loads: " + id)
		if visual: visual.free()
	var art = load("res://scripts/art/art_2d.gd")
	for portrait in art.PORTRAITS.values(): _check(portrait != null and portrait.get_width() > 0, "packed portrait loads")
	for ending in art.ENDINGS.values(): _check(ending != null and ending.get_width() > 0, "packed ending loads")
	for private_path in ["res://.env", "res://assets/models/aholo/production.json", "res://scripts/art/produce_assets.py", "res://assets/models/aholo/CHAR_01/CHAR_01_lux3d.zip", "res://assets/models/aholo/_input/CHAR_01/subject.png"]:
		_check(not FileAccess.file_exists(private_path), "production-only file excluded: " + private_path)
	var game: Node3D = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	_check(game.get_node_or_null("Pig/VisualMesh/CHAR_01") != null, "packed player model mounted")
	_check(game.get_node("Farm/Gate").find_child("GateLeft", true, false) != null, "packed gate hinged")
	var environment: Node3D = game.get_node_or_null("Farm/PastoralEnvironment")
	_check(environment != null and environment.get_script() == null, "authored environment is baked into the pack")
	_check(environment.get_meta("layout_version",0)==3,"mountain environment version packaged")
	_check(game.camera.size==8 and not game.camera.test_high_view,"packed game starts with close gameplay camera")
	_check(ResourceLoader.exists("res://scripts/levels/farm_layout.gd"),"mountain layout packaged")
	_check(InputMap.has_action("action_jump"),"jump input packaged")
	_check(ResourceLoader.exists("res://scripts/art/pastoral_surface.gdshader"), "pastoral shader packaged")
	_check(game.get_node_or_null("Farm/PigpenGate/TimberGate") != null, "pigpen gate insert packaged")
	print("EXPORTED_ART_TEST failures=%d" % failures)
	quit(failures)
