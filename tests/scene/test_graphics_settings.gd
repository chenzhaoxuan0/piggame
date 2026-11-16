extends SceneTree
## 画质档位验证：低/中/高切换实时生效（MSAA/阴影/色彩分级/渲染缩放），
## 档位持久化（重定向档案，headless 不碰玩家真实设置），设置菜单三档按钮。

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("GRAPHICS_SETTINGS_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("GRAPHICS_SETTINGS_TEST FAIL: %s" % message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gm = root.get_node_or_null("GraphicsManager")
	_check(gm != null, "GraphicsManager autoload is registered")
	if gm == null:
		quit(1)
		return

	var level = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var sun = level.get_node("Sun")
	var env = level.get_node("WorldEnvironment").environment

	gm.set_tier("low")
	await process_frame
	_check(root.msaa_3d == Viewport.MSAA_DISABLED, "Low tier: MSAA off")
	_check(not sun.shadow_enabled, "Low tier: sun shadows off")
	_check(not env.adjustment_enabled, "Low tier: no color grading")
	_check(is_equal_approx(root.scaling_3d_scale, 0.75), "Low tier: render scale 0.75")

	gm.set_tier("high")
	await process_frame
	_check(root.msaa_3d == Viewport.MSAA_4X, "High tier: 4x MSAA")
	_check(sun.shadow_enabled and sun.directional_shadow_max_distance >= 120.0,
		"High tier: long-range shadows")
	_check(env.adjustment_enabled and env.adjustment_saturation > 1.05,
		"High tier: color grading on")

	gm.set_tier("medium")
	await process_frame
	_check(root.msaa_3d == Viewport.MSAA_2X and sun.shadow_enabled,
		"Medium tier: 2x MSAA + shadows")

	# 持久化往返：重定向档案后写入，模拟重启读回。
	gm.settings_path = "user://test_graphics_qwen.json"
	gm.set_tier("low")
	gm.tier = "high"
	gm._load()
	_check(gm.tier == "low", "Tier choice persists across reload")
	DirAccess.remove_absolute(gm.settings_path)

	# 设置菜单三档按钮 + 点击即生效。
	level.start_game()
	await process_frame
	level._open_settings(true)
	await process_frame
	var row = level.settings_menu.find_child("QualityRow", true, false)
	_check(row != null and row.get_child_count() == 3, "Settings menu has a 3-tier quality row")
	var btn_high = level.settings_menu.find_child("BtnQuality_high", true, false)
	_check(btn_high != null, "High quality button exists")
	if btn_high != null:
		btn_high.pressed.emit()
		await process_frame
		_check(gm.tier == "high" and root.msaa_3d == Viewport.MSAA_4X,
			"Clicking high quality applies 4x MSAA live")

	level.queue_free()
	await process_frame
	print("\nGRAPHICS SETTINGS TESTS FINISHED: failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)
