class_name HorizonBackdrop
extends Node

# Horizon closure for the floating hidden-track islands. Course worlds are
# slabs hovering over nothing, and their ZoneEnvironment skies are flat color
# gradients - look down the track and the eye runs off the last platform into
# empty space. This node plants a ring of distant, zone-styled silhouettes
# around the track plus a dark under-disc, so the horizon has something to
# land on. Everything is MeshInstance3D only: no collision, no gameplay, and
# it dies with the course (add_child under the course root).
#
# Styles (per-zone 画风, AGENTS.md S5):
#   "neon"       - course_4 大院: a dusk city skyline of dark towers with
#                  alternating cyan/magenta roof trim for the variety-show set.
#   "voxel"      - course_2 溪流: stacked-block ridges, stone with grass caps.
#   "silhouette" - course_3 林间: a dense ring of near-black conifer
#                  silhouettes fading into the zone mist.
#
# Usage from a course's _ready(), after the ground is built:
#   HorizonBackdrop.apply(self, "neon", Vector3(0, 0, -77), 105.0)

var style := "neon"
var center := Vector3.ZERO
var ring_radius := 100.0
# How far below the track the closing disc sits (below every kill_y, so it
# never catches a falling pig's eye before the respawn).
var disc_drop := 22.0

static func apply(host: Node, style_id: String, ring_center: Vector3, radius: float) -> Node:
	# new() instead of HorizonBackdrop.new(): a freshly added class_name is not
	# in .godot/global_script_class_cache.cfg until the editor rescans, and
	# headless test runs would fail to compile any reference to it by name
	# (same reason ZoneEnvironment.apply does this).
	var hb = new()
	hb.name = "HorizonBackdrop"
	hb.style = style_id
	hb.center = ring_center
	hb.ring_radius = radius
	host.add_child(hb)
	return hb

func _ready() -> void:
	var root := Node3D.new()
	root.name = "BackdropRing"
	add_child(root)
	match style:
		"neon":
			_neon_skyline(root)
		"voxel":
			_voxel_ridges(root)
		"silhouette":
			_silhouette_forest(root)
		_:
			push_warning("HorizonBackdrop: unknown style '%s'" % style)
	_under_disc(root)

func _angle_count() -> int:
	return 26 if style != "silhouette" else 34

func _neon_skyline(root: Node3D) -> void:
	for i in _angle_count():
		var angle := TAU * i / _angle_count()
		var pos := center + Vector3(cos(angle) * ring_radius, 0, sin(angle) * ring_radius)
		var w := 6.0 + float(i % 5) * 1.6
		var h := 18.0 + float((i * 7) % 6) * 4.0 # deterministic 18-38 m towers
		var depth := 6.0
		_slab(root, "NeonTower%d" % i, Vector3(w, h, depth), pos + Vector3(0, h * 0.5, 0),
			Color("0B1329"))
		# Roof trim: alternating cyan/magenta emissive strips - the variety-show
		# skyline reads as lit set pieces against the dusk gradient.
		var trim_color := Color("22D3EE") if i % 2 == 0 else Color("E879F9")
		_slab(root, "NeonTrim%d" % i, Vector3(w * 0.9, 0.8, depth * 0.9),
			pos + Vector3(0, h + 0.4, 0), trim_color, true)

func _voxel_ridges(root: Node3D) -> void:
	for i in _angle_count():
		var angle := TAU * i / _angle_count()
		var pos := center + Vector3(cos(angle) * ring_radius, 0, sin(angle) * ring_radius)
		var base_w := 22.0 + float((i * 5) % 4) * 5.0
		var base_h := 14.0 + float((i * 3) % 5) * 4.0
		# Two stacked stone blocks per ridge - chunky voxel mountains, capped
		# with a grass slab like every other island in the creek zone.
		_slab(root, "VoxelRidge%dBase" % i, Vector3(base_w, base_h, base_w * 0.6),
			pos + Vector3(0, base_h * 0.5, 0), Color("78909C"))
		var top_w := base_w * 0.62
		var top_h := base_h * 0.5
		_slab(root, "VoxelRidge%dTop" % i, Vector3(top_w, top_h, top_w * 0.6),
			pos + Vector3(0, base_h + top_h * 0.5, 0), Color("8FA3B5"))
		_slab(root, "VoxelRidge%dCap" % i, Vector3(top_w, 0.8, top_w * 0.6),
			pos + Vector3(0, base_h + top_h + 0.4, 0), Color("4ADE80"))

func _silhouette_forest(root: Node3D) -> void:
	# Near-black conifers, dense enough to read as one dark treeline that the
	# zone's heavy mist (fog 0.045) washes into the horizon.
	for i in _angle_count():
		var angle := TAU * i / _angle_count()
		var pos := center + Vector3(cos(angle) * ring_radius, 0, sin(angle) * ring_radius)
		# Tall crowns: the ring sits inside the zone's heavy mist (fog 0.045)
		# and only the upper silhouette reads through - short trees would
		# vanish into the fog wall entirely.
		var crown_h := 18.0 + float((i * 3) % 5) * 4.0
		var crown_r := 4.0 + float(i % 3) * 1.2
		var crown := MeshInstance3D.new()
		crown.name = "TreeCrown%d" % i
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = crown_r
		cone.height = crown_h
		crown.mesh = cone
		crown.position = pos + Vector3(0, crown_h * 0.5 + 4.0, 0)
		crown.material_override = _mat(Color("1B2433"))
		root.add_child(crown)
		_slab(root, "TreeTrunk%d" % i, Vector3(1.2, 8.0, 1.2), pos + Vector3(0, 4.0, 0),
			Color("141B28"))

func _under_disc(root: Node3D) -> void:
	# A wide dark disc well below the track: glancing off a platform edge now
	# lands on "distant ground" instead of the raw background color.
	var disc := MeshInstance3D.new()
	disc.name = "UnderDisc"
	var cyl := CylinderMesh.new()
	cyl.top_radius = ring_radius * 1.05
	cyl.bottom_radius = ring_radius * 1.05
	cyl.height = 0.6
	disc.mesh = cyl
	disc.position = center + Vector3(0, -disc_drop, 0)
	var disc_color := Color("131C36") # dusk haze below the neon set, lighter than the sky top
	if style == "voxel":
		disc_color = Color("3E5C6E") # the creek's far water plane
	elif style == "silhouette":
		disc_color = Color("232C3B") # shadowed forest floor
	disc.material_override = _mat(disc_color)
	root.add_child(disc)

func _slab(root: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color,
		emissive := false) -> void:
	var slab := MeshInstance3D.new()
	slab.name = node_name
	var box := BoxMesh.new()
	box.size = size
	slab.mesh = box
	slab.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
	slab.material_override = mat
	root.add_child(slab)

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
