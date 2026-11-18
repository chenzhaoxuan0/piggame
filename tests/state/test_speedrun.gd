extends SceneTree

# Run: godot --headless --path . --script tests/state/test_speedrun.gd
# 速通玩法（2026-11-19）档案与门槛自检：
#   1) 二周目门槛：一周目速通牌入口锁定，逃出过一次进主界面（hub 动态内容）；
#   2) record_speedrun：首记刷新、更慢不刷、更快刷；最近 5 次滚动裁旧；
#   3) 持久化往返：run_progress.json 落盘后新实例读回 best/recent；
#   4) reset_run 清进行中标志但留档案；reset_profile 连纪录带文件一起清；
#   5) format_speedrun_time 与 race_timer 同款格式。
var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var state = root.get_node("GameManager")
	var dialogue = root.get_node("DialogueManager")

	# 存档隔离：重定向到临时档案并清掉旧文件（demo_state 的做法）。
	state.progress_path = "user://run_progress_speedrun_test.json"
	DirAccess.open("user://").remove("run_progress_speedrun_test.json")
	state.finished_runs = 0
	state.ng_plus = false
	state.speedrun_best = -1.0
	state.speedrun_recent.clear()
	state.speedrun_active = false

	# 1) 二周目门槛 + hub 动态内容
	_check(dialogue.get_entry_for("speedrun_board") == "speedrun_board_locked",
		"First run sees a locked board")
	state.finished_runs = 1
	state.ng_plus = true
	_check(dialogue.get_entry_for("speedrun_board") == "speedrun_board_hub",
		"NG+ opens the speedrun hub")
	var hub: Dictionary = dialogue.get_dialogue_node("speedrun_board_hub")
	_check(String(hub.get("content", "")).contains("虚位以待"), "Empty profile renders 'awaiting first record'")
	var has_start := false
	for option in hub.get("options", []):
		if str(option.get("event", "")) == "start_speedrun":
			has_start = true
	_check(has_start, "Hub start option carries the start_speedrun event")
	_check(not String(dialogue.get_dialogue_node("speedrun_board_locked").get("content", "")).is_empty(),
		"Locked board explains itself")

	# 2) 记录逻辑：首记/更慢/更快 + 最近 5 次滚动
	_check(state.record_speedrun(100.0) and state.speedrun_best == 100.0,
		"First record becomes the best")
	_check(not state.record_speedrun(120.0) and state.speedrun_best == 100.0,
		"A slower run does not beat the best")
	_check(state.record_speedrun(80.5) and state.speedrun_best == 80.5,
		"A faster run refreshes the best")
	for t in [70.0, 90.0, 110.0, 130.0, 150.0, 170.0]:
		state.record_speedrun(t)
	_check(state.speedrun_recent.size() == 5, "Recent list keeps only the last 5")
	_check(state.speedrun_recent[0] == 90.0 and state.speedrun_recent[4] == 170.0,
		"Recent list rolls off the oldest entries")
	_check(state.speedrun_best == 70.0, "Best tracks the fastest run seen")
	_check(FileAccess.file_exists(state.progress_path), "Recording persists the profile")

	# 3) 持久化往返：新实例手动 _load_persisted_progress 读回（成就测试同款）
	var reloaded = load("res://scripts/core/game_manager.gd").new()
	reloaded.progress_path = state.progress_path
	reloaded._load_persisted_progress()
	_check(reloaded.speedrun_best == 70.0, "Reloaded profile restores the best time")
	_check(reloaded.speedrun_recent.size() == 5 and reloaded.speedrun_recent[0] == 90.0,
		"Reloaded profile restores the recent list")
	reloaded.free()

	# 4) 局内重置 vs 档案重置
	state.speedrun_active = true
	state.reset_run()
	_check(not state.speedrun_active and state.speedrun_best == 70.0,
		"reset_run clears the active flag but keeps records")
	state.reset_profile()
	_check(state.speedrun_best == -1.0 and state.speedrun_recent.is_empty(),
		"reset_profile wipes speedrun records")
	_check(not FileAccess.file_exists(state.progress_path), "reset_profile removes the profile file")

	# 5) 时间格式（与 race_timer.gd 的 %02d:%05.2f 同款——%05.2f 会四舍五入）
	_check(state.format_speedrun_time(83.456) == "01:23.46", "Time format matches race_timer style")
	_check(state.format_speedrun_time(0.0) == "00:00.00", "Zero formats cleanly")

	# 复位：把测试动过的档案字段清干净
	state.finished_runs = 0
	state.ng_plus = false
	state.reset_run()

	print("SPEEDRUN_TEST assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)
