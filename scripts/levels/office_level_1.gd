extends Node3D

# 第一关控制器：办公室第3层 (Level 3: Agile Empowerment Zone)
# 驱动完整的主线剧情与支线恶作剧清单系统

@onready var player = $Pig
@onready var camera = $IsometricCamera
@onready var hud = $HUD
@onready var dialogue_box = $HUD/DialogueBox
@onready var speaker_label = $HUD/DialogueBox/VBox/LabelSpeaker
@onready var surface_label = $HUD/DialogueBox/VBox/LabelSurface
@onready var subtext_label = $HUD/DialogueBox/VBox/LabelSubtext
@onready var objective_label = $HUD/ObjectivePanel/LabelObjective
@onready var todo_panel = $HUD/TodoListPanel
@onready var todo_list_label = $HUD/TodoListPanel/VBox/LabelItems
@onready var elevator_door = $OfficeEnvironment/ElevatorArea/ElevatorDoor
@onready var badge_item = $OfficeEnvironment/WorkstationArea/BadgeItem

var has_p8_badge: bool = false
var is_escaped: bool = false

func _ready() -> void:
	print("[Level1] 办公室第3层关卡故事线启动！")
	
	# 开局剧情：从工位纸箱苏醒
	show_dialogue("m1_wake_up")
	refresh_objective_display()
	update_todo_list_text()

	# 连接玩家事件
	if player:
		player.interacted_with.connect(_on_player_interacted)
		player.oink_triggered.connect(_on_player_oinked)
		player.dashed.connect(_on_player_dashed)

func _unhandled_input(event: InputEvent) -> void:
	# Tab 键切换查看搞事清单 (Untitled Goose Game 经典 To-Do List)
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if todo_panel:
			todo_panel.visible = !todo_panel.visible
			if todo_panel.visible:
				update_todo_list_text()

func show_dialogue(dialogue_key: String) -> void:
	var data = DialogueManager.get_dialogue(dialogue_key)
	if dialogue_box:
		dialogue_box.visible = true
		speaker_label.text = "📢 " + data["speaker"]
		surface_label.text = "【明面】 " + data["surface"]
		subtext_label.text = "【扎心暗线】 " + data["subtext"]

func hide_dialogue() -> void:
	if dialogue_box:
		dialogue_box.visible = false

func refresh_objective_display() -> void:
	if objective_label:
		objective_label.text = "🎯 当前主线: " + GameManager.get_current_main_objective()

func update_todo_list_text() -> void:
	if not todo_list_label:
		return
	var text = ""
	for q_id in GameManager.side_quests.keys():
		var q = GameManager.side_quests[q_id]
		var check = "[X] " if q["completed"] else "[  ] "
		var style = " (已完成)" if q["completed"] else ""
		text += "%s%s: %s%s\n" % [check, q["title"], q["desc"], style]
	todo_list_label.text = text

func _on_player_oinked(pos: Vector3) -> void:
	GameManager.stats["oink_count"] += 1
	# 触发支线：发出反叛的猪叫
	if not GameManager.side_quests["sq_mega_oink"]["completed"]:
		GameManager.complete_side_quest("sq_mega_oink")
		update_todo_list_text()

func _on_player_dashed() -> void:
	# 破箱脱困 (主线1)
	if not GameManager.main_quests["m1_escape_box"]["completed"]:
		GameManager.complete_main_quest("m1_escape_box")
		refresh_objective_display()
		show_dialogue("m1_broadcast_start")

func _on_player_interacted(target: Node) -> void:
	print("[Level1] 玩家交互对象: ", target.name)

	# 交互：工牌 (主线4)
	if target.is_in_group("badge") and not has_p8_badge:
		collect_p8_badge()
	
	# 交互：电梯按钮 (主线2 / 主线6)
	elif target.is_in_group("elevator_button"):
		handle_elevator_interact()

	# 交互：咖啡机 / 键盘 (支线1)
	elif target.is_in_group("coffee_machine"):
		if not GameManager.side_quests["sq_break_coffee"]["completed"]:
			GameManager.complete_side_quest("sq_break_coffee")
			show_dialogue("side_coffee_dev")
			update_todo_list_text()

func collect_p8_badge() -> void:
	has_p8_badge = true
	GameManager.complete_main_quest("m4_steal_badge")
	if badge_item:
		badge_item.queue_free()
	show_dialogue("m4_badge_stolen")
	refresh_objective_display()

func handle_elevator_interact() -> void:
	if not has_p8_badge:
		# 主线2：探明电梯锁定
		GameManager.complete_main_quest("m2_inspect_elevator")
		show_dialogue("m2_elevator_locked")
		refresh_objective_display()
	elif not is_escaped:
		# 主线6：刷卡逃离电梯，通关 Demo
		is_escaped = true
		GameManager.complete_main_quest("m6_escape_elevator")
		show_dialogue("m6_elevator_escape")
		refresh_objective_display()
		
		# 电梯开门与通关演出
		if elevator_door:
			var tween = create_tween()
			tween.tween_property(elevator_door, "position:x", elevator_door.position.x + 1.8, 1.2)
			tween.tween_callback(func():
				print("[Level1] 恭喜！特立独行的猪成功踏入电梯，逃离第3层！Demo结束！")
			)

func _on_dialogue_close_pressed() -> void:
	hide_dialogue()
