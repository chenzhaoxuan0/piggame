extends SceneTree

# Run: godot --headless --path . --script tests/state/test_demo_state.gd
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
	# NG+ 记账走临时档案：finish_escape 会写玩家档案，别把测试机的真实
	# 二周目标记烧进去。
	state.progress_path = "user://run_progress_demo_test.json"
	state.finished_runs = 0
	state.ng_plus = false
	DirAccess.open("user://").remove("run_progress_demo_test.json")
	state.reset_run()
	_check(state.stage == "prologue" and not state.has_pin, "New run must start in prologue without pin")
	_check(not state.start_chase(), "Chase cannot start before choosing red")
	_check(not state.complete_chase(), "Cannot claim chase success outside chase")
	_check(not state.complete_showdown(), "Cannot break gate before showdown")
	_check(not state.finish_escape(), "Cannot finish from the starting point")
	_check(not state.complete_npc("ox"), "Cannot finish a companion during prologue")
	_check(state.choose_blue(), "Blue choice should finish prologue")
	_check(state.ending == "stay" and state.stage == "ending", "Blue choice produces stay ending")
	_check(not state.choose_red() and not state.choose_blue(), "A choice is committed only once")
	_check(not state.can_launch_cablecar(), "Blue ending cannot launch cablecar")

	state.reset_run()
	_check(state.choose_red(), "Red choice succeeds from new run")
	_check(state.has_pin and state.stage == "exploring", "Red choice grants pin and exploring stage")
	_check(not state.choose_red() and not state.choose_blue(), "Cannot change or repeat red choice")
	_check(not state.complete_npc("unknown"), "Unknown NPC must not become completed")
	_check(not state.complete_npc("horse"), "Horse conclusion requires observed record")
	_check(dialogue.get_entry_for("ox") == "aniu_interaction", "First encounter selects initial dialogue")
	_check(not state.npc_met["ox"], "Entry lookup has no side effects")
	state.npc_met["ox"] = true
	_check(dialogue.get_entry_for("ox") == "aniu_revisit", "Leaving and returning selects revisit")
	_check(not state.npc_completed["ox"], "Encounter and revisit do not grant completion")
	_check(state.complete_npc("ox"), "Companion completion event succeeds")
	_check(not state.complete_npc("ox"), "Companion completion event is idempotent")
	_check(dialogue.get_entry_for("ox") == "aniu_post_idle", "Completion selects idle dialogue")
	var unseen: Dictionary = dialogue.get_dialogue_node("zhuifeng_record_check")
	_check(unseen["options"][0].get("event", "") == "read_record", "Unseen record requires observation")
	state.read_record()
	_check(state.has_read_record, "Observation commits record knowledge")
	_check(dialogue.get_dialogue_node("zhuifeng_record_check")["title"] == "35 秒", "Observed record unlocks truth dialogue")
	_check(state.complete_npc("horse"), "Horse can complete after record observation")
	_check(state.start_chase(), "Chase starts in exploring")
	_check(not state.start_chase(), "Chase cannot start twice")
	_check(not state.complete_npc("sheep"), "Companions cannot complete during chase")
	for attempt in range(3):
		_check(state.retry_chase(), "Retry returns to exploring")
		_check(state.has_pin and state.npc_completed["ox"] and state.npc_completed["horse"], "Retry retains completed companions and pin")
		_check(state.start_chase(), "A retry allows another chase")
	_check(state.complete_chase(), "Chase success enters showdown")
	_check(not state.complete_chase() and not state.retry_chase(), "Completed chase cannot complete or retry again")
	_check(not state.can_launch_cablecar(), "Chase success alone does not unlock cablecar")
	_check(dialogue.get_entry_for("farmer") == "ordeal_encounter", "Farmer starts three-round showdown")
	_check(state.complete_showdown(), "Final showdown event unlocks gate")
	_check(not state.complete_showdown(), "Gate event cannot repeat")
	_check(state.can_launch_cablecar(), "Completed showdown with pin unlocks cablecar")
	state.has_pin = false
	_check(not state.finish_escape(), "Missing pin blocks final event even after gate opens")
	state.has_pin = true
	_check(state.finish_escape(), "Final event produces escape ending")
	_check(state.ending == "escape" and state.stage == "ending", "Escape state is terminal")
	_check(not state.finish_escape(), "Ending cannot repeat")

	# --- NG+：通关一次记账进玩家档案并常驻；reset_run 不清它；三个技能
	# getter 从醒来起全部为真，但同伴任务本身不被点亮。
	_check(state.finished_runs == 1 and state.ng_plus, "Escaping once arms NG+ on the profile")
	state.reset_run()
	_check(state.ng_plus, "reset_run keeps the NG+ profile flag")
	_check(state.has_struggle_skill and state.has_discern_skill and state.has_dash_skill,
		"NG+ carries every companion skill from wake-up")
	_check(not state.npc_completed.get("ox", false) and not state.npc_completed.get("sheep", false)
		and not state.npc_completed.get("horse", false), "NG+ grants skills without ticking companion quests")
	var am_ng: Node = root.get_node("AchievementManager")
	var am_ng_path: String = am_ng.save_path
	am_ng.save_path = "user://achievements_demo_ng_test.json"
	DirAccess.open("user://").remove("achievements_demo_ng_test.json")
	am_ng.reset_progress(true)
	_check(state.begin_ng_plus_if_earned(), "NG+ boot helper reports earned")
	_check(am_ng.is_unlocked("second_visit"), "再见围城 pays on an NG+ boot")
	am_ng.save_path = am_ng_path

	state.reset_run()
	state.choose_red()
	_check(state.start_chase() and state.complete_chase() and state.complete_showdown() and state.finish_escape(), "Zero companion path must complete")
	_check(state.finished_runs == 2, "A second full escape adds to the profile counter")
	# NG+ 断言到此为止：下面的 course-loan 段要求"无任何技能"的干净档案，
	# 把档案标记与临时文件就地清掉。
	state.finished_runs = 0
	state.ng_plus = false
	DirAccess.open("user://").remove("run_progress_demo_test.json")
	DirAccess.open("user://").remove("achievements_demo_ng_test.json")
	state.reset_run()
	_check(not state.has_pin and not state.has_read_record and state.ending == "", "Reset clears inventory, clue, ending")
	for id in ["ox", "sheep", "horse"]:
		_check(not state.npc_completed[id] and not state.npc_met[id], "Reset clears NPC progress: " + id)
	_check(not state.select_character(state.CharacterType.OX), "Locked playable characters remain locked")
	_check(state.select_character(state.CharacterType.PIG), "Pig selection remains compatible")

	# Course-scoped skill loans never touch the farm story's companion progress.
	state.reset_run()
	state.choose_red()
	_check(not state.has_struggle_skill and not state.has_discern_skill and not state.has_dash_skill, "No skills before any grant")
	state.grant_course_skills(["struggle", "discern"])
	_check(state.has_struggle_skill and state.has_discern_skill and not state.has_dash_skill, "Course loan grants only the requested skills")
	_check(not state.npc_completed["ox"] and not state.npc_completed["sheep"], "Course loan does not complete companion quests")
	var todo_done := {}
	for item in state.get_to_do_items():
		todo_done[item["id"]] = item["done"]
	_check(not todo_done["ox_skill"] and not todo_done["sheep_skill"], "Course loan does not tick the to-do list")
	_check(state.complete_npc("ox"), "Companion quest still completable while a loan is active")
	state.clear_course_skills()
	_check(state.has_struggle_skill and not state.has_discern_skill, "Clearing loans keeps earned skills and drops borrowed ones")
	state.grant_course_skills(["dash", "bogus"])
	_check(state.has_dash_skill and not state.course_skill_bonuses.has("bogus"), "Unknown loan ids are ignored")
	state.reset_run()
	_check(not state.has_dash_skill and not state.has_struggle_skill, "Reset clears course loans and earned skills")

	var events: Array[String] = ["choose_red", "choose_blue", "complete_ox", "complete_sheep", "complete_horse", "read_record", "complete_showdown", "launch_cablecar"]
	for key in dialogue.dialogue_tree:
		var node: Dictionary = dialogue.get_dialogue_node(key)
		_check(not node.get("options", []).is_empty(), "Dialogue node has a visible exit: " + key)
		for option in node.get("options", []):
			var next_key: String = option.get("next", "")
			_check(next_key == "" or not dialogue.get_dialogue_node(next_key).is_empty(), "Option target exists: " + key + " -> " + next_key)
			var event: String = option.get("event", "")
			_check(event == "" or event in events, "Option event is registered: " + key)
	_check(dialogue.get_dialogue_node("ordeal_aftermath")["options"][0]["next"] == "", "Showdown aftermath must return to exploration")
	_check(dialogue.get_entry_for("cablecar") == "cablecar_locked", "New game cannot enter ending dialogue from cablecar")
	print("DEMO_STATE_TEST assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)
