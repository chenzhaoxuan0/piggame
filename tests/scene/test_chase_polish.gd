extends SceneTree

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("POLISH_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("POLISH_TEST FAIL: %s" % message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	
	# Load level scene
	var level_scene := load("res://scenes/levels/office_level_1.tscn")
	var level = level_scene.instantiate()
	root_node.add_child(level)
	await process_frame
	await process_frame
	
	# Dismiss start menu
	level.start_game()
	await process_frame
	
	# 1. Test Skill Unlock Modal
	level._show_skill_unlock(
		"【 坚 韧 挣 脱 】",
		"借老牛坚忍不屈的硬骨气 · 挣脱命运的死锁",
		"【核心按键】 被咬住时狂按 [ 空格键 / SPACE ] 或 [ E ]",
		"被恶犬扑咬纠缠时，在 3.5 秒内猛敲空格 5 次，即可爆发巨力震退恶犬 6 米并使其眩晕！"
	)
	await process_frame
	_check(level.skill_card_modal.visible, "Skill unlock card modal opens and is visible")
	_check(level.skill_card_title.text == "【 坚 韧 挣 脱 】", "Skill title displays correctly")
	_check("空格键" in level.skill_card_key_label.text, "Skill card displays clear Space key prompt")
	_check(level.in_skill_card, "Player is in skill card reading state")
	_check(level.player.control_mode == "cinematic", "Player movement is paused while reading skill card")
	
	# Dismiss skill card
	level._dismiss_skill_card()
	await process_frame
	_check(not level.skill_card_modal.visible, "Skill unlock card modal closes cleanly")
	_check(not level.in_skill_card, "Player exits skill card state")
	_check(level.player.control_mode == "explore", "Player control restored to explore mode")
	
	# 2. Test QTE in Chase 2 (before meeting Ox) - Must NOT instantly fail!
	var game: Node = root.get_node("GameManager")
	game.reset_run()
	game.choose_red()
	level.start_stage_chase("chase_2")
	await process_frame
	_check(game.is_in_chase(), "Chase 2 is active")
	_check(not game.has_struggle_skill, "Player does not yet have Ox struggle skill in Chase 2")

	# Simulate dog grappling player in Chase 2
	var first_dog: ChaseDog = level.chase._dogs[0]
	level.chase._on_dog_grapple(first_dog)
	await process_frame
	_check(level.in_qte, "Grapple triggers QTE struggle mode even in Chase 2")
	_check(level.qte_panel.visible, "QTE struggle panel is visible to player")
	_check(level.qte_time_remaining >= 3.0, "QTE provides generous 3.5s struggle countdown")
	_check("空格" in level.qte_btn_label.text, "QTE panel shows prominent Space key prompt")
	_check(level.player.control_mode == "qte", "Player enters QTE control mode")
	_check(not level.overlay.visible, "Game over overlay is NOT shown immediately on catch")
	
	# Tap space during Chase 1 struggle
	level._on_qte_tapped()
	level._on_qte_tapped()
	_check(level.qte_hits == 2, "QTE hits increment correctly on Space tap")
	_check(level.qte_counter_label.text == "2 / %d" % level.QTE_TARGET_HITS, "QTE counter label displays hit count")

	# Complete Chase 1 struggle
	level._on_qte_tapped()
	level._on_qte_tapped()
	level._on_qte_tapped()
	level._on_qte_tapped()
	await process_frame
	_check(not level.in_qte, "QTE resolved upon reaching target hits")
	_check(not level.qte_panel.visible, "QTE panel hidden after escaping")
	_check(level.player.control_mode == "chase", "Player resumes chase movement")
	_check(first_dog.phase == "stun", "Attacking dog is stunned after being kicked away")
	
	# 3. Test Dog Leaping Over Low Obstacles (Logs)
	var dog := ChaseDog.new()
	root_node.add_child(dog)
	dog.global_position = Vector3(0, 0, 0)
	dog.configure(level.player, 0.0)
	
	# Test course direction does not divert sideways when facing low obstacle
	var dir_straight := Vector3(0, 0, -1)
	var steer_result := dog._steer_around_obstacles(dir_straight)
	_check(steer_result.dot(dir_straight) > 0.8, "Dog charges forward through low obstacle clearance")
	
	# 4. Test Ambush Spawning
	var initial_dog_count: int = level.chase._dogs.size()
	var test_ambush := {
		"trigger": level.player.global_position + Vector3(0, 0, 2),
		"spawn": level.player.global_position + Vector3(4, 0, 0),
		"phantom": false,
		"radius": 10.0,
		"triggered": false
	}
	level.chase._ambushes.append(test_ambush)
	level.chase._check_ambushes()
	await process_frame
	_check(level.chase._dogs.size() > initial_dog_count, "Ambush triggered and spawned reinforcement dog")
	_check(test_ambush.get("triggered", false), "Ambush marked as triggered")
	
	# Cleanup
	level.chase.stop_chase()
	root_node.queue_free()
	await process_frame
	
	print("\nALL POLISH TESTS FINISHED: failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)
