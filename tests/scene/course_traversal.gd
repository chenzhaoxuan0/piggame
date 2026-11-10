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

		var target := waypoints[index]
		if not player.is_moving or player.target_destination.distance_to(target) > 0.01:
			player.interact_target = null
			player._click_route.clear()
			player.target_destination = target
			player.is_moving = true
	return {}

static func _result(ok: bool, index: int, seconds: float, position: Vector3, reason: String, splits: Array[float], knocks: int) -> Dictionary:
	return {"ok": ok, "index": index, "seconds": seconds, "position": position, "reason": reason, "splits": splits, "knocks": knocks}
