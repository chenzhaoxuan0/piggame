extends SceneTree

# Dev tool: run the demo briefly, teleport the pig to each district, save screenshots.
# Run: godot --path . --script tests/scene/capture_farm_shots.gd
const SHOTS := [
	["spawn", Vector3(0, 0.1, 93)],
	["route1", Vector3(0, 0.1, 78)],
	["ox", Vector3(-10, 0.1, 50)],
	["shed", Vector3(-6, 0.1, 10)],
	["pond", Vector3(14, 0.1, 6)],
	["track", Vector3(2, 0.1, -28)],
	["open", Vector3(0, 0.1, -60)],
	["gate", Vector3(0, 0.1, -86)],
	["cablecar", Vector3(0, 0.1, -101)],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds")
	var office: Node = (load("res://scenes/levels/office_level_1.tscn") as PackedScene).instantiate()
	root.add_child(office)
	for i in 300:
		if office.dialogue_open:
			break
		await process_frame
	await process_frame
	office.close_dialogue()
	office.cinematic = true
	office.player.set_control_mode("cinematic")
	await process_frame
	for shot in SHOTS:
		office.player.global_position = shot[1]
		office.camera.snap_to_target()
		for i in 14:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("res://builds/farm_shot_%s.png" % shot[0])
		print("saved farm_shot_%s.png" % shot[0])
	office.queue_free()
	quit(0)
