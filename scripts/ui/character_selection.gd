extends Control

# Character Selection Screen (《一口猪在金牌农场》围城多视角选择)
# 核心机制：同一个悬崖箱庭，不同动物视角，相互羡慕，相互救赎

const UI = preload("res://scripts/ui/ui_kit.gd")

@onready var btn_pig = $VBoxContainer/CharactersRow/CardPig/VBox/BtnSelect
@onready var btn_ox = $VBoxContainer/CharactersRow/CardOx/VBox/BtnSelect
@onready var btn_horse = $VBoxContainer/CharactersRow/CardHorse/VBox/BtnSelect
@onready var btn_sheep = $VBoxContainer/CharactersRow/CardSheep/VBox/BtnSelect

@onready var btn_lang_zh = $BottomBar/HBoxContainer/BtnLangZH
@onready var btn_lang_en = $BottomBar/HBoxContainer/BtnLangEN
@onready var info_label = $VBoxContainer/InfoBanner/LabelInfo

var characters_desc = {
	"pig": {
		"title": "一口猪 (MVP核心视角)",
		"subtitle": "【悬崖边的清醒者 · 用智慧给同伴松绑】",
		"desc": "在猪的视角里，你看不到自己的危险，只看到阿牛在死磕石头、绵绵因自卑抽泣、追风在泥圈打转。\n你用大智慧与硬拱嘴给它们解开枷锁，乘悬崖木吊厢滑向旷野。\n【围城提示】：想看猪自己的隐秘故事，需在后续篇章选择其他动物！",
		"unlocked": true
	},
	"ox": {
		"title": "阿牛 (老耕牛视角)",
		"subtitle": "【力拔千钧 · 撞碎屠宰门】",
		"desc": "在牛的视角里，牛心疼那口整天吃了睡的猪：它不知道下个月就要被宰了！牛用一身蛮力撞破屠宰场大门去救猪。(后续篇章)",
		"unlocked": false
	},
	"sheep": {
		"title": "绵绵 (小绵羊视角)",
		"subtitle": "【以柔克刚 · 守护奔腾】",
		"desc": "在羊的视角里，羊羡慕马能跑，却心疼马每天在泥圈里跑得蹄子裂开，羊用自己最柔软的细毛给马编织护蹄套。(后续篇章)",
		"unlocked": false
	},
	"horse": {
		"title": "追风 (烈马视角)",
		"subtitle": "【疾风破障 · 绝地奔腾】",
		"desc": "在马的视角里，马看到弱小的羊总被猎犬威吓，马放开四蹄以狂风般的速度带着羊群跃出牢笼。(后续篇章)",
		"unlocked": false
	}
}

func _ready() -> void:
	UI.apply(self)
	$Background.color = UI.PAPER_DEEP
	for card_name in ["CardPig", "CardOx", "CardHorse", "CardSheep"]:
		var card: PanelContainer = get_node_or_null("VBoxContainer/CharactersRow/" + card_name)
		if card:
			card.add_theme_stylebox_override("panel", UI.patch(20, UI.PAPER, Vector2(18, 16)))
			UI.stitch_rect(card, UI.PINK if card_name == "CardPig" else UI.SAGE, 8.0, 15.0)
			var btn: Button = card.get_node_or_null("VBox/BtnSelect")
			if btn:
				for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
					btn.add_theme_color_override(c, UI.INK)
			if card_name != "CardPig":
				card.modulate = Color(1, 1, 1, 0.72)
	var pig_name: Label = get_node_or_null("VBoxContainer/CharactersRow/CardPig/VBox/Name")
	if pig_name:
		pig_name.add_theme_color_override("font_color", UI.CORAL)
	var pig_role: Label = get_node_or_null("VBoxContainer/CharactersRow/CardPig/VBox/Role")
	if pig_role:
		pig_role.add_theme_color_override("font_color", UI.INK_SOFT)
	var info: PanelContainer = get_node_or_null("VBoxContainer/InfoBanner")
	if info:
		info.add_theme_stylebox_override("panel", UI.patch(16, UI.WHITE, Vector2(20, 12)))
	$VBoxContainer/Header/Title.add_theme_color_override("font_color", UI.TEAL_DEEP)
	$VBoxContainer/Header/Title.add_theme_font_override("font", UI.font_bold())
	$VBoxContainer/Header/SubTitle.add_theme_color_override("font_color", UI.INK_SOFT)
	$VBoxContainer/InfoBanner/LabelInfo.add_theme_color_override("font_color", UI.INK)
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
	print("[CharacterSelect] 选择【一口猪】视角！开启悬崖边的金牌农场旷野突围之旅...")
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
		info_label.text = "【系统提示】English language is coming soon! 当前阶段优先打磨原生金牌农场围城寓言！"
