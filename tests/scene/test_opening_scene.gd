extends SceneTree

# Opening boot menu + pigpen tutorial guard: the boot menu is a plain menu
# over a sky (the floating key-test pen is gone - it had no fall rescue, the
# 架空层 bug), and the "farm" boot drops the pig into its REAL pigpen in a
# pre-game tutorial sandbox: keys work, trough snorts, NPCs won't talk, the
# pen gate stays bolted. Both "start the game" doors (the title card's
# 开始游戏 button and F on the goat in the sandbox) funnel into the SAME
# brain-hole quiz → fall-asleep beat → course_0 dream - no door hard-cuts
# into the nightmare or opens the red-road dialogue early. The goat's
# cliff_goat_intro story beat only plays AFTER the dream, when the sandbox
# is over (narrative order restored).

var failures := 0
var game: Node
var am: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("OPENING_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _quiz_button(quiz: Control, text: String) -> Button:
	for b in quiz.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null

func _run() -> void:
	game = root.get_node("GameManager")
	am = root.get_node("AchievementManager")
	game.pending_boot = ""

	# --- 1. Opening scene is a plain menu: no stage, no pig, no strip
	var opening: Node = load("res://scenes/ui/opening_scene.tscn").instantiate()
	root.add_child(opening)
	await create_timer(0.4).timeout

	_check(opening.get("pig") == null, "The floating pen pig is gone from the boot menu")
	_check(opening.get("trough") == null, "The floating pen trough is gone from the boot menu")
	_check(opening.find_child("Pig", true, false) == null, "No PigController node in the boot menu")
	_check(opening.find_child("KeyTestStrip", true, false) == null, "No key-test strip in the boot menu")
	_check(opening.find_child("BackdropPen", true, false) != null, "The boot menu backdrop is the pigpen diorama")
	_check(opening.find_child("BackdropPig", true, false) != null, "The backdrop pig waits in the pen")
	_check(opening.find_child("BackdropTrough", true, false) != null, "The backdrop trough stands in the pen")
	for btn_name in ["StartButton", "SkipIntroButton", "QuitButton"]:
		var btn: Button = opening.find_child(btn_name, true, false)
		_check(btn != null, "Menu button exists: " + btn_name)
		if btn != null:
			_check(btn.focus_mode == Control.FOCUS_NONE, "Button never grabs focus: " + btn_name)
	opening.queue_free()
	await process_frame

	# --- 2. "farm" boot lands in the pigpen tutorial sandbox
	game.reset_run()
	game.pending_boot = "farm"
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.5).timeout

	_check(not office.in_start_menu and game.pending_boot == "", "farm boot consumed, no start menu")
	_check(game.tutorial_free_roam, "Pigpen tutorial sandbox is active")
	_check(game.intro_dream_done, "Skip hand-off still marks the prologue beat as known")
	_check(office.active_course == null and office.farm.get_parent() == office, "Farm world is live (no floating pen)")

	# --- 2b. Boot is playable at once - the brain-hole quiz only appears on 开始游戏
	_check(office.find_child("BrainHoleQuiz", true, false) == null, "No quiz at boot - the pen is playable immediately")
	_check(office.player.control_mode == "explore", "Pig can roam during the tutorial")
	var tcard: Control = office.find_child("TitleCard", true, false)
	var start_btn: Button = _quiz_button(tcard, "▶  开始游戏（入梦序章）") if tcard != null else null
	_check(start_btn != null, "Title card's 开始游戏 button exists")
	if start_btn != null:
		start_btn.pressed.emit()
		await process_frame
		var quiz: Control = office.find_child("BrainHoleQuiz", true, false)
		_check(quiz != null and quiz.visible, "Brain-hole quiz appears only after clicking 开始游戏")
		_check(office.player.control_mode == "locked", "Pig waits while the quiz owns the centre")
		_check("无厘头" in office._brain_hint.text, "The quiz hint admits this is a useless absurd-comedy game")
		var wrong_btn: Button = _quiz_button(quiz, "好玩")
		var right_btn: Button = _quiz_button(quiz, "不")
		if wrong_btn != null and right_btn != null:
			wrong_btn.pressed.emit()
			await process_frame
			_check(office.find_child("BrainHoleQuiz", true, false) != null, "Answering 好玩 is rejected - the quiz stays")
			_check(office.player.control_mode == "locked", "The pig stays locked after a wrong answer")
			_check("不" in office._brain_hint.text, "The wrong-answer hint still says only 「不」 passes")
		# Park the quiz unanswered so the sandbox sections below keep their pen;
		# the accept-into-dream path runs end-to-end in section 5.
		office._quiz_next = ""
		quiz.queue_free()
		await process_frame
		office.player.set_control_mode("explore")
	_check(office.find_child("BrainHoleQuiz", true, false) == null, "The parked quiz is gone")
	_check(office.player.control_mode == "explore", "Pig roams again")
	_check(office.find_child("TitleCard", true, false) != null, "The boot title card (开始游戏 etc.) stays over the pen during the tutorial")
	var todo_hub: Control = office.find_child("TodoHub", true, false)
	var notebook: Control = office.find_child("TodoNotebook", true, false)
	var todo_btn: Button = office.find_child("TodoToggleButton", true, false)
	var keys_btn: Button = office.find_child("KeysToggleButton", true, false)
	_check(todo_hub != null and todo_hub.visible, "Todo hub (今日待办 + 键位说明 buttons) lives top-right")
	_check(notebook != null and not notebook.visible, "To-do notebook starts folded - only the toggle buttons show")
	_check(todo_btn != null and keys_btn != null, "今日待办 and 键位说明 toggle buttons exist beside each other")
	if todo_btn != null and notebook != null:
		todo_btn.pressed.emit()
		await process_frame
		_check(notebook.visible, "Clicking 今日待办 unfolds the notebook")
		await process_frame # let the auto-height layout settle before measuring
		var nb_rect := notebook.get_global_rect()
		_check(nb_rect.size.x > 300.0, "To-do notebook keeps its ~330px width (no corner sliver)")
		_check(nb_rect.size.y > 60.0 and nb_rect.size.y < 260.0,
			"To-do notebook height fits its entries (auto-height, capped)")
		todo_btn.pressed.emit()
		await process_frame
		_check(not notebook.visible, "Clicking 今日待办 again folds the notebook back")
	if tcard != null and todo_hub != null:
		_check(absf(tcard.get_global_rect().position.y - todo_hub.get_global_rect().position.y) < 6.0,
			"Title card top edge aligns with the todo hub top edge")
	_check(office.player.dash_enabled and office.player.can_dodge(), "Shift sprint and dodge are armed for the sandbox (dodge is always cooled down to start)")
	var spawn_dist: float = office.player.global_position.distance_to(office.farm.get_spawn_position())
	_check(spawn_dist < 1.0, "Pig wakes at the real pigpen spawn")
	var strip: Control = office.find_child("KeyTestStrip", true, false)
	_check(strip != null and not strip.visible, "Key-test strip starts hidden - 键位说明 opens it on demand")
	if keys_btn != null and strip != null:
		keys_btn.pressed.emit()
		await process_frame
		_check(strip.visible, "键位说明 click expands the key strip")
		await process_frame
		var viewport_rect := Rect2(Vector2.ZERO, strip.get_viewport_rect().size)
		_check(viewport_rect.encloses(strip.get_global_rect()), "Key-test strip fully inside the viewport")
		office._key_strip_time_left = 0.2 # shorten the 10s window - real _process ticks it down
		await create_timer(0.5).timeout
		_check(not strip.visible, "Key strip closes itself once the 10s window elapses")
	var pigpen_gate: StaticBody3D = office.farm._pigpen_gate
	_check(pigpen_gate.collision_layer == 1, "Pen gate stays bolted during the tutorial")

	# --- 2b. The title card fades out while the pig moves and fades back once it
	# has stood still ~3s; the to-do notebook folds away on movement (its toggle
	# button never fades), blinks while the pig stands still, and auto-expands
	# after the 3s idle window if nobody clicked. Driven through
	# _update_ui_auto_hide with injected deltas, so the suite never sleeps the
	# real 3 seconds.
	if notebook != null and tcard != null and todo_hub != null and todo_btn != null:
		office.player.velocity = Vector3(3.0, 0.0, 0.0)
		office._update_ui_auto_hide(0.016)
		await create_timer(0.4).timeout # 0.25s fade
		_check(tcard.modulate.a < 0.05, "Title card fades out while the pig is moving")
		_check(not notebook.visible, "Running folds the to-do notebook away")
		_check(todo_hub.visible and todo_btn.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"The toggle buttons never fade - 待办 stays reachable while running")
		var hide_btn: Button = tcard.find_child("TitleStartButton", true, false)
		_check(hide_btn != null and hide_btn.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Faded title-card buttons stop eating clicks (click-to-move stays free)")
		office.player.velocity = Vector3.ZERO
		office._update_ui_auto_hide(1.0)
		await create_timer(0.45).timeout
		_check(not notebook.visible, "Notebook stays folded before the 3s idle window elapses")
		_check(todo_btn.modulate.a < 0.9, "The folded todo button blinks while the pig stands still")
		_check(tcard.modulate.a < 0.05, "Title card stays faded before the 3s idle window elapses")
		office.player.velocity = Vector3.ZERO
		office._update_ui_auto_hide(2.1) # cumulative idle past the 3s window
		await create_timer(0.4).timeout
		_check(tcard.modulate.a > 0.95, "Title card fades back in after ~3s standing still")
		_check(notebook.visible, "To-do auto-expands after 3s idle without a click")
		_check(todo_btn.modulate.a > 0.95, "Blink stops once the notebook is unfolded")
		_check(hide_btn != null and hide_btn.mouse_filter == Control.MOUSE_FILTER_STOP,
			"Title-card buttons clickable again once shown")
		# Manual fold resets the blink window: standing still must not instantly
		# re-expand what the player just folded.
		todo_btn.pressed.emit()
		await process_frame
		_check(not notebook.visible, "Clicking the toggle folds the auto-expanded notebook again")
		office._update_ui_auto_hide(0.5)
		_check(not notebook.visible, "A fresh 3s window starts after a manual fold (no instant re-expand)")
		# Menus/pause own the screen: movement must not auto-hide under them.
		office.paused = true
		office.player.velocity = Vector3(3.0, 0.0, 0.0)
		office._update_ui_auto_hide(0.016)
		await create_timer(0.4).timeout
		_check(tcard.modulate.a > 0.95, "Auto-hide stands down while paused")
		_check(todo_btn.modulate.a == 1.0, "Blink stops while paused")
		office.paused = false
		office.player.velocity = Vector3.ZERO

	# --- 3. The trough snorts: gag + achievement, no dialogue
	var trough: StaticBody3D = office.farm.get_node("PigpenTrough")
	_check(trough.is_in_group("interactable"), "Pigpen trough is a real interactable")
	office._on_interact(trough)
	await process_frame
	_check(not office.dialogue_open, "Trough never opens dialogue")
	_check(am.is_unlocked("trough_sniff"), "trough_sniff unlocks at the real pigpen trough")

	# --- 4. NPCs won't talk during the sandbox
	var goat: StaticBody3D = office.farm.get_node("NPC_goat")
	var fake_npc := StaticBody3D.new()
	fake_npc.set_meta("interaction_id", "ox")
	office._on_interact(fake_npc)
	await process_frame
	_check(not office.dialogue_open, "Non-goat interactions stay blocked in the sandbox")
	_check(game.tutorial_free_roam, "Blocked interaction does not end the tutorial")

	# --- 4b. F on the goat in the sandbox: the dream door, not the story dialogue
	office.player.global_position = goat.global_position + Vector3(1.2, 0.1, 0.8)
	await physics_frame
	office.player._try_interact(goat)
	await process_frame
	_check(not office.dialogue_open, "Sandbox F on the goat does NOT open cliff_goat_intro or the red-road choice")
	_check(game.tutorial_free_roam, "The sandbox survives the goat interaction - the dream comes first")
	var funnel_quiz: Control = office.find_child("BrainHoleQuiz", true, false)
	_check(funnel_quiz != null and funnel_quiz.visible, "F on the goat funnels into the brain-hole quiz (dream intent)")
	_check(office._quiz_next == "dream", "The goat door routes the quiz answer into the dream flow")
	_check(not office.sleep_playing, "The pig is not asleep yet - the quiz gates the fall-asleep beat")
	# Park it again: the end-to-end accept path runs through the title card below.
	if funnel_quiz != null:
		office._quiz_next = ""
		funnel_quiz.queue_free()
		await process_frame
	office.player.set_control_mode("explore")

	# --- 5. Title card 开始游戏 + 「不」: quiz → fall-asleep beat → course_0 (no hard cut)
	var tcard2: Control = office.find_child("TitleCard", true, false)
	start_btn = _quiz_button(tcard2, "▶  开始游戏（入梦序章）") if tcard2 != null else null
	if start_btn != null:
		start_btn.pressed.emit()
		await process_frame
		var quiz2: Control = office.find_child("BrainHoleQuiz", true, false)
		_check(quiz2 != null, "A second 开始游戏 click reopens the still-unanswered quiz")
		var no_btn: Button = _quiz_button(quiz2, "不") if quiz2 != null else null
		if no_btn != null:
			no_btn.pressed.emit()
			await process_frame
			_check(not game.tutorial_free_roam, "Answering 不 ends the sandbox and starts the dream flow")
			_check(office.sleep_playing, "The fall-asleep beat owns the flow (no instant cut into the nightmare)")
			_check(office.active_course == null, "No course entered on the answer frame - the pig falls asleep first")
			_check(not office.dialogue_open, "The dream door never opens the goat story dialogue")
			_check(office.find_child("TitleCard", true, false) == null, "Title card leaves with the tutorial sandbox")
			_check(not office.player.dash_enabled, "Dash returns to story gating after the sandbox")
			_check(not strip.visible, "Key strip hides once the game starts")
			_check(pigpen_gate.collision_layer == 1, "Gate is still bolted - the red/blue choice opens it, not the dream door")
			var waited := 0.0
			while office.active_course == null and waited < 8.0:
				await create_timer(0.2).timeout
				waited += 0.2
			_check(is_instance_valid(office.active_course) and office.active_course.runner.config.course_id == "course_0",
				"After the fall-asleep beat the pig is inside course_0")
			_check(office.current_chase_id == "intro", "Dream runs under the intro chase id")
			_check(not office.sleep_playing and not office.cinematic, "The sleep sequence hands control to the dream")

			# End the dream (same teardown as the dream-boot section), then the
			# goat becomes the post-dream story beat.
			office.active_course.runner._on_start(office.player)
			await process_frame
			office.active_course.runner._on_exit(office.player)
			await create_timer(3.4).timeout
			_check(office.active_course == null and office.farm.get_parent() == office, "Dream unloaded, farm restored on waking")

			# --- 5b. AFTER the dream, F on the goat finally opens cliff_goat_intro
			office.player.global_position = goat.global_position + Vector3(1.2, 0.1, 0.8)
			await physics_frame
			office.player._try_interact(goat)
			await process_frame
			_check(office.dialogue_open and office.current_dialogue == "cliff_goat_intro",
				"Post-dream F on the goat opens cliff_goat_intro (narrative order restored)")
			office.close_dialogue()
			await process_frame

	office.queue_free()
	await process_frame

	# --- 6. "dream" hand-off still auto-enters the nightmare prologue
	game.reset_run()
	game.pending_boot = "dream"
	var office_dream: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office_dream)
	await create_timer(0.6).timeout
	_check(not office_dream.in_start_menu, "Dream intent skips the start menu too")
	_check(not game.tutorial_free_roam, "Dream boot does not enter the pigpen sandbox")
	_check(is_instance_valid(office_dream.active_course) and office_dream.active_course.runner.config.course_id == "course_0", "Start intent falls asleep into the nightmare")
	# End the dream before quitting: tearing the tree down with a live course
	# crashes the headless teardown (test_dream_intro ends the same way).
	office_dream.active_course.runner._on_start(office_dream.player)
	await process_frame
	office_dream.active_course.runner._on_exit(office_dream.player)
	await create_timer(3.4).timeout
	_check(office_dream.active_course == null, "Dream hand-off office also wakes cleanly")
	office_dream.queue_free()
	await process_frame

	# --- 7. The real front door: boot_farm stamps the flag and hands off
	game.reset_run()
	game.pending_boot = ""
	var boot: Node = load("res://scenes/ui/boot_farm.tscn").instantiate()
	root.add_child(boot)
	await create_timer(1.0).timeout
	var cur: Node = current_scene
	_check(cur != null and cur.name == "FarmDemo", "The boot scene hands straight off to the level (no menu screen)")
	_check(game.tutorial_free_roam, "Booting the game lands in the pigpen tutorial")
	_check(not cur.in_start_menu, "No dimmed start menu at boot - the pen is playable immediately")

	print("\nALL OPENING SCENE TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
