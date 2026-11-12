extends SceneTree
## Character rig animation guard: every CHAR model carries its per-character
## skeletal clip set (loops + one-shots), play_oneshot() plays a one-shot and
## returns to locomotion, missing clips report false so gameplay keeps its
## procedural fallback, and the pig/dog/NPC wiring hooks resolve end-to-end.
const ASSETS = preload("res://scripts/art/asset_library.gd")

var failures := 0
var assertions := 0

const EXPECTED_CLIPS := {
	"CHAR_01": ["idle", "walk", "run", "celebrate", "talk", "jump", "dodge", "hit"],
	"CHAR_02": ["idle", "walk", "run", "celebrate", "talk"],
	"CHAR_03": ["idle", "walk", "run", "celebrate", "talk"],
	"CHAR_04": ["idle", "walk", "run", "celebrate", "talk"],
	"CHAR_05": ["idle", "walk", "run", "celebrate", "talk"],
	"CHAR_06": ["idle", "walk", "run", "celebrate", "talk", "attack", "bark"],
	"CHAR_07": ["idle", "walk", "run", "celebrate", "talk", "attack"],
}

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(text)
	print("RIG_TEST %s: %s" % ["PASS" if ok else "FAIL", text])

func _animator(visual: Node) -> Node:
	return visual.get_node_or_null("ActorAnimation") if visual != null else null

func _run() -> void:
	# --- 1. Every character model carries its per-character clip set
	for cid in EXPECTED_CLIPS:
		var visual := ASSETS.make(cid)
		_check(visual != null, "%s instantiates" % cid)
		if visual == null: continue
		root.add_child(visual)
		var animator := _animator(visual)
		_check(animator != null, "%s has an ActorAnimation driver" % cid)
		if animator == null:
			visual.queue_free()
			continue
		for clip in EXPECTED_CLIPS[cid]:
			_check(animator.has_clip(clip), "%s carries clip: %s" % [cid, clip])
		if cid == "CHAR_01":
			_check(not animator.has_clip("attack"), "pig has no dog attack clip (fallback path stays)")
			_check(animator.play_oneshot("attack") == false, "missing clip returns false so procedural fallback runs")
		if cid == "CHAR_06":
			_check(animator.has_clip("bark") and animator.has_clip("attack"), "dog carries bark + attack one-shots")
		visual.queue_free()
	await create_timer(0.2).timeout

	# --- 2. play_oneshot plays the clip and falls back to locomotion
	var pig_visual := ASSETS.make("CHAR_01")
	root.add_child(pig_visual)
	var pig_animator := _animator(pig_visual)
	_check(pig_animator != null, "pig visual animator resolves")
	if pig_animator != null:
		_check(pig_animator.play_oneshot("jump", 4.0) == true, "jump one-shot starts")
		_check(pig_animator._current == "jump", "jump clip is the active animation")
		await create_timer(0.6).timeout
		_check(pig_animator._oneshot_until <= 0.0, "jump one-shot expired")
		await create_timer(0.1).timeout
		_check(pig_animator._current == "idle", "locomotion resumed after one-shot (idle)")
		# One-shot clips must not be forced-looping like locomotion clips.
		var player: AnimationPlayer = pig_animator._player
		var jump_anim: Animation = player.get_animation(pig_animator._clips["jump"])
		_check(jump_anim.loop_mode == Animation.LOOP_NONE, "one-shot clip never loops")
		var idle_anim: Animation = player.get_animation(pig_animator._clips["idle"])
		_check(idle_anim.loop_mode == Animation.LOOP_LINEAR, "locomotion clip keeps looping")
	pig_visual.queue_free()

	# --- 3. Pig controller wiring: dodge/hit/jump use the skeletal clips
	var pig: Node = load("res://scenes/characters/pig.tscn").instantiate()
	root.add_child(pig)
	await create_timer(0.3).timeout
	pig._perform_dodge()
	_check(pig._dodge_animated, "dodge plays the skeletal dodge clip")
	pig.dodge_timer = 0.0
	pig._dodge_animated = false
	pig.apply_knockback(Vector3(3, 2, 0))
	_check(pig._hit_animated, "knockback plays the skeletal hit clip")
	pig.knockback_timer = 0.0
	pig.play_victory_animation()
	_check(pig._play_action("celebrate") == true, "victory flourish reaches the celebrate clip")
	pig.queue_free()

	# --- 4. Chase dog wiring: windup bark / lunge attack reach the animator
	var dog_script: GDScript = load("res://scripts/chase/chase_dog.gd")
	_check(dog_script != null, "chase dog script loads")
	var dog := CharacterBody3D.new()
	dog.set_script(dog_script)
	root.add_child(dog)
	await create_timer(0.3).timeout
	var dog_animators: Array = dog._visual.find_children("ActorAnimation", "Node", true, false)
	var dog_animator: Node = dog_animators[0] if not dog_animators.is_empty() else null
	_check(dog_animator != null, "dressed dog exposes its animator")
	if dog_animator != null:
		_check(dog._play_action("bark"), "dog windup bark clip plays")
		_check(dog._play_action("attack"), "dog lunge attack clip plays")
	dog.queue_free()

	# --- 5. Farm NPC talk lookup maps dialogue titles to rigged bodies
	var farm_script: GDScript = load("res://scripts/levels/farm_grounds.gd")
	var farm := Node3D.new()
	farm.set_script(farm_script)
	var body := Node3D.new()
	body.add_child(ASSETS.make("CHAR_02"))
	farm._npcs["goat"] = body
	root.add_child(farm)
	await create_timer(0.2).timeout
	_check(farm.play_npc_action("老岩羊", "talk"), "NPC title lookup animates the goat's talk clip")
	_check(not farm.play_npc_action("不存在的角色", "talk"), "unknown speaker safely reports no animation")
	farm.queue_free()

	# --- 6. Locomotion switching: actual movement selects the skeletal walk
	# clip (windowed speed, not per-frame flicker) and the procedural bob
	# stands down while skeletal locomotion owns the body motion.
	var walker: Node = load("res://scenes/characters/pig.tscn").instantiate()
	root.add_child(walker)
	await create_timer(0.3).timeout
	walker.set_control_mode("explore")
	var walk_animator: Node = walker.visual_mesh.find_children("ActorAnimation", "Node", true, false)[0]
	walker.target_destination = Vector3(0, 0, -12)
	walker.is_moving = true
	await create_timer(0.6).timeout
	_check(walker.global_position.distance_to(Vector3.ZERO) > 1.0, "walker pig actually moves")
	_check(walk_animator._current == "walk", "moving pig selects the skeletal walk clip")
	_check(walker.visual_mesh.position.y == 0.0, "procedural bob stands down while skeletal walk plays")
	walker.target_destination = walker.global_position
	walker.is_moving = false
	await create_timer(0.6).timeout
	_check(walk_animator._current == "idle", "stopping returns the pig to idle")
	walker.queue_free()

	print("RIG_TEST summary: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
