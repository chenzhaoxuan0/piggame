extends SceneTree

# Woodland plunger combat: the pig's armory starts loaded, pickups resupply,
# Q fires with aim assist, patrol dogs take the knockdown, and three knockdowns
# mint the 马桶骑士 achievement.

var failures := 0
var game: Node
var am: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("PLUNGER_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _ev(action: String, pressed: bool = true) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _run() -> void:
	game = root.get_node("GameManager")
	am = root.get_node("AchievementManager")
	game.reset_run()
	game.choose_red()

	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.5).timeout
	office.start_game()
	await process_frame
	office.enter_secret_course("course_3")
	await create_timer(0.5).timeout

	var course = office.active_course
	_check(course != null, "Woodland course entered via secret pipe")
	if course == null:
		print("PLUNGER_TEST FINISHED: failures=%d" % failures)
		quit(1)
		return

	var launcher = course.plunger_launcher
	_check(launcher != null, "PlungerLauncher lives in the woodland course")
	if launcher == null:
		print("PLUNGER_TEST FINISHED: failures=%d" % failures)
		quit(1)
		return
	_check(launcher.ammo == 5, "The pocket starts with five rounds")

	# --- Teaching (2026-11-15 playtest #3): players pocketed plungers without
	# ever learning Q fires them. The counter panel now carries the hint.
	var counter_panel = root.find_child("PlungerCounter", true, false)
	_check(counter_panel != null, "Ammo counter panel exists")
	var hint_text := ""
	if counter_panel != null:
		for lbl in counter_panel.find_children("*", "Label", true, false):
			if "Q" in str(lbl.text):
				hint_text = str(lbl.text)
	_check(hint_text.contains("Q"), "Counter panel teaches the fire key (按 Q 发射)")

	# --- Reachability guard: 马桶骑士 needs 3 knockdowns, so the course must
	# keep offering at least 3 dog sources (zigzag patrol + maze patrol + the
	# runner's chasers). A config change that silently drops below this locks
	# the achievement - pin it.
	var dog_sources := 0
	if is_instance_valid(course.zigzag_dog): dog_sources += 1
	if is_instance_valid(course.patrol_dog): dog_sources += 1
	dog_sources += course.runner._dogs.size()
	_check(dog_sources >= launcher.ACHIEVEMENT_GOAL,
		"At least %d dog sources live in the woodland (马桶骑士 stays earnable)" % launcher.ACHIEVEMENT_GOAL)

	var pickups := []
	for child in course.get_children():
		if child is PlungerProp:
			pickups.append(child)
	_check(pickups.size() == 5, "Five resupply caches placed along the track")

	# 进场对话节拍：先锁住讲剧情；走共享快进接口放行后 Q 才能开火
	# （launcher.fire() 只在 explore/chase 模式下生效）。
	_check(course.runner.beat_active() and course.runner.active_beat_id() == "course_3_intro", "Intro dialogue beat shows on woodland entry")
	course.runner.skip_beats()
	await create_timer(0.15).timeout
	_check(not course.runner.beat_active() and office.player.control_mode != "cinematic", "Beat released the pig for the plunger drill")

	# --- 1. Real input fires: Q with the pig in explore mode
	var ammo_before: int = launcher.ammo
	_ev("action_shoot")
	for i in 6: await physics_frame
	_ev("action_shoot", false)
	await create_timer(0.1).timeout
	_check(launcher.ammo == ammo_before - 1, "Q consumes one round")
	_check(root.find_child("PlungerProjectile", true, false) != null or launcher.get_tree().root.find_child("PlungerProjectile", true, false) != null,
		"A plunger projectile took flight")
	await create_timer(0.6).timeout # flight lands before the next shot

	# --- 1b. Mouse fire (2026-11-15 follow-up): left click launches with
	# mouse-aim; the keyboard path keeps the pig-facing assist.
	var mouse_ammo: int = launcher.ammo
	Input.warp_mouse(Vector2(200, 300))
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await create_timer(0.1).timeout
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	Input.parse_input_event(click)
	_check(launcher.ammo == mouse_ammo - 1, "Left click fires too (mouse-aimed shot)")
	await create_timer(0.6).timeout
	launcher.add_ammo(1) # the extra range drill round, so the knockdown legs keep their budget

	# --- 2. Aim-assist hit: stand the pig next to a patrol dog facing it
	var dog = course.zigzag_dog
	_check(is_instance_valid(dog), "Zigzag patrol dog exists as a knockdown target")
	var pig = office.player
	pig.global_position = dog.global_position + Vector3(0.0, 0.1, 2.2)
	await physics_frame
	pig.look_at(dog.global_position + Vector3(0, 0.6, 0), Vector3.UP)
	await physics_frame
	launcher.fire()
	await create_timer(0.6).timeout
	_check(dog.is_stunned, "Plunger hit knocks the patrol dog down (stunned)")
	_check(launcher._knockdowns == 1, "Knockdown counter ticks")

	# The zigzag placement above can land the pig on the maze-entry beat
	# trigger band (its first patrol leg runs along it): the story card fires
	# there by design. Skip it so the drill's remaining shots are fired with a
	# movable pig - launcher.fire() only works in explore/chase.
	course.runner.skip_beats()
	await create_timer(0.15).timeout

	# --- 3. Two more knockdowns mint the achievement (aim assist correctly
	# skips already-stunned dogs, so each shot takes a fresh victim)
	var dog2 = course.patrol_dog
	_check(is_instance_valid(dog2) and not dog2.is_stunned, "Second patrol dog is up and targetable")
	pig.global_position = dog2.global_position + Vector3(0.0, 0.1, 2.2)
	pig.look_at(dog2.global_position + Vector3(0, 0.6, 0), Vector3.UP)
	launcher.fire()
	await create_timer(0.6).timeout
	_check(dog2.is_stunned, "Second patrol dog knocked down")
	_check(launcher._knockdowns == 2, "Two knockdowns before the chaser leg")
	# The rubber-band chaser wakes at the course start gate
	course.runner._on_start(pig)
	await process_frame
	var chaser = course.runner._dogs[0]
	_check(is_instance_valid(chaser) and chaser.active, "Runner chaser is active after the start gate")
	launcher.add_ammo(1) # pocket ran dry - resupply like a player would
	pig.global_position = chaser.global_position + Vector3(0.0, 0.1, 2.2)
	pig.look_at(chaser.global_position + Vector3(0, 0.6, 0), Vector3.UP)
	launcher.fire()
	await create_timer(0.6).timeout
	_check(str(chaser.phase) == "stun", "Runner chaser stunned by plunger (short escape stun)")
	_check(launcher._knockdowns == 3 and am.is_unlocked("plunger_knight"),
		"马桶骑士 unlocks at three knockdowns")

	# --- 3b. Repeat knockdown (2026-11-15 follow-up): patrol dogs recover and
	# can be floored again - targets are repeatable, not one-shot. The chasers
	# are parked first: an awake rubber-band dog shadows the pig through the
	# 5 s recovery wait and steals the aim assist (learned the hard way).
	course.runner.set_dogs_active(false)
	await create_timer(launcher.PATROL_STUN + 0.6).timeout
	_check(not dog.is_stunned, "Patrol dog recovers from the stun")
	launcher.add_ammo(1)
	pig.global_position = dog.global_position + Vector3(0.0, 0.1, 2.2)
	pig.look_at(dog.global_position + Vector3(0, 0.6, 0), Vector3.UP)
	await physics_frame
	launcher.fire()
	await create_timer(0.6).timeout
	_check(dog.is_stunned and launcher._knockdowns == 4,
		"Recovered patrol dog takes another knockdown (repeatable targets, 4 hits)")

	# --- 4. Pickup resupply + regrowth (repeatable pickups)
	launcher.add_ammo(0)
	var ammo_before_pickup: int = launcher.ammo
	var first_pickup = pickups[0] if pickups.size() > 0 else null
	if first_pickup != null:
		first_pickup.respawn_seconds = 0.3
		first_pickup._collect()
		await process_frame
	_check(launcher.ammo == ammo_before_pickup + 1, "A collected plunger adds one round")
	if first_pickup != null:
		await create_timer(0.6).timeout
		_check(not first_pickup._collected, "The pickup spot regrows its plunger (repeatable supply)")
		var regrown_visible := false
		for visual in first_pickup._visuals:
			if is_instance_valid(visual) and visual.visible:
				regrown_visible = true
		_check(regrown_visible, "Respawned plunger is visible again")

	# --- 5. Miss drops a reusable pickup at the landing spot
	pig.global_position = Vector3(0, 0.6, -30) # open meadow, away from the track dogs
	pig.look_at(pig.global_position + Vector3(0, 0, -1), Vector3.UP)
	var count_before := 0
	for child in root.get_children():
		if child is PlungerProp:
			count_before += 1
	launcher._drop_on_ground(launcher._build_plunger_visual(), Vector3(2.0, 0.3, -32))
	await process_frame
	var count_after := 0
	for child in root.get_children():
		if child is PlungerProp:
			count_after += 1
	_check(count_after == count_before + 1, "A missed plunger lands as a fresh pickup")

	# --- Cleanup: end the course so the tree teardown stays headless-safe
	course.runner._on_exit(office.player)
	await create_timer(1.0).timeout
	_check(office.active_course == null, "Course exits cleanly after the plunger drill")

	print("\nALL PLUNGER TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
