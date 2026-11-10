class_name VoxelPushBlock
extends CharacterBody3D

signal block_pushed(block: Node3D, direction: Vector3)
signal block_fell_into_water(block: Node3D, stream: Node3D)
signal block_landed_on_target(block: Node3D, target: Node3D)

enum BlockType { DIRT, SAND, TNT, STONE }

@export var block_type: BlockType = BlockType.DIRT
@export var block_size: float = 1.8
@export var push_distance: float = 2.0
@export var is_gravity_affected: bool = false
@export var can_be_pushed: bool = true
@export var preferred_push_axis: Vector3 = Vector3.ZERO

const COLOR_DIRT := Color("5A3E28")
const COLOR_GRASS := Color("4ADE80")
const COLOR_SAND := Color("FBBF24")
const COLOR_TNT_RED := Color("DC2626")
const COLOR_TNT_WHITE := Color("F8FAFC")
const COLOR_STONE := Color("78909C")

var is_moving: bool = false
var is_falling: bool = false
var has_exploded: bool = false
var has_bridged: bool = false
var mesh_instance: MeshInstance3D
var push_area: Area3D
var prompt_label: Label3D

func _ready() -> void:
	_setup_collision()
	_setup_visuals()
	_setup_push_area()
	_setup_prompt()

func _setup_prompt() -> void:
	prompt_label = Label3D.new()
	prompt_label.name = "PushPromptLabel"
	prompt_label.text = "[E] 猪拱推进"
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 24
	prompt_label.modulate = Color("FDE047") # Vibrant yellow
	prompt_label.outline_modulate = Color("1E293B")
	prompt_label.outline_size = 5
	prompt_label.position.y = block_size + 0.5
	prompt_label.visible = false
	add_child(prompt_label)

func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p: Node3D = players[0] as Node3D
		var dist := global_position.distance_to(p.global_position)
		var nearby := dist < 3.2 and can_be_pushed and not has_bridged and not has_exploded
		if is_instance_valid(prompt_label):
			prompt_label.visible = nearby
	elif is_instance_valid(prompt_label):
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not can_be_pushed or is_moving or is_falling or has_exploded or has_bridged:
		return
	if event.is_action_pressed("action_interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_SPACE)):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var p: Node3D = players[0] as Node3D
			if global_position.distance_to(p.global_position) < 3.2:
				var push_dir := preferred_push_axis
				if push_dir == Vector3.ZERO:
					var diff := global_position - p.global_position
					diff.y = 0
					if abs(diff.x) > abs(diff.z):
						push_dir = Vector3(sign(diff.x), 0, 0)
					else:
						push_dir = Vector3(0, 0, sign(diff.z))
				push(push_dir)

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape"
	var box := BoxShape3D.new()
	box.size = Vector3(block_size, block_size, block_size)
	col.shape = box
	col.position.y = block_size * 0.5
	add_child(col)

func _setup_visuals() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "BlockMesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(block_size, block_size, block_size)
	mesh_instance.mesh = box_mesh
	mesh_instance.position.y = block_size * 0.5

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.9

	match block_type:
		BlockType.DIRT:
			mat.albedo_color = COLOR_DIRT
		BlockType.SAND:
			mat.albedo_color = COLOR_SAND
			is_gravity_affected = true
		BlockType.TNT:
			mat.albedo_color = COLOR_TNT_RED
		BlockType.STONE:
			mat.albedo_color = COLOR_STONE

	mesh_instance.material_override = mat
	add_child(mesh_instance)

	# If TNT, add a white band in the middle
	if block_type == BlockType.TNT:
		var band := MeshInstance3D.new()
		band.name = "TNTBand"
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(block_size * 1.02, block_size * 0.35, block_size * 1.02)
		band.mesh = band_mesh
		band.position.y = block_size * 0.5
		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = COLOR_TNT_WHITE
		band.material_override = band_mat
		add_child(band)

func _setup_push_area() -> void:
	push_area = Area3D.new()
	push_area.name = "PushArea"
	push_area.collision_mask = 2 # Player layer
	var area_col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(block_size + 0.8, block_size, block_size + 0.8)
	area_col.shape = box
	area_col.position.y = block_size * 0.5
	push_area.add_child(area_col)
	push_area.body_entered.connect(_on_pusher_entered)
	add_child(push_area)

func _on_pusher_entered(body: Node3D) -> void:
	if not can_be_pushed or is_moving or is_falling or has_exploded:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return

	# Calculate push direction
	var diff := global_position - body.global_position
	diff.y = 0
	if diff.length_squared() < 0.01:
		return

	var push_dir := preferred_push_axis
	if push_dir == Vector3.ZERO:
		if abs(diff.x) > abs(diff.z):
			push_dir.x = sign(diff.x)
		else:
			push_dir.z = sign(diff.z)

	push(push_dir)

func push(direction: Vector3) -> bool:
	if is_moving or is_falling or not can_be_pushed:
		return false

	var target_pos := global_position + direction.normalized() * push_distance
	is_moving = true

	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		is_moving = false
		block_pushed.emit(self, direction)
		_check_fall_or_support()
	)
	return true

func _check_fall_or_support() -> void:
	if not is_gravity_affected:
		return
	# Raycast downward or simple floor check: if no floor beneath, drop down
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, -10.0, 0))
	query.exclude = [self]
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		# Fall into abyss
		_fall_down(global_position.y - 12.0, null)
	elif global_position.y - result.position.y > 1.0:
		# There is a drop
		_fall_down(result.position.y, result.collider)

func _fall_down(target_y: float, hit_collider: Object) -> void:
	is_falling = true
	var tween := create_tween()
	var fall_time: float = maxf(0.2, (global_position.y - target_y) * 0.08)
	tween.tween_property(self, "global_position:y", target_y, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		is_falling = false
		if hit_collider != null and hit_collider is Node3D:
			block_landed_on_target.emit(self, hit_collider as Node3D)
	)

func ignite_and_explode(callback: Callable = Callable()) -> void:
	if has_exploded:
		return
	has_exploded = true
	can_be_pushed = false

	# Sizzle & flash white
	var tween := create_tween()
	for i in range(2):
		tween.tween_property(mesh_instance, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
		tween.tween_property(mesh_instance, "scale", Vector3(0.9, 1.25, 0.9), 0.08)
	tween.tween_callback(func():
		# Boom!
		if callback.is_valid():
			callback.call()
		_spawn_explosion_effect()
		queue_free()
	)

func _spawn_explosion_effect() -> void:
	# Clean explosion visual
	pass
