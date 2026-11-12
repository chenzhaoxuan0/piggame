extends SceneTree

# Opening key-test scene guard: the boot menu is a real playground - the pig
# answers WASD / Space / Shift live, the trough reacts to F/E/K, buttons never
# steal focus, and GameManager.pending_boot hands off to office_level_1 which
# auto-enters the dream (or the farm) instead of its own start menu.

var failures := 0
var game: Node
var _snorted := false # member on purpose: lambda captures copy local vars

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("OPENING_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _ev(action: String, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _on_snort(_target: Node3D) -> void:
	_snorted = true

func _run() -> void:
	game = root.get_node("GameManager")
	game.pending_boot = ""

	# --- 1. Scene builds: pig on stage, trough interactable, menu buttons
	var opening: Node = load("res://scenes/ui/opening_scene.tscn").instantiate()
	root.add_child(opening)
	await create_timer(0.5).timeout

	var pig: PigController = opening.pig
	_check(pig != null and pig.is_in_group("player"), "The real pig controller is on stage")
	_check(pig.control_mode == "explore", "Pig answers keys immediately (explore mode)")
	_check(pig.dash_enabled and pig.force_dodge_available, "Shift sprint and dodge are armed for the demo")
	_check(opening.trough != null and opening.trough.is_in_group("interactable"), "Trough is a real interactable")

	for btn_name in ["StartButton", "SkipIntroButton", "QuitButton"]:
		var btn: Button = opening.find_child(btn_name, true, false)
		_check(btn != null, "Menu button exists: " + btn_name)
		if btn != null:
			_check(btn.focus_mode == Control.FOCUS_NONE, "Button never steals keyboard focus: " + btn_name)
	_check(opening.find_child("KeyTestStrip", true, false) != null, "Key-test strip is on screen")

	# --- 2. Keys move the pig: WASD walking (polled, first input used)
	var origin: Vector3 = pig.global_position
	Input.action_press("move_right")
	for i in 30: await physics_frame
	Input.action_release("move_right")
	_check(pig.global_position.distance_to(origin) > 0.5, "Holding D walks the pig across the pen")

	# --- 3. Space hops (event-driven input)
	var jumps_before: int = pig.jumps
	_ev("action_jump")
	for i in 12: await physics_frame
	_ev("action_jump", false)
	_check(pig.jumps > jumps_before, "Space hops the pig")

	# --- 4. Hold-Shift sprint: sample DURING the hold (mixed synthetic input
	# sources can drop the polled state mid-hold, so don't check afterwards).
	_ev("move_up")
	_ev("action_dash")
	var sprint_seen := false
	var stamina_spent := false
	for i in 20:
		await physics_frame
		if pig.is_sprinting: sprint_seen = true
		if pig.stamina < pig.max_stamina: stamina_spent = true
	_ev("move_up", false)
	_ev("action_dash", false)
	_check(sprint_seen or stamina_spent, "Hold-Shift sprints while moving")

	# --- 5. F/E/K near the trough: the interact chain fires end to end
	pig.global_position = opening.trough.global_position + Vector3(-0.9, 0.25, -0.9)
	await physics_frame
	pig.reached_interactable.connect(_on_snort)
	_ev("action_interact")
	for i in 8: await physics_frame
	_ev("action_interact", false)
	_check(_snorted, "F/E/K at the trough emits the interaction (snort chain)")

	opening.queue_free()
	await process_frame

	# --- 6. Hand-off "farm": office consumes the flag, no start menu stop
	game.pending_boot = "farm"
	var office_farm: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office_farm)
	await create_timer(0.5).timeout
	_check(not office_farm.in_start_menu and office_farm.active_course == null, "Skip intent lands straight on the farm")
	_check(office_farm.farm.get_parent() == office_farm and office_farm.player.control_mode == "explore", "Farm open and pig in control after skip hand-off")
	_check(game.pending_boot == "", "Boot flag consumed after use")
	_check(game.intro_dream_done, "Skip hand-off marks the prologue beat as known")
	office_farm.queue_free()
	await process_frame

	# --- 7. Hand-off "dream": office auto-enters the nightmare prologue
	game.reset_run()
	game.pending_boot = "dream"
	var office_dream: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office_dream)
	await create_timer(0.6).timeout
	_check(not office_dream.in_start_menu, "Dream intent skips the start menu too")
	_check(is_instance_valid(office_dream.active_course) and office_dream.active_course.runner.config.course_id == "course_0", "Start intent falls asleep into the nightmare")
	# End the dream before quitting: tearing the tree down with a live course
	# crashes the headless teardown (test_dream_intro ends the same way).
	office_dream.active_course.runner._on_start(office_dream.player)
	await process_frame
	office_dream.active_course.runner._on_exit(office_dream.player)
	await create_timer(3.4).timeout
	_check(office_dream.active_course == null, "Dream hand-off office also wakes cleanly")

	print("\nALL OPENING SCENE TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
