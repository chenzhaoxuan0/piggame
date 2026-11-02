extends SceneTree
## Real rendered scene, keyboard movement and UI buttons; no state shortcuts or teleporting.
const L = preload("res://scripts/levels/farm_layout.gd")
var office: Node
var failures := 0
var game: Node
var dog_progress := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("JOURNEY %s %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _click_option(index: int = 0) -> void:
	while office.line_index < office.dialogue_lines.size() - 1:
		office._advance_dialogue()
		await process_frame
	await process_frame
	office.options.get_child(index).pressed.emit()
	await process_frame
	while office.busy: await process_frame

func _dialogue() -> void:
	for i in 20:
		if not office.dialogue_open: return
		await _click_option()
	_check(false, "dialogue terminates")

func _walk_to(point: Vector3) -> void:
	for frame in 2400:
		var offset: Vector3 = point - office.player.global_position
		offset.y = 0
		if offset.length() < 0.35: break
		if office.overlay.visible or office.dialogue_open: break
		for dog in office.chase._dogs:
			dog_progress=maxf(dog_progress,L.closest_on_path(dog.global_position,L.chase_course()).progress)
		var right: Vector3 = office.camera.global_basis.x
		var back: Vector3 = office.camera.global_basis.z
		right.y = 0
		back.y = 0
		var direction := offset.normalized()
		# Test input anticipates visible trail obstacles; gameplay receives ordinary Space.
		if office.player.is_on_floor():
			var obstacles: Array[Vector3]=[L.CREEK_CENTER]
			for item in L.LOGS: obstacles.append(item.a.lerp(item.b,item.t))
			for obstacle in obstacles:
				var ahead: Vector3=obstacle-office.player.global_position
				ahead.y=0
				var distance:=ahead.dot(direction)
				var trigger:=1.65 if obstacle==L.CREEK_CENTER else 1.25
				if distance>0 and distance<trigger and ahead.length()<trigger+.25:
					var jump:=InputEventAction.new()
					jump.action="action_jump"
					jump.pressed=true
					Input.parse_input_event(jump)
		var x := direction.dot(right.normalized())
		var y := direction.dot(back.normalized())
		for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
		Input.action_press("move_right" if x > 0 else "move_left", absf(x))
		Input.action_press("move_down" if y > 0 else "move_up", absf(y))
		await physics_frame
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	_check(office.player.global_position.distance_to(point) < 0.8, "walk to %s actual=%s" % [point,office.player.global_position])
	if office.player.global_position.distance_to(point)>2: quit(1)

func _interact() -> void:
	var event := InputEventAction.new()
	event.action = "action_interact"
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
	event = InputEventAction.new()
	event.action = "action_interact"
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	_check(office.dialogue_open, "E opens nearby interaction")

func _shot(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://builds")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join("journey_%s.png" % id))

func _run() -> void:
	game = root.get_node("GameManager")
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout
	await _shot("intro")
	await _click_option()
	await _click_option(1)
	await _click_option()
	_check(game.ending == "stay", "blue ending via dialogue")
	office.queue_free()
	await process_frame
	office = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.6).timeout
	await _dialogue()
	_check(game.has_pin and game.stage == "exploring", "red choice opens pigpen")
	await _travel_to_chase()
	await _follow(L.chase_course())
	_check(game.stage == "showdown", "zero skill winding chase won")
	_check(dog_progress>L.length_of(L.chase_course())*.70,"dogs follow bends and obstacles: %.1f m" % dog_progress)
	_check(office.farm.recoveries==0, "whole journey without fall recovery or teleport")
	_check(office.player.jumps>=3, "actual Space input clears two logs and creek gap")
	await _walk_to(Vector3(-79.4,2.1,-225))
	await _interact()
	await _dialogue()
	_check(game.stage == "cablecar_ready", "three rounds open iron gate")
	await _walk_to(Vector3(-82,2.1,-225))
	await _follow(L.path("escape"))
	await _walk_to(Vector3(-14,0.1,-275.5))
	await _interact()
	await _dialogue()
	await create_timer(4.3).timeout
	_check(game.ending == "escape", "cablecar reaches red ending")
	_check(office.farm.get_cablecar().position.is_equal_approx(L.STATION+L.TRAVEL), "cabin completes travel")
	print("FULL_JOURNEY failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func _follow(points: Array[Vector3]) -> void:
	for point in points: await _walk_to(point+Vector3.UP*.1)

func _travel_to_chase() -> void:
	await _follow(L.path("summit"))
	await _follow([Vector3(46,24,55),Vector3(56,24,38),Vector3(72,24,20)])
	await _follow(L.path("creek"))
	await _follow([Vector3(-40,16,-32),Vector3(-38,16,-53),Vector3(-66,16,-62)])
	await _follow(L.path("woodland"))
	await _follow([Vector3(20,8,-102),Vector3(30,8,-110),Vector3(10,8,-120),Vector3(-6,8,-135)])
	await _follow(L.path("approach"))
