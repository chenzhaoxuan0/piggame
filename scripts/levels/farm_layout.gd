extends RefCounted
## Metres, Y up. Shared by terrain, route following, encounters and tests.
const SPAWN := Vector3(0, 32.1, 100)
const PIG_GATE := Vector3(0, 32, 88)
const GATE := Vector3(-82, 2, -229)
const STATION := Vector3(-12, 0, -280)
const LEVER := Vector3(-14, 0, -277)
const RETRY := Vector3(-24, 4.1, -166)
const TRAVEL := Vector3(12, -2, -26)
const TRACK_CENTER := Vector3(40, 8, -120)
const TRACK_STRAIGHT := 50.0
const TERRACES := [
	{"id": "Summit", "center": Vector3(0,32,100), "half": Vector2(14,12)},
	{"id": "OxTerrace", "center": Vector3(50,24,40), "half": Vector2(46,20)},
	{"id": "SheepMeadow", "center": Vector3(-40,16,-40), "half": Vector2(40,22)},
	{"id": "HorsePasture", "center": Vector3(40,8,-120), "half": Vector2(50,30)},
	{"id": "EquipmentCourt", "center": Vector3(-59,2,-174), "half": Vector2(10,8)},
	{"id": "GateCourt", "center": Vector3(-82,2,-224), "half": Vector2(9,6)},
	{"id": "Station", "center": Vector3(-12,0,-278), "half": Vector2(9,9)},
]
const NPCS := {
	"goat": Vector3(-3,32,90), "ox": Vector3(41,24,37),
	"sheep": Vector3(-52,16,-41.5), "horse": Vector3(26,8,-120),
	"farmer": Vector3(-78,2,-225),
}
const RESTS := {"ox": Vector3(38,24,34), "sheep": Vector3(-48,16,-41.5), "horse": Vector3(30,8,-120)}
const ROUTES := {
	"summit": [Vector3(0,32,88),Vector3(0,31,78),Vector3(-20,29,72),Vector3(-29,27,87),Vector3(-30,26,105),Vector3(-52,25,105),Vector3(-58,24,80),Vector3(-48,24,62),Vector3(-25,24,54),Vector3(-8,24,50),Vector3(16,24,64),Vector3(30,24,55)],
	"creek": [Vector3(72,24,20),Vector3(72,23,8),Vector3(50,22,0),Vector3(32,21,8),Vector3(12,20,4),Vector3(-2,18,-10),Vector3(-20,16,-8),Vector3(-40,16,-22)],
	"woodland": [Vector3(-66,16,-62),Vector3(-66,15,-76),Vector3(-46,14,-82),Vector3(-34,13,-70),Vector3(-14,12,-76),Vector3(0,10,-78),Vector3(18,8,-90)],
	"approach": [Vector3(-6,8,-135),Vector3(-18,7,-138),Vector3(-16,6,-154),Vector3(-24,4,-166),Vector3(-30,4,-172)],
	"chase": [Vector3(-30,4,-172),Vector3(-38,4,-172),Vector3(-50,4,-154),Vector3(-70,4,-154),Vector3(-80,3,-174),Vector3(-66,3,-190),Vector3(-46,2,-190),Vector3(-46,2,-210),Vector3(-70,2,-210),Vector3(-82,2,-222)],
	"escape": [Vector3(-82,2,-229),Vector3(-82,2,-242),Vector3(-62,1,-251),Vector3(-40,1,-243),Vector3(-24,0,-255),Vector3(-12,0,-273)],
}
const LOGS := [
	{"a": Vector3(-52,25,105), "b": Vector3(-58,24,80), "t": .4},
	{"a": Vector3(-66,16,-62), "b": Vector3(-66,15,-76), "t": .5},
]
const CREEK_CENTER := Vector3(41,21.5,4)

static func chase_course() -> Array[Vector3]:
	# A suggested line for click navigation and dogs. Player checkpoints are the
	# broad road bends, allowing either side of a hay stack and improvised dodges.
	return [Vector3(-30,4,-172),Vector3(-38,4,-172),Vector3(-50,4,-154),Vector3(-54,4,-151.6),Vector3(-60,4,-151.6),Vector3(-64,4,-154),Vector3(-70,4,-154),Vector3(-80,3,-174),Vector3(-66,3,-190),Vector3(-46,2,-190),Vector3(-43.5,2,-198),Vector3(-43.5,2,-204),Vector3(-46,2,-207),Vector3(-46,2,-210),Vector3(-70,2,-210),Vector3(-82,2,-222)]

static func path(id: String) -> Array[Vector3]:
	var result: Array[Vector3] = []
	result.assign(ROUTES[id])
	return result

static func length_of(points: Array[Vector3]) -> float:
	var total := 0.0
	for i in range(1, points.size()): total += points[i-1].distance_to(points[i])
	return total

static func closest_on_path(p: Vector3, points: Array[Vector3]) -> Dictionary:
	var best := {"distance": INF, "point": points[0], "index": 0, "progress": 0.0}
	var travelled := 0.0
	for i in points.size()-1:
		var a := points[i]
		var b := points[i+1]
		var t := clampf((p-a).dot(b-a) / (b-a).length_squared(), 0, 1)
		var q := a.lerp(b,t)
		var distance := p.distance_to(q)
		if distance < best.distance: best = {"distance":distance,"point":q,"index":i,"progress":travelled+a.distance_to(q)}
		travelled += a.distance_to(b)
	return best

static func journey() -> Array[Vector3]:
	var result: Array[Vector3] = [SPAWN, PIG_GATE]
	result.append_array(path("summit"))
	result.append_array([Vector3(46,24,55),Vector3(56,24,38),Vector3(72,24,20)])
	result.append_array(path("creek"))
	result.append_array([Vector3(-40,16,-32),Vector3(-38,16,-53),Vector3(-66,16,-62)])
	result.append_array(path("woodland"))
	result.append_array([Vector3(20,8,-102),Vector3(30,8,-110),Vector3(10,8,-120),Vector3(-6,8,-135)])
	result.append_array(path("approach"))
	result.append_array(chase_course())
	result.append(GATE)
	result.append_array(path("escape"))
	result.append(STATION)
	return result
