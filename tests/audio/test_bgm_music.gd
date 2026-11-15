extends SceneTree

# Run: godot --headless --path . --script tests/audio/test_bgm_music.gd
# BGM 与署名自检：
#   1) TRACKS 每个文件存在且已导入（--import 之后可 load）；
#   2) CREDITS_DATA 音乐区覆盖 TRACKS 的每一个文件（署名不缺曲）；
#   3) 署名块含 incompetech 官方三要素：作者 / 许可名 / 许可链接；
#   4) COURSE_TRACKS 五条赛道全部解析到 TRACKS；
#   5) MusicManager play/stop 在 headless（dummy 音频）下全链路不炸；
#   6) 仓库留档 CREDITS.md 存在且提及每首曲名（多处署名的文件侧）。
var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var music = root.get_node("MusicManager")

	# 1) 文件齐全 + 可加载
	var missing: Array[String] = []
	var unloadable: Array[String] = []
	for id: String in music.TRACKS:
		var path := "res://assets/audio/bgm/%s" % music.TRACKS[id]["file"]
		if not FileAccess.file_exists(path):
			missing.append(id)
		elif not ResourceLoader.exists(path):
			unloadable.append(id)
	_check(missing.is_empty(), "Every BGM track file exists (missing: %s)" % ", ".join(missing))
	_check(unloadable.is_empty(), "Every BGM track is imported & loadable (unimported: %s)" % ", ".join(unloadable))

	# 2) 音乐署名区覆盖每个曲目文件
	var music_section: Dictionary = {}
	for section: Dictionary in music.CREDITS_DATA:
		if section.has("license"):
			music_section = section
			break
	_check(not music_section.is_empty(), "Credits data has a licensed music section")
	var credited_files: Dictionary = {}
	for item: Dictionary in music_section.get("items", []):
		credited_files[String(item.get("file", ""))] = String(item.get("title", ""))
	var uncredited: Array[String] = []
	for id: String in music.TRACKS:
		if not credited_files.has(music.TRACKS[id]["file"]):
			uncredited.append(id)
	_check(uncredited.is_empty(), "Every track has a credits entry (uncredited: %s)" % ", ".join(uncredited))

	# 3) 署名三要素逐字在场
	var license_text := String(music_section.get("license", ""))
	_check(license_text.contains("Kevin MacLeod (incompetech.com)"), "License block names the author")
	_check(license_text.contains("Creative Commons: By Attribution 4.0"), "License block names the license")
	_check(license_text.contains("https://creativecommons.org/licenses/by/4.0/"), "License block links the license")

	# 4) 赛道映射全部有效
	var bad_map: Array[String] = []
	for course_id: String in music.COURSE_TRACKS:
		var tid: String = music.track_for_course(course_id)
		if tid.is_empty() or not music.TRACKS.has(tid):
			bad_map.append(course_id)
	_check(bad_map.is_empty(), "Course track map resolves (bad: %s)" % ", ".join(bad_map))

	# 5) headless 播放链路（dummy 驱动：无声但不炸）
	music.play("farm")
	music.play("courtyard")
	music.stop()
	music.play("not_a_track") # 未知 id：警告后静默，不崩
	music.stop()
	_check(true, "play/stop runs headless without crashing")

	# 6) 仓库留档侧：CREDITS.md 存在且逐曲登记
	var credits_path := "res://assets/audio/bgm/CREDITS.md"
	var credits_text := ""
	if FileAccess.file_exists(credits_path):
		var f := FileAccess.open(credits_path, FileAccess.READ)
		credits_text = f.get_as_text()
		f.close()
	_check(not credits_text.is_empty(), "BGM CREDITS.md exists in repo")
	var undoc: Array[String] = []
	for file: String in credited_files:
		if not credits_text.contains(file):
			undoc.append(file)
	_check(undoc.is_empty(), "CREDITS.md lists every track file (missing: %s)" % ", ".join(undoc))
	_check(credits_text.contains("https://creativecommons.org/licenses/by/4.0/"), "CREDITS.md links the license")

	# 7) 游戏内侧：主菜单致谢面板真的建得出来（menus.gd 编译错在这会直接红灯，
	#    而不是等 office 启动时才炸成挂死的测试）
	var game_menus = load("res://scripts/ui/menus.gd")
	_check(game_menus != null, "menus.gd compiles")
	if game_menus != null:
		var host := Control.new()
		host.name = "CreditsSmokeHost"
		root.add_child(host)
		var panel: Control = game_menus.build_credits_menu(host, Callable())
		var has_back := panel != null and panel.find_child("BackButton", true, false) != null
		var has_license := false
		if panel != null:
			for lbl: Label in panel.find_children("*", "Label", true, false):
				if lbl.text.contains("Creative Commons: By Attribution 4.0"):
					has_license = true
					break
		_check(has_back, "Credits panel builds with a back button")
		_check(has_license, "Credits panel renders the CC BY license block")
		host.queue_free()

	print("BGM_MUSIC_TEST assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)
