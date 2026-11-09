extends CourseTrap
class_name DoorDashGate

@export var breakable_index: int = 1 # 0: Left, 1: Center, 2: Right
@export var gate_width: float = 7.6
@export var gate_height: float = 2.8
@export var door_colors: Array[Color] = [Color("E74C3C"), Color("F39C12"), Color("3498DB")] # Red, Orange, Blue

var _doors: Array[Node3D] = []
var _is_broken := false

func _ready() -> void:
	_build_frame()
	_build_doors()

func _build_frame() -> void:
	var frame := StaticBody3D.new()
	frame.collision_layer = 1
	frame.collision_mask = 0

	var half_w := gate_width * 0.5
	# Left post
	_add_box_col(frame, Vector3(0.4, gate_height, 0.4), Vector3(-half_w, gate_height * 0.5, 0), Color("4A4A4A"))
	# Right post
	_add_box_col(frame, Vector3(0.4, gate_height, 0.4), Vector3(half_w, gate_height * 0.5, 0), Color("4A4A4A"))
	# Top beam
	_add_box_col(frame, Vector3(gate_width + 0.4, 0.4, 0.5), Vector3(0, gate_height + 0.2, 0), Color("F1C40F"))
	# Dividers
	var lane_w := gate_width / 3.0
	_add_box_col(frame, Vector3(0.2, gate_height, 0.3), Vector3(-lane_w * 0.5, gate_height * 0.5, 0), Color("5D6D7E"))
	_add_box_col(frame, Vector3(0.2, gate_height, 0.3), Vector3(lane_w * 0.5, gate_height * 0.5, 0), Color("5D6D7E"))

	add_child(frame)

	# Banner above gate
	var banner := Label3D.new()
	banner.text = "★ 疯狂三选一 · 哪扇能撞开？ ★"
	banner.font_size = 22
	banner.position = Vector3(0, gate_height + 0.8, 0)
	banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner.modulate = Color("FFF275")
	banner.outline_modulate = Color("3A3630")
	banner.outline_size = 6
	add_child(banner)

func _build_doors() -> void:
	var lane_w := gate_width / 3.0
	var door_w := lane_w - 0.25
	var door_h := gate_height - 0.1
	var centers := [-lane_w, 0.0, lane_w]

	for i in 3:
		var center_x: float = centers[i]
		var is_breakable := (i == breakable_index)
		var color: Color = door_colors[i % door_colors.size()]
		var door_root := Node3D.new()
		door_root.name = "Door_%d" % i
		door_root.position = Vector3(center_x, 0, 0)
		add_child(door_root)
		_doors.append(door_root)

		# Door panel mesh
		var panel := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(door_w, door_h, 0.2)
		panel.mesh = box
		panel.position.y = door_h * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.7
		panel.material_override = mat
		panel.name = "Panel"
		door_root.add_child(panel)

		# Door symbol / markings
		var sym := Label3D.new()
		sym.text = "?" if not is_breakable else "!"
		sym.font_size = 48
		sym.position = Vector3(0, door_h * 0.55, 0.12)
		sym.modulate = Color.WHITE
		door_root.add_child(sym)

		if not is_breakable:
			# Solid fake door
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var cshape := CollisionShape3D.new()
			var cbox := BoxShape3D.new()
			cbox.size = Vector3(door_w, door_h, 0.2)
			cshape.shape = cbox
			cshape.position.y = door_h * 0.5
			body.add_child(cshape)
			door_root.add_child(body)

			# Bonk trigger area
			var bonk_area := Area3D.new()
			bonk_area.collision_layer = 0
			bonk_area.collision_mask = 2 | 4
			var bshape := CollisionShape3D.new()
			var bbox := BoxShape3D.new()
			bbox.size = Vector3(door_w * 0.9, door_h, 0.6)
			bshape.shape = bbox
			bshape.position = Vector3(0, door_h * 0.5, 0.25)
			bonk_area.add_child(bshape)
			bonk_area.body_entered.connect(_on_fake_door_hit.bind(door_root))
			door_root.add_child(bonk_area)
		else:
			# Breakable door: charges through
			var break_area := Area3D.new()
			break_area.collision_layer = 0
			break_area.collision_mask = 2 | 4
			var brk_shape := CollisionShape3D.new()
			var brk_box := BoxShape3D.new()
			brk_box.size = Vector3(door_w * 0.95, door_h, 0.8)
			brk_shape.shape = brk_box
			brk_shape.position = Vector3(0, door_h * 0.5, 0.2)
			break_area.add_child(brk_shape)
			break_area.body_entered.connect(_on_breakable_door_hit.bind(door_root))
			door_root.add_child(break_area)

func _on_fake_door_hit(body: Node3D, door_root: Node3D) -> void:
	if _is_player(body):
		var panel := door_root.get_node_or_null("Panel")
		if panel:
			var tw := create_tween()
			tw.tween_property(panel, "position:z", -0.08, 0.04)
			tw.tween_property(panel, "position:z", 0.08, 0.04)
			tw.tween_property(panel, "position:z", 0.0, 0.04)
		_knock(body, Vector3(0, 1.8, 4.0), 0.45)
		_meme(telegraph_meme_id if not telegraph_meme_id.is_empty() else "door_bonk", body.global_position)
	elif _is_dog(body):
		_hit_dog(body, 1.5, Vector3(0, 1.0, 3.5))

func _on_breakable_door_hit(body: Node3D, door_root: Node3D) -> void:
	if _is_broken:
		return
	_is_broken = true
	var panel := door_root.get_node_or_null("Panel")
	if panel:
		var tw := create_tween()
		tw.tween_property(door_root, "rotation:x", -PI * 0.5, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(door_root, "position:y", -0.05, 0.25)
	if _is_player(body):
		_meme(meme_id if not meme_id.is_empty() else "door_dash_break", body.global_position)

func _add_box_col(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	parent.add_child(shape)

	var mesh := MeshInstance3D.new()
	var mbox := BoxMesh.new()
	mbox.size = size
	mesh.mesh = mbox
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	parent.add_child(mesh)
