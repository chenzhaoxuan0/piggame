extends Node3D

# 第一关控制器：周五 19:15 的办公室 (Level 1: Friday Dusk Office)
# 玩法特征：
# 1. 类似《极乐迪斯科》与《红猪》的深度对话与处事哲学
# 2. 2.5D 点击移动 (Point & Click / Tap to Move)
# 3. 类似《Untitled Goose Game》的环境物理碰撞互动 (碰倒杯子、推移椅子)

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
@onready var elevator_door = $OfficeEnvironment/ElevatorArea/ElevatorDoor
@onready var click_indicator = $Pig/ClickIndicator

# 关卡进程状态
var met_laoli: bool = false
var met_xiaoyang: bool = false
var met_director: bool = false
var is_game_finished: bool = false

func _ready() -> void:
	print("[Level1] 5分钟哲学治愈体验：《特立独行的猪》启动！")
	
	# 连接玩家点击移动信号
	if player:
		player.moved_to_target.connect(_on_player_moved_to_target)
		player.reached_interactable.connect(_on_player_reached_interactable)
	
	# 开局延迟半秒弹出老朱内心沉思
	get_tree().create_timer(0.4).timeout.connect(func():
		open_dialogue("intro_reflection")
	)

func _on_player_moved_to_target(pos: Vector3) -> void:
	# 在目标位置播放轻柔的点击光圈指示动画
	if click_indicator:
		click_indicator.global_position = Vector3(pos.x, 0.05, pos.z)
		click_indicator.visible = true
		var tween = create_tween()
		click_indicator.scale = Vector3(0.5, 0.5, 0.5)
		tween.tween_property(click_indicator, "scale", Vector3(1.2, 1.2, 1.2), 0.25)
		tween.tween_property(click_indicator, "scale", Vector3.ZERO, 0.2)
		tween.tween_callback(func(): click_indicator.visible = false)

func _on_player_reached_interactable(target: Node3D) -> void:
	print("[Level1] 到达交互目标: ", target.name)
	
	if target.is_in_group("npc_laoli"):
		open_dialogue("laoli_interaction")
		met_laoli = true
		check_progress()
	elif target.is_in_group("npc_xiaoyang"):
		open_dialogue("xiaoyang_interaction")
		met_xiaoyang = true
		check_progress()
	elif target.is_in_group("npc_director"):
		open_dialogue("director_interaction")
		met_director = true
		check_progress()
	elif target.is_in_group("elevator_button"):
		handle_elevator_interact()
	elif target.is_in_group("coffee_cup"):
		# 趣味物理互动：碰倒杯子
		if target is RigidBody3D:
			target.apply_impulse(Vector3(0.8, 1.2, 0.5) * 2.0)
			print("[Level1] 顺手碰倒了咖啡杯，拿铁慢慢浸润了草稿纸")

func check_progress() -> void:
	if met_laoli and met_xiaoyang and met_director:
		objective_label.text = "🎯 所有伙伴的心结已解开。向夕阳下的电梯厅漫步，从容回家生活。"
	else:
		objective_label.text = "🎯 穿行在黄昏的办公室，与焦虑的伙伴们聊两句，走向电梯。"

func handle_elevator_interact() -> void:
	if is_game_finished:
		return
	is_game_finished = true
	open_dialogue("elevator_final")
	
	# 电梯门徐徐展开
	if elevator_door:
		var tween = create_tween()
		tween.tween_property(elevator_door, "position:x", elevator_door.position.x + 2.0, 1.6)

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
