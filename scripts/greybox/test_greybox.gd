extends SceneTree
## Run headless with --script res://scripts/greybox/test_greybox.gd.

var _failures: int = 0
var _trigger_count: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/levels/greybox/farm_greybox.tscn")
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await physics_frame
	await physics_frame
	_check(world.get_spawn_position().is_equal_approx(Vector3(0, 0.1, 18)), "spawn contract")
	_check(get_nodes_in_group("interactable").size() == 7, "seven interaction targets")
	_check(_hit(world, Vector3(0, 0.6, -24), Vector3(0, 0.6, -26)), "iron gate initially blocks center")
	_check(_hit(world, Vector3(8, 0.6, -24), Vector3(8, 0.6, -26)), "side wall prevents bypass")
	_check(_hit(world, Vector3(0, 0.6, 14), Vector3(0, 0.6, 12)), "pigpen initially closed")
	world.set_gate_open(true)
	world.set_pigpen_open(true)
	await physics_frame
	await physics_frame
	_check(not _hit(world, Vector3(0, 0.6, -24), Vector3(0, 0.6, -26)), "open iron gate clears corridor")
	_check(not _hit(world, Vector3(0, 0.6, 14), Vector3(0, 0.6, 12)), "open pigpen clears corridor")
	_check(not _hit(world, Vector3(0, 0.6, 12), Vector3(0, 0.6, -24)), "entire center route unobstructed")
	_check(_hit(world, Vector3(9.5, 0.6, -10), Vector3(10.8, 0.6, -10)), "east boundary sealed")
	_check(_hit(world, Vector3(0, 1, -35), Vector3(0, -1, -35)), "cablecar platform has ground")
	world.set_npc_completed("ox")
	await create_timer(0.9).timeout
	_check(world.get_node("NPC_ox").position.is_equal_approx(Vector3(-6.8, 0, 6)), "ox moves beside trough")
	world.get_cablecar().position += Vector3(2, 0, -2)
	world.reset_world()
	await physics_frame
	await physics_frame
	_check(world.get_node("NPC_ox").position.is_equal_approx(Vector3(-4, 0, 8)), "reset restores npc")
	_check(world.get_cablecar().position.is_equal_approx(Vector3(0, 0, -34)), "reset restores cablecar")
	_check(_hit(world, Vector3(0, 0.6, -24), Vector3(0, 0.6, -26)), "reset closes gate")
	world.chase_entered.connect(func(): _trigger_count += 1)
	var player := CharacterBody3D.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player")
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.1
	collider.shape = shape
	collider.position.y = 0.55
	player.add_child(collider)
	player.position = Vector3(0, 0.1, -5.4)
	world.add_child(player)
	await physics_frame
	await physics_frame
	await physics_frame
	_check(_trigger_count == 1, "player entering chase emits once")
	print("GREYBOX_TEST_RESULT failures=%d" % _failures)
	world.queue_free()
	await process_frame
	quit(1 if _failures else 0)

func _hit(world: Node3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)
