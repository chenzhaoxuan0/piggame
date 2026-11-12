class_name BoostPad
extends Area3D

signal boost_activated(player: Node3D)

const ASSETS = preload("res://scripts/art/asset_library.gd")

@export var boost_speed: float = 18.0
@export var boost_duration: float = 1.6
@export var pad_size: Vector2 = Vector2(3.5, 3.0)
# Optional zone dressing (courtyard neon): the chevron boost plate model
# replaces the flat slab; the pulse tween keeps working on the pad node.
@export var lux_asset_id: String = ""

const COLOR_NEON_YELLOW := Color("FACC15")
const COLOR_NEON_ORANGE := Color("FB923C")

var is_active: bool = true
var pad_mesh: MeshInstance3D
var arrow_label: Label3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player
	_setup_collision()
	_setup_visual()
	body_entered.connect(_on_body_entered)

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "PadCol"
	var box := BoxShape3D.new()
	box.size = Vector3(pad_size.x, 0.4, pad_size.y)
	col.shape = box
	col.position.y = 0.2
	add_child(col)

func _setup_visual() -> void:
	pad_mesh = MeshInstance3D.new()
	pad_mesh.name = "PadMesh"
	var quad := BoxMesh.new()
	quad.size = Vector3(pad_size.x, 0.08, pad_size.y)
	pad_mesh.mesh = quad
	pad_mesh.position.y = 0.04

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_NEON_YELLOW
	mat.emission_enabled = true
	mat.emission = COLOR_NEON_YELLOW
	mat.emission_energy_multiplier = 1.8
	pad_mesh.material_override = mat
	add_child(pad_mesh)

	# Racing chevron arrows
	arrow_label = Label3D.new()
	arrow_label.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	arrow_label.name = "Chevron"
	arrow_label.text = "▲ ▲ ▲"
	arrow_label.font_size = 46
	arrow_label.rotation.x = -deg_to_rad(90.0)
	arrow_label.position = Vector3(0, 0.09, 0)
	arrow_label.modulate = COLOR_NEON_ORANGE
	arrow_label.outline_modulate = Color("1E293B")
	arrow_label.outline_size = 6
	add_child(arrow_label)

	# Zone dressing: the neon chevron plate replaces the flat slab (the model
	# carries its own printed arrows, so the Label3D chevron hides).
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			pad_mesh.mesh = null
			pad_mesh.add_child(lux)
			arrow_label.visible = false

func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return

	# Apply forward racing boost
	var forward_dir := -global_transform.basis.z.normalized()
	if body is CharacterBody3D:
		var cb := body as CharacterBody3D
		cb.velocity += forward_dir * boost_speed

	# Visual pulse
	var tween := create_tween()
	tween.tween_property(pad_mesh, "scale", Vector3(1.15, 1.0, 1.15), 0.1)
	tween.tween_property(pad_mesh, "scale", Vector3.ONE, 0.15)

	boost_activated.emit(body)
