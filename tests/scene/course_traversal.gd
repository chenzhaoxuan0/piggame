extends RefCounted

# Shared helper for end-to-end course traversal tests. It drives the pig along a
# list of waypoints with its real click-to-move controller and real physics, so
# a test can prove a track is actually completable (no blocked lane, no barrier
# that never opens, no gap that cannot be crossed) instead of poking internals
# with synthetic coordinates.
#
# Knockbacks, respawns and control-mode switches cancel the pig's destination;
# the walker simply re-issues the current waypoint every physics frame, so
# hazards slow the run down without derailing it.
#
# A waypoint counts as passed when the pig is within `reach` of it OR has
# crossed its gate plane (the plane through the waypoint, perpendicular to the
# leg leading into it). Without the plane rule a pig that gets knocked or
# boosted past a waypoint would turn around and walk back to touch it, which
# measures the bot's detours rather than the track.
#
# The returned dictionary carries per-waypoint split times and a knockback
# count, so lap-time tuning can see where the seconds went.
#
# Deliberately not named test_*.gd: run_demo.ps1 -AllTests must not enumerate it.

static func walk(tree: SceneTree, player: Node3D, waypoints: Array[Vector3], is_done: Callable, timeout_s: float = 75.0, reach: float = 1.3, on_tick: Callable = Callable()) -> Dictionary:
	var index := 0
	var started_ms := Time.get_ticks_msec()
	var splits: Array[float] = []
	var knocks := 0
	var was_knocked := false
	# Arc-length table of the route, for a progress probe: when a knockback
	# throws the pig BACK past an already-passed waypoint (e.g. nipped into the
	# previous maze corridor), the target index rewinds so the pig re-routes
	# through the proper gap instead of pushing into a wall face forever.
	var arcs: Array[float] = [0.0]
	for i in range(1, waypoints.size()):
		var step := waypoints[i] - waypoints[i - 1]
		step.y = 0.0
		arcs.append(arcs[i - 1] + step.length())
	# Unstick logic: a wall-hugging walker needs a sidestep. Every 0.6 s of
	# standing still, strafe the commanded target sideways (alternating sides)
	# for 0.8 s, which slides the pig around corner clips and gap edges the way a
	# player would steer. Without it, one knock into a wall face wedges the walk.
	var anchor: Vector3 = Vector3.INF
	var frames_since_probe := 0
	var sidestep := 0 # 0 = none, +1 = +x, -1 = -x
	var sidestep_until := 0.0
	var sidestep_flip := false
	while true:
		await tree.physics_frame
		var seconds := float(Time.get_ticks_msec() - started_ms) / 1000.0
		if not is_instance_valid(player):
			return _result(false, index, seconds, Vector3.INF, "player freed", splits, knocks)
		if is_done.call():
			return _result(true, index, seconds, player.global_position, "", splits, knocks)
		if seconds > timeout_s:
			return _result(false, index, seconds, player.global_position, "timeout", splits, knocks)
		if on_tick.is_valid():
			on_tick.call()

		var knocked: bool = player.has_method("is_knocked_back") and player.is_knocked_back()
		if knocked and not was_knocked:
			knocks += 1
		was_knocked = knocked

		# Advance past every waypoint already passed (never past the last one).
		var flat: Vector3 = player.global_position
		flat.y = 0.0
		while index < waypoints.size() - 1:
			var gate := waypoints[index]
			gate.y = 0.0
			var passed := flat.distance_to(gate) <= reach
			if not passed and index > 0:
				var leg := gate - waypoints[index - 1]
				leg.y = 0.0
				passed = leg.length_squared() > 0.001 and (flat - gate).dot(leg) > 0.0
			if not passed:
				break
			splits.append(seconds)
			index += 1

		# Regression rewind: thrown well behind the previous waypoint -> retarget
		# it (2.5 m slack so small knocks don't cause re-target dithering).
		while index > 0 and _route_progress(flat, waypoints, arcs) < arcs[index - 1] - 2.5:
			index -= 1

		# Stuck probe (skipped while knocked back: that stall is expected).
		# 0.06 m over 0.6 s: sliding along a wall at a crawl still counts as
		# progress; only a true standstill triggers the sidestep. Airborne pigs
		# are skipped too - falling into a pit moves ~0 horizontally, which used
		# to arm a sideways offset that made the respawned pig leap gaps
		# diagonally and land short.
		var grounded: bool = not player.has_method("is_on_floor") or player.is_on_floor()
		frames_since_probe += 1
		if knocked or not grounded or sidestep != 0 and seconds > sidestep_until:
			if knocked or not grounded:
				anchor = Vector3.INF
			if sidestep != 0 and seconds > sidestep_until:
				sidestep = 0
				anchor = Vector3.INF
		if grounded and not knocked and sidestep == 0 and frames_since_probe >= 36:
			if anchor == Vector3.INF or flat.distance_to(anchor) < 0.06:
				sidestep_flip = not sidestep_flip
				sidestep = 1 if sidestep_flip else -1
				sidestep_until = seconds + 0.8
			anchor = flat
			frames_since_probe = 0

		var target := waypoints[index]
		if sidestep != 0:
			target += Vector3(2.6, 0, 0) * sidestep
		if not player.is_moving or player.target_destination.distance_to(target) > 0.01:
			player.interact_target = null
			player._click_route.clear()
			player.target_destination = target
			player.is_moving = true
	return {}

static func _route_progress(flat: Vector3, waypoints: Array[Vector3], arcs: Array[float]) -> float:
	# Arc length of the route point closest to the pig (full scan: routes are short).
	var best_arc := 0.0
	var best_dist := INF
	for i in range(1, waypoints.size()):
		var a := waypoints[i - 1]
		a.y = 0.0
		var b := waypoints[i]
		b.y = 0.0
		var seg := b - a
		var t: float = clampf((flat - a).dot(seg) / maxf(0.001, seg.length_squared()), 0.0, 1.0)
		var closest := a + seg * t
		var d := flat.distance_to(closest)
		if d < best_dist:
			best_dist = d
			best_arc = arcs[i - 1] + seg.length() * t
	return best_arc

static func _result(ok: bool, index: int, seconds: float, position: Vector3, reason: String, splits: Array[float], knocks: int) -> Dictionary:
	return {"ok": ok, "index": index, "seconds": seconds, "position": position, "reason": reason, "splits": splits, "knocks": knocks}
