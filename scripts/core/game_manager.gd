extends Node

# One owner for the whitebox demo's run state. No persistence or art dependencies.
signal state_changed
signal character_selected(character_id: String)
# Course-scoped loans only: fires for each skill that flips false->true while
# the pig does not own it permanently, so the HUD can show a loan skill card
# once per course entry (re-grants and farm-learned skills stay silent).
signal course_skill_granted(skill_id: String)
signal language_changed(language_code: String)

enum CharacterType { PIG, OX, HORSE, SHEEP }

var current_character: CharacterType = CharacterType.PIG
var current_language: String = "zh_CN"
var unlocked_characters: Dictionary = {
	CharacterType.PIG: true, CharacterType.OX: false,
	CharacterType.HORSE: false, CharacterType.SHEEP: false
}

var stage: String = "prologue"
var current_chase: String = "chase_1"
var chase_completed: Dictionary = {"chase_1": false, "chase_2": false, "chase_3": false, "chase_final": false}
var has_pin: bool = false
var npc_completed: Dictionary = {"ox": false, "sheep": false, "horse": false}
var npc_met: Dictionary = {"ox": false, "sheep": false, "horse": false}
var has_read_record: bool = false
var ending: String = ""
# Boot handoff from the opening key-test scene: "dream" auto-enters the
# nightmare prologue, "farm" skips straight to the pen. Deliberately NOT
# cleared by reset_run() - office_level_1._ready() resets the run BEFORE it
# consumes this flag.
var pending_boot: String = ""
# The nightmare prologue's story beat: true once the pig has woken from the
# dream (or skipped it - the 6am truck deadline is known either way), so the
# to-do notebook can show the prologue as a crossed-out story entry.
var intro_dream_done: bool = false
# Pre-game pigpen sandbox ("farm" boot): the pig can roam/hop/dash/snuffle in
# its pen to learn the keys, but NPCs won't talk and the pen gate stays
# bolted. F on the goat is the "start the game" button and clears this.
var tutorial_free_roam: bool = false

# Companions' granted powers (meaningful forward momentum).
# Setters write npc_completed: assignments from level select must be visible to
# every reader (getter-only properties silently swallow writes).
# Hidden courses lend their skills through course_skill_bonuses instead, so
# entering a course never ticks the farm story's companion quests.
var has_struggle_skill: bool:
	get: return npc_completed.get("ox", false) or course_skill_bonuses.get("struggle", false)
	set(value): npc_completed["ox"] = value
var has_discern_skill: bool:
	get: return npc_completed.get("sheep", false) or course_skill_bonuses.get("discern", false)
	set(value): npc_completed["sheep"] = value
var has_dash_skill: bool:
	get: return npc_completed.get("horse", false) or course_skill_bonuses.get("dash", false)
	set(value): npc_completed["horse"] = value

# Course-scoped skill loans: granted on course setup(), cleared on course exit.
var course_skill_bonuses: Dictionary = {"struggle": false, "discern": false, "dash": false}

const _SKILL_OWNER_NPC := {"struggle": "ox", "discern": "sheep", "dash": "horse"}

func grant_course_skills(ids: Array) -> void:
	for id in ids:
		if course_skill_bonuses.has(id):
			if course_skill_bonuses[id]:
				continue
			course_skill_bonuses[id] = true
			if not npc_completed.get(_SKILL_OWNER_NPC.get(id, ""), false):
				course_skill_granted.emit(id)

func clear_course_skills() -> void:
	for id in course_skill_bonuses:
		course_skill_bonuses[id] = false

func reset_run() -> void:
	stage = "prologue"
	current_chase = "chase_1"
	chase_completed = {"chase_1": false, "chase_2": false, "chase_3": false, "chase_final": false}
	has_pin = false
	npc_completed = {"ox": false, "sheep": false, "horse": false}
	npc_met = {"ox": false, "sheep": false, "horse": false}
	has_read_record = false
	ending = ""
	intro_dream_done = false
	tutorial_free_roam = false
	clear_course_skills()
	state_changed.emit()

func is_in_chase() -> bool:
	return stage.begins_with("chase")

## The dream beat is a plain field write in the level script; this setter lets
## listeners (AchievementManager) hear about it through state_changed.
func mark_intro_dream_done() -> void:
	intro_dream_done = true
	state_changed.emit()

func start_stage_chase(chase_id: String) -> bool:
	if not has_pin and chase_id != "chase_1":
		return false
	current_chase = chase_id
	stage = chase_id
	state_changed.emit()
	return true

func complete_stage_chase(chase_id: String) -> bool:
	chase_completed[chase_id] = true
	if chase_id == "chase_final" or chase_id == "chase":
		stage = "showdown"
	else:
		stage = "exploring"
	state_changed.emit()
	return true

func choose_red() -> bool:
	if stage != "prologue":
		return false
	has_pin = true
	stage = "exploring"
	state_changed.emit()
	return true

func choose_blue() -> bool:
	if stage != "prologue":
		return false
	ending = "stay"
	stage = "ending"
	state_changed.emit()
	return true

func complete_npc(id: String) -> bool:
	if stage != "exploring" or not npc_completed.has(id) or npc_completed[id]:
		return false
	if id == "horse" and not has_read_record:
		return false
	npc_met[id] = true
	npc_completed[id] = true
	state_changed.emit()
	return true

func read_record() -> void:
	if stage != "exploring" or has_read_record:
		return
	has_read_record = true
	state_changed.emit()

func start_chase() -> bool:
	if stage != "exploring" or not has_pin:
		return false
	stage = "chase"
	state_changed.emit()
	return true

func retry_chase() -> bool:
	if not stage.begins_with("chase"):
		return false
	# Completed companions and the pin survive a retry. Scene resets are external.
	stage = "exploring"
	state_changed.emit()
	return true

func complete_chase() -> bool:
	if stage != "chase":
		return false
	stage = "showdown"
	state_changed.emit()
	return true

func complete_showdown() -> bool:
	if stage != "showdown":
		return false
	stage = "cablecar_ready"
	state_changed.emit()
	return true

func can_launch_cablecar() -> bool:
	return stage == "cablecar_ready" and has_pin

func finish_escape() -> bool:
	if not can_launch_cablecar():
		return false
	ending = "escape"
	stage = "ending"
	state_changed.emit()
	return true

func select_character(type: CharacterType) -> bool:
	if not unlocked_characters.get(type, false):
		return false
	current_character = type
	character_selected.emit("pig")
	return true

func set_language(lang: String) -> void:
	if lang in ["zh_CN", "en"]:
		current_language = lang
		language_changed.emit(lang)

func get_to_do_items() -> Array[Dictionary]:
	return [
		{
			"id": "prologue_dream",
			"text": "从噩梦中醒来（运牲车明早六点就到）",
			"done": intro_dream_done
		},
		{
			"id": "break_free",
			"text": "叼起铜插销，撞开猪圈木栓",
			"done": has_pin
		},
		{
			"id": "chase_1",
			"text": "甩掉身后的过往阴影，冲进牛耕地",
			"done": chase_completed.get("chase_1", false)
		},
		{
			"id": "ox_skill",
			"text": "帮阿牛卸下沉重的犁（获得坚韧挣脱之力）",
			"done": npc_completed.get("ox", false)
		},
		{
			"id": "chase_2",
			"text": "穿越溪谷，在狗群扑咬中挣脱突围",
			"done": chase_completed.get("chase_2", false)
		},
		{
			"id": "sheep_skill",
			"text": "帮小羊走出阴影（获得识破虚妄幻影之眼）",
			"done": npc_completed.get("sheep", false)
		},
		{
			"id": "chase_3",
			"text": "看穿幻影虚影，越过障碍奔向马场",
			"done": chase_completed.get("chase_3", false)
		},
		{
			"id": "horse_skill",
			"text": "告诉追风纪录真相（获得疾风爆发冲刺）",
			"done": npc_completed.get("horse", false)
		},
		{
			"id": "chase_final",
			"text": "疾风突围，冲破农场大铁门！",
			"done": chase_completed.get("chase_final", false) or stage in ["showdown", "cablecar_ready", "ending"]
		},
		{
			"id": "cablecar",
			"text": "启动后山索道，奔向自由的旷野",
			"done": ending == "escape"
		}
	]
