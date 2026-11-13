extends SceneTree

# Opening boot menu + pigpen tutorial guard: the boot menu is a plain menu
# over a sky (the floating key-test pen is gone - it had no fall rescue, the
# 架空层 bug), and the "farm" boot drops the pig into its REAL pigpen in a
# pre-game tutorial sandbox: keys work, trough snorts, NPCs won't talk, the
# pen gate stays bolted, and F on the goat starts the day.

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
		var wrong_btn: Button = _quiz_button(quiz, "好玩")
		var right_btn: Button = _quiz_button(quiz, "不")
		if wrong_btn != null and right_btn != null:
			wrong_btn.pressed.emit()
			await process_frame
			_check(office.find_child("BrainHoleQuiz", true, false) != null, "Answering 好玩 is rejected - the quiz stays")
			_check(office.player.control_mode == "locked", "The pig stays locked after a wrong answer")
			_check("不" in office._brain_hint.text, "The hint tells the pig only 「不」 passes")
		# Park the quiz unanswered so the goat-flow section below still has its sandbox;
		# the accept-into-dream path is exercised end-to-end by the dream-boot section.
		office._quiz_next = ""
		quiz.queue_free()
		await process_frame
		office.player.set_control_mode("explore")
	_check(office.find_child("BrainHoleQuiz", true, false) == null, "The parked quiz is gone")
	_check(office.player.control_mode == "explore", "Pig roams again")
	_check(office.find_child("TitleCard", true, false) != null, "The boot title card (开始游戏 etc.) stays over the pen during the tutorial")
	var notebook: Control = office.find_child("TodoNotebook", true, false)
	if tcard != null and notebook != null:
		_check(absf(tcard.get_global_rect().position.y - notebook.get_global_rect().position.y) < 6.0,
			"Title card top edge aligns with the to-do notebook top edge") # the notebook's pop-in scale gives it a ~4px top offset
	if notebook != null:
		await process_frame # let the auto-height layout settle before measuring
		var nb_rect := notebook.get_global_rect()
		_check(nb_rect.size.x > 300.0, "To-do notebook keeps its ~330px width (no corner sliver)")
		_check(nb_rect.size.y > 60.0 and nb_rect.size.y < 260.0,
			"To-do notebook height fits its entries (auto-height, capped)")
	_check(office.player.dash_enabled and office.player.force_dodge_available, "Shift sprint and dodge are armed for the sandbox")
	var spawn_dist: float = office.player.global_position.distance_to(office.farm.get_spawn_position())
	_check(spawn_dist < 1.0, "Pig wakes at the real pigpen spawn")
	var strip: Control = office.find_child("KeyTestStrip", true, false)
	_check(strip != null and strip.visible, "Key-test strip lives in the farm HUD during the tutorial")
	if strip != null:
		await process_frame
		var viewport_rect := Rect2(Vector2.ZERO, strip.get_viewport_rect().size)
		_check(viewport_rect.encloses(strip.get_global_rect()), "Key-test strip fully inside the viewport")
	var pigpen_gate: StaticBody3D = office.farm._pigpen_gate
	_check(pigpen_gate.collision_layer == 1, "Pen gate stays bolted during the tutorial")

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

	# --- 5. F on the goat starts the day: tutorial ends, story dialogue opens
	office.player.global_position = goat.global_position + Vector3(1.2, 0.1, 0.8)
	await physics_frame
	office.player._try_interact(goat)
	await process_frame
	_check(not game.tutorial_free_roam, "Goat interaction ends the tutorial sandbox")
	_check(office.find_child("TitleCard", true, false) == null, "Title card leaves with the tutorial sandbox")
	_check(office.dialogue_open, "Goat interaction opens the story dialogue")
	_check(not office.player.dash_enabled, "Dash returns to story gating after the sandbox")
	_check(not office.player.force_dodge_available, "Free dodge disarms after the sandbox")
	_check(not strip.visible, "Key strip hides once the game starts")
	_check(pigpen_gate.collision_layer == 1, "Gate is still bolted - the red/blue choice opens it, not the sandbox")
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
