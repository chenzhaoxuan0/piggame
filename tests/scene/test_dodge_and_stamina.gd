extends SceneTree

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("DODGE_STAMINA_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("DODGE_STAMINA_TEST FAIL: %s" % message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)

	# 1. Instantiate level
	var level_scene := load("res://scenes/levels/office_level_1.tscn")
	var level = level_scene.instantiate()
	root_node.add_child(level)
	await process_frame
	await process_frame

	level.start_game()
	await process_frame
	var player: PigController = level.player

	# 2. Test Dodge Restriction: Cannot dodge without dog red-circle threat
	_check(not player.is_dodging(), "Pig is initially not dodging")
	_check(not player.can_dodge(), "can_dodge() is false when no dog is preparing to pounce")
	_check(player.stamina == player.max_stamina, "Initial stamina is at max (3.0)")
	
	# Tap action_dash when no dog is attacking
	var ev := InputEventAction.new()
	ev.action = "action_dash"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	ev = InputEventAction.new()
	ev.action = "action_dash"
	ev.pressed = false
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame

	_check(not player.is_dodging(), "Shift tap without threat does NOT trigger dodge (infinite spam prevented)")
	_check(player.dodge_timer == 0.0, "Dodge timer remains 0.0")

	# 3. Spawn Dog in Windup (Red warning circle under player)
	var dog := ChaseDog.new()
	root_node.add_child(dog)
	dog.global_position = player.global_position + Vector3(0, 0, 2.0)
	dog.configure(player, 0.0)
	dog.phase = "windup"
	dog.phase_time = dog.windup_duration
	dog._lunge_direction = (player.global_position - dog.global_position).normalized()
	dog._warning.visible = true
	dog._warning.global_position = player.global_position + Vector3(0, 0.04, 0)
	await physics_frame
	await physics_frame

	_check(dog.is_threatening_player(), "Dog is threatening player with red circle windup")
	_check(dog._warning.visible, "Dog red warning circle is visible")
	_check(dog._warning.global_position.distance_to(player.global_position) < 0.5, "Red circle is positioned directly under the pig's feet")
	_check(player.can_dodge(), "can_dodge() is now true under red circle threat")

	# 4. Reactive Dodge under Dog Pounce Threat
	ev = InputEventAction.new()
	ev.action = "action_dash"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	ev = InputEventAction.new()
	ev.action = "action_dash"
	ev.pressed = false
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame

	_check(player.is_dodging(), "Shift tap during red circle threat triggers evasive dodge!")
	_check(player.dodge_timer > 0.0, "Dodge timer active (%.2f s)" % player.dodge_timer)
	_check(player.dash_remaining > 0.0, "dash_remaining reports active dodge window")

	# 5. Dog Lunges and Whiffs against Dodging Player
	dog.phase = "lunge"
	dog.phase_time = 0.38
	dog._lunge_direction = (player.global_position - dog.global_position).normalized()
	for f in 20:
		await physics_frame
		if dog.phase == "recover":
			break

	_check(dog.phase == "recover", "Dog lunge whiffed against dodging pig and entered recover skid")
	_check(player._successful_dodges >= 1, "Successful dodge counter incremented (%d)" % player._successful_dodges)
	_check(not dog.is_threatening_player(), "Dog in recover is no longer threatening player")
	_check(not player.can_dodge(), "Player cannot immediately chain dodge once threat is resolved")

	# Wait for dodge to finish
	await create_timer(0.45).timeout
	_check(not player.is_dodging(), "Dodge state expired naturally")

	# 6. Test Horse Sprint Long-Press Stamina System
	var game: Node = root.get_node("GameManager")
	game.stage = "exploring"
	game.npc_completed["horse"] = true
	level.farm.set_npc_completed("horse")
	level._refresh_hud()
	await process_frame

	_check(player.dash_enabled, "Horse sprint skill is now enabled")
	_check(level.dash_gauge != null and level.dash_gauge.visible, "Stamina gauge visible on HUD")
	_check(level.dash_bar.value >= 2.9, "Stamina gauge starts full (%.1f / %.1f)" % [level.dash_bar.value, level.dash_bar.max_value])

	# Hold Shift to sprint while moving forward
	player.target_destination = player.global_position + Vector3(0, 0, -20.0)
	player.is_moving = true
	var shift_down := InputEventAction.new()
	shift_down.action = "action_dash"
	shift_down.pressed = true
	Input.parse_input_event(shift_down)

	for frame in 30:
		await physics_frame

	var stamina_after_hold: float = player.stamina
	_check(player.is_sprinting, "Holding Shift enters continuous sprint")
	_check(stamina_after_hold < 2.7, "Stamina drained proportionally while holding Shift: %.2f / %.2f" % [stamina_after_hold, player.max_stamina])
	_check(level.dash_bar.value < 2.7, "HUD dash bar dropped to match stamina: %.2f" % level.dash_bar.value)

	# Release Shift: sprint ceases and stamina recovers
	var shift_up := InputEventAction.new()
	shift_up.action = "action_dash"
	shift_up.pressed = false
	Input.parse_input_event(shift_up)
	player.is_moving = false
	await physics_frame
	await physics_frame

	_check(not player.is_sprinting, "Releasing Shift stops sprint immediately")

	# Wait for stamina to recharge
	await create_timer(1.2).timeout
	_check(player.stamina > stamina_after_hold + 0.35, "Stamina regenerated after releasing Shift: %.2f" % player.stamina)
	_check(level.dash_bar.value > stamina_after_hold + 0.35, "HUD stamina bar reflects recharged energy: %.2f" % level.dash_bar.value)

	# Cleanup
	root_node.queue_free()
	await process_frame

	print("\nDODGE AND STAMINA TESTS FINISHED: failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)
