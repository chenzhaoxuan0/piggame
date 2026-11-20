extends SceneTree
## 诊断:模拟 Web 端字体解析路径(剥离 SystemFont 回退),验证成就弹窗的 🏅
## 走内嵌 NotoColorEmoji CBDT 子集时是否出彩色。窗口化真机渲染后截图对比。
## 运行:.tools/godot-4.3/Godot_v4.3-stable_win64.exe --path . --script scripts/art/capture_medal_webpath.gd

const OUT := "res://builds/ui_refresh_2026/medal_webpath_check.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var UI = load("res://scripts/ui/ui_kit.gd")
	var base: Font = UI.font()
	# 剥掉 fallbacks[0](SystemFont)——Web 上它解析不到任何字形,等效跳过。
	# 剩下: ColorEmoji → Symbols2 → MonoEmoji → DejaVu,与 Web 实际链一致。
	var web_font := (base as FontFile).duplicate()
	var fb: Array = (base as FontFile).fallbacks.duplicate()
	fb.remove_at(0)
	web_font.fallbacks = fb

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(root_ctrl)
	await create_timer(0.2).timeout

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(200, 120)
	root_ctrl.add_child(box)

	# 三行对照: Web 字体链 / 桌面完整链 / 弹窗同款 34 号 🏅
	var cases := [
		["Web链 34号: 🏅成就解锁!", 34, web_font],
		["Web链 24号: 🏅🐷🏆✨", 24, web_font],
		["桌面链 34号: 🏅成就解锁!", 34, base],
	]
	for c in cases:
		var l := Label.new()
		l.text = c[0]
		l.add_theme_font_size_override("font_size", c[1])
		l.add_theme_font_override("font", c[2])
		l.add_theme_color_override("font_color", UI.INK)
		box.add_child(l)

	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://builds/ui_refresh_2026")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("SAVED ", OUT)
	quit()
