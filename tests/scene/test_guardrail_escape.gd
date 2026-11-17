extends SceneTree
## 2026-11-18 导演反馈：石墙空气墙比木栅栏矮、可两段跳上、圈外可站立。
## 钉几何契约（高度序/可站顶面/圈外草架）+ 真实物理站立验证。

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("GUARDRAIL_ESCAPE_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("GUARDRAIL_ESCAPE_TEST FAIL: %s" % message)

func _init() -> void:
	call_deferred("_run")

func _top_center(body: Node3D) -> Vector3:
	var shape := body.get_child(0) as CollisionShape3D
	var hull := shape.shape as ConvexPolygonShape3D
	var max_y := -1e9
	for p in hull.points:
		max_y = maxf(max_y, p.y)
	var sum := Vector3.ZERO
	var n := 0
	for p in hull.points:
		if absf(p.y - max_y) < 0.01:
			sum += p
			n += 1
	return sum / maxf(n, 1)

func _run() -> void:
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.8).timeout
	office.start_game()
	await create_timer(0.3).timeout
	var farm = office.farm
	var pig = office.player
	pig.set_control_mode("cinematic")

	var stones: Array = _by_kind(farm, "RailStone")
	var woods: Array = _by_kind(farm, "RailWood")
	var aprons: Array = _by_kind(farm, "RailApron")
	_check(stones.size() > 0 and woods.size() > 0 and aprons.size() > 0,
		"Per-segment stone/wood air walls and outside aprons exist (%d/%d/%d)" % [stones.size(), woods.size(), aprons.size()])
	if stones.is_empty() or woods.is_empty() or aprons.is_empty():
		quit(1)
		return

	# 高度用凸板自身厚度（maxy-miny），世界 Y 含台地海拔不可比。
	var stone_h := 0.0
	for b in stones:
		stone_h = maxf(stone_h, _height(b))
	var wood_h := 0.0
	for b in woods:
		wood_h = maxf(wood_h, _height(b))
	_check(stone_h < wood_h, "Stone air wall lower than wood (%.2f < %.2f)" % [stone_h, wood_h])
	_check(stone_h <= 0.9, "Stone top within pig jump apex (%.2f <= 0.9)" % stone_h)
	_check(wood_h <= 1.75, "Wood top reachable from stone top (%.2f <= 1.75)" % wood_h)
	var apex: float = pig.JUMP_SPEED * pig.JUMP_SPEED / (2.0 * pig.GRAVITY)
	_check(apex >= stone_h and apex >= wood_h - stone_h,
		"Jump apex %.2f covers ground->stone and stone->wood hops" % apex)

	# 真实物理：石墙顶 / 木栅栏顶 / 圈外草架 三处都站得住（不坠空不重生）。
	var recoveries_before: int = farm.recoveries
	for pair in [["stone top", stones[0]], ["wood top", woods[0]], ["outside apron", aprons[0]]]:
		var spot: Vector3 = _top_center(pair[1])
		pig.global_position = spot + Vector3.UP * 0.3
		pig.velocity = Vector3.ZERO
		await create_timer(0.7).timeout
		_check(pig.is_on_floor() and absf(pig.global_position.y - spot.y) < 0.35,
			"Pig stands on %s (y=%.2f target=%.2f)" % [pair[0], pig.global_position.y, spot.y])
	_check(farm.recoveries == recoveries_before, "No fall recovery while standing on walls/apron")

	office.queue_free()
	await process_frame
	print("\nGUARDRAIL ESCAPE TESTS FINISHED: failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)

func _by_kind(farm: Node, kind: String) -> Array:
	var out: Array = []
	for b in farm.find_children("*", "StaticBody3D", true, false):
		if b.get_meta("rail_kind", "") == kind:
			out.append(b)
	return out

func _height(body: Node3D) -> float:
	var shape := body.get_child(0) as CollisionShape3D
	var hull := shape.shape as ConvexPolygonShape3D
	# _convex 点序为「顶,底」成对：首对之差即纯段高（不受坡道海拔差影响）。
	return hull.points[0].y - hull.points[1].y
