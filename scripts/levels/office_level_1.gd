extends Node3D

# 关卡控制器：新星模范生态农庄 · 英雄之旅史诗全本
# 核心机制：
# 1. 探索大院，分别点化并唤醒三位盟友：阿牛 (牛)、绵绵 (羊)、追风 (马)
# 2. 前往中央钟楼直面老张 (犬)，撞断总电闸引出漫天繁星
# 3. 奔赴后山索道崖口，交付引水图度化老张，踏上辽阔自由原野

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

# 英雄之旅盟友与进程状态
var met_mentor: bool = false
var met_aniu: bool = false
var met_mianmian: bool = false
var met_zhuifeng: bool = false
var power_cut: bool = false
var is_game_finished: bool = false

func _ready() -> void:
	print("[Level1] 英雄之旅史诗级现代农庄寓言启动！")
	
	if player:
		player.moved_to_target.connect(_on_player_moved_to_target)
		player.reached_interactable.connect(_on_player_reached_interactable)
	
	# 开局弹出阶段4：遇见导师（老岩羊白须的赠言）
	get_tree().create_timer(0.4).timeout.connect(func():
		open_dialogue("mentor_reflection")
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
	print("[Level1] 到达史诗交互目标: ", target.name)
	
	if target.is_in_group("npc_aniu"):
		open_dialogue("aniu_interaction")
		met_aniu = true
		check_hero_progress()
	elif target.is_in_group("npc_mianmian"):
		open_dialogue("mianmian_interaction")
		met_mianmian = true
		check_hero_progress()
	elif target.is_in_group("npc_zhuifeng"):
		open_dialogue("zhuifeng_interaction")
		met_zhuifeng = true
		check_hero_progress()
	elif target.is_in_group("npc_laozhang"):
		# 触发钟楼生死对决
		open_dialogue("ordeal_encounter")
		power_cut = true
		check_hero_progress()
	elif target.is_in_group("cablecar_button"):
		handle_cablecar_interact()
	elif target.is_in_group("milk_jug"):
		if target is RigidBody3D:
			target.apply_impulse(Vector3(0.8, 1.4, 0.6) * 2.2)

func check_hero_progress() -> void:
	if met_aniu and met_mianmian and met_zhuifeng and not power_cut:
		objective_label.text = "🎯 三位同伴已觉醒！前往中央钟楼直面老张，打破规训总闸！"
	elif power_cut:
		objective_label.text = "🌟 总电闸已断，银河星空现世！趁乱奔赴后山索道崖口，迈向自由！"
	else:
		objective_label.text = "🎯 穿行于阳光大院，寻访牛、羊、马三位同伴，解开被规训的心灵枷锁。"

func handle_cablecar_interact() -> void:
	if is_game_finished:
		return
	is_game_finished = true
	open_dialogue("cablecar_climax")
	
	# 缆车在晨光与繁星下徐徐滑向原野
	if cablecar_cabin:
		var tween = create_tween()
		tween.tween_property(cablecar_cabin, "position", cablecar_cabin.position + Vector3(14.0, -5.0, 10.0), 3.5)

func open_dialogue(node_key: String) -> void:
	var node_data = DialogueManager.get_dialogue_node(node_key)
	if node_data.is_empty():
		close_dialogue()
		return

	if dialogue_box:
		dialogue_box.visible = true
		avatar_label.text = node_data.get("avatar", "🐷")
		speaker_label.text = node_data.get("speaker", "神秘人")
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
