extends Node

# 关卡对话节拍（dialogue beat）：底部台词卡 + 暂停猪的操作，讲清剧情再开跑。
# 五条赛道共用，由 CourseRunner 持有并转发（runner.begin_beat()），关卡只给
# 台词 spec，不依赖 office 层的任何 UI：
#   spec = {
#     "id": "course_0_intro", "title": "序幕 · 噩梦",
#     "lines": ["第一句", "第二句", ...],        # 2-4 句；进场 2.4-2.8s/句，剧情点 1.2-1.4s/句
#     "line_time": 2.6,                          # 每句自动推进秒数
#     "lock": true,                              # 是否锁住猪（剧情点也是 true）
#     "accent": Color("8C99A8"),                 # 缝线补丁的分区主题色
#     "player": pig,                             # runner 注入
#   }
# 行为契约（与 runner 的配合见 course_runner.gd）：
#   - 锁 = control_mode "cinematic"：控制器每帧把速度清零并提前返回，重力、
#     击退、输入全部停摆；上场击退先结清，避免解锁后补飞。
#   - 锁定期由 runner 的 watchdog 跳过（站着不动不算挂机）、恶犬不得起扭打
#     （runner.can_dog_grapple() 为 false）。
#   - 点击 / F / 空格 / 回车推进一句（连按即整段跳过）；skip_all() 供测试与
#     暂停菜单快进；每句有 line_time 自动推进，卡不住任何人。
#   - 起点时序不受影响：出生点都在起点 marker 之外，节拍先锁住猪，结束后
#     玩家走一步才触发 marker → course_started（锁定期内物理上碰不到 marker）。
# （不注册 class_name：headless 测试跑在全局类缓存重扫之前，preload 才稳，
# 见 race_timer.gd 的同类注释。）

signal beat_started(beat_id: String)
signal beat_finished(beat_id: String)

const UI = preload("res://scripts/ui/ui_kit.gd")

const LOCK_MODE := "cinematic"
# 别的系统在节拍期间合法接管猪的模式（QTE、暂停、office 对话……）：
# 节拍既不覆盖它们，解锁时也不抢回来。
const FOREIGN_MODES := ["qte", "paused", "dialogue", "locked", "ending"]
const MOVABLE_MODES := ["explore", "chase"]

var _queue: Array[Dictionary] = []
var _active: Dictionary = {}
var _begun := false
var _lock_held := false
var _locked_player: Node = null
var _saved_mode := ""
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

func locking() -> bool:
	# True while a beat both shows and holds the pig (runner gates dogs and the
	# watchdog on this).
	return is_active() and _lock_held

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
	# 首次锁定延迟一帧：关卡在 setup() 里调 begin_beat()，而 office 层在
	# setup() 返回后立刻写 control_mode "explore"——同步上锁会在同一调用栈
	# 里被覆盖。call_deferred 一定排在它之后。
	_do_begin.call_deferred()

func _do_begin() -> void:
	if not is_inside_tree() or _active.is_empty():
		return
	_begun = true
	_line_index = 0
	if bool(_active.get("lock", true)):
		_lock()
	_build_card()
	_apply_line()
	_card.visible = true
	_card.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_card, "modulate:a", 1.0, 0.16)

func _line_time() -> float:
	return maxf(0.4, float(_active.get("line_time", 2.5)))

func _lock() -> void:
	var player: Node = _active.get("player")
	if not is_instance_valid(player) or not ("control_mode" in player):
		return
	_locked_player = player
	_saved_mode = str(player.control_mode)
	if _saved_mode in FOREIGN_MODES:
		_saved_mode = "explore" # 没有更合理的回归模式
	# 结清在途击退：锁定期控制器不推进 knockback_timer，留着的击退会在
	# 解锁后突然续飞半秒。
	if "knockback_timer" in player:
		player.knockback_timer = 0.0
	if "knockback_velocity" in player:
		player.knockback_velocity = Vector3.ZERO
	player.set_control_mode(LOCK_MODE)
	_lock_held = true

func _unlock() -> void:
	if not _lock_held:
		return
	_lock_held = false
	var player := _locked_player
	_locked_player = null
	if not is_instance_valid(player) or not ("control_mode" in player):
		return
	if str(player.control_mode) != LOCK_MODE:
		return # 已被 QTE/暂停等接管，交给对方
	player.set_control_mode(_saved_mode)

func _process(delta: float) -> void:
	if not _begun:
		return
	# 复锁：若别的系统在节拍播放中把猪拨回可动模式（测试直接调 _on_start、
	# office 的 course_started 回调都会写 "chase"），台词没讲完猪就得站着。
	if _lock_held:
		var player := _locked_player
		if is_instance_valid(player) and "control_mode" in player and str(player.control_mode) in MOVABLE_MODES:
			player.set_control_mode(LOCK_MODE)
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
	_card.reset_size()

func _finish() -> void:
	var finished_id := active_id()
	_active = {}
	_begun = false
	_unlock()
	if _card != null and is_instance_valid(_card):
		_card.visible = false
	if not finished_id.is_empty():
		beat_finished.emit(finished_id)
	if not _queue.is_empty():
		_start_next()

func _exit_tree() -> void:
	# 关卡在节拍中途被卸下（完成、设置跳转）时不能把猪永远锁在原地。
	_unlock()
	_queue.clear()

func _unhandled_input(event: InputEvent) -> void:
	if not _begun:
		return
	var advance := false
	if (event.is_action_pressed("action_interact") or event.is_action_pressed("action_jump") or event.is_action_pressed("ui_accept")) and not event.is_echo():
		advance = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance = true
	if advance:
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
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = -320.0
	_card.offset_right = 320.0
	_card.offset_top = -212.0
	_card.offset_bottom = -40.0
	_card.custom_minimum_size = Vector2(560, 0)
	_card.visible = false
	_card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_advance()
	)
	_layer.add_child(_card)

	var head := HBoxContainer.new()
	_title_label = UI.label("", 20, UI.TEAL_DEEP, true)
	_title_label.text = str(_active.get("title", ""))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter_label = UI.label("", 14, UI.INK_SOFT)
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_title_label)
	head.add_child(spacer)
	head.add_child(_counter_label)
	_card.add_child(head)

	_text_label = UI.label("", 19, UI.INK)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(560, 0)
	_card.add_child(_text_label)

	_hint_label = UI.label("点击 / F / 空格：下一句（连按跳过）", 13, UI.INK_SOFT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_hint_label)
