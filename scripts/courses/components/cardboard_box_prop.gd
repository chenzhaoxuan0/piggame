class_name CardboardBoxProp
extends Node3D

signal box_equipped(player: Node3D)
signal box_unequipped(player: Node3D)

@export var box_size: Vector3 = Vector3(1.6, 1.4, 2.0)

const COLOR_CARDBOARD := Color("B45309") # Warm cardboard kraft
const COLOR_LABEL := Color("FEF3C7")

var is_equipped: bool = false
var current_player: Node3D = null
var interact_area: Area3D
var box_mesh: MeshInstance3D
var prompt_label: Label3D

func _ready() -> void:
	_setup_visual()
	_setup_interact_area()

func _setup_visual() -> void:
	box_mesh = MeshInstance3D.new()
	box_mesh.name = "BoxMesh"
	var cube := BoxMesh.new()
	cube.size = box_size
	box_mesh.mesh = cube
	box_mesh.position.y = box_size.y * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CARDBOARD
	mat.roughness = 0.8
	box_mesh.material_override = mat
	add_child(box_mesh)

	# Label on the box
	var lbl := Label3D.new()
	lbl.name = "BoxLogo"
	lbl.text = "THE ORANGE\n一口猪专属纸箱"
	lbl.font_size = 20
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color("1E293B")
	lbl.position = Vector3(0, box_size.y + 0.35, 0)
	add_child(lbl)

	prompt_label = Label3D.new()
	prompt_label.name = "BoxPrompt"
	prompt_label.text = "[E] 穿上纸箱伪装潜行"
	prompt_label.font_size = 22
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.modulate = Color("FDE047")
	prompt_label.outline_modulate = Color("1E293B")
	prompt_label.outline_size = 5
	prompt_label.position = Vector3(0, box_size.y + 0.8, 0)
	add_child(prompt_label)

func _setup_interact_area() -> void:
	interact_area = Area3D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 0
	interact_area.collision_mask = 2 # Player

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(box_size.x + 1.2, box_size.y + 1.0, box_size.z + 1.2)
	col.shape = box
	col.position.y = box_size.y * 0.5
	interact_area.add_child(col)

	interact_area.body_entered.connect(_on_player_entered)
	add_child(interact_area)

func _process(_delta: float) -> void:
	if not is_equipped:
		return
	if current_player == null or not is_instance_valid(current_player):
		return

	var speed: float = 0.0
	if current_player is CharacterBody3D:
		speed = (current_player as CharacterBody3D).velocity.length()

	if speed > 0.4:
		# Cute waddling box animation while walking
		var t := Time.get_ticks_msec() * 0.012
		rotation.z = sin(t) * 0.08
		position.y = 0.15 + abs(sin(t)) * 0.06
	else:
		# Box drops flat to the ground when still (camouflaged)
		rotation.z = 0.0
		position.y = 0.05

func _unhandled_input(event: InputEvent) -> void:
	if is_equipped:
		if event.is_action_pressed("action_interact") \
			or event.is_action_pressed("action_jump") \
			or event.is_action_pressed("action_dash") \
			or (event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_E, KEY_SPACE, KEY_SHIFT])):
			unequip_box()
	else:
		if event.is_action_pressed("action_interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
			var players := get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				var p: Node3D = players[0] as Node3D
				if global_position.distance_to(p.global_position) < 2.8:
					equip_box(p)

func _on_player_entered(body: Node3D) -> void:
	if is_equipped:
		return
	if body.is_in_group("player") or body.name.to_lower().contains("pig"):
		equip_box(body)

func equip_box(player: Node3D) -> void:
	if is_equipped:
		return
	is_equipped = true
	current_player = player

	# Attach visual to player
	reparent(player)
	position = Vector3(0, 0.1, 0)
	rotation = Vector3.ZERO
	player.set_meta("in_stealth_box", true)

	if prompt_label:
		prompt_label.text = "[ 纸箱潜行中 ] 静止可隐蔽 | 按 [E] / [空格] / [Shift] 脱下纸箱"
		prompt_label.modulate = Color("38BDF8")
		prompt_label.position = Vector3(0, box_size.y + 0.6, 0)

	box_equipped.emit(player)

func unequip_box() -> void:
	if not is_equipped:
		return
	is_equipped = false
	var prev_player := current_player
	current_player = null
	if is_instance_valid(prev_player):
		prev_player.set_meta("in_stealth_box", false)
	box_unequipped.emit(prev_player)

	# Fun cartoon popping tween
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.3, 0.2, 1.3), 0.12).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(queue_free)
