class_name NeonBumper
extends Node3D

signal bumper_hit(bumper: NeonBumper, body: Node3D)

@export var bumper_radius: float = 1.1
@export var bumper_height: float = 1.2
@export var repel_force: float = 16.0
@export var cooldown: float = 0.25

const COLOR_NEON_MAGENTA := Color("EC4899")
const COLOR_NEON_CYAN := Color("06B6D4")

var _cooldown_timer: float = 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

func _ready() -> void:
	_setup_visual()
	_setup_collision()
	_setup_trigger()

func _setup_visual() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "BumperMesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = bumper_radius
	cyl.bottom_radius = bumper_radius
	cyl.height = bumper_height
	_mesh.mesh = cyl
	_mesh.position.y = bumper_height * 0.5

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR_NEON_MAGENTA
	_mat.emission_enabled = true
	_mat.emission = COLOR_NEON_MAGENTA
	_mat.emission_energy_multiplier = 1.8
	_mesh.material_override = _mat
	add_child(_mesh)

	# Top cap ring
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = bumper_radius * 0.7
	tor.outer_radius = bumper_radius * 0.95
	ring.mesh = tor
	ring.position.y = bumper_height + 0.05
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = COLOR_NEON_CYAN
	r_mat.emission_enabled = true
	r_mat.emission = COLOR_NEON_CYAN
	r_mat.emission_energy_multiplier = 2.0
	ring.material_override = r_mat
	add_child(ring)

func _setup_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "BumperBody"
	body.collision_layer = 1
	body.collision_mask = 0

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = bumper_radius * 0.7
	cyl.height = bumper_height
	col.shape = cyl
	col.position.y = bumper_height * 0.5
	body.add_child(col)
	add_child(body)

func _setup_trigger() -> void:
	var area := Area3D.new()
	area.name = "BumperTrigger"
	area.collision_layer = 0
	area.collision_mask = 2 | 4 # Player and Dog

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = bumper_radius * 1.15
	cyl.height = bumper_height * 1.2
	shape.shape = cyl
	shape.position.y = bumper_height * 0.5
	area.add_child(shape)

	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func _on_body_entered(body: Node3D) -> void:
	if _cooldown_timer > 0.0:
		return
	if not (body is CharacterBody3D):
		return

	_cooldown_timer = cooldown
	var cb := body as CharacterBody3D

	# Calculate bounce direction radially outwards
	var repel_dir := (cb.global_position - global_position)
	repel_dir.y = 0.0
	if repel_dir.length_squared() < 0.01:
		repel_dir = -global_transform.basis.z
	repel_dir = repel_dir.normalized()

	cb.velocity = repel_dir * repel_force + Vector3(0, 3.5, 0)
	if body.has_method("stun"):
		body.stun(1.5)

	# Bumper pulse animation
	if is_instance_valid(_mesh):
		var tween := create_tween()
		tween.tween_property(_mesh, "scale", Vector3(1.3, 0.8, 1.3), 0.06)
		tween.tween_property(_mesh, "scale", Vector3.ONE, 0.12)

	# Pop up arcade score
	var score_lbl := Label3D.new()
	score_lbl.text = "🎯 BOING! +100"
	score_lbl.font_size = 22
	score_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	score_lbl.modulate = Color("38BDF8")
	score_lbl.outline_modulate = Color("0F172A")
	score_lbl.outline_size = 5
	score_lbl.position = Vector3(0, bumper_height + 0.8, 0)
	add_child(score_lbl)

	var lbl_tween := score_lbl.create_tween()
	lbl_tween.tween_property(score_lbl, "position:y", score_lbl.position.y + 0.8, 0.8)
	lbl_tween.tween_callback(score_lbl.queue_free)

	bumper_hit.emit(self, body)
