extends Node
## Imported skeletal clips follow the existing gameplay root's actual movement.
## Locomotion speed is measured over a fixed time window, not per frame: raw
## per-frame distance reads zero on frames without a physics step and spikes on
## frames with several, so whenever the render rate differs from the physics
## rate (144 Hz displays, headless runs) the pig's walk clip flickered idle/run
## and never read as walking. Loop clips auto-loop; one-shot clips play via
## play_oneshot() and fall back to locomotion when they finish.
##
## NPC life extensions: register_clip() adds runtime-built bone clips (plow,
## mope, stamp, guard, snuffle - see npc_clips.gd) and force_clip() pins a loop
## regardless of measured speed, so a plowing ox reads as plowing even while
## its pacing tween barely moves it.
const LOOPS := ["idle", "walk", "run", "celebrate", "talk"]
const SPEED_WINDOW := 0.15
const RUN_ENTER := 5.2
const RUN_EXIT := 4.6

var _player: AnimationPlayer
var _visual: Node3D
var _previous: Vector3
var _clips: Dictionary = {}
var _loop_clips: Dictionary = {}
var _current := ""
var _oneshot_until := 0.0
var _acc_distance := 0.0
var _acc_time := 0.0
var _speed := 0.0
var _forced := ""
var _forced_rate := 1.0

func _ready() -> void:
	_visual = get_parent() as Node3D
	_previous = _visual.global_position
	for candidate in _visual.find_children("*", "AnimationPlayer", true, false):
		_player = candidate
		break
	if _player == null: return
	for name in _player.get_animation_list():
		var clip := str(name).get_file().to_lower()
		_clips[clip] = name
		if LOOPS.has(clip):
			_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
			_loop_clips[clip] = true
	_play("idle", 1.0)

func _process(delta: float) -> void:
	if _player == null or delta <= 0: return
	var position_now := _visual.global_position
	_acc_distance += Vector2(position_now.x - _previous.x, position_now.z - _previous.z).length()
	_previous = position_now
	_acc_time += delta
	if _acc_time >= SPEED_WINDOW:
		var raw := _acc_distance / _acc_time
		# Ignore reset/teleport jumps; animations never drive collision or displacement.
		_speed = 0.0 if raw > 20.0 else raw
		_acc_distance = 0.0
		_acc_time = 0.0
	if _oneshot_until > 0.0:
		_oneshot_until -= delta
		if _oneshot_until > 0.0:
			return
		_oneshot_until = 0.0
		_current = ""
	if _forced != "" and _clips.has(_forced):
		_play(_forced, _forced_rate)
		return
	# Hysteresis keeps a ~4.5 m/s jog from flip-flopping around the run threshold.
	var clip := "idle"
	if _speed > 0.15:
		clip = "walk"
		if _current == "run":
			if _speed > RUN_EXIT: clip = "run"
		elif _speed > RUN_ENTER:
			clip = "run"
	var rate := clampf(_speed / (6.0 if clip == "run" else 3.5), 0.65, 1.6) if clip != "idle" else 1.0
	_play(clip, rate)

func has_clip(clip: String) -> bool:
	return _player != null and _clips.has(clip.to_lower())

## Play a clip once (one-shot or looped) and return to locomotion afterwards.
## Returns true when the clip exists and was started.
func play_oneshot(clip: String, rate := 1.15) -> bool:
	clip = clip.to_lower()
	if not has_clip(clip): return false
	if not _loop_clips.has(clip):
		_player.get_animation(_clips[clip]).loop_mode = Animation.LOOP_NONE
	_play(clip, rate)
	_oneshot_until = _player.get_animation(_clips[clip]).length / maxf(rate, 0.01)
	return true

## Add a runtime-built clip. loop=true joins the looping set; loop=false makes
## it a one-shot usable through play_oneshot().
func register_clip(clip: String, anim: Animation, loop := true) -> bool:
	if _player == null or anim == null: return false
	var key := clip.to_lower()
	var lib := _player.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		_player.add_animation_library("", lib)
	if lib.has_animation(key):
		lib.remove_animation(key)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	lib.add_animation(key, anim)
	_clips[key] = key
	if loop:
		_loop_clips[key] = true
	else:
		_loop_clips.erase(key)
	return true

## Pin a loop clip regardless of locomotion speed (plowing ox, moping sheep,
## guarding farmer). One-shots still interrupt it and fall back to the pin.
func force_clip(clip: String, rate := 1.0) -> void:
	_forced = clip.to_lower()
	_forced_rate = rate

func clear_force() -> void:
	_forced = ""

func current_clip() -> String:
	return _current

func _play(clip: String, rate: float) -> void:
	if not _clips.has(clip): return
	if clip != _current:
		_player.play(_clips[clip], 0.15)
		_current = clip
	_player.speed_scale = rate
