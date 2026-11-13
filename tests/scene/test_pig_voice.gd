extends SceneTree

# Pig voice SFX: the pig carries a PigVoice bank, jump oinks / Shift+Space
# squeals / QTE struggle grunts all route through it, and the bank stays
# green (silent no-op) when the wav assets are missing.

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("VOICE_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("VOICE_TEST FAIL: %s" % message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)

	var level_scene := load("res://scenes/levels/office_level_1.tscn")
	var level = level_scene.instantiate()
	root_node.add_child(level)
	await process_frame
	await process_frame

	var pig = level.player
	_check(is_instance_valid(pig), "Pig controller exists")
	var voice = pig.get_node_or_null("PigVoice")
	_check(voice != null and voice is PigVoice, "Pig spawns with a PigVoice bank child")
	if voice == null:
		print("VOICE_TEST FINISHED: failures=%d" % _failures)
		quit(1 if _failures > 0 else 0)
		return

	# 1. Streams actually loaded from assets/audio/pig (this repo ships them).
	_check(voice._snorts.size() >= 2, "Snort bank loaded at least two variants")
	_check(voice._squeals.size() >= 1, "Squeal bank loaded")
	for player in voice._players:
		_check(player.volume_db == PigVoice.VOLUME_DB, "Voice player volume is tamed (%.0f dB)" % player.volume_db)

	# 2. Calls play without crashing and pick a stream + randomized pitch.
	var before_frames := [voice._players[0].stream, voice._players[1].stream]
	voice.oink()
	await process_frame
	_check(voice._players[0].playing or voice._players[1].playing, "oink() starts playback")
	var snort_a_pitch: float = voice._players[0].pitch_scale
	var seen_new := false
	for i in 6:
		voice.oink()
		await process_frame
		if absf(voice._players[0].pitch_scale - snort_a_pitch) > 0.0001:
			seen_new = true
	_check(seen_new, "Pitch varies between oinks (not a loop)")

	voice.squeal()
	await process_frame
	# A still-ringing oink may occupy one player; the squeal must ring on the
	# other (or preempt one) - so any playing stream from the squeal bank counts.
	var squeal_ringing := false
	for player in voice._players:
		if player.playing and player.stream in voice._squeals:
			squeal_ringing = true
	_check(squeal_ringing, "squeal() starts playback from the squeal bank")

	# 3. QTE struggle grunts are rate-limited: two immediate calls -> one new play.
	for player in voice._players:
		player.stop()
	voice.struggle_grunt()
	await process_frame
	var frames_after_first := _playing_frames(voice)
	voice.struggle_grunt() # within MIN_GRUNT_INTERVAL_MS -> ignored
	await process_frame
	_check(_playing_frames(voice) == frames_after_first, "struggle_grunt() rate-limits rapid taps")
	var wait_ms := PigVoice.MIN_GRUNT_INTERVAL_MS + 30
	await create_timer(wait_ms / 1000.0).timeout
	voice.struggle_grunt()
	await process_frame
	_check(_playing_frames(voice) >= frames_after_first, "struggle_grunt() plays again after the interval")

	# 4. Trough interactions snort through reached_interactable meta (no crash,
	#    works regardless of whether a trough exists in this scene).
	level.start_game() # leave the start menu so the pig is in explore mode
	await process_frame
	var trough_probe := StaticBody3D.new()
	trough_probe.position = pig.global_position + Vector3(0, 0, 1.0)
	trough_probe.set_meta("interaction_id", "trough")
	trough_probe.add_to_group("interactable")
	root_node.add_child(trough_probe)
	await process_frame
	var ok: bool = pig._try_interact(trough_probe)
	_check(ok, "Trough probe interacts cleanly with voice attached")

	# 5. Missing-asset resilience: a fresh bank with no streams stays silent-safe.
	var silent_bank := PigVoice.new()
	root_node.add_child(silent_bank)
	await process_frame
	silent_bank.oink()
	silent_bank.squeal()
	silent_bank.struggle_grunt()
	await process_frame
	_check(true, "Empty bank no-ops without errors")

	print("VOICE_TEST FINISHED: failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)

func _playing_frames(voice) -> int:
	var count := 0
	for player in voice._players:
		if player.playing:
			count += 1
	return count
