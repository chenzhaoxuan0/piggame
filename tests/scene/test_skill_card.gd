extends SceneTree

# Loan skill card: GameManager.course_skill_granted fires once per newly-loaned
# skill the pig does not own permanently, and office_level_1 answers with the
# non-blocking LoanSkillCard that shows and auto-hides without locking control.
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

	# --- Card show / auto-dismiss in the real level scene ---
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.5).timeout

	var card: Control = office.hud.get_node_or_null("LoanSkillCard")
	_check(card != null, "LoanSkillCard built on the hud")
	if card == null:
		_finish()
		return
	_check(not card.visible, "card hidden before any grant")

	var control_before: String = office.player.control_mode if "control_mode" in office.player else ""
	gm.grant_course_skills(["dash"])
	await create_timer(0.4).timeout
	_check(card.visible, "card visible after a course loan")
	_check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "card is non-blocking (mouse IGNORE)")
	if "control_mode" in office.player:
		_check(office.player.control_mode == control_before, "player control untouched by the card")
	_check(office.loan_card_title.text == "【 疾 风 冲 刺 】", "card text matches the dash skill entry")

	await create_timer(4.0).timeout
	_check(not card.visible, "card auto-hides after its 3s hold + fade")

	_finish()

func _finish() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.reset_run()
	print("SKILL_CARD_TEST %s" % ("PASS" if _failures == 0 else "FAIL(%d)" % _failures))
	quit(1 if _failures > 0 else 0)
