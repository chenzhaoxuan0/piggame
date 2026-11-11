extends Node
class_name MemeLayer

signal meme_played(meme_id: String)

const UI = preload("res://scripts/ui/ui_kit.gd")

var _memes: Dictionary = {}
var _toast: PanelContainer
var _title_label: Label
var _text_label: Label
var _hide_timer: SceneTreeTimer
var _last_played: Dictionary = {}
var _audio: AudioStreamPlayer

func _ready() -> void:
	add_to_group("meme_layer")
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_toast = UI.patch_panel(18, UI.PAPER, UI.SAGE, Vector2(22, 12))
	_toast.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_toast.custom_minimum_size = Vector2(440, 0)
	_toast.visible = false
	var vbox := VBoxContainer.new()
	_title_label = UI.label("", 20, UI.TEAL_DEEP, true)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	_text_label = UI.label("", 16, UI.INK)
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(_text_label)
	_toast.add_child(vbox)
	layer.add_child(_toast)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)

func configure(memes: Dictionary) -> void:
	_memes = memes

func play(meme_id: String, world_pos: Vector3 = Vector3.INF) -> void:
	var entry: Dictionary = _memes.get(meme_id, {})
	if entry.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown: float = float(entry.get("cooldown", 1.5))
	if now - float(_last_played.get(meme_id, -999.0)) < cooldown:
		return
	_last_played[meme_id] = now
	var rhythm: Array = entry.get("rhythm", [])
	if not rhythm.is_empty():
		_play_rhythm(meme_id, entry, rhythm)
	else:
		_show_toast(str(entry.get("title", "")), str(entry.get("text", "")), float(entry.get("duration", 2.6)))
		_play_audio(entry)
		meme_played.emit(meme_id)
	if world_pos != Vector3.INF and entry.get("world_popup", true):
		_world_popup(str(entry.get("title", "")), world_pos)

func _play_rhythm(meme_id: String, entry: Dictionary, rhythm: Array) -> void:
	var interval: float = float(entry.get("interval", 0.55))
	_play_audio(entry)
	for i in rhythm.size():
		if i > 0:
			await get_tree().create_timer(interval).timeout
		_show_toast(str(entry.get("title", "")), str(rhythm[i]), interval + 0.25)
		meme_played.emit(meme_id)

func _show_toast(title_text: String, body_text: String, duration: float) -> void:
	_title_label.text = title_text
	_title_label.visible = not title_text.is_empty()
	_text_label.text = body_text
	_toast.reset_size()
	_toast.visible = true
	var viewport_width := get_viewport().get_visible_rect().size.x
	var toast_width := maxf(_toast.size.x, 440.0)
	_toast.position = Vector2((viewport_width - toast_width) * 0.5, 24.0)
	if _hide_timer:
		_hide_timer.timeout.disconnect(_hide_toast)
	_hide_timer = get_tree().create_timer(duration)
	_hide_timer.timeout.connect(_hide_toast)

func _hide_toast() -> void:
	_toast.visible = false

func _world_popup(text: String, world_pos: Vector3) -> void:
	if text.is_empty():
		return
	var label := UI.world_label(text, 48, UI.SUNNY, UI.TEAL_DEEP)
	var parent := get_parent()
	if parent == null:
		parent = get_tree().root
	parent.add_child(label)
	label.global_position = world_pos + Vector3.UP * 2.2
	var tween := label.create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.2, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.4)
	tween.tween_callback(label.queue_free)

func _play_audio(entry: Dictionary) -> void:
	var path: String = str(entry.get("audio", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream:
		_audio.stream = stream
		_audio.play()