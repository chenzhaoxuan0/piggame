extends SceneTree
## 桌面端开始菜单图标渲染对比截图（web/桌面字形一致性诊断，2026-11-20）。
## 运行（窗口化真机渲染，1280x720，与 capture_ui_refresh_2026 同款纪律）：
##   .tools/godot-4.3/Godot_v4.3-stable_win64.exe --path . --script scripts/art/capture_menu_icons.gd
## 存档纪律：进度/成就档案先重定向到 throwaway 文件，不写玩家真实 user:// 档案。

const OUT := "res://builds/ui_refresh_2026/menu_icons_desktop.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node("GameManager")
	game.progress_path = "user://capture_ui_progress.json"
	game.finished_runs = 0
	game.seen_endings = {}
	game.ng_plus = false
	game.speedrun_best = -1.0
	game.speedrun_recent.clear()
	var am: Node = root.get_node("AchievementManager")
	am.save_path = "user://capture_achievements.json"

	# 直连实例（pending_boot 为空）→ 经典开始菜单，与 web 验收同一画面。
	var node: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(node)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://builds/ui_refresh_2026")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("SAVED ", OUT)
	quit()
