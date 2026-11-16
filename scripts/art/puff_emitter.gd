extends Node3D
## Headless-safe dust/spark emitter. The repo's own convention for dust is
## tweened meshes (farm_grounds._dust_ring): CPUParticles3D segfaults the
## headless dummy renderer (mesh_get_surface_count "m is null"), which took
## down whole suite runs at random asset-heavy tests. Same look, zero
## particle-system risk. `emitting` drives a continuous trickle; burst()
## fires a one-shot spray (splashes, impact sparks).
var tint := Color("C9B48A")
var rate := 12.0
var puff_size := 0.1
var speed := 0.8
var emitting := false
var _acc := 0.0

func _process(delta: float) -> void:
	if not emitting:
		return
	_acc += delta * rate
	while _acc >= 1.0:
		_acc -= 1.0
		_puff(Vector3(randf_range(-0.2, 0.2), 0.1, randf_range(-0.2, 0.2)),
			Vector3(randf_range(-0.3, 0.3), speed, randf_range(0.1, 0.5)))

func burst(count: int, up_speed := 3.5) -> void:
	for i in count:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized()
		_puff(Vector3.ZERO, dir * randf_range(up_speed * 0.5, up_speed))

func _puff(at: Vector3, vel: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = puff_size
	sphere.height = puff_size * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	puff.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material_override = mat
	add_child(puff)
	puff.position = at
	var tw := create_tween()
	tw.tween_property(puff, "position", at + vel * 0.5 + Vector3(0, -0.4, 0), 0.7)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(puff, "scale", Vector3(1.6, 1.6, 1.6), 0.7)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.tween_callback(puff.queue_free)
