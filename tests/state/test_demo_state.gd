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

	state.reset_run()
	state.choose_red()
	_check(state.start_chase() and state.complete_chase() and state.complete_showdown() and state.finish_escape(), "Zero companion path must complete")
	state.reset_run()
	_check(not state.has_pin and not state.has_read_record and state.ending == "", "Reset clears inventory, clue, ending")
	for id in ["ox", "sheep", "horse"]:
		_check(not state.npc_completed[id] and not state.npc_met[id], "Reset clears NPC progress: " + id)
	_check(not state.select_character(state.CharacterType.OX), "Locked playable characters remain locked")
	_check(state.select_character(state.CharacterType.PIG), "Pig selection remains compatible")

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
