extends Node3D
## Reusable pastoral architecture and palette mesh primitives.
## mountain_environment.gd places these modules on the shared mountain layout.

const GRASS := Color("879B60")
const MEADOW := Color("95A96A")
const GRASS_DARK := Color("708651")
const LEAF := Color("526E49")
const LEAF_LIGHT := Color("698553")
const STONE := Color("8B9093")
const STONE_LIGHT := Color("A5A69F")
const ROCK := Color("777F8D")
const WOOD := Color("9C805E")
const WOOD_LIGHT := Color("B39A70")
const WOOD_DARK := Color("665A48")
const ROOF := Color("626F75")
const SOIL := Color("614739")
const SOIL_LIGHT := Color("795A43")
const PATH := Color("C2AE85")
const STRAW := Color("C9B16C")
const CREAM := Color("E1DDC5")
const RED := Color("A96550")
const WATER := Color("6C9E9C")
const IRON := Color("515A5A")

var _batches: Dictionary = {}
var _district := "Landscape"
var _rng := RandomNumberGenerator.new()
var _material: ShaderMaterial
var _farm: Node3D

func _tool(point: Vector3) -> SurfaceTool:
	var key := "%s_%d_%d" % [_district, floori(point.x / 20), floori(point.z / 20)]
	if _district == "PigGateGeometry": key = _district
	if not _batches.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(_material)
		_batches[key] = surface
	return _batches[key]

func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.5: return
	if normal.dot(outward) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	var surface := _tool((a + b + c) / 3.0)
	# Godot front faces use clockwise winding; normals still point outward.
	for vertex in [a, c, b]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(vertex)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	_tri(a, b, c, color, outward)
	_tri(a, c, d, color, outward)

func _box(pos: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var p: Array[Vector3] = []
	for y in [-0.5, 0.5]:
		for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
			p.append(pos + basis * (Vector3(corner.x, y, corner.y) * size))
	_quad(p[4], p[5], p[6], p[7], color, Vector3.UP)
	_quad(p[3], p[2], p[1], p[0], color, Vector3.DOWN)
	for i in 4:
		var j := (i + 1) % 4
		_quad(p[i], p[j], p[j + 4], p[i + 4], color, (p[i] + p[j]) * 0.5 - pos)

func _beam(a: Vector3, b: Vector3, width: float, depth: float, color: Color) -> void:
	var direction := (b - a).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.1: side = Vector3.RIGHT
	var up := side.cross(direction).normalized()
	var p: Array[Vector3] = []
	for end in [a, b]:
		p.append(end - side * width * 0.5 - up * depth * 0.5)
		p.append(end + side * width * 0.5 - up * depth * 0.5)
		p.append(end + side * width * 0.5 + up * depth * 0.5)
		p.append(end - side * width * 0.5 + up * depth * 0.5)
	_quad(p[0], p[1], p[2], p[3], color, -direction)
	_quad(p[4], p[5], p[6], p[7], color, direction)
	for i in 4:
		var j := (i + 1) % 4
		_quad(p[i], p[j], p[j + 4], p[i + 4], color, (p[i] + p[j]) * 0.5 - a)

func _patch(center: Vector3, radius: Vector2, color: Color, count: int = 20, irregularity: float = 0.1) -> void:
	var previous := _district
	_district = "Ground_" + previous
	var points: Array[Vector3] = []
	for i in count:
		var angle := TAU * i / count
		var wobble := 1.0 + irregularity * sin(i * 2.37 + center.x * 0.3 + center.z)
		points.append(center + Vector3(cos(angle) * radius.x, 0, sin(angle) * radius.y) * wobble)
	for i in count: _tri(center, points[i], points[(i + 1) % count], color, Vector3.UP)
	_district = previous

func _ribbon(points: Array[Vector3], width: float, color: Color) -> void:
	for i in range(points.size() - 1):
		var side := (points[i + 1] - points[i]).normalized().cross(Vector3.UP) * width * 0.5
		_quad(points[i] - side, points[i] + side, points[i + 1] + side, points[i + 1] - side, color, Vector3.UP)
	for point in points: _patch(point, Vector2.ONE * width * 0.5, color, 12, 0)

func _boulder(center: Vector3, size: Vector3, color: Color, phase: float = 0) -> void:
	var rings: Array = []
	for ring in 3:
		var row: Array[Vector3] = []
		for i in 7:
			var angle := TAU * float(i) / 7.0 + phase
			var radius := [0.68, 1.0, 0.65][ring] as float
			var vary := 1.0 + sin(i * 7.3 + phase) * 0.09
			row.append(center + Vector3(cos(angle) * radius * vary, [-0.48, 0.05, 0.42][ring], sin(angle) * radius * vary) * size)
		rings.append(row)
	for i in 7:
		var j := (i + 1) % 7
		_tri(center + Vector3(0, size.y * 0.58, 0), rings[2][i], rings[2][j], color, Vector3.UP)
		for ring in 2:
			_quad(rings[ring][i], rings[ring][j], rings[ring + 1][j], rings[ring + 1][i], color, rings[1][i] - center)

func _stone_wall(a: Vector3, b: Vector3, height: float = 1.05, thickness: float = 0.5) -> void:
	var length := a.distance_to(b)
	var count := maxi(1, ceili(length / 1.05))
	var direction := (b - a).normalized()
	var angle := atan2(direction.x, direction.z)
	var row_count := maxi(1, roundi((height - 0.16) / 0.34))
	for row in row_count:
		for i in count:
			var p := a.lerp(b, (i + 0.5) / count)
			p.y += 0.17 + row * 0.34
			var shade := STONE.lerp(STONE_LIGHT, _rng.randf_range(0, 0.55))
			_stone_block(p, Vector3(thickness + _rng.randf_range(-0.04, 0.04), 0.32, length / count - 0.025), shade, angle + _rng.randf_range(-0.025, 0.025))
	# Coping is a separate, slightly wider course resting cleanly on top of the uppermost wall course.
	var coping_y: float = 0.17 + (row_count - 1) * 0.34 + 0.16 + 0.07
	for i in count:
		_stone_block(a.lerp(b, (i + 0.5) / count) + Vector3.UP * coping_y, Vector3(thickness + 0.12, 0.16, length / count - 0.025), STONE_LIGHT, angle)

func _stone_block(p: Vector3, size: Vector3, color: Color, angle: float) -> void:
	var basis := Basis(Vector3.UP, angle)
	var footprint := [Vector2(-.40, -.5), Vector2(.40, -.5), Vector2(.5, -.40), Vector2(.5, .40), Vector2(.40, .5), Vector2(-.40, .5), Vector2(-.5, .40), Vector2(-.5, -.40)]
	for i in 8:
		var a: Vector2 = footprint[i]
		var b: Vector2 = footprint[(i + 1) % 8]
		var low_a := p + basis * (Vector3(a.x, -.5, a.y) * size)
		var low_b := p + basis * (Vector3(b.x, -.5, b.y) * size)
		var high_a := p + basis * (Vector3(a.x * .94, .5, a.y * .94) * size)
		var high_b := p + basis * (Vector3(b.x * .94, .5, b.y * .94) * size)
		_quad(low_a, low_b, high_b, high_a, color, (low_a + low_b) * .5 - p)
		_tri(p + Vector3.UP * size.y * .5, high_a, high_b, color, Vector3.UP)

func _bucket(p: Vector3) -> void:
	# 白盒清扫：木水桶复用 PROP_10_WATER_BUCKET（游乐场拱翻水桶同款模型）。
	_place_lux("PROP_10_WATER_BUCKET", p, 1.0)

func _feed_rack(p: Vector3, length: float = 2.4) -> void:
	# 2026-11-16 回退：ENV_10_FEED_RACK 模型撤销，恢复原程序托盘四腿饲料架。
	_box(p + Vector3(0, .45, 0), Vector3(length, .15, .8), WOOD_DARK)
	for x in [-length * .45, length * .45]:
		for z in [-.3, .3]: _box(p + Vector3(x, .25, z), Vector3(.11, .5, .11), WOOD)
	for i in ceili(length / .3):
		var x := -length * .5 + i * .3
		for z in [-1, 1]: _beam(p + Vector3(x, .5, z * .25), p + Vector3(x, 1.15, z * .55), .065, .065, WOOD_LIGHT)
	_patch(p + Vector3.UP * .70, Vector2(length * .48, .4), STRAW, 14, .1)
	_collider("FeedRack", p + Vector3(0, .5, 0), Vector3(length, 1, .8))

func _fence(a: Vector3, b: Vector3, color: Color = WOOD, height: float = 1.1) -> void:
	var length := a.distance_to(b)
	var count := maxi(1, ceili(length / 2.3))
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		_box(p + Vector3.UP * height * 0.5, Vector3(0.17, height + 0.12, 0.17), color)
	for h in [0.38, 0.82]: _beam(a + Vector3.UP * h * height, b + Vector3.UP * h * height, 0.09, 0.14, color)

func _hedge(a: Vector3, b: Vector3, height: float = 1.2) -> void:
	var count := maxi(1, ceili(a.distance_to(b) / 1.7))
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		_boulder(p + Vector3(0, height * 0.52, 0), Vector3(0.93, height, 0.74), LEAF.lerp(LEAF_LIGHT, float(i % 3) * 0.16), i * 0.7)

func _tuft(p: Vector3, size: float = 0.45, color: Color = GRASS_DARK) -> void:
	for i in 3:
		var angle := i * 2.1 + p.x
		var side := Vector3(cos(angle), 0, sin(angle)) * size * 0.23
		var tip := p + Vector3(sin(angle) * size * 0.35, size * (0.6 + i * 0.18), cos(angle) * size * 0.35)
		_tri(p - side, p + side, tip, color, Vector3(1, 0.2, 1))
		_tri(p + side, p - side, tip, color, Vector3(-1, 0.2, -1))

func _tree(p: Vector3, scale_factor: float = 1.0) -> void:
	_beam(p, p + Vector3(0.15, 2.8, 0) * scale_factor, 0.42 * scale_factor, 0.38 * scale_factor, WOOD_DARK)
	for i in 4:
		var angle := i * 1.8
		var end := p + Vector3(cos(angle) * 1.1, 2.7 + i * 0.22, sin(angle) * 0.9) * scale_factor
		_beam(p + Vector3.UP * 1.8 * scale_factor, end, 0.17 * scale_factor, 0.17 * scale_factor, WOOD_DARK)
		_boulder(end + Vector3.UP * 0.5 * scale_factor, Vector3(1.5, 1.85, 1.3) * scale_factor, LEAF.lerp(LEAF_LIGHT, i * 0.18), i * 0.61)
	_boulder(p + Vector3(0, 4.0, 0) * scale_factor, Vector3(1.25, 1.65, 1.15) * scale_factor, LEAF_LIGHT, 0.4)

func _collider(label: String, p: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = p
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

## Lux3D 模型挂点：共享 builder 里的白模地标改由模型绘制。山地子类把它接到
## dressing 批处理（坐标加 _origin、烘进 pastoral_farm.scn）；裸基类只被
## course_01 的四邻场景直接实例化（那里不摆农场地标），保持 no-op。
## scale 传数字（整体等比）或 Vector3（分轴适配——当生成模型的长宽比与
## 原白模不一致时，优先保碰撞盒不露隐形边）。
func _place_lux(_id: String, _local: Vector3, _scale = 1.0, _yaw := 0.0) -> void:
	pass

func _pigpen() -> void:
	_district = "PigpenStoneAndMud"
	_patch(Vector3(0, .045, 94), Vector2(8.7, 6.0), Color("939665"), 28, .045)
	_patch(Vector3(.3, .055, 93), Vector2(4.8, 3.25), Color("9C8665"), 30, .06)
	_patch(Vector3(.3, .063, 93), Vector2(4.0, 2.65), Color("796451"), 30, .065)
	_patch(Vector3(1.6, .068, 92.7), Vector2(2.0, 1.0), Color("8D7562"), 15, .12)
	# Low ruined shelter in the back corner: open toward the player and camera.
	# 2026-11-16 回退：ENV_10_RUINED_SHED 模型撤销——分轴拉伸在实机上变形，
	# 恢复原程序白模断顶棚（后墙/侧墙/立柱碰撞体本就未动）。
	var p := Vector3(-6, 0, 89.3)
	_box(p + Vector3(-2.3, 1.05, 0), Vector3(.3, 2.1, 4.2), WOOD_DARK)
	_box(p + Vector3(0, .65, -2), Vector3(4.8, 1.3, .35), WOOD_DARK)
	_collider("PigShelterBack", p + Vector3(-2.3, 1.05, 0), Vector3(.3, 2.1, 4.2))
	_collider("PigShelterSide", p + Vector3(0, .65, -2), Vector3(4.8, 1.3, .35))
	for i in 11:
		_box(p + Vector3(-2.05 + i * .42, .70, -1.82), Vector3(.38, 1.4 + sin(i) * .08, .09), WOOD.lerp(WOOD_DARK, float(i % 3) * .16))
	for x in [-2.25, 2.25]:
		for z in [-1.85, 1.85]:
			_box(p + Vector3(x, 1.22, z), Vector3(.22, 2.44, .22), WOOD)
			_collider("ShelterPost", p + Vector3(x, 1.22, z), Vector3(.22, 2.44, .22))
	for x in [-2.25, 2.25]: _beam(p + Vector3(x, 2.7, -2.1), p + Vector3(x, 2.35, 2.1), .18, .20, WOOD)
	# Slates remain on the far half, leaving a genuine broken roof silhouette.
	for row in 5:
		for col in 9:
			if row > 2 and col > 5: continue
			var z := -2.0 + row * .54
			_box(p + Vector3(-2.0 + col * .51, 2.68 - (z + 2) * .085, z), Vector3(.50, .09, .56), ROOF.lightened(float((row + col) % 3) * .028))
	_patch(p + Vector3(0, .079, .2), Vector2(1.7, 1.5), STRAW.darkened(.1), 14, .15)
	for i in 28:
		var q := p + Vector3(_rng.randf_range(-1.7, 1.7), .085, _rng.randf_range(-1.5, 1.6))
		_box(q, Vector3(.20, .015, .045), STRAW, _rng.randf() * PI)
	# Chipped rock outcrops and vegetation sit on the safe side of the cliff.
	for i in 12:
		var q := Vector3(9.7 + sin(i) * .3, -.12, 87 + i * 1.2)
		_boulder(q, Vector3(.7, .6, 1.0), ROCK, i)
		_tuft(q + Vector3(-.8, .17, 0), .6)
	for q in [Vector3(-7, .08, 97), Vector3(7, .08, 97), Vector3(-7, .08, 92), Vector3(5, .08, 88), Vector3(8, .08, 91)]:
		for i in 5: _tuft(q + Vector3(sin(i * 2) * .6, 0, cos(i * 2) * .6), .5)
	_feed_rack(Vector3(-6.7, 0, 94), 2.2)
	_bucket(Vector3(-3.2, .04, 96.6))
	for i in 6: _stone_block(Vector3(5 + i * .35, .10, 89 + sin(i) * .16), Vector3(.6, .13, .4), STONE, i * .2)
	# Physical wooden pig gate follows the original opening/reset visibility.
	var previous := _district
	_district = "PigGateGeometry"
	_fence(Vector3(-2.15, -.6, 0), Vector3(2.15, -.6, 0), WOOD, 1.15)
	_beam(Vector3(-2, -.35, .02), Vector3(2, .38, .02), .11, .12, WOOD_LIGHT)
	var gate_mesh := MeshInstance3D.new()
	gate_mesh.name = "PigpenGateInsert"
	gate_mesh.mesh = (_batches[_district] as SurfaceTool).commit()
	gate_mesh.hide()
	add_child(gate_mesh)
	_batches.erase(_district)
	_district = previous

func _fields() -> void:
	_district = "OxFurrowsAndIrrigation"
	# 2026-11-12: the furrow field used to sprawl across the ox-gate main lane
	# and the ox-NPC spur; trimmed and shifted west so the crops sit off the road
	# corridor. 2026-11-13 follow-up: the loose dirt patch still reached world
	# x 41 / z 55 and ran under the summit road's gate-corner quad, and the
	# irrigation ditch cut straight through the barn — patch hugs the furrow
	# rectangle now (world x ~6..32, z ~34..54, >=1.3 m clear of every road
	# boundary), furrows trimmed to 11x8, ditch re-routed east of the barn.
	_patch(Vector3(-31.2, .044, 57.9), Vector2(13.0, 10.0), SOIL, 16, .025)
	# Low trapezoidal furrows: actual raised soil volumes, not a row of boxes.
	for row in 8:
		var z := 51.4 + row * 1.85
		for col in 11:
			var x := -40.0 + col * 1.6
			var h := .17 + sin(col * .8 + row) * .025
			var shade := SOIL_LIGHT.lightened(float(row % 3) * .012)
			_quad(Vector3(x, .06, z - .6), Vector3(x + 1.61, .06, z - .6), Vector3(x + 1.61, h, z - .3), Vector3(x, h, z - .3), shade, Vector3(0, 1, -1))
			_quad(Vector3(x, h, z - .3), Vector3(x + 1.61, h, z - .3), Vector3(x + 1.61, h, z + .3), Vector3(x, h, z + .3), shade, Vector3.UP)
			_quad(Vector3(x, h, z + .3), Vector3(x + 1.61, h, z + .3), Vector3(x + 1.61, .06, z + .6), Vector3(x, .06, z + .6), SOIL, Vector3(0, 1, 1))
			if row > 4 and col % 2 == 0:
				_tuft(Vector3(x + .7, h, z), .40, LEAF_LIGHT)
	# Stone-lined irrigation ditch runs along the field edge, east of the barn
	# (the old line crossed the barn footprint) with a plank footbridge.
	_box(Vector3(-20.75, .056, 48.5), Vector3(12.5, .03, .95), WATER)
	for z in [47.94, 49.06]: _stone_wall(Vector3(-27, 0, z), Vector3(-14.5, 0, z), .22, .30)
	for i in 4: _box(Vector3(-21.4 + i * .35, .34, 48.5), Vector3(.32, .12, 1.9), WOOD)
	for i in 8:
		_box(Vector3(-26 + i * 1.5, .081, 48.4 + sin(i) * .15), Vector3(.6, .01, .035), Color("B1C8B7"))
	_barn(Vector3(-33, 0, 46), Vector3(11, 5, 8), false)
	# 2026-11-16 回退：ENV_10_SILO 模型撤销，恢复程序圆柱筒仓（锥顶塔身）。
	for i in 18:
		var a := TAU * i / 18.0
		var b := TAU * (i + 1) / 18.0
		var center := Vector3(-41.5, 0, 38)
		_quad(center + Vector3(cos(a) * 2.5, 0, sin(a) * 2.5), center + Vector3(cos(b) * 2.5, 0, sin(b) * 2.5), center + Vector3(cos(b) * 2.1, 8.8, sin(b) * 2.1), center + Vector3(cos(a) * 2.1, 8.8, sin(a) * 2.1), Color("A8AEAB"), Vector3(cos(a), 0, sin(a)))
		_tri(center + Vector3(cos(a) * 2.3, 8.8, sin(a) * 2.3), center + Vector3(cos(b) * 2.3, 8.8, sin(b) * 2.3), center + Vector3(0, 10, 0), ROOF, Vector3.UP)
	_tree(Vector3(-42, 0, 58), 1.35)
	_bucket(Vector3(-24.5, 0, 41))
	_feed_rack(Vector3(-25, 0, 42), 2.6)
	# Right side is an orchard/pasture with rows of fruit trees and smaller beds.
	for x in [18, 25, 32]:
		for z in [48, 57, 65]:
			_tree(Vector3(x, 0, z), 1.0)
			_collider("OrchardTrunk", Vector3(x, 1, z), Vector3(.5, 2, .5))
	# 2026-11-13: the four small beds used to straddle the ox->creek lane (world
	# z ~28, one dead-center on it); moved into the orchard interior between the
	# tree rows (world z ~46), fully off the lane.
	for i in 4:
		_patch(Vector3(12 + i * 3, .05, 60), Vector2(1.05, 2.0), SOIL, 8, .03)
		for j in 5: _tuft(Vector3(12 + i * 3, .08, 58.5 + j * .65), .5, LEAF_LIGHT)

func _barn(p: Vector3, size: Vector3, add_collision: bool = true) -> void:
	# 2026-11-16 回退：ENV_10_BARN 模型撤销，恢复原程序红墙谷仓（挂板 + 坡顶
	# + 双 stable 门）；碰撞体回到与盒体一致的 (11,5,8) 档。
	var w := size.x
	var h := size.y
	var d := size.z
	_box(p + Vector3(0, h * .5, 0), size, RED)
	if add_collision: _collider("BarnBody", p + Vector3(0, h * .5, 0), size)
	# Horizontal weatherboards and corner trim make a building, not a red cube.
	for row in ceili(h / .38):
		var y := .18 + row * .38
		_box(p + Vector3(0, y, d * .5 + .03), Vector3(w, .34, .07), RED.lightened(float(row % 3) * .025))
		_box(p + Vector3(w * .5 + .03, y, 0), Vector3(.07, .34, d), RED.lightened(float(row % 3) * .025))
	for x in [-w * .5, w * .5]:
		for z in [-d * .5, d * .5]: _box(p + Vector3(x, h * .5, z), Vector3(.16, h + .1, .16), CREAM)
	var ridge := h + w * .28
	for side in [-1, 1]:
		_quad(p + Vector3(0, ridge, -d * .56), p + Vector3(0, ridge, d * .56), p + Vector3(side * w * .56, h, d * .56), p + Vector3(side * w * .56, h, -d * .56), ROOF, Vector3(side, 1, 0))
		for z in [-d * .56, d * .56]: _beam(p + Vector3(0, ridge, z), p + Vector3(side * w * .56, h, z), .16, .16, CREAM)
	for z in [-d * .5, d * .5]:
		_tri(p + Vector3(-w * .5, h, z), p + Vector3(w * .5, h, z), p + Vector3(0, ridge, z), RED, Vector3(0, 0, z))
	# Double stable doors facing the camera, with large readable cross braces.
	var door_z := d * .5 + .09
	_box(p + Vector3(0, 1.35, door_z), Vector3(w * .45, 2.7, .1), WOOD_DARK)
	for x in [-w * .225, 0, w * .225]: _box(p + Vector3(x, 1.35, door_z + .08), Vector3(.10, 2.8, .08), CREAM)
	_box(p + Vector3(0, 2.75, door_z + .08), Vector3(w * .47, .12, .08), CREAM)
	_beam(p + Vector3(-w * .21, .12, door_z + .1), p + Vector3(0, 2.65, door_z + .1), .09, .09, CREAM)
	_beam(p + Vector3(w * .21, .12, door_z + .1), p + Vector3(0, 2.65, door_z + .1), .09, .09, CREAM)
	_box(p + Vector3(0, h * .83, door_z), Vector3(.9, .8, .1), WOOD_DARK)

func _shearing() -> void:
	_district = "LowShearingShed"
	var p := Vector3(-16, 0, 10)
	_patch(p + Vector3(0, .053, 0), Vector2(6, 4.5), Color("AC976B"), 16, .05)
	_patch(p + Vector3(.8, .063, 0), Vector2(4.2, 3.0), STRAW, 20, .08)
	# 2026-11-16 回退：ENV_10_SHED_SHEAR 模型撤销，恢复原程序板墙半坡顶剪毛棚
	# （剪毛台、麻袋、悬挂工具与棚内干草都在）；棚外羊毛堆维持白盒清扫的
	# farm_dressing 实体 ENV_09_WOOL（白模羊毛团不再画回，避免双份）。
	# Match the existing back and side collisions, with plank walls and frames.
	for i in 17:
		var z := -3.25 + i * .4
		_box(p + Vector3(-5, 1.1, z), Vector3(.30, 2.2, .38), WOOD_DARK.lerp(WOOD, float(i % 3) * .22))
	for z in [-3.25, 3.25]:
		for i in 25:
			_box(p + Vector3(-4.8 + i * .4, .70, z), Vector3(.38, 1.4, .30), WOOD.lerp(WOOD_DARK, float(i % 4) * .11))
		_box(p + Vector3(0, 1.45, z), Vector3(10, .16, .40), WOOD_LIGHT)
	for x in [-4.8, -.5, 4.5]:
		for z in [-3.1, 3.1]:
			_box(p + Vector3(x, 1.4, z), Vector3(.22, 2.8, .22), WOOD_DARK)
		_beam(p + Vector3(x, 2.8, -3.4), p + Vector3(x, 3.6, 0), .20, .20, WOOD)
		_beam(p + Vector3(x, 3.6, 0), p + Vector3(x, 2.8, 3.4), .20, .20, WOOD)
	_beam(p + Vector3(-5.3, 3.6, 0), p + Vector3(4.8, 3.6, 0), .22, .22, WOOD_DARK)
	# Far roof slope + west end only. Open near slope keeps the sheep visible.
	_quad(p + Vector3(-5.5, 3.65, 0), p + Vector3(4.9, 3.65, 0), p + Vector3(4.9, 2.8, -3.7), p + Vector3(-5.5, 2.8, -3.7), ROOF, Vector3.UP)
	_quad(p + Vector3(-5.5, 3.65, 0), p + Vector3(-2.7, 3.65, 0), p + Vector3(-2.7, 2.8, 3.7), p + Vector3(-5.5, 2.8, 3.7), ROOF, Vector3.UP)
	for i in 11:
		var x := -5.2 + i * .95
		_beam(p + Vector3(x, 3.69, 0), p + Vector3(x, 2.85, -3.7), .05, .04, ROOF.lightened(.12))
	# Actual shearing table, sacking, wool bundles and hanging hand tools.
	_box(p + Vector3(-2.5, .76, 1.6), Vector3(1.6, .14, 1.1), WOOD)
	for x in [-3.1, -1.9]:
		for z in [1.2, 2.0]: _box(p + Vector3(x, .36, z), Vector3(.12, .72, .12), WOOD_DARK)
	for i in 4:
		_box(p + Vector3(-3.6, .24 + i * .38, -2.2), Vector3(1.4, .36, .9), CREAM.darkened(.05 + i * .015))
		_box(p + Vector3(-3.6, .43 + i * .38, -2.2), Vector3(.15, .025, .92), WOOD_LIGHT)
	for i in 75:
		var q := p + Vector3(_rng.randf_range(-4.7, 4.3), .077, _rng.randf_range(-3.1, 3.1))
		_box(q, Vector3(.22, .015, .045), STRAW.lightened(.13), _rng.randf() * PI)
	_beam(p + Vector3(-4.7, 1.1, -.8), p + Vector3(-4.7, 2.3, -.6), .06, .06, WOOD_LIGHT)
	_box(p + Vector3(-4.7, 1.1, -.8), Vector3(.12, .1, .5), IRON)
	_bucket(Vector3(-10.1, .03, 12))
	_feed_rack(Vector3(-7.8, 0, 15.8), 2.6)
	# Holding pen behind the shed, with a gate on the east side.
	for segment in [[Vector3(-22, 0, 15), Vector3(-22, 0, 21)], [Vector3(-22, 0, 21), Vector3(-9, 0, 21)], [Vector3(-9, 0, 21), Vector3(-9, 0, 18)]]:
		_fence(segment[0], segment[1], WOOD)
		var mid: Vector3 = (segment[0] + segment[1]) * .5
		var size: Vector3 = (segment[1] - segment[0]).abs() + Vector3(.22, 1.1, .22)
		_collider("SheepHoldingFence", mid + Vector3.UP * .55, size)
	for q in [Vector3(-21, .04, 18), Vector3(-12, .04, 20), Vector3(-9, .04, 17)]: _flowers(q, 12)
	_pond(Vector3(26, 0, 6))
	_patch(Vector3(8, .055, 4), Vector2(3.4, 2.9), MEADOW.lightened(.07), 18, .13)
	for q in [Vector3(9, .07, 5), Vector3(6, .07, 3), Vector3(10, .07, 2)]: _flowers(q, 9)

func _pond(p: Vector3) -> void:
	_patch(p + Vector3.UP * .04, Vector2(7.5, 6.5), Color("A79E77"), 28, .13)
	_patch(p + Vector3.UP * .055, Vector2(6.8, 5.9), WATER, 28, .13)
	for i in 25:
		var a := i * TAU / 25
		var q := p + Vector3(cos(a) * 7.1, .20, sin(a) * 6.1)
		if i % 3 == 0: _boulder(q, Vector3(.55, .5, .44), STONE, i)
		for j in 3:
			var r := q + Vector3(j * .16, 0, j * .13)
			_beam(r, r + Vector3(.08, .8 + j * .16, 0), .035, .035, LEAF)
			_beam(r + Vector3(.08, .75 + j * .16, 0), r + Vector3(.08, 1 + j * .16, 0), .10, .08, WOOD_DARK)
	for i in 8:
		_patch(p + Vector3(sin(i * 4) * 4.8, .065, cos(i * 4) * 3.5), Vector2(.42, .28), LEAF_LIGHT, 9, .08)
		_box(p + Vector3(sin(i * 3) * 4.8, .071, cos(i * 3) * 3.5), Vector3(.65, .01, .028), Color("B1CBC0"))

func _bench(p: Vector3) -> void:
	# 白盒清扫：长椅由 ENV_10_BENCH 模型绘制（模型实长 1.82 m，放大到原
	# 2.3 m 座宽与 Bench 碰撞体对齐）。
	_place_lux("ENV_10_BENCH", p, 2.3 / 1.82)
	_collider("Bench", p + Vector3(0, .6, 0), Vector3(2.3, 1.2, .7))

func _flowers(p: Vector3, count: int) -> void:
	for i in count:
		var q := p + Vector3(sin(i * 8.6) * 1.1, 0, cos(i * 5.2) * 1.0)
		_tuft(q, .32, LEAF_LIGHT)
		_patch(q + Vector3.UP * (.27 + (i % 3) * .03), Vector2(.11, .11), CREAM if i % 4 else STRAW, 6, .08)

func _flush() -> void:
	var canopy_material:=_material.duplicate() as ShaderMaterial
	canopy_material.set_shader_parameter("canopy_cutout",true)
	for key in _batches:
		var mesh := MeshInstance3D.new()
		mesh.name = key
		var surface := _batches[key] as SurfaceTool
		surface.index()
		mesh.mesh = surface.commit()
		if "GoldenWilderness" in String(key):
			var golden_material := _material.duplicate() as ShaderMaterial
			golden_material.set_shader_parameter("valley_haze_enabled", false)
			mesh.material_override = golden_material
		if String(key).begins_with("TreeCanopies") or String(key).begins_with("FarmWorkingYard"):
			mesh.material_override=canopy_material
		if String(key).begins_with("MountainSlopes") or String(key).begins_with("ValleyAndHorizon") or String(key).begins_with("Ground_"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	_batches.clear()
