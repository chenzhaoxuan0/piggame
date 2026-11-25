class_name GameMenus
extends RefCounted

const UI = preload("res://scripts/ui/ui_kit.gd")
# Menu CONSTRUCTION ONLY (start / pause / settings + level select) for the farm
# level. Builders assign the level's existing menu member fields and bind the
# level's methods; show/hide logic and state stay in the level script.
# 视觉：UiKit 卡通缝线补丁风——主菜单参考 Piece by Piece：世界透出来、
# 奶油纸片微微歪斜、胶囊按钮、右下角键位提示。

static func build_all(host: Node) -> void:
	_build_start_menu(host)
	_build_pause_menu(host)
	_build_settings_menu(host)

static func _dim(host: Node, parent: Control, alpha: float) -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.13, 0.25, 0.23, alpha)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(bg)

# 成就墙面板：不绑 host（office 的 hud 层与开场场景的 UI 层都能挂），
# 展示时调 refresh_achievements_menu 重建行。on_close 由调用方决定回到哪个菜单。
# 制作名单与致谢面板：Kevin MacLeod BGM 的 CC BY 4.0 署名（法定义务）+
# 音效/配音/引擎致谢。数据唯一事实源在 MusicManager.CREDITS_DATA，
# 主菜单按钮点击打开（多处署名之一；仓库留档见 assets/audio/bgm/CREDITS.md）。
static func build_credits_menu(parent: Control, on_close: Callable) -> Control:
	var music: Node = Engine.get_main_loop().root.get_node_or_null("MusicManager")
	var menu := Control.new()
	menu.name = "CreditsMenu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	parent.add_child(menu)
	_dim(parent, menu, 0.55)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var card := UI.patch_panel(24, UI.PAPER, UI.SUNNY, Vector2(28, 18))
	card.custom_minimum_size = Vector2(680, 0)
	_tilt(card, 0.5)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title := UI.label("📜 制作名单与致谢", 28, UI.TEAL_DEEP, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sub := UI.label("本游戏使用了以下开放许可的素材，谨此致谢", 13, UI.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	vbox.add_child(HSeparator.new())

	# 制作人（2026-11-15 实机反馈 #20）：署名放在素材致谢之前——BGM 的
	# CC BY 义务块是这块面板的常客，但制作人的名字理应排在名单最前面。
	var producer := UI.label("制作人 · 陈兆轩 & 子鱼尘AI", 20, UI.INK, true)
	producer.name = "ProducerLine"
	producer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(producer)
	var site := UI.label("zxcorner.cn", 15, UI.TEAL_DEEP, true)
	site.name = "ProducerSite"
	site.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(site)
	var quote := UI.label("「感谢您玩我的无聊游戏，游戏史上即将迎来大便」", 13, UI.INK_SOFT)
	quote.name = "ProducerQuote"
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(quote)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	if music != null:
		for section: Dictionary in music.CREDITS_DATA:
			var head := UI.label(str(section.get("section", "")), 18, UI.TEAL_DEEP, true)
			head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rows.add_child(head)
			for item: Dictionary in section.get("items", []):
				var line := UI.label("\"%s\"  Kevin MacLeod (incompetech.com)" % item.get("title", ""), 15, UI.INK, true) \
					if section.has("license") else UI.label(str(item.get("title", "")), 15, UI.INK, true)
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				rows.add_child(line)
				var use := UI.label("　　" + str(item.get("use", "")), 13, UI.INK_SOFT)
				use.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				rows.add_child(use)
			if section.has("license"):
				# CC BY 的法定署名块：作者 + 许可名 + 许可链接，逐字按 incompetech 官方格式。
				var license_box := PanelContainer.new()
				var license_style := UI.pill(UI.PAPER_DEEP, 10, Color.TRANSPARENT, 0, Vector2(14, 10))
				license_box.add_theme_stylebox_override("panel", license_style)
				rows.add_child(license_box)
				var license_text := UI.label(str(section.get("license", "")), 13, UI.INK_SOFT)
				license_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				license_box.add_child(license_text)
			rows.add_child(HSeparator.new())

	var btn_back := UI.button("返  回", on_close)
	btn_back.name = "BackButton"
	btn_back.custom_minimum_size.y = 44
	btn_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_back)
	return menu

static func build_achievements_menu(parent: Control, on_close: Callable) -> Control:
	var menu := Control.new()
	menu.name = "AchievementsMenu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	parent.add_child(menu)
	_dim(parent, menu, 0.55)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var card := UI.patch_panel(24, UI.PAPER, UI.SUNNY, Vector2(28, 18))
	card.custom_minimum_size = Vector2(640, 0)
	_tilt(card, -0.6)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title := UI.label("🏅 成就墙", 28, UI.TEAL_DEEP, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var count := UI.label("？", 14, UI.INK_SOFT)
	count.name = "AchievementCount"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.name = "AchievementRows"
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	var btn_back := UI.button("返  回", on_close)
	btn_back.name = "BackButton"
	btn_back.custom_minimum_size.y = 44
	btn_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)
	buttons.add_child(btn_back)
	# Tester aid: achievements are unlock-once by design, so a machine that
	# already earned them can never see the popups again. One click wipes the
	# save file (memory + disk) and refreshes the wall - replay the trigger
	# and the whole unlock chain fires afresh.
	var btn_reset := UI.button("重置成就（测试用）", func():
		var am_reset: Node = Engine.get_main_loop().root.get_node_or_null("AchievementManager")
		if am_reset != null:
			am_reset.reset_progress(true)
			refresh_achievements_menu(menu)
	)
	btn_reset.name = "ResetButton"
	btn_reset.custom_minimum_size.y = 44
	buttons.add_child(btn_reset)
	return menu

static func refresh_achievements_menu(menu: Control) -> void:
	if not is_instance_valid(menu):
		return
	var rows: VBoxContainer = menu.find_child("AchievementRows", true, false)
	var count: Label = menu.find_child("AchievementCount", true, false)
	if rows == null or count == null:
		return
	for child in rows.get_children():
		child.queue_free()
	var am: Node = Engine.get_main_loop().root.get_node_or_null("AchievementManager")
	if am == null:
		return
	count.text = "已解锁 %d / %d" % [am.unlocked_count(), am.total()]
	for def in am.DEFS:
		var done: bool = am.is_unlocked(str(def["id"]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		rows.add_child(row)
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.add_theme_stylebox_override("panel", UI.pill(
			UI.SUNNY if done else UI.PAPER_DEEP, 9,
			Color.TRANSPARENT if done else UI.PAPER_EDGE, 0 if done else 2, Vector2.ZERO))
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 1)
		row.add_child(text)
		var t := UI.label(("🏅 " if done else "🔒 ") + str(def["title"]), 17,
			UI.TEAL_DEEP if done else UI.INK_SOFT, true)
		text.add_child(t)
		text.add_child(UI.label(str(def["desc"]), 13, UI.INK_SOFT))

static func _tilt(node: Control, degrees: float) -> void:
	node.rotation_degrees = degrees
	node.resized.connect(func(): node.pivot_offset = node.size * 0.5)

static func _build_start_menu(host: Node) -> void:
	host.start_menu = Control.new()
	host.start_menu.name = "StartMenu"
	host.start_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.hud.add_child(host.start_menu)
	_dim(host, host.start_menu, 0.30)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	column.offset_left = 84
	column.offset_top = 56
	column.offset_right = 560
	column.offset_bottom = 660
	column.add_theme_constant_override("separation", 18)
	host.start_menu.add_child(column)

	var title := UI.banner("一口猪在金牌农场", 54, UI.WHITE, UI.TEAL_DEEP)
	column.add_child(title)
	var subtitle := UI.name_tag("A PIG IN GOLDEN FARM · 今晚就逃离农场", UI.SUNNY, UI.INK, 16)
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(subtitle)

	var card := UI.patch_panel(22, UI.PAPER, UI.PINK, Vector2(26, 22))
	card.custom_minimum_size = Vector2(400, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tilt(card, -1.2)
	column.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var btn_start := UI.button("▶  开始游戏", host.start_dream_intro, true)
	btn_start.name = "StartButton"
	btn_start.custom_minimum_size.y = 52
	vbox.add_child(btn_start)

	# The nightmare prologue plays first; this skips straight to the pen escape.
	var btn_skip := UI.button("跳过序章，直接出圈", host.skip_dream_intro)
	btn_skip.name = "SkipIntroButton"
	btn_skip.custom_minimum_size.y = 36
	btn_skip.add_theme_font_size_override("font_size", 16)
	vbox.add_child(btn_skip)

	var btn_settings := UI.button("⚙  游戏设置", host._open_settings.bind(true))
	btn_settings.name = "SettingsButton"
	btn_settings.custom_minimum_size.y = 48
	vbox.add_child(btn_settings)

	var mcm_start := host.get_node_or_null("/root/MobileControlManager")
	if mcm_start != null:
		var mobile_row := HBoxContainer.new()
		mobile_row.name = "QuickMobileRow"
		mobile_row.add_theme_constant_override("separation", 8)
		vbox.add_child(mobile_row)

		var btn_touch := UI.button(mcm_start.touch_mode_label(), mcm_start.toggle_touch_controls)
		btn_touch.name = "StartTouchModeButton"
		btn_touch.custom_minimum_size.y = 38
		btn_touch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_touch.add_theme_font_size_override("font_size", 14)
		mobile_row.add_child(btn_touch)

		var btn_land := UI.button(mcm_start.landscape_mode_label(), mcm_start.toggle_landscape_mode)
		btn_land.name = "StartLandscapeModeButton"
		btn_land.custom_minimum_size.y = 38
		btn_land.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_land.add_theme_font_size_override("font_size", 14)
		mobile_row.add_child(btn_land)

		var sync_start_mobile := func(_unused = null):
			if is_instance_valid(btn_touch):
				btn_touch.text = mcm_start.touch_mode_label()
			if is_instance_valid(btn_land):
				btn_land.text = mcm_start.landscape_mode_label()
		mcm_start.touch_controls_changed.connect(sync_start_mobile)
		mcm_start.landscape_mode_changed.connect(sync_start_mobile)

	var btn_achv := UI.button("🏅  成就墙", host._open_achievements.bind(true))
	btn_achv.name = "AchievementsButton"
	btn_achv.custom_minimum_size.y = 44
	vbox.add_child(btn_achv)

	var btn_quit := UI.button("✕  退出游戏", func(): host.get_tree().quit())
	btn_quit.name = "QuitButton"
	btn_quit.custom_minimum_size.y = 44
	vbox.add_child(btn_quit)

	var hints := HBoxContainer.new()
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hints.offset_left = -360
	hints.offset_top = -56
	hints.offset_right = -24
	hints.offset_bottom = -16
	hints.add_theme_constant_override("separation", 10)
	hints.alignment = BoxContainer.ALIGNMENT_END
	host.start_menu.add_child(hints)
	hints.add_child(UI.key_hint("↵", "选择"))
	hints.add_child(UI.key_hint("↑↓", "移动"))

static func _build_pause_menu(host: Node) -> void:
	host.pause_menu = Control.new()
	host.pause_menu.name = "PauseMenu"
	host.pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.pause_menu.visible = false
	host.hud.add_child(host.pause_menu)
	_dim(host, host.pause_menu, 0.55)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.pause_menu.add_child(center)

	var card := UI.patch_panel(24, UI.PAPER, UI.PINK, Vector2(32, 26))
	card.custom_minimum_size = Vector2(560, 0)
	_tilt(card, 0.8)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title := UI.label("游戏暂停", 32, UI.TEAL_DEEP, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var guide_panel := PanelContainer.new()
	guide_panel.name = "GuidePanel"
	guide_panel.add_theme_stylebox_override("panel", UI.pill(UI.PAPER_DEEP, 16, UI.PAPER_EDGE, 2, Vector2(20, 14)))
	vbox.add_child(guide_panel)

	var guide_vbox := VBoxContainer.new()
	guide_vbox.add_theme_constant_override("separation", 7)
	guide_panel.add_child(guide_vbox)

	var guide_title := UI.label("键位与操作指南", 17, UI.CORAL, true)
	guide_title.name = "GuideTitle"
	guide_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_vbox.add_child(guide_title)

	var guide_items := [
		["WASD", "移动角色（方向键也可以）"],
		["鼠标", "点击地面寻路 / 点选对话选项"],
		["SPACE", "跳跃：越过倒木与溪流缺口"],
		["F / E", "与动物伙伴、场景道具交互"],
		["SHIFT", "长按冲刺 · 红圈扑咬时闪避"],
		["ESC", "暂停游戏 / 返回"],
	]
	for item in guide_items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		guide_vbox.add_child(row)
		var key := UI.keycap(item[0], 14, UI.TEAL)
		key.custom_minimum_size.x = 86
		row.add_child(key)
		row.add_child(UI.label(item[1], 15, UI.INK))

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_resume := UI.button("▶  继续游戏", host._resume, true)
	btn_resume.name = "ResumeButton"
	btn_resume.custom_minimum_size.y = 46
	vbox.add_child(btn_resume)

	var btn_settings := UI.button("⚙  游戏设置", host._open_settings.bind(false))
	btn_settings.name = "SettingsButton"
	btn_settings.custom_minimum_size.y = 44
	vbox.add_child(btn_settings)

	var btn_achv := UI.button("🏅  成就墙", host._open_achievements.bind(false))
	btn_achv.name = "AchievementsButton"
	btn_achv.custom_minimum_size.y = 44
	vbox.add_child(btn_achv)

	var btn_restart := UI.button("↺  从头开始", host._restart)
	btn_restart.name = "RestartButton"
	btn_restart.custom_minimum_size.y = 44
	vbox.add_child(btn_restart)

	# 2026-11-18 导演反馈：暂停菜单不做「返回主菜单」——主菜单（开场猪圈）
	# 只属于开机流程，对局中离开就该直接退出游戏。
	var btn_quit := UI.button("⏻  退出游戏", func(): host.get_tree().quit())
	btn_quit.name = "QuitGameButton"
	btn_quit.custom_minimum_size.y = 44
	vbox.add_child(btn_quit)

static func _build_settings_menu(host: Node) -> void:
	host.settings_menu = Control.new()
	host.settings_menu.name = "SettingsMenu"
	host.settings_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.settings_menu.visible = false
	host.hud.add_child(host.settings_menu)
	_dim(host, host.settings_menu, 0.55)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.settings_menu.add_child(center)

	var card := UI.patch_panel(24, UI.PAPER, UI.SAGE, Vector2(28, 18))
	card.custom_minimum_size = Vector2(600, 0)
	_tilt(card, -0.6)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	card.add_child(vbox)

	var title := UI.label("游戏设置", 28, UI.TEAL_DEEP, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sub := UI.label("画面 · 声音 · 关卡直达 · 关于", 14, UI.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var sep := HSeparator.new()
	vbox.add_child(sep)
	# 2026-11-17 实机反馈：设置项越加越多（画质三档 + 开关组 + 重置周目 +
	# 关卡直达七连），整卡高度超出屏幕。标题与返回固定，中间内容进滚动区，
	# 高度封顶为视口的 62%——小屏滚着看，大屏一屏尽收。
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.custom_minimum_size = Vector2(0, host.get_viewport().get_visible_rect().size.y * 0.72)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "SettingsContent"
	content.add_theme_constant_override("separation", 7)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# 画质档位（2026-11-17 评测新增）：低/中/高三档，即点即生效并持久化。
	var gm := host.get_node_or_null("/root/GraphicsManager")
	if gm != null:
		var quality_tag := UI.name_tag("🎨 画质档位 · QUALITY", UI.SUNNY, UI.INK, 15)
		quality_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(quality_tag)
		var quality_row := HBoxContainer.new()
		quality_row.name = "QualityRow"
		quality_row.add_theme_constant_override("separation", 8)
		quality_row.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(quality_row)
		for tier_id in gm.TIERS:
			var qbtn := UI.button(gm.TIER_NAMES[tier_id], gm.set_tier.bind(tier_id))
			qbtn.name = "BtnQuality_" + tier_id
			qbtn.custom_minimum_size = Vector2(160, 34)
			qbtn.add_theme_font_size_override("font_size", 15)
			quality_row.add_child(qbtn)
		var refresh_quality := func(_t: String = ""):
			for tier_id in gm.TIERS:
				var b: Button = quality_row.get_node("BtnQuality_" + tier_id)
				b.modulate = Color(1, 1, 1, 1) if gm.tier == tier_id else Color(0.72, 0.72, 0.72, 0.85)
		gm.quality_changed.connect(refresh_quality)
		refresh_quality.call()
		var quality_hint := UI.label("低：无阴影·降分辨率省电 ／ 中：均衡 ／ 高：4×抗锯齿·远阴影·色彩分级", 12, UI.INK_SOFT)
		quality_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(quality_hint)

	var toggle_high := CheckButton.new()
	toggle_high.name = "TestHighCamera"
	toggle_high.text = "测试用高视角（原高度 / 原视野）"
	toggle_high.add_theme_font_size_override("font_size", 16)
	toggle_high.button_pressed = host.camera.test_high_view
	toggle_high.toggled.connect(host.camera.set_test_high_view)
	content.add_child(toggle_high)

	var toggle_fs := CheckButton.new()
	toggle_fs.name = "FullscreenToggle"
	toggle_fs.text = "全屏显示模式"
	toggle_fs.add_theme_font_size_override("font_size", 16)
	toggle_fs.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	toggle_fs.toggled.connect(func(pressed: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	content.add_child(toggle_fs)

	var mcm_settings := host.get_node_or_null("/root/MobileControlManager")
	if mcm_settings != null:
		var mobile_tag := UI.name_tag("📱 移动端与触屏 · MOBILE", UI.SUNNY, UI.INK, 15)
		mobile_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(mobile_tag)

		var toggle_touch := CheckButton.new()
		toggle_touch.name = "TouchControlsToggle"
		toggle_touch.text = "虚拟摇杆与触屏按键（移动端操作模式）"
		toggle_touch.add_theme_font_size_override("font_size", 16)
		toggle_touch.button_pressed = mcm_settings.touch_controls_enabled
		toggle_touch.toggled.connect(func(pressed: bool):
			mcm_settings.set_touch_controls_enabled(pressed)
		)
		mcm_settings.touch_controls_changed.connect(func(enabled: bool):
			if is_instance_valid(toggle_touch) and toggle_touch.button_pressed != enabled:
				toggle_touch.set_pressed_no_signal(enabled)
		)
		content.add_child(toggle_touch)

		var toggle_land := CheckButton.new()
		toggle_land.name = "ForceLandscapeToggle"
		toggle_land.text = "强制横屏显示（竖屏手机 90° 旋转兜底）"
		toggle_land.add_theme_font_size_override("font_size", 16)
		toggle_land.button_pressed = (mcm_settings.landscape_mode == "force")
		toggle_land.toggled.connect(func(pressed: bool):
			mcm_settings.set_landscape_mode("force" if pressed else "auto")
		)
		mcm_settings.landscape_mode_changed.connect(func(mode: String):
			var want := (mode == "force")
			if is_instance_valid(toggle_land) and toggle_land.button_pressed != want:
				toggle_land.set_pressed_no_signal(want)
		)
		content.add_child(toggle_land)

		var btn_req_land := UI.button("🔄  尝试进入全屏横屏（Android 浏览器）", mcm_settings.request_native_landscape)
		btn_req_land.name = "RequestLandscapeButton"
		btn_req_land.custom_minimum_size.y = 36
		btn_req_land.add_theme_font_size_override("font_size", 14)
		content.add_child(btn_req_land)

	var toggle_mute := CheckButton.new()
	toggle_mute.name = "MuteAudioToggle"
	toggle_mute.text = "静音所有声音"
	toggle_mute.add_theme_font_size_override("font_size", 16)
	toggle_mute.button_pressed = AudioServer.is_bus_mute(0)
	toggle_mute.toggled.connect(func(pressed: bool):
		AudioServer.set_bus_mute(0, pressed)
	)
	content.add_child(toggle_mute)

	# 分轨静音（2026-11-19 录制需求）：对话配音与 BGM 各占一条子总线
	# （MusicManager._ready 建线），可单独静音——录解说/后期配音时不串音；
	# 猪叫等操作音效留在 Master，不进这两条轨。
	var music_node: Node = Engine.get_main_loop().root.get_node_or_null("MusicManager")
	if music_node != null:
		var toggle_vo := CheckButton.new()
		toggle_vo.name = "MuteVoiceToggle"
		toggle_vo.text = "静音角色对话配音（VO）"
		toggle_vo.add_theme_font_size_override("font_size", 16)
		toggle_vo.button_pressed = music_node.track_muted(music_node.VOICE_BUS)
		toggle_vo.toggled.connect(func(pressed: bool):
			music_node.set_track_muted(music_node.VOICE_BUS, pressed)
		)
		content.add_child(toggle_vo)

		var toggle_bgm := CheckButton.new()
		toggle_bgm.name = "MuteBGMToggle"
		toggle_bgm.text = "静音背景音乐（BGM）"
		toggle_bgm.add_theme_font_size_override("font_size", 16)
		toggle_bgm.button_pressed = music_node.track_muted(music_node.BGM_BUS)
		toggle_bgm.toggled.connect(func(pressed: bool):
			music_node.set_track_muted(music_node.BGM_BUS, pressed)
		)
		content.add_child(toggle_bgm)

		var track_hint := UI.label("分轨静音方便录制：两轨互不影响，猪叫等音效始终保留", 12, UI.INK_SOFT)
		track_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(track_hint)

	# 2026-11-17 实机反馈：周目档案只有通关累加没有出口——加一个彻底重置，
	# 清掉 finished_runs / seen_endings / NG+ 并回到开场（成就档不受影响）。
	var btn_reset_week := UI.button("↺  重置周目数（回到一周目，重新开始整个游戏）", func():
		var game_reset: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
		if game_reset != null and game_reset.has_method("reset_profile"):
			game_reset.reset_profile()
		Engine.get_main_loop().change_scene_to_file("res://scenes/ui/boot_farm.tscn")
	)
	btn_reset_week.name = "ResetWeekButton"
	btn_reset_week.custom_minimum_size.y = 40
	btn_reset_week.add_theme_font_size_override("font_size", 15)
	content.add_child(btn_reset_week)

	var sep_level := HSeparator.new()
	content.add_child(sep_level)

	var lvl_tag := UI.name_tag("🚩 关卡直达 · LEVEL SELECT", UI.SUNNY, UI.INK, 15)
	lvl_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(lvl_tag)

	var lvl_sub := UI.label("点击直接跳转到对应关卡，独立测试玩法与机制", 12, UI.INK_SOFT)
	lvl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(lvl_sub)

	var grid := GridContainer.new()
	grid.name = "LevelSelectGrid"
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 4)
	content.add_child(grid)

	var levels: Array[Dictionary] = [
		{"id": "course_0", "name": "序章: 噩梦屠宰场 (困雾逃窜/机关/追逐)"},
		{"id": "course_1", "name": "关卡 1: 牛耕地 (综艺闯关)"},
		{"id": "course_2", "name": "关卡 2: 溪流 (体素方块)"},
		{"id": "course_3", "name": "关卡 3: 林间 (纸箱潜行破幻)"},
		{"id": "course_4", "name": "关卡 4: 大院 (卡丁冲刺)"},
	]

	for item in levels:
		var btn := UI.button(item["name"], host._select_level_from_settings.bind(item["id"]))
		btn.name = "BtnSelect_" + item["id"]
		btn.custom_minimum_size = Vector2(520, 32)
		btn.add_theme_font_size_override("font_size", 15)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(btn)

	var btn_farm := UI.button("🏡 返回农场主线世界 (自由探索)", host._select_level_from_settings.bind("farm"), true)
	btn_farm.name = "BtnSelect_farm"
	btn_farm.custom_minimum_size.y = 36
	btn_farm.add_theme_font_size_override("font_size", 15)
	content.add_child(btn_farm)

	var sep2 := HSeparator.new()
	content.add_child(sep2)

	# 关于游戏：BGM（Kevin MacLeod，CC BY 4.0）等开放素材的署名义务从这里可查。
	var btn_about := UI.button("📜  关于游戏（BGM 署名与致谢）", host._open_credits_from_settings)
	btn_about.name = "AboutGameButton"
	btn_about.custom_minimum_size.y = 38
	btn_about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(btn_about)

	var btn_back := UI.button("◀  返回", host._close_settings)
	btn_back.name = "BackButton"
	btn_back.custom_minimum_size.y = 38
	vbox.add_child(btn_back)