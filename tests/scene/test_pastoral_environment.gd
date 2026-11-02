extends "res://tests/scene/test_full_journey.gd"
## Visit every story district by normal movement after the environment rebuild.
## Unlike screenshot capture, this test never teleports the player.

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(.6).timeout
	var environment: Node3D = office.farm.get_node("PastoralEnvironment")
	_check(environment.get_script() == null, "runtime loads baked environment")
	var districts := ["PigpenStoneAndMud", "OxFurrowsAndIrrigation", "LowShearingShed", "HorsePaddockAndTrack", "FarmWorkingYard", "StoneGatewayAndCableStation", "CliffFaces"]
	for district in districts:
		var found := false
		for child in environment.get_children():
			if String(child.name).begins_with(district) and child is MeshInstance3D:
				found = found or child.visible
		_check(found, "authored district visible: " + district)
	_check(not office.farm.get_node("Ground/VisualMesh").visible, "rectangular blockout floor hidden")
	_check(office.farm.get_node("PigpenGate/TimberGate").visible, "wooden gate replaces red slab")
	# Actual body sweeps check the new architecture, not just metadata.
	await physics_frame
	var world: PhysicsDirectSpaceState3D = office.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(-8.8, .8, 89), Vector3(-8, .8, 89), 1)
	_check(not world.intersect_ray(query).is_empty(), "pig shelter wall has collision")
	query = PhysicsRayQueryParameters3D.create(Vector3(28, .8, -24.5), Vector3(33, .8, -24.5), 1)
	_check(not world.intersect_ray(query).is_empty(), "stable has collision")
	await _dialogue()
	_check(game.has_pin, "opening story still gives pin")
	await _walk_to(Vector3(0, .1, 64))
	await _walk_to(Vector3(-7.8, .1, 51))
	await _interact()
	await _dialogue()
	await create_timer(1).timeout
	_check(office.farm.get_node("NPC_ox").position.distance_to(Vector3(-24.5, 0, 40)) < .1, "ox story reaches water")
	await _walk_to(Vector3(0, .1, 51))
	await _walk_to(Vector3(0, .1, 10))
	await _walk_to(Vector3(-10.8, .1, 10))
	await _interact()
	await _dialogue()
	_check(not office.farm._sheep_tag.visible, "sheep story removes grade tag")
	await _walk_to(Vector3(0, .1, 10))
	await _walk_to(Vector3(0, .1, -28))
	await _walk_to(Vector3(14.8, .1, -28))
	await _interact()
	await _dialogue()
	await create_timer(1).timeout
	_check(office.farm.get_node("NPC_horse").position.distance_to(Vector3(7.5, 0, -28)) < .1, "horse story reaches grazing patch")
	# Walk around the horse after it moves into the west exit lane.
	await _walk_to(Vector3(14.8, .1, -26.3))
	await _walk_to(Vector3(6, .1, -26.3))
	await _walk_to(Vector3(0, .1, -28))
	await _walk_to(Vector3(0, .1, -52))
	_check(not office.overlay.visible, "all districts traversed without losing")
	print("PASTORAL_ENVIRONMENT_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
