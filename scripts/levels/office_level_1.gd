extends Node3D

# 关卡控制器：《一口猪在金牌农场》第一篇章 (英雄之旅 · 意志凝聚版)
# 核心机制：
# 1. 悬崖在下方，老岩羊从崖底跃上残墙，给生锈铜插销
# 2. 向上挺进，陌生相遇并点化牛、羊、马，分别汲取【坚忍】、【温柔】与【决绝】三股意志
# 3. 意志齐聚直面中央钟楼老张，铁头撞断高压电闸引出星空
# 4. 索道崖口交付引水图，度化老张，木缆车滑入原野

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

# 英雄意志掌握状态 (从同伴身上学到的意志)
var will_ox: bool = false      # 从老黄牛处学到的【坚忍之骨】
var will_sheep: bool = false   # 从小绵羊处学到的【温柔之心】
var will_horse: bool = false   # 从烈马处学到的【决绝之勇】
var power_cut: bool = false
var is_game_finished: bool = false

func _ready() -> void:
	print("[Level1] 《一口猪在金牌农场》启动！")
	
	if player:
		player.moved_to_target.connect(_on_player_moved_to_target)
		player.reached_interactable.connect(_on_player_reached_interactable)
	
	# 开局自动弹出悬崖边老岩羊对话
	get_tree().create_timer(0.4).timeout.connect(func():
		open_dialogue("cliff_goat_intro")
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
		will_ox = true
		check_hero_progress()
	elif target.is_in_group("npc_mianmian"):
		open_dialogue("mianmian_interaction")
		will_sheep = true
		check_hero_progress()
	elif target.is_in_group("npc_zhuifeng"):
		open_dialogue("zhuifeng_interaction")
		will_horse = true
		check_hero_progress()
	elif target.is_in_group("npc_laozhang"):
		open_dialogue("ordeal_encounter")
		power_cut = true
		check_hero_progress()
	elif target.is_in_group("cablecar_button"):
		handle_cablecar_interact()
	elif target.is_in_group("milk_jug"):
		if target is RigidBody3D:
			target.apply_impulse(Vector3(0.8, 1.4, 0.6) * 2.2)

func check_hero_progress() -> void:
	var wills = []
	if will_ox: wills.append("坚忍之骨")
	if will_sheep: wills.append("温柔之心")
	if will_horse: wills.append("决绝之勇")
	
	if will_ox and will_sheep and will_horse and not power_cut:
		objective_label.text = "🎯 三大意志已凝聚【坚忍·温柔·决绝】！向中央红砖钟楼冲锋，撞碎电闸！"
	elif power_cut:
		objective_label.text = "🌟 高压电闸已碎，星空现世！在全员掩护下，奔赴最上方悬崖索道！"
	else:
		var status = "、".join(wills) if wills.size() > 0 else "无"
		objective_label.text = "🎯 向上探索农庄 · 已领悟意志: [%s] · 继续寻访陌生同伴" % status

func handle_cablecar_interact() -> void:
	if is_game_finished:
		return
	is_game_finished = true
	open_dialogue("cablecar_climax")
	
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
