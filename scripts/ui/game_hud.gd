class_name GameHud
extends RefCounted
# UI CONSTRUCTION ONLY for the farm level (office_level_1.gd).
# Every builder assigns the level's existing UI member fields (host.prompt, host.hud,
# host.qte_panel, ...) so all behavior/state stays in the level script and every
# existing test that pokes office.<field> keeps working unchanged.
# 视觉：UiKit 卡通缝线补丁风（奶油纸 / 圆体字 / 鼠尾草绿 / 湖青 / 珊瑚橙）。

const UI = preload("res://scripts/ui/ui_kit.gd")

static func build_all(host: Node) -> void:
	var layer := CanvasLayer.new()
	host.add_child(layer)
	host.hud = Control.new()
	host.hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host.hud)
	UI.apply(host.hud)

	_build_prompt(host)
	_build_dialogue_panel(host)
	_build_overlay(host)
	_build_todo_notebook(host)
	_build_qte_panel(host)
	_build_dash_gauge(host)
	_build_toast_banner(host)
	_build_notice_feed(host)
	_build_key_strip(host)

static func _build_key_strip(host: Node) -> void:
	# Key-test strip, ported from the old opening pen: keycap per bound key,
	# lights up while held (office_level_1._process drives the highlight).
	# Built hidden - only the pigpen tutorial boot turns it on.
	var strip := UI.patch_panel(18, UI.PAPER, UI.TEAL, Vector2(20, 12))
	strip.name = "KeyTestStrip"
	# MINSIZE preset is applied while the strip is still empty (min size 0), so
	# the keycap rows added below grow the panel afterwards - that growth must
	# go UP, or the strip sinks past the bottom edge (default grow_vertical is
	# END/down; same trap the achievement popup's grow-directions dodge).
	strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.offset_top -= 24
	strip.offset_bottom -= 24
	strip.visible = false
	host.hud.add_child(strip)
	host.key_strip = strip
	var caps := {}
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	strip.add_child(rows)
	var caption := UI.label("开演前先试试蹄子——按键当场生效 ｜ 走到山羊旁按 [ F ] 开始今天的农场", 16, UI.TEAL_DEEP, true)
	caption.name = "KeyTestCaption"
	rows.add_child(caption)
	var line1 := HBoxContainer.new()
	line1.add_theme_constant_override("separation", 12)
	rows.add_child(line1)
	_key_group(line1, ["W", "A", "S", "D"], "移动", ["move_up", "move_left", "move_down", "move_right"], caps)
	_key_group(line1, ["空格"], "跳跃+哼哼", ["action_jump"], caps)
	var line2 := HBoxContainer.new()
	line2.add_theme_constant_override("separation", 12)
	rows.add_child(line2)
	_key_group(line2, ["Shift"], "长按冲刺 · 点按闪避", ["action_dash"], caps)
	_key_group(line2, ["Shift+空格"], "惨叫跳", ["__squeal__"], caps)
	_key_group(line2, ["F", "E", "K"], "拱食槽 / 交互", ["action_interact", "action_interact", "action_interact"], caps)
	_key_group(line2, ["🖱+"], "点击走位", ["__mouse__"], caps)
	host.key_strip_caps = caps

static func _key_group(row: HBoxContainer, keys: Array, desc: String, actions: Array, caps: Dictionary) -> void:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	row.add_child(group)
	for i in keys.size():
		var cap := UI.keycap(keys[i], 15, UI.TEAL)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(cap)
		var tag: String = actions[i]
		if not caps.has(tag):
			caps[tag] = []
		caps[tag].append(cap)
	var label := UI.label(" " + desc, 15, UI.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(label)

static func _center_pivot(node: Control) -> void:
	node.resized.connect(func(): node.pivot_offset = node.size * 0.5)

static func _build_prompt(host: Node) -> void:
	# 互动提示：底部居中的奶油胶囊键位提示，宽度随文字自适应。
	host.prompt = UI.label("", 19, UI.INK, true)
	host.prompt.add_theme_stylebox_override("normal", UI.pill(Color(UI.PAPER, 0.96), 20, UI.PAPER_EDGE, 2, Vector2(20, 7), true))
	host.prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	host.prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	host.prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	host.prompt.offset_top = -36
	host.prompt.offset_bottom = -36
	host.prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.hud.add_child(host.prompt)

static func _build_dialogue_panel(host: Node) -> void:
	# 对话：底部缝线补丁 + 左侧头像补丁框 + NPC 名牌胶囊。
	host.dialogue_panel = UI.patch_panel(22, UI.PAPER, UI.PINK, Vector2(28, 22))
	host.dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	host.dialogue_panel.offset_left = 130
	host.dialogue_panel.offset_right = -130
	host.dialogue_panel.offset_top = -310
	host.dialogue_panel.offset_bottom = -48
	host.dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	host.hud.add_child(host.dialogue_panel)

	var dialogue_row := HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation", 24)
	dialogue_row.mouse_filter = Control.MOUSE_FILTER_PASS
	host.dialogue_panel.add_child(dialogue_row)

	var portrait_frame := UI.patch_panel(26, UI.WHITE, UI.SAGE, Vector2(8, 8))
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_row.add_child(portrait_frame)
	host.portrait = TextureRect.new()
	host.portrait.custom_minimum_size = Vector2(150, 150)
	host.portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(host.portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_row.add_child(column)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(name_row)
	var name_pill := PanelContainer.new()
	name_pill.add_theme_stylebox_override("panel", UI.pill(UI.SAGE, 14, Color.TRANSPARENT, 0, Vector2(16, 4), true))
	name_pill.mouse_filter = Control.MOUSE_FILTER_PASS
	name_row.add_child(name_pill)
	host.speaker_label = UI.label("", 20, UI.INK, true)
	host.speaker_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_pill.add_child(host.speaker_label)

	host.content_label = UI.label("", 20, UI.INK)
	host.content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.content_label.mouse_filter = Control.MOUSE_FILTER_PASS
	host.content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(host.content_label)

	host.line_hint = UI.label("▼ 点击 / 空格 继续", 14, UI.INK_SOFT)
	host.line_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host.line_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(host.line_hint)

	host.options = VBoxContainer.new()
	host.options.add_theme_constant_override("separation", 8)
	column.add_child(host.options)
	host.dialogue_panel.visible = false

static func _build_overlay(host: Node) -> void:
	# 结算 / 失败覆盖层：暖奶油全屏 + 居中缝线大补丁。
	host.overlay = ColorRect.new()
	host.overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.overlay.color = Color(UI.PAPER, 0.96)
	host.hud.add_child(host.overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.overlay.add_child(center)
	var card := UI.patch_panel(26, UI.PAPER, UI.PINK, Vector2(40, 32))
	card.custom_minimum_size.x = 640
	center.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)
	var art_frame := UI.patch_panel(20, UI.WHITE, UI.SAGE, Vector2(8, 8))
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(art_frame)
	host.ending_art = TextureRect.new()
	host.ending_art.custom_minimum_size = Vector2(600, 270)
	host.ending_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.ending_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.ending_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(host.ending_art)
	host.ending_art.visibility_changed.connect(func(): art_frame.visible = host.ending_art.visible)
	host.ending_art.hide()
	host.overlay_title = UI.label("", 40, UI.TEAL_DEEP, true)
	host.overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(host.overlay_title)
	host.overlay_text = UI.label("", 20, UI.INK)
	host.overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.overlay_text.custom_minimum_size.x = 600
	host.overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(host.overlay_text)
	host.overlay_buttons = VBoxContainer.new()
	host.overlay_buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(host.overlay_buttons)
	host.overlay.visible = false

static func _build_todo_notebook(host: Node) -> void:
	# 右上角挂件组：两枚胶囊按钮（今日待办 / 键位说明）+ 折叠的待办补丁。
	# 待办默认只露按钮，点按钮展开/收起（office_level_1 持有状态机：跑动折叠、
	# 静止闪烁招引点击、久站自动展开）；键位说明点开 10 秒自动收起。
	var hub := VBoxContainer.new()
	hub.name = "TodoHub"
	hub.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	# MINSIZE leaves a zero-width rect at the corner anchor: the hub must grow
	# LEFT-and-down from that point, or it collapses into an edge sliver.
	hub.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hub.grow_vertical = Control.GROW_DIRECTION_END
	hub.offset_left = -24
	hub.offset_right = -24
	hub.offset_top = 24
	hub.offset_bottom = 24
	hub.add_theme_constant_override("separation", 10)
	# 容器自身不吃鼠标：空隙处点击照常走位，按钮自己收事件。
	hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.hud.add_child(hub)
	host.todo_hub = hub

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hub.add_child(btn_row)

	var todo_btn := UI.button("📋 今日待办", host._toggle_todo)
	todo_btn.name = "TodoToggleButton"
	todo_btn.custom_minimum_size = Vector2(0, 34)
	todo_btn.add_theme_font_size_override("font_size", 15)
	todo_btn.focus_mode = Control.FOCUS_NONE # F/Enter/Space 属于猪，不属于按钮
	btn_row.add_child(todo_btn)
	host.todo_toggle_btn = todo_btn

	var keys_btn := UI.button("⌨ 键位说明", host._toggle_key_strip)
	keys_btn.name = "KeysToggleButton"
	keys_btn.custom_minimum_size = Vector2(0, 34)
	keys_btn.add_theme_font_size_override("font_size", 15)
	keys_btn.focus_mode = Control.FOCUS_NONE
	btn_row.add_child(keys_btn)
	host.keys_toggle_btn = keys_btn

	# 待办补丁：微微歪斜的缝线纸片，像贴在按钮下面的一张便利贴。
	host.todo_notebook = UI.patch_panel(16, UI.PAPER, UI.PINK, Vector2(20, 16))
	host.todo_notebook.name = "TodoNotebook"
	# 高度随待办条目数增减（容器自己长高长矮），宽度压住 330；
	# 上限由 _refresh_todo_list 的条目数封顶控制（3 条进行中 + 最近 2 条已完成）。
	host.todo_notebook.custom_minimum_size = Vector2(330, 0)
	host.todo_notebook.mouse_filter = Control.MOUSE_FILTER_PASS
	host.todo_notebook.rotation_degrees = -1.4
	_center_pivot(host.todo_notebook)
	host.todo_notebook.visible = false # 默认折叠：初始状态只露出右上角按钮
	hub.add_child(host.todo_notebook)

	var notebook_layout := VBoxContainer.new()
	notebook_layout.add_theme_constant_override("separation", 8)
	host.todo_notebook.add_child(notebook_layout)

	var header_box := HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	notebook_layout.add_child(header_box)
	var pin_icon := UI.label("✎", 18, UI.CORAL, true)
	header_box.add_child(pin_icon)
	var nb_title := UI.label("今日待办 · TO-DO", 18, UI.TEAL_DEEP, true)
	header_box.add_child(nb_title)

	var sep := HSeparator.new()
	notebook_layout.add_child(sep)

	host.todo_vbox = VBoxContainer.new()
	host.todo_vbox.add_theme_constant_override("separation", 7)
	notebook_layout.add_child(host.todo_vbox)

	host._refresh_todo_list()

static func _build_qte_panel(host: Node) -> void:
	# 挣脱 QTE：珊瑚缝线补丁 + 大键帽 + 圆角进度条。
	host.qte_panel = UI.patch_panel(22, UI.PAPER, UI.CORAL, Vector2(28, 20))
	host.qte_panel.name = "StruggleQTEPanel"
	host.qte_panel.set_anchors_preset(Control.PRESET_CENTER)
	host.qte_panel.offset_left = -240
	host.qte_panel.offset_top = -155
	host.qte_panel.offset_right = 240
	host.qte_panel.offset_bottom = 105
	host.qte_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_pivot(host.qte_panel)
	host.hud.add_child(host.qte_panel)

	var qte_layout := VBoxContainer.new()
	qte_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	qte_layout.add_theme_constant_override("separation", 10)
	host.qte_panel.add_child(qte_layout)

	var key_row := HBoxContainer.new()
	key_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qte_layout.add_child(key_row)
	key_row.add_child(UI.keycap("SPACE", 24, UI.RED))

	host.qte_btn_label = UI.label("【 狂按空格键 / SPACE 】", 23, UI.RED, true)
	host.qte_btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_pivot(host.qte_btn_label)
	qte_layout.add_child(host.qte_btn_label)

	host.qte_desc_label = UI.label("恶犬扑咬！连续猛击按键拼命挣脱！", 16, UI.INK_SOFT)
	host.qte_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte_layout.add_child(host.qte_desc_label)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 12)
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qte_layout.add_child(bar_row)

	host.qte_bar = UI.progress_bar(0, host.QTE_TARGET_HITS, UI.CORAL, Vector2(280, 22))
	bar_row.add_child(host.qte_bar)

	host.qte_counter_label = UI.label("0 / 5", 17, UI.RED, true)
	bar_row.add_child(host.qte_counter_label)

	host.qte_timer_bar = UI.progress_bar(host.QTE_TIME_TOTAL, host.QTE_TIME_TOTAL, UI.SUNNY, Vector2(340, 8))
	qte_layout.add_child(host.qte_timer_bar)

	host.qte_panel.visible = false

static func _build_dash_gauge(host: Node) -> void:
	# 冲刺体力：右下角奶油小胶囊 + 闪电 + 圆角体力条。
	host.dash_gauge = Control.new()
	host.dash_gauge.name = "DashGauge"
	host.dash_gauge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	host.dash_gauge.offset_left = -220
	host.dash_gauge.offset_top = -70
	host.dash_gauge.offset_right = -25
	host.dash_gauge.offset_bottom = -25
	host.dash_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.hud.add_child(host.dash_gauge)

	var capsule := PanelContainer.new()
	capsule.add_theme_stylebox_override("panel", UI.pill(Color(UI.PAPER, 0.94), 20, UI.PAPER_EDGE, 2, Vector2(14, 8), true))
	capsule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.dash_gauge.add_child(capsule)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule.add_child(hbox)

	var icon := UI.label("⚡", 18, UI.SUNNY, true)
	hbox.add_child(icon)

	host.dash_bar = UI.progress_bar(3.0, 3.0, UI.SAGE_DEEP, Vector2(130, 14))
	hbox.add_child(host.dash_bar)

	host.dash_gauge.visible = false

static func _build_toast_banner(host: Node) -> void:
	# 提示横幅：鼠尾草缝线奶油补丁，标题湖青加粗。
	host.toast_panel = UI.patch_panel(18, UI.PAPER, UI.SAGE, Vector2(24, 12))
	host.toast_panel.name = "ToastBanner"
	host.toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	host.toast_panel.offset_left = -330
	host.toast_panel.offset_top = -142
	host.toast_panel.offset_right = 330
	host.toast_panel.offset_bottom = -78
	host.toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.hud.add_child(host.toast_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	host.toast_panel.add_child(vbox)

	host.toast_title = UI.label("", 19, UI.TEAL_DEEP, true)
	host.toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(host.toast_title)

	host.toast_desc = UI.label("", 15, UI.INK_SOFT)
	host.toast_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(host.toast_desc)

	host.toast_panel.visible = false

static func _build_notice_feed(host: Node) -> void:
	# 右下角通知流：彩蛋触发台词的统一去处。世界里的 Label3D 小字在
	# 镜头拉远后不可读，这里用屏幕角落的补丁卡片逐条弹出、自动消退。
	# 底边抬高到成就弹窗（AchievementPopup，右下角 24px）上方，避免同屏重叠。
	host.notice_feed = VBoxContainer.new()
	host.notice_feed.name = "NoticeFeed"
	host.notice_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	host.notice_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	host.notice_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	host.notice_feed.add_theme_constant_override("separation", 8)
	host.notice_feed.alignment = BoxContainer.ALIGNMENT_END
	host.notice_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.notice_feed.offset_left = -420
	host.notice_feed.offset_right = -24
	# 留出右下角成就弹窗的高度（约 120px），通知叠在它上方。
	host.notice_feed.offset_top = -500
	host.notice_feed.offset_bottom = -150
	host.hud.add_child(host.notice_feed)
	# 技能解锁/赛道借得不再有居中卡片：office_level_1._notify_skill 把它们作为
	# 富卡片压进这条右下角通知流（弹入、停留、自动淡出，不锁猪）。