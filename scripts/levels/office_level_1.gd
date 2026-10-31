extends Node3D

# 第一关控制器：新星模范生态农庄 (Level 1: The Modern Farm Allegory)
# 玩法特征：
# 1. 类似《极乐迪斯科》与《红猪》的寓言深度对话与从容处事智慧
# 2. 2.5D 点击移动 (Point & Click / Tap to Move)
# 3. 类似《Untitled Goose Game》的田园环境物理碰撞互动 (碰翻牛奶桶、推歪木栅栏)

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

# 关卡进程状态
var met_aniu: bool = false
var met_mianmian: bool = false
var met_laozhang: bool = false
var is_game_finished: bool = false

func _ready() -> void:
	print("[Level1] 5分钟农庄寓言治愈体验：《特立独行的猪》启动！")
	
	# 连接玩家点击移动信号
	if player:
		player.moved_to_target.connect(_on_player_moved_to_target)
		player.reached_interactable.connect(_on_player_reached_interactable)
	
	# 开局延迟片刻弹出老朱黄昏沉思
	get_tree().create_timer(0.4).timeout.connect(func():
		open_dialogue("intro_reflection")
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
	print("[Level1] 到达田园交互目标: ", target.name)
	
	if target.is_in_group("npc_aniu"):
		open_dialogue("aniu_interaction")
		met_aniu = true
		check_progress()
	elif target.is_in_group("npc_mianmian"):
		open_dialogue("mianmian_interaction")
		met_mianmian = true
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
			print("[Level1] 碰翻了木制牛奶桶，纯白牛奶浸润了青草地")

func check_progress() -> void:
	if met_aniu and met_mianmian and met_laozhang:
		objective_label.text = "🎯 农庄同伴的心结已解开。向夕阳下的后山索道漫步，乘缆车归家。"
	else:
		objective_label.text = "🎯 漫步于黄昏的阳光农庄，与焦虑的同伴聊两句，前往后山索道。"

func handle_cablecar_interact() -> void:
	if is_game_finished:
		return
	is_game_finished = true
	open_dialogue("cablecar_final")
	
	# 缆车吊厢平滑滑出站台，下行进入群山远景
	if cablecar_cabin:
		var tween = create_tween()
		tween.tween_property(cablecar_cabin, "position", cablecar_cabin.position + Vector3(12.0, -4.0, 8.0), 3.0)

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

		# 清理旧选项
		for child in options_container.get_children():
			child.queue_free()

		# 生成选项按钮 (极乐迪斯科风格选择枝)
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
