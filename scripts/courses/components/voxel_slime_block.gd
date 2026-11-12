class_name VoxelSlimeBlock
extends Node3D

signal slime_bounced(block: VoxelSlimeBlock, body: Node3D)

@export var block_size: Vector3 = Vector3(2.0, 1.0, 2.0)
@export var bounce_velocity: float = 12.0
@export var forward_boost: float = 6.0
@export var cooldown: float = 0.4

const COLOR_SLIME_GREEN := Color("22C55E")
const COLOR_SLIME_INNER := Color("15803D")

var _cooldown_timer: float = 0.0
var _mesh_root: Node3D
var _outer_mesh: MeshInstance3D
var _inner_mesh: MeshInstance3D

func _ready() -> void:
	_setup_visual()
	_setup_collision()
	_setup_trigger()

func _setup_visual() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)

	# Translucent outer slime jelly
	_outer_mesh = MeshInstance3D.new()
	_outer_mesh.name = "OuterJelly"
	var outer_box := BoxMesh.new()
	outer_box.size = block_size
	_outer_mesh.mesh = outer_box
	_outer_mesh.position.y = block_size.y * 0.5

	var outer_mat := StandardMaterial3D.new()
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.albedo_color = Color("22C55ECC")
	outer_mat.roughness = 0.1
	outer_mat.emission_enabled = true
	outer_mat.emission = Color("4ADE80")
	outer_mat.emission_energy_multiplier = 0.4
	_outer_mesh.material_override = outer_mat
	_mesh_root.add_child(_outer_mesh)

	# Solid darker inner core
	_inner_mesh = MeshInstance3D.new()
	_inner_mesh.name = "InnerCore"
	var inner_box := BoxMesh.new()
	inner_box.size = block_size * 0.6
	_inner_mesh.mesh = inner_box
	_inner_mesh.position.y = block_size.y * 0.5

	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = COLOR_SLIME_INNER
	inner_mat.roughness = 0.4
	_inner_mesh.material_override = inner_mat
	_mesh_root.add_child(_inner_mesh)

	# Label above block
	var lbl := Label3D.new()
	lbl.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	lbl.name = "SlimeLabel"
	lbl.text = "【史莱姆弹跳块】\nBoing!"
	lbl.font_size = 18
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color("86EFAC")
	lbl.outline_modulate = Color("14532D")
	lbl.outline_size = 5
	lbl.position = Vector3(0, block_size.y + 0.6, 0)
	add_child(lbl)

func _setup_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "SlimeBody"
	body.collision_layer = 1
	body.collision_mask = 0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(block_size.x, block_size.y * 0.7, block_size.z)
	shape.shape = box
	shape.position.y = block_size.y * 0.35
	body.add_child(shape)
	add_child(body)

func _setup_trigger() -> void:
	var area := Area3D.new()
	area.name = "BounceArea"
	area.collision_layer = 0
	area.collision_mask = 2 | 4 # Player and Dog

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(block_size.x * 0.95, 0.4, block_size.z * 0.95)
	shape.shape = box
	shape.position.y = block_size.y + 0.1
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

	# Slime bounce impulse
	var forward_dir := -global_transform.basis.z.normalized()
	if forward_dir.length_squared() < 0.001:
		forward_dir = Vector3.FORWARD

	cb.velocity.y = bounce_velocity
	cb.velocity.x = forward_dir.x * forward_boost
	cb.velocity.z = forward_dir.z * forward_boost

	if cb.has_method("apply_knockback"):
		# Or if custom controller
		pass

	# Squash & stretch animation
	if is_instance_valid(_mesh_root):
		var tween := create_tween()
		tween.tween_property(_mesh_root, "scale", Vector3(1.4, 0.35, 1.4), 0.08)
		tween.tween_property(_mesh_root, "scale", Vector3(0.85, 1.4, 0.85), 0.15)
		tween.tween_property(_mesh_root, "scale", Vector3.ONE, 0.12)

	slime_bounced.emit(self, body)
