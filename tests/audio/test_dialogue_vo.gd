extends SceneTree

# Run: godot --headless --path . --script tests/audio/test_dialogue_vo.gd
# 对话配音（TTS 白盒）资产与接线自检：
#   1) dialogue_tree 的每个节点都有 assets/audio/vo/{id}.mp3；
#   2) 虚键 zhuifeng_record_check 解析后携带真实节点 id（VO 才能对上文件）；
#   3) --import 之后所有 mp3 可被 ResourceLoader 认领（headless 也能 load）；
#   4) dialogue_vo 组件在 dummy 音频驱动下 play_for/stop 全链路不炸。
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
	var dialogue = root.get_node("DialogueManager")
	var gm = root.get_node("GameManager")

	var vo_script = load("res://scripts/core/dialogue_vo.gd")
	_check(vo_script != null, "dialogue_vo.gd compiles")
	var vo = vo_script.new()
	root.add_child(vo)

	# 1) 每个对话节点一条 VO 文件（FileAccess 兜底，未导入也能查）
	# 豁免清单：速通记录牌的两个节点（2026-11-19 速通玩法）是数据面板不是
	# 角色，无配音。日后补 MiniMax TTS（speedrun_board_locked/hub.mp3）即可移出。
	var vo_exempt: Array[String] = ["speedrun_board_locked", "speedrun_board_hub"]
	var missing: Array[String] = []
	for key: String in dialogue.dialogue_tree:
		if key in vo_exempt:
			continue
		if not FileAccess.file_exists("res://assets/audio/vo/%s.mp3" % key):
			missing.append(key)
	_check(missing.is_empty(), "Every dialogue node has a VO file (missing: %s)" % ", ".join(missing))

	# 2) 虚键解析携带真实 id
	gm.reset_run()
	gm.has_read_record = false
	_check(dialogue.get_dialogue_node("zhuifeng_record_check").get("id", "") == "zhuifeng_observe_record",
		"record_check resolves to observe_record before the board is read")
	gm.has_read_record = true
	_check(dialogue.get_dialogue_node("zhuifeng_record_check").get("id", "") == "zhuifeng_awaken",
		"record_check resolves to awaken after the board is read")

	# 3) 导入元数据齐备（--import 之后才为真；缺了真实运行同样播不出声）
	var unimported: Array[String] = []
	for key: String in dialogue.dialogue_tree:
		if key in vo_exempt:
			continue
		if not ResourceLoader.exists("res://assets/audio/vo/%s.mp3" % key):
			unimported.append(key)
	_check(unimported.is_empty(), "Every VO file is imported & loadable (unimported: %s)" % ", ".join(unimported))

	# 4) headless 全链路：正常播、切节点掐上一条、未知节点静默跳过
	vo.play_for("cliff_goat_intro")
	vo.play_for("aniu_interaction")
	vo.stop()
	vo.play_for("not_a_real_node")
	vo.stop()
	vo.queue_free()

	print("DIALOGUE_VO_TEST assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)
