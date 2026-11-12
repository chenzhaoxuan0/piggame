extends SceneTree

const L = preload("res://scripts/levels/farm_layout.gd")

var office: Node
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_02_JOURNEY_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await process_frame

	game.choose_red()
	office.farm.set_pigpen_open(true)
	await process_frame

	# 1. Secret Creek Pipe at Ox Terrace
	_check(office.farm.has_node("SecretCreekPipe"), "Farm has SecretCreekPipe entrance")
	_check(office.farm.has_node("SecretCreekPipeExit"), "Farm has SecretCreekPipeExit at sheep meadow entrance")
	var pipe: Node3D = office.farm.get_node("SecretCreekPipe")
	_check(pipe.position.distance_to(Vector3(-27.0, 16.0, -15.0)) < 1.0, "Secret creek entrance at the creek-chase end, tucked off the roadside fence")
	_check(pipe.has_node("PipeBody") and pipe.has_node("PipeTopArea"), "Pipe has solid body and top detection area")

	# Pig standing on pipe rim
	var top_area := pipe.get_node("PipeTopArea") as Area3D
	top_area.body_entered.emit(office.player)
	_check(office.farm._player_on_pipe, "Pig standing on creek pipe rim detected")

	# Trigger descent into course_2
	office.farm._trigger_pipe_enter("course_2", pipe)
	await create_timer(0.5).timeout
	_check(is_instance_valid(office.active_course), "Secret pipe trigger loaded course_2")
	_check(office.farm.get_parent() == null, "Farm removed from tree during course")
	var runner: CourseRunner = office.active_course.runner
	_check(runner.config.course_id == "course_2", "Course 2 config wired")
	_check(runner._dogs.size() == 1, "Rubber-band dog spawned")

	# Grant Ox struggle skill
	game.complete_npc("ox")
	await process_frame
	_check(game.has_struggle_skill, "Struggle skill active")

	# 2. Start trigger
	runner._on_start(office.player)
	await process_frame
	_check(runner.started, "Course 2 started")
	_check(game.is_in_chase(), "Game entered chase stage on course start")
	_check(office.player.control_mode == "chase", "Player in chase mode during course")
	for dog in runner._dogs:
		dog.set_active(false)

	# 3. Checkpoint registration
	runner._on_checkpoint(office.player, 1, Vector3(0, 0.6, -50))
	_check(runner.last_checkpoint == Vector3(0, 0.6, -50), "Checkpoint registered as respawn point")

	# 4. Watchdog: fall below kill_y -> respawn at checkpoint (non-lethal)
	office.player.global_position = Vector3(0, -50, -50)
	for i in 5: await physics_frame
	_check(runner.respawn_count >= 1, "Watchdog respawned pig after falling out of bounds")
	_check(office.player.global_position.y > -12.0, "Pig respawned above kill_y (not dead)")

	# 4.1 Minecraft Voxel Mechanics
	var course = office.active_course
	_check(course.water_stream != null, "Course 2 has VoxelWaterStream")
	_check(course.dirt_block_1 != null and course.dirt_block_2 != null, "Course 2 has pushable dirt blocks")
	# Push dirt block 1 into stream
	course.dirt_block_1.push(Vector3(0, 0, -2.0))
	await create_timer(0.3).timeout
	course.water_stream._handle_block_drop(course.dirt_block_1)
	await create_timer(0.3).timeout
	_check(course.dirt_block_1.has_bridged, "Dirt block bridged the voxel water stream")

	# Bridge platform must span the stream in WORLD space: setting global_position
	# before add_child shifted it one stream-width downstream and left a 2m hole at
	# the near bank (z in [-2, 0]) that swallowed midline walkers.
	var bridge = course.water_stream.get_node_or_null("BridgePlatform")
	_check(bridge != null, "Bridge platform created after block drop")
	if bridge != null:
		_check(absf(bridge.global_position.z - course.water_stream.global_position.z) < 0.05, "Bridge centered on the stream, not offset downstream")
		var bridge_cols: Array = bridge.find_children("*", "CollisionShape3D", true, false)
		_check(not bridge_cols.is_empty(), "Bridge has a collision box")
		if not bridge_cols.is_empty():
			var bridge_box: BoxShape3D = bridge_cols[0].shape
			var half_z: float = bridge_box.size.z * 0.5
			_check(bridge.global_position.z - half_z <= course.water_stream.global_position.z - 2.4 and bridge.global_position.z + half_z >= course.water_stream.global_position.z + 2.4, "Bridge spans the full stream with overlap onto both banks")

	# Canyon throat: a real sentry plugs the gap until the sand buries it
	_check(course.sand_block != null and course.canyon_dog != null, "Course 2 has sand block and canyon dog")
	_check(course.canyon_dog.is_in_group("chase_dogs") and course.canyon_dog.has_node("GuardShape"), "Canyon guard is a solid body (plugs the throat)")
	_check(course.canyon_dog.collision_layer != 0, "Canyon guard blocks the passage while awake")
	_check(course.has_node("CanyonThroatRockW") and course.has_node("CanyonThroatRockE"), "Canyon throat is pinched by rock shoulders")
	_check(course.canyon_dog.global_position.distance_to(course.sand_block.global_position) > 4.0, "Sand spawns clear of the guard (the burial must be earned)")

	# The sand toboggans down the waterfall steps, then one east push buries him
	for i in 3:
		course.sand_block.push(Vector3(0, 0, -1.0))
		await create_timer(0.45).timeout
	course.sand_block.push(Vector3(1, 0, 0))
	await create_timer(0.45).timeout
	_check(course.canyon_dog_buried, "Sand push chain buried the canyon guard")
	_check(course.canyon_dog.get_node("DogLabel").text.contains("活埋"), "Buried guard label says so")
	_check(course.canyon_dog.is_stunned and course.canyon_dog.collision_layer == 0, "Buried guard stops blocking the throat")

	# TNT and Obsidian wall - the puzzle can no longer be skipped
	_check(course.obsidian_wall != null and course.pressure_plate != null, "Course 2 has obsidian wall and pressure plate")
	_check(course.obsidian_wall.wall_width >= 10.0, "Obsidian wall seals the full 10m canyon gap (no side squeeze)")
	_check((course.pressure_plate.collision_mask & 1) != 0, "Pressure plate can detect push blocks on layer 1")
	_check(absf(course.tnt_block.position.x) < 0.05, "TNT starts aligned with the pressure plate for straight pushes")
	_check(course.tnt_block.position.distance_to(course.pressure_plate.position) >= 5.5, "TNT spawns well clear of the plate (anti-bypass)")
	# Pig stepping on the plate with the TNT still on its spawn pad: nothing happens
	course.pressure_plate._on_body_entered(office.player)
	await create_timer(0.4).timeout
	_check(course.obsidian_wall != null and not course.obsidian_wall.is_demolished, "Pig on the plate alone does NOT detonate distant TNT (old 2.2 m bypass)")
	# Physically the pig was never on the plate, so nothing fired body_exited;
	# release it manually or the plate stays "pressed" and swallows the TNT step.
	course.pressure_plate._on_body_exited(office.player)
	# Three pushes land the TNT on the plate; the plate's own body_entered
	# catches it mid-push, ignites it, and the explosion pays an FX burst.
	for i in 3:
		course.tnt_block.push(Vector3(0, 0, -1.0))
		await create_timer(0.4).timeout
	var fx_seen := false
	for i in 12:
		await create_timer(0.1).timeout
		if is_instance_valid(course) and course.find_children("ExplosionFX", "Node3D", true, false).size() > 0:
			fx_seen = true
	_check(course.obsidian_wall == null or course.obsidian_wall.is_demolished, "TNT pushed onto the plate demolished the obsidian wall")
	_check(fx_seen, "TNT explosion pays an on-screen FX burst")
	_check(not is_instance_valid(course.tnt_block), "Ignited TNT is gone after the blast")

	# Sweet potatoes on the cliff stairs are real pickups now: one modest,
	# non-stacking, course-scoped boost (three used to stack to 2.2x and the
	# boost leaked into the farm via a wall-clock timer).
	var potato = course.get_node_or_null("SweetPotato2")
	var potato_base: float = office.player.move_speed
	_check(potato != null, "Cliff stairs have collectible sweet potatoes")
	if potato != null:
		potato._on_body_entered(office.player)
		_check(potato.is_collected, "Sweet potato collected on contact")
		_check(is_equal_approx(office.player.move_speed, potato_base * course.POTATO_SPEED_FACTOR), "Sweet potato grants its speed boost")
		var second_potato = course.get_node_or_null("SweetPotato3")
		if second_potato != null:
			second_potato._on_body_entered(office.player)
			_check(is_equal_approx(office.player.move_speed, potato_base * course.POTATO_SPEED_FACTOR), "A second potato refreshes the boost without stacking")

	# CliffRamp steps flush with HighCliff (no buried or embedded steps)
	var ramp = course.get_node_or_null("CliffRamp")
	_check(ramp != null, "Course 2 has CliffRamp")
	if ramp != null:
		var step7 = ramp.get_node_or_null("StepCol7")
		_check(step7 != null, "CliffRamp has step 7")
		if step7 != null:
			var top_y: float = ramp.position.y + step7.position.y + (step7.shape as BoxShape3D).size.y * 0.5
			_check(is_equal_approx(top_y, 3.0), "CliffRamp top step is flush at Y = 3.0 matching HighCliff")
			var step7_north_z: float = ramp.position.z + step7.position.z - (step7.shape as BoxShape3D).size.z * 0.5
			_check(step7_north_z <= -20.0, "CliffRamp step 7 meets HighCliff south face without embedded steps")

	# Waterfall slide steps must DESCEND along the travel direction (-Z): from the
	# cliff edge the pig meets the 3m step first, the 1m step last (each rise was
	# 1.0m > jump height 0.934m when reversed, stranding the pig mid-slide).
	var slide = course.get_node_or_null("WaterfallSlide")
	_check(slide != null, "Course 2 has waterfall slide")
	if slide != null:
		var step_tops: Array = []
		for step_col in slide.find_children("*", "CollisionShape3D", true, false):
			if step_col.get_parent() != slide:
				continue # skip the chute trigger box
			var step_box: BoxShape3D = step_col.shape
			step_tops.append([step_col.global_position.z, slide.global_position.y + step_col.position.y + step_box.size.y * 0.5])
		step_tops.sort()
		_check(step_tops.size() == 3, "Slide has three cascade steps")
		if step_tops.size() == 3:
			_check(step_tops[0][1] < step_tops[1][1] and step_tops[1][1] < step_tops[2][1], "Slide steps descend from cliff toward canyon")
			_check(is_equal_approx(step_tops[0][1], 1.0) and is_equal_approx(step_tops[2][1], 3.0), "Slide runs from Y=3 at the cliff down to Y=1 at the canyon")

	# 5. QTE struggle in course
	var test_dog: ChaseDog = runner._dogs[0]
	runner._on_dog_grapple(test_dog)
	await process_frame
	_check(office.in_qte and office.qte_panel.visible, "QTE panel triggered on course dog grapple")
	_check(office.player.control_mode == "qte", "Player locked into QTE mode")
	for i in office.QTE_TARGET_HITS:
		office._on_qte_tapped()
		await process_frame
	_check(not office.in_qte, "QTE resolved after rapid taps")
	_check(test_dog.phase == "stun", "Dog stunned after successful struggle")
	_check(office.player.control_mode == "chase", "Player restored to chase mode")

	# 6. QTE failure is slapstick knockback
	runner._on_dog_grapple(test_dog)
	await process_frame
	if office.in_qte:
		office._finish_qte(false)
		await process_frame
	_check(game.stage != "ending", "QTE failure does not end the run (non-lethal)")
	_check(office.player.is_knocked_back() or office.player.control_mode == "chase", "QTE failure knocks pig back and resumes")

	# 7. Reach exit -> course complete, farm restored, drops at Sheep meadow entrance
	var memes_played: Array = []
	course.meme_layer.meme_played.connect(func(id): memes_played.append(id))
	runner._on_exit(office.player)
	await process_frame
	_check(memes_played.has("portal_enter"), "Crossing the exit plays the nether-portal toast (defined but never played before)")
	_check(game.chase_completed.get("chase_2", false), "chase_2 marked complete via course exit")
	_check(office.active_course == null, "Course scene unloaded")
	_check(office.farm.get_parent() == office, "Farm restored to tree")
	_check(game.stage == "exploring", "Returned to exploring stage")
	_check(office.player.global_position.distance_to(Vector3(-44.0, 16.1, -37.0)) < 1.5, "Pig emerged deep inside the sheep meadow (far from the hidden entrance)")
	_check(office.player.global_position.distance_to(L.GATE_SHEEP) > 10.0, "Exit drop keeps clear distance from the Sheep gate")
	_check(office.player.global_position.distance_to(Vector3(-27.0, 16.0, -15.0)) > 20.0, "Exit drop is far from the creek pipe entrance")
	_check(is_equal_approx(office.player.move_speed, potato_base), "Potato boost is settled at course exit, not carried into the farm")

	print("\nALL COURSE 02 JOURNEY TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
