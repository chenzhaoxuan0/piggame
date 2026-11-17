extends SceneTree

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("POKEMON_BATTLE_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("POKEMON_BATTLE_TEST FAIL: %s" % message)

## 轮询等回合推进/战斗结束：固定 sleep 在负载机上会输给引擎调度（分支
## 提交自己都写着 "flaked on loaded machines"）——等状态而不是等时间。
func _await_turn(b: Node, target_turn: int, want_active := true, timeout_s := 4.0) -> void:
	var waited := 0.0
	while waited < timeout_s:
		await create_timer(0.05).timeout
		waited += 0.05
		if not is_instance_valid(b):
			return
		if not want_active and not b.battle_active:
			return
		if want_active and b.battle_active and b.current_turn >= target_turn and not b.is_busy:
			return

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

	var game: Node = root.get_node("GameManager")
	game.choose_red()
	game.stage = "showdown"
	await process_frame

	# 2. Verify Pokemon battle component exists
	_check(level.pokemon_battle != null, "PokemonShowdown battle component is initialized")
	_check(not level.pokemon_battle.visible, "Battle screen is initially hidden before showdown")

	# 3. Trigger Farmer Showdown
	level._start_farmer_showdown()
	await process_frame
	_check(level.dialogue_open, "Showdown battle enters dialogue state to block player wandering")
	_check(level.pokemon_battle.visible, "PokemonShowdown arena UI is displayed")
	_check(level.pokemon_battle.battle_active, "Battle active flag is true")
	_check(level.pokemon_battle.farmer_hp == 100.0, "Farmer starts with 100 authority/willpower HP")
	_check(level.pokemon_battle.pig_hp == 100.0, "Pig starts with 100 willpower HP")
	_check(level.pokemon_battle.move_buttons.size() == 4, "Deck contains all 4 Pokemon combat commands")
	_check(level.options.get_child_count() == 4, "Dialogue options are synchronized with 4 battle moves")

	# 4. Turn 1: Execute Move 2 (【借羊之眸】破妄暴击)
	level.pokemon_battle.execute_move(2)
	await _await_turn(level.pokemon_battle, 2)
	_check(level.pokemon_battle.farmer_hp <= 65.0, "Turn 1 deal massive crit damage to Farmer: %.1f" % level.pokemon_battle.farmer_hp)
	_check(level.pokemon_battle.current_turn == 2, "Turn advances to Turn 2")
	_check(level.pokemon_battle.pig_hp > 80.0, "Pig withstood Farmer's sweet mash temptation")
	_check(level.options.get_child_count() == 4, "Options synchronized for Turn 2")

	# 5. Turn 2: Execute Move 1 (【借牛之坚】坚韧反震)
	level.pokemon_battle.execute_move(1)
	await _await_turn(level.pokemon_battle, 3)
	_check(level.pokemon_battle.farmer_hp <= 35.0, "Turn 2 deal heavy stagger damage to Farmer: %.1f" % level.pokemon_battle.farmer_hp)
	_check(level.pokemon_battle.current_turn == 3, "Turn advances to Turn 3")
	_check(level.options.get_child_count() == 4, "Options synchronized for Turn 3")

	# 6. Turn 3: Execute Move 3 (【借马之风】极速闪避并撞门)
	level.pokemon_battle.execute_move(3)
	await _await_turn(level.pokemon_battle, 3, false)
	_check(level.pokemon_battle.farmer_hp == 0.0, "Farmer authority HP reduced to 0")
	_check(game.stage == "cablecar_ready", "Game stage transitions to cablecar_ready upon showdown victory")
	_check(not level.pokemon_battle.visible, "Battle arena hides upon completion")
	_check(not level.dialogue_open, "Dialogue state clears and returns control to player")
	_check(level.player.control_mode == "explore", "Player control mode restored to explore")

	# 7. Defeat path: plain 斗志 spam no longer wins the counter duel
	game.stage = "showdown"
	level._start_farmer_showdown()
	await process_frame
	_check(level.pokemon_battle.battle_active and level.pokemon_battle.farmer_hp == 100.0
		and level.pokemon_battle.pig_hp == 100.0, "Rematch restarts the duel with full HP on both sides")
	# 开场演出期的出拳会被吞——轮询等第一回合就绪再开打。
	await _await_turn(level.pokemon_battle, 1)
	for i in 3:
		level.pokemon_battle.execute_move(0)
		await _await_turn(level.pokemon_battle, i + 2 if i < 2 else 3, i < 2)
	_check(not level.pokemon_battle.battle_active, "Three plain charges lose the reworked duel")
	_check(game.stage == "showdown", "Defeat keeps the showdown stage - the gate stays shut")
	_check(level.overlay.visible, "Failure ending overlay shows the dragged-back-to-pen beat")

	# 8. Retry from the failure overlay, then win on the razor's edge
	level._retry_farmer_showdown()
	await process_frame
	_check(not level.overlay.visible and level.pokemon_battle.battle_active
		and level.pokemon_battle.pig_hp == 100.0, "Rematch button reopens the battle fully reset")
	# 同段 7：轮询等开场就绪，三击各自等回合推进/终局。
	await _await_turn(level.pokemon_battle, 1)
	level.pokemon_battle.execute_move(2)
	await _await_turn(level.pokemon_battle, 2)
	level.pokemon_battle.execute_move(1)
	await _await_turn(level.pokemon_battle, 3)
	level.pokemon_battle.execute_move(3)
	await _await_turn(level.pokemon_battle, 3, false)
	_check(game.stage == "cablecar_ready", "Counter sequence wins after a defeat - lose, retry, survive")

	# Cleanup
	root_node.queue_free()
	await process_frame

	print("\nPOKEMON SHOWDOWN TESTS FINISHED: failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)
