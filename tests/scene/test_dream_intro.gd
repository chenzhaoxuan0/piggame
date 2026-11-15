extends SceneTree

# Boot-flow guard for the nightmare prologue: the start menu's main button
# falls asleep into the dream, completing it wakes the pig in its pen with the
# run state untouched, and the skip button goes straight to the farm.

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("DREAM_INTRO_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	game = root.get_node("GameManager")

	# --- 1. Main button: begin the game = fall asleep into the nightmare
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await process_frame
	game.reset_run()
	office._show_start_menu()
	await process_frame
	_check(office.in_start_menu, "Start menu shown")

	var start_btn: Button = office.start_menu.find_child("StartButton", true, false)
	start_btn.pressed.emit()
	await create_timer(0.5).timeout
	_check(not office.in_start_menu, "Start menu closed by the main button")
	_check(is_instance_valid(office.active_course) and office.active_course.runner.config.course_id == "course_0", "Main button enters the nightmare dream")
	_check(office.farm.get_parent() == null, "Farm removed during the dream")
	_check(game.stage == "prologue", "Dream keeps the run stage in prologue")
	_check(office.current_chase_id == "intro", "Dream runs under the intro chase id")

	# --- 2. Completing the dream: wake up in the pen, run state untouched
	var runner: CourseRunner = office.active_course.runner
	runner._on_start(office.player)
	await process_frame
	_check(game.stage == "prologue", "Crossing the dream's start line does not start a stage chase")
	runner._on_exit(office.player)
	await create_timer(0.4).timeout
	_check(office.active_course == null and office.farm.get_parent() == office, "Dream unloaded, farm restored on waking")
	_check(game.stage == "prologue", "Waking up keeps the run stage in prologue")
	var pen_spawn: Vector3 = office.farm.get_spawn_position()
	_check(office.player.global_position.distance_to(pen_spawn) < 2.0, "Pig wakes up in its pen (spawn point)")
	for chase_id in game.chase_completed:
		_check(not game.chase_completed[chase_id], "No chase booked by the dream: " + chase_id)
	_check(office.player.control_mode == "explore", "Control restored after waking")
	await create_timer(3.0).timeout # Let the wake toast chain settle before the scene is reused

	# --- 3. Skip button: straight to the farm opening
	office._show_start_menu()
	await process_frame
	var skip_btn: Button = office.start_menu.find_child("SkipIntroButton", true, false)
	_check(skip_btn != null, "Skip-intro button exists on the start menu")
	skip_btn.pressed.emit()
	await create_timer(0.5).timeout
	_check(not office.in_start_menu and office.active_course == null, "Skip goes straight to the farm, no dream")
	_check(office.farm.get_parent() == office and office.player.control_mode == "explore", "Farm open and pig in control after skipping")
	_check(game.tutorial_free_roam, "In-menu skip also lands in the pigpen tutorial")

	# --- 4. Start-menu 开始游戏 while the pigpen sandbox is live: converge, no hard cut
	# (menus.gd binds the button to host.start_dream_intro; in the pigpen context
	# it must funnel through the quiz + fall-asleep beat like the title card does.)
	office._show_start_menu()
	await process_frame
	var pen_start_btn: Button = office.start_menu.find_child("StartButton", true, false)
	_check(pen_start_btn != null, "Start button exists for the pigpen-context check")
	if pen_start_btn != null:
		pen_start_btn.pressed.emit()
		await process_frame
		_check(office.find_child("BrainHoleQuiz", true, false) != null, "Pigpen-context 开始游戏 funnels through the brain-hole quiz")
		_check(office.active_course == null and not office.sleep_playing, "No hard cut: the sleep beat only starts after the quiz")
	office._quiz_next = ""
	var parked: Control = office.find_child("BrainHoleQuiz", true, false)
	if parked != null:
		parked.queue_free()

	# --- 5. NG+ (2026-11-15 playtest #15): the prologue plays exactly once.
	# Second-visit profiles talk to the goat and go straight out the gate.
	game.ng_plus = true
	game.tutorial_free_roam = true
	game.stage = "prologue"
	game.has_pin = false
	office.in_start_menu = false
	office._on_interact(office.farm.get_node("NPC_goat"))
	await process_frame
	await process_frame
	_check(not game.tutorial_free_roam and game.has_pin, "NG+ goat talk hands the pin straight over")
	_check(game.stage == "exploring", "NG+ skips the dream straight into exploration")
	_check(office.active_course == null and not office.sleep_playing, "NG+ never starts the sleep/dream beat")
	office.queue_free()
	await process_frame

	print("\nALL DREAM INTRO TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
