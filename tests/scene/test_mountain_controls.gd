extends "res://tests/scene/test_full_journey.gd"
## Focused physics fixtures deliberately reposition to isolate failure/retry behavior.
func _aim(direction: Vector3) -> void:
	var right: Vector3=office.camera.global_basis.x
	var back: Vector3=office.camera.global_basis.z
	right.y=0; back.y=0
	var x:=direction.dot(right.normalized())
	var y:=direction.dot(back.normalized())
	_release()
	Input.action_press("move_right" if x>0 else "move_left",absf(x))
	Input.action_press("move_down" if y>0 else "move_up",absf(y))

func _release() -> void:
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)

func _input(action: String) -> void:
	var event:=InputEventAction.new()
	event.action=action; event.pressed=true
	Input.parse_input_event(event)
	event=InputEventAction.new()
	event.action=action; event.pressed=false
	Input.parse_input_event(event)

func _run() -> void:
	game=root.get_node("GameManager")
	office=load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(.6).timeout
	await _dialogue()
	for i in 4: await physics_frame
	var floor_y: float=office.player.position.y
	_input("action_jump")
	for i in 10: await physics_frame
	_check(office.player.position.y>floor_y+.5,"Space jumps with real vertical velocity")
	_input("ui_cancel")
	await process_frame
	var frozen: Vector3=office.player.position
	var jumps: int=office.player.jumps
	_input("action_jump")
	for i in 30: await physics_frame
	_check(office.paused and office.player.position==frozen,"pause freezes airborne movement")
	office._resume()
	for i in 90: await physics_frame
	_check(office.player.is_on_floor() and office.player.jumps==jumps,"resume lands without buffered pause jump")
	# Walking off the bridge must recover before reaching the decorative valley.
	var direction: Vector3=(L.path("creek")[3]-L.path("creek")[2]).normalized()
	var start:=L.CREEK_CENTER-direction*3+Vector3.UP*.1
	office.player.reset_at(start)
	office.farm._checkpoint=start
	for i in 4: await physics_frame
	direction.y=0
	_aim(direction.normalized())
	for i in 240:
		await physics_frame
		if office.farm.recoveries>0: break
	_release()
	_check(office.farm.recoveries==1,"missing bridge planks cause recovery when not jumped")
	# The farm checkpoint rolls forward with the pig (farm_grounds re-projects the pig
	# onto the journey path every physics frame), so recovery lands at the walk-off
	# point, not at the pre-walk `start` position.
	_check(office.player.position.distance_to(office.farm._checkpoint)<.5,"recovery returns to the rolling safe point")
	# Real entry trigger, pause, capture and retry preserve completed companions.
	game.complete_npc("ox")
	office.player.reset_at(L.RETRY)
	office.farm._checkpoint=L.RETRY
	await _walk_to(L.path("chase")[0]+Vector3.UP*.1)
	_check(game.stage=="chase_final" and office.chase._dogs.size()==6,"course trigger starts the final chase (3 dogs + 3 phantoms)")
	_input("ui_cancel")
	await process_frame
	var dogs: Array[Vector3]=[]
	for dog in office.chase._dogs: dogs.append(dog.position)
	for i in 90: await physics_frame
	_check(office.paused and not office.chase.active,"pause suspends chase")
	for i in dogs.size(): _check(dogs[i]==office.chase._dogs[i].position,"paused dog stays still")
	office._resume()
	for i in 720:
		await physics_frame
		if office.overlay.visible: break
	_check(office.overlay.visible and not office.chase.running,"standing still is caught on actual mountain course")
	office._retry()
	_check(game.stage=="exploring" and game.npc_completed.ox,"retry preserves companion progress")
	_check(office.player.position==L.RETRY and office.chase._dogs.is_empty(),"retry resets to approach and clears dogs")
	_check(not office.camera.test_high_view and office.camera.size==8,"gameplay camera stays close after retry")
	print("MOUNTAIN_CONTROLS failures=%d" % failures)
	quit(0 if failures==0 else 1)
