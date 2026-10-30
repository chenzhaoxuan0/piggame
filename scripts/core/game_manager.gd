extends Node

# Global Game Manager (Autoload)
# 管理全局角色、语言、游戏进度、主线与支线任务状态

signal character_selected(character_id: String)
signal language_changed(language_code: String)
signal objective_updated(quest_type: String, quest_id: String, completed: bool)

enum CharacterType {
	PIG,    # 特立独行的猪 (MVP核心唯一主角)
	OX,     # 老黄牛 (后续篇章)
	HORSE,  # 神秘马 (后续篇章)
	SHEEP   # 领头羊 (后续篇章)
}

# 游戏状态
var current_character: CharacterType = CharacterType.PIG
var current_language: String = "zh_CN"
var current_floor: int = 3 # 第3层

# 角色解锁状态 (MVP期间仅做猪)
var unlocked_characters = {
	CharacterType.PIG: true,
	CharacterType.OX: false,
	CharacterType.HORSE: false,
	CharacterType.SHEEP: false
}

# 主线任务链：逃离第3层 (Main Quest)
var main_quests = {
	"m1_escape_box": {
		"title": "破箱脱困",
		"desc": "挣脱身上的吉祥物红绸带，冲破工位纸箱",
		"completed": false
	},
	"m2_inspect_elevator": {
		"title": "探明封锁",
		"desc": "侦查电梯厅，发现需要【P8总监黑金工牌】才能下行",
		"completed": false
	},
	"m3_distract_director": {
		"title": "调虎离山",
		"desc": "制造混乱引出风暴会议室里正在洗脑的P8总监",
		"completed": false
	},
	"m4_steal_badge": {
		"title": "顺手牵牌",
		"desc": "潜入风暴会议室，叼走桌上的【P8总监黑金工牌】",
		"completed": false
	},
	"m5_bypass_hr": {
		"title": "突破封锁",
		"desc": "利用茶水间制冰机与热咖啡滑倒堵在走廊的HR政委",
		"completed": false
	},
	"m6_escape_elevator": {
		"title": "电梯大逃亡",
		"desc": "刷卡开启电梯，在追兵赶到前踏入下行电梯轿厢！",
		"completed": false
	}
}

# 支线恶作剧清单：打工猪的搞事日常 (Side Quests / Mischief List)
var side_quests = {
	"sq_break_coffee": {
		"title": "让程序员当场破防",
		"desc": "把程序员的冰美式撞翻在青轴机械键盘上",
		"completed": false
	},
	"sq_steal_pen": {
		"title": "打破商业闭环",
		"desc": "偷走产品经理画饼用的所有白板马克笔",
		"completed": false
	},
	"sq_room_brawl": {
		"title": "抢会议室修罗场",
		"desc": "交换会议室预订门牌，引发两大部门总监当场开撕",
		"completed": false
	},
	"sq_leak_salary": {
		"title": "薪酬倒挂大白天下",
		"desc": "撞开保密文件柜，让应届生薪酬表在中央空调风口起飞",
		"completed": false
	},
	"sq_comfort_intern": {
		"title": "整顿职场温情一击",
		"desc": "给楼梯间偷偷哭泣的实习生叼去一包威化饼干",
		"completed": false
	},
	"sq_raid_fridge": {
		"title": "扫荡高管专享冷柜",
		"desc": "把茶水间高管小冰箱里的瑞士卷和车厘子炫光",
		"completed": false
	},
	"sq_mega_oink": {
		"title": "发出反叛的猪叫",
		"desc": "在全静音办公区发出最大音量的反抗之吼！",
		"completed": false
	}
}

# 搞事统计
var stats = {
	"oink_count": 0,
	"chairs_pushed": 0,
	"items_destroyed": 0,
	"time_spent": 0.0
}

func _ready() -> void:
	print("[GameManager] 《特立独行的猪》主线与支线故事系统已就绪！")

func complete_main_quest(quest_id: String) -> void:
	if main_quests.has(quest_id) and not main_quests[quest_id]["completed"]:
		main_quests[quest_id]["completed"] = true
		objective_updated.emit("main", quest_id, true)
		print("[MainQuest] 主线完成: ", main_quests[quest_id]["title"])

func complete_side_quest(quest_id: String) -> void:
	if side_quests.has(quest_id) and not side_quests[quest_id]["completed"]:
		side_quests[quest_id]["completed"] = true
		objective_updated.emit("side", quest_id, true)
		print("[SideQuest] 支线恶作剧达成: ", side_quests[quest_id]["title"])

func get_current_main_objective() -> String:
	for q_id in ["m1_escape_box", "m2_inspect_elevator", "m3_distract_director", "m4_steal_badge", "m5_bypass_hr", "m6_escape_elevator"]:
		if not main_quests[q_id]["completed"]:
			return "%s: %s" % [main_quests[q_id]["title"], main_quests[q_id]["desc"]]
	return "所有主线已完成！准备逃出生天！"

func select_character(type: CharacterType) -> bool:
	if not unlocked_characters.get(type, false):
		return false
	current_character = type
	character_selected.emit("pig")
	return true

func set_language(lang: String) -> void:
	if lang == "zh_CN" or lang == "en":
		current_language = lang
		language_changed.emit(lang)
