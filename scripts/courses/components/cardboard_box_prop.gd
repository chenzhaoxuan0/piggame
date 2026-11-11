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
var _home_parent: Node = null # Where unequipping drops the box (the course root)
var _bowled_dogs: Array[Node3D] = [] # Dogs already struck during the current slide
var _auto_pickup_cooldown: float = 0.0 # Grace after a drop: no instant re-equip

const AUTO_PICKUP_GRACE := 1.5

func _ready() -> void:
	_home_parent = get_parent()
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
	lbl.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	lbl.name = "BoxLogo"
	lbl.text = "THE ORANGE\n一口猪专属纸箱"
	lbl.font_size = 20
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color("1E293B")
	lbl.position = Vector3(0, box_size.y + 0.35, 0)
	add_child(lbl)

	prompt_label = Label3D.new()
	prompt_label.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
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

var is_sliding: bool = false
var _slide_timer: float = 0.0

func _process(delta: float) -> void:
	if not is_equipped:
		_auto_pickup_cooldown = maxf(0.0, _auto_pickup_cooldown - delta)
		return
	if current_player == null or not is_instance_valid(current_player):
		return

	if is_sliding:
		_slide_timer -= delta
		rotation.x = deg_to_rad(15.0)
		position.y = 0.02
		# Check bowling impact with dogs (each dog only once per slide: the label
		# used to spawn every frame the box overlapped a dog)
		for dog in get_tree().get_nodes_in_group("chase_dogs"):
			if is_instance_valid(dog) and not _bowled_dogs.has(dog) and global_position.distance_to(dog.global_position) < 2.5:
				_bowled_dogs.append(dog)
				_bowl_over_dog(dog)
		if _slide_timer <= 0.0:
			is_sliding = false
			rotation.x = 0.0
		return

	var speed: float = 0.0
	if current_player is CharacterBody3D:
		speed = (current_player as CharacterBody3D).velocity.length()

	if speed > 0.4:
		# Cute waddling box animation while walking
		var t := Time.get_ticks_msec() * 0.012
		rotation.z = sin(t) * 0.08
		rotation.x = 0.0
		position.y = 0.15 + abs(sin(t)) * 0.06
	else:
		# Box drops flat to the ground when still (camouflaged)
		rotation.z = 0.0
		rotation.x = 0.0
		position.y = 0.05

func _unhandled_input(event: InputEvent) -> void:
	if is_equipped:
		if event.is_action_pressed("action_dash") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT):
			start_toboggan_slide()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("action_interact") \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
			# Only E unequips: jump is the jump key, and it used to destroy the box.
			unequip_box()
			get_viewport().set_input_as_handled()
	else:
		if event.is_action_pressed("action_interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
			var players := get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				var p: Node3D = players[0] as Node3D
				if global_position.distance_to(p.global_position) < 2.8:
					equip_box(p)

func start_toboggan_slide() -> void:
	if not is_equipped or is_sliding:
		return
	is_sliding = true
	_slide_timer = 1.3
	_bowled_dogs.clear()
	if current_player is CharacterBody3D:
		var cb := current_player as CharacterBody3D
		var forward_dir := -cb.global_transform.basis.z.normalized()
		if forward_dir.length_squared() < 0.001:
			forward_dir = Vector3(0, 0, -1)
		cb.velocity = forward_dir * 10.5

	if prompt_label:
		prompt_label.text = "🎳【纸箱雪橇俯冲！】全速保龄球滑行！"
		prompt_label.modulate = Color("FACC15")

func _bowl_over_dog(dog: Node3D) -> void:
	if dog.has_method("stun"):
		dog.stun(4.5)
	var strike_lbl := Label3D.new()
	strike_lbl.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	strike_lbl.text = "🎳 STRIKE! 全中！\n【恶犬被纸箱保龄球撞飞！】"
	strike_lbl.font_size = 26
	strike_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	strike_lbl.modulate = Color("FACC15")
	strike_lbl.outline_modulate = Color("78350F")
	strike_lbl.outline_size = 6
	strike_lbl.global_position = dog.global_position + Vector3(0, 2.0, 0)
	get_tree().root.add_child(strike_lbl)

	var tween := strike_lbl.create_tween()
	tween.tween_property(strike_lbl, "position:y", strike_lbl.position.y + 1.2, 1.5)
	tween.tween_callback(strike_lbl.queue_free)

func _on_player_entered(body: Node3D) -> void:
	if is_equipped or _auto_pickup_cooldown > 0.0:
		# The grace window stops a just-dropped box from snapping straight back
		# onto the pig the moment it takes a step; deliberate [E] still works.
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
		prompt_label.text = "[ 纸箱潜行中 ] 静止隐蔽 | 按 [Shift] 俯冲保龄撞狗！ | 按 [E] 脱下（可再穿上）"
		prompt_label.modulate = Color("38BDF8")
		prompt_label.position = Vector3(0, box_size.y + 0.6, 0)

	box_equipped.emit(player)

func unequip_box() -> void:
	if not is_equipped:
		return
	is_equipped = false
	is_sliding = false
	_bowled_dogs.clear()
	var prev_player := current_player
	current_player = null
	if is_instance_valid(prev_player):
		prev_player.set_meta("in_stealth_box", false)
	box_unequipped.emit(prev_player)

	# Drop the box in front of the pig instead of destroying it, so the prop can
	# be picked up again (and re-hides the pig later). Falls back to the world.
	var forward := Vector3(0, 0, -1)
	if is_instance_valid(prev_player):
		forward = -prev_player.global_transform.basis.z.normalized()
		if forward.length_squared() < 0.001:
			forward = Vector3(0, 0, -1)
	var drop_parent := _home_parent if is_instance_valid(_home_parent) else get_tree().root
	reparent(drop_parent)
	global_position = (prev_player.global_position if is_instance_valid(prev_player) else global_position) + forward * 1.6
	global_position.y = 0.05
	rotation = Vector3.ZERO
	_auto_pickup_cooldown = AUTO_PICKUP_GRACE

	# Fun cartoon pop, then behave like a fresh pickup again
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.3, 0.75, 1.3), 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	if prompt_label:
		prompt_label.text = "[E] 穿上纸箱伪装潜行"
		prompt_label.modulate = Color("FDE047")
		prompt_label.position = Vector3(0, box_size.y + 0.8, 0)
