extends Area3D

# Non-lethal kart hazard: a mud puddle that drags the pig down to
# mud_speed_factor of its speed while inside. move_speed is multiplied on entry
# and divided back on exit (and in _exit_tree, so leaving the course mid-mud can
# never strand a slowed pig). Scaling by a factor instead of saving/restoring an
# absolute value keeps it order-independent with other speed effects such as
# the golden star. Golden-star racers plow through unaffected.
# (No class_name self-references, see race_timer.gd.)

signal mud_entered(body: Node3D)
signal mud_exited(body: Node3D)

const COLOR_MUD := Color("5C3D2E")
const COLOR_MUD_DARK := Color("3F2A1F")

@export var patch_size: Vector2 = Vector2(6.0, 5.0)
@export var mud_speed_factor: float = 0.5
# Recolor for other slow surfaces (e.g. the courtyard's sandy infield gravel trap).
@export var surface_color: Color = COLOR_MUD
@export var blob_color: Color = COLOR_MUD_DARK

var _slowed: Array[Node3D] = [] # bodies currently carrying this patch's slow factor

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player
	_setup_collision()
	_setup_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _exit_tree() -> void:
	for body in _slowed:
		_restore(body)
	_slowed.clear()

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "MudCol"
	var box := BoxShape3D.new()
	box.size = Vector3(patch_size.x, 0.8, patch_size.y)
	col.shape = box
	col.position.y = 0.4
	add_child(col)

func _setup_visual() -> void:
	var puddle := MeshInstance3D.new()
	puddle.name = "MudMesh"
	var quad := BoxMesh.new()
	quad.size = Vector3(patch_size.x, 0.06, patch_size.y)
	puddle.mesh = quad
	puddle.position.y = 0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color = surface_color
	mat.roughness = 0.25
	puddle.material_override = mat
	add_child(puddle)

	# A few darker blobs so the patch reads as a surface, not a flat carpet.
	for i in 5:
		var blob := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35 + 0.12 * (i % 3)
		cyl.bottom_radius = cyl.top_radius + 0.1
		cyl.height = 0.08
		blob.mesh = cyl
		blob.position = Vector3(
			(float(i) / 4.0 - 0.5) * (patch_size.x - 1.4),
			0.07,
			(0.35 if i % 2 == 0 else -0.35) * (patch_size.y - 1.4)
		)
		var blob_mat := StandardMaterial3D.new()
		blob_mat.albedo_color = blob_color
		blob_mat.roughness = 0.2
		blob.material_override = blob_mat
		add_child(blob)

func _is_player(body: Node3D) -> bool:
	return body is CharacterBody3D and "move_speed" in body and (body.is_in_group("player") or body.name.to_lower().contains("pig"))

func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body) or _slowed.has(body):
		return
	if body.has_meta("star_invincible") and body.get_meta("star_invincible", false):
		return
	_slowed.append(body)
	body.move_speed = body.move_speed * mud_speed_factor
	mud_entered.emit(body)

func _on_body_exited(body: Node3D) -> void:
	if not _slowed.has(body):
		return
	_restore(body)
	_slowed.erase(body)
	mud_exited.emit(body)

func _restore(body) -> void:
	if is_instance_valid(body) and "move_speed" in body and mud_speed_factor > 0.0:
		body.move_speed = body.move_speed / mud_speed_factor
