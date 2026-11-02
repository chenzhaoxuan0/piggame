extends RefCounted
## Authored clusters tell each district's farming activity; seeded verge planting
## fills the connecting routes without placing objects in the movement corridor.
const L = preload("res://scripts/levels/farm_layout.gd")
const SURFACE = preload("res://scripts/art/mountain_surface.gd")
var e: Node3D
var rng:=RandomNumberGenerator.new()

func _put(id: String,p: Vector3,s: float=1,yaw: float=0) -> void:
	e._dressing.place("ENV_09_"+id,p,Vector3.ONE*s,yaw)
	var footprints: Dictionary={"BARREL":Vector3(.72,.92,.72),"WHEELBARROW":Vector3(.7,.65,1.4),"CART":Vector3(1.6,1,2),"PUMP":Vector3(.3,1.1,.3),"WOOL":Vector3(1,.5,.7),"HURDLE":Vector3(.35,1.4,2.4),"RAIL":Vector3(1.7,1.1,.22),"WALL":Vector3(3.4,1,.44)}
	if footprints.has(id):
		var size: Vector3=footprints[id]*s
		var basis:=Basis(Vector3.UP,yaw)
		var corners: Array[Vector3]=[]
		for c in [Vector3(-.5,1,-.5),Vector3(.5,1,-.5),Vector3(.5,1,.5),Vector3(-.5,1,.5)]: corners.append(p+basis*(c*size))
		e._convex("DressingCollision_"+id,corners,size.y)

func _root(id: String,p: Vector3,s: float=1,yaw: float=0) -> void:
	p.y=SURFACE.mesh_height_at(p)-.06
	_put(id,p,s,yaw)

func _cluster(p: Vector3,kind: int) -> void:
	_root("ROCK",p,.55+rng.randf()*.55,rng.randf()*TAU)
	_root("HAWTHORN",p+Vector3(1.3,0,-.6),.7+rng.randf()*.3,rng.randf()*TAU)
	for i in 3:
		var q:=p+Vector3(sin(i*2.2)*1.4,0,cos(i*2.2)*1.1)
		_root("FERN" if kind!=1 else "REEDS",q,.6+rng.randf()*.35,i)

func build(environment: Node3D) -> void:
	e=environment
	rng.seed=90112
	_verges()
	_summit()
	_fields()
	_sheep()
	_horses()
	_workyard()
	_station()

func _verges() -> void:
	for id in L.ROUTES:
		var route:=L.path(id)
		for i in route.size()-1:
			var a:=route[i]
			var b:=route[i+1]
			var tangent:=(b-a).normalized()
			var side:=tangent.cross(Vector3.UP).normalized()
			var count:=maxi(1,floori(a.distance_to(b)/7))
			for j in count:
				var p:=a.lerp(b,(j+.5)/count)
				for sign_side in [-1,1]:
					var q: Vector3=p+side*sign_side*(5.8+rng.randf()*1.6)
					# Bends and adjacent switchbacks retain their full clearance.
					if _near_lane(q,4.5): continue
					_cluster(q,1 if id=="creek" else 0)
					if (i+j+sign_side)%3==0:
						var tree: String="PINE" if id in ["summit","escape"] else ("BIRCH" if id=="creek" else "OAK")
						_root(tree,q+side*sign_side*2.7,.65+rng.randf()*.3,rng.randf()*TAU)
					if id=="woodland" and j==0: _root("STUMP",q+side,1.2,i)
	# Distant groves blend ridge lines into the surrounding landscape.
	for i in 82:
		var q:=Vector3(rng.randf_range(-112,112),0,rng.randf_range(-305,125))
		if _near_lane(q,13): continue
		var in_terrace:=false
		for t in L.TERRACES:
			if absf(q.x-t.center.x)<t.half.x+3 and absf(q.z-t.center.z)<t.half.y+3: in_terrace=true
		if in_terrace: continue
		_root(["OAK","BIRCH","PINE"][i%3],q,.8+rng.randf()*.55,i*1.4)
		if i%2==0: _cluster(q,0)
	# Sign boards remain blank; the existing localized trail captions give directions.
	for p in [Vector3(2,32,89),Vector3(-50,25,101),Vector3(54,22,2),Vector3(72,24,23),Vector3(-63,16,-59),Vector3(-4,8,-134),Vector3(-79,2,-237)]:
		_put("SIGN",p,.85,-.3)

func _near_lane(p: Vector3,clearance: float) -> bool:
	for id in L.ROUTES:
		var route:=L.path(id)
		for i in route.size()-1:
			var a:=Vector2(route[i].x,route[i].z)
			var b:=Vector2(route[i+1].x,route[i+1].z)
			var q:=Vector2(p.x,p.z)
			var t:=clampf((q-a).dot(b-a)/(b-a).length_squared(),0,1)
			if q.distance_to(a.lerp(b,t))<clearance: return true
	return false

func _summit() -> void:
	e._district="SummitFarmLife"
	_put("BARREL",Vector3(-8.8,32,101),.85)
	_put("STUMP",Vector3(7.5,32,106),1.1,.4)
	_put("WHEELBARROW",Vector3(-7.4,32,104),.9,-.8)
	for p in [Vector3(-10,32,108),Vector3(9,32,109),Vector3(10,32,94)]:
		_put("HAWTHORN",p,.7,p.x)
	# Collapsed timber and old slates at the abandoned shelter, off the exit path.
	for i in 5:
		e._beam(Vector3(-10+i*.25,32.12,95),Vector3(-9+i*.25,32.23,97),.14,.13,e.WOOD_DARK)
	for i in 4: e._stone_block(Vector3(-9+i*.35,32.07,98.3),Vector3(.6,.12,.5),e.ROOF,i*.3)

func _fields() -> void:
	e._district="HarvestAndIrrigation"
	_put("WHEELBARROW",Vector3(40,24,43),1,1.4)
	_put("PUMP",Vector3(38,24,30.8),1,-.4)
	_put("BARREL",Vector3(36.8,24,30),1)
	_put("CART",Vector3(23,24,29),1,-.7)
	for p in [Vector3(67,24,35),Vector3(77,24,44),Vector3(84,24,51)]:
		e._dressing.place("ENV_06_CRATE",p,Vector3.ONE*.65,.4)
		_put("BARREL",p+Vector3(1.2,0,0),.65)
	# Raised vegetable beds beyond the story lane, with broad readable crop heads.
	for row in 4:
		var p:=Vector3(55+row*3,24.09,29)
		e._patch(p,Vector2(1.1,3.5),e.SOIL,12,.02)
		for j in 6:
			var q:=p+Vector3(0,.15,-2.8+j*1.1)
			e._boulder(q,Vector3(.38,.34,.4),e.LEAF_LIGHT,j)
			e._tuft(q+Vector3.UP*.1,.35,e.LEAF)
	for i in 5:
		_put("REEDS",Vector3(18+i*3,24,33.3),.65,i)
	for i in 4:
		_put("WALL",Vector3(55+i*5,24,57),.85)
		_put("HAWTHORN",Vector3(57+i*5,24,57.5),.75,i)

func _sheep() -> void:
	e._district="ShearingAndWetMeadow"
	for p in [Vector3(-58,16,-39),Vector3(-59,16,-43),Vector3(-54,16,-43)]: _put("WOOL",p,1.1,p.x)
	_put("BARREL",Vector3(-61,16,-37),.85)
	_put("CART",Vector3(-62,16,-30),.85,1.2)
	# Grazing paddock uses airy rails instead of a continuous green wall.
	for i in 5:
		_put("RAIL",Vector3(-37+i*5,16,-56),.9)
		if i%2==0: _put("HAWTHORN",Vector3(-35+i*5,16,-57),.9,i)
	for i in 14:
		var angle:=i*TAU/14
		var p:=Vector3(-14+cos(angle)*7.6,16,-45+sin(angle)*6.6)
		_put("REEDS",p,.65+(i%3)*.12,i)
	for p in [Vector3(-24,16,-37),Vector3(-5,16,-49),Vector3(-22,16,-53)]: _root("BIRCH",p,.85,p.x)
	for p in [Vector3(-70,16,-47),Vector3(-63,16,-57),Vector3(-7,16,-30)]: _cluster(p,0)

func _horses() -> void:
	e._district="EquestrianTraining"
	# Training is inside the oval; both 50 m straights and companion approach stay open.
	for i in 3:
		_put("HURDLE",Vector3(42+i*10,8,-123),.95,PI*.5)
		e._patch(Vector3(42+i*10,8.04,-123),Vector2(3.0,1.8),e.PATH.darkened(.07),16,.06)
		for sign_side in [-1,1]:
			e._box(Vector3(42+i*10+sign_side*2.5,8.22,-123),Vector3(.35,.44,.35),e.CREAM)
	_put("PUMP",Vector3(77,8,-129),1)
	_put("BARREL",Vector3(78.2,8,-128),1)
	_put("WHEELBARROW",Vector3(78,8,-133),1,.5)
	for i in 9:
		_put("RAIL",Vector3(12+i*7.5,8,-141),1.05)
		if i%3==1: _put("HAWTHORN",Vector3(14+i*7.5,8,-142),1,i)
	for p in [Vector3(52,8,-98),Vector3(62,8,-99),Vector3(72,8,-98)]:
		_root("OAK",p,.75,p.x)
		_put("ROCK",p+Vector3(2,0,0),.6)

func _workyard() -> void:
	e._district="WorkingFarmCourts"
	_put("CART",Vector3(-62,2,-169),.95,.9)
	_put("BARREL",Vector3(-55,2,-170),1.0)
	_put("WHEELBARROW",Vector3(-55,2,-177),1,-.7)
	for p in [Vector3(-57,2,-168),Vector3(-58.3,2,-168.4)]:
		e._dressing.place("ENV_06_CRATE",p,Vector3.ONE*.85,.2)
	# Existing obstacle collisions keep their dimensions; round bales decorate only
	# the separate work court, never conceal the actual avoidance corridor.
	for i in 3: e._dressing.place("ENV_06_HAY",Vector3(-64+i*1.4,2,-179),Vector3.ONE,0)
	for p in [Vector3(-86,2,-224),Vector3(-76,2,-220)]:
		_put("BARREL",p,.85)
		_put("HAWTHORN",p+Vector3(-1.4,0,1.2),.8)

func _station() -> void:
	e._district="CableStationSupplies"
	_put("BARREL",Vector3(-18,0,-279),.9)
	_put("CART",Vector3(-6,0,-276),.8,-.9)
	_put("SIGN",Vector3(-16,0,-272),1,-.5)
	for i in 3: e._dressing.place("ENV_06_CRATE",Vector3(-18,0,-281-i*.9),Vector3.ONE*.65,.1)
	for p in [Vector3(-19,0,-284),Vector3(-5,0,-284)]:
		_root("PINE",p,.75,p.x)
		_cluster(p+Vector3(1,0,1),0)
