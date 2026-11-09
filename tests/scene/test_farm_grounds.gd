extends SceneTree

# Run: godot --headless --path . --script tests/scene/test_farm_grounds.gd
const L = preload("res://scripts/levels/farm_layout.gd")
var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _hit(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not root.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _run() -> void:
	var farm: Node3D=load("res://scenes/levels/farm/farm_grounds.tscn").instantiate()
	root.add_child(farm)
	await physics_frame
	await physics_frame
	_check(farm.get_spawn_position()==L.SPAWN,"summit spawn contract")
	_check(get_nodes_in_group("interactable").size()==7,"seven story interaction targets")
	_check(farm.get_node("PastoralEnvironment").get_meta("layout_version")==4,"mountain bake is current")
	_check(farm.get_node("PastoralEnvironment").get_script()==null,"runtime uses baked geometry")
	_check(farm.get_node_or_null("Ground")==null,"old giant flat floor removed")
	for point in [L.GATE,L.PIG_GATE]:
		_check(_hit(point+Vector3(0,.7,1),point+Vector3(0,.7,-1)),"closed gate blocks passage")
	for dx in [-6,6]:
		_check(_hit(L.GATE+Vector3(dx,.7,1),L.GATE+Vector3(dx,.7,-1)),"gate side walls block bypass")
	farm.set_gate_open(true)
	farm.set_pigpen_open(true)
	await physics_frame
	await physics_frame
	for point in [L.GATE,L.PIG_GATE]:
		_check(not _hit(point+Vector3(0,.7,1),point+Vector3(0,.7,-1)),"open gate clears passage")
	for terrace in L.TERRACES:
		_check(_hit(terrace.center+Vector3.UP,terrace.center-Vector3.UP),"terrace floor at declared altitude: "+terrace.id)
	for id in L.ROUTES:
		var points:=L.path(id)
		for i in points.size()-1:
			for t in [.15,.35,.65,.85]:
				var point:=points[i].lerp(points[i+1],t)
				_check(_hit(point+Vector3.UP,point-Vector3.UP*.5),"walkable slope "+id+" segment "+str(i))
	_check(not _hit(L.CREEK_CENTER+Vector3.UP*.4,L.CREEK_CENTER-Vector3.UP*.8),"creek bridge has a real jump gap")
	_check(_hit(Vector3(-54,4.6,-154),Vector3(-60,4.6,-154)),"central hay stack blocks straight sprint")
	_check(_hit(Vector3(-46,2.6,-198),Vector3(-46,2.6,-204)),"second stack forces opposite side")
	_check(L.length_of(L.path("summit"))>150,"substantial winding summit descent")
	_check(L.length_of(L.chase_course())>170,"extended obstacle chase")
	_check(L.length_of(L.path("escape"))>85,"winding route after gate")
	_check(L.TRACK_STRAIGHT==50,"50 metre stadium straight")
	var route: Array[Vector3]=farm.click_path(Vector3(0,31,78),Vector3(-30,26,105))
	_check(route.size()>2 and L.length_of(route)>45,"click routing follows switchback instead of cliff shortcut")
	farm.set_npc_completed("ox")
	await create_timer(1).timeout
	_check(farm.get_node("NPC_ox").position.distance_to(L.RESTS.ox)<.05,"ox moves to water on its own terrace")
	farm.reset_world()
	await physics_frame
	_check(farm.get_node("NPC_ox").position==L.NPCS.ox,"reset restores NPC elevation")
	_check(farm.get_cablecar().position==L.STATION,"cabin starts at relocated station")
	farm.queue_free()
	await process_frame
	var office: Node=load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(.6).timeout
	_check(office.in_start_menu,"start menu opens on entry")
	_check(not office.dialogue_open,"dialogue not auto opened on entry")
	office.start_game()
	_check(not office.in_start_menu and not office.dialogue_open,"game starts into explore mode")
	_check(office.camera.size==8 and office.camera.camera_offset.y==5.25,"default camera halves view and height")
	var pause:=InputEventAction.new()
	pause.action="ui_cancel"
	pause.pressed=true
	Input.parse_input_event(pause)
	await process_frame
	_check(office.paused and office.overlay.visible,"Esc opens settings")
	var toggle: CheckButton=office.overlay_buttons.get_node("TestHighCamera")
	toggle.button_pressed=true
	_check(office.camera.test_high_view and office.camera.size==16 and office.camera.camera_offset.y==10.5,"settings restores original test camera")
	toggle.button_pressed=false
	_check(not office.camera.test_high_view and office.camera.size==8,"settings restores gameplay camera")
	office._resume()
	_check(not office.overlay.visible and not office.paused,"resume closes settings")
	office.queue_free()
	await process_frame
	print("FARM_GROUNDS_TEST assertions=%d failures=%d" % [assertions,failures])
	quit(0 if failures==0 else 1)
