extends SceneTree

# Pigpen playground + meteor reset guard: the pen gets its own messable props
# (tippable bucket, kickable cabbage, hay dive) that stay out of the story
# interactable group, and the red meteor button drops one meteor that snaps
# every wrecked pen prop back to its built transform and re-arms one-shot gags.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("PIGPEN_METEOR_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	var am: Node = root.get_node("AchievementManager")
	am.save_path = "user://achievements_pigpen_meteor_test.json"
	am.reset_progress(true)

	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.4).timeout
	office.start_game()
	await physics_frame
	var farm: Node = office.farm
	var pig: Node = office.player

	# --- The pen props and the button exist; interactables stay at eight
	for node_name in ["PenBucket", "PenCabbageBall", "PenHaystack", "MeteorButton"]:
		_check(farm.get_node_or_null(node_name) != null, "%s is built in the pigpen" % node_name)
	_check(get_nodes_in_group("interactable").size() == 8,
		"Pen playthings stay out of the story interactables (still 5 NPCs + board + cablecar + trough)")

	# --- The pen props wear their Lux3D models (the flat boxes stay as collision
	# only - the white-box look must not creep back; a null make() fallback fails
	# here because the mounted model is flagged by the asset library).
	for lux_check in [["PenBucket", "BucketLux"], ["PenCabbageBall", "CabbageLux"],
			["PenHaystack", "HaystackLux"], ["MeteorButton", "ButtonLux"]]:
		var lux: Node = farm.get_node(lux_check[0]).get_node_or_null(lux_check[1])
		_check(lux != null and lux.visible and lux.get_meta("source", "") == "Aholo Lux3D",
			"%s wears its Lux3D model (%s)" % [lux_check[0], lux_check[1]])

	# --- Kick the pen cabbage away from home
	var ball: Node3D = farm.get_node("PenCabbageBall")
	var ball_home: Vector3 = ball.global_position
	pig.global_position = ball_home + Vector3(0, 0.6, 0.8)
	pig.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await create_timer(0.5).timeout
	var ball_moved: float = ball.global_position.distance_to(ball_home)
	_check(ball_moved > 0.4, "Touching the pen cabbage kicks it away (moved %.2f m)" % ball_moved)

	# --- Topple the bucket (one-shot tippable)
	var bucket: Node3D = farm.get_node("PenBucket")
	var bucket_basis: Basis = bucket.basis
	pig.global_position = bucket.global_position + Vector3(0, 0.6, 0.8)
	pig.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await create_timer(0.6).timeout
	var bucket_tipped: bool = not bucket.basis.is_equal_approx(bucket_basis)
	_check(bucket_tipped, "Walking into the bucket topples it")
	_check(ball.global_position.distance_to(ball_home) > 0.4, "Cabbage is still away from home pre-reset")

	# --- Hoof on the red button: one meteor falls and resets the pen
	var button: Node3D = farm.get_node("MeteorButton")
	pig.global_position = button.global_position + Vector3(0, 0.4, 0)
	pig.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await create_timer(0.3).timeout # body_entered lands a beat after the physics step
	_check(farm.get_node_or_null("Meteor") != null or farm._meteor_falling,
		"Stepping on the button summons the falling meteor")
	await create_timer(2.2).timeout # 1.1s fall + impact frame + settle
	_check(farm.get_node_or_null("Meteor") == null and not farm._meteor_falling,
		"The meteor lands and is cleaned up")
	_check(ball.global_position.distance_to(ball_home) < 0.1,
		"Meteor impact snaps the kicked cabbage back home")
	_check(bucket.basis.is_equal_approx(bucket_basis),
		"Meteor impact stands the toppled bucket back up")

	# --- The re-armed bucket can topple again (one-shot cleared by reset)
	pig.global_position = bucket.global_position + Vector3(0, 0.6, 0.9)
	pig.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await create_timer(0.6).timeout
	_check(not bucket.basis.is_equal_approx(bucket_basis),
		"Re-armed by the reset, the bucket topples again")

	# --- reset_prop kills an in-flight kick tween (a meteor landing mid-kick
	# must not leave the dying tween overwriting the restored transform)
	var thing: Node = ball.get_node("Plaything")
	thing._react_cabbage(pig) # kick starts, 0.28s roll tween in flight
	thing.reset_prop() # impact lands the same frame
	await create_timer(0.5).timeout # long enough for a live tween to have written
	_check(ball.global_position.distance_to(ball_home) < 0.1,
		"A reset mid-kick leaves the cabbage home (in-flight tween killed)")

	office.queue_free()
	await create_timer(0.2).timeout
	print("PIGPEN_METEOR_TEST assertions done, failures=%d" % failures)
	if failures > 0:
		quit(1)
	else:
		quit(0)
