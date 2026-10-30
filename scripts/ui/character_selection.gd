extends Control

# Character Selection Screen (角色选择界面)
# 4大主角：特立独行的猪(可选)、老黄牛(锁)、神秘马(锁)、领头羊(锁)
# 底部语言选择：中文(默认)、English(未开放)

@onready var btn_pig = $VBoxContainer/CharactersRow/CardPig/BtnSelect
@onready var btn_ox = $VBoxContainer/CharactersRow/CardOx/BtnSelect
@onready var btn_horse = $VBoxContainer/CharactersRow/CardHorse/BtnSelect
@onready var btn_sheep = $VBoxContainer/CharactersRow/CardSheep/BtnSelect

@onready var btn_lang_zh = $BottomBar/HBoxContainer/BtnLangZH
@onready var btn_lang_en = $BottomBar/HBoxContainer/BtnLangEN
@onready var info_label = $VBoxContainer/InfoBanner/LabelInfo

var characters_desc = {
	"pig": {
		"title": "特立独行的猪 (MVP主角)",
		"subtitle": "【觉醒摸鱼者】绝不做KPI的饲料",
		"desc": "目标：逃出大厂写字楼！一路突破开放工位与会议室封锁，冲向电梯下行！",
		"unlocked": true
	},
	"ox": {
		"title": "老黄牛 (锁定中)",
		"subtitle": "【卷王之王】任劳任怨的代码耕耘者",
		"desc": "目标：克服一切险阻，历经千难万险必须回到工位提交周报！(后续章节开放)",
		"unlocked": false
	},
	"sheep": {
		"title": "领头羊 (锁定中)",
		"subtitle": "【汇报大师】精通中英双语与顶层设计",
		"desc": "目标：一路向阳直通顶楼董事会，给CEO做震撼PPT闭环汇报！(后续章节开放)",
		"unlocked": false
	},
	"horse": {
		"title": "神秘马 (企划中)",
		"subtitle": "【奔腾黑马】35岁危机前的跑路先锋",
		"desc": "目标：未知命运，猎头、转正还是空降？敬请期待！(后续章节开放)",
		"unlocked": false
	}
}

func _ready() -> void:
	update_info_display("pig")
	setup_connections()

func setup_connections() -> void:
	if btn_pig:
		btn_pig.pressed.connect(_on_pig_selected)
	if btn_ox:
		btn_ox.pressed.connect(func(): _on_locked_selected("ox"))
	if btn_horse:
		btn_horse.pressed.connect(func(): _on_locked_selected("horse"))
	if btn_sheep:
		btn_sheep.pressed.connect(func(): _on_locked_selected("sheep"))
		
	if btn_lang_zh:
		btn_lang_zh.pressed.connect(_on_lang_zh_selected)
	if btn_lang_en:
		btn_lang_en.pressed.connect(_on_lang_en_selected)

func update_info_display(char_key: String) -> void:
	var info = characters_desc[char_key]
	if info_label:
		info_label.text = "%s - %s\n%s" % [info["title"], info["subtitle"], info["desc"]]

func _on_pig_selected() -> void:
	print("[CharacterSelect] 选中【特立独行的猪】！准备进入办公室第3层逃脱关卡...")
	GameManager.select_character(GameManager.CharacterType.PIG)
	# 切换到第一关场景
	get_tree().change_scene_to_file("res://scenes/levels/office_level_1.tscn")

func _on_locked_selected(char_key: String) -> void:
	update_info_display(char_key)
	print("[CharacterSelect] %s 角色仍在封闭开发中！" % char_key)

func _on_lang_zh_selected() -> void:
	GameManager.set_language("zh_CN")
	btn_lang_zh.modulate = Color.WHITE
	btn_lang_en.modulate = Color(0.6, 0.6, 0.6, 0.6)

func _on_lang_en_selected() -> void:
	print("[CharacterSelect] English 版本暂未开放，本阶段专注打磨中文梗与本土职场叙事！")
	if info_label:
		info_label.text = "【系统提示】English language is coming soon! 当前阶段优先打磨原生中文职场黑话梗！"

