extends SceneTree

const BUMPER_PILLAR = preload("res://scripts/courses/components/bumper_pillar.gd")
const DOOR_DASH = preload("res://scripts/courses/components/door_dash_gate.gd")
const PENDULUM_BALL = preload("res://scripts/courses/components/pendulum_ball.gd")

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
	root.add_child(pendulum)
	await process_frame
	pig.reset_at(Vector3(0, 0.5, 0))
	pendulum._on_ball_body(pig)
	_check(pig.is_knocked_back(), "PendulumBall imparts lateral knockback")
	pendulum.queue_free()

	await process_frame
	print("\nALL COURSE COMPONENT TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)