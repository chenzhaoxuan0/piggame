extends SceneTree

# Achievement system guard: definition sanity, unlock idempotence, the
# state-driven auto chain (GameManager.state_changed), persistence across a
# fresh manager instance and across reset_run, and the wall panel smoke test.
# Uses its own save file so the dev machine's real progress stays untouched.

var failures := 0
var game: Node
var am: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("ACHIEVEMENT_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	game = root.get_node("GameManager")
	am = root.get_node("AchievementManager")
	am.save_path = "user://achievements_test.json"
	am.reset_progress(true) # wipes memory + the test file only

	# --- 1. Definition table sanity
	_check(am.total() >= 15, "Achievement table loaded with the full set")
	var seen := {}
	var table_ok := true
	for def in am.DEFS:
		if str(def["id"]).is_empty() or str(def["title"]).is_empty() or seen.has(def["id"]):
			table_ok = false
		seen[def["id"]] = true
	_check(table_ok, "Every def has a unique id and a title")

	# --- 2. Unlock semantics
	_check(am.unlock("first_dodge"), "unlock returns true the first time")
	_check(not am.unlock("first_dodge"), "unlock is idempotent")
	_check(not am.unlock("bogus_id"), "Unknown ids are rejected safely")
	_check(am.is_unlocked("first_dodge") and am.unlocked_count() == 1, "State queries reflect the unlock")

	# --- 3. Persistence: file written, fresh manager reloads it
	_check(FileAccess.file_exists(am.save_path), "Unlock writes the save file")
	var am2: Node = load("res://scripts/core/achievement_manager.gd").new()
	am2.save_path = am.save_path
	root.add_child(am2)
	await process_frame
	_check(am2.is_unlocked("first_dodge"), "A fresh manager instance reloads persisted progress")
	am2.queue_free()
	await process_frame

	# --- 4. State-driven chain through GameManager
	game.reset_run()
	await process_frame
	game.choose_blue()
	await process_frame
	_check(am.is_unlocked("warm_mud"), "The blue choice unlocks 温热的泥浆")

	game.reset_run()
	await process_frame
	game.choose_red()
	await process_frame
	_check(am.is_unlocked("red_pin"), "The red choice unlocks 红色的生锈插销")
	_check(not am.is_unlocked("showdown_winner"), "The blue ending did not secretly award the showdown")
	game.mark_intro_dream_done()
	await process_frame
	_check(am.is_unlocked("nightmare_survivor"), "Waking from the dream unlocks 从噩梦中醒来")
	game.complete_npc("ox")
	await process_frame
	_check(am.is_unlocked("ox_friend"), "The ox story unlocks 卸下重轭")
	game.complete_stage_chase("chase_final") # stage -> showdown
	await process_frame
	game.complete_showdown() # stage -> cablecar_ready
	await process_frame
	_check(am.is_unlocked("showdown_winner"), "Winning the showdown unlocks 意志的对决")
	game.finish_escape()
	await process_frame
	_check(am.is_unlocked("maverick_pioneer"), "Escaping unlocks 特立独行的先驱")

	# --- 5. Achievements survive a run reset (the whole point of the save)
	game.reset_run()
	await process_frame
	_check(am.is_unlocked("red_pin") and am.is_unlocked("maverick_pioneer"),
		"A reset_run keeps unlocked achievements")

	# --- 6. Course completion chain
	game.reset_run()
	await process_frame
	game.choose_red()
	await process_frame
	for chase_id in ["chase_1", "chase_2", "chase_3", "chase_final"]:
		game.complete_stage_chase(chase_id)
		await process_frame
	_check(am.is_unlocked("gate_crasher"), "Clearing the final chase unlocks 冲破大铁门")
	_check(am.is_unlocked("all_courses"), "All four hidden courses unlock 四通八达")

	# --- 7. Wall panel smoke test on the level
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.3).timeout
	office._open_achievements(true)
	await process_frame
	_check(is_instance_valid(office.achievements_menu) and office.achievements_menu.visible,
		"The achievements wall opens from the start menu")
	var rows: VBoxContainer = office.achievements_menu.find_child("AchievementRows", true, false)
	_check(rows != null and rows.get_child_count() == am.total(),
		"The wall lists every achievement row")
	var count_label: Label = office.achievements_menu.find_child("AchievementCount", true, false)
	_check(count_label != null and count_label.text.contains("/ %d" % am.total()),
		"The header shows the unlock progress")
	office._close_achievements()
	await process_frame
	_check(not office.achievements_menu.visible and office.start_menu.visible,
		"Closing the wall returns to the start menu")

	# --- 8. Unlock popup anchors the bottom-right corner (above the notice feed zone)
	am.reset_progress(true)
	await process_frame
	am.unlock("first_dodge")
	await create_timer(0.4).timeout
	var popup: Control = null
	for layer in am.get_children():
		if layer is CanvasLayer:
			var found: Control = layer.find_child("AchievementPopup", true, false)
			if found != null:
				popup = found
				break
	if popup != null:
		var vp_end: float = root.get_visible_rect().end.y
		var vp_right: float = root.get_visible_rect().end.x
		var anchored_br: bool = popup.global_position.y + popup.size.y >= vp_end - 200.0 \
			and popup.global_position.y + popup.size.y <= vp_end \
			and popup.global_position.x + popup.size.x >= vp_right - 200.0 \
			and popup.global_position.x + popup.size.x <= vp_right
		_check(anchored_br, "The unlock popup sits in the bottom-right corner")
	else:
		_check(false, "The unlock popup exists on its canvas layer")
	office.queue_free()
	await process_frame

	am.reset_progress(true) # leave the test file clean
	print("\nALL ACHIEVEMENT TESTS DONE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
