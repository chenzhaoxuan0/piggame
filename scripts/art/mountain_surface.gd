extends RefCounted
## Shared visible ground sampler for mountain skin and rooted scenery.
## The skin is scenery only; authored route/terrace collision stays authoritative.
const L = preload("res://scripts/levels/farm_layout.gd")

static func mesh_height_at(p: Vector3) -> float:
	# Interpolate the exact 3 m triangles used by the baked skin, so roots cannot
	# hover where the analytic ridge bends between grid samples.
	var x:=floorf((p.x+190)/3)*3-190
	var z:=floorf((p.z+380)/3)*3-380
	var u:=(p.x-x)/3
	var v:=(p.z-z)/3
	var a:=height_at(Vector3(x,0,z))
	var b:=height_at(Vector3(x+3,0,z))
	var c:=height_at(Vector3(x+3,0,z+3))
	var d:=height_at(Vector3(x,0,z+3))
	return a+(b-a)*u+(c-b)*v if u>v else a+(c-d)*u+(d-a)*v

static func height_at(p: Vector3) -> float:
	var height := -30.0 + sin(p.x*.025)*2.0 + cos(p.z*.018)*2.0
	var ceiling := INF
	for terrace in L.TERRACES:
		var c: Vector3 = terrace.center
		var r: Vector2 = terrace.half
		var delta := Vector2(absf(p.x-c.x),absf(p.z-c.z))
		# Octagonal corners follow the collision plateau, including its bevels.
		var outside := maxf(maxf(delta.x-r.x,delta.y-r.y),(delta.x/r.x+delta.y/r.y-1.78)*minf(r.x,r.y)*.7)
		outside = maxf(0,outside)
		height = maxf(height,c.y-.05-outside*.58)
		if outside<1.5: ceiling=minf(ceiling,c.y-.05)
	for id in L.ROUTES:
		var route: Array = L.ROUTES[id]
		for i in route.size()-1:
			var a := Vector2(route[i].x,route[i].z)
			var b := Vector2(route[i+1].x,route[i+1].z)
			var q := Vector2(p.x,p.z)
			var t := clampf((q-a).dot(b-a)/(b-a).length_squared(),0,1)
			var distance := q.distance_to(a.lerp(b,t))
			var level := lerpf(route[i].y,route[i+1].y,t)
			var shoulder := 5.5 if id=="chase" else 5.0
			height=maxf(height,level-.05-maxf(0,distance-shoulder)*.62)
			if distance<7.5: ceiling=minf(ceiling,level-.05+maxf(0,distance-4.5)*.18)
	# A real hollow under the broken bridge keeps its missing planks readable.
	var creek := L.CREEK_CENTER
	var forward := (L.path("creek")[3]-L.path("creek")[2]).normalized()
	forward.y=0
	forward=forward.normalized()
	var cross_creek := forward.cross(Vector3.UP).normalized()
	var delta := p-creek
	delta.y=0
	if absf(delta.dot(forward))<2.5 and absf(delta.dot(cross_creek))<19.0:
		ceiling=minf(ceiling,creek.y-2.7)
	return minf(height,ceiling)
