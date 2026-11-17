extends Node

# AchievementManager — 《一口猪在金牌农场》成就系统（autoload）。
# 36 枚成就覆盖全流程：故事 5 + 伙伴 3 + 闯关 4 + 身手 3 + 农场玩场 17 + 二周目 5。
# 2026-11-16 #6：林间远射手随林间分赛场一起退役（马场没有卷心菜可踢，
# 实战不可达成），卷心菜全满贯改为三门。
# 2026-11-16 #1/#2：羊矮棚新增除草机（杂草区啃食）与落水猪（水池首游）。
# 2026-11-16 #4/#5：35 秒纪录改由马场计时赛真实圈速驱动（大院只报金牌杯
# 最佳），圈赛章一枚：稳稳一圈（近道竞速 2026-11-17 实机反馈删除，只留原跑道）。
# 2026-11-16 #19：围栏开缺口 + 圈外崖边草带（马场），新增越狱惯犯。
# 解锁来源两层：状态驱动（监听 GameManager.state_changed 回读字段，reset_run
# 发的信号字段全 false 天然无副作用）+ 关卡侧直挂（管道发现/闪避/QTE/破纪录/
# 开场拱槽）。进度跨局持久化到 user://achievements.json —— 这是仓库唯一的
# 存档文件：游戏运行进度仍无存档（契约口径见 DEMO_AGENT_CONTRACT）。
# 解锁弹窗自包含（自带 CanvasLayer layer 11，盖过 meme 层的 10 与 HUD 的 1），
# 队列化依次展示，不与 ToastBanner 抢同一个面板。

signal achievement_unlocked(id: String)

const UI = preload("res://scripts/ui/ui_kit.gd")
const DEFAULT_SAVE_PATH := "user://achievements.json"

# 顺序即成就墙的展示顺序。
const DEFS := [
	{"id": "nightmare_survivor", "title": "从噩梦中醒来", "desc": "完整经历了那场屠宰场之梦，并在冷汗里记住了六点的运牲车。"},
	{"id": "red_pin", "title": "红色的生锈插销", "desc": "叼起铜插销，撞断了猪圈的木栓——红色抉择，当夜出逃。"},
	{"id": "warm_mud", "title": "温热的泥浆", "desc": "选了蓝色的安稳：回到泥窝，吃那把甜料。结局一「安稳的肉馅」。"},
	{"id": "showdown_winner", "title": "意志的对决", "desc": "在后山大铁门前，三回合舌战农场主，赢得意志对决。"},
	{"id": "maverick_pioneer", "title": "特立独行的先驱", "desc": "铜插销插进绞盘，木吊厢冲向金色麦浪。结局二「旷野归途」。"},
	{"id": "ox_friend", "title": "卸下重轭", "desc": "帮阿牛认出犁下的花岗岩，学会了【坚韧挣脱】。"},
	{"id": "sheep_friend", "title": "走出阴影", "desc": "踢飞残次牌，让绵绵晒到了太阳，学会了【破妄明眸】。"},
	{"id": "horse_friend", "title": "告诉它真相", "desc": "把纪录榜的真相说给追风听，学会了【疾风冲刺】。"},
	{"id": "pipe_explorer", "title": "管道探险家", "desc": "发现了第一根超级绿水管——农场地下的隐藏赛道网。"},
	{"id": "gate_crasher", "title": "冲破大铁门", "desc": "在大院赛道撞开了农场主的大铁门。"},
	{"id": "all_courses", "title": "四通八达", "desc": "跑通了全部四条隐藏赛道：牛耕地、溪谷、林间、大院。"},
	{"id": "record_breaker", "title": "35 秒新纪录", "desc": "在马场跑道计时赛跑进 35 秒，把名字钉上了纪录榜。"},
	{"id": "first_dodge", "title": "千钧一发", "desc": "看准红圈，第一次闪避成功。"},
	{"id": "grapple_escape", "title": "挣脱本能", "desc": "第一次在恶犬的扑咬下狂点挣脱（QTE）成功。"},
	{"id": "trough_sniff", "title": "哼哼初试", "desc": "还没入梦，就在开场猪圈里拱了拱食槽。"},
	{"id": "cabbage_striker", "title": "卷心菜前锋", "desc": "在牛耕地球会，把卷心菜一脚踢进了球门。"},
	{"id": "cabbage_goal_pitch", "title": "牛耕地金靴", "desc": "把卷心菜踢进了牛耕地球会的联赛球门。"},
	{"id": "cabbage_goal_pen", "title": "猪圈点球王", "desc": "把卷心菜踢进了猪圈后院的分赛场球门。"},
	{"id": "cabbage_goal_creek", "title": "溪桥漂流手", "desc": "把卷心菜一路踢进了溪桥边的分赛场球门。"},
	{"id": "cabbage_grand_slam", "title": "卷心菜全满贯", "desc": "三大球门全部命中：牛耕地、猪圈、溪桥——全农场的网都被你踢穿过。"},
	{"id": "second_path", "title": "第二条路", "desc": "用肩膀（和冲刺）顶开了下山路上那根倒木——不只有跳这一条路。"},
	{"id": "demolition_crew", "title": "拆家小队", "desc": "全农场的农具都在发抖——随便挑五件，全都被你撞翻了一遍。"},
	{"id": "lawn_mower", "title": "除草机", "desc": "羊矮棚旁的杂草区被你啃得寸草不留——十二株，一株不剩。"},
	{"id": "pig_paddle", "title": "落水猪", "desc": "扑通！羊棚草甸的水池里溅起了猪形水花。"},
	{"id": "steady_lap", "title": "稳稳一圈", "desc": "和纪录牌约好后，老老实实沿马场跑道跑完一整圈回到起点。"},
	{"id": "fence_breaker", "title": "越狱惯犯", "desc": "从围栏的缺口钻了出去，站上了圈外的崖边野草带——风是自由的味道。"},
	{"id": "grass_gourmet", "title": "食草动物的本分", "desc": "啃遍了下山路上全部六丛嫩草。"},
	{"id": "perfect_dive", "title": "满分入坑", "desc": "从山坡跳进草垛，麻雀评委打出了 10 分。"},
	{"id": "potato_harvest", "title": "春耕的馈赠", "desc": "在牛耕地的犁沟里拱出了全部五颗土豆。"},
	{"id": "apple_rain", "title": "牛顿的苹果", "desc": "撞下马场苹果树的苹果雨，并当场吃完三颗。"},
	{"id": "plunger_knight", "title": "马桶骑士", "desc": "在迷雾林间用马桶搋子正中面门，把三只恶犬吸倒在地。"},
	{"id": "second_visit", "title": "再见围城", "desc": "通关一次后再入农场：全部伙伴之力从醒来起随身。手推车和苹果树，这次顺路解决。"},
	{"id": "second_escape", "title": "旧路重逃", "desc": "二周目再次滑向旷野——这一次，每一步都是自己选的。"},
	{"id": "reunion_tour", "title": "老友重逢", "desc": "二周目里再帮阿牛、绵绵、追风把心结各解了一遍。"},
	{"id": "both_doors", "title": "两扇门都看过", "desc": "同一个档案里，既在温饱里睡去过，也奔向过旷野。"},
	{"id": "full_ledger", "title": "金牌农场全纪录", "desc": "其余每一枚成就都到手——墙上一格不空。"},
]

var unlocked := {} # id -> true
var save_path := DEFAULT_SAVE_PATH

var _queue: Array[String] = []
var _showing := false
var _popup: PanelContainer
var _popup_title: Label
var _popup_desc: Label

func _ready() -> void:
	# headless（测试进程）绝不碰真实成就档：测试与玩家游戏并发读写同一个
	# achievements.json 会互相覆盖丢档（2026-11-17 实机反馈：一周目成就莫名
	# 消失）。测试要验证持久化就显式重定向 save_path（game_manager 同款纪律）。
	if DisplayServer.get_name() == "headless" and save_path == DEFAULT_SAVE_PATH:
		save_path = "user://test_achievements.json"
	_load()
	_build_popup()
	# 状态驱动解锁：信号无参，回读字段比对（reset_run 也发此信号，字段全 false）。
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed() # 开机即对账（跳过序章等入口已置位的情况）

func _on_state_changed() -> void:
	if GameManager.intro_dream_done:
		unlock("nightmare_survivor")
	if GameManager.has_pin:
		unlock("red_pin")
	if GameManager.ending == "stay":
		unlock("warm_mud")
	if GameManager.stage == "cablecar_ready" or GameManager.ending == "escape":
		unlock("showdown_winner") # the blue ending's stage="ending" must NOT count
	if GameManager.ending == "escape":
		unlock("maverick_pioneer")
	for pair in [["ox", "ox_friend"], ["sheep", "sheep_friend"], ["horse", "horse_friend"]]:
		if GameManager.npc_completed.get(pair[0], false):
			unlock(pair[1])
	if GameManager.chase_completed.get("chase_final", false):
		unlock("gate_crasher")
	var all_clear := true
	for done in GameManager.chase_completed.values():
		all_clear = all_clear and done
	if all_clear:
		unlock("all_courses")
	# 二周目组：档案第二次逃离付费；NG+ 一局内三位伙伴全部重逢付费。
	if GameManager.ending == "escape" and GameManager.finished_runs >= 2:
		unlock("second_escape")
	if GameManager.ng_plus and GameManager.npc_completed.get("ox", false) \
			and GameManager.npc_completed.get("sheep", false) and GameManager.npc_completed.get("horse", false):
		unlock("reunion_tour")

func unlock(id: String) -> bool:
	if _def_index(id) < 0:
		push_warning("Unknown achievement id: " + id)
		return false
	if unlocked.has(id):
		return false
	unlocked[id] = true
	_save()
	_queue.append(id)
	_pump()
	achievement_unlocked.emit(id)
	# 全收集 meta：其余每一枚都到手时自动点亮（full_ledger 自身除外，防递归）。
	if id != "full_ledger" and not unlocked.has("full_ledger") and unlocked.size() >= DEFS.size() - 1:
		unlock("full_ledger")
	return true

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func unlocked_count() -> int:
	return unlocked.size()

func total() -> int:
	return DEFS.size()

func get_def(id: String) -> Dictionary:
	var index := _def_index(id)
	return DEFS[index] if index >= 0 else {}

func reset_progress(wipe_file := false) -> void:
	unlocked.clear()
	_queue.clear()
	_showing = false
	if is_instance_valid(_popup):
		_popup.modulate.a = 0.0
	if wipe_file:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
		# .bak 一并清掉：否则空主档会让 _load 回退"复活"刚被玩家清空的成就。
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".bak"))

func _def_index(id: String) -> int:
	for i in DEFS.size():
		if DEFS[i]["id"] == id:
			return i
	return -1

# ------------------------------------------------------------- persistence
func _load() -> void:
	# 主档三种坏态（缺失/打不开/解析失败）都不提前 return——统一落到下面
	# 的 .bak 回退：半截 JSON 也是真实事故形态（2026-11-17 review 抓出原
	# 实现解析失败直接放弃，自愈永远轮不到）。
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for id in parsed.get("unlocked", []):
					if _def_index(str(id)) >= 0:
						unlocked[str(id)] = true
	# 空档回退：主档被并发覆盖成空/半截时，用上一次成功的备份自愈（写前
	# 备份，.bak 永远落后主档一个版本）。
	if unlocked.is_empty() and FileAccess.file_exists(save_path + ".bak"):
		var bak := FileAccess.open(save_path + ".bak", FileAccess.READ)
		if bak != null:
			var bak_parsed = JSON.parse_string(bak.get_as_text())
			if bak_parsed is Dictionary:
				for id in bak_parsed.get("unlocked", []):
					if _def_index(str(id)) >= 0:
						unlocked[str(id)] = true

func _save() -> void:
	# 写前把上一版留进 .bak——必须在 WRITE 打开主档【之前】完成：Godot 的
	# WRITE 在 open 瞬间就截断文件，先开主档再去读"上一版"只能读到空串，
	# 备份就成了永远空文件的死功能（2026-11-17 review P1-2 实测抓出）。
	if FileAccess.file_exists(save_path):
		var prev := FileAccess.open(save_path, FileAccess.READ)
		if prev != null:
			var prev_text := prev.get_as_text()
			prev.close()
			var bak := FileAccess.open(save_path + ".bak", FileAccess.WRITE)
			if bak != null:
				bak.store_string(prev_text)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return # 只读环境下静默降级为仅内存
	file.store_string(JSON.stringify({"unlocked": unlocked.keys()}))

# ------------------------------------------------------------- unlock popup
func _build_popup() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AchievementLayer"
	layer.layer = 11 # over meme layer (10) and the HUD (default 1)
	add_child(layer)

	_popup = UI.patch_panel(16, UI.PAPER, UI.SUNNY, Vector2(18, 10))
	_popup.name = "AchievementPopup"
	# Pin a zero-size point 24 px in from the bottom-right corner, then let the
	# panel auto-size to its content growing LEFT and UP (offset presets with
	# placeholder text would pin a stale size and shove it off-screen).
	# 右下角与彩蛋通知流（NoticeFeed，HUD 层）同区：通知流底边抬高到弹窗上方。
	_popup.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_popup.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_popup.offset_left = -24
	_popup.offset_right = -24
	_popup.offset_top = -24
	_popup.offset_bottom = -24
	_popup.modulate.a = 0.0
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_popup)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_popup.add_child(row)
	var medal := UI.label("🏅", 34)
	row.add_child(medal)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var tag := UI.name_tag("成就解锁！", UI.SUNNY, UI.INK, 13)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	text.add_child(tag)
	_popup_title = UI.label("？", 20, UI.TEAL_DEEP, true)
	text.add_child(_popup_title)
	_popup_desc = UI.label("？", 13, UI.INK_SOFT)
	text.add_child(_popup_desc)

func _pump() -> void:
	if _showing or _queue.is_empty():
		return
	_showing = true
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		var def := get_def(id)
		if def.is_empty():
			continue
		_popup_title.text = str(def["title"])
		_popup_desc.text = str(def["desc"])
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_popup, "modulate:a", 1.0, 0.22)
		tween.tween_property(_popup, "scale", Vector2.ONE, 0.22).from(Vector2(0.9, 0.9))
		await get_tree().create_timer(2.4).timeout
		var fade := create_tween()
		fade.tween_property(_popup, "modulate:a", 0.0, 0.3)
		await fade.finished
	_showing = false
