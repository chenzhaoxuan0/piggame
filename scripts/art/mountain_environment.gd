extends "res://scripts/art/pastoral_environment.gd"
## Mountain farm: authored structures are reused at metre scale; land and roads
## share their exact vertices with collision so slopes never float above a floor.
const L = preload("res://scripts/levels/farm_layout.gd")
const SURFACE = preload("res://scripts/art/mountain_surface.gd")
const DRESSING = preload("res://scripts/art/farm_dressing.gd")
var _dressing = preload("res://scripts/art/dressing_batches.gd").new()
var _origin := Vector3.ZERO

func build(farm: Node3D) -> void:
	_farm = farm
	_rng.seed = 4701
	name = "PastoralEnvironment"
	set_meta("layout_version", 6)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://scripts/art/pastoral_surface.gdshader")
	_mountainside()
	for terrace in L.TERRACES: _terrace(terrace)
	for id in L.ROUTES: _road(id)
	_origin = Vector3(0,32,7)
	_pigpen()
	_origin = Vector3(50,24,-14)
	_fields()
	_collider("OxBarn", Vector3(-33,2.5,46), Vector3(11,5,8))
	_origin = Vector3(-40,16,-51)
	_shearing()
	_collider("ShedBack",Vector3(-21,1.1,10),Vector3(.3,2.2,6.6))
	for z in [6.75,13.25]: _collider("ShedSide",Vector3(-16,.7,z),Vector3(10,1.4,.3))
	_origin = Vector3.ZERO
	_summit_walls()
	_large_racetrack()
	_chase_dressing()
	_meadow_lanes()
	_station()
	_landmarks()
	DRESSING.new().build(self)
	_flush()
	_dressing.flush(self)
	_farm = null

func _slope_height(p: Vector3) -> float:
	return SURFACE.height_at(p)

func _mountainside() -> void:
	# A continuous slope beneath the ledges connects the farm into one mountain.
	# It is scenery below the recoverable drop, never a shortcut collision floor.
	_district="MountainSlopes"
	var rows: Array=[]
	for z in range(-380,179,3):
		var row: Array[Vector3]=[]
		for x in range(-190,191,3):
			var p:=Vector3(x,0,z)
			p.y=_slope_height(p)
			row.append(p)
		rows.append(row)
	for row in rows.size()-1:
		for col in rows[row].size()-1:
			var a: Vector3=rows[row][col]
			var b: Vector3=rows[row][col+1]
			var c: Vector3=rows[row+1][col+1]
			var d: Vector3=rows[row+1][col]
			var color:=GRASS_DARK.lerp(GRASS,.3+.16*sin(a.x*.024+a.z*.036))
			_quad(a,b,c,d,color,Vector3.UP)
	# Close the far rim below the normal camera's sight line.
	for row in rows.size()-1:
		for col in [0,rows[row].size()-1]:
			var a: Vector3=rows[row][col]
			var b: Vector3=rows[row+1][col]
			_quad(a,b,Vector3(b.x,-90,b.z),Vector3(a.x,-90,a.z),ROCK,Vector3.LEFT if col==0 else Vector3.RIGHT)
	for row in [0,rows.size()-1]:
		for col in rows[row].size()-1:
			var a: Vector3=rows[row][col]
			var b: Vector3=rows[row][col+1]
			_quad(a,b,Vector3(b.x,-90,b.z),Vector3(a.x,-90,a.z),ROCK,Vector3.FORWARD if row==0 else Vector3.BACK)

func _tri(a: Vector3,b: Vector3,c: Vector3,color: Color,outward: Vector3) -> void:
	var offset := Vector3.ZERO if _district == "PigGateGeometry" else _origin
	super._tri(a+offset,b+offset,c+offset,color,outward)

func _collider(label: String,p: Vector3,size: Vector3) -> void:
	super._collider(label,p+_origin,size)

func _tree(p: Vector3,scale_factor: float=1.0) -> void:
	var q:=p+_origin
	var id: String=["ENV_09_OAK","ENV_09_BIRCH","ENV_09_PINE"][posmod(roundi(q.x*.7+q.z),3)]
	if _district=="OxFurrowsAndIrrigation" and p.x>0: id="ENV_09_APPLE"
	# The old roadside trees were placed at road height over empty space.
	q.y=SURFACE.mesh_height_at(q)-.08
	_dressing.place(id,q,Vector3.ONE*scale_factor*.85,_rng.randf()*TAU)

func _convex(label: String, top: Array[Vector3], depth: float = .6) -> void:
	var points := PackedVector3Array()
	for p in top:
		points.append(p)
		points.append(p-Vector3.UP*depth)
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("walkable",true)
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	shape.shape = hull
	body.add_child(shape)
	add_child(body)

func _terrace(data: Dictionary) -> void:
	_district = "Ground_"+data.id
	var p: Vector3 = data.center
	var r: Vector2 = data.half
	var contour: Array[Vector3] = []
	# Bevelled grass ledges with faceted retaining cliffs, never a giant flat floor.
	for v in [Vector2(-1,-.78),Vector2(-.83,-1),Vector2(.83,-1),Vector2(1,-.78),Vector2(1,.78),Vector2(.83,1),Vector2(-.83,1),Vector2(-1,.78)]:
		contour.append(p+Vector3(v.x*r.x,0,v.y*r.y))
	_convex(data.id+"Floor",contour)
	for i in contour.size():
		var a := contour[i]
		var b := contour[(i+1)%contour.size()]
		_tri(p,a,b,GRASS if data.id != "HorsePasture" else MEADOW,Vector3.UP)
		_district = "Cliffs_"+data.id
		var down := Vector3(0,-15,0)
		_quad(a,b,b+down,a+down,ROCK,(a+b)*.5-p)
		for j in 3:
			var q := a.lerp(b,(j+.5)/3.0)
			_boulder(q+Vector3(0,-1.0,0),Vector3(2.0,2.1,1.5),ROCK.lightened(.03*(j%3)),j)
		_district = "Ground_"+data.id
	# Grazing boundaries make the edge of playable ground legible. Connections
	# remain open; the scenery skin outside is never mistaken for a walkable field.
	if data.id in ["OxTerrace","SheepMeadow","HorsePasture"]:
		_district="PastureBoundary_"+data.id
		for i in contour.size():
			var a:=contour[i].lerp(p,.025)
			var b:=contour[(i+1)%contour.size()].lerp(p,.025)
			var count:=ceili(a.distance_to(b)/3.4)
			for j in count:
				var first:=a.lerp(b,float(j)/count)
				var last:=a.lerp(b,float(j+1)/count)
				var connection:=false
				for id in L.ROUTES:
					for endpoint in [L.path(id).front(),L.path(id).back()]:
						if first.distance_to(endpoint)<7 or last.distance_to(endpoint)<7: connection=true
				if not connection: _edge_wall(first,last)
	# Meadow details stay outside the route entrances and building footprints.
	for i in 32:
		var q := p+Vector3(_rng.randf_range(-r.x*.8,r.x*.8),.05,_rng.randf_range(-r.y*.8,r.y*.8))
		if data.id in ["Summit","Station","GateCourt"]: continue
		if data.id == "OxTerrace" and q.x<46: continue
		if data.id == "HorsePasture" and absf(q.z+120)<15: continue
		_tuft(q,.45)

func _edge_wall(a: Vector3,b: Vector3,hedge: bool=false) -> void:
	var h := 1.8 if hedge else 1.45
	var direction := (b-a).normalized()
	var side_vector:=direction.cross(Vector3.UP).normalized()
	var count:=maxi(1,ceili(a.distance_to(b)/3.8))
	for i in count:
		var first:=a.lerp(b,float(i)/count)
		var last:=a.lerp(b,float(i+1)/count)
		var q:=(first+last)*.5
		var variant:=posmod(i+roundi(a.x+a.z),5)
		if variant==0 or (hedge and variant==3):
			_stone_wall(first,last,1.25 if hedge else .85,.42)
		else:
			_fence(first,last,WOOD_DARK if variant==2 else WOOD,h)
			if variant==2: _beam(first+Vector3.UP*.2,last+Vector3.UP*(h*.9),.08,.1,WOOD_LIGHT)
		# Vegetation is in broken clumps, with a visible fence behind every gap.
		if variant in [1,3]:
			q+=side_vector*.4
			_dressing.place("ENV_09_HAWTHORN",q-Vector3.UP*.08,Vector3(1.15,.8,1.0),i*1.7)
	# Convex sloping barriers match the visible posts/hedges on descending roads.
	var side := (b-a).normalized().cross(Vector3.UP).normalized()*.15
	_convex("RoadHedge" if hedge else "RoadRail",[a-side+Vector3.UP*h,a+side+Vector3.UP*h,b+side+Vector3.UP*h,b-side+Vector3.UP*h],h)

func _road(id: String) -> void:
	var points: Array[Vector3] = L.path(id)
	var half := 3.8 if id=="chase" else 3.2
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	# Miter joints keep the road and fence continuous at every bend.
	for i in points.size():
		var before := (points[i]-points[maxi(0,i-1)])
		var after := (points[mini(i+1,points.size()-1)]-points[i])
		before.y=0; after.y=0
		if before.length()<.1: before=after
		if after.length()<.1: after=before
		var n1 := before.normalized().cross(Vector3.UP)
		var n2 := after.normalized().cross(Vector3.UP)
		var n := (n1+n2).normalized()
		var side := n*half/maxf(.45,n.dot(n1))
		left.append(points[i]-side)
		right.append(points[i]+side)
	for i in points.size()-1:
		_district = "Ground_Route_"+id
		var intervals := [Vector2(0,1)]
		# 1.58 m missing planks: walk up to the cream lip, jump across the creek.
		if id=="creek" and i==2: intervals=[Vector2(0,.46),Vector2(.54,1)]
		for interval in intervals:
			var a := left[i].lerp(left[i+1],interval.x)
			var b := right[i].lerp(right[i+1],interval.x)
			var c := right[i].lerp(right[i+1],interval.y)
			var d := left[i].lerp(left[i+1],interval.y)
			_quad(a,b,c,d,GRASS,Vector3.UP)
			_convex("Route_"+id,[a,b,c,d])
			var start := points[i].lerp(points[i+1],interval.x)
			var end := points[i].lerp(points[i+1],interval.y)
			if id=="creek" and i==2:
				# Individual bridge planks stop at both broken lips: no circular caps
				# filling the visible gap while collision is missing below them.
				var side:=(b-a).normalized()*2.2
				var count:=ceili(start.distance_to(end)/.42)
				for plank in count:
					var q:=start.lerp(end,(plank+.5)/count)+Vector3.UP*.045
					_beam(q-side,q+side,.38,.08,WOOD_LIGHT.lightened(.035*(plank%3)))
			else:
				# Follow the same cross-sections as the grass mesh: an independent
				# straight strip intersects twisted miter quads on sloping bends.
				var inset:=.5-2.2/(a.distance_to(b))
				_quad(a.lerp(b,inset)+Vector3.UP*.09,b.lerp(a,inset)+Vector3.UP*.09,c.lerp(d,inset)+Vector3.UP*.09,d.lerp(c,inset)+Vector3.UP*.09,PATH,Vector3.UP)
			_district = "Cliffs_Route_"+id
			for edge in [[a,d],[b,c]]:
				_quad(edge[0],edge[1],edge[1]-Vector3.UP*12,edge[0]-Vector3.UP*12,ROCK,(edge[0]-start).normalized())
		_district = "RouteEdges_"+id
		# Open at terrace connections; rail endpoints meet without blocking the lane.
		_edge_wall(left[i],left[i+1],id=="chase")
		_edge_wall(right[i],right[i+1],id=="chase")
		var middle := (points[i]+points[i+1])*.5
		var outward := (right[i]-left[i]).normalized()
		if id!="chase":
			_tree(middle+outward*7.8,.8)
			var rock_pos:=middle-outward*5.6
			rock_pos.y=SURFACE.mesh_height_at(rock_pos)-.2
			_dressing.place("ENV_09_ROCK",rock_pos,Vector3(1.4,1.1,1.3),i)
	# Additional flora on both sides of the path, not in the pig's sight line.
	for i in range(1,points.size()-1):
		_flowers(left[i]+(right[i]-left[i]).normalized()*.6+Vector3.UP*.05,5)

func _summit_walls() -> void:
	_district="SummitEnclosure"
	for segment in [[Vector3(-12,32,88),Vector3(-2.2,32,88)],[Vector3(2.2,32,88),Vector3(12,32,88)],[Vector3(-12,32,88),Vector3(-12,32,110)],[Vector3(12,32,88),Vector3(12,32,110)],[Vector3(-12,32,110),Vector3(12,32,110)]]:
		_stone_wall(segment[0],segment[1],1.5,.55)
		var a: Vector3=segment[0]; var b: Vector3=segment[1]
		_collider("PigpenWall",(a+b)*.5+Vector3.UP*.75,(b-a).abs()+Vector3(.55,1.5,.55))
	for log_data in L.LOGS:
		var a: Vector3=log_data.a; var b: Vector3=log_data.b
		var p:=a.lerp(b,log_data.t)
		var side:=(b-a).normalized().cross(Vector3.UP).normalized()*3.05
		_district="JumpLogs"
		_beam(p-side+Vector3.UP*.26,p+side+Vector3.UP*.26,.55,.52,WOOD_DARK)
		var corners: Array[Vector3]=[p-side+Vector3(.0,.52,-.25),p+side+Vector3(0,.52,-.25),p+side+Vector3(0,.52,.25),p-side+Vector3(0,.52,.25)]
		_convex("JumpLog",corners,.52)
		for x in [-.6,.6]: _box(p+Vector3(x,.54,0),Vector3(.18,.035,.4),CREAM)
	_district="CreekCrossing"
	var p:=L.CREEK_CENTER
	var direction:=(L.path("creek")[3]-L.path("creek")[2]).normalized()
	var across:=direction.cross(Vector3.UP).normalized()
	_ribbon([p-across*16-Vector3.UP*1.2,p+across*16-Vector3.UP*1.2],2.1,WATER)
	for bank in [-1,1]:
		var a: Vector3=p-across*16+direction*bank*1.2-Vector3.UP*1.3
		var b: Vector3=p+across*16+direction*bank*1.2-Vector3.UP*1.3
		_quad(a,b,b+direction*bank*2-Vector3.UP*4,a+direction*bank*2-Vector3.UP*4,ROCK,Vector3.UP)
	for i in 12:
		var q:=p+across*(-14+i*2.5)-Vector3.UP*1.1
		_boulder(q+direction*1.7,Vector3(.7,.5,.65),STONE,i)
	for side in [-1,1]:
		var q: Vector3=p+direction*.9*side
		_beam(q-across*3.2+Vector3.UP*.045,q+across*3.2+Vector3.UP*.045,.12,.08,CREAM)

func _large_racetrack() -> void:
	_district="HorsePaddockAndTrack"
	var p:=L.TRACK_CENTER
	# A stadium, not an ellipse: precisely 50 metres between semicircle centres.
	var ring: Array[Vector3]=[]
	for side in [-1,1]:
		for i in 33:
			var angle:=(-PI*.5 if side==1 else PI*.5)+PI*i/32.0
			ring.append(p+Vector3(side*25+cos(angle)*11,.045,sin(angle)*11))
	# Traverse left arc bottom->top, right arc top->bottom, joining 50 m straights.
	ring.append(ring[0])
	_ribbon(ring,4.4,SOIL_LIGHT)
	for delta in [-1.4,1.4]:
		var line: Array[Vector3]=[]
		for side in [-1,1]:
			for i in 33:
				var angle:=(-PI*.5 if side==1 else PI*.5)+PI*i/32.0
				line.append(p+Vector3(side*25+cos(angle)*(11+delta),.065,sin(angle)*(11+delta)))
		line.append(line[0]); _ribbon(line,.08,CREAM)
	for i in 6:
		var q:=p+Vector3(-25+i*10,.08,11)
		_box(q,Vector3(.15,.025,4.2),CREAM)
	_barn(p+Vector3(41,0,-15),Vector3(7,3.4,6))
	_feed_rack(p+Vector3(37,0,-7),3)
	_bench(p+Vector3(0,0,20))
	for x in [5,75]:
		_fence(Vector3(x,8,-146),Vector3(x+12,8,-146),WOOD)
	for q in [Vector3(85,8,-100),Vector3(85,8,-140),Vector3(-3,8,-100)]: _tree(q,1.2)
	_ribbon([Vector3(18,8.035,-90),Vector3(20,8.035,-102)],3.2,PATH)

func _chase_dressing() -> void:
	_district="FarmWorkingYard"
	_barn(Vector3(-59,2,-174),Vector3(8,3.3,7))
	# Off-centre stacks constrict alternating sides, leaving a clear running line.
	for p in [Vector3(-57,4,-154),Vector3(-76,3.3,-176),Vector3(-46,2,-201)]:
		var size:=Vector3(3,1.3,2.4) if p.x==-57 else Vector3(2.4,1.3,3)
		_box(p+Vector3.UP*.65,size,STRAW)
		_box(p+Vector3.UP*1.32,Vector3(.15,.07,size.z+.04),WOOD)
		_collider("ChaseHayStack",p+Vector3.UP*.65,size)
	# Closed gateway is the very end of the obstacle course.
	_district="StoneGatewayAndCableStation"
	for sign_x in [-1,1]:
		var a:=L.GATE+Vector3(sign_x*2.5,0,0)
		var b:=L.GATE+Vector3(sign_x*9,0,0)
		_stone_wall(a,b,2,.7)
		_collider("GateWall",(a+b)*.5+Vector3.UP,Vector3(6.5,2,.7))
	for x in [-2.65,2.65]:
		_box(L.GATE+Vector3(x,1.35,0),Vector3(.85,2.7,.85),STONE_LIGHT)
	# Fence the court edges: no route around the locked gate.
	for x in [-8.5,8.5]: _edge_wall(L.GATE+Vector3(x,0,0),L.GATE+Vector3(x,0,9),true)

func _station() -> void:
	_district="StoneGatewayAndCableStation"
	for i in 19: _box(L.STATION+Vector3(0,.06,5-i*.5),Vector3(5,.12,.46),WOOD_LIGHT)
	for x in [-2.8,2.8]: _fence(L.STATION+Vector3(x,0,1),L.STATION+Vector3(x,0,-4),WOOD_DARK)
	for x in [-2,2]: _box(L.STATION+Vector3(x,2.15,5),Vector3(.25,4.3,.25),WOOD_DARK)
	_box(L.STATION+Vector3(0,4.3,5),Vector3(4.4,.22,.28),WOOD_DARK)
	var start:=L.STATION+Vector3(0,4.1,0)
	_beam(start-L.TRAVEL*.6,start+L.TRAVEL*1.5,.055,.055,IRON)
	_district="GoldenWilderness"
	_patch(L.STATION+Vector3(15,-10,-48),Vector2(65,35),STRAW,32,.05)
	for i in 800:
		var q:=L.STATION+Vector3(_rng.randf_range(-40,65),-9.9,_rng.randf_range(-70,-27))
		_tuft(q,1.1,STRAW.lightened(.08))

func _meadow_lanes() -> void:
	_district="Ground_MeadowLanes"
	for lane in [
		[Vector3(30,24.04,55),Vector3(46,24.04,55),Vector3(56,24.04,38),Vector3(72,24.04,20)],
		[Vector3(50,24.04,48),Vector3(46,24.04,40),Vector3(43,24.04,37)],
		[Vector3(-40,16.04,-22),Vector3(-40,16.04,-32),Vector3(-38,16.04,-53),Vector3(-66,16.04,-62)],
		[Vector3(-39,16.04,-38),Vector3(-49,16.04,-41.5)],
		[Vector3(20,8.04,-102),Vector3(30,8.04,-110),Vector3(10,8.04,-120),Vector3(-6,8.04,-135)]
	]:
		var points: Array[Vector3]=[]
		points.assign(lane)
		_ribbon(points,2.2,PATH)
	_district="MeadowDetails"
	_feed_rack(Vector3(39,24,32),2.6)
	_bucket(Vector3(38,24,33))
	_patch(Vector3(-48,16.05,-41.5),Vector2(2.3,2),MEADOW.lightened(.06))
	for p in [Vector3(78,24,55),Vector3(-70,16,-30),Vector3(-10,16,-30),Vector3(47,8,-143)]:
		_tree(p,1.1)
		_flowers(p+Vector3(2,.04,0),12)

func _landmarks() -> void:
	_district="ValleyAndHorizon"
	for i in 26:
		var p:=Vector3(-140+(i%2)*300,-24,130-i*18)
		_boulder(p,Vector3(65,45,40),Color("9BA7A2"),i)
	# Sight breaks after the gate, and orchard clusters on each terrace.
	_district="OrchardsAndWildEdges"
	for id in ["escape","woodland","summit"]:
		var route:=L.path(id)
		for i in range(1,route.size()-1):
			var normal:=(route[i+1]-route[i]).normalized().cross(Vector3.UP)
			for sign_x in [-1,1]:
				var q: Vector3=route[i]+normal*sign_x*5.5
				if L.closest_on_path(q,route).distance<4.8: continue
				_tree(q,1.15)
				_collider("WoodlandTrunk",q+Vector3.UP,Vector3(.5,2,.5))
