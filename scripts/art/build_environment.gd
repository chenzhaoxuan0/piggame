extends SceneTree
## godot --headless --path . --script scripts/art/build_environment.gd -- --rebuild-environment

func _initialize() -> void:
	call_deferred("_build")

func _own(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_own(child, scene_root)

func _build() -> void:
	if not "--rebuild-environment" in OS.get_cmdline_user_args():
		push_error("Pass -- --rebuild-environment to rebuild from authored source")
		quit(1)
		return
	var farm := load("res://scenes/levels/farm/farm_grounds.tscn").instantiate() as Node3D
	root.add_child(farm)
	var environment := farm.get_node("PastoralEnvironment")
	_own(environment, environment)
	# The baked scene needs no generator script or editor-time RNG at runtime.
	environment.set_script(null)
	var packed := PackedScene.new()
	var result := packed.pack(environment)
	if result == OK:
		DirAccess.make_dir_recursive_absolute("res://assets/environments")
		result = ResourceSaver.save(packed, "res://assets/environments/pastoral_farm.scn", ResourceSaver.FLAG_COMPRESS)
	print("PASTORAL_BUILD result=%d" % result)
	quit(0 if result == OK else 1)
