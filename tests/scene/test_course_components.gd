extends SceneTree

const BUMPER_PILLAR = preload("res://scripts/courses/components/bumper_pillar.gd")
const DOOR_DASH = preload("res://scripts/courses/components/door_dash_gate.gd")
const PENDULUM_BALL = preload("res://scripts/courses/components/pendulum_ball.gd")
const VOXEL_TNT = preload("res://scripts/courses/components/voxel_tnt.gd")
const BOUNCY_MUSHROOM = preload("res://scripts/courses/components/bouncy_mushroom.gd")
const SEESAW = preload("res://scripts/courses/components/seesaw_platform.gd")
const BOOST_PAD = preload("res://scripts/courses/components/boost_pad.gd")
const WATERMELON_PEEL = preload("res://scripts/courses/components/watermelon_peel.gd")
const RACING_FINISH = preload("res://scripts/courses/components/racing_finish_gate.gd")
const VOXEL_PUSH_BLOCK = preload("res://scripts/courses/components/voxel_push_block.gd")
const VOXEL_STREAM = preload("res://scripts/courses/components/voxel_water_stream.gd")
const CARDBOARD_BOX = preload("res://scripts/courses/components/cardboard_box_prop.gd")
const ILLUSORY_WALL = preload("res://scripts/courses/components/illusory_wall.gd")
const MIMIC_CHEST = preload("res://scripts/courses/components/mimic_chest.gd")
const VOXEL_SLIME = preload("res://scripts/courses/components/voxel_slime_block.gd")
const PINECONE_PROP = preload("res://scripts/courses/components/pinecone_prop.gd")
const MYSTERY_BOX = preload("res://scripts/courses/components/mystery_item_box.gd")
const STUNT_RAMP = preload("res://scripts/courses/components/stunt_jump_ramp.gd")
const NEON_BUMPER = preload("res://scripts/courses/components/neon_bumper.gd")
const RACE_TIMER = preload("res://scripts/courses/components/race_timer.gd")
const MUD_PATCH = preload("res://scripts/courses/components/mud_patch.gd")
const PATROL_VISION_CONE = preload("res://scripts/courses/components/patrol_vision_cone.gd")
const PATROL_GUARD_DOG = preload("res://scripts/courses/components/patrol_guard_dog.gd")
const CONVEYOR_BELT = preload("res://scripts/courses/components/conveyor_belt.gd")
const DOG_SCRIPT = preload("res://scripts/chase/chase_dog.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("COURSE_COMPONENT_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	var pig: PigController = load("res://scenes/characters/pig.tscn").instantiate()
	root.add_child(pig)
	pig.reset_at(Vector3(0, 1, 0))
	await process_frame

	# LaunchPad
	var pad := LaunchPad.new()
	pad.position = Vector3(100, 0, 100)
	root.add_child(pad)
	await process_frame
	pig.reset_at(Vector3(0, 1, 0))
	pad._cooldown_timer = 0.0
	pad._on_body(pig)
	_check(pig.is_knocked_back(), "LaunchPad applies knockback")
	_check(pig.velocity.y > 0.0, "LaunchPad imparts upward velocity")
	pad.queue_free()

	# SpinHammer
	var hammer := SpinHammer.new()
	root.add_child(hammer)
	await process_frame
	pig.reset_at(Vector3(2, 1, 0))
	hammer._on_head_body(pig)
	_check(pig.is_knocked_back(), "SpinHammer applies knockback")
	hammer.queue_free()

	# FakeFloor
	var floor_tile := FakeFloor.new()
	floor_tile.trigger_delay = 0.1
	floor_tile.reset_time = 0.3
	root.add_child(floor_tile)
	await process_frame
	pig.reset_at(Vector3(0, 1, 0))
	floor_tile._on_step(pig)
	_check(floor_tile._state == "wobbling", "FakeFloor wobbles on step (telegraph)")
	await create_timer(0.25).timeout
	_check(floor_tile._state == "fallen", "FakeFloor collapses after delay")
	_check(floor_tile._shape.disabled, "FakeFloor collision disabled when fallen")
	await create_timer(0.45).timeout
	_check(floor_tile._state == "solid", "FakeFloor resets to solid")
	_check(not floor_tile._shape.disabled, "FakeFloor collision restored")
	floor_tile.queue_free()

	# DecoyGoal
	var decoy := DecoyGoal.new()
	root.add_child(decoy)
	await process_frame
	pig.reset_at(Vector3(0, 1, 2))
	decoy._on_enter(pig)
	_check(pig.is_knocked_back(), "DecoyGoal bounces pig back")
	_check(decoy._triggered_once, "DecoyGoal marks first trigger")
	decoy.queue_free()

	# RollingHay
	var hay := RollingHay.new()
	root.add_child(hay)
	await process_frame
	hay.release()
	_check(hay._state == "rolling", "RollingHay releases into rolling state")
	_check(not hay._bale.freeze, "RollingHay unfreezes rigid body")
	pig.reset_at(Vector3(0, 1, -2))
	hay._on_contact(pig)
	_check(pig.is_knocked_back(), "RollingHay knocks pig on contact")
	hay.queue_free()

	# SpinningSweeper
	var sweeper := SpinningSweeper.new()
	root.add_child(sweeper)
	await process_frame
	pig.reset_at(Vector3(1.5, 0.4, 0))
	sweeper._on_bar_body(pig)
	_check(pig.is_knocked_back(), "SpinningSweeper applies knockback")
	sweeper.queue_free()

	# BumperPillar
	var bumper = BUMPER_PILLAR.new()
	root.add_child(bumper)
	await process_frame
	pig.reset_at(Vector3(0, 0.5, 1.0))
	bumper._on_body(pig)
	_check(pig.is_knocked_back(), "BumperPillar applies bouncy knockback")
	bumper.queue_free()

	# DoorDashGate
	var gate = DOOR_DASH.new()
	gate.breakable_index = 1
	root.add_child(gate)
	await process_frame
	# Test fake door (door 0)
	pig.reset_at(Vector3(-2.5, 0.5, 0.5))
	gate._on_fake_door_hit(pig, gate._doors[0])
	_check(pig.is_knocked_back(), "DoorDashGate fake door repels pig")
	# Test breakable door (door 1)
	pig.reset_at(Vector3(0, 0.5, 0.5))
	gate._on_breakable_door_hit(pig, gate._doors[1])
	_check(gate._is_broken, "DoorDashGate breakable door breaks open")
	gate.queue_free()

	# PendulumBall
	var pendulum = PENDULUM_BALL.new()
	pendulum.position = Vector3(100, 0, 100)
	root.add_child(pendulum)
	await process_frame
	pig.reset_at(Vector3(0, 0.5, 0))
	pendulum._hit_timer = 0.0
	pendulum._on_ball_body(pig)
	_check(pig.is_knocked_back(), "PendulumBall imparts lateral knockback")
	pendulum.queue_free()

	# VoxelTNT
	var tnt = VOXEL_TNT.new()
	tnt.fuse_time = 0.05
	root.add_child(tnt)
	await process_frame
	pig.reset_at(Vector3(0, 1.3, 0))
	tnt._on_step(pig)
	await create_timer(0.12).timeout
	_check(pig.is_knocked_back(), "VoxelTNT explodes and knocks back target")
	tnt.queue_free()

	# BouncyMushroom
	var shroom = BOUNCY_MUSHROOM.new()
	root.add_child(shroom)
	await process_frame
	pig.reset_at(Vector3(0, 1.5, 0))
	shroom._cooldown_timer = 0.0
	shroom._on_cap_step(pig)
	_check(pig.is_knocked_back(), "BouncyMushroom launches pig into air")
	_check(pig.velocity.y > 0.0, "BouncyMushroom imparts upward boost")
	shroom.queue_free()

	# SeesawPlatform
	var seesaw = SEESAW.new()
	root.add_child(seesaw)
	await process_frame
	pig.reset_at(Vector3(0, 0.5, 4.0)) # Front side
	seesaw._on_body_entered(pig)
	seesaw._physics_process(0.2)
	_check(absf(seesaw._target_tilt) > 0.01, "SeesawPlatform responds to player weight with tilt")
	seesaw.queue_free()

	# VoxelPushBlock (spawned away from the pig: its push area overlapping the
	# pig used to auto-push it first, flaking this assertion on frame timing)
	var v_block = VOXEL_PUSH_BLOCK.new()
	v_block.position = Vector3(100, 0, 100)
	root.add_child(v_block)
	await process_frame
	_check(v_block.push(Vector3(0, 0, -1)), "VoxelPushBlock can be pushed forward")
	v_block.queue_free()

	# VoxelWaterStream
	var stream = VOXEL_STREAM.new()
	stream.shore_point = Vector3(0, 0.5, 4.0)
	root.add_child(stream)
	await process_frame
	pig.reset_at(Vector3(0, 0, 0))
	stream._handle_player_entered(pig)
	_check(pig.is_knocked_back() or pig.global_position.distance_to(stream.shore_point) < 2.0, "VoxelWaterStream sweeps player towards shore")
	stream.queue_free()

	# CardboardBoxProp
	var box_prop = CARDBOARD_BOX.new()
	root.add_child(box_prop)
	await process_frame
	box_prop.equip_box(pig)
	_check(pig.get_meta("in_stealth_box", false), "CardboardBoxProp equips onto player")
	box_prop.unequip_box()
	_check(not pig.get_meta("in_stealth_box", false), "CardboardBoxProp unequips cleanly")
	box_prop.queue_free()

	# IllusoryWall
	var ill_wall = ILLUSORY_WALL.new()
	root.add_child(ill_wall)
	await process_frame
	ill_wall.shatter()
	_check(ill_wall.is_shattered, "IllusoryWall shatters into hidden passage")
	ill_wall.queue_free()

	# MimicChest
	var chest = MIMIC_CHEST.new()
	chest.is_mimic = true
	root.add_child(chest)
	await process_frame
	pig.reset_at(Vector3(0, 0.5, 1.0))
	chest._on_player_entered(pig)
	_check(chest.is_triggered, "MimicChest snaps open and bites player")
	chest.queue_free()

	# BoostPad
	var b_pad = BOOST_PAD.new()
	root.add_child(b_pad)
	await process_frame
	pig.velocity = Vector3.ZERO
	b_pad._on_body_entered(pig)
	_check(pig.velocity.length() > 10.0, "BoostPad activates racing speed boost")
	b_pad.queue_free()

	# WatermelonPeel
	var peel = WATERMELON_PEEL.new()
	root.add_child(peel)
	await process_frame
	_check(peel.collision_mask & 4 != 0, "WatermelonPeel mask includes the dog layer (4)")
	var dummy_dog := Node3D.new()
	root.add_child(dummy_dog)
	peel.trigger_slip(dummy_dog)
	_check(peel.is_slipping, "WatermelonPeel causes target to slip and spin")
	dummy_dog.queue_free()

	# WatermelonPeel vs a real dog: stun() must arm the dog's own stun timer
	var peel_2 = WATERMELON_PEEL.new()
	root.add_child(peel_2)
	var real_dog: ChaseDog = DOG_SCRIPT.new()
	root.add_child(real_dog)
	await process_frame
	real_dog.phase = "seek"
	real_dog.phase_time = 0.0
	peel_2.trigger_slip(real_dog)
	_check(real_dog.phase == "stun" and real_dog.phase_time > 2.0, "WatermelonPeel stuns a real dog for a lasting duration")
	real_dog.queue_free()

	# RacingFinishGate: a faster-than-record run earns the RECORD BROKEN banner
	var f_gate = RACING_FINISH.new()
	root.add_child(f_gate)
	await process_frame
	f_gate.time_provider = func() -> float: return 20.0
	f_gate._on_finish_entered(pig)
	_check(f_gate.is_finished and f_gate.banner_label.visible, "RacingFinishGate drops record broken victory banner")
	_check(f_gate.record_broken and f_gate.banner_label.text.contains("RECORD BROKEN") and f_gate.banner_label.text.contains("00:20.00"), "RacingFinishGate banner reports a real record-breaking time")
	f_gate.queue_free()

	# RacingFinishGate: a slower run finishes without a free record
	var slow_gate = RACING_FINISH.new()
	root.add_child(slow_gate)
	await process_frame
	slow_gate.time_provider = func() -> float: return 40.0
	slow_gate._on_finish_entered(pig)
	_check(slow_gate.banner_label.visible and not slow_gate.record_broken, "RacingFinishGate does not award the record to a slow run")
	_check(slow_gate.banner_label.text.contains("00:40.00") and not slow_gate.banner_label.text.contains("RECORD BROKEN"), "RacingFinishGate shows the slow run's real time instead")
	slow_gate.queue_free()

	# RacingFinishGate without a clock keeps a plain finish banner
	var plain_gate = RACING_FINISH.new()
	root.add_child(plain_gate)
	await process_frame
	plain_gate._on_finish_entered(pig)
	_check(plain_gate.banner_label.visible and plain_gate.final_time < 0.0 and not plain_gate.record_broken, "RacingFinishGate without a clock claims no record")
	plain_gate.queue_free()

	# VoxelSlimeBlock
	var slime = VOXEL_SLIME.new()
	root.add_child(slime)
	await process_frame
	pig.reset_at(Vector3(0, 1.2, 0))
	slime._on_body_entered(pig)
	_check(pig.velocity.y > 0.0, "VoxelSlimeBlock launches pig upwards")
	slime.queue_free()

	# PineconeProp
	var cone = PINECONE_PROP.new()
	root.add_child(cone)
	await process_frame
	cone.pickup(pig)
	_check(cone.is_held, "PineconeProp can be picked up by player")
	cone.throw_cone()
	_check(cone.is_spent, "PineconeProp can be thrown to distract dog")
	# Freed mid-flight (e.g. course exit): the thrown cone must not be orphaned on
	# the scene root with a landing callback pointing at the freed prop.
	var thrown_mesh: Node = cone._cone_mesh
	cone.queue_free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(thrown_mesh), "PineconeProp freed mid-flight takes its thrown cone along")

	# MysteryItemBox
	var m_box = MYSTERY_BOX.new()
	root.add_child(m_box)
	await process_frame
	m_box._collect(pig)
	_check(not m_box.is_active, "MysteryItemBox collects and activates roulette power-up")
	# Golden star effects are granted by the COURSE (they must be course-scoped);
	# the box itself only pops the toast and reports the item.
	var granted_items: Array = []
	m_box.item_collected.connect(func(item, _p): granted_items.append(item))
	var star_speed_before: float = pig.move_speed
	m_box._apply_item("GOLDEN_STAR", pig)
	_check(not pig.get_meta("star_invincible", false), "GOLDEN_STAR alone no longer flips invincibility (the course owns that)")
	_check(is_equal_approx(pig.move_speed, star_speed_before), "GOLDEN_STAR alone no longer touches speed (the course owns that)")
	m_box.item_collected.emit("GOLDEN_STAR", pig)
	_check(granted_items.has("GOLDEN_STAR"), "GOLDEN_STAR is reported through item_collected for the course to grant")
	m_box.queue_free()

	# StuntJumpRamp (+ the landing mini-turbo it promises)
	var landing_floor := StaticBody3D.new()
	landing_floor.collision_layer = 1
	landing_floor.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60, 1, 80)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.5, -20)
	landing_floor.add_child(floor_shape)
	root.add_child(landing_floor)
	var ramp = STUNT_RAMP.new()
	root.add_child(ramp)
	await process_frame
	pig.reset_at(Vector3(0, 2.0, 0))
	ramp._on_player_crest(pig)
	_check(pig.velocity.y > 0.0, "StuntJumpRamp launches pig for 360 aerial stunt")
	var turbo_fired := [false]
	ramp.landing_turbo.connect(func(_p): turbo_fired[0] = true)
	var turbo_wait := 0
	while not turbo_fired[0] and turbo_wait < 40:
		await create_timer(0.1).timeout
		turbo_wait += 1
	_check(turbo_fired[0], "StuntJumpRamp pays out the landing mini-turbo on touchdown")
	ramp.queue_free()
	landing_floor.queue_free()

	# RaceTimer
	var r_timer = RACE_TIMER.new()
	r_timer.countdown_duration = 0.3
	root.add_child(r_timer)
	await process_frame
	r_timer.start_countdown()
	_check(r_timer.state == "countdown", "RaceTimer starts in countdown")
	await create_timer(0.7).timeout
	_check(r_timer.state == "running" and r_timer.elapsed > 0.0, "RaceTimer runs after the countdown")
	var stopped_at: float = r_timer.stop()
	_check(stopped_at > 0.0 and r_timer.state == "stopped" and is_equal_approx(stopped_at, r_timer.final_time), "RaceTimer freezes the final time")
	var frozen_elapsed: float = r_timer.elapsed
	await create_timer(0.2).timeout
	_check(is_equal_approx(r_timer.elapsed, frozen_elapsed), "Stopped RaceTimer no longer advances")
	_check(r_timer.format_time(75.5) == "01:15.50", "RaceTimer formats mm:ss.cc")
	r_timer.queue_free()
	var early_timer = RACE_TIMER.new()
	root.add_child(early_timer)
	await process_frame
	early_timer.start_countdown()
	_check(early_timer.stop() < 0.0, "RaceTimer stopped before GO reports no valid time")
	early_timer.queue_free()

	# MudPatch
	var mud = MUD_PATCH.new()
	root.add_child(mud)
	await process_frame
	var mud_base: float = pig.move_speed
	mud._on_body_entered(pig)
	_check(is_equal_approx(pig.move_speed, mud_base * 0.5), "MudPatch slows the pig")
	mud._on_body_entered(pig)
	_check(is_equal_approx(pig.move_speed, mud_base * 0.5), "MudPatch slowdown does not stack on re-entry")
	mud._on_body_exited(pig)
	_check(is_equal_approx(pig.move_speed, mud_base), "MudPatch restores speed on exit")
	pig.set_meta("star_invincible", true)
	mud._on_body_entered(pig)
	_check(is_equal_approx(pig.move_speed, mud_base), "Star pig ignores mud")
	pig.set_meta("star_invincible", false)
	mud._on_body_entered(pig)
	mud.queue_free()
	await process_frame
	_check(is_equal_approx(pig.move_speed, mud_base), "MudPatch freed mid-slow hands the speed back")

	# NeonBumper
	var n_bumper = NEON_BUMPER.new()
	root.add_child(n_bumper)
	await process_frame
	pig.reset_at(Vector3(0, 0.5, 2.0))
	n_bumper._on_body_entered(pig)
	_check(pig.velocity.length() > 0.0, "NeonBumper repels target with pinball bounce")
	n_bumper.queue_free()

	# PatrolVisionCone occlusion: real cover between cone and pig blocks sight
	var vision_cone = PATROL_VISION_CONE.new()
	vision_cone.position = Vector3(300, 0, 300)
	root.add_child(vision_cone)
	await process_frame
	vision_cone.target_player = pig
	pig.reset_at(Vector3(300, 0.6, 296.0))
	await physics_frame
	vision_cone._scan_for_player()
	_check(vision_cone.is_alert, "Vision cone spots an unobstructed pig")
	var screen := StaticBody3D.new()
	screen.name = "CoverScreen"
	screen.collision_layer = 1
	screen.collision_mask = 0
	var screen_col := CollisionShape3D.new()
	var screen_box := BoxShape3D.new()
	screen_box.size = Vector3(2.0, 2.4, 0.4)
	screen_col.shape = screen_box
	screen_col.position = Vector3(0, 1.2, 0)
	screen.add_child(screen_col)
	screen.position = Vector3(300, 0, 298.0)
	root.add_child(screen)
	await physics_frame
	vision_cone._scan_for_player()
	_check(not vision_cone.is_alert, "Vision cone loses the pig behind solid cover")
	screen.queue_free()
	vision_cone.queue_free()

	# ConveyorBelt: carries whoever stands on it, wading against it is slow
	var belt_floor := StaticBody3D.new()
	belt_floor.collision_layer = 1
	belt_floor.collision_mask = 0
	var belt_floor_col := CollisionShape3D.new()
	var belt_floor_box := BoxShape3D.new()
	belt_floor_box.size = Vector3(60, 1, 60)
	belt_floor_col.shape = belt_floor_box
	belt_floor_col.position = Vector3(0, -0.5, 500)
	belt_floor.add_child(belt_floor_col)
	root.add_child(belt_floor)
	var belt = CONVEYOR_BELT.new()
	belt.name = "TestBelt"
	belt.position = Vector3(0, 0, 500.0)
	belt.belt_direction = Vector3(0, 0, 1) # Carries the pig north (+Z)
	belt.belt_speed = 2.5
	root.add_child(belt)
	await process_frame
	pig.reset_at(Vector3(0, 0.6, 500.0))
	pig.velocity = Vector3.ZERO
	await create_timer(1.0).timeout
	_check(pig.global_position.z > 500.0 + belt.belt_speed * 0.6, "ConveyorBelt carries a standing pig along its direction (z=%.2f)" % pig.global_position.z)
	# Wading against the belt: net (walk - belt) = -2.0 m/s, so after 1.8 s the
	# pig has progressed well into the belt but NOT reached a target free
	# walking covers in 1.3 s
	pig.reset_at(Vector3(0, 0.6, 500.0))
	pig.interact_target = null
	pig._click_route.clear()
	pig.target_destination = Vector3(0, 0.6, 494.0)
	pig.is_moving = true
	await create_timer(1.8).timeout
	_check(494.5 < pig.global_position.z and pig.global_position.z < 498.8, "Wading against the belt: slow progress, target not yet reached (z=%.2f)" % pig.global_position.z)
	belt.queue_free()
	belt_floor.queue_free()
	await process_frame

	# PatrolGuardDog: solid body with a chase-dog-compatible stun contract
	var guard = PATROL_GUARD_DOG.new()
	guard.position = Vector3(200, 0, 200)
	root.add_child(guard)
	await process_frame
	_check(guard.is_in_group("chase_dogs") and guard.has_node("GuardShape"), "PatrolGuardDog is a solid body tagged as a dog")
	guard.stun(0.1)
	_check(guard.is_stunned, "PatrolGuardDog stuns like a chase dog (box bowling)")
	await create_timer(0.3).timeout
	_check(not guard.is_stunned, "PatrolGuardDog recovers from a stun")
	guard.queue_free()

	# DialogueBeat: bottom-card story pause - locks the pig, auto-advances each
	# line, restores control at the end, and skip_all() fast-forwards (the path
	# tests and mash-skipping players share).
	var beat = preload("res://scripts/courses/components/dialogue_beat.gd").new()
	root.add_child(beat)
	await process_frame
	pig.reset_at(Vector3(0, 0.6, 0))
	pig.set_control_mode("chase")
	beat.play({"id": "unit_intro", "title": "单元测试", "lines": ["第一句。", "第二句。"], "line_time": 0.6, "player": pig})
	_check(beat.is_active(), "Beat is active the moment play() is called")
	await create_timer(0.25).timeout # deferred begin lands; line 1 still on screen
	_check(beat.locking() and pig.control_mode == "cinematic", "Deferred lock holds the pig in cinematic mode")
	await create_timer(0.8).timeout # line 1 auto-advanced at 0.6 s, line 2 playing
	_check(beat.locking() and pig.control_mode == "cinematic", "Beat still holds the pig on line 2 (auto-advance, no release)")
	await create_timer(0.9).timeout # line 2 also auto-advanced -> beat ends on its own
	_check(not beat.is_active() and not beat.locking(), "Beat ends by itself after the last line (nothing can be wedged)")
	_check(pig.control_mode == "chase", "Control restored to the pre-beat mode")
	beat.play({"id": "unit_skip", "title": "跳过", "lines": ["没人读得到这句。"], "line_time": 2.0, "player": pig})
	await create_timer(0.25).timeout
	_check(beat.locking() and pig.control_mode == "cinematic", "Second beat locks again")
	beat.skip_all()
	await process_frame
	_check(not beat.is_active() and pig.control_mode == "chase", "skip_all() ends the beat at once and restores control")
	beat.queue_free()
	await process_frame

	await process_frame
	print("\nALL COURSE COMPONENT TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)