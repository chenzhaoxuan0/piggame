extends Node3D

const CHASE_SCRIPT = preload("res://scripts/chase/simple_chase.gd")
const ART_2D = preload("res://scripts/art/art_2d.gd")
const L = preload("res://scripts/levels/farm_layout.gd")
const POKEMON_SHOWDOWN = preload("res://scripts/battle/pokemon_showdown.gd")
const COURSE_SCENES = {"chase_1": preload("res://scenes/courses/course_01_ox_field.tscn")}

@onready var player: PigController = $Pig
@onready var camera: IsometricCamera = $IsometricCamera
@onready var farm: Node3D = $Farm

var pokemon_battle: Control = null

var chase: SimpleChase
var active_course: Node3D = null
var _farm_removed := false
var hud: Control
var objective: Label
var status: Label
var prompt: Label
var dialogue_panel: PanelContainer
var speaker_label: Label
var content_label: Label
var line_hint: Label
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
var dialogue_lines: Array = []
var line_index := 0
var pressure := 999.0
var pin_visual: Node3D
var portrait: TextureRect
var ending_art: TextureRect

var in_start_menu := true
var in_settings := false
var settings_from_start := false
var start_menu: Control
var pause_menu: Control
var settings_menu: Control

# Untitled Goose Game Style UI Extensions
var todo_notebook: PanelContainer
var todo_vbox: VBoxContainer
var todo_toggle_btn: Button
var todo_folded := false
var qte_panel: PanelContainer
var qte_btn_label: Label
var qte_desc_label: Label
var qte_counter_label: Label
var qte_bar: ProgressBar
var qte_timer_bar: ProgressBar
var toast_panel: PanelContainer
var toast_title: Label
var toast_desc: Label
var dash_gauge: Control
var dash_bar: ProgressBar

# Skill Unlock Card Modal
var skill_card_modal: PanelContainer
var skill_card_title: Label
var skill_card_subtitle: Label
var skill_card_key_label: Label
var skill_card_desc_label: Label
var skill_card_btn: Button
var in_skill_card := false

# Chase & QTE logic state
var current_chase_id := ""
var in_qte := false
var current_qte_dog: ChaseDog = null
var qte_hits := 0
const QTE_TARGET_HITS := 5
var qte_time_remaining := 3.5
const QTE_TIME_TOTAL := 3.5

func _ready() -> void:
	GameManager.reset_run()
	chase = CHASE_SCRIPT.new()
	add_child(chase)
	chase.finished.connect(_on_chase_finished)
	chase.pressure_changed.connect(func(value: float): pressure = value)
	chase.qte_requested.connect(_on_qte_requested)
	
	player.reached_interactable.connect(_on_interact)
	player.qte_tapped.connect(_on_qte_tapped)
	player.dash_state_changed.connect(_on_player_dash_changed)
	player.dodge_succeeded.connect(_on_player_dodge_succeeded)
	
	farm.chase_entered.connect(_start_chase)
	if farm.has_signal("chase_triggered"):
		farm.chase_triggered.connect(_on_farm_chase_triggered)
	if farm.has_signal("stage_chase_completed"):
		farm.stage_chase_completed.connect(_on_farm_gate_passed)
		
	GameManager.state_changed.connect(_refresh_hud)
	
	_build_hud()
	_build_pin()
	player.reset_at(farm.get_spawn_position())
	camera.snap_to_target()
	_refresh_hud()
	_show_start_menu()

func _build_pin() -> void:
	pin_visual = preload("res://scripts/art/asset_library.gd").make("PROP_03")
	if pin_visual == null:
		pin_visual = MeshInstance3D.new()
		_build_fallback_pin(pin_visual)
	player.get_node("VisualMesh").add_child(pin_visual)
	pin_visual.position = Vector3(0, 0.55, -0.9)
	preload("res://scripts/art/asset_library.gd").attach_to_bone(player.get_node_or_null("VisualMesh/CHAR_01"), "Head", pin_visual, pin_visual.position)
	pin_visual.visible = false

func _build_fallback_pin(mesh_node: MeshInstance3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.08, 0.08)
	mesh_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c9984d")
	mesh_node.material_override = material

func _style(bg: Color, border: Color = Color(0.40, 0.38, 0.30), radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
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

func _button(text_value: String, callback: Callable, align_left: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 44
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_CENTER
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(callback)
	button.add_theme_color_override("font_color", Color("343b30"))
	button.add_theme_color_override("font_hover_color", Color("343b30"))
	button.add_theme_color_override("font_focus_color", Color("343b30"))
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
	theme.set_color("font_color", "Label", Color(0.24, 0.27, 0.20))
	theme.set_stylebox("normal", "Button", _style(Color(0.92, 0.88, 0.76), Color(0.36, 0.34, 0.26), 8))
	theme.set_stylebox("hover", "Button", _style(Color(0.99, 0.95, 0.78), Color(0.78, 0.52, 0.18), 8))
	theme.set_stylebox("pressed", "Button", _style(Color(0.80, 0.76, 0.62), Color(0.36, 0.34, 0.26), 8))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), Color(0.85, 0.60, 0.20), 8))
	hud.theme = theme

	# Clean interaction prompt (Untitled Goose Game small pill at bottom)
	prompt = _label("", 19)
	prompt.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.75))
	prompt.add_theme_constant_override("shadow_offset_x", 1)
	prompt.add_theme_constant_override("shadow_offset_y", 1)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -420
	prompt.offset_right = 420
	prompt.offset_top = -85
	prompt.offset_bottom = -45
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt)

	# Minimalist Warm Paper Dialogue Panel
	dialogue_panel = PanelContainer.new()
	dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_panel.offset_left = 120
	dialogue_panel.offset_right = -120
	dialogue_panel.offset_top = -320
	dialogue_panel.offset_bottom = -50
	dialogue_panel.add_theme_stylebox_override("panel", _style(Color(0.98, 0.96, 0.90, 0.98), Color(0.42, 0.38, 0.28), 16))
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if dialogue_open and not busy and not cinematic and (pokemon_battle == null or not pokemon_battle.battle_active):
				_advance_dialogue()
	)
	hud.add_child(dialogue_panel)
	
	var dialogue_row := HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation", 22)
	dialogue_row.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_panel.add_child(dialogue_row)
	
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(160, 160)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_row.add_child(portrait)
	
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_row.add_child(column)
	
	speaker_label = _label("", 21)
	speaker_label.add_theme_color_override("font_color", Color(0.58, 0.32, 0.14))
	speaker_label.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(speaker_label)
	
	content_label = _label("", 19)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(content_label)
	
	line_hint = _label("▼ 点击继续", 14)
	line_hint.add_theme_color_override("font_color", Color(0.48, 0.50, 0.40))
	line_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(line_hint)
	
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", 6)
	column.add_child(options)
	dialogue_panel.visible = false

	# Fullscreen Overlay for Ending & Failure
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.95, 0.93, 0.86, 0.97)
	hud.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 600
	card.add_theme_constant_override("separation", 22)
	center.add_child(card)
	ending_art = TextureRect.new()
	ending_art.custom_minimum_size = Vector2(600, 270)
	ending_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ending_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ending_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_art.hide()
	card.add_child(ending_art)
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

	_build_todo_notebook()
	_build_qte_panel()
	_build_dash_gauge()
	_build_toast_banner()
	_build_skill_card()
	_build_pokemon_battle()
	_build_pause_menu()
	_build_settings_menu()
	_build_start_menu()

func _build_pokemon_battle() -> void:
	pokemon_battle = POKEMON_SHOWDOWN.new()
	pokemon_battle.name = "PokemonShowdown"
	hud.add_child(pokemon_battle)
	pokemon_battle.battle_completed.connect(_on_pokemon_battle_finished)

# -------------------------------------------------------------
# Untitled Goose Game Style: To-Do Notebook
# -------------------------------------------------------------
func _build_todo_notebook() -> void:
	todo_notebook = PanelContainer.new()
	todo_notebook.name = "TodoNotebook"
	todo_notebook.custom_minimum_size = Vector2(330, 200)
	todo_notebook.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	todo_notebook.offset_left = -350
	todo_notebook.offset_top = 22
	todo_notebook.offset_right = -20
	todo_notebook.offset_bottom = 260
	todo_notebook.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Parchment paper look
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color(0.97, 0.95, 0.88, 0.95)
	paper_style.border_color = Color(0.36, 0.32, 0.24)
	paper_style.set_border_width_all(2)
	paper_style.set_corner_radius_all(10)
	paper_style.content_margin_left = 18
	paper_style.content_margin_right = 18
	paper_style.content_margin_top = 14
	paper_style.content_margin_bottom = 14
	paper_style.shadow_color = Color(0, 0, 0, 0.12)
	paper_style.shadow_size = 6
	paper_style.shadow_offset = Vector2(2, 3)
	todo_notebook.add_theme_stylebox_override("panel", paper_style)
	hud.add_child(todo_notebook)

	var notebook_layout := VBoxContainer.new()
	notebook_layout.add_theme_constant_override("separation", 8)
	todo_notebook.add_child(notebook_layout)

	# Notebook header
	var header_box := HBoxContainer.new()
	notebook_layout.add_child(header_box)
	
	var pin_icon := _label("✎", 16)
	pin_icon.add_theme_color_override("font_color", Color(0.68, 0.32, 0.18))
	header_box.add_child(pin_icon)
	
	var nb_title := _label("待办事项 / TO-DO", 16)
	nb_title.add_theme_color_override("font_color", Color(0.36, 0.30, 0.22))
	header_box.add_child(nb_title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.50, 0.44, 0.34, 0.5)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	notebook_layout.add_child(sep)

	todo_vbox = VBoxContainer.new()
	todo_vbox.add_theme_constant_override("separation", 7)
	notebook_layout.add_child(todo_vbox)
	
	_refresh_todo_list()

func _refresh_todo_list() -> void:
	if not is_instance_valid(todo_vbox): return
	_clear_children(todo_vbox)
	var items: Array[Dictionary] = GameManager.get_to_do_items()
	
	# Show active item and recent items in Goose Game fashion
	var shown_count := 0
	for item in items:
		var is_done: bool = item.get("done", false)
		var text: String = str(item.get("text", ""))
		
		# Skip far future tasks to keep the notebook concise
		if not is_done and shown_count >= 3:
			continue
			
		var item_label := Label.new()
		item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.add_theme_font_size_override("font_size", 14)
		
		if is_done:
			# Strikethrough completed items in handwriting style!
			item_label.text = "✓  " + text
			item_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.45, 0.75))
			# Visual strike line can be represented with decoration or Unicode/strikethrough font
			# In Godot 4, we can draw line or strike text
		else:
			item_label.text = "●  " + text
			item_label.add_theme_color_override("font_color", Color(0.25, 0.22, 0.16))
			shown_count += 1
		
		todo_vbox.add_child(item_label)
		
		# If completed, add strike line across it
		if is_done:
			var strike_rect := ColorRect.new()
			strike_rect.color = Color(0.72, 0.28, 0.22, 0.75) # Goose red strike line
			strike_rect.custom_minimum_size = Vector2(0, 2)
			item_label.add_child(strike_rect)
			strike_rect.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			strike_rect.offset_top = 0
			strike_rect.offset_bottom = 2
			strike_rect.offset_left = 18
			strike_rect.offset_right = 260

# -------------------------------------------------------------
# Untitled Goose Game Style: QTE Struggle Panel
# -------------------------------------------------------------
func _build_qte_panel() -> void:
	qte_panel = PanelContainer.new()
	qte_panel.name = "StruggleQTEPanel"
	qte_panel.set_anchors_preset(Control.PRESET_CENTER)
	qte_panel.offset_left = -230
	qte_panel.offset_top = -145
	qte_panel.offset_right = 230
	qte_panel.offset_bottom = 95
	qte_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Circular rustic stamp container with rich tactile border
	var qte_box := StyleBoxFlat.new()
	qte_box.bg_color = Color(0.97, 0.94, 0.86, 0.98)
	qte_box.border_color = Color(0.72, 0.24, 0.16) # Goose red accent
	qte_box.set_border_width_all(4)
	qte_box.set_corner_radius_all(20)
	qte_box.content_margin_left = 26
	qte_box.content_margin_right = 26
	qte_box.content_margin_top = 18
	qte_box.content_margin_bottom = 18
	qte_box.shadow_color = Color(0, 0, 0, 0.35)
	qte_box.shadow_size = 12
	qte_box.shadow_offset = Vector2(0, 4)
	qte_panel.add_theme_stylebox_override("panel", qte_box)
	hud.add_child(qte_panel)

	var qte_layout := VBoxContainer.new()
	qte_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	qte_layout.add_theme_constant_override("separation", 10)
	qte_panel.add_child(qte_layout)

	# Key prompt badge
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.92, 0.86, 0.74)
	badge_style.border_color = Color(0.68, 0.22, 0.14)
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(10)
	badge_style.content_margin_left = 16
	badge_style.content_margin_right = 16
	badge_style.content_margin_top = 6
	badge_style.content_margin_bottom = 6
	badge.add_theme_stylebox_override("panel", badge_style)
	qte_layout.add_child(badge)

	qte_btn_label = _label("【 狂按空格键 / SPACE 】", 23)
	qte_btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte_btn_label.add_theme_color_override("font_color", Color(0.72, 0.22, 0.14))
	badge.add_child(qte_btn_label)

	qte_desc_label = _label("恶犬扑咬！连续猛击按键拼命挣脱！", 16)
	qte_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte_desc_label.add_theme_color_override("font_color", Color(0.36, 0.30, 0.22))
	qte_layout.add_child(qte_desc_label)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 12)
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qte_layout.add_child(bar_row)

	qte_bar = ProgressBar.new()
	qte_bar.custom_minimum_size = Vector2(280, 24)
	qte_bar.max_value = QTE_TARGET_HITS
	qte_bar.value = 0
	qte_bar.show_percentage = false
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.82, 0.34, 0.18)
	bar_fill.set_corner_radius_all(8)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.86, 0.82, 0.72)
	bar_bg.set_corner_radius_all(8)
	qte_bar.add_theme_stylebox_override("fill", bar_fill)
	qte_bar.add_theme_stylebox_override("background", bar_bg)
	bar_row.add_child(qte_bar)

	qte_counter_label = _label("0 / 5", 16)
	qte_counter_label.add_theme_color_override("font_color", Color(0.72, 0.22, 0.14))
	bar_row.add_child(qte_counter_label)

	qte_timer_bar = ProgressBar.new()
	qte_timer_bar.custom_minimum_size = Vector2(340, 6)
	qte_timer_bar.max_value = QTE_TIME_TOTAL
	qte_timer_bar.value = QTE_TIME_TOTAL
	qte_timer_bar.show_percentage = false
	var timer_fill := StyleBoxFlat.new()
	timer_fill.bg_color = Color(0.55, 0.48, 0.36)
	var timer_bg := StyleBoxFlat.new()
	timer_bg.bg_color = Color(0.85, 0.82, 0.72)
	qte_timer_bar.add_theme_stylebox_override("fill", timer_fill)
	qte_timer_bar.add_theme_stylebox_override("background", timer_bg)
	qte_layout.add_child(qte_timer_bar)

	qte_panel.visible = false

func _on_qte_requested(dog: ChaseDog) -> void:
	if in_qte or dialogue_open or cinematic or paused: return
	in_qte = true
	current_qte_dog = dog
	qte_hits = 0
	qte_time_remaining = QTE_TIME_TOTAL
	qte_bar.value = 0
	qte_timer_bar.value = QTE_TIME_TOTAL
	if is_instance_valid(qte_counter_label):
		qte_counter_label.text = "0 / %d" % QTE_TARGET_HITS
	
	if GameManager.has_struggle_skill:
		qte_btn_label.text = "【 狂按空格键 / SPACE 】"
		qte_desc_label.text = "借老牛坚韧硬骨气 · 狂敲按键挣脱重负！"
	else:
		qte_btn_label.text = "【 狂按空格键 / SPACE 拼命挣扎 】"
		qte_desc_label.text = "被过往阴影缠住！拼命按空格尝试挣脱！"
		
	qte_panel.visible = true
	player.set_control_mode("qte")
	
	# Bounce punch animation on QTE pop
	qte_panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.tween_property(qte_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_qte_tapped() -> void:
	if not in_qte: return
	qte_hits += 1
	qte_bar.value = qte_hits
	if is_instance_valid(qte_counter_label):
		qte_counter_label.text = "%d / %d" % [qte_hits, QTE_TARGET_HITS]
	
	# Punch pop on hit
	var tween := create_tween()
	tween.tween_property(qte_btn_label, "scale", Vector2(1.15, 1.15), 0.04)
	tween.tween_property(qte_btn_label, "scale", Vector2.ONE, 0.08)
	
	if qte_hits >= QTE_TARGET_HITS:
		_finish_qte(true)

func _finish_qte(success: bool) -> void:
	if not in_qte: return
	in_qte = false
	qte_panel.visible = false
	var dog := current_qte_dog
	current_qte_dog = null

	if is_instance_valid(active_course):
		active_course.runner.resolve_qte(dog, success)
		player.set_control_mode("chase")
		if success:
			_show_toast("挣脱成功！", "借老牛之力震退恶犬，继续闯关！")
		return

	if success:
		var toast_desc_text := "借老牛之力震退恶犬，继续跑！" if GameManager.has_struggle_skill else "挣脱了恶犬的纠缠，快跑！"
		_show_toast("挣脱成功！", toast_desc_text)
		chase.resolve_qte(dog, true)
		player.set_control_mode("chase")
	else:
		chase.resolve_qte(dog, false)

# -------------------------------------------------------------
# Untitled Goose Game Style: Skill Unlock Modal
# -------------------------------------------------------------
func _build_skill_card() -> void:
	skill_card_modal = PanelContainer.new()
	skill_card_modal.name = "SkillCardModal"
	skill_card_modal.set_anchors_preset(Control.PRESET_CENTER)
	skill_card_modal.offset_left = -260
	skill_card_modal.offset_top = -180
	skill_card_modal.offset_right = 260
	skill_card_modal.offset_bottom = 180
	skill_card_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.90, 0.99)
	style.border_color = Color(0.68, 0.28, 0.18) # Goose wax red
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	skill_card_modal.add_theme_stylebox_override("panel", style)
	hud.add_child(skill_card_modal)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_card_modal.add_child(vbox)
	
	var tag := _label("★ 领 悟 伙 伴 新 技 能 ★", 14)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color(0.72, 0.28, 0.18))
	vbox.add_child(tag)
	
	skill_card_title = _label("【 坚 韧 挣 脱 】", 26)
	skill_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_card_title.add_theme_color_override("font_color", Color(0.32, 0.25, 0.16))
	vbox.add_child(skill_card_title)
	
	skill_card_subtitle = _label("借老牛坚忍不屈的硬骨气", 15)
	skill_card_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_card_subtitle.add_theme_color_override("font_color", Color(0.55, 0.48, 0.38))
	vbox.add_child(skill_card_subtitle)
	
	# Key hint badge box
	var key_panel := PanelContainer.new()
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.92, 0.88, 0.78)
	key_style.border_color = Color(0.50, 0.42, 0.30)
	key_style.set_border_width_all(2)
	key_style.set_corner_radius_all(10)
	key_style.content_margin_left = 16
	key_style.content_margin_right = 16
	key_style.content_margin_top = 10
	key_style.content_margin_bottom = 10
	key_panel.add_theme_stylebox_override("panel", key_style)
	vbox.add_child(key_panel)
	
	skill_card_key_label = _label("【核心按键】 被咬住时狂按 [ 空格键 / SPACE ]", 17)
	skill_card_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_card_key_label.add_theme_color_override("font_color", Color(0.75, 0.24, 0.16))
	key_panel.add_child(skill_card_key_label)
	
	skill_card_desc_label = _label("恶犬扑咬纠缠时，在时限内猛敲 5 次，可瞬间震飞恶犬 6 米并使其眩晕！", 15)
	skill_card_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_card_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_card_desc_label.add_theme_color_override("font_color", Color(0.30, 0.28, 0.22))
	vbox.add_child(skill_card_desc_label)
	
	skill_card_btn = _button("我 领 悟 了 (按空格或点击继续)", _dismiss_skill_card)
	vbox.add_child(skill_card_btn)
	
	skill_card_modal.visible = false

func _show_skill_unlock(title_text: String, subtitle_text: String, key_text: String, desc_text: String) -> void:
	in_skill_card = true
	player.set_control_mode("cinematic")
	skill_card_title.text = title_text
	skill_card_subtitle.text = subtitle_text
	skill_card_key_label.text = key_text
	skill_card_desc_label.text = desc_text
	skill_card_modal.visible = true
	skill_card_btn.grab_focus()
	
	# Pop scale spring animation
	skill_card_modal.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.tween_property(skill_card_modal, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _dismiss_skill_card() -> void:
	if not in_skill_card: return
	in_skill_card = false
	skill_card_modal.visible = false
	_restore_control()
	_refresh_hud()

# -------------------------------------------------------------
# Dash Sprint Gauge (Horse Pasture Power)
# -------------------------------------------------------------
func _build_dash_gauge() -> void:
	dash_gauge = Control.new()
	dash_gauge.name = "DashGauge"
	dash_gauge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_gauge.offset_left = -210
	dash_gauge.offset_top = -68
	dash_gauge.offset_right = -25
	dash_gauge.offset_bottom = -25
	dash_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dash_gauge)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	dash_gauge.add_child(hbox)

	var icon := _label("⚡", 18)
	icon.add_theme_color_override("font_color", Color(0.82, 0.58, 0.18))
	hbox.add_child(icon)

	dash_bar = ProgressBar.new()
	dash_bar.custom_minimum_size = Vector2(130, 16)
	dash_bar.max_value = 3.0
	dash_bar.value = 3.0
	dash_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.42, 0.75, 0.38) # Goose green when full
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.40, 0.36, 0.28, 0.8)
	bg.set_corner_radius_all(6)
	dash_bar.add_theme_stylebox_override("fill", fill)
	dash_bar.add_theme_stylebox_override("background", bg)
	hbox.add_child(dash_bar)

	dash_gauge.visible = false

func _on_player_dash_changed(remaining: float, _cooldown: float) -> void:
	var battle_on: bool = is_instance_valid(pokemon_battle) and pokemon_battle.battle_active
	if not GameManager.has_dash_skill or battle_on:
		dash_gauge.visible = false
		return
	dash_gauge.visible = true
	if is_instance_valid(dash_bar):
		var max_val: float = player.max_stamina if is_instance_valid(player) else 3.0
		dash_bar.max_value = max_val
		dash_bar.value = remaining
		var fill_style: StyleBoxFlat = dash_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if is_instance_valid(player) and player.is_sprinting:
				fill_style.bg_color = Color(0.95, 0.55, 0.18) # Active sprint energetic orange
			elif remaining < max_val:
				fill_style.bg_color = Color(0.85, 0.70, 0.25) # Recharging warm gold
			else:
				fill_style.bg_color = Color(0.42, 0.75, 0.38) # Full stamina green

func _on_player_dodge_succeeded(_dog: Node3D) -> void:
	_show_toast("★ 闪避成功！", "灵巧侧身闪过恶犬扑杀！")

# -------------------------------------------------------------
# Ambient Toast Banner (Goose Game Subtitle)
# -------------------------------------------------------------
func _build_toast_banner() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.name = "ToastBanner"
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_left = -320
	toast_panel.offset_top = -140
	toast_panel.offset_right = 320
	toast_panel.offset_bottom = -80
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.18, 0.20, 0.16, 0.88)
	toast_style.border_color = Color(0.75, 0.68, 0.52)
	toast_style.set_border_width_all(2)
	toast_style.set_corner_radius_all(12)
	toast_style.content_margin_left = 18
	toast_style.content_margin_right = 18
	toast_panel.add_theme_stylebox_override("panel", toast_style)
	hud.add_child(toast_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	toast_panel.add_child(vbox)

	toast_title = _label("", 17)
	toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
	vbox.add_child(toast_title)

	toast_desc = _label("", 14)
	toast_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_desc.add_theme_color_override("font_color", Color(0.80, 0.78, 0.70))
	vbox.add_child(toast_desc)

	toast_panel.visible = false

func _show_toast(title_text: String, desc_text: String) -> void:
	if not is_instance_valid(toast_panel): return
	toast_title.text = title_text
	toast_desc.text = desc_text
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.5)
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): toast_panel.visible = false)

# -------------------------------------------------------------
# Menus: Start, Pause, Settings
# -------------------------------------------------------------
func _build_start_menu() -> void:
	start_menu = Control.new()
	start_menu.name = "StartMenu"
	start_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(start_menu)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.14, 0.11, 0.72)
	start_menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_menu.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 360)
	card.add_theme_stylebox_override("panel", _style(Color(0.96, 0.94, 0.88, 0.98), Color(0.40, 0.38, 0.30)))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var title := _label("一口猪在金牌农场", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.45, 0.28, 0.14))
	vbox.add_child(title)

	var subtitle := _label("A PIG IN GOLDEN FARM · 逃离农场", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.52, 0.48, 0.38))
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_start := _button("▶  开始游戏", _start_game)
	btn_start.name = "StartButton"
	btn_start.custom_minimum_size.y = 48
	vbox.add_child(btn_start)

	var btn_settings := _button("⚙  游戏设置", _open_settings.bind(true))
	btn_settings.name = "SettingsButton"
	btn_settings.custom_minimum_size.y = 48
	vbox.add_child(btn_settings)

	var btn_quit := _button("✕  退出游戏", func(): get_tree().quit())
	btn_quit.name = "QuitButton"
	btn_quit.custom_minimum_size.y = 44
	vbox.add_child(btn_quit)

func _build_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	hud.add_child(pause_menu)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.14, 0.11, 0.75)
	pause_menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 500)
	card.add_theme_stylebox_override("panel", _style(Color(0.96, 0.94, 0.88, 0.98), Color(0.40, 0.38, 0.30)))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title := _label("游戏暂停", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.45, 0.28, 0.14))
	vbox.add_child(title)

	var guide_panel := PanelContainer.new()
	guide_panel.name = "GuidePanel"
	guide_panel.add_theme_stylebox_override("panel", _style(Color(0.91, 0.88, 0.80, 0.92), Color(0.65, 0.60, 0.48)))
	vbox.add_child(guide_panel)

	var guide_vbox := VBoxContainer.new()
	guide_vbox.add_theme_constant_override("separation", 6)
	guide_panel.add_child(guide_vbox)

	var guide_title := _label("【 键位与操作指南 】", 15)
	guide_title.name = "GuideTitle"
	guide_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_title.add_theme_color_override("font_color", Color(0.42, 0.26, 0.12))
	guide_vbox.add_child(guide_title)

	var guide_items := [
		"WASD / 方向键   移动角色",
		"鼠标左键          点击地面寻路 / 对话选项",
		"空格键 (Space)    跳跃（越过倒木与溪流缺口）",
		"F 键 / E 键        与动物伙伴、场景道具交互",
		"连续敲击空格/E     被恶犬咬住时 QTE 挣脱（老牛技能）",
		"Shift 键          长按加速冲刺（马技能）/ 红圈扑咬时按Shift闪避",
		"ESC 键           暂停游戏 / 返回"
	]
	for item in guide_items:
		var lbl := _label(item, 14)
		lbl.add_theme_color_override("font_color", Color(0.26, 0.28, 0.22))
		guide_vbox.add_child(lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_resume := _button("▶  继续游戏", _resume)
	btn_resume.name = "ResumeButton"
	btn_resume.custom_minimum_size.y = 44
	vbox.add_child(btn_resume)

	var btn_settings := _button("⚙  游戏设置", _open_settings.bind(false))
	btn_settings.name = "SettingsButton"
	btn_settings.custom_minimum_size.y = 44
	vbox.add_child(btn_settings)

	var btn_restart := _button("↺  从头开始", _restart)
	btn_restart.name = "RestartButton"
	btn_restart.custom_minimum_size.y = 44
	vbox.add_child(btn_restart)

	var btn_main := _button("⌂  返回主菜单", _return_to_main_menu)
	btn_main.name = "MainMenuButton"
	btn_main.custom_minimum_size.y = 44
	vbox.add_child(btn_main)

func _build_settings_menu() -> void:
	settings_menu = Control.new()
	settings_menu.name = "SettingsMenu"
	settings_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_menu.visible = false
	hud.add_child(settings_menu)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.14, 0.11, 0.75)
	settings_menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_menu.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 360)
	card.add_theme_stylebox_override("panel", _style(Color(0.96, 0.94, 0.88, 0.98), Color(0.40, 0.38, 0.30)))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var title := _label("游戏设置", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.45, 0.28, 0.14))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var toggle_high := CheckButton.new()
	toggle_high.name = "TestHighCamera"
	toggle_high.text = "测试用高视角（原高度 / 原视野）"
	toggle_high.button_pressed = camera.test_high_view
	toggle_high.toggled.connect(camera.set_test_high_view)
	vbox.add_child(toggle_high)

	var toggle_fs := CheckButton.new()
	toggle_fs.name = "FullscreenToggle"
	toggle_fs.text = "全屏显示模式"
	toggle_fs.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	toggle_fs.toggled.connect(func(pressed: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	vbox.add_child(toggle_fs)

	var toggle_mute := CheckButton.new()
	toggle_mute.name = "MuteAudioToggle"
	toggle_mute.text = "静音所有声音"
	toggle_mute.button_pressed = AudioServer.is_bus_mute(0)
	toggle_mute.toggled.connect(func(pressed: bool):
		AudioServer.set_bus_mute(0, pressed)
	)
	vbox.add_child(toggle_mute)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var btn_back := _button("◀  返回", _close_settings)
	btn_back.name = "BackButton"
	btn_back.custom_minimum_size.y = 44
	vbox.add_child(btn_back)

func start_game() -> void:
	_start_game()

func _start_game() -> void:
	in_start_menu = false
	if is_instance_valid(start_menu):
		start_menu.visible = false
	if in_settings:
		_close_settings()
	_restore_control()
	_refresh_hud()

func _show_start_menu() -> void:
	in_start_menu = true
	in_settings = false
	if is_instance_valid(start_menu):
		start_menu.visible = true
		var start_btn: Button = start_menu.find_child("StartButton", true, false)
		if is_instance_valid(start_btn):
			start_btn.grab_focus()
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
	if is_instance_valid(overlay):
		overlay.visible = false
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	if is_instance_valid(todo_notebook):
		todo_notebook.visible = false
	player.set_control_mode("cinematic")

func _show_pause_menu() -> void:
	paused = true
	in_settings = false
	if is_instance_valid(pause_menu):
		pause_menu.visible = true
		var resume_btn: Button = pause_menu.find_child("ResumeButton", true, false)
		if is_instance_valid(resume_btn):
			resume_btn.grab_focus()
	# Keep overlay and TestHighCamera compatibility for tests
	_clear_children(overlay_buttons)
	var toggle := CheckButton.new()
	toggle.name = "TestHighCamera"
	toggle.text = "测试用高视角（原高度 / 原视野）"
	toggle.button_pressed = camera.test_high_view
	toggle.toggled.connect(camera.set_test_high_view)
	overlay_buttons.add_child(toggle)
	overlay.visible = true

func _show_pause_settings() -> void:
	_show_pause_menu()

func _open_settings(from_start: bool = false) -> void:
	in_settings = true
	settings_from_start = from_start
	if from_start:
		if is_instance_valid(start_menu): start_menu.visible = false
	else:
		if is_instance_valid(pause_menu): pause_menu.visible = false
	if is_instance_valid(settings_menu):
		var toggle_cam: CheckButton = settings_menu.find_child("TestHighCamera", true, false)
		if is_instance_valid(toggle_cam):
			toggle_cam.button_pressed = camera.test_high_view
		settings_menu.visible = true
		var back_btn: Button = settings_menu.find_child("BackButton", true, false)
		if is_instance_valid(back_btn):
			back_btn.grab_focus()

func _close_settings() -> void:
	in_settings = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
	if settings_from_start:
		if is_instance_valid(start_menu):
			start_menu.visible = true
			var settings_btn: Button = start_menu.find_child("SettingsButton", true, false)
			if is_instance_valid(settings_btn):
				settings_btn.grab_focus()
	else:
		if is_instance_valid(pause_menu):
			pause_menu.visible = true
			var settings_btn: Button = pause_menu.find_child("SettingsButton", true, false)
			if is_instance_valid(settings_btn):
				settings_btn.grab_focus()

func _return_to_main_menu() -> void:
	paused = false
	in_settings = false
	_restart()

func _resume() -> void:
	paused = false
	in_settings = false
	if is_instance_valid(pause_menu): pause_menu.visible = false
	if is_instance_valid(settings_menu): settings_menu.visible = false
	overlay.visible = false
	chase.set_active(GameManager.is_in_chase())
	_restore_control()

func _process(delta: float) -> void:
	if in_qte:
		qte_time_remaining -= delta
		if is_instance_valid(qte_timer_bar):
			qte_timer_bar.value = maxf(0.0, qte_time_remaining)
		if is_instance_valid(qte_btn_label):
			var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.06
			qte_btn_label.scale = Vector2(pulse, pulse)
		if qte_time_remaining <= 0.0:
			_finish_qte(false)
		return

	if not is_instance_valid(prompt): return
	if in_start_menu or paused or in_settings or dialogue_open or (overlay.visible and not paused) or cinematic or in_skill_card:
		prompt.visible = false
		return
	prompt.visible = true
	
	if GameManager.is_in_chase():
		prompt.text = "奔跑避障突围！犬队逼近 %.1f m  [红圈扑咬时按Shift闪避 / 遇障碍按空格跃过 / 被咬时狂按空格挣脱]" % pressure
	else:
		var target := player.get_nearest_interactable()
		if is_instance_valid(target):
			var id: String = str(target.get_meta("interaction_id", ""))
			var names := {"goat": "老岩羊", "ox": "老牛", "sheep": "小羊", "horse": "追风", "farmer": "农场主", "record_board": "纪录牌", "cablecar": "索道"}
			prompt.text = "[ F ]  " + str(names.get(id, "调查"))
		else:
			prompt.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if in_skill_card:
		var dismiss: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("action_jump") \
			or event.is_action_pressed("action_interact") \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
		if dismiss:
			_dismiss_skill_card()
			get_viewport().set_input_as_handled()
			return

	if dialogue_open and not busy and not cinematic and (pokemon_battle == null or not pokemon_battle.battle_active):
		var advance: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("action_interact") \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if advance:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
			return
			
	if event.is_action_pressed("ui_cancel") and not cinematic and GameManager.stage != "ending":
		if in_settings:
			_close_settings()
			get_viewport().set_input_as_handled()
			return
		if in_start_menu:
			return
		if in_skill_card:
			_dismiss_skill_card()
			get_viewport().set_input_as_handled()
			return
		if overlay.visible and not paused: return
		paused = not paused
		if paused:
			player.set_control_mode("paused")
			chase.set_active(false)
			_show_pause_menu()
		else:
			_resume()
		get_viewport().set_input_as_handled()

func _refresh_hud() -> void:
	if is_instance_valid(objective):
		objective.text = GameManager.get_current_main_objective()
	if is_instance_valid(status):
		var dash: String = "Shift 长按加速已解锁" if GameManager.npc_completed.get("horse", false) else "伙伴可自由探索"
		status.text = ("铜插销：已取得  /  " if GameManager.has_pin else "铜插销：未取得  /  ") + dash
	player.set_dash_enabled(GameManager.npc_completed.get("horse", false))
	if is_instance_valid(pin_visual): pin_visual.visible = GameManager.has_pin
	if is_instance_valid(todo_notebook):
		var battle_on: bool = is_instance_valid(pokemon_battle) and pokemon_battle.battle_active
		todo_notebook.visible = not in_start_menu and not paused and not overlay.visible and not battle_on
		if todo_notebook.visible:
			_refresh_todo_list()

func _on_interact(target: Node3D) -> void:
	if dialogue_open or overlay.visible or cinematic or GameManager.is_in_chase() or GameManager.stage == "ending": return
	if not is_instance_valid(target): return
	var id := str(target.get_meta("interaction_id", ""))
	if id == "farmer":
		if GameManager.stage == "showdown" or (GameManager.has_pin and GameManager.npc_completed.get("horse", false) and GameManager.stage != "cablecar_ready" and GameManager.stage != "ending"):
			if GameManager.stage != "showdown":
				GameManager.stage = "showdown"
			_start_farmer_showdown()
			return
	var entry: String = DialogueManager.get_entry_for(id)
	if GameManager.npc_met.has(id): GameManager.npc_met[id] = true
	if not entry.is_empty(): open_dialogue(entry)

func open_dialogue(key: String) -> void:
	if in_start_menu:
		in_start_menu = false
		if is_instance_valid(start_menu):
			start_menu.visible = false
	if paused:
		_resume()
	if key == "ordeal_encounter":
		if GameManager.stage != "showdown":
			GameManager.stage = "showdown"
		_start_farmer_showdown()
		return
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
	portrait.texture = ART_2D.PORTRAITS.get(str(data.get("speaker", "")))
	portrait.visible = portrait.texture != null
	dialogue_lines = _split_lines(str(data.get("content", "")))
	line_index = 0
	current_options = data.get("options", [])
	_clear_children(options)
	_show_current_line()

func _start_farmer_showdown() -> void:
	if is_instance_valid(pokemon_battle) and pokemon_battle.battle_active: return
	if in_start_menu:
		in_start_menu = false
		if is_instance_valid(start_menu): start_menu.visible = false
	if paused: _resume()
	dialogue_open = true
	player.set_control_mode("dialogue")
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	if is_instance_valid(prompt):
		prompt.visible = false
	if is_instance_valid(todo_notebook):
		todo_notebook.visible = false
	if is_instance_valid(dash_gauge):
		dash_gauge.visible = false
	if is_instance_valid(pokemon_battle):
		pokemon_battle.start_battle(self)

func _on_pokemon_battle_finished(success: bool) -> void:
	dialogue_open = false
	_clear_children(options)
	if success:
		var ok := GameManager.complete_showdown()
		if ok: farm.set_gate_open(true)
		_show_toast("意志对决胜利！铁门轰然开启！", "农场主掌控欲彻底瓦解，快穿过大铁门登上后山索道！")
	_restore_control()
	_refresh_hud()

func _split_lines(content: String) -> Array:
	var lines := []
	for line in content.split("\n"):
		var text := str(line).strip_edges()
		if not text.is_empty():
			lines.append(text)
	if lines.is_empty():
		lines.append("")
	return lines

func _show_current_line() -> void:
	content_label.text = str(dialogue_lines[line_index])
	var on_last_line := line_index >= dialogue_lines.size() - 1
	line_hint.visible = not on_last_line
	if on_last_line and options.get_child_count() == 0:
		for index in range(current_options.size()):
			var option: Dictionary = current_options[index]
			options.add_child(_button(str(option.get("text", "继续")), _select_option.bind(index), true))
		if options.get_child_count() > 0:
			options.get_child(0).grab_focus()

func _advance_dialogue() -> void:
	if not dialogue_open or busy:
		return
	if is_instance_valid(pokemon_battle) and pokemon_battle.battle_active:
		return
	if line_index < dialogue_lines.size() - 1:
		line_index += 1
		_show_current_line()
	elif current_options.is_empty():
		close_dialogue()

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
			if ok:
				farm.set_pigpen_open(true)
				_show_toast("迈出第一步！", "身后的过往在紧追不放，沿山路逃往牛耕地！")
		"choose_blue":
			ok = GameManager.choose_blue()
			if ok:
				close_dialogue()
				_show_ending()
		"complete_ox", "complete_sheep", "complete_horse":
			var id := event_id.trim_prefix("complete_")
			if not GameManager.npc_completed.get(id, false):
				farm.set_npc_completed(id)
				await get_tree().create_timer(0.85).timeout
				ok = GameManager.complete_npc(id)
				if id == "ox":
					farm.set_named_gate_open("ox", true)
					_show_skill_unlock(
						"【 坚 韧 挣 脱 】",
						"借老牛坚忍不屈的硬骨气 · 挣脱命运的死锁",
						"【核心按键】 被咬住时狂按 [ 空格键 / SPACE ] 或 [ E ]",
						"被恶犬扑咬纠缠时，在 3.5 秒内猛敲空格 5 次，即可爆发巨力震退恶犬 6 米并使其眩晕！"
					)
				elif id == "sheep":
					farm.set_named_gate_open("sheep", true)
					_show_skill_unlock(
						"【 破 妄 明 眸 】",
						"借小羊清澈明辨的目光 · 看穿虚张声势的恐吓",
						"【被动视觉】 幻影恶犬将显现为半透明紫灰虚影",
						"幻影恶犬无法阻拦你，穿过虚影会使其化作烟尘消散！专心避开实体黑犬即可！"
					)
				elif id == "horse":
					farm.set_named_gate_open("horse", true)
					_show_skill_unlock(
						"【 疾 风 冲 刺 】",
						"借追风骏马四蹄翻腾的疾速 · 踏碎一切围追堵截",
						"【核心按键】 长按 [ Shift 键 ] 消耗体力加速",
						"长按多久就加速多久，松开即刻自动恢复体力！在恶犬红圈扑杀时按 Shift 灵巧闪避！"
					)
			else: ok = false
		"read_record": GameManager.read_record()
		"complete_showdown":
			ok = GameManager.complete_showdown()
			if ok: farm.set_gate_open(true)
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
	if in_start_menu:
		in_start_menu = false
		if is_instance_valid(start_menu):
			start_menu.visible = false
	dialogue_open = false
	dialogue_panel.visible = false
	_restore_control()
	_refresh_hud()

func _restore_control() -> void:
	if in_start_menu: player.set_control_mode("cinematic")
	elif in_skill_card: player.set_control_mode("cinematic")
	elif cinematic: player.set_control_mode("cinematic")
	elif paused: player.set_control_mode("paused")
	elif in_qte: player.set_control_mode("qte")
	elif GameManager.stage == "ending" or (overlay.visible and not paused): player.set_control_mode("ending")
	elif dialogue_open: player.set_control_mode("dialogue")
	else: player.set_control_mode("chase" if GameManager.is_in_chase() else "explore")

# -------------------------------------------------------------
# Multi-Stage Chase System
# -------------------------------------------------------------
func _on_farm_chase_triggered(stage_id: String) -> void:
	if dialogue_open or cinematic or overlay.visible or GameManager.is_in_chase(): return
	if GameManager.chase_completed.get(stage_id, false): return
	
	# Pre-requisite checks
	if stage_id == "chase_2" and not GameManager.npc_completed.get("ox", false): return
	if stage_id == "chase_3" and not GameManager.npc_completed.get("sheep", false): return
	
	start_stage_chase(stage_id)

func start_stage_chase(stage_id: String) -> void:
	current_chase_id = stage_id
	if COURSE_SCENES.has(stage_id):
		_enter_course(stage_id)
		return
	if not GameManager.start_stage_chase(stage_id): return
	player.set_control_mode("chase")
	
	var config: Dictionary = L.CHASE_CONFIGS.get(stage_id, {})
	var route_name: String = str(config.get("route", "chase"))
	var points: Array[Vector3] = L.path(route_name)
	
	_show_toast(str(config.get("title", "追逐开始！")), str(config.get("desc", "向前跑！")))
	chase.start_stage(stage_id, player, config, points)
	_refresh_hud()

func _start_chase() -> void:
	# Standard entrance trigger for the final courtyard chase
	if dialogue_open or cinematic or overlay.visible: return
	start_stage_chase("chase_final")

# -------------------------------------------------------------
# Course Mode (Fall Guys-style obstacle courses)
# -------------------------------------------------------------
func _enter_course(stage_id: String) -> void:
	if is_instance_valid(active_course): return
	active_course = COURSE_SCENES[stage_id].instantiate()
	add_child(active_course)
	if is_instance_valid(farm) and farm.get_parent() == self:
		remove_child(farm)
		_farm_removed = true
	active_course.setup(player)
	player.set_control_mode("explore")
	camera.snap_to_target()
	active_course.runner.course_started.connect(_on_course_started)
	active_course.runner.course_completed.connect(_on_course_completed)
	active_course.runner.qte_requested.connect(_on_qte_requested)
	active_course.runner.player_respawned.connect(func(_pos: Vector3): camera.snap_to_target())
	_show_toast(active_course.runner.config.title, active_course.runner.config.desc)
	_refresh_hud()

func _on_course_started() -> void:
	GameManager.start_stage_chase(current_chase_id)
	player.set_control_mode("chase")
	_refresh_hud()

func _on_course_completed() -> void:
	GameManager.complete_stage_chase(current_chase_id)
	# Defer the world swap out of the physics callback so the pig's reset position
	# is not overwritten by the same frame's move_and_slide.
	_finish_course_deferred.call_deferred()

func _finish_course_deferred() -> void:
	_exit_course()
	_show_toast("闯关成功！", "牛耕地赛道通关，回到农场前往溪流区。")
	_refresh_hud()

func _exit_course() -> void:
	if is_instance_valid(active_course):
		active_course.queue_free()
		active_course = null
	if _farm_removed and is_instance_valid(farm):
		add_child(farm)
		_farm_removed = false
	for id in GameManager.npc_completed:
		if GameManager.npc_completed[id]:
			farm.set_npc_completed(id)
	if GameManager.chase_completed.get("chase_1", false):
		farm.set_named_gate_open("ox", true)
	player.reset_at(L.path("creek")[0] + Vector3.UP * 0.5)
	player.set_control_mode("explore")
	camera.snap_to_target()

func _on_farm_gate_passed(gate_id: String) -> void:
	# Player safely crossed a zone gate!
	if GameManager.is_in_chase():
		chase.stop_chase()
		var completed_id := current_chase_id
		GameManager.complete_stage_chase(completed_id)
		player.set_control_mode("explore")
		_show_toast("成功脱险！", "大门已轰然锁上，恶犬被挡在门外。")
		_refresh_hud()

func _on_chase_finished(success: bool) -> void:
	if success:
		chase.stop_chase()
		GameManager.complete_stage_chase(current_chase_id)
		player.set_control_mode("explore")
		_refresh_hud()
	else:
		player.set_control_mode("ending")
		var tip := "沿小路奔跑，按空格越过倒木障碍！被恶犬咬住时狂按空格拼命挣脱！"
		if GameManager.has_struggle_skill:
			tip = "【坚韧挣脱】已激活：被咬住时，在 3.5 秒内狂敲 [空格键 / SPACE] 5 次即可震退恶犬！"
		_show_overlay("被犬队追上了", tip, [{"text": "从本段起点重试", "call": _retry}, {"text": "从头开始", "call": _restart}])

func _retry() -> void:
	chase.stop_chase()
	in_qte = false
	overlay.visible = false
	
	var config: Dictionary = L.CHASE_CONFIGS.get(current_chase_id, {})
	var retry_pos: Vector3 = config.get("retry", farm.RETRY_POSITION)
	
	player.reset_at(retry_pos)
	farm._checkpoint = retry_pos
	camera.snap_to_target()
	
	if current_chase_id == "chase_final" or current_chase_id == "chase":
		GameManager.retry_chase()
	else:
		GameManager.stage = "exploring"
		
	_restore_control()
	_refresh_hud()

func _launch_cablecar() -> void:
	cinematic = true
	player.set_control_mode("cinematic")
	var cabin: Node3D = farm.get_cablecar()
	player.global_position = cabin.global_position + Vector3(0, 0.5, 0)
	player.set_physics_process(false)
	var tween := create_tween().set_parallel(true)
	var direction: Vector3 = farm.CABLECAR_TRAVEL
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
		_show_overlay("旷野归途", "金牌是农场的，但命是你自己的。\n\n风从麦浪上吹来。前面没有围栏与食槽。", [{"text": "重新出发", "call": _restart}])
	ending_art.texture = ART_2D.ENDINGS.get(GameManager.ending)
	ending_art.visible = ending_art.texture != null

func _show_overlay(title: String, body: String, buttons: Array) -> void:
	ending_art.hide()
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
