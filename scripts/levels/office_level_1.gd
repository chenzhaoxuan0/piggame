extends Node3D

# 关卡控制器：《一口猪在金牌农场》第一篇章
# 场景：悬崖边的金牌农场 (The Cliffside Golden Farm)
# 核心机制：
# 1. 悬崖残墙处与老岩羊对话，拿到旧索道插销
# 2. 深入大院，以简短有力的智慧点醒阿牛 (牛)、绵绵 (羊)、追风 (马)
# 3. 面对管家犬老张，质问“金牌能嚼得动吗”，跨越石道
# 4. 前往悬崖边木质吊厢，将插销撞入卡槽，缆车滑入原野

@onready var player: PigController = $Pig
@onready var camera = $IsometricCamera
@onready var hud = $HUD

# 对话 UI 节点
@onready var dialogue_box = $HUD/DialogueBox
@onready var avatar_label = $HUD/DialogueBox/Margin/VBox/Header/Avatar
@onready var speaker_label = $HUD/DialogueBox/Margin/VBox/Header/NameVBox/LabelSpeaker
@onready var title_label = $HUD/DialogueBox/Margin/VBox/Header/NameVBox/LabelTitle
@onready var content_label = $HUD/DialogueBox/Margin/VBox/LabelContent
@onready var options_container = $HUD/DialogueBox/Margin/VBox/OptionsContainer

@onready var objective_label = $HUD/ObjectivePanel/LabelObjective
@onready var cablecar_cabin = $FarmEnvironment/CableCarArea/CableCarCabin
@onready var click_indicator = $Pig/ClickIndicator

# 进程状态
var met_goat: bool = false
var met_aniu: bool = false
var met_mianmian: bool = false
var met_zhuifeng: bool = false
var met_laozhang: bool = false
var is_game_finished: bool = false

func _ready() -> void:
	print("[Level1] 《一口猪在金牌农场》启动！")
	
	if player:
		player.moved_to_target.connect(_on_player_moved_to_target)
		player.reached_interactable.connect(_on_player_reached_interactable)
	
	# 开局自动弹出悬崖边老岩羊对话
	get_tree().create_timer(0.4).timeout.connect(func():
		open_dialogue("cliff_goat_intro")
		met_goat = true
	)

func _on_player_moved_to_target(pos: Vector3) -> void:
	if click_indicator:
		click_indicator.global_position = Vector3(pos.x, 0.05, pos.z)
		click_indicator.visible = true
		var tween = create_tween()
		click_indicator.scale = Vector3(0.5, 0.5, 0.5)
		tween.tween_property(click_indicator, "scale", Vector3(1.2, 1.2, 1.2), 0.25)
		tween.tween_property(click_indicator, "scale", Vector3.ZERO, 0.2)
		tween.tween_callback(func(): click_indicator.visible = false)

func _on_player_reached_interactable(target: Node3D) -> void:
	print("[Level1] 到达目标: ", target.name)
	
	if target.is_in_group("npc_cliff_goat"):
		open_dialogue("cliff_goat_intro")
	elif target.is_in_group("npc_aniu"):
		open_dialogue("aniu_interaction")
		met_aniu = true
		check_progress()
	elif target.is_in_group("npc_mianmian"):
		open_dialogue("mianmian_interaction")
		met_mianmian = true
		check_progress()
	elif target.is_in_group("npc_zhuifeng"):
		open_dialogue("zhuifeng_interaction")
		met_zhuifeng = true
		check_progress()
	elif target.is_in_group("npc_laozhang"):
		open_dialogue("laozhang_interaction")
		met_laozhang = true
		check_progress()
	elif target.is_in_group("cablecar_button"):
		handle_cablecar_interact()
	elif target.is_in_group("milk_jug"):
		if target is RigidBody3D:
			target.apply_impulse(Vector3(0.8, 1.4, 0.6) * 2.2)

func check_progress() -> void:
	if met_aniu and met_mianmian and met_zhuifeng and met_laozhang:
		objective_label.text = "🎯 农庄的枷锁已全部松开。前往悬崖木吊厢，推下插销奔向广阔人间！"
	elif met_aniu and met_mianmian and met_zhuifeng:
		objective_label.text = "🎯 三位同伴已觉醒！穿过中央石板路，面对摇晃铜铃的管家犬老张。"
	else:
		objective_label.text = "🎯 漫步于悬崖边的金牌农庄，顺路给大院里的牛、羊、马松松绑。"

func handle_cablecar_interact() -> void:
	if is_game_finished:
		return
	is_game_finished = true
	open_dialogue("cablecar_final")
	
	# 缆车吊厢在落日熔金的万丈绝壁上滑出
	if cablecar_cabin:
		var tween = create_tween()
		tween.tween_property(cablecar_cabin, "position", cablecar_cabin.position + Vector3(15.0, -6.0, 10.0), 3.8)

func open_dialogue(node_key: String) -> void:
	var node_data = DialogueManager.get_dialogue_node(node_key)
	if node_data.is_empty():
		close_dialogue()
		return

	if dialogue_box:
		dialogue_box.visible = true
		avatar_label.text = node_data.get("avatar", "🐷")
		speaker_label.text = node_data.get("speaker", "神秘生灵")
		title_label.text = node_data.get("title", "")
		content_label.text = node_data.get("content", "")

		for child in options_container.get_children():
			child.queue_free()

		var options = node_data.get("options", [])
		for opt in options:
			var btn = Button.new()
			btn.text = "▶ " + opt.get("text", "继续")
			btn.custom_minimum_size = Vector2(0, 36)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var next_key = opt.get("next", "")
			btn.pressed.connect(func():
				_on_option_selected(next_key)
			)
			options_container.add_child(btn)

func _on_option_selected(next_key: String) -> void:
	if next_key == "":
		close_dialogue()
	elif next_key == "game_win":
		close_dialogue()
		show_end_screen()
	else:
		open_dialogue(next_key)

func close_dialogue() -> void:
	if dialogue_box:
		dialogue_box.visible = false

func show_end_screen() -> void:
	var end_panel = $HUD/EndScreenPanel
	if end_panel:
		end_panel.visible = true
