extends Control
## 移动端虚拟操作浮层：
## - 左下角：虚拟摇杆（多指追踪 + 鼠标拖拽调试兼容，直接写 MobileControlManager.joystick_vector）
## - 右下角：跳跃（QTE 期间高亮可狂点挣脱）+ 冲刺（点按闪避 / 长按加速）+ 靠近可交互物时浮现的交互按钮
## - 右上角：暂停/设置按钮（手机端没有 ESC 键）
## 视觉遵循 UiKit 奶油纸 / 湖青 / 珊瑚橙 / 向日葵黄的卡通缝线补丁风格。

const UI = preload("res://scripts/ui/ui_kit.gd")

signal pause_requested

var joystick: VirtualJoystick
var btn_jump: TouchActionButton
var btn_dash: TouchActionButton
var btn_interact: TouchActionButton
var btn_pause: Button

var _mcm: Node = null
var _qte_mode := false
var _interact_label := ""

func _ready() -> void:
	name = "MobileControls"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mcm = get_node_or_null("/root/MobileControlManager")
	_build_widgets()
	visible = false

func _build_widgets() -> void:
	# 左下角：虚拟摇杆
	joystick = VirtualJoystick.new()
	joystick.name = "VirtualJoystick"
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 26
	joystick.offset_right = 216
	joystick.offset_top = -216
	joystick.offset_bottom = -26
	joystick.vector_changed.connect(_on_joystick_changed)
	add_child(joystick)

	# 右下角：跳跃（主大圆钮）
	btn_jump = TouchActionButton.new()
	btn_jump.name = "TouchJumpButton"
	btn_jump.action_name = "action_jump"
	btn_jump.label_text = "跳跃"
	btn_jump.sub_text = "JUMP"
	btn_jump.base_color = UI.TEAL
	btn_jump.pressed_color = UI.TEAL_DEEP
	btn_jump.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_jump.offset_left = -132
	btn_jump.offset_right = -26
	btn_jump.offset_top = -132
	btn_jump.offset_bottom = -26
	add_child(btn_jump)

	# 右下角偏左：冲刺 / 闪避
	btn_dash = TouchActionButton.new()
	btn_dash.name = "TouchDashButton"
	btn_dash.action_name = "action_dash"
	btn_dash.label_text = "冲刺"
	btn_dash.sub_text = "闪避/长按"
	btn_dash.base_color = UI.CORAL
	btn_dash.pressed_color = UI.RED
	btn_dash.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_dash.offset_left = -238
	btn_dash.offset_right = -146
	btn_dash.offset_top = -118
	btn_dash.offset_bottom = -26
	add_child(btn_dash)

	# 跳跃上方：条件出现的交互按钮（靠近 NPC / 食槽 / 索道时显示）
	btn_interact = TouchActionButton.new()
	btn_interact.name = "TouchInteractButton"
	btn_interact.action_name = "action_interact"
	btn_interact.label_text = "交互"
	btn_interact.sub_text = "F"
	btn_interact.base_color = UI.SUNNY
	btn_interact.pressed_color = UI.CORAL
	btn_interact.text_color = UI.INK
	btn_interact.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_interact.offset_left = -152
	btn_interact.offset_right = -44
	btn_interact.offset_top = -232
	btn_interact.offset_bottom = -146
	btn_interact.visible = false
	add_child(btn_interact)

	# 右上角：暂停 / 设置按钮（位于 TodoHub 按钮行下方，不遮挡待办与键位按钮）
	btn_pause = UI.button("⏸ 暂停/设置", func(): pause_requested.emit())
	btn_pause.name = "TouchPauseButton"
	btn_pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	btn_pause.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn_pause.grow_vertical = Control.GROW_DIRECTION_END
	btn_pause.offset_left = -24
	btn_pause.offset_right = -24
	btn_pause.offset_top = 68
	btn_pause.offset_bottom = 68
	btn_pause.custom_minimum_size = Vector2(118, 36)
	btn_pause.add_theme_font_size_override("font_size", 15)
	btn_pause.focus_mode = Control.FOCUS_NONE
	add_child(btn_pause)

func _on_joystick_changed(vec: Vector2) -> void:
	if _mcm != null:
		_mcm.set_joystick_vector(vec)

func set_gameplay_state(should_show: bool, qte_active: bool, interact_target_name: String, pause_in_hub: bool) -> void:
	if not should_show:
		if visible:
			release_all()
			visible = false
		return

	visible = true
	_qte_mode = qte_active
	if qte_active:
		# QTE 挣脱期间隐藏摇杆/冲刺/交互/暂停，放大并高亮跳跃键方便狂点挣脱
		joystick.reset_stick()
		btn_dash.release_action()
		btn_interact.release_action()
		joystick.visible = false
		btn_dash.visible = false
		btn_interact.visible = false
		btn_pause.visible = false
		btn_jump.visible = true
		btn_jump.set_labels("狂点挣脱!", "QTE")
		btn_jump.base_color = UI.RED
		btn_jump.queue_redraw()
	else:
		joystick.visible = true
		btn_dash.visible = true
		btn_pause.visible = true
		btn_pause.text = "⚙ 设置" if pause_in_hub else "⏸ 暂停"
		btn_jump.visible = true
		btn_jump.set_labels("跳跃", "JUMP")
		btn_jump.base_color = UI.TEAL
		btn_jump.queue_redraw()
		var has_target := not interact_target_name.is_empty()
		if has_target:
			if _interact_label != interact_target_name:
				_interact_label = interact_target_name
				btn_interact.set_labels(interact_target_name, "交互")
			btn_interact.visible = true
		else:
			if btn_interact.visible:
				btn_interact.release_action()
				btn_interact.visible = false
			_interact_label = ""

func release_all() -> void:
	if is_instance_valid(joystick):
		joystick.reset_stick()
	if is_instance_valid(btn_jump):
		btn_jump.release_action()
	if is_instance_valid(btn_dash):
		btn_dash.release_action()
	if is_instance_valid(btn_interact):
		btn_interact.release_action()
	if _mcm != null:
		_mcm.clear_virtual_inputs()

func _exit_tree() -> void:
	release_all()


class VirtualJoystick extends Control:
	signal vector_changed(vec: Vector2)

	const OUTER_RADIUS := 68.0
	const KNOB_RADIUS := 28.0
	const DEADZONE := 0.12

	var _touch_index := -1
	var _mouse_active := false
	var _knob_offset := Vector2.ZERO
	var _current_vec := Vector2.ZERO

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP

	func reset_stick() -> void:
		_touch_index = -1
		_mouse_active = false
		_knob_offset = Vector2.ZERO
		if _current_vec != Vector2.ZERO:
			_current_vec = Vector2.ZERO
			vector_changed.emit(Vector2.ZERO)
		queue_redraw()

	func _center() -> Vector2:
		return size * 0.5

	func _update_from_local_pos(local_pos: Vector2) -> void:
		var delta := local_pos - _center()
		var max_dist := OUTER_RADIUS - 8.0
		var dist := delta.length()
		if dist > max_dist:
			delta = delta / dist * max_dist
			dist = max_dist
		_knob_offset = delta
		var norm := delta / max_dist
		if norm.length() < DEADZONE:
			norm = Vector2.ZERO
		if norm != _current_vec:
			_current_vec = norm
			vector_changed.emit(_current_vec)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _touch_index == -1:
				_touch_index = touch.index
				_update_from_local_pos(touch.position)
				accept_event()
			elif not touch.pressed and touch.index == _touch_index:
				reset_stick()
				accept_event()
		elif event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == _touch_index:
				_update_from_local_pos(drag.position)
				accept_event()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_mouse_active = true
					_update_from_local_pos(mb.position)
					accept_event()
				elif _mouse_active:
					reset_stick()
					accept_event()
		elif event is InputEventMouseMotion and _mouse_active:
			var mm := event as InputEventMouseMotion
			_update_from_local_pos(mm.position)
			accept_event()

	func _input(event: InputEvent) -> void:
		# 手指滑出摇杆控件边界后，依然继续追踪直到抬起，保证拖拽不中断。
		if not is_visible_in_tree():
			return
		if _touch_index != -1:
			if event is InputEventScreenDrag and event.index == _touch_index:
				_update_from_local_pos(get_global_transform_with_canvas().affine_inverse() * event.position)
			elif event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
				reset_stick()
		elif _mouse_active:
			if event is InputEventMouseMotion:
				_update_from_local_pos(get_global_transform_with_canvas().affine_inverse() * event.position)
			elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				reset_stick()

	func _draw() -> void:
		var c := _center()
		# 外圈底盘：半透明奶油纸 + 暖边 + 内环刻度
		draw_circle(c + Vector2(0, 3), OUTER_RADIUS, Color(0.10, 0.20, 0.20, 0.22))
		draw_circle(c, OUTER_RADIUS, Color(UI.PAPER, 0.52))
		draw_arc(c, OUTER_RADIUS, 0.0, TAU, 48, Color(UI.TEAL, 0.85), 3.0, true)
		draw_arc(c, OUTER_RADIUS - 8.0, 0.0, TAU, 36, Color(UI.PAPER_EDGE, 0.75), 1.5, true)
		# 四个方向小箭头点
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_circle(c + dir * (OUTER_RADIUS - 16.0), 3.2, Color(UI.TEAL_DEEP, 0.55))
		# 摇杆推钮
		var knob_pos := c + _knob_offset
		var active := _touch_index != -1 or _mouse_active
		var knob_col := UI.CORAL if active else UI.TEAL
		draw_circle(knob_pos + Vector2(0, 2), KNOB_RADIUS, Color(0.10, 0.20, 0.20, 0.26))
		draw_circle(knob_pos, KNOB_RADIUS, Color(knob_col, 0.90))
		draw_arc(knob_pos, KNOB_RADIUS, 0.0, TAU, 32, Color(UI.WHITE, 0.95), 3.0, true)


class TouchActionButton extends Control:
	var action_name := ""
	var label_text := ""
	var sub_text := ""
	var base_color: Color = UI.TEAL
	var pressed_color: Color = UI.TEAL_DEEP
	var text_color: Color = UI.WHITE

	var _touch_index := -1
	var _mouse_active := false
	var _is_pressed := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_labels(main_text: String, sub: String = "") -> void:
		label_text = main_text
		sub_text = sub
		queue_redraw()

	func _set_action_pressed(down: bool) -> void:
		if _is_pressed == down:
			return
		_is_pressed = down
		if not action_name.is_empty() and InputMap.has_action(action_name):
			var ev := InputEventAction.new()
			ev.action = action_name
			ev.pressed = down
			ev.strength = 1.0 if down else 0.0
			Input.parse_input_event(ev)
		queue_redraw()

	func release_action() -> void:
		_touch_index = -1
		_mouse_active = false
		_set_action_pressed(false)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and _touch_index == -1:
				_touch_index = touch.index
				_set_action_pressed(true)
				accept_event()
			elif not touch.pressed and touch.index == _touch_index:
				release_action()
				accept_event()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_mouse_active = true
					_set_action_pressed(true)
					accept_event()
				elif _mouse_active:
					release_action()
					accept_event()

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if _touch_index != -1 and event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
			release_action()
		elif _mouse_active and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			release_action()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		var col := pressed_color if _is_pressed else base_color
		var scale_r := r * (0.93 if _is_pressed else 1.0)
		draw_circle(c + Vector2(0, 3), scale_r, Color(0.10, 0.20, 0.20, 0.26))
		draw_circle(c, scale_r, Color(col, 0.88))
		draw_arc(c, scale_r, 0.0, TAU, 40, Color(UI.WHITE, 0.92), 3.0, true)
		var f := UI.font_bold()
		var main_size := 20 if label_text.length() <= 3 else 15
		var main_w := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, main_size).x
		var y_base := c.y + (3.0 if sub_text.is_empty() else -2.0)
		draw_string(f, Vector2(c.x - main_w * 0.5, y_base + main_size * 0.25), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, main_size, text_color)
		if not sub_text.is_empty():
			var sub_size := 11
			var sub_w := f.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size).x
			draw_string(f, Vector2(c.x - sub_w * 0.5, c.y + 18.0), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(text_color, 0.86))
