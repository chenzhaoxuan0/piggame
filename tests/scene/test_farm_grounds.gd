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
	_check(get_nodes_in_group("interactable").size()==8,"eight story interaction targets (5 NPCs + record board + cablecar + pigpen trough)")
	_check(farm.get_node("PastoralEnvironment").get_meta("layout_version")==11,"mountain bake is current")
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
	# 2026-11-16 实机开局的物理闸：0a5244d 那次烘焙的场景产物带碰撞洞——
	# raycast pin 全绿，猪却在 spawn 无限坠落（用户实机 + boot 采样实锤）。
	# raycast 走 broadphase 命中不代表窄相能接住角色，这里用真实刚体落体
	# 复刻故障模式：小球从每个台地中心上方落下，1 秒内必须停在台地高度。
	for terrace in L.TERRACES:
		# 候选落点：台地中心 + 四向偏移（EquipmentCourt 的中心被工作谷仓占
		# 着，球停在仓顶同样是好物理——换空位落点验证地面本身）。
		var drop_offsets: Array[Vector3] = [
			Vector3(0, 2, 0),
			Vector3(terrace.half.x * .55, 2, terrace.half.y * .3),
			Vector3(-terrace.half.x * .55, 2, -terrace.half.y * .3),
			Vector3(terrace.half.x * .3, 2, -terrace.half.y * .55),
		]
		var ball_settled := false
		for off in drop_offsets:
			var ball := RigidBody3D.new()
			var ball_shape := CollisionShape3D.new()
			var ball_sphere := SphereShape3D.new()
			ball_sphere.radius = 0.3
			ball_shape.shape = ball_sphere
			ball.add_child(ball_shape)
			ball.position = terrace.center + off
			root.add_child(ball)
			for i in 60:
				await physics_frame
			if absf(ball.global_position.y - terrace.center.y) < 1.0:
				ball_settled = true
			ball.queue_free()
			if ball_settled:
				break
		_check(ball_settled,
			"dropped ball settles on the terrace floor (real physics, not raycast): " + terrace.id)
	for id in L.ROUTES:
		var points:=L.path(id)
		for i in points.size()-1:
			for t in [.15,.35,.65,.85]:
				var point:=points[i].lerp(points[i+1],t)
				_check(_hit(point+Vector3.UP,point-Vector3.UP*.5),"walkable slope "+id+" segment "+str(i))
	_check(not _hit(L.CREEK_CENTER+Vector3.UP*.4,L.CREEK_CENTER-Vector3.UP*.8),"creek bridge has a real jump gap")
	# 2026-11-18 导演反馈第二轮：草架板回滚后，圈外站立由山体皮肤逐格碰撞
	# （SlopeStandable）承担——牛耕地东栏/羊牧场西栏外的向下射线必须命中皮肤格，
	# 猪跳出围栏才真的站在可见地形上（马场一侧由运行时草带+playground 用例覆盖）。
	for outside in [Vector3(99, 25.0, 40), Vector3(-83, 17.0, -40)]:
		_check(_hit(outside, outside + Vector3.DOWN * 4.0),
			"slope skin stands outside the fence: " + str(outside))
	_check(_hit(Vector3(-54,4.6,-154),Vector3(-60,4.6,-154)),"central hay stack blocks straight sprint")
	_check(_hit(Vector3(-46,2.6,-198),Vector3(-46,2.6,-204)),"second stack forces opposite side")
	_check(farm.get_node("CabbageBall") is RigidBody3D and farm.get_node("PenCabbageBall") is RigidBody3D,
		"both cabbage balls are real rigid bodies (impulse kicks, not tweens)")
	_check(_hit(Vector3(5,34,104.5),Vector3(5,32.2,104.5)),"pen haystack collider catches a falling pig")
	_check(_hit(Vector3(-6,17.6,-40),Vector3(-6,15.9,-40)),"sheep-pond hay dive stack is solid (2026-11-16 move)")
	_check(farm.get_node_or_null("PenBallFence")!=null and farm.get_node_or_null("PitchBallFenceN")!=null
		and farm.get_node_or_null("PitchBallFenceS")!=null and farm.get_node_or_null("PitchBallFenceW")!=null
		and farm.get_node_or_null("PitchBallFenceE")!=null,
		"ball-only fences exist (pen gate gap + four pitch boards)")
	# Rocky crossings into the ox terrace: the descent road's terrace-side rail
	# and the pasture boundary are open at the two stone seams (rays cast at
	# y=25.0 pass under the 1.45 m rail top - they would hit any rail still
	# standing), while the same fence line away from the seams still blocks.
	_check(not _hit(Vector3(10.2,25.0,56.0),Vector3(10.2,25.0,53.0)),"crossing A road rail is open at the seam")
	_check(not _hit(Vector3(10.2,25.0,60.2),Vector3(10.2,25.0,58.2)),"crossing A pasture boundary is open at the bevel")
	_check(not _hit(Vector3(21.7,25.0,55.5),Vector3(21.7,25.0,52.8)),"crossing B road rail is open at the seam")
	# 2026-11-18：石墙空气墙降为 0.85m（可跳上），射线改 0.6m 高验证"护栏仍在"。
	_check(_hit(Vector3(-2,24.6,51.5),Vector3(-2,24.6,48.5)),"summit road rail still blocks away from the crossings")
	_check(_hit(Vector3(10.2,25.2,57.0),Vector3(10.2,23.8,57.0)),"crossing A stepping stone is solid")
	_check(_hit(Vector3(22.9,25.2,56.0),Vector3(22.9,23.8,56.0)),"crossing B stepping stone is solid")
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
