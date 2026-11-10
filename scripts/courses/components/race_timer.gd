extends CanvasLayer

# Real race clock for the courtyard course: a 3-2-1-GO countdown (mirrored on
# the start gantry label), then a live TIME HUD; stop() freezes the clock and
# hands the true finish time to RacingFinishGate so "RECORD BROKEN 00:34.88"
# becomes an earned result instead of a hardcoded banner.
# The layer lives on the course node, so it is freed with it - game_hud/menus
# stay untouched. (No class_name self-references: fresh class names are
# invisible to headless runs until the editor rescans the global class cache.)

signal countdown_finished

@export var countdown_duration: float = 3.0

var elapsed: float = 0.0
var final_time: float = -1.0
var state: String = "idle" # idle | countdown | running | stopped

var _label: Label
var _gantry_label: Label3D = null
var _countdown_left: float = 0.0
var _last_shown_int: int = -1

func _ready() -> void:
	layer = 10
	_label = Label.new()
	_label.name = "RaceTimerLabel"
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.position.y = 14.0
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color("FACC15"))
	_label.add_theme_color_override("font_outline_color", Color("0F172A"))
	_label.add_theme_constant_override("outline_size", 10)
	_label.text = ""
	add_child(_label)
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
			if _gantry_label != null:
				_gantry_label.text = txt
		if _countdown_left <= 0.0:
			state = "running"
			elapsed = 0.0
			_label.add_theme_font_size_override("font_size", 36)
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
		else:
			_label.text = ""
	return final_time

func format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := fmod(t, 60.0)
	return "%02d:%05.2f" % [minutes, seconds]
