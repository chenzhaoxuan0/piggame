extends SceneTree

# 2026-11-15 实机反馈 #8/#9：追逐段末段被恶犬咬住的一瞬间钻进隐藏赛道，
# QTE 面板跟着进关——空格监听只在 qte 控制模式下生效，进关后它既关不掉
# 也打不满，只能干等倒计时归零。修复口径：世界切换（进出赛道）立刻按
# 「脱险」收场。本用例钉四条契约：
#   1. 进关瞬间挂着的 QTE 面板消失、猪恢复 explore；
#   2. QTE 所有者（农场 SimpleChase）复位，之后的扑咬不再被卡死拒绝；
#   3. 出赛道（对称保险）同样立刻收场；
#   4. 世界切换的「脱险」不白付 grapple_escape——玩家并没有真的狂按挣脱。

var failures := 0
var game: Node
var am: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("QTE_SWITCH_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	game = root.get_node("GameManager")
	am = root.get_node("AchievementManager")
	am.save_path = "user://achievements_qte_switch.json"
	am.reset_progress(true) # wipes memory + the dedicated test file only

	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.5).timeout
	# 顺序有讲究：office._ready() 会 reset_run()，choose_red 必须在其后，
	# 否则 has_pin 被洗掉、start_stage_chase("chase_2") 会被静默拒绝。
	office.start_game()
	await process_frame
	game.choose_red()
	await process_frame

	# --- 1. 农场追逐中被咬住 → 钻进隐藏赛道（实机 bug 的原路径）
	office.start_stage_chase("chase_2")
	await create_timer(0.2).timeout
	_check(office.chase._dogs.size() >= 1, "Farm chase spawned dogs for the drill")
	var dog: ChaseDog = office.chase._dogs[0]
	office.chase._on_dog_grapple(dog)
	await process_frame
	_check(office.in_qte and office.qte_panel.visible, "QTE panel up on dog grapple")
	_check(office.chase.in_qte, "Farm chase owns the pending QTE")

	office.enter_secret_course("course_3")
	await create_timer(0.5).timeout
	_check(office.active_course != null, "Secret course entered mid-QTE")
	_check(not office.in_qte and not office.qte_panel.visible, "QTE panel dismissed the moment the world switched")
	_check(not office.chase.in_qte, "Farm chase QTE flag reset - later grapples not refused")
	_check(office.player.control_mode == "explore", "Pig handed back to explore mode")
	_check(not am.is_unlocked("grapple_escape"), "World-switch escape pays no free grapple_escape")

	# --- 2. 赛道内被咬住 → 出赛道（对称保险）
	var course = office.active_course
	course.runner.skip_beats() # intro beat locks the pig cinematic - QTE would be refused
	await create_timer(0.15).timeout
	game.grant_course_skills(["struggle"]) # runner-side grapples need the ox power
	course.runner._on_start(office.player)
	await process_frame
	var chaser: ChaseDog = course.runner._dogs[0]
	_check(is_instance_valid(chaser) and chaser.active, "Runner chaser awake for the exit-side drill")
	course.runner._on_dog_grapple(chaser)
	await process_frame
	_check(office.in_qte and office.qte_panel.visible, "Runner-side QTE panel up before the exit")

	course.runner._on_exit(office.player)
	await create_timer(1.0).timeout
	_check(office.active_course == null, "Course exited while the QTE was pending")
	_check(not office.in_qte and not office.qte_panel.visible, "QTE panel dismissed on course exit too")
	_check(not am.is_unlocked("grapple_escape"), "Exit dismissal still pays no free grapple_escape")

	am.reset_progress(true) # leave the temp file clean
	print("\nALL QTE WORLD-SWITCH TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
