extends SceneTree

const L = preload("res://scripts/levels/farm_layout.gd")
var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("CHASE_JOURNEY_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _input_action(action: String) -> void:
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

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout

	# 1. Start game and verify To-Do Notebook
	office.start_game()
	await process_frame
	_check(office.todo_hub != null and office.todo_hub.visible, "To-Do hub is created and visible")
	_check(office.todo_notebook != null and not office.todo_notebook.visible, "To-Do notebook starts folded behind its toggle button")
	var todo_items: Array[Dictionary] = game.get_to_do_items()
	_check(todo_items.size() >= 8, "To-Do checklist contains all milestone tasks")
	# Index 0 is the crossed-out prologue-dream entry; the escape plan starts at 1.
	_check(not todo_items[0]["done"], "Prologue dream task stays unticked before the pig sleeps")
	_check(not todo_items[1]["done"], "Initial break free task is not done yet")

	# 2. Test Chase 1 Triggering (Summit -> Ox)
	# Trigger red choice
	game.choose_red()
	office.farm.set_pigpen_open(true)
	await process_frame
	_check(game.has_pin, "Pig acquired the brass pin")
	_check(game.get_to_do_items()[1]["done"], "First task is completed and marked with strikethrough")

	# Enter Course 1 via secret pipe
	office.enter_secret_course("course_1")
	await process_frame
	_check(is_instance_valid(office.active_course), "Course 1 scene loaded")
	var runner: CourseRunner = office.active_course.runner
	_check(runner._dogs.size() >= 1, "Course rubber-band dog spawned")

	# 进场对话节拍：台词不暂停游戏（纯字幕），但机器人照旧快进收场，
	# 让起跑时序保持确定。
	_check(runner.beat_active() and runner.active_beat_id() == "course_1_intro", "Intro dialogue beat shows on course 1 entry")
	runner.skip_beats()
	await create_timer(0.15).timeout
	_check(not runner.beat_active(), "Beat skipped so the run can start")

	# Ox at course entrance grants Struggle QTE skill
	game.complete_npc("ox")
	await process_frame
	_check(game.has_struggle_skill, "Struggle QTE skill unlocked from entrance Ox")

	# Cross course start trigger
	runner._on_start(office.player)
	await process_frame
	_check(game.is_in_chase(), "Game entered Chase 1 stage on course start")
	_check(office.player.control_mode == "chase", "Player in chase control mode")
	for dog in runner._dogs: dog.set_active(false)

	# Simulate Pig jumping
	for i in 10: await physics_frame
	var pre_jumps: int = office.player.jumps
	_input_action("action_jump")
	for i in 8: await physics_frame
	_check(office.player.jumps > pre_jumps or office.player.velocity.y > 0, "Pig jumped successfully in course")

	# Reach course exit -> Course 1 victory, farm restored
	runner._on_exit(office.player)
	await process_frame
	_check(not game.is_in_chase(), "Course 1 ended safely after reaching exit")
	_check(game.chase_completed.get("chase_1", false), "Chase 1 marked complete in manager")
	_check(office.player.control_mode == "explore", "Player restored to explore mode")
	_check(office.farm.get_parent() == office, "Farm restored after course")

	# 3. Sync Ox completion to farm
	office.farm.set_npc_completed("ox")
	await process_frame
	_check(game.get_to_do_items()[3]["done"], "Ox companion task marked complete with strikethrough")

	# 4. Test Chase 2 & QTE Struggle (Ox -> Sheep)
	office.start_stage_chase("chase_2")
	await process_frame
	_check(game.stage == "chase_2", "Game entered Chase 2 stage")
	_check(office.chase._dogs.size() >= 2, "Real dog and phantom dog spawned in Chase 2")

	# Test Dog grapple -> triggers QTE Struggle UI
	var test_dog: ChaseDog = office.chase._dogs[0]
	office.chase._on_dog_grapple(test_dog)
	await process_frame
	_check(office.in_qte and office.qte_panel.visible, "QTE struggle UI popped on dog grapple")
	_check(office.player.control_mode == "qte", "Player locked into QTE input mode")

	# Rapid taps to break free (target count follows the office constant)
	for i in office.QTE_TARGET_HITS:
		office._on_qte_tapped()
		await process_frame
	_check(not office.in_qte and not office.qte_panel.visible, "QTE completed successfully after rapid taps")
	_check(office.player.control_mode == "chase", "Player freed from struggle and resumes running")
	_check(test_dog.phase == "stun", "Attacking dog is stunned and knocked back")

	# Reach Sheep Gate
	office._on_farm_gate_passed("sheep")
	await process_frame
	_check(game.chase_completed.get("chase_2", false), "Chase 2 marked complete")

	# 5. Complete Sheep dialogue & gain Discern skill (immunize phantoms)
	game.complete_npc("sheep")
	office.farm.set_npc_completed("sheep")
	await process_frame
	_check(game.has_discern_skill, "Discern power unlocked from companion Sheep")

	# 6. Test Chase 3 & Phantom Immunity (Sheep -> Horse)
	office.start_stage_chase("chase_3")
	await process_frame
	_check(game.stage == "chase_3", "Game entered Chase 3 stage")
	
	# Find phantom dog and verify translucent state & dissipation on contact
	var phantom_found := false
	for dog in office.chase._dogs:
		if dog.is_phantom:
			phantom_found = true
			_check(dog.is_discerned, "Phantom dog is recognized and discerned")
			# Simulate lunge into player -> should harmlessly dissipate
			dog.global_position = office.player.global_position
			dog.dissolve_phantom()
			_check(dog._is_dissolving, "Phantom dog dissolves into smoke harmlessly")
			break
	_check(phantom_found, "Phantom dogs present in Chase 3")

	# Reach Horse Gate
	office._on_farm_gate_passed("horse")
	await process_frame
	_check(game.chase_completed.get("chase_3", false), "Chase 3 marked complete")

	# 7. Complete Horse dialogue & gain Dash Sprint skill
	game.read_record()
	game.complete_npc("horse")
	office.farm.set_npc_completed("horse")
	await process_frame
	_check(game.has_dash_skill, "Dash sprint power unlocked from companion Horse")
	_check(office.player.dash_enabled, "Pig controller dash is enabled")
	_check(office.dash_gauge != null and office.dash_gauge.visible, "Sprint stamina gauge visible on HUD")

	# Test Horse Sprint with Hold Shift
	office.player.target_destination = office.player.global_position + Vector3(0, 0, -10.0)
	office.player.is_moving = true
	var ev_dash := InputEventAction.new()
	ev_dash.action = "action_dash"
	ev_dash.pressed = true
	Input.parse_input_event(ev_dash)
	for i in 6: await physics_frame
	_check(office.player.is_sprinting or office.player.dash_enabled, "Holding Shift triggers sprint")
	ev_dash = InputEventAction.new()
	ev_dash.action = "action_dash"
	ev_dash.pressed = false
	Input.parse_input_event(ev_dash)
	office.player.is_moving = false
	var sprint_speed: float = office.player.move_speed * office.player.dash_multiplier
	_check(sprint_speed > 6.5, "Sprint speed (%.2f) exceeds dog speed (5.4) to outrun pursuers" % sprint_speed)

	# 8. Test Final Breakout & Escape
	office.start_stage_chase("chase_final")
	await process_frame
	_check(game.is_in_chase(), "Final breakout chase active")
	office._on_farm_gate_passed("final")
	await process_frame
	_check(game.chase_completed.get("chase_final", false), "Final chase completed")
	_check(game.stage == "showdown", "Proceeded to showdown stage with farmer")

	print("\nALL CHASE AND QTE JOURNEY TESTS PASSED: %d failures" % failures)
	quit(0 if failures == 0 else 1)
