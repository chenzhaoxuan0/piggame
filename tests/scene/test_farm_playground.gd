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
	_check(get_nodes_in_group("interactable").size() == 8, "Playground props stay out of the story interactables (5 NPCs + record board + cablecar + pigpen trough)")

	# --- Cabbage kick: contact hops the ball away from the pig
	var ball: Node3D = farm.get_node("CabbageBall")
	var ball_home: Vector3 = ball.global_position
	pig.global_position = ball_home + Vector3(0, 0.6, 0.8)
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

	# --- The cabbage field: the goal-side beds grow planted cabbages that
	# harvest into free balls on the kick, score in the same net, and stay
	# free FOREVER for the session - the meteor is the only restock.
	var plots: Array = farm.find_children("PlotCabbage*", "", true, false)
	_check(plots.size() == 12, "Twelve plot cabbages grow beside the goal")
	var all_planted := true
	for plot in plots:
		if not (plot is RigidBody3D and plot.freeze and plot.global_position.x > 52.0):
			all_planted = false
	_check(all_planted, "Planted cabbages are frozen rigid bodies in the beds east of the pitch")
	_check(plots[0].collision_mask == 1, "Plot cabbages ignore the ball-only fences (their road to the goal crosses the east board)")
	var plot: RigidBody3D = plots[0]
	var plot_home: Vector3 = plot.global_position
	pig.global_position = plot_home + Vector3(0, 0.6, 0.8)
	pig.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await create_timer(0.5).timeout
	_check(not plot.freeze and plot.global_position.distance_to(plot_home) > 0.4,
		"Kicking a planted cabbage harvests it into a free ball")
	var goal_events: Array = [] # lambdas capture locals by value; a reference type carries the signal out
	farm.playground_event.connect(func(kind: String, _detail):
		if kind == "cabbage_goal":
			goal_events.append(kind)
	)
	farm._cabbage_goal_cool = 0.0 # the pitch ball scored moments ago; clear the 5s goal cooldown
	plot.global_position = farm.get_node("CabbageGoal").global_position + Vector3(0, 0.8, 0)
	plot.linear_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await create_timer(0.3).timeout
	_check(goal_events.size() > 0, "A harvested field cabbage scores in the same goal")
	# Permanence: the 20 s auto-replant is gone for good - a freed cabbage
	# never walks home by itself anymore, wherever the pig kicked it.
	_check(not farm.has_method("_replant_plot_cabbages"), "The 20 s auto-replant is gone for good")
	_check(not plot.freeze, "A harvested cabbage stays free - no snap-home timer")
	# The meteor impact path is the one restock left. Assert the synchronous
	# snap: a pig standing in the beds would legitimately harvest the refrozen
	# cabbage a frame later (that is the game, not a bug), so no frame passes
	# between the reset call and the state check.
	farm._reset_pen_props()
	_check(plot.freeze and plot.global_position.distance_to(plot_home) < 0.1,
		"The meteor reset is the one restock path back into the bed")

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
	var gag_notices: Array[String] = []
	farm.playground_event.connect(func(kind, detail):
		nest_events.append(kind)
		if kind == "gag":
			gag_notices.append(str(detail)))
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
	_check(gag_notices.size() >= 4, "Every nest gag also reports a gag notice for the corner feed")
	_check(gag_notices.any(func(t: String): return "拱出一枚蛋" in t), "Gag notice carries the actual line text")
	_check(office.get("notice_feed") != null and office.notice_feed is VBoxContainer,
		"The HUD owns a bottom-right notice feed")
	_check(office.notice_feed.get_child_count() >= 1,
		"Gag notices actually spawned corner cards in the HUD feed")

	# --- Potato mounds: five nose-digs in the furrow field
	_check(not am.is_unlocked("potato_harvest"), "Harvest locked before digging")
	for mound in farm.find_children("PotatoMound*", "", true, false):
		pig.global_position = mound.global_position + Vector3(0, 0.4, 0.2)
		await physics_frame
		await physics_frame
		await create_timer(0.2).timeout
	_check(am.is_unlocked("potato_harvest"), "Digging all five mounds unlocks 春耕的馈赠")

	# --- Apple tree: charged shake rains apples, walking over them eats all three
	_check(not am.is_unlocked("apple_rain"), "Apple rain locked before the shake")
	var tree: Node3D = farm.get_node("AppleTree")
	pig.global_position = tree.global_position + Vector3(0, 0.6, 1.4)
	pig.dodge_timer = 0.35
	await physics_frame
	await physics_frame
	pig.global_position += Vector3(0, 0.6, 5.0) # step clear: an apple landing on the pig gets eaten instantly
	await create_timer(0.7).timeout # let the apples land
	var apples: Array = tree.find_children("ApplePickup*", "", true, false)
	_check(apples.size() == 3, "The shake rains exactly three apples")
	for apple in apples:
		# An apple that landed on the standing pig was auto-eaten and queued
		# for deletion - it can appear in the array yet be gone by our turn.
		if not is_instance_valid(apple) or apple.is_queued_for_deletion():
			continue
		pig.global_position = apple.global_position + Vector3(0, 0.3, 0.1)
		await physics_frame
		await physics_frame
		await create_timer(0.3).timeout
	_check(am.is_unlocked("apple_rain"), "Eating all three apples unlocks 牛顿的苹果")

	# --- Cabbage physics: real rigid bodies, spin from the strike, full stop
	_check(farm.get_node("CabbageBall") is RigidBody3D and farm.get_node("PenCabbageBall") is RigidBody3D,
		"Both cabbage balls are real rigid bodies")
	var phys_ball := farm.get_node("CabbageBall") as RigidBody3D
	_check(phys_ball.physics_material_override != null and phys_ball.physics_material_override.bounce > 0.0,
		"The ball carries a bouncy physics material")
	# Light football contract: a heavy/high-damp ball reads as glued to the turf
	# (the old mass 0.9 + linear_damp 0.7 killed every punt within a metre).
	_check(phys_ball.mass <= 0.5, "The ball is light enough to punt around freely (mass <= 0.5)")
	_check(phys_ball.linear_damp < 0.5, "The ball rolls out instead of sinking into the turf (low linear damp)")
	_check(farm.get_node_or_null("PenBallFence") != null, "The pen gate gap has a ball-only fence")
	for fence_name in ["PitchBallFenceN", "PitchBallFenceS", "PitchBallFenceW", "PitchBallFenceE"]:
		_check(farm.get_node_or_null(fence_name) != null, "%s keeps the pitch ball on the pitch" % fence_name)
	phys_ball.sleeping = false
	phys_ball.apply_impulse(Vector3(2.2, 0.9, 0.0), Vector3(0.0, -0.24, 0.0)) # off-centre hoof strike
	await physics_frame
	await physics_frame
	_check(phys_ball.linear_velocity.length() > 1.0, "The impulse produces linear velocity")
	_check(phys_ball.angular_velocity.length() > 1.0, "The off-centre strike produces spin (it rolls, not slides)")
	# A runaway punt at the east board bounces back and stays in the pitch
	phys_ball.sleeping = false
	phys_ball.linear_velocity = Vector3(8.0, 0.5, 0.0)
	await create_timer(1.2).timeout
	_check(phys_ball.global_position.x < 52.6, "The invisible east board bounces a runaway punt back")
	for settle_i in 40:
		if phys_ball.sleeping or phys_ball.linear_velocity.length() < 0.05:
			break
		await create_timer(0.25).timeout
	_check(phys_ball.sleeping or phys_ball.linear_velocity.length() < 0.06,
		"The punt rolls out and the ball settles to rest")

	# --- Pen haystack: solid to land on, diveable, squashes under the pig
	var pen_hay: Node3D = farm.get_node("PenHaystack")
	_check(pen_hay is StaticBody3D and pen_hay.get_node_or_null("CollisionShape3D") != null,
		"The pen haystack has a real collider (the pig lands on it, not through it)")
	_check(farm.get_node("HayDiveStack") is StaticBody3D, "The west-zigzag hay dive stack is solid too")
	var dive_events := []
	farm.playground_event.connect(func(kind, _detail):
		if kind == "dive" or kind == "perfect_dive":
			dive_events.append(kind))
	# The teleport keeps the pig flagged on-floor for one frame, which wipes the
	# assigned -8 vy - the dive comes from a gravity fall instead (~0.28 s to
	# reach the sense box, entering at vy ~ -5), so sample well past that.
	pig.global_position = pen_hay.global_position + Vector3(0, 2.0, 0)
	pig.velocity = Vector3(0, -8.0, 0)
	await physics_frame
	await physics_frame
	await create_timer(0.45).timeout # dive fires on area entry; squash is 0.1 s deep
	_check(dive_events.size() >= 1, "Falling onto the pen haystack triggers the dive (playground_event)")
	_check(pen_hay.scale.y < 1.0, "The stack compresses under the landing pig")
	await create_timer(1.0).timeout
	_check(is_equal_approx(pen_hay.scale.y, 1.0), "The squashed stack springs back")
	_check(pig.global_position.y > pen_hay.global_position.y + 0.3, "The pig ends up standing on top of the stack")

	# --- White-box regression net: every playground prop wears its Lux3D model.
	# The flat boxes stay as collision only; a prop that fell back to its box
	# (missing asset) shows up here as a failure.
	for mounted in [
		["CabbageBall", "CabbageLux"], ["PenCabbageBall", "CabbageLux"],
		["PenBucket", "BucketLux"], ["PenHaystack", "HaystackLux"],
		["HayDiveStack", "HaystackLux"], ["MeteorButton", "ButtonLux"],
		["Barrel_Zigzag", "BarrelLux"], ["Wheelbarrow_Meadow", "WheelbarrowLux"],
		["WoolBale_Meadow", "WoolBaleLux"], ["Barrel_Track", "BarrelLux"],
		["Beehive", "BeehiveLux"], ["MailboxPost", "MailboxLux"],
		["BroadcastHorn", "HornLux"], ["HenNest", "HenNestLux"],
		["AppleTree", "AppleTreeLux"], ["Scarecrow_Field", "ScarecrowLux"],
		["TrailSignPost", "TrailSignLux"], ["PotatoMound0", "MoundLux"],
		["Hurdle_Creek_Side", "HurdleLux"], ["CablecarLever", "LeverLux"],
	]:
		var lux: Node = farm.get_node(mounted[0]).get_node_or_null(mounted[1])
		_check(lux != null and lux.visible and lux.get_meta("source", "") == "Aholo Lux3D",
			"%s wears its Lux3D model (%s)" % [mounted[0], mounted[1]])

	# --- Meteor button: repeatable; each press fully resets the pen
	var pen_ball: RigidBody3D = farm.get_node("PenCabbageBall")
	var pen_ball_home: Vector3 = pen_ball.global_position
	var pen_bucket: Node3D = farm.get_node("PenBucket")
	var bucket_home_basis: Basis = pen_bucket.basis
	var meteor_button: Node3D = farm.get_node("MeteorButton")
	for cycle in 3:
		# Wreck the pen: punt the cabbage off home and topple the bucket.
		pen_ball.sleeping = false
		pen_ball.linear_velocity = Vector3(2.4, 1.0, -1.6)
		pig.global_position = pen_bucket.global_position + Vector3(0, 0.6, 0.8)
		pig.velocity = Vector3.ZERO
		await physics_frame
		await physics_frame
		await create_timer(0.55).timeout
		_check(pen_ball.global_position.distance_to(pen_ball_home) > 0.3,
			"Cycle %d wrecked: the pen cabbage is away from home" % (cycle + 1))
		_check(not pen_bucket.basis.is_equal_approx(bucket_home_basis),
			"Cycle %d wrecked: the bucket is toppled" % (cycle + 1))
		# Hoof on the red button.
		pig.global_position = meteor_button.global_position + Vector3(0, 0.4, 0)
		pig.velocity = Vector3.ZERO
		await physics_frame
		await physics_frame
		await create_timer(0.3).timeout
		_check(farm._meteor_falling, "Cycle %d: the button summons the meteor" % (cycle + 1))
		if cycle == 0:
			# A stomp mid-fall must not spawn a second rock.
			farm._launch_meteor_reset()
			_check(farm.find_children("Meteor*", "MeshInstance3D", false, false).size() == 1,
				"No second meteor while one is already falling")
		await create_timer(2.1).timeout # 1.1 s fall + impact + re-arm margin
		_check(not farm._meteor_falling and farm.get_node_or_null("Meteor") == null,
			"Cycle %d: the meteor lands, cleans up and the flag re-arms" % (cycle + 1))
		_check(pen_ball.global_position.distance_to(pen_ball_home) < 0.1,
			"Cycle %d: impact resets the pen cabbage home" % (cycle + 1))
		_check(pen_bucket.basis.is_equal_approx(bucket_home_basis),
			"Cycle %d: impact stands the bucket back up" % (cycle + 1))

	am.reset_progress(true)
	print("\nALL FARM PLAYGROUND TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
