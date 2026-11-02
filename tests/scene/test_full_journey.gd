extends SceneTree
## Real rendered scene, keyboard movement and UI buttons; no state shortcuts or teleporting.
var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("JOURNEY %s %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _click_option(index: int = 0) -> void:
	while office.line_index < office.dialogue_lines.size() - 1:
		office._advance_dialogue()
		await process_frame
	await process_frame
	office.options.get_child(index).pressed.emit()
	await process_frame
	while office.busy: await process_frame

func _dialogue() -> void:
	for i in 20:
		if not office.dialogue_open: return
		await _click_option()
	_check(false, "dialogue terminates")

func _walk_to(point: Vector3) -> void:
	for frame in 18000:
		var offset: Vector3 = point - office.player.global_position
		offset.y = 0
		if offset.length() < 0.35: break
		if office.overlay.visible or office.dialogue_open: break
		var right: Vector3 = office.camera.global_basis.x
		var back: Vector3 = office.camera.global_basis.z
		right.y = 0
		back.y = 0
		var direction := offset.normalized()
		var x := direction.dot(right.normalized())
		var y := direction.dot(back.normalized())
		for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
		Input.action_press("move_right" if x > 0 else "move_left", absf(x))
		Input.action_press("move_down" if y > 0 else "move_up", absf(y))
		await physics_frame
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	_check(office.player.global_position.distance_to(point) < 0.7, "walk to %s" % point)

func _interact() -> void:
	var event := InputEventAction.new()
	event.action = "action_interact"
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
	event = InputEventAction.new()
	event.action = "action_interact"
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	_check(office.dialogue_open, "E opens nearby interaction")

func _shot(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://builds")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join("journey_%s.png" % id))

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout
	await _shot("intro")
	await _click_option()
	await _click_option(1)
	await _click_option()
	_check(game.ending == "stay", "blue ending via dialogue")
	office.queue_free()
	await process_frame
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout
	await _dialogue()
	_check(game.has_pin and game.stage == "exploring", "red choice opens pigpen")
	await _walk_to(Vector3(0, 0.1, -52))
	await _shot("route")
	await _walk_to(Vector3(0, 0.1, -86))
	_check(game.stage == "showdown", "zero skill chase won")
	await _shot("gate")
	await _walk_to(Vector3(3.3, 0.1, -87.5))
	await _interact()
	await _dialogue()
	_check(game.stage == "cablecar_ready", "three rounds open iron gate")
	await _walk_to(Vector3(0, 0.1, -87))
	await _walk_to(Vector3(0, 0.1, -96.8))
	await _walk_to(Vector3(-1, 0.1, -97))
	await _interact()
	await _dialogue()
	await create_timer(4.3).timeout
	await _shot("escape")
	_check(game.ending == "escape", "cablecar reaches red ending")
	_check(office.farm.get_cablecar().position.is_equal_approx(Vector3(0, 2, -126)), "cabin completes travel")
	print("FULL_JOURNEY failures=%d" % failures)
	quit(0 if failures == 0 else 1)
