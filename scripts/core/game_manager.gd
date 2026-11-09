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
var current_chase: String = "chase_1"
var chase_completed: Dictionary = {"chase_1": false, "chase_2": false, "chase_3": false, "chase_final": false}
var has_pin: bool = false
var npc_completed: Dictionary = {"ox": false, "sheep": false, "horse": false}
var npc_met: Dictionary = {"ox": false, "sheep": false, "horse": false}
var has_read_record: bool = false
var ending: String = ""

# Companions' granted powers (meaningful forward momentum)
var has_struggle_skill: bool:
	get: return npc_completed.get("ox", false)
var has_discern_skill: bool:
	get: return npc_completed.get("sheep", false)
var has_dash_skill: bool:
	get: return npc_completed.get("horse", false)

func reset_run() -> void:
	stage = "prologue"
	current_chase = "chase_1"
	chase_completed = {"chase_1": false, "chase_2": false, "chase_3": false, "chase_final": false}
	has_pin = false
	npc_completed = {"ox": false, "sheep": false, "horse": false}
	npc_met = {"ox": false, "sheep": false, "horse": false}
	has_read_record = false
	ending = ""
	state_changed.emit()

func is_in_chase() -> bool:
	return stage.begins_with("chase")

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

func get_current_main_objective() -> String:
	match stage:
		"prologue": return "与老岩羊交谈，选择你的路。"
		"chase_1": return "【牛耕地闯关】顶问号砖、过假地板、识破画中门、跟着大锤节奏走位！"
		"chase_2": return "【第二段追逐】避开幻影，若被咬住狂按空格挣脱，逃向羊棚！"
		"chase_3": return "【第三段追逐】看穿幻影虚影，跨过障碍冲向追风马场！"
		"chase_final", "chase": return "【最终突围】按 Shift 爆发冲刺，甩开犬队冲向大铁门！"
		"exploring":
			if not chase_completed.get("chase_1", false):
				return "穿过猪圈破损木门，准备向牛耕地下山突围！"
			elif not npc_completed.get("ox", false):
				return "与老牛交谈，帮助他卸下沉重的犁头枷锁。"
			elif not chase_completed.get("chase_2", false):
				return "耕地出口已开，沿溪流山道向羊矮棚进发！"
			elif not npc_completed.get("sheep", false):
				return "与小羊绵绵交谈，帮助她看破不合宜的世俗规尺。"
			elif not chase_completed.get("chase_3", false):
				return "羊棚出口已开，穿越林间山路奔向马场！"
			elif not npc_completed.get("horse", false):
				return "查看 35 秒纪录板，告诉追风不必追赶过去的影子。"
			elif not chase_completed.get("chase_final", false):
				return "马场出口已开，穿过大院发起最终突围！"
			else:
				return "接近铁门，打破束缚！"
		"showdown": return "靠近农场主，完成意志对决，撞开铁门！"
		"cablecar_ready": return "铁门已开：带着铜插销登上后山索道，奔向旷野！"
		"ending": return "旅程已达彼岸，风中没有栏杆与食槽。"
	return ""

func get_to_do_items() -> Array[Dictionary]:
	return [
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
