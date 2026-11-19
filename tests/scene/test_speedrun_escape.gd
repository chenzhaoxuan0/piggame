extends SceneTree

# Run: godot --headless --path . --script tests/scene/test_speedrun_escape.gd
# 速通直达终点（2026-11-19 实机反馈）回归：
#   1) 非速通时索道拉杆维持故事门：对话进 cablecar_locked，不发射不改状态；
#   2) 二周目开局猪圈沙盒里，速通牌直接可对话（不需要先找山羊解锁）；
#      一周目沙盒维持「现在还不能对话」的契约；
#   3) 从沙盒对话开赛：沙盒解除、标题卡收走、重置为一局全新开始；
#   4) 速通计时中 F 拉杆 = 直接发射逃生，无对决/铁门/铜插销任何前置——
#      强制补 stage/has_pin 后 finish_escape 正常记账，停表记档；
#   5) 倒计时未走完（时钟未开）时 F 不发射——GO 之前不算冲线。
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
	# 档案隔离：速通记档会落盘，重定向到临时文件（demo_state 的做法）。
	state.progress_path = "user://run_progress_escape_test.json"
	DirAccess.open("user://").remove("run_progress_escape_test.json")
	state.finished_runs = 1
	state.ng_plus = true
	state.speedrun_best = -1.0
	state.speedrun_recent.clear()
	state.reset_run()

	var level: Node3D = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	var lever: Node3D = level.farm.get_node("CablecarLever")
	var board: Node3D = level.farm.get_node("SpeedrunBoard")
	level.player.set_control_mode("explore")

	# 1) 非速通：拉杆是「尚未就绪」的故事门
	level._on_interact(lever)
	await process_frame
	_check(level.dialogue_open and level.current_dialogue == "cablecar_locked",
		"Outside a speedrun the lever keeps its story gate (cablecar_locked)")
	_check(state.stage == "prologue" and not state.has_pin, "Locked lever changes no state")
	level.close_dialogue()

	# 2) 开局沙盒：一周目牌子维持「不能对话」契约，二周目直接开对话
	state.tutorial_free_roam = true
	state.ng_plus = false
	level._on_interact(board)
	await process_frame
	_check(not level.dialogue_open, "First-run sandbox keeps the no-talk contract on the board")
	state.ng_plus = true
	level._on_interact(board)
	await process_frame
	_check(level.dialogue_open and level.current_dialogue == "speedrun_board_hub",
		"NG+ sandbox opens the speedrun hub directly (no goat detour)")

	# 3) 对话里选「开始速通」：从沙盒一击开赛
	var start_index := -1
	for i in range(level.current_options.size()):
		if str(level.current_options[i].get("event", "")) == "start_speedrun":
			start_index = i
			break
	_check(start_index >= 0, "The hub offers the start option while the clock is idle")
	level._select_option(start_index)
	await process_frame
	await process_frame
	_check(state.speedrun_active and state.stage == "prologue",
		"Starting from the sandbox arms a fresh prologue run")
	_check(not state.tutorial_free_roam, "Starting the speedrun clears the pen-sandbox flag")
	_check(level._speedrun_timer != null and is_instance_valid(level._speedrun_timer)
		and level._speedrun_timer.state == "countdown", "The speedrun clock counts down")
	_check(not is_instance_valid(level._title_card), "The sandbox title card is dismissed for good")

	# 4) 倒计时中 F 拉杆不发射（时钟未开）
	level._on_interact(lever)
	await process_frame
	_check(not level.cinematic and state.stage == "prologue",
		"F during the countdown does not launch (clock not started yet)")

	# 5) GO 之后：F 拉杆直接发射（无任何前置）
	await create_timer(3.6).timeout  # GO 之后（countdown_duration 3.0）
	level._on_interact(lever)
	await process_frame
	_check(level.cinematic and state.stage == "cablecar_ready" and state.has_pin,
		"Speedrun F on the lever force-arms cablecar_ready with the pin")
	_check(state.speedrun_active, "The clock keeps running through the launch cinematic")
	await create_timer(4.6).timeout  # 索道飞行 tween 4.0s
	_check(state.ending == "escape" and state.stage == "ending", "The direct lever launch completes the escape")
	_check(state.finished_runs == 2, "The speedrun escape counts as a finished run")
	_check(not state.speedrun_active, "The launch stops the speedrun clock")
	_check(state.speedrun_best > 0.0 and state.speedrun_recent.size() == 1,
		"The escape time is recorded to the profile")
	_check(level._speedrun_verdict == "", "The verdict line was consumed by the ending overlay")

	# 清理临时档案与档案标记
	DirAccess.open("user://").remove("run_progress_escape_test.json")
	state.finished_runs = 0
	state.ng_plus = false
	state.reset_run()

	print("SPEEDRUN_ESCAPE_TEST assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)
