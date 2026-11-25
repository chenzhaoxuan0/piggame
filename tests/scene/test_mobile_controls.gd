extends SceneTree
## 移动端控制与横屏设置验证：
## 1) MobileControlManager 注册、触屏/横屏切换、持久化往返（重定向档案，不碰真实配置）；
## 2) 初始标题卡、经典开始菜单、设置菜单里的快捷切换按钮实时联动；
## 3) 虚拟摇杆向量驱动 PigController 移动方向，跳跃/冲刺/条件交互/暂停按钮按游戏态显隐与响应；
## 4) QTE 期间仅保留高亮跳跃钮供狂点挣脱。

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("MOBILE_CONTROLS_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("MOBILE_CONTROLS_TEST FAIL: %s" % message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var mcm = root.get_node_or_null("MobileControlManager")
	_check(mcm != null, "MobileControlManager autoload is registered")
	if mcm == null:
		quit(1)
		return

	# 1. 持久化往返（重定向路径）
	mcm.settings_path = "user://test_mobile_controls.json"
	mcm.set_touch_controls_enabled(true)
	mcm.set_landscape_mode("force")
	mcm.touch_controls_enabled = false
	mcm.landscape_mode = "auto"
	mcm._load()
	_check(mcm.touch_controls_enabled == true, "Touch controls preference persists across reload")
	_check(mcm.landscape_mode == "force", "Landscape mode preference persists across reload")
	DirAccess.remove_absolute(mcm.settings_path)
	mcm.set_touch_controls_enabled(false)
	mcm.set_landscape_mode("auto")

	# 2. 加载主关卡（默认经典开始菜单路径）
	var level = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(level)
	await process_frame

	_check(level.mobile_controls != null, "MobileControls HUD node is created")
	_check(not level.mobile_controls.visible, "MobileControls hidden when touch mode is off")

	# 经典开始菜单快捷按钮
	var start_touch_btn: Button = level.start_menu.find_child("StartTouchModeButton", true, false)
	var start_land_btn: Button = level.start_menu.find_child("StartLandscapeModeButton", true, false)
	_check(start_touch_btn != null and start_land_btn != null, "StartMenu has quick touch & landscape toggle buttons")
	if start_touch_btn != null:
		start_touch_btn.pressed.emit()
		await process_frame
		_check(mcm.touch_controls_enabled, "Clicking StartTouchModeButton enables touch controls")
		_check(start_touch_btn.text.find("开") >= 0, "StartTouchModeButton label reflects ON state")
	if start_land_btn != null:
		start_land_btn.pressed.emit()
		await process_frame
		_check(mcm.landscape_mode == "force", "Clicking StartLandscapeModeButton toggles force landscape")

	# 开始菜单打开时，虚拟按键浮层仍保持隐藏
	_check(not level.mobile_controls.visible, "MobileControls stays hidden while StartMenu is open")

	# 3. 进入猪圈教程（真实开机路径，带左上角 TitleCard）
	level.skip_dream_intro()
	await process_frame
	await process_frame
	_check(level.mobile_controls.visible, "MobileControls appears in gameplay when touch mode is ON")
	_check(level.mobile_controls.joystick.visible, "Virtual joystick visible in gameplay")
	_check(level.mobile_controls.btn_jump.visible, "Touch jump button visible in gameplay")
	_check(level.mobile_controls.btn_dash.visible, "Touch dash button visible in gameplay")
	_check(level.mobile_controls.btn_pause.visible, "Touch pause/settings button visible in gameplay")

	# 右上角常驻挂件（今日待办 / 键位说明旁）快捷切换按钮同步
	var hud_touch_btn: Button = level.todo_hub.find_child("HudTouchModeButton", true, false)
	var hud_land_btn: Button = level.todo_hub.find_child("HudLandscapeModeButton", true, false)
	_check(hud_touch_btn != null and hud_land_btn != null, "Top-right TodoHub has quick touch & landscape toggle buttons")
	if hud_touch_btn != null:
		_check(hud_touch_btn.text.find("开") >= 0, "HudTouchModeButton stays synced with MobileControlManager")

	# 4. 虚拟摇杆驱动 PigController 移动方向 + 真实点击跳跃按钮触发跳跃而非点击寻路
	mcm.set_joystick_vector(Vector2(1.0, 0.0))
	var dir: Vector3 = level.player._keyboard_direction()
	_check(dir.length() > 0.5, "Virtual joystick vector drives PigController movement direction")
	mcm.set_joystick_vector(Vector2.ZERO)

	var jump_canvas_pt: Vector2 = level.mobile_controls.btn_jump.get_global_rect().get_center()
	var jump_win_pt: Vector2 = root.get_final_transform() * jump_canvas_pt
	var click_down := InputEventMouseButton.new()
	click_down.button_index = MOUSE_BUTTON_LEFT
	click_down.pressed = true
	click_down.position = jump_win_pt
	click_down.global_position = jump_win_pt
	Input.parse_input_event(click_down)
	await process_frame
	var click_up := InputEventMouseButton.new()
	click_up.button_index = MOUSE_BUTTON_LEFT
	click_up.pressed = false
	click_up.position = jump_win_pt
	click_up.global_position = jump_win_pt
	Input.parse_input_event(click_up)
	await process_frame
	_check(level.player._jump_buffer > 0.0 or level.player.jumps > 0, "Clicking TouchJumpButton triggers a real jump")
	_check(not level.player._has_pending_click and not level.player.is_moving,
		"Clicking TouchJumpButton does NOT fall through to click-to-move")

	# 5. 触屏暂停/设置按钮在猪圈枢纽打开设置菜单
	level.mobile_controls.btn_pause.pressed.emit()
	await process_frame
	_check(level.in_settings and level.settings_menu.visible, "Touch pause button opens settings in pigpen hub")
	_check(not level.mobile_controls.visible, "MobileControls hides while SettingsMenu is open")

	# 设置菜单里的触屏与横屏开关
	var set_touch: CheckButton = level.settings_menu.find_child("TouchControlsToggle", true, false)
	var set_land: CheckButton = level.settings_menu.find_child("ForceLandscapeToggle", true, false)
	_check(set_touch != null and set_touch.button_pressed, "Settings TouchControlsToggle exists and synced ON")
	_check(set_land != null and set_land.button_pressed, "Settings ForceLandscapeToggle exists and synced ON")
	level._close_settings()
	await process_frame
	await process_frame
	_check(level.mobile_controls.visible, "MobileControls returns after closing SettingsMenu")

	# 6. QTE 期间仅保留跳跃按钮用于狂点挣脱
	level._on_qte_requested(null)
	await process_frame
	_check(level.mobile_controls.visible, "MobileControls stays visible during QTE")
	_check(level.mobile_controls.btn_jump.visible and not level.mobile_controls.joystick.visible,
		"During QTE only jump button is shown for mashing")
	level._dismiss_qte_for_world_switch()
	await process_frame

	# 7. 触屏模式下成就弹窗上移避开右下角按键；关闭触屏模式后恢复并隐藏浮层
	var am = root.get_node_or_null("AchievementManager")
	if am != null and is_instance_valid(am._popup):
		_check(am._popup.offset_bottom <= -280, "AchievementPopup shifts above touch buttons when touch mode is ON")
	mcm.set_touch_controls_enabled(false)
	mcm.set_landscape_mode("auto")
	await process_frame
	if am != null and is_instance_valid(am._popup):
		_check(am._popup.offset_bottom == -82.0 and am._popup.size.y >= 40.0,
			"AchievementPopup sits cleanly above DashGauge with non-collapsed height in PC mode")
	_check(not level.mobile_controls.visible, "MobileControls hides immediately when touch mode toggled OFF")

	level.queue_free()
	await process_frame
	print("\nMOBILE CONTROLS TESTS FINISHED: failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)
