extends Node3D
## Geometry only: gameplay dimensions and interaction anchors stay stable when art arrives.

signal chase_entered

const SPAWN := Vector3(0, 0.1, 18)
const WALL := Color(0.54, 0.58, 0.60)
const WHITE := Color(0.86, 0.88, 0.87)
const INK := Color(0.16, 0.22, 0.25)
const ACCENT := Color(0.95, 0.72, 0.32)

var _gate: StaticBody3D
var _pigpen_gate: StaticBody3D
var _cabin: Node3D
var _npcs: Dictionary = {}
var _npc_origins: Dictionary = {}
var _npc_tweens: Dictionary = {}
var _gate_label: Label3D

func _ready() -> void:
	_build_ground()
	_build_boundaries()
	_build_exploration()
	_build_chase()
	_build_exit()

func get_spawn_position() -> Vector3:
	return to_global(SPAWN)

func set_gate_open(open: bool) -> void:
	_set_barrier(_gate, open)
	if is_instance_valid(_gate_label):
		_gate_label.text = "铁门已开 / OPEN" if open else "铁门 / LOCKED"

func set_pigpen_open(open: bool) -> void:
	_set_barrier(_pigpen_gate, open)

func set_npc_completed(id: String) -> void:
	if not _npcs.has(id):
		return
	if _npc_tweens.has(id) and is_instance_valid(_npc_tweens[id]):
		_npc_tweens[id].kill()
	var targets := {"ox": Vector3(-6.8, 0, 6), "sheep": Vector3(6.4, 0, 4), "horse": Vector3(-6.6, 0, -1)}
	if targets.has(id):
		var tween := create_tween()
		tween.tween_property(_npcs[id], "position", targets[id], 0.8)
		_npc_tweens[id] = tween
	var label := _npcs[id].get_node_or_null("NameLabel") as Label3D
	if label:
		var names := {"ox": "老牛 · 饮水", "sheep": "小羊 · 晒太阳", "horse": "追风 · 嚼野草"}
		label.text = names.get(id, id)

func get_cablecar() -> Node3D:
	return _cabin

func reset_world() -> void:
	for tween in _npc_tweens.values():
		if is_instance_valid(tween):
			tween.kill()
	_npc_tweens.clear()
	for id in _npc_origins:
		_npcs[id].position = _npc_origins[id]
	var labels := {"ox": "老牛 / OX", "sheep": "小羊 / SHEEP", "horse": "追风 / HORSE"}
	for id in labels:
		_npcs[id].get_node("NameLabel").text = labels[id]
	set_gate_open(false)
	set_pigpen_open(false)
	_cabin.position = Vector3(0, 0, -34)

func _build_ground() -> void:
	_box(self, "Ground", Vector3(20, 0.5, 60), Vector3(0, -0.25, -7), Color(0.70, 0.74, 0.70), true)
	_box(self, "PigpenZone", Vector3(19.8, 0.03, 10), Vector3(0, 0.015, 18), Color(0.79, 0.77, 0.70))
	_box(self, "ChaseZone", Vector3(19.8, 0.03, 18), Vector3(0, 0.015, -14), Color(0.66, 0.69, 0.68))
	_box(self, "ExitZone", Vector3(19.8, 0.03, 11), Vector3(0, 0.015, -31.5), Color(0.76, 0.79, 0.77))
	# The center route stays clear; contrast marks progression without requiring detailed art.
	for z in range(-34, 22, 3):
		_box(self, "Route_%d" % z, Vector3(0.16, 0.025, 0.7), Vector3(0, 0.045, z), Color(0.87, 0.89, 0.83))
	_label(self, "StartTitle", "01  山顶猪圈\nPIGPEN", Vector3(0, 2.1, 21), 44)
	_label(self, "ExploreTitle", "02  农场 / FARM", Vector3(0, 2.4, 10), 38)

func _build_boundaries() -> void:
	# High collision boundaries with low visible rails: no falling or camera occlusion.
	_boundary("WestBoundary", Vector3(-10.25, 0, -7), Vector3(0.5, 5, 60.5))
	_boundary("EastBoundary", Vector3(10.25, 0, -7), Vector3(0.5, 5, 60.5))
	_boundary("StartBoundary", Vector3(0, 0, 23.25), Vector3(20.5, 5, 0.5))
	_boundary("EndBoundary", Vector3(0, 0, -37.25), Vector3(20.5, 5, 0.5))
	_box(self, "PigpenLeft", Vector3(7.8, 0.9, 0.45), Vector3(-6.1, 0.45, 13), WALL, true)
	_box(self, "PigpenRight", Vector3(7.8, 0.9, 0.45), Vector3(6.1, 0.45, 13), WALL, true)
	_pigpen_gate = _box(self, "PigpenGate", Vector3(4.4, 1.2, 0.45), Vector3(0, 0.6, 13), ACCENT, true) as StaticBody3D
	_label(self, "PigpenGateLabel", "出口 / EXIT", Vector3(0, 1.6, 13), 28)

func _build_exploration() -> void:
	_npc("goat", "老岩羊 / GOAT", Vector3(-3, 0, 18), Color(0.68, 0.70, 0.69), 1.4)
	_npc("ox", "老牛 / OX", Vector3(-4, 0, 8), Color(0.58, 0.60, 0.58), 1.5)
	_npc("sheep", "小羊 / SHEEP", Vector3(4, 0, 5), WHITE, 1.05)
	_npc("horse", "追风 / HORSE", Vector3(-4, 0, 0), Color(0.39, 0.45, 0.48), 1.6)
	_box(self, "WaterTrough", Vector3(1.6, 0.35, 2.4), Vector3(-8.2, 0.175, 6), Color(0.42, 0.62, 0.68), true)
	_box(self, "SunPatch", Vector3(3, 0.025, 3), Vector3(6.4, 0.05, 4), Color(0.88, 0.84, 0.65))
	_box(self, "HorseGrass", Vector3(3, 0.04, 1.8), Vector3(-6.6, 0.05, -1), Color(0.56, 0.66, 0.49))
	_box(self, "Plow", Vector3(0.8, 0.4, 1.6), Vector3(-6.4, 0.2, 9.8), WALL, true)
	var board := _box(self, "RecordBoard", Vector3(1.9, 1.4, 0.28), Vector3(3.2, 0.7, -0.5), Color(0.81, 0.83, 0.79), true) as StaticBody3D
	_interactable(board, "record_board")
	_label(board, "BoardText", "41 秒 → 35 秒\n纪录榜 / RECORD", Vector3(0, 1.25, 0), 30)
	_label(self, "ChaseWarning", "03  追逐区 / CHASE\n向前跑到铁门", Vector3(0, 2, -4.1), 36)

func _build_chase() -> void:
	_box(self, "ChaseStartStripe", Vector3(20, 0.025, 0.25), Vector3(0, 0.055, -5), ACCENT)
	_box(self, "ChaseExitStripe", Vector3(20, 0.025, 0.25), Vector3(0, 0.055, -23), Color(0.46, 0.70, 0.59))
	# Obstacles remain outside a generous 6 m center lane. No required skill or narrow gap.
	_box(self, "HayBlockLeft", Vector3(2.5, 0.9, 2.5), Vector3(-5.5, 0.45, -11), Color(0.74, 0.71, 0.59), true)
	_box(self, "CrateRight", Vector3(2.2, 0.9, 2.2), Vector3(5.3, 0.45, -17), Color(0.63, 0.62, 0.56), true)
	var trigger := Area3D.new()
	trigger.name = "ChaseStart"
	trigger.position = Vector3(0, 1, -5.4)
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	add_child(trigger)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 2, 0.8)
	collider.shape = shape
	trigger.add_child(collider)
	trigger.body_entered.connect(_on_chase_entered)

func _build_exit() -> void:
	_box(self, "GateWallLeft", Vector3(7.5, 1, 0.6), Vector3(-6.25, 0.5, -25), WALL, true)
	_box(self, "GateWallRight", Vector3(7.5, 1, 0.6), Vector3(6.25, 0.5, -25), WALL, true)
	_gate = _box(self, "Gate", Vector3(5, 1.8, 0.6), Vector3(0, 0.9, -25), Color(0.38, 0.46, 0.50), true) as StaticBody3D
	_gate_label = _label(self, "GateLabel", "铁门 / LOCKED", Vector3(0, 2.4, -25), 38)
	_npc("farmer", "农场主 / FARMER", Vector3(3.4, 0, -23.8), Color(0.53, 0.59, 0.64), 1.6)
	_label(self, "CablecarTitle", "04  索道 / CABLE CAR", Vector3(0, 2.6, -32), 38)
	var lever := _box(self, "CableCarLever", Vector3(0.5, 0.8, 0.5), Vector3(-1.5, 0.4, -32), ACCENT, true) as StaticBody3D
	_interactable(lever, "cablecar")
	_label(lever, "LeverLabel", "插入铜插销\nE  启动", Vector3(0, 1.2, 0), 28)
	_cabin = Node3D.new()
	_cabin.name = "CableCarCabin"
	_cabin.position = Vector3(0, 0, -34)
	add_child(_cabin)
	_box(_cabin, "Deck", Vector3(3.2, 0.2, 2.6), Vector3(0, 0.12, 0), Color(0.65, 0.67, 0.64))
	for x in [-1.5, 1.5]:
		_box(_cabin, "Rail_%s" % str(x), Vector3(0.12, 0.8, 2.6), Vector3(x, 0.6, 0), WALL)
	# Open frame instead of an opaque roof, so the isometric camera can see the passenger.
	_box(_cabin, "RoofFront", Vector3(3.3, 0.12, 0.12), Vector3(0, 2.25, 1.3), Color(0.75, 0.78, 0.76))
	_box(_cabin, "RoofBack", Vector3(3.3, 0.12, 0.12), Vector3(0, 2.25, -1.3), Color(0.75, 0.78, 0.76))
	for x in [-1.4, 1.4]:
		_box(_cabin, "Post_%s" % str(x), Vector3(0.10, 2.1, 0.10), Vector3(x, 1.15, -1), WALL)
	_box(self, "CableLine", Vector3(0.06, 0.06, 14), Vector3(0, 3.4, -38), INK)
	# Beyond the protected play area, a dark box communicates the cliff without a lethal hole.
	_box(self, "CliffBackdrop", Vector3(24, 3, 10), Vector3(0, -1.6, -42.5), Color(0.30, 0.38, 0.43))

func _npc(id: String, title: String, pos: Vector3, color: Color, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "NPC_" + id
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_interactable(body, id)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = height
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = height * 0.5
	body.add_child(collider)
	var mesh := MeshInstance3D.new()
	mesh.name = "VisualMesh"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = height
	mesh.mesh = capsule
	mesh.material_override = _material(color)
	mesh.position.y = height * 0.5
	body.add_child(mesh)
	_label(body, "NameLabel", title, Vector3(0, height + 0.35, 0), 30)
	_npcs[id] = body
	_npc_origins[id] = pos

func _interactable(body: StaticBody3D, id: String) -> void:
	body.add_to_group("interactable")
	body.set_meta("interaction_id", id)

func _boundary(node_name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)
	_box(body, "VisibleRail", Vector3(size.x, 0.45, size.z), Vector3(0, 0.225, 0), WALL)

func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color, solid: bool = false) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root = body
	else:
		root = Node3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)
	var mesh := MeshInstance3D.new()
	mesh.name = "VisualMesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	root.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root

func _label(parent: Node3D, node_name: String, text: String, pos: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = Color(0.94, 0.96, 0.94)
	label.outline_modulate = INK
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)
	return label

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material

func _set_barrier(body: StaticBody3D, open: bool) -> void:
	if not is_instance_valid(body):
		return
	body.visible = not open
	body.set_deferred("collision_layer", 0 if open else 1)
	var collision := body.get_node("CollisionShape3D") as CollisionShape3D
	collision.set_deferred("disabled", open)

func _on_chase_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		chase_entered.emit()
