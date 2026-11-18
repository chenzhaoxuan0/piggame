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
# 二周目（NG+）：通关一次后写进 user:// 档案并常驻——reset_run() 不清它，
# 它属于玩家档案而不是某一局。技能 getter 全部 or ng_plus：二周目从泥窝
# 醒来就自带全部伙伴之力（2026-11-15 实机反馈：冲刺门控的彩蛋——羊棚手推
# 车、苹果树这类——一周目拿到冲刺太晚，正适合二周目顺路完成）。
var ng_plus := false
var finished_runs := 0
# 见过的结局记档（"escape"/"stay" -> true，随档案持久化）——「两扇门都看过」
# 要跨局对账：先安稳后出逃、或先出逃后回头看蓝色结局，都算同一档案的收获。
var seen_endings := {}
const DEFAULT_PROGRESS_PATH := "user://run_progress.json"
var progress_path := DEFAULT_PROGRESS_PATH
# 速通档案（2026-11-19 速通玩法）：猪圈速通记录牌的最短成绩与最近 5 次。
# best 为 -1 表示还没有任何纪录；speedrun_active 是"本轮计时进行中"标志，
# 对话路由（计时中不再给开赛选项）与结局停表都读它。
var speedrun_best := -1.0
var speedrun_recent: Array[float] = []
var speedrun_active := false

func _ready() -> void:
	# headless（测试进程）不读真实档案：通关型测试写过 run_progress.json 会让
	# 之后的每一个测试进程带着 NG+ 全技能启动，"技能应为关"的断言全灭。
	# 测试要验证持久化就显式重定向 progress_path（demo_state 的做法）。
	if DisplayServer.get_name() != "headless":
		_load_persisted_progress()

func _load_persisted_progress() -> void:
	if not FileAccess.file_exists(progress_path):
		return
	var f := FileAccess.open(progress_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		finished_runs = int(parsed.get("finished_runs", 0))
		var endings = parsed.get("seen_endings", {})
		if endings is Dictionary:
			seen_endings = endings
		speedrun_best = float(parsed.get("speedrun_best", -1.0))
		speedrun_recent.clear()
		var recent = parsed.get("speedrun_recent", [])
		if recent is Array:
			for item in recent:
				speedrun_recent.append(float(item))
	ng_plus = finished_runs >= 1

func _persist_progress() -> void:
	# headless 只允许写显式重定向过的临时档案，绝不碰玩家的真实进度文件。
	if DisplayServer.get_name() == "headless" and progress_path == DEFAULT_PROGRESS_PATH:
		return
	var f := FileAccess.open(progress_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"finished_runs": finished_runs,
		"seen_endings": seen_endings,
		"speedrun_best": speedrun_best,
		"speedrun_recent": speedrun_recent,
	}))
	f.close()

## 结局记档：随档案落盘；两种结局都见过时点亮「两扇门都看过」。
func _note_ending(kind: String) -> void:
	seen_endings[kind] = true
	_persist_progress()
	if seen_endings.get("escape", false) and seen_endings.get("stay", false):
		AchievementManager.unlock("both_doors")

## 局启动时由关卡调用：二周目开局点亮纪念成就并回报 true（用于一次性提示）。
func begin_ng_plus_if_earned() -> bool:
	if not ng_plus:
		return false
	AchievementManager.unlock("second_visit")
	return true

# Companions' granted powers (meaningful forward momentum).
# Setters write npc_completed: assignments from level select must be visible to
# every reader (getter-only properties silently swallow writes).
# Hidden courses lend their skills through course_skill_bonuses instead, so
# entering a course never ticks the farm story's companion quests.
# NG+ tacks on `or ng_plus`: a profile that escaped once keeps all three powers
# on every later run, without ticking the companion quests themselves.
var has_struggle_skill: bool:
	get: return npc_completed.get("ox", false) or course_skill_bonuses.get("struggle", false) or ng_plus
	set(value): npc_completed["ox"] = value
var has_discern_skill: bool:
	get: return npc_completed.get("sheep", false) or course_skill_bonuses.get("discern", false) or ng_plus
	set(value): npc_completed["sheep"] = value
var has_dash_skill: bool:
	get: return npc_completed.get("horse", false) or course_skill_bonuses.get("dash", false) or ng_plus
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

## 彻底清档回一周目（设置面板「重置周目数」）：周目档案（finished_runs /
## seen_endings / NG+）连文件一起清，局内状态走 reset_run。成就档不在此列
## ——成就墙自带自己的重置。
func reset_profile() -> void:
	finished_runs = 0
	seen_endings = {}
	ng_plus = false
	# 速通纪录属于玩家档案：重置周目数连它一起清——回到一周目时牌面回到
	# 「未解锁」，不留悬空在锁定牌面上的旧成绩。
	speedrun_best = -1.0
	speedrun_recent.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	reset_run()

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
	speedrun_active = false
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
	_note_ending("stay")
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
	# 通关记账：这一局结束，玩家档案从此标记 NG+（后续每一局全技能随身）。
	finished_runs += 1
	ng_plus = true
	_note_ending("escape")
	state_changed.emit()
	return true

## 速通记档（2026-11-19 速通玩法）：猪圈数据牌开赛 → 触发索道逃脱停表。
## 用时进最近 5 次（裁掉最旧），更短则刷新最佳，随后落盘。
## 返回是否刷新了最佳纪录（结局画面与牌面提示用）；负用时直接忽略。
func record_speedrun(t: float) -> bool:
	if t < 0.0:
		return false
	speedrun_recent.append(t)
	while speedrun_recent.size() > 5:
		speedrun_recent.pop_front()
	var beat := speedrun_best < 0.0 or t < speedrun_best
	if beat:
		speedrun_best = t
	_persist_progress()
	return beat

## 速通用时格式化（与 race_timer.gd 同款 %02d:%05.2f）：牌面与对话渲染共用。
func format_speedrun_time(t: float) -> String:
	return "%02d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]

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
