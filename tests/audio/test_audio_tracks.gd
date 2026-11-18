extends SceneTree

# Run: godot --headless --path . --script tests/audio/test_audio_tracks.gd
# 分轨静音（录制用）接线自检：
#   1) MusicManager 建出 BGM / Voice 两条子总线，均发送到 Master；
#   2) BGM 播放器挂在 BGM 轨，对话配音播放器挂在 Voice 轨；
#   3) 两轨独立静音：静音其一不影响另一轨与 Master（互不串音）；
#   4) 猪叫（PigVoice）留在 Master，不属于任何可静音轨；
#   5) 未知总线名静默忽略，不炸。
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

	# 1) 两条子总线存在且归 Master
	for bus_name: String in [music.BGM_BUS, music.VOICE_BUS]:
		var idx := AudioServer.get_bus_index(bus_name)
		_check(idx > 0, "Bus '%s' exists below Master" % bus_name)
		if idx > 0:
			_check(String(AudioServer.get_bus_send(idx)) == "Master",
				"Bus '%s' sends to Master" % bus_name)

	# 2) 播放器接线：BGM → BGM 轨，对话配音 → Voice 轨
	_check(String(music._player.bus) == music.BGM_BUS, "BGMPlayer sits on the BGM bus")
	var vo_script = load("res://scripts/core/dialogue_vo.gd")
	_check(vo_script != null, "dialogue_vo.gd compiles")
	var vo = vo_script.new()
	root.add_child(vo)
	_check(String(vo._player.bus) == music.VOICE_BUS, "DialogueVOPlayer sits on the Voice bus")

	# 4) 猪叫不进任何可静音轨（留在 Master，随操作音效走）
	var pig_script = load("res://scripts/core/pig_voice.gd")
	var pig = pig_script.new()
	root.add_child(pig)
	for player in pig._players:
		_check(String(player.bus) == "Master", "PigVoice stays on Master (not a muteable track)")

	# 3) 两轨独立静音
	music.set_track_muted(music.BGM_BUS, true)
	_check(music.track_muted(music.BGM_BUS), "BGM bus can be muted")
	_check(not music.track_muted(music.VOICE_BUS), "Muting BGM leaves Voice unmuted")
	_check(not AudioServer.is_bus_mute(0), "Muting BGM leaves Master unmuted")
	music.set_track_muted(music.VOICE_BUS, true)
	_check(music.track_muted(music.VOICE_BUS), "Voice bus can be muted")
	_check(music.track_muted(music.BGM_BUS), "Muting Voice leaves BGM muted (independent)")
	music.set_track_muted(music.BGM_BUS, false)
	_check(not music.track_muted(music.BGM_BUS), "BGM unmute works")
	_check(music.track_muted(music.VOICE_BUS), "BGM unmute leaves Voice muted")

	# 5) 未知总线静默
	music.set_track_muted("NotABus", true)
	_check(not music.track_muted("NotABus"), "Unknown bus names are silently ignored")

	# 复位：把测试动过的总线状态清干净再退出
	music.set_track_muted(music.VOICE_BUS, false)
	_check(not music.track_muted(music.VOICE_BUS), "Voice unmute restores default")

	vo.queue_free()
	pig.queue_free()

	print("AUDIO_TRACKS_TEST assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)
