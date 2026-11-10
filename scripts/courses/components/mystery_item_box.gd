class_name MysteryItemBox
extends Area3D

signal item_collected(item_type: String, player: Node3D)

enum ItemType {
	ROCKET_BOOST,
	DEPLOY_PEEL,
	GOLDEN_STAR
}

@export var respawn_time: float = 4.0
@export var box_size: float = 1.3

const COLOR_NEON_YELLOW := Color("FACC15")
const COLOR_NEON_ORANGE := Color("FB923C")

var is_active: bool = true
var _respawn_timer: float = 0.0
var _box_mesh: MeshInstance3D
var _q_label: Label3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player
	_setup_visual()
	_setup_collision()
	body_entered.connect(_on_body_entered)

func _setup_visual() -> void:
	_box_mesh = MeshInstance3D.new()
	_box_mesh.name = "BoxMesh"
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * box_size
	_box_mesh.mesh = cube
	_box_mesh.position.y = 1.0

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("FACC15DD")
	mat.emission_enabled = true
	mat.emission = COLOR_NEON_YELLOW
	mat.emission_energy_multiplier = 1.6
	mat.roughness = 0.2
	_box_mesh.material_override = mat
	add_child(_box_mesh)

	# Question mark label
	_q_label = Label3D.new()
	_q_label.name = "QuestionMark"
	_q_label.text = "?"
	_q_label.font_size = 56
	_q_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_q_label.modulate = Color("1E293B")
	_q_label.outline_modulate = Color("FFFFFF")
	_q_label.outline_size = 6
	_q_label.position = Vector3(0, 1.0, 0)
	add_child(_q_label)

func _setup_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * (box_size * 1.3)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)

func _process(delta: float) -> void:
	if not is_active:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	# Idle floating & rotation animation
	var t := Time.get_ticks_msec() * 0.003
	if is_instance_valid(_box_mesh):
		_box_mesh.rotation.y = t * 1.5
		_box_mesh.position.y = 1.0 + sin(t * 2.0) * 0.15
	if is_instance_valid(_q_label):
		_q_label.position.y = 1.0 + sin(t * 2.0) * 0.15

func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return

	_collect(body)

func _collect(player: Node3D) -> void:
	is_active = false
	_respawn_timer = respawn_time

	if is_instance_valid(_box_mesh):
		_box_mesh.visible = false
	if is_instance_valid(_q_label):
		_q_label.visible = false

	# Pick random item
	var items := ["ROCKET_BOOST", "DEPLOY_PEEL", "GOLDEN_STAR"]
	var item_type: String = items[randi() % items.size()]
	_apply_item(item_type, player)
	item_collected.emit(item_type, player)

func _apply_item(item: String, player: Node3D) -> void:
	var popup_lbl := Label3D.new()
	popup_lbl.font_size = 24
	popup_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup_lbl.outline_size = 6
	popup_lbl.position = Vector3(0, 2.4, 0)

	match item:
		"ROCKET_BOOST":
			popup_lbl.text = "🚀【红薯火箭推进！】\n极速喷火爆发！"
			popup_lbl.modulate = Color("F97316")
			popup_lbl.outline_modulate = Color("7C2D12")
			if player is CharacterBody3D:
				var cb := player as CharacterBody3D
				var fwd := -cb.global_transform.basis.z.normalized()
				if fwd.length_squared() < 0.001:
					fwd = Vector3(0, 0, -1)
				cb.velocity += fwd * 20.0

		"DEPLOY_PEEL":
			popup_lbl.text = "🍉【获得滑溜西瓜皮！】\n已放置于后方阻截恶犬！"
			popup_lbl.modulate = Color("10B981")
			popup_lbl.outline_modulate = Color("064E3B")
			# Spawn watermelon peel behind player
			var peel_script := load("res://scripts/courses/components/watermelon_peel.gd")
			if peel_script:
				var peel: Node3D = peel_script.new()
				get_parent().add_child(peel)
				# Set the world position only after entering the tree (a pre-add_child
				# global_position assignment is treated as local coordinates).
				var back_pos := player.global_position + player.global_transform.basis.z * 2.5
				back_pos.y = 0.05
				peel.global_position = back_pos

		"GOLDEN_STAR":
			popup_lbl.text = "⭐【无敌金星小猪！】\n全速横冲直撞！"
			popup_lbl.modulate = Color("FDE047")
			popup_lbl.outline_modulate = Color("78350F")
			if player is CharacterBody3D and "move_speed" in player:
				var orig_speed: float = player.move_speed
				player.move_speed = orig_speed * 1.6
				var timer := player.get_tree().create_timer(5.0)
				timer.timeout.connect(func():
					if is_instance_valid(player) and "move_speed" in player:
						player.move_speed = orig_speed
				)

	player.add_child(popup_lbl)
	var tween := popup_lbl.create_tween()
	tween.tween_property(popup_lbl, "position:y", popup_lbl.position.y + 1.2, 1.8)
	tween.tween_callback(popup_lbl.queue_free)

func _respawn() -> void:
	is_active = true
	if is_instance_valid(_box_mesh):
		_box_mesh.visible = true
		_box_mesh.scale = Vector3.ZERO
		var tween := create_tween()
		tween.tween_property(_box_mesh, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	if is_instance_valid(_q_label):
		_q_label.visible = true
