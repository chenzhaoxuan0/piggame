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

	# VoxelPushBlock
	var v_block = VOXEL_PUSH_BLOCK.new()
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
	var init_vel: Vector3 = pig.velocity
	b_pad._on_body_entered(pig)
	_check(pig.velocity.length() > init_vel.length() or b_pad.is_active, "BoostPad activates racing speed boost")
	b_pad.queue_free()

	# WatermelonPeel
	var peel = WATERMELON_PEEL.new()
	root.add_child(peel)
	await process_frame
	var dummy_dog := Node3D.new()
	root.add_child(dummy_dog)
	peel.trigger_slip(dummy_dog)
	_check(peel.is_slipping, "WatermelonPeel causes target to slip and spin")
	dummy_dog.queue_free()

	# RacingFinishGate
	var f_gate = RACING_FINISH.new()
	root.add_child(f_gate)
	await process_frame
	f_gate._on_finish_entered(pig)
	_check(f_gate.is_finished and f_gate.banner_label.visible, "RacingFinishGate drops record broken victory banner")
	f_gate.queue_free()

	await process_frame
	print("\nALL COURSE COMPONENT TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)