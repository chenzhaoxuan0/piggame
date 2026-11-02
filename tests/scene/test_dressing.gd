extends SceneTree
const SURFACE=preload("res://scripts/art/mountain_surface.gd")
const L=preload("res://scripts/levels/farm_layout.gd")
var failures:=0
var assertions:=0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		push_error(message)
func _run() -> void:
	var office: Node=load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(.5).timeout
	var env: Node=office.farm.get_node("PastoralEnvironment")
	var counts: Dictionary=env.get_meta("dressing_counts",{})
	_check(counts.size()>=18,"diverse dressing classes baked")
	var instances:=0
	for batch in env.find_children("Dressing_*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh=batch.multimesh
		_check(mm.mesh!=null and mm.mesh.get_surface_count()==1,"one surface per dressing batch")
		_check(mm.instance_count>0,"dressing batch populated")
		for i in mm.instance_count:
			instances+=1
			var t: Transform3D=batch.get_meta("placements")[i] if DisplayServer.get_name()=="headless" else mm.get_instance_transform(i)
			_check(t.basis.determinant()>.001,"nonzero instance scale "+batch.name)
			_check(t.origin.length()>1,"instance placement survives scene serialization "+batch.name)
	_check(instances>400,"environment has substantial planted detail")
	_check(office.camera._canopy_materials.size()>0,"camera receives instanced foliage cutout materials")
	for id in L.ROUTES:
		var route:=L.path(id)
		for i in route.size()-1:
			for fraction in [.2,.5,.8]:
				var p:=route[i].lerp(route[i+1],fraction)
				_check(SURFACE.height_at(p)<p.y,"mountain skin stays below playable route")
	print("DRESSING_TEST assertions=%d instances=%d failures=%d" % [assertions,instances,failures])
	quit(1 if failures else 0)
