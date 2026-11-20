extends Node

# BGM 播放器（autoload：MusicManager）。曲目表 + 淡入淡出 + 整曲循环。
# 文件缺失时静默跳过（pig_voice.gd 的 ResourceLoader.exists 守卫模式）：
# headless 测试与全新 checkout 保持安静且绿色。
#
# 曲目全部来自 Kevin MacLeod (incompetech.com)，CC BY 4.0——署名是许可的
# 唯一义务，落在两处（同步维护）：
#   1. 游戏内：主菜单「制作名单与致谢」面板（menus.build_credits_menu 渲染
#      本文件的 CREDITS_DATA）；
#   2. 仓库内：assets/audio/bgm/CREDITS.md。
# tests/audio/test_bgm_music.gd 钉住「每首入库曲目必有署名条目」，两边不会漂移。

const BGM_DIR := "res://assets/audio/bgm/"
const LICENSE_LINE := "Kevin MacLeod (incompetech.com)\nLicensed under Creative Commons: By Attribution 4.0\nhttps://creativecommons.org/licenses/by/4.0/"
const FADE_OUT := 0.6
const FADE_IN := 1.0
const SILENT_DB := -60.0

# 播放 id → 文件与音量。farm/menu/ending 共用 Carefree（田园基调），
# 追逐与五条赛道各有性格。新增曲目：这里 + CREDITS_DATA + CREDITS.md 三处同步。
const TRACKS := {
	"menu": {"file": "Carefree.mp3", "vol_db": -11.0},
	"farm": {"file": "Carefree.mp3", "vol_db": -13.0},
	"ending": {"file": "Carefree.mp3", "vol_db": -10.0},
	"nightmare": {"file": "Not As It Seems.mp3", "vol_db": -12.0},
	"ox_field": {"file": "The Builder.mp3", "vol_db": -12.0},
	"creek": {"file": "Itty Bitty 8 Bit.mp3", "vol_db": -12.0},
	"woodland": {"file": "Sneaky Snitch.mp3", "vol_db": -12.0},
	"courtyard": {"file": "Who Likes to Party.mp3", "vol_db": -12.0},
	"chase": {"file": "Run Amok.mp3", "vol_db": -11.0},
}

# 赛道 course_id → 播放 id（追逐腿全部走对应赛道场景，进 _enter_course 时统一换曲）
const COURSE_TRACKS := {
	"course_0": "nightmare",
	"course_1": "ox_field",
	"course_2": "creek",
	"course_3": "woodland",
	"course_4": "courtyard",
}

# 致谢数据（游戏内面板直接渲染；titles 与 TRACKS 的文件一一对应）
const CREDITS_DATA := [
	{
		"section": "🎵 背景音乐 · CC BY 4.0（署名即可免费商用）",
		"license": LICENSE_LINE,
		"items": [
			{"title": "Carefree", "file": "Carefree.mp3", "use": "主菜单 / 农场 / 结局"},
			{"title": "Not As It Seems", "file": "Not As It Seems.mp3", "use": "序章 · 噩梦屠宰场"},
			{"title": "The Builder", "file": "The Builder.mp3", "use": "第一章 · 牛耕地"},
			{"title": "Itty Bitty 8 Bit", "file": "Itty Bitty 8 Bit.mp3", "use": "第二章 · 溪谷"},
			{"title": "Sneaky Snitch", "file": "Sneaky Snitch.mp3", "use": "第三章 · 林间"},
			{"title": "Who Likes to Party", "file": "Who Likes to Party.mp3", "use": "终章 · 大院金牌杯"},
			{"title": "Run Amok", "file": "Run Amok.mp3", "use": "追逐战"},
		],
	},
	{
		"section": "🐷 音效 · CC0（可免署名，仍留档致谢）",
		"items": [{"title": "Pig 系列猪叫（JarredGibb，Freesound.org）", "file": "", "use": "跳跃哼哼 / 惨叫跳 / 挣脱\n详见 assets/audio/pig/CREDITS.md"}],
	},
	{
		"section": "🎙 角色配音（白盒试作）",
		"items": [{"title": "MiniMax speech-2.8-hd 合成（分角色音色）", "file": "", "use": "32 条 NPC 对话试听版；正式版将由制作人本人配音"}],
	},
	{
		"section": "🛠 引擎",
		"items": [{"title": "Godot Engine 4.3（MIT License）", "file": "", "use": "godotengine.org"}],
	},
]

# 分轨静音（2026-11-19 录制需求）：BGM 与角色对话配音各占一条 Master 下的
# 子总线，设置面板可单独静音某一轨（录解说 / 后期配音时不串音）。总线由
# autoload 的 _ready 统一创建——全项目最早的接线点，所有播放器接上之前就绪；
# 不落 .tres 总线布局文件，导出包里也就不存在"新文件没进包"的坑。
# 猪叫（PigVoice）是跳跃操作音效，留在 Master，不受分轨静音影响。
const BGM_BUS := "BGM"
const VOICE_BUS := "Voice"

var _player: AudioStreamPlayer = null
var _current := ""

func _ready() -> void:
	# Web 平台规避：单线程 WebAudio 下动态创建 Bus 会因引擎底层把 atPos=-1 传给 JS
	# 导致 move(id, -1) 反转 Master 索引并形成死循环环路导致整图静音；
	# 且 WebAudio SampleNode 不响应 Tween 驱动的 volume_db 变化。
	# 因此 Web 端直接走 Master 单总线并直达 target_db；桌面/测试环境保留分轨以供录制。
	if not OS.has_feature("web"):
		_ensure_bus(BGM_BUS)
		_ensure_bus(VOICE_BUS)
	_player = AudioStreamPlayer.new()
	_player.name = "BGMPlayer"
	_player.bus = BGM_BUS if AudioServer.get_bus_index(BGM_BUS) != -1 else "Master"
	add_child(_player)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

## 分轨静音开关（设置面板与 tests/audio/test_audio_tracks.gd 共用）。
## 未知总线静默忽略——缺总线的环境里静音操作不炸。
func set_track_muted(track: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(track)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)

func track_muted(track: String) -> bool:
	var idx := AudioServer.get_bus_index(track)
	return idx != -1 and AudioServer.is_bus_mute(idx)

func current_id() -> String:
	return _current

func track_for_course(course_id: String) -> String:
	return String(COURSE_TRACKS.get(course_id, ""))

## 切曲：同曲不重启；缺文件静默（白盒友好）。
func play(id: String) -> void:
	if id == _current and _player.playing:
		return
	var cfg: Dictionary = TRACKS.get(id, {})
	if cfg.is_empty():
		push_warning("MusicManager: unknown track id '%s'" % id)
		_current = ""
		return
	var path := BGM_DIR + String(cfg["file"])
	if not ResourceLoader.exists(path):
		_current = ""
		return
	var stream: AudioStream = load(path)
	if stream == null:
		_current = ""
		return
	if stream is AudioStreamMP3:
		stream.loop = true # 整曲循环；白盒不切分 loop 点
	_fade_to(stream, float(cfg.get("vol_db", -12.0)))
	_current = id

func stop() -> void:
	_current = ""
	if _player == null or not _player.playing:
		return
	if OS.has_feature("web"):
		_player.stop()
		_player.volume_db = 0.0
		return
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", SILENT_DB, FADE_OUT)
	tween.tween_callback(func():
		if _player != null:
			_player.stop()
			_player.volume_db = 0.0
	)

func _fade_to(stream: AudioStream, target_db: float) -> void:
	var apply := func() -> void:
		_player.stream = stream
		if OS.has_feature("web"):
			# Web 平台 WebAudio Samples 模式下，底层 SampleNode 在 play() 瞬间捕获音量，
			# 且不响应后续由 Tween 驱动的 volume_db 变化。直接以目标音量启播。
			_player.volume_db = target_db
			_player.play()
		else:
			_player.volume_db = SILENT_DB
			_player.play()
			var tween := create_tween()
			tween.tween_property(_player, "volume_db", target_db, FADE_IN)
	if _player.playing:
		if OS.has_feature("web"):
			apply.call()
		else:
			var out := create_tween()
			out.tween_property(_player, "volume_db", SILENT_DB, FADE_OUT)
			out.tween_callback(apply)
	else:
		apply.call()
