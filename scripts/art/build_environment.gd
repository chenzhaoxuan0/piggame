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
	# 2026-11-16 实机连环 bug 的出口闸：外部工具（另一版本的 Godot 编辑器）
	# 曾把烘焙产物重写成半损坏的资源，引擎按坏头报「format version 不支
	# 持」，开局猪无限坠落。保存后立刻回读——解析不动就非零退出，坏件永
	# 远到不了 git。
	var verify: PackedScene = null
	if result == OK:
		verify = load("res://assets/environments/pastoral_farm.scn") as PackedScene
	print("PASTORAL_BUILD result=%d verify=%s" % [result, verify != null])
	quit(0 if (result == OK and verify != null) else 1)
