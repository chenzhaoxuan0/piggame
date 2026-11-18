extends Node

# 对话节点配音（VO）播放器：对话面板打开哪个节点，就播 assets/audio/vo/{id}.mp3。
# 与 pig_voice.gd 同一守卫模式（ResourceLoader.exists）：文件缺失时静默跳过，
# headless 测试与全新 checkout 保持安静且绿色。
# 对决界面（pokemon_showdown）借用宿主的 play_dialogue_vo() 走同一目录。
# （不注册 class_name：headless 测试跑在全局类缓存重扫之前，preload 才稳，
# 见 dialogue_beat.gd 的同类注释。）

const VO_DIR := "res://assets/audio/vo/"
const VOLUME_DB := -3.0 # TTS 输出偏响，压一档让它坐在猪叫/环境音旁边

var _player: AudioStreamPlayer = null

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "DialogueVOPlayer"
	_player.volume_db = VOLUME_DB
	# 角色对话轨（总线由 MusicManager._ready 统一建线）：录制时可整轨静音，
	# BGM 与猪叫不受影响。tests/audio/test_audio_tracks.gd 钉住这条接线。
	_player.bus = "Voice"
	add_child(_player)

## 按对话节点 id 播对应配音；换节点时先掐掉上一条。
func play_for(node_id: String) -> void:
	stop()
	var path := VO_DIR + node_id + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	_player.stream = stream
	_player.play()

func stop() -> void:
	if _player == null:
		return
	if _player.playing:
		_player.stop()
	_player.stream = null
