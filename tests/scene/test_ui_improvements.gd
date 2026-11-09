extends SceneTree

const L = preload("res://scripts/levels/farm_layout.gd")
var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("UI_TEST %s %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _input(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _walk_to(point: Vector3) -> void:
	for frame in 600:
		var offset: Vector3 = point - office.player.global_position
		offset.y = 0
		if offset.length() < 0.35: break
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

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.5).timeout

	# 1. Entry state: Start Menu visible, no auto dialogue, no top bar, prompt hidden
	_check(office.in_start_menu and office.start_menu.visible, "Start menu is visible on game launch")
	_check(not office.dialogue_open, "No auto-dialogue with Old Goat on entry")
	_check(office.player.control_mode == "cinematic", "Player controls locked during start menu")
	_check(not office.prompt.visible, "Prompt is hidden on start menu")
	_check(office.objective == null or not office.objective.is_inside_tree(), "Top title/objective bar is removed")

	# 2. Test Settings menu from Start Screen
	office._open_settings(true)
	await process_frame
	_check(office.in_settings and office.settings_menu.visible, "Settings modal opens from start menu")
	_check(not office.start_menu.visible, "Start menu hides while in settings")
	office._close_settings()
	await process_frame
	_check(not office.in_settings and not office.settings_menu.visible, "Settings modal closes cleanly")
	_check(office.in_start_menu and office.start_menu.visible, "Start menu restored after closing settings")

	# 3. Start Game button
	office.start_game()
	await process_frame
	_check(not office.in_start_menu and not office.start_menu.visible, "Start menu dismissed on start_game()")
	_check(office.player.control_mode == "explore", "Player enters explore mode")
	_check(not office.dialogue_open, "Dialogue remains closed until manual interaction")
	_check(office.prompt.text == "", "Prompt text is empty when idle (clean screen)")

	# 4. In-game ESC Pause & Controls Guide
	await _input("ui_cancel")
	await process_frame
	_check(office.paused and office.pause_menu.visible, "ESC key opens Pause menu")
	_check(office.player.control_mode == "paused", "Player movement frozen when paused")
	var guide_label: Node = office.pause_menu.find_child("GuideTitle", true, false)
	_check(guide_label != null and guide_label.is_inside_tree(), "Controls guide is displayed inside pause menu")

	# Resume from pause
	office._resume()
	await process_frame
	_check(not office.paused and not office.pause_menu.visible, "Resuming closes pause menu and guide")
	_check(office.player.control_mode == "explore", "Player returns to explore mode after resume")

	# 5. Approach Old Goat and interact to trigger dialogue
	# Pig spawns at (0, 32.1, 100), Goat is at (-3, 32, 90)
	await _walk_to(Vector3(-1.8, 32.1, 91.2))
	for i in 10: await physics_frame
	var nearest: Node3D = office.player.get_nearest_interactable()
	_check(nearest != null and str(nearest.get_meta("interaction_id", "")) == "goat", "Old Goat is detected when approaching")
	_check(office.prompt.text.contains("老岩羊"), "Prompt displays [ F ] 老岩羊 near goat")

	# Press F / interact to talk to Old Goat
	await _input("action_interact")
	for i in 6: await process_frame
	_check(office.dialogue_open, "Manual interaction opens dialogue with Old Goat")
	_check(office.speaker_label.text.contains("老岩羊"), "Dialogue speaker is Old Goat")
	_check(office.dialogue_lines.size() > 0, "Dialogue content lines populated")

	print("UI_IMPROVEMENTS_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
