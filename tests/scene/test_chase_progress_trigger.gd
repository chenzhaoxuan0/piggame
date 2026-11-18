extends SceneTree
## 2026-11-18 导演反馈：护栏可跳（round 8）+ 山坡可走（round 9）之后，猪可以
## 不走公路——6×6 的路标触发盒被越野绕过，第二/三段追逐不再出现。
## 钉「旅程进度兜底触发」：任意路线走到该段进度线即触发；前置 NPC 未完成时
## 不触发、补做后立即触发（迟补仍开追）。

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("CHASE_PROGRESS_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("CHASE_PROGRESS_TEST FAIL: %s" % message)

func _init() -> void:
	call_deferred("_run")

func _wait_frames(office: Node, frames: int) -> void:
	for i in frames: await physics_frame

func _run() -> void:
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.8).timeout
	office.start_game()
	await create_timer(0.4).timeout
	var gm: Node = root.get_node("GameManager")
	# 序章红选项：拿图钉（has_pin）——没有它 start_stage_chase 对 chase_2+ 一律拒发。
	office.open_dialogue("cliff_goat_intro")
	await create_timer(0.3).timeout
	for i in 3:
		while office.line_index < office.dialogue_lines.size() - 1:
			office._advance_dialogue()
			await process_frame
		await process_frame
		office.options.get_child(0).pressed.emit()
		for j in 6: await process_frame
	_check(gm.has_pin and gm.stage == "exploring", "prologue red choice grants the pin (has_pin)")
	var pig: Node3D = office.player
	pig.set_control_mode("explore")

	# 起手：真实触发处理器开 chase_1，再走真实的过门脱险（GateOxTrigger）。
	office._on_farm_chase_triggered("chase_1")
	await _wait_frames(office, 10)
	_check(gm.stage == "chase_1", "chase_1 armed via the real trigger handler")
	pig.global_position = Vector3(30, 24, 55)
	pig.velocity = Vector3.ZERO
	await _wait_frames(office, 15)
	_check(gm.stage == "exploring" and gm.chase_completed.chase_1,
		"ox-gate crossing rescues chase_1 back to exploring")

	# 越野场景 A：猪抄近路到溪谷路以南（远离 6×6 路标盒），先不做牛的故事。
	pig.global_position = Vector3(44, 21.0, -10)
	pig.velocity = Vector3.ZERO
	await _wait_frames(office, 40)
	_check(gm.stage != "chase_2", "past-threshold off-road without the ox story does NOT arm chase_2 (prerequisite)")

	# 补做牛的故事：下一帧立即补触发——迟到的旅程照样开追。
	gm.complete_npc("ox")
	await _wait_frames(office, 20)
	_check(gm.stage == "chase_2", "completing the ox arms chase_2 off-road (progress fallback)")
	_check(office.chase.running and office.chase._dogs.size() > 0,
		"chase_2 has real dogs on the pig (%d)" % office.chase._dogs.size())

	# 真实脱险：把猪送到羊门（chase_2 的安全区门）。
	pig.global_position = Vector3(-40, 16, -22)
	pig.velocity = Vector3.ZERO
	await _wait_frames(office, 15)
	_check(gm.chase_completed.chase_2, "sheep-gate crossing rescues chase_2")

	# 越野场景 B：羊棚去马场这段同样抄近路（远离 ChaseTrigger_3 的路标盒）。
	gm.complete_npc("sheep")
	pig.global_position = Vector3(-55, 14.5, -79)
	pig.velocity = Vector3.ZERO
	await _wait_frames(office, 30)
	_check(gm.stage == "chase_3", "chase_3 arms off-road past the woodland threshold (progress fallback)")

	# chase_3 真实脱险：马门。
	pig.global_position = Vector3(18, 8, -90)
	pig.velocity = Vector3.ZERO
	await _wait_frames(office, 15)
	_check(gm.chase_completed.chase_3, "horse-gate crossing rescues chase_3")

	# 安全区豁免：猪在马场台地里（赛跑/啃草的活动区）时，纵然进度线全过，
	# 也不开追——活动不被追逐打断。
	pig.global_position = Vector3(40, 8.6, -120)
	pig.velocity = Vector3.ZERO
	await _wait_frames(office, 40)
	_check(gm.stage == "exploring" and pig.control_mode == "explore",
		"inside the pasture terrace no chase fires (safe activity zone)")

	# 窗口上限：过了羊段的猪走到终局赛道入口一带，Creek 旧段不再捞回。
	pig.global_position = Vector3(-30, 4.3, -165)
	pig.velocity = Vector3.ZERO
	await _wait_frames(office, 40)
	_check(gm.stage == "exploring", "past the chase_3 window no stale chase re-fires near the final entry")

	print("\nCHASE PROGRESS TRIGGER TESTS FINISHED: failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)
