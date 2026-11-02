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
	print("EXPORTED_ART_TEST failures=%d" % failures)
	quit(failures)
