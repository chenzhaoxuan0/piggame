extends Node
class_name PigVoice

# Pig voice SFX bank. The pig oinks on every jump, squeals on a Shift+Space
# jump (sprint/dash hopping deserves the dramatic version), grunts through the
# QTE struggle mashing, and snorts at the trough. Streams load through a
# ResourceLoader.exists guard (meme_layer._play_audio pattern) so tests and
# fresh checkouts stay silent-but-green when the wav files are missing.

const SNORT_PATHS := [
	"res://assets/audio/pig/pig_snort_a.wav",
	"res://assets/audio/pig/pig_snort_b.wav",
	"res://assets/audio/pig/pig_snort_c.wav",
]
const SQUEAL_PATHS := [
	"res://assets/audio/pig/pig_squeal_a.wav",
	"res://assets/audio/pig/pig_squeal_b.wav",
]

const VOLUME_DB := -6.0
const SNORT_PITCH := Vector2(0.92, 1.08) # min/max pitch_scale for oinks
const SQUEAL_PITCH := Vector2(0.96, 1.10) # screams read funnier slightly sharp
const MIN_GRUNT_INTERVAL_MS := 90 # QTE mashing hits ~10 taps/s; don't pile up

var _snorts: Array[AudioStream] = []
var _squeals: Array[AudioStream] = []
var _players: Array[AudioStreamPlayer] = []
var _last_grunt_ms := 0

func _ready() -> void:
	for path: String in SNORT_PATHS:
		if ResourceLoader.exists(path):
			_snorts.append(load(path))
	for path: String in SQUEAL_PATHS:
		if ResourceLoader.exists(path):
			_squeals.append(load(path))
	# Two voices so a squeal can ring out over a still-playing snort.
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.volume_db = VOLUME_DB
		add_child(player)
		_players.append(player)

## Regular jump oink - a random snort with random pitch, so mashing jump
## never sounds like a broken loop.
func oink() -> void:
	_play(_snorts, SNORT_PITCH)

## Shift+Space (or any dramatic beat) - the big cartoon scream.
func squeal() -> void:
	_play(_squeals, SQUEAL_PITCH)

## Rate-limited short oink for QTE struggle taps.
func struggle_grunt() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_grunt_ms < MIN_GRUNT_INTERVAL_MS:
		return
	_last_grunt_ms = now
	_play(_snorts, SNORT_PITCH)

func _play(streams: Array[AudioStream], pitch_range: Vector2) -> void:
	if streams.is_empty():
		return
	var stream: AudioStream = streams[randi() % streams.size()]
	var player: AudioStreamPlayer = _players[0]
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	player.stream = stream
	player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	player.play()
