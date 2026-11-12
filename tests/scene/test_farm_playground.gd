extends SceneTree

# Farm playground guard: the ten body-driven easter eggs (cabbage pitch,
# shoveable log, tippables, nibble grass, hay dive, beehive buff...) react
# through the plaything areas, count toward their achievements, and never
# leak into the story interactable group.

const L = preload("res://scripts/levels/farm_layout.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	print("FARM_PLAYGROUND_TEST %s: %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1

func _run() -> void:
	var am: Node = root.get_node("AchievementManager")
	am.save_path = "user://achievements_playground_test.json"
	am.reset_progress(true)

	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await physics_frame
	var farm: Node = office.farm
	var pig: Node = office.player

	# --- The pitch exists and the interactable group stays at seven
	_check(farm.get_node_or_null("CabbageBall") != null and farm.get_node_or_null("CabbageGoal") != null,
		"Cabbage pitch is built (ball + goal)")
	_check(farm.get_node_or_null("Log_Summit_1") != null, "Summit log obstacle exists")
	_check(get_nodes_in_group("interactable").size() == 7, "Playground props stay out of the story interactables")

	# --- Cabbage kick: contact hops the ball away from the pig
	var ball: Node3D = farm.get_node("CabbageBall")
	var ball_home: Vector3 = ball.global_position
	pig.global_position = ball_home + Vector3(0, 0.6, 1.0)
	pig.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await create_timer(0.5).timeout # the kick tween moves the ball after ~0.12s
	_check(ball.global_position.distance_to(ball_home) > 0.4, "Touching the cabbage kicks it away")

	# --- Scoring: the ball entering the goal mouth fires the achievement
	_check(not am.is_unlocked("cabbage_striker"), "Striker achievement locked before the goal")
	ball.global_position = farm.get_node("CabbageGoal").global_position + Vector3(0, 0.8, 0)
	await physics_frame
	await physics_frame
	await create_timer(0.3).timeout
	_check(am.is_unlocked("cabbage_striker"), "Ball in the net unlocks 卷心菜前锋")

	# --- Log shove: a sprinting pig opens the second path
	_check(not am.is_unlocked("second_path"), "Second-path achievement locked before the shove")
	var log: Node3D = farm.get_node("Log_Summit_1")
	var log_pos: Vector3 = log.global_position
	pig.global_position = log_pos + Vector3(0, 0.6, 1.6)
	pig.dodge_timer = 0.35 # survives pig physics (is_sprinting gets recomputed)
	await physics_frame
	await physics_frame
	await create_timer(0.2).timeout
	_check(am.is_unlocked("second_path"), "Sprinting into the log unlocks 第二条路")
	_check(log.collision_layer == 0, "Shoved log stops blocking the road")

	# --- Tippables: five sprint knocks unlock the demolition crew
	_check(not am.is_unlocked("demolition_crew"), "Demolition locked before the rampage")
	for name_ in ["Barrel_Zigzag", "Wheelbarrow_Meadow", "WoolBale_Meadow", "Barrel_Track", "Scarecrow_Field"]:
		var prop: Node3D = farm.get_node(name_)
		pig.global_position = prop.global_position + Vector3(0, 0.6, 0.9)
		pig.dodge_timer = 0.35
		await physics_frame
		await physics_frame
		await create_timer(0.25).timeout
	_check(am.is_unlocked("demolition_crew"), "Toppling all five props unlocks 拆家小队")

	# --- Grass: six tufts nibbled
	_check(not am.is_unlocked("grass_gourmet"), "Gourmet locked before grazing")
	for tuft in farm.find_children("NibbleGrass*", "", true, false):
		pig.global_position = tuft.global_position + Vector3(0, 0.4, 0.2)
		await physics_frame
		await physics_frame
		await create_timer(0.2).timeout
	_check(am.is_unlocked("grass_gourmet"), "Nibbling all six tufts unlocks 食草动物的本分")

	# --- Hay dive: falling into the stack scores; a 10 lands the achievement
	var hay: Node3D = farm.get_node("HayDiveStack")
	_check(not am.is_unlocked("perfect_dive"), "Perfect dive locked before jumping")
	pig.global_position = hay.global_position + Vector3(0, 2.2, 0)
	pig.velocity = Vector3(0, -8.0, 0)
	await physics_frame
	await physics_frame
	await create_timer(0.3).timeout
	# The score is random - force the ace by replanting until it lands 10.0.
	for attempt in 40:
		if am.is_unlocked("perfect_dive"):
			break
		var thing: Node = hay.get_node("Plaything")
		thing._cool_timer = 0.0
		pig.global_position = hay.global_position + Vector3(0, 1.6, 0)
		pig.velocity = Vector3(0, -8.0, 0)
		await physics_frame
		await physics_frame
		await create_timer(0.25).timeout
	_check(am.is_unlocked("perfect_dive"), "A 10.0 hay dive unlocks 满分入坑")

	# --- Beehive: the sting buff speeds the pig up and wears off
	var hive: Node3D = farm.get_node("Beehive")
	var base_speed: float = pig.move_speed
	pig.global_position = hive.global_position + Vector3(0, 0.4, 1.0)
	await physics_frame
	await physics_frame
	await create_timer(0.1).timeout
	_check(pig.move_speed > base_speed, "Bee sting speeds the pig up")
	await create_timer(3.4).timeout
	_check(is_equal_approx(pig.move_speed, base_speed), "The sting buff wears off after 3 seconds")

	# --- Nest: three eggs then the chick finale
	var nest_events := []
	farm.playground_event.connect(func(kind, detail): nest_events.append(kind))
	# body_entered needs re-entry per nudge: step out, then back in.
	for i in 4:
		pig.global_position = farm.get_node("HenNest").global_position + Vector3(0, 0.4, 2.2)
		await physics_frame
		await create_timer(1.3).timeout # per-nest cooldown
		pig.global_position = farm.get_node("HenNest").global_position + Vector3(0, 0.4, 0.3)
		await physics_frame
		await physics_frame
	await create_timer(0.2).timeout
	_check(nest_events.has("chick"), "Fourth nest nudge pops the chick")

	am.reset_progress(true)
	print("\nALL FARM PLAYGROUND TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
