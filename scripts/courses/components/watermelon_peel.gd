class_name WatermelonPeel
extends Area3D

signal peel_slipped(victim: Node3D)
signal peel_collected(player: Node3D)

const COLOR_RIND := Color("15803D") # Green outer rind
const COLOR_FLESH := Color("EF4444") # Red inner flesh

var is_placed_on_track: bool = true
var is_slipping: bool = false
var peel_mesh: MeshInstance3D

func _ready() -> void:
	collision_mask = 2 | 1 # Player and Dogs
	_setup_collision()
	_setup_visual()
	body_entered.connect(_on_body_entered)

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "PeelCol"
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.6, 1.2)
	col.shape = box
	col.position.y = 0.3
	add_child(col)

func _setup_visual() -> void:
	peel_mesh = MeshInstance3D.new()
	peel_mesh.name = "PeelMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.6
	cyl.height = 0.15
	peel_mesh.mesh = cyl
	peel_mesh.position.y = 0.08

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_RIND
	mat.roughness = 0.4
	peel_mesh.material_override = mat
	add_child(peel_mesh)

	var label := Label3D.new()
	label.name = "PeelLabel"
	label.text = "西瓜皮"
	label.font_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("FEF08A")
	label.outline_modulate = Color("1E293B")
	label.outline_size = 4
	label.position = Vector3(0, 0.6, 0)
	add_child(label)

func _on_body_entered(body: Node3D) -> void:
	if is_slipping:
		return

	# If dog steps on it -> slip and spin!
	if body.is_in_group("dogs") or body.name.to_lower().contains("dog"):
		trigger_slip(body)
	elif body.is_in_group("player") or body.name.to_lower().contains("pig"):
		peel_collected.emit(body)

func trigger_slip(victim: Node3D) -> void:
	if is_slipping:
		return
	is_slipping = true

	# Spin 3 full rotations
	var tween := victim.create_tween()
	tween.tween_property(victim, "rotation:y", victim.rotation.y + TAU * 3.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if victim.has_method("set_stunned"):
		victim.set_stunned(2.5)
	elif "phase" in victim:
		victim.phase = "stun"

	peel_slipped.emit(victim)

	# Peel vanishes with pop
	var peel_tween := create_tween()
	peel_tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	peel_tween.tween_callback(queue_free)
