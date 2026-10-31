extends Control

# Character Selection Screen (角色选择界面 - 纯正动物寓言版)
# 核心主旨：真正特立独行的猪，自由图腾，拒绝被规训

@onready var btn_pig = $VBoxContainer/CharactersRow/CardPig/VBox/BtnSelect
@onready var btn_ox = $VBoxContainer/CharactersRow/CardOx/VBox/BtnSelect
@onready var btn_horse = $VBoxContainer/CharactersRow/CardHorse/VBox/BtnSelect
@onready var btn_sheep = $VBoxContainer/CharactersRow/CardSheep/VBox/BtnSelect

@onready var btn_lang_zh = $BottomBar/HBoxContainer/BtnLangZH
@onready var btn_lang_en = $BottomBar/HBoxContainer/BtnLangEN
@onready var info_label = $VBoxContainer/InfoBanner/LabelInfo

var characters_desc = {
	"pig": {
		"title": "特立独行的猪 (MVP核心唯一主角)",
		"subtitle": "【王小波式的自由图腾 · 拒绝被规训】",
		"desc": "一头活生生的、敏捷健康的猪。嘴叼干麦穗，长着山羊般轻健的蹄子，喜欢在红谷仓屋顶乘凉。\n看透农庄的精细化规训，以猪拱嘴顶飞顽石、以从容温厚抚慰同伴，乘后山缆车奔向辽阔荒野。",
		"unlocked": true
	},
	"ox": {
		"title": "阿牛 (老耕牛)",
		"subtitle": "【力竭耕耘的耕作骨干】",
		"desc": "被沉重铁犁死死勒住的老黄牛，在猪的顶石点化下卸下枷锁，明白大地亦懂冬眠休养。(后续篇章)",
		"unlocked": false
	},
	"sheep": {
		"title": "绵绵 (小绵羊)",
		"subtitle": "【刚被剪毛的小绵羊】",
		"desc": "因毛质太软被评为三等次品而暗自抽泣的小羊，懂得云朵天生就是柔软的，守护原生真诚。(后续篇章)",
		"unlocked": false
	},
	"horse": {
		"title": "烈马 (奔腾马)",
		"subtitle": "【远方探索者】",
		"desc": "在农庄篱笆之外的无垠原野探寻自由边界，敬请期待！(后续篇章)",
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
	print("[CharacterSelect] 选择【特立独行的猪】！开启黄昏阳光农庄的 5 分钟动物寓言之旅...")
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
		info_label.text = "【系统提示】English language is coming soon! 当前阶段优先打磨原生田园现代动物寓言！"
