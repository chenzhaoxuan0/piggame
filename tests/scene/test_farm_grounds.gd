extends SceneTree

# Run: godot --headless --path . --script tests/scene/test_farm_grounds.gd
var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _hit(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not root.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/levels/farm/farm_grounds.tscn")
	_check(scene != null, "farm_grounds scene loads")
	if scene == null:
		return
	var farm := scene.instantiate() as Node3D
	root.add_child(farm)
	await physics_frame
	await physics_frame
	_check(farm.get_spawn_position().is_equal_approx(Vector3(0, 0.1, 93)), "spawn contract")
	_check(get_nodes_in_group("interactable").size() == 7, "seven interaction targets")
	_check(_hit(Vector3(0, 0.6, -89), Vector3(0, 0.6, -91)), "iron gate blocks center")
	_check(_hit(Vector3(-12, 0.6, -89), Vector3(-12, 0.6, -91)), "west gate wall prevents bypass")
	_check(_hit(Vector3(12, 0.6, -89), Vector3(12, 0.6, -91)), "east gate wall prevents bypass")
	_check(_hit(Vector3(0, 0.6, 85), Vector3(0, 0.6, 87)), "pigpen initially closed")
	farm.set_gate_open(true)
	farm.set_pigpen_open(true)
	await physics_frame
	await physics_frame
	_check(not _hit(Vector3(0, 0.6, -89), Vector3(0, 0.6, -91)), "open iron gate clears corridor")
	_check(not _hit(Vector3(0, 0.6, 85), Vector3(0, 0.6, 87)), "open pigpen clears corridor")
	_check(not _hit(Vector3(0, 0.6, 85), Vector3(0, 0.6, -89)), "entire journey route unobstructed")
	_check(_hit(Vector3(44.5, 0.6, 55), Vector3(46.0, 0.6, 55)), "east boundary sealed")
	_check(_hit(Vector3(-44.5, 0.6, 55), Vector3(-46.0, 0.6, 55)), "west boundary sealed")
	_check(_hit(Vector3(0, 1, -104), Vector3(0, -1, -104)), "cablecar platform has ground")
	_check(farm.get_cablecar() != null and farm.get_cablecar().position.is_equal_approx(Vector3(0, 0, -104)), "cablecar cabin positioned at start")
	_check(farm.get_node_or_null("ChaseStart") != null, "chase trigger exists")
	var ox: Node3D = farm.get_node("NPC_ox")
	var ox_origin: Vector3 = ox.position
	ox_origin.y = 0.0
	farm.set_npc_completed("ox")
	await create_timer(1.0).timeout
	_check(ox.position.distance_to(Vector3(-24.5, 0, 40)) < 0.05, "ox walks to trough target")
	_check(farm.get_node("NPC_ox/NameLabel").text == "老牛 · 饮水", "ox label updates")
	farm.reset_world()
	await physics_frame
	await physics_frame
	_check(ox.position.is_equal_approx(ox_origin), "reset restores ox origin")
	_check(_hit(Vector3(0, 0.6, -89), Vector3(0, 0.6, -91)), "reset closes iron gate")

	# Main scene smoke test: boots, opens intro, advances one dialogue line per click.
	var office_scene: PackedScene = load("res://scenes/levels/office_level_1.tscn")
	_check(office_scene != null, "office scene loads")
	var office: Node = office_scene.instantiate()
	root.add_child(office)
	await create_timer(0.9).timeout
	_check(office.dialogue_open, "office opens intro dialogue")
	_check(not office.dialogue_lines.is_empty(), "intro dialogue has lines")
	var line_count: int = office.dialogue_lines.size()
	if line_count > 1:
		office._advance_dialogue()
		_check(office.line_index == 1, "click advances exactly one line")
		_check(not office.line_hint.visible == (office.line_index >= line_count - 1), "hint hides on last line")
	office.queue_free()
	print("FARM_GROUNDS_TEST assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)
