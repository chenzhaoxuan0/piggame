extends Node3D

const CHASE_SCRIPT = preload("res://scripts/chase/simple_chase.gd")
@onready var player: PigController = $Pig
@onready var camera: IsometricCamera = $IsometricCamera
@onready var greybox: Node3D = $Greybox
var chase: SimpleChase
var hud: Control
var objective: Label
var status: Label
var prompt: Label
var dialogue_panel: PanelContainer
var speaker_label: Label
var content_label: Label
var options: VBoxContainer
var overlay: ColorRect
var overlay_title: Label
var overlay_text: Label
var overlay_buttons: VBoxContainer
var dialogue_open := false
var cinematic := false
var paused := false
var busy := false
var current_dialogue := ""
var current_options: Array = []
var pressure := 999.0
var pin_visual: MeshInstance3D

func _ready() -> void:
	GameManager.reset_run()
	chase = CHASE_SCRIPT.new()
	add_child(chase)
	chase.finished.connect(_on_chase_finished)
	chase.pressure_changed.connect(func(value: float): pressure = value)
	player.reached_interactable.connect(_on_interact)
	greybox.chase_entered.connect(_start_chase)
	GameManager.state_changed.connect(_refresh_hud)
	_build_hud()
	_build_pin()
	player.reset_at(greybox.get_spawn_position())
	camera.snap_to_target()
	_refresh_hud()
	player.set_control_mode("dialogue")
	await get_tree().create_timer(0.25).timeout
	open_dialogue("cliff_goat_intro")

func _build_pin() -> void:
	pin_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.08, 0.08)
	pin_visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c9984d")
	pin_visual.material_override = material
	player.get_node("VisualMesh").add_child(pin_visual)
	pin_visual.position = Vector3(0, 0.55, -0.9)
	pin_visual.visible = false

func _style(bg: Color, border: Color = Color("52626a")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	return style

func _label(text_value: String, font_size: int = 18) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 44
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(callback)
	return button

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	theme.default_font = font
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", Color("eef1e8"))
	theme.set_stylebox("normal", "Button", _style(Color("2d3e43")))
	theme.set_stylebox("hover", "Button", _style(Color("455b5b"), Color("d6b576")))
	theme.set_stylebox("pressed", "Button", _style(Color("657768")))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color("e3bd70")))
	hud.theme = theme
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 20
	top.offset_bottom = 110
	top.add_theme_stylebox_override("panel", _style(Color(0.09, 0.14, 0.16, 0.94)))
	hud.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 30)
	top.add_child(top_row)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_column)
	title_column.add_child(_label("一口猪在金牌农场", 25))
	objective = _label("", 16)
	title_column.add_child(objective)
	var right := VBoxContainer.new()
	top_row.add_child(right)
	right.add_child(_label("WHITEBOX / 玩法展示  01", 15))
	status = _label("", 15)
	right.add_child(status)
	prompt = _label("", 19)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -420
	prompt.offset_right = 420
	prompt.offset_top = -105
	prompt.offset_bottom = -65
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt)
	var controls := _label("WASD / 方向键 移动    ·    E 交互    ·    鼠标点击前往    ·    Esc 暂停", 15)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -46
	controls.offset_bottom = -15
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(controls)
	dialogue_panel = PanelContainer.new()
	dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_panel.offset_left = 100
	dialogue_panel.offset_right = -100
	dialogue_panel.offset_top = -325
	dialogue_panel.offset_bottom = -65
	dialogue_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.13, 0.15, 0.98), Color("a6aa86")))
	hud.add_child(dialogue_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	dialogue_panel.add_child(column)
	speaker_label = _label("", 21)
	speaker_label.add_theme_color_override("font_color", Color("e5c27e"))
	column.add_child(speaker_label)
	content_label = _label("", 20)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(content_label)
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", 7)
	column.add_child(options)
	dialogue_panel.visible = false
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.09, 0.11, 0.94)
	hud.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 600
	card.add_theme_constant_override("separation", 22)
	center.add_child(card)
	overlay_title = _label("", 38)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(overlay_title)
	overlay_text = _label("", 20)
	overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_text.custom_minimum_size.x = 600
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(overlay_text)
	overlay_buttons = VBoxContainer.new()
	overlay_buttons.add_theme_constant_override("separation", 10)
	card.add_child(overlay_buttons)
	overlay.visible = false

func _process(_delta: float) -> void:
	if not is_instance_valid(prompt): return
	prompt.visible = not dialogue_open and not overlay.visible and not cinematic
	if GameManager.stage == "chase":
		prompt.text = "犬队追来了！朝铁门跑，绕开扑咬。  距离 %.1fm" % pressure
	else:
		var target := player.get_nearest_interactable()
		if is_instance_valid(target):
			var id: String = str(target.get_meta("interaction_id", ""))
			var names := {"goat": "老岩羊", "ox": "老牛", "sheep": "小羊", "horse": "追风", "farmer": "农场主", "record_board": "纪录牌", "cablecar": "索道"}
			prompt.text = "[ E ]  " + str(names.get(id, "调查"))
		else:
			prompt.text = "沿着地面标记向前探索"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not cinematic and GameManager.stage != "ending":
		if overlay.visible and not paused: return
		paused = not paused
		if paused:
			player.set_control_mode("paused")
			chase.set_active(false)
			_show_overlay("稍作停留", "旅程不会在暂停时继续。", [{"text": "继续旅程", "call": _resume}, {"text": "从头开始", "call": _restart}])
		else: _resume()
		get_viewport().set_input_as_handled()

func _resume() -> void:
	paused = false
	overlay.visible = false
	chase.set_active(GameManager.stage == "chase")
	_restore_control()

func _refresh_hud() -> void:
	if not is_instance_valid(objective): return
	objective.text = GameManager.get_current_main_objective()
	var dash: String = "Shift 冲刺已解锁" if GameManager.npc_completed.get("horse", false) else "伙伴可自由探索"
	status.text = ("铜插销：已取得  /  " if GameManager.has_pin else "铜插销：未取得  /  ") + dash
	player.set_dash_enabled(GameManager.npc_completed.get("horse", false))
	if is_instance_valid(pin_visual): pin_visual.visible = GameManager.has_pin

func _on_interact(target: Node3D) -> void:
	if dialogue_open or overlay.visible or cinematic or GameManager.stage in ["chase", "ending"]: return
	if not is_instance_valid(target): return
	var id := str(target.get_meta("interaction_id", ""))
	var entry: String = DialogueManager.get_entry_for(id)
	if GameManager.npc_met.has(id): GameManager.npc_met[id] = true
	if not entry.is_empty(): open_dialogue(entry)

func open_dialogue(key: String) -> void:
	var data: Dictionary = DialogueManager.get_dialogue_node(key)
	if data.is_empty():
		push_error("Missing dialogue: " + key)
		close_dialogue()
		return
	current_dialogue = key
	dialogue_open = true
	player.set_control_mode("dialogue")
	dialogue_panel.visible = true
	speaker_label.text = str(data.get("speaker", "")) + "  /  " + str(data.get("title", ""))
	content_label.text = str(data.get("content", ""))
	_clear_children(options)
	current_options = data.get("options", [])
	for index in range(current_options.size()):
		var option: Dictionary = current_options[index]
		options.add_child(_button(str(option.get("text", "继续")), _select_option.bind(index)))
	if options.get_child_count() > 0: options.get_child(0).grab_focus()

func _select_option(index: int) -> void:
	if busy or index < 0 or index >= current_options.size(): return
	busy = true
	for button in options.get_children(): button.disabled = true
	var option: Dictionary = current_options[index].duplicate()
	var event_id: String = str(option.get("event", ""))
	var ok := true
	match event_id:
		"choose_red":
			ok = GameManager.choose_red()
			if ok: greybox.set_pigpen_open(true)
		"choose_blue":
			ok = GameManager.choose_blue()
			if ok:
				close_dialogue()
				_show_ending()
		"complete_ox", "complete_sheep", "complete_horse":
			var id := event_id.trim_prefix("complete_")
			if GameManager.stage == "exploring" and not GameManager.npc_completed.get(id, false):
				greybox.set_npc_completed(id)
				await get_tree().create_timer(0.85).timeout
				ok = GameManager.complete_npc(id)
			else: ok = false
		"read_record": GameManager.read_record()
		"complete_showdown":
			ok = GameManager.complete_showdown()
			if ok: greybox.set_gate_open(true)
		"launch_cablecar":
			ok = GameManager.can_launch_cablecar()
			if ok:
				close_dialogue()
				_launch_cablecar()
		"": pass
		_:
			ok = false
			push_error("Unknown event: " + event_id)
	await get_tree().process_frame
	busy = false
	if GameManager.stage == "ending" or cinematic: return
	if not ok:
		close_dialogue()
		return
	var next_key := str(option.get("next", ""))
	if next_key.is_empty(): close_dialogue()
	else: open_dialogue(next_key)

func close_dialogue() -> void:
	dialogue_open = false
	dialogue_panel.visible = false
	_restore_control()

func _restore_control() -> void:
	if cinematic: player.set_control_mode("cinematic")
	elif paused: player.set_control_mode("paused")
	elif GameManager.stage == "ending" or overlay.visible: player.set_control_mode("ending")
	elif dialogue_open: player.set_control_mode("dialogue")
	else: player.set_control_mode("chase" if GameManager.stage == "chase" else "explore")

func _start_chase() -> void:
	if dialogue_open or cinematic or overlay.visible: return
	if not GameManager.start_chase(): return
	player.set_control_mode("chase")
	var spawns: Array[Vector3] = [Vector3(-4, 0.2, -2), Vector3(4, 0.2, -1)]
	chase.start_chase(player, spawns, -23.0)

func _on_chase_finished(success: bool) -> void:
	if success:
		GameManager.complete_chase()
		chase.stop_chase()
		player.set_control_mode("explore")
	else:
		player.set_control_mode("ending")
		_show_overlay("被犬队拦住了", "再试一次。已完成的伙伴交互会保留。\n沿中央路向前，扑咬出现时向侧面让开。", [{"text": "回到大院入口重试", "call": _retry}, {"text": "从头开始", "call": _restart}])

func _retry() -> void:
	if not GameManager.retry_chase(): return
	chase.stop_chase()
	player.reset_at(Vector3(0, 0.1, -3.0))
	camera.snap_to_target()
	overlay.visible = false
	_restore_control()

func _launch_cablecar() -> void:
	cinematic = true
	player.set_control_mode("cinematic")
	var cabin: Node3D = greybox.get_cablecar()
	player.global_position = cabin.global_position + Vector3(0, 0.5, 0)
	player.set_physics_process(false)
	var tween := create_tween().set_parallel(true)
	var direction := Vector3(0, 1.5, -18)
	tween.tween_property(cabin, "position", cabin.position + direction, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "global_position", player.global_position + direction, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	GameManager.finish_escape()
	cinematic = false
	_show_ending()

func _show_ending() -> void:
	player.set_control_mode("ending")
	if GameManager.ending == "stay":
		_show_overlay("安稳的肉馅", "甜料很暖，明早的车还很远。\n\n你选择留在猪圈。也可以再走一次另一条路。", [{"text": "重新选择", "call": _restart}])
	else:
		_show_overlay("旷野归途", "金牌是农场的，但命是你自己的。\n\n白模展示结束。场景、美术与模型仍为玩法占位。", [{"text": "重新出发", "call": _restart}])

func _show_overlay(title: String, body: String, buttons: Array) -> void:
	overlay_title.text = title
	overlay_text.text = body
	_clear_children(overlay_buttons)
	for item in buttons:
		overlay_buttons.add_child(_button(item["text"], item["call"]))
	overlay.visible = true
	if overlay_buttons.get_child_count() > 0: overlay_buttons.get_child(0).grab_focus()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _restart() -> void:
	get_tree().reload_current_scene()