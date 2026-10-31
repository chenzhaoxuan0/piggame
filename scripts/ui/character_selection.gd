extends Control

# Character Selection Screen (角色选择界面)
# 核心主旨：从容自洽、体面生活、守住内心的火

@onready var btn_pig = $VBoxContainer/CharactersRow/CardPig/VBox/BtnSelect
@onready var btn_ox = $VBoxContainer/CharactersRow/CardOx/VBox/BtnSelect
@onready var btn_horse = $VBoxContainer/CharactersRow/CardHorse/VBox/BtnSelect
@onready var btn_sheep = $VBoxContainer/CharactersRow/CardSheep/VBox/BtnSelect

@onready var btn_lang_zh = $BottomBar/HBoxContainer/BtnLangZH
@onready var btn_lang_en = $BottomBar/HBoxContainer/BtnLangEN
@onready var info_label = $VBoxContainer/InfoBanner/LabelInfo

var characters_desc = {
	"pig": {
		"title": "老朱 (特立独行的猪 - MVP主角)",
		"subtitle": "【资深业务架构师 · 从容自洽】",
		"desc": "“不能飞的猪，就只是一只普通的猪。”\n认清生活的规训后，依然选择从容而体面地活出自己，在黄昏的办公室照亮身边的同伴。",
		"unlocked": true
	},
	"ox": {
		"title": "老李 (老黄牛)",
		"subtitle": "【核心系统开发骨干】",
		"desc": "埋头苦干的资深工程师，正在老朱的点拨下学会放下无谓的焦虑与自责，找回生活的节奏。(后续篇章)",
		"unlocked": false
	},
	"sheep": {
		"title": "小杨 (领头羊)",
		"subtitle": "【新锐产品策划实习生】",
		"desc": "刚刚步入职场的年轻人，逐渐明白真诚与敏感并不是弱点，而是未被磨平的宝贵棱角。(后续篇章)",
		"unlocked": false
	},
	"horse": {
		"title": "神秘马",
		"subtitle": "【远行探索者】",
		"desc": "在更宽广的世界探寻属于自我的边界，敬请期待！(后续篇章)",
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
	print("[CharacterSelect] 选择【老朱】！开启周五傍晚 19:15 的 5 分钟哲学治愈之旅...")
	GameManager.select_character(GameManager.CharacterType.PIG)
	get_tree().change_scene_to_file("res://scenes/levels/office_level_1.tscn")

func _on_locked_selected(char_key: String) -> void:
	update_info_display(char_key)

func _on_lang_zh_selected() -> void:
	GameManager.set_language("zh_CN")
	btn_lang_zh.modulate = Color.WHITE
	btn_lang_en.modulate = Color(0.6, 0.6, 0.6, 0.6)

func _on_lang_en_selected() -> void:
	if info_label:
		info_label.text = "【系统提示】English language is coming soon! 当前阶段优先打磨原生中文职场哲学叙事！"
