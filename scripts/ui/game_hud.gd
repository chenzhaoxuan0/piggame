class_name GameHud
extends RefCounted
# UI CONSTRUCTION ONLY for the farm level (office_level_1.gd).
# Every builder assigns the level's existing UI member fields (host.prompt, host.hud,
# host.qte_panel, ...) so all behavior/state stays in the level script and every
# existing test that pokes office.<field> keeps working unchanged.

static func style(bg: Color, border: Color = Color(0.40, 0.38, 0.30), radius: int = 12) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = bg
	style_box.border_color = border
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(radius)
	style_box.content_margin_left = 22
	style_box.content_margin_right = 22
	style_box.content_margin_top = 15
	style_box.content_margin_bottom = 15
	return style_box

static func label(text_value: String, font_size: int = 18) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text_value: String, callback: Callable, align_left: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.custom_minimum_size.y = 44
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_CENTER
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.pressed.connect(callback)
	btn.add_theme_color_override("font_color", Color("343b30"))
	btn.add_theme_color_override("font_hover_color", Color("343b30"))
	btn.add_theme_color_override("font_focus_color", Color("343b30"))
	return btn

static func build_all(host: Node) -> void:
	var layer := CanvasLayer.new()
	host.add_child(layer)
	host.hud = Control.new()
	host.hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host.hud)

	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	theme.default_font = font
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", Color(0.24, 0.27, 0.20))
	theme.set_stylebox("normal", "Button", style(Color(0.92, 0.88, 0.76), Color(0.36, 0.34, 0.26), 8))
	theme.set_stylebox("hover", "Button", style(Color(0.99, 0.95, 0.78), Color(0.78, 0.52, 0.18), 8))
	theme.set_stylebox("pressed", "Button", style(Color(0.80, 0.76, 0.62), Color(0.36, 0.34, 0.26), 8))
	theme.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), Color(0.85, 0.60, 0.20), 8))
	host.hud.theme = theme

	_build_prompt(host)
	_build_dialogue_panel(host)
	_build_overlay(host)
	_build_todo_notebook(host)
	_build_qte_panel(host)
	_build_dash_gauge(host)
	_build_toast_banner(host)
	_build_skill_card(host)

static func _build_prompt(host: Node) -> void:
	# Clean interaction prompt (Untitled Goose Game small pill at bottom)
	host.prompt = label("", 19)
	host.prompt.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.75))
	host.prompt.add_theme_constant_override("shadow_offset_x", 1)
	host.prompt.add_theme_constant_override("shadow_offset_y", 1)
	host.prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	host.prompt.offset_left = -420
	host.prompt.offset_right = 420
	host.prompt.offset_top = -85
	host.prompt.offset_bottom = -45
	host.prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.hud.add_child(host.prompt)

static func _build_dialogue_panel(host: Node) -> void:
	# Minimalist Warm Paper Dialogue Panel (wiring happens in the level script)
	host.dialogue_panel = PanelContainer.new()
	host.dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	host.dialogue_panel.offset_left = 120
	host.dialogue_panel.offset_right = -120
	host.dialogue_panel.offset_top = -320
	host.dialogue_panel.offset_bottom = -50
	host.dialogue_panel.add_theme_stylebox_override("panel", style(Color(0.98, 0.96, 0.90, 0.98), Color(0.42, 0.38, 0.28), 16))
	host.dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	host.hud.add_child(host.dialogue_panel)

	var dialogue_row := HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation", 22)
	dialogue_row.mouse_filter = Control.MOUSE_FILTER_PASS
	host.dialogue_panel.add_child(dialogue_row)

	host.portrait = TextureRect.new()
	host.portrait.custom_minimum_size = Vector2(160, 160)
	host.portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_row.add_child(host.portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_row.add_child(column)

	host.speaker_label = label("", 21)
	host.speaker_label.add_theme_color_override("font_color", Color(0.58, 0.32, 0.14))
	host.speaker_label.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(host.speaker_label)

	host.content_label = label("", 19)
	host.content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.content_label.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(host.content_label)

	host.line_hint = label("▼ 点击继续", 14)
	host.line_hint.add_theme_color_override("font_color", Color(0.48, 0.50, 0.40))
	host.line_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host.line_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(host.line_hint)

	host.options = VBoxContainer.new()
	host.options.add_theme_constant_override("separation", 6)
	column.add_child(host.options)
	host.dialogue_panel.visible = false

static func _build_overlay(host: Node) -> void:
	# Fullscreen Overlay for Ending & Failure
	host.overlay = ColorRect.new()
	host.overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.overlay.color = Color(0.95, 0.93, 0.86, 0.97)
	host.hud.add_child(host.overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.overlay.add_child(center)
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 600
	card.add_theme_constant_override("separation", 22)
	center.add_child(card)
	host.ending_art = TextureRect.new()
	host.ending_art.custom_minimum_size = Vector2(600, 270)
	host.ending_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.ending_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.ending_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.ending_art.hide()
	card.add_child(host.ending_art)
	host.overlay_title = label("", 38)
	host.overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(host.overlay_title)
	host.overlay_text = label("", 20)
	host.overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.overlay_text.custom_minimum_size.x = 600
	host.overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(host.overlay_text)
	host.overlay_buttons = VBoxContainer.new()
	host.overlay_buttons.add_theme_constant_override("separation", 10)
	card.add_child(host.overlay_buttons)
	host.overlay.visible = false

static func _build_todo_notebook(host: Node) -> void:
	host.todo_notebook = PanelContainer.new()
	host.todo_notebook.name = "TodoNotebook"
	host.todo_notebook.custom_minimum_size = Vector2(330, 200)
	host.todo_notebook.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	host.todo_notebook.offset_left = -350
	host.todo_notebook.offset_top = 22
	host.todo_notebook.offset_right = -20
	host.todo_notebook.offset_bottom = 260
	host.todo_notebook.mouse_filter = Control.MOUSE_FILTER_PASS

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
	host.todo_notebook.add_theme_stylebox_override("panel", paper_style)
	host.hud.add_child(host.todo_notebook)

	var notebook_layout := VBoxContainer.new()
	notebook_layout.add_theme_constant_override("separation", 8)
	host.todo_notebook.add_child(notebook_layout)

	# Notebook header
	var header_box := HBoxContainer.new()
	notebook_layout.add_child(header_box)

	var pin_icon := label("✎", 16)
	pin_icon.add_theme_color_override("font_color", Color(0.68, 0.32, 0.18))
	header_box.add_child(pin_icon)

	var nb_title := label("待办事项 / TO-DO", 16)
	nb_title.add_theme_color_override("font_color", Color(0.36, 0.30, 0.22))
	header_box.add_child(nb_title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.50, 0.44, 0.34, 0.5)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	notebook_layout.add_child(sep)

	host.todo_vbox = VBoxContainer.new()
	host.todo_vbox.add_theme_constant_override("separation", 7)
	notebook_layout.add_child(host.todo_vbox)

	host._refresh_todo_list()

static func _build_qte_panel(host: Node) -> void:
	host.qte_panel = PanelContainer.new()
	host.qte_panel.name = "StruggleQTEPanel"
	host.qte_panel.set_anchors_preset(Control.PRESET_CENTER)
	host.qte_panel.offset_left = -230
	host.qte_panel.offset_top = -145
	host.qte_panel.offset_right = 230
	host.qte_panel.offset_bottom = 95
	host.qte_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	host.qte_panel.add_theme_stylebox_override("panel", qte_box)
	host.hud.add_child(host.qte_panel)

	var qte_layout := VBoxContainer.new()
	qte_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	qte_layout.add_theme_constant_override("separation", 10)
	host.qte_panel.add_child(qte_layout)

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

	host.qte_btn_label = label("【 狂按空格键 / SPACE 】", 23)
	host.qte_btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.qte_btn_label.add_theme_color_override("font_color", Color(0.72, 0.22, 0.14))
	badge.add_child(host.qte_btn_label)

	host.qte_desc_label = label("恶犬扑咬！连续猛击按键拼命挣脱！", 16)
	host.qte_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.qte_desc_label.add_theme_color_override("font_color", Color(0.36, 0.30, 0.22))
	qte_layout.add_child(host.qte_desc_label)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 12)
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qte_layout.add_child(bar_row)

	host.qte_bar = ProgressBar.new()
	host.qte_bar.custom_minimum_size = Vector2(280, 24)
	host.qte_bar.max_value = host.QTE_TARGET_HITS
	host.qte_bar.value = 0
	host.qte_bar.show_percentage = false
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.82, 0.34, 0.18)
	bar_fill.set_corner_radius_all(8)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.86, 0.82, 0.72)
	bar_bg.set_corner_radius_all(8)
	host.qte_bar.add_theme_stylebox_override("fill", bar_fill)
	host.qte_bar.add_theme_stylebox_override("background", bar_bg)
	bar_row.add_child(host.qte_bar)

	host.qte_counter_label = label("0 / 5", 16)
	host.qte_counter_label.add_theme_color_override("font_color", Color(0.72, 0.22, 0.14))
	bar_row.add_child(host.qte_counter_label)

	host.qte_timer_bar = ProgressBar.new()
	host.qte_timer_bar.custom_minimum_size = Vector2(340, 6)
	host.qte_timer_bar.max_value = host.QTE_TIME_TOTAL
	host.qte_timer_bar.value = host.QTE_TIME_TOTAL
	host.qte_timer_bar.show_percentage = false
	var timer_fill := StyleBoxFlat.new()
	timer_fill.bg_color = Color(0.55, 0.48, 0.36)
	var timer_bg := StyleBoxFlat.new()
	timer_bg.bg_color = Color(0.85, 0.82, 0.72)
	host.qte_timer_bar.add_theme_stylebox_override("fill", timer_fill)
	host.qte_timer_bar.add_theme_stylebox_override("background", timer_bg)
	qte_layout.add_child(host.qte_timer_bar)

	host.qte_panel.visible = false

static func _build_dash_gauge(host: Node) -> void:
	host.dash_gauge = Control.new()
	host.dash_gauge.name = "DashGauge"
	host.dash_gauge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	host.dash_gauge.offset_left = -210
	host.dash_gauge.offset_top = -68
	host.dash_gauge.offset_right = -25
	host.dash_gauge.offset_bottom = -25
	host.dash_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.hud.add_child(host.dash_gauge)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	host.dash_gauge.add_child(hbox)

	var icon := label("⚡", 18)
	icon.add_theme_color_override("font_color", Color(0.82, 0.58, 0.18))
	hbox.add_child(icon)

	host.dash_bar = ProgressBar.new()
	host.dash_bar.custom_minimum_size = Vector2(130, 16)
	host.dash_bar.max_value = 3.0
	host.dash_bar.value = 3.0
	host.dash_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.42, 0.75, 0.38) # Goose green when full
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.40, 0.36, 0.28, 0.8)
	bg.set_corner_radius_all(6)
	host.dash_bar.add_theme_stylebox_override("fill", fill)
	host.dash_bar.add_theme_stylebox_override("background", bg)
	hbox.add_child(host.dash_bar)

	host.dash_gauge.visible = false

static func _build_toast_banner(host: Node) -> void:
	host.toast_panel = PanelContainer.new()
	host.toast_panel.name = "ToastBanner"
	host.toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	host.toast_panel.offset_left = -320
	host.toast_panel.offset_top = -140
	host.toast_panel.offset_right = 320
	host.toast_panel.offset_bottom = -80
	host.toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.18, 0.20, 0.16, 0.88)
	toast_style.border_color = Color(0.75, 0.68, 0.52)
	toast_style.set_border_width_all(2)
	toast_style.set_corner_radius_all(12)
	toast_style.content_margin_left = 18
	toast_style.content_margin_right = 18
	host.toast_panel.add_theme_stylebox_override("panel", toast_style)
	host.hud.add_child(host.toast_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	host.toast_panel.add_child(vbox)

	host.toast_title = label("", 17)
	host.toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.toast_title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
	vbox.add_child(host.toast_title)

	host.toast_desc = label("", 14)
	host.toast_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.toast_desc.add_theme_color_override("font_color", Color(0.80, 0.78, 0.70))
	vbox.add_child(host.toast_desc)

	host.toast_panel.visible = false

static func _build_skill_card(host: Node) -> void:
	host.skill_card_modal = PanelContainer.new()
	host.skill_card_modal.name = "SkillCardModal"
	host.skill_card_modal.set_anchors_preset(Control.PRESET_CENTER)
	host.skill_card_modal.offset_left = -260
	host.skill_card_modal.offset_top = -180
	host.skill_card_modal.offset_right = 260
	host.skill_card_modal.offset_bottom = 180
	host.skill_card_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.98, 0.96, 0.90, 0.99)
	card_style.border_color = Color(0.68, 0.28, 0.18) # Goose wax red
	card_style.set_border_width_all(4)
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 22
	card_style.content_margin_bottom = 22
	card_style.shadow_color = Color(0, 0, 0, 0.3)
	card_style.shadow_size = 12
	card_style.shadow_offset = Vector2(0, 6)
	host.skill_card_modal.add_theme_stylebox_override("panel", card_style)
	host.hud.add_child(host.skill_card_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	host.skill_card_modal.add_child(vbox)

	var tag := label("★ 领 悟 伙 伴 新 技 能 ★", 14)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Color(0.72, 0.28, 0.18))
	vbox.add_child(tag)

	host.skill_card_title = label("【 坚 韧 挣 脱 】", 26)
	host.skill_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.skill_card_title.add_theme_color_override("font_color", Color(0.32, 0.25, 0.16))
	vbox.add_child(host.skill_card_title)

	host.skill_card_subtitle = label("借老牛坚忍不屈的硬骨气", 15)
	host.skill_card_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.skill_card_subtitle.add_theme_color_override("font_color", Color(0.55, 0.48, 0.38))
	vbox.add_child(host.skill_card_subtitle)

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

	host.skill_card_key_label = label("【核心按键】 被咬住时狂按 [ 空格键 / SPACE ]", 17)
	host.skill_card_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.skill_card_key_label.add_theme_color_override("font_color", Color(0.75, 0.24, 0.16))
	key_panel.add_child(host.skill_card_key_label)

	host.skill_card_desc_label = label("恶犬扑咬纠缠时，在时限内猛敲 5 次，可瞬间震飞恶犬 6 米并使其眩晕！", 15)
	host.skill_card_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.skill_card_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.skill_card_desc_label.add_theme_color_override("font_color", Color(0.30, 0.28, 0.22))
	vbox.add_child(host.skill_card_desc_label)

	host.skill_card_btn = button("我 领 悟 了 (按空格或点击继续)", host._dismiss_skill_card)
	vbox.add_child(host.skill_card_btn)

	host.skill_card_modal.visible = false
