extends Node

# One owner for the whitebox demo's run state. No persistence or art dependencies.
signal state_changed
signal character_selected(character_id: String)
signal language_changed(language_code: String)

enum CharacterType { PIG, OX, HORSE, SHEEP }

var current_character: CharacterType = CharacterType.PIG
var current_language: String = "zh_CN"
var unlocked_characters: Dictionary = {
	CharacterType.PIG: true, CharacterType.OX: false,
	CharacterType.HORSE: false, CharacterType.SHEEP: false
}

var stage: String = "prologue"
var has_pin: bool = false
var npc_completed: Dictionary = {"ox": false, "sheep": false, "horse": false}
var npc_met: Dictionary = {"ox": false, "sheep": false, "horse": false}
var has_read_record: bool = false
var ending: String = ""

func reset_run() -> void:
	stage = "prologue"
	has_pin = false
	npc_completed = {"ox": false, "sheep": false, "horse": false}
	npc_met = {"ox": false, "sheep": false, "horse": false}
	has_read_record = false
	ending = ""
	state_changed.emit()

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
	if stage != "chase":
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

func get_current_main_objective() -> String:
	match stage:
		"prologue": return "与老岩羊交谈，选择你的路。"
		"exploring": return "向下山方向探索；伙伴可选，穿过大院到铁门。"
		"chase": return "绕开护院犬，向铁门前的出口跑！"
		"showdown": return "靠近农场主，完成三回合意志对决。"
		"cablecar_ready": return "铁门已开：带着铜插销走到索道站。"
		"ending": return "本次旅程结束，可以重新开始。"
	return ""
