extends Node
## Imported skeletal clips follow the existing gameplay root's actual movement.
## Loop clips (idle/walk/run/celebrate/talk) auto-switch by measured speed;
## one-shot clips (jump/dodge/hit/attack/bark/...) play via play_oneshot() and
## fall back to locomotion when they finish.
const LOOPS := ["idle", "walk", "run", "celebrate", "talk"]

var _player: AnimationPlayer
var _visual: Node3D
var _previous: Vector3
var _clips: Dictionary = {}
var _current := ""
var _oneshot_until := 0.0

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
	_play("idle", 1.0)

func _process(delta: float) -> void:
	if _player == null or delta <= 0: return
	var position_now := _visual.global_position
	var distance := Vector2(position_now.x - _previous.x, position_now.z - _previous.z).length()
	_previous = position_now
	var speed := distance / delta
	# Ignore reset/teleport jumps; animations never drive collision or displacement.
	if speed > 20: speed = 0
	if _oneshot_until > 0.0:
		_oneshot_until -= delta
		if _oneshot_until > 0.0:
			return
		_oneshot_until = 0.0
		_current = ""
	var clip := "run" if speed > 5.0 else ("walk" if speed > 0.15 else "idle")
	var rate := clampf(speed / (6.0 if clip == "run" else 3.5), 0.65, 1.6) if clip != "idle" else 1.0
	_play(clip, rate)

func has_clip(clip: String) -> bool:
	return _player != null and _clips.has(clip)

## Play a clip once (one-shot or looped) and return to locomotion afterwards.
## Returns true when the clip exists and was started.
func play_oneshot(clip: String, rate := 1.15) -> bool:
	if not has_clip(clip): return false
	if not LOOPS.has(clip):
		_player.get_animation(_clips[clip]).loop_mode = Animation.LOOP_NONE
	_play(clip, rate)
	_oneshot_until = _player.get_animation(_clips[clip]).length / maxf(rate, 0.01)
	return true

func _play(clip: String, rate: float) -> void:
	if not _clips.has(clip): return
	if clip != _current:
		_player.play(_clips[clip], 0.15)
		_current = clip
	_player.speed_scale = rate
