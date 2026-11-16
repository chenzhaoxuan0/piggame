extends CanvasLayer

# Real race clock for the courtyard course and the ranch time trial: a 3-2-1-GO
# countdown (mirrored on the start gantry label), then a live TIME HUD; stop()
# freezes the clock and hands the true finish time to RacingFinishGate / the
# ranch lap check so "金牌杯最佳 00:34.88" / the 35 s medal become earned
# results instead of hardcoded banners.
# The layer lives on the course node, so it is freed with it - game_hud/menus
# stay untouched. (No class_name self-references: fresh class names are
# invisible to headless runs until the editor rescans the global class cache.)

signal countdown_finished

const UI = preload("res://scripts/ui/ui_kit.gd")

@export var countdown_duration: float = 3.0

var elapsed: float = 0.0
var final_time: float = -1.0
var state: String = "idle" # idle | countdown | running | stopped

var _label: Label
var _badge: PanelContainer
var _gantry_label: Label3D = null
var _countdown_left: float = 0.0
var _last_shown_int: int = -1

func _ready() -> void:
	layer = 10
	_badge = PanelContainer.new()
	_badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_badge.offset_top = 14.0
	_badge.offset_bottom = 14.0
	_badge.add_theme_stylebox_override("panel", UI.pill(Color(UI.PAPER, 0.95), 22, UI.PAPER_EDGE, 2, Vector2(24, 8), true))
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_label = UI.label("", 36, UI.TEAL_DEEP, true)
	_label.name = "RaceTimerLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_child(_label)
	set_process(false)

func start_countdown(gantry_label: Label3D = null) -> void:
	if state != "idle":
		return
	_gantry_label = gantry_label
	state = "countdown"
	_countdown_left = countdown_duration
	_last_shown_int = -1
	set_process(true)

func _process(delta: float) -> void:
	if state == "countdown":
		_countdown_left -= delta
		var shown := int(ceil(_countdown_left))
		if shown != _last_shown_int:
			_last_shown_int = shown
			var txt := "🏁 GO！🏁" if shown <= 0 else str(shown)
			_label.text = txt
			_label.add_theme_font_size_override("font_size", 48 if shown <= 0 else 56)
			_label.add_theme_color_override("font_color", UI.CORAL if shown <= 0 else UI.TEAL_DEEP)
			if _gantry_label != null:
				_gantry_label.text = txt
		if _countdown_left <= 0.0:
			state = "running"
			elapsed = 0.0
			_label.add_theme_font_size_override("font_size", 32)
			_label.add_theme_color_override("font_color", UI.TEAL_DEEP)
			_label.text = "TIME 00:00.00"
			countdown_finished.emit()
	elif state == "running":
		elapsed += delta
		_label.text = "TIME " + format_time(elapsed)

func stop() -> float:
	# Returns the final race time, or -1.0 when the clock never reached GO (the
	# finish gate then shows a plain FINISH banner instead of a bogus 00:00.00).
	if state == "running":
		final_time = elapsed
	if state != "stopped":
		state = "stopped"
		if final_time >= 0.0:
			_label.text = "🏁 " + format_time(final_time) + " 🏁"
			_label.add_theme_color_override("font_color", UI.CORAL)
		else:
			_label.text = ""
	return final_time

func fade_out(delay: float = 2.5) -> void:
	# 2026-11-16 实机反馈：完赛/取消后计分条一直挂在屏幕顶上不走。让最终
	# 成绩先亮一会儿（gag 台词同屏），随后淡出——layer 由拥有者按需重建。
	if state != "stopped":
		stop()
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)

func format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := fmod(t, 60.0)
	return "%02d:%05.2f" % [minutes, seconds]