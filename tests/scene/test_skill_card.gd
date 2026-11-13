extends SceneTree

# Loan skill notice: GameManager.course_skill_granted fires once per newly-loaned
# skill the pig does not own permanently, and office_level_1 answers with a rich
# LoanSkillNotice card in the bottom-right notice feed - non-blocking, no modal,
# auto-fades without ever locking control.
#   Godot_v4.3-stable_win64.exe --path . -s tests/scene/test_skill_card.gd

var _failures := 0

func _check(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		_failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.reset_run()

	# --- Signal semantics ---
	var granted: Array[String] = []
	var collector := func(id: String): granted.append(id)
	gm.course_skill_granted.connect(collector)
	gm.grant_course_skills(["struggle", "dash"])
	_check(granted.size() == 2, "two fresh loans emit two signals (got %d)" % granted.size())
	_check("struggle" in granted and "dash" in granted, "loan ids carried on the signal")

	granted.clear()
	gm.grant_course_skills(["struggle", "dash"])
	_check(granted.is_empty(), "re-granting already-loaned skills stays silent")

	gm.clear_course_skills()
	granted.clear()
	gm.npc_completed["horse"] = true  # dash owned permanently on the farm
	gm.grant_course_skills(["dash", "discern"])
	_check(granted == ["discern"], "farm-learned skill does not re-trigger the card")
	gm.reset_run()
	gm.course_skill_granted.disconnect(collector)

	# --- Notice show / auto-fade in the real level scene ---
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.5).timeout

	_check(office.notice_feed.get_node_or_null("LoanSkillNotice") == null, "no loan notice exists before any grant")

	var control_before: String = office.player.control_mode if "control_mode" in office.player else ""
	gm.grant_course_skills(["dash"])
	await create_timer(0.4).timeout
	var card: Control = office.notice_feed.get_node_or_null("LoanSkillNotice")
	_check(card != null and card.visible, "loan notice appears in the bottom-right feed after a course loan")
	if card == null:
		_finish()
		return
	_check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "notice is non-blocking (mouse IGNORE)")
	if "control_mode" in office.player:
		_check(office.player.control_mode == control_before, "player control untouched by the notice")
	var title_label: Label = card.find_child("SkillTitle", true, false)
	_check(title_label != null and title_label.text == "【 疾 风 冲 刺 】", "notice text matches the dash skill entry")

	await create_timer(4.8).timeout
	_check(office.notice_feed.get_node_or_null("LoanSkillNotice") == null, "notice auto-fades away after its 4s hold + fade")

	_finish()

func _finish() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.reset_run()
	print("SKILL_CARD_TEST %s" % ("PASS" if _failures == 0 else "FAIL(%d)" % _failures))
	quit(1 if _failures > 0 else 0)
