class_name GameMenus
extends RefCounted

const HUD = preload("res://scripts/ui/game_hud.gd")
# Menu CONSTRUCTION ONLY (start / pause / settings + level select) for the farm
# level. Builders assign the level's existing menu member fields and bind the
# level's methods; show/hide logic and state stay in the level script.

static func build_all(host: Node) -> void:
	_build_start_menu(host)
	_build_pause_menu(host)
	_build_settings_menu(host)

static func _build_start_menu(host: Node) -> void:
	host.start_menu = Control.new()
	host.start_menu.name = "StartMenu"
	host.start_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.hud.add_child(host.start_menu)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.14, 0.11, 0.72)
	host.start_menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.start_menu.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 400)
	card.add_theme_stylebox_override("panel", HUD.style(Color(0.96, 0.94, 0.88, 0.98), Color(0.40, 0.38, 0.30)))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var title := HUD.label("一口猪在金牌农场", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.45, 0.28, 0.14))
	vbox.add_child(title)

	var subtitle := HUD.label("A PIG IN GOLDEN FARM · 逃离农场", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.52, 0.48, 0.38))
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_start := HUD.button("▶  开始游戏", host.start_dream_intro)
	btn_start.name = "StartButton"
	btn_start.custom_minimum_size.y = 48
	vbox.add_child(btn_start)

	# The nightmare prologue plays first; this skips straight to the pen escape.
	var btn_skip := HUD.button("跳过序章，直接出圈", host._start_game)
	btn_skip.name = "SkipIntroButton"
	btn_skip.custom_minimum_size.y = 30
	vbox.add_child(btn_skip)

	var btn_settings := HUD.button("⚙  游戏设置", host._open_settings.bind(true))
	btn_settings.name = "SettingsButton"
	btn_settings.custom_minimum_size.y = 48
	vbox.add_child(btn_settings)

	var btn_quit := HUD.button("✕  退出游戏", func(): host.get_tree().quit())
	btn_quit.name = "QuitButton"
	btn_quit.custom_minimum_size.y = 44
	vbox.add_child(btn_quit)

static func _build_pause_menu(host: Node) -> void:
	host.pause_menu = Control.new()
	host.pause_menu.name = "PauseMenu"
	host.pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.pause_menu.visible = false
	host.hud.add_child(host.pause_menu)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.14, 0.11, 0.75)
	host.pause_menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.pause_menu.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 500)
	card.add_theme_stylebox_override("panel", HUD.style(Color(0.96, 0.94, 0.88, 0.98), Color(0.40, 0.38, 0.30)))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title := HUD.label("游戏暂停", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.45, 0.28, 0.14))
	vbox.add_child(title)

	var guide_panel := PanelContainer.new()
	guide_panel.name = "GuidePanel"
	guide_panel.add_theme_stylebox_override("panel", HUD.style(Color(0.91, 0.88, 0.80, 0.92), Color(0.65, 0.60, 0.48)))
	vbox.add_child(guide_panel)

	var guide_vbox := VBoxContainer.new()
	guide_vbox.add_theme_constant_override("separation", 6)
	guide_panel.add_child(guide_vbox)

	var guide_title := HUD.label("【 键位与操作指南 】", 15)
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
		var lbl := HUD.label(item, 14)
		lbl.add_theme_color_override("font_color", Color(0.26, 0.28, 0.22))
		guide_vbox.add_child(lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_resume := HUD.button("▶  继续游戏", host._resume)
	btn_resume.name = "ResumeButton"
	btn_resume.custom_minimum_size.y = 44
	vbox.add_child(btn_resume)

	var btn_settings := HUD.button("⚙  游戏设置", host._open_settings.bind(false))
	btn_settings.name = "SettingsButton"
	btn_settings.custom_minimum_size.y = 44
	vbox.add_child(btn_settings)

	var btn_restart := HUD.button("↺  从头开始", host._restart)
	btn_restart.name = "RestartButton"
	btn_restart.custom_minimum_size.y = 44
	vbox.add_child(btn_restart)

	var btn_main := HUD.button("⌂  返回主菜单", host._return_to_main_menu)
	btn_main.name = "MainMenuButton"
	btn_main.custom_minimum_size.y = 44
	vbox.add_child(btn_main)

static func _build_settings_menu(host: Node) -> void:
	host.settings_menu = Control.new()
	host.settings_menu.name = "SettingsMenu"
	host.settings_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.settings_menu.visible = false
	host.hud.add_child(host.settings_menu)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.14, 0.11, 0.75)
	host.settings_menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.settings_menu.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 560)
	card.add_theme_stylebox_override("panel", HUD.style(Color(0.96, 0.94, 0.88, 0.98), Color(0.40, 0.38, 0.30)))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title := HUD.label("游戏设置与关卡选择", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.45, 0.28, 0.14))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var toggle_high := CheckButton.new()
	toggle_high.name = "TestHighCamera"
	toggle_high.text = "测试用高视角（原高度 / 原视野）"
	toggle_high.button_pressed = host.camera.test_high_view
	toggle_high.toggled.connect(host.camera.set_test_high_view)
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

	var sep_level := HSeparator.new()
	vbox.add_child(sep_level)

	var lvl_title := HUD.label("🚩 关卡测试选择 / Level Select", 18)
	lvl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_title.add_theme_color_override("font_color", Color(0.55, 0.32, 0.16))
	vbox.add_child(lvl_title)

	var lvl_sub := HUD.label("点击可直接跳转到对应关卡进行独立玩法与机制测试：", 13)
	lvl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_sub.add_theme_color_override("font_color", Color(0.50, 0.45, 0.35))
	vbox.add_child(lvl_sub)

	var grid := GridContainer.new()
	grid.name = "LevelSelectGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	var levels: Array[Dictionary] = [
		{"id": "course_0", "name": "序章: 噩梦屠宰场 (困雾逃窜/机关/追逐)"},
		{"id": "course_1", "name": "关卡 1: 牛耕地 (糖豆人跑酷)"},
		{"id": "course_2", "name": "关卡 2: 溪流 (我的世界体素)"},
		{"id": "course_3", "name": "关卡 3: 林间 (纸箱潜行破幻)"},
		{"id": "course_4", "name": "关卡 4: 大院 (马车竞速冲刺)"},
	]

	for item in levels:
		var btn := HUD.button(item["name"], host._select_level_from_settings.bind(item["id"]))
		btn.name = "BtnSelect_" + item["id"]
		btn.custom_minimum_size = Vector2(250, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(btn)

	var btn_farm := HUD.button("🏡 返回农场主线世界 (自由探索)", host._select_level_from_settings.bind("farm"))
	btn_farm.name = "BtnSelect_farm"
	btn_farm.custom_minimum_size.y = 38
	vbox.add_child(btn_farm)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var btn_back := HUD.button("◀  返回", host._close_settings)
	btn_back.name = "BackButton"
	btn_back.custom_minimum_size.y = 40
	vbox.add_child(btn_back)
