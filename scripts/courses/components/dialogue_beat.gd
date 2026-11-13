extends Node

# 关卡对话节拍（dialogue beat）：底部台词卡，播台词但不暂停游戏。
# 五条赛道共用，由 CourseRunner 持有并转发（runner.begin_beat()），关卡只给
# 台词 spec，不依赖 office 层的任何 UI：
#   spec = {
#     "id": "course_0_intro", "title": "序幕 · 噩梦",
#     "lines": ["第一句", "第二句", ...],        # 2-4 句
#     "line_time": 3.0,                          # 每句停留秒数（下限 LINE_HOLD_MIN）
#     "accent": Color("8C99A8"),                 # 缝线补丁的分区主题色
#   }
# 行为契约：
#   - 不锁猪、不停任何系统：卡片只是一条屏幕字幕，玩家照常跑跳打闹，
#     对话绝不打断游玩节奏。
#   - 每句停留至少 LINE_HOLD_MIN（3s）后自动换下一句；最后一句停留期满，
#     整卡淡出。配音时代 line_time 可以按语音时长写更长。
#   - 只有 F（action_interact）推进一句（连按即整段跳过）。空格/回车/鼠标
#     都不推进——空格是跳跃键，不能让一跳顺走一句台词。
#   - 卡片 mouse IGNORE：点击走位穿透卡片，不会被字幕截走。
#   - skip_all() 供测试与机器人快进（beats 照常 fire，但永远卡不住任何人）。
# （不注册 class_name：headless 测试跑在全局类缓存重扫之前，preload 才稳，
# 见 race_timer.gd 的同类注释。）

signal beat_started(beat_id: String)
signal beat_finished(beat_id: String)

const UI = preload("res://scripts/ui/ui_kit.gd")

# 每句台词的最短停留：读一句中文台词 + 将来的一条配音，3 秒是下限。
const LINE_HOLD_MIN := 3.0

var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _begun := false
var _line_index := 0
var _line_left := 0.0

var _layer: CanvasLayer = null
var _card: PanelContainer = null
var _title_label: Label
var _counter_label: Label
var _text_label: Label
var _hint_label: Label

func is_active() -> bool:
	return not _active.is_empty()

func active_id() -> String:
	return str(_active.get("id", ""))

func play(spec: Dictionary) -> void:
	_queue.append(spec)
	if _active.is_empty():
		_start_next()

func skip_all() -> void:
	# Fast-forward for tests and menus: drop everything queued and end the
	# live beat on the spot (beat_finished still fires, so countdown hooks and
	# follow-up toasts land exactly as if the lines had run).
	_queue.clear()
	if is_active():
		_finish()

func _start_next() -> void:
	if _queue.is_empty():
		return
	_active = _queue.pop_front()
	_begun = false
	# beat_started 与「成为当前节拍」同步广播（而不是延迟到 _do_begin）：
	# 快进可能在延迟帧之前就把节拍结掉（测试 tick / 玩家狂按），监听
	# beat_started 的统计与断言不能漏掉这种节拍。
	beat_started.emit(active_id())
	# 建卡延迟一帧：关卡在 setup() 里调 begin_beat()，此时关卡自己的节点树
	# 还在搭建中；call_deferred 让卡片在这一帧收尾后再上屏。
	_do_begin.call_deferred()

func _do_begin() -> void:
	if not is_inside_tree() or _active.is_empty():
		return
	_begun = true
	_line_index = 0
	_build_card()
	_apply_line()
	_card.visible = true
	_card.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_card, "modulate:a", 1.0, 0.16)

func _line_time() -> float:
	return maxf(LINE_HOLD_MIN, float(_active.get("line_time", LINE_HOLD_MIN)))

func _process(delta: float) -> void:
	if not _begun:
		return
	_line_left -= delta
	if _line_left <= 0.0:
		_advance()

func _advance() -> void:
	var lines: Array = _active.get("lines", [])
	_line_index += 1
	if _line_index >= lines.size():
		_finish()
		return
	_apply_line()

func _apply_line() -> void:
	var lines: Array = _active.get("lines", [])
	if _line_index >= lines.size():
		return
	_text_label.text = str(lines[_line_index])
	_counter_label.text = "%d / %d" % [_line_index + 1, lines.size()]
	_line_left = _line_time()

func _finish() -> void:
	var finished_id := active_id()
	_active = {}
	_begun = false
	if _card != null and is_instance_valid(_card):
		_card.visible = false
	if not finished_id.is_empty():
		beat_finished.emit(finished_id)
	if not _queue.is_empty():
		_start_next()

func _exit_tree() -> void:
	_queue.clear()

func _unhandled_input(event: InputEvent) -> void:
	if not _begun:
		return
	# 只认 F（action_interact）推进。空格（跳跃）、回车、鼠标都不算：游戏在
	# 字幕期间照常进行，这些键属于玩法，不能顺手带走台词。
	if event.is_action_pressed("action_interact") and not event.is_echo():
		_advance()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------
# UI：底部居中的缝线补丁横幅卡（office dialogue_panel 的同款语言，但住在
# 关卡自己的 CanvasLayer 上，layer 12 盖过赛道 meme toast（10）与 HUD（1））。
# ------------------------------------------------------------------
func _build_card() -> void:
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 12
		add_child(_layer)
	for child in _layer.get_children():
		child.queue_free()
	var accent: Color = _active.get("accent", UI.PINK)
	_card = UI.patch_panel(20, UI.PAPER, accent, Vector2(26, 16))
	_card.name = "BeatCard"
	# MINSIZE 锚定 + 向上生长（game_hud key strip 同款手法）：卡片随行数自动
	# 长高。旧实现的固定 offset（top -212 / bottom -40 的 172px 定高）把换行
	# 文本压回卡片里。
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_top -= 40.0
	_card.offset_bottom -= 40.0
	_card.custom_minimum_size = Vector2(560, 0)
	_card.visible = false
	# 字幕不吃鼠标：游戏照常进行，点击走位必须穿透卡片（推进只认 F）。
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card)

	# patch_panel 是 PanelContainer：它把【每一个】子节点都拉伸到同一块内容
	# 矩形，不做纵向堆叠——标题行/正文/提示必须收进唯一的 VBox 子节点，
	# 否则三层文字全部叠印在同一块区域（全库 patch_panel 用法同此惯例）。
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(layout)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label = UI.label("", 20, UI.TEAL_DEEP, true)
	_title_label.text = str(_active.get("title", ""))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_label = UI.label("", 14, UI.INK_SOFT)
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_title_label)
	head.add_child(spacer)
	head.add_child(_counter_label)
	layout.add_child(head)

	_text_label = UI.label("", 19, UI.INK)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(560, 0)
	layout.add_child(_text_label)

	_hint_label = UI.label("按 F 下一句（连按跳过）", 13, UI.INK_SOFT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layout.add_child(_hint_label)
