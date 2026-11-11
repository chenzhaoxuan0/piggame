extends StaticBody3D

# A real body for the woodland's patrol guards (and later the creek canyon
# guard). They used to be label-and-cylinder dummies with no collision and no
# stun(): walking into them did nothing and the cardboard box's bowling dive
# could not actually knock them out.
#
# This node IS the solid body (so it physically blocks corridors), it joins the
# "chase_dogs" group so the box dive finds it via has_method("stun"), and a
# touch area delivers a non-lethal slapstick nip. Its PatrolVisionCone child is
# paused while stunned so a bowled-over guard stops seeing the pig.
# (No class_name self-references: fresh class names are invisible to headless
# runs until the editor rescans the global class cache - see race_timer.gd.)

signal guard_nipped(player: Node3D)
signal guard_stunned(duration: float)

@export var body_radius: float = 0.55
@export var body_height: float = 1.15
@export var nip_power: float = 4.5
@export var nip_up: float = 3.5
@export var nip_cooldown: float = 1.2
@export var body_color: Color = Color("8C2F2F") # Storybook hound red-brown
@export var display_name: String = "巡逻恶犬"

var is_stunned: bool = false

var _stun_time_left: float = 0.0
var _nip_cooldown_left: float = 0.0
var _stars_label: Label3D = null

func _ready() -> void:
	add_to_group("chase_dogs")
	collision_layer = 1 # Solid world geometry: the guard physically holds a corridor
	collision_mask = 0

	var shape := CollisionShape3D.new()
	shape.name = "GuardShape"
	var cyl := CylinderShape3D.new()
	cyl.radius = body_radius
	cyl.height = body_height
	shape.shape = cyl
	shape.position.y = body_height * 0.5
	add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.name = "GuardMesh"
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = body_radius
	cyl_mesh.bottom_radius = body_radius
	cyl_mesh.height = body_height
	mesh.mesh = cyl_mesh
	mesh.position.y = body_height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 0.9
	mesh.material_override = mat
	add_child(mesh)

	var label := Label3D.new()
	label.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
	label.name = "DogLabel"
	label.text = display_name
	label.font_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("FFFBEB")
	label.outline_modulate = Color("292524")
	label.outline_size = 5
	label.position = Vector3(0, body_height + 0.65, 0)
	add_child(label)

	var nip := Area3D.new()
	nip.name = "NipArea"
	nip.collision_layer = 0
	nip.collision_mask = 2 # Player
	var nip_col := CollisionShape3D.new()
	var nip_box := BoxShape3D.new()
	nip_box.size = Vector3(body_radius * 2.0 + 0.9, body_height + 0.6, body_radius * 2.0 + 0.9)
	nip_col.shape = nip_box
	nip_col.position.y = body_height * 0.5
	nip.add_child(nip_col)
	nip.body_entered.connect(_on_nip_entered)
	add_child(nip)

func _physics_process(delta: float) -> void:
	_nip_cooldown_left = maxf(0.0, _nip_cooldown_left - delta)
	if not is_stunned:
		return
	_stun_time_left -= delta
	if _stun_time_left <= 0.0:
		_wake_up()

func stun(duration: float = 4.0, _knockback: Vector3 = Vector3.ZERO) -> void:
	# Same contract as ChaseDog.stun(): called by the cardboard box bowling dive
	# (and anything else that hits "chase_dogs" with has_method("stun")).
	if is_stunned:
		_stun_time_left = maxf(_stun_time_left, duration)
		return
	is_stunned = true
	_stun_time_left = duration
	_set_cone_paused(true)

	# Dizzy spin + stars
	if _stars_label == null:
		_stars_label = Label3D.new()
		_stars_label.font = preload("res://scripts/ui/ui_kit.gd").font_bold()
		_stars_label.name = "StunStars"
		_stars_label.text = "💫 眼冒金星…"
		_stars_label.font_size = 22
		_stars_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_stars_label.modulate = Color("FACC15")
		_stars_label.outline_modulate = Color("292524")
		_stars_label.outline_size = 5
		_stars_label.position = Vector3(0, body_height + 1.1, 0)
		add_child(_stars_label)
	_stars_label.visible = true
	var tween := create_tween()
	tween.set_loops(int(ceil(duration)))
	tween.tween_property(self, "rotation:y", rotation.y + TAU, 0.5)

	guard_stunned.emit(duration)

func _wake_up() -> void:
	is_stunned = false
	_set_cone_paused(false)
	if _stars_label != null:
		_stars_label.visible = false

func bury() -> void:
	# Gravity-sand burial (creek canyon): squash flat and stop blocking the
	# corridor for good. The guard never wakes from this one.
	if is_stunned and _stun_time_left > 100.0:
		return # Already buried.
	is_stunned = true
	_stun_time_left = 999.0
	collision_layer = 0 # The passage opens once the sand has done its work
	_set_cone_paused(true)
	for child in get_children():
		if child is MeshInstance3D and child.name == "GuardMesh":
			var squash := create_tween()
			squash.tween_property(child, "scale", Vector3(1.4, 0.2, 1.4), 0.2)

func _set_cone_paused(paused: bool) -> void:
	for child in get_children():
		if child.is_in_group("patrol_vision_cones"):
			child.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

func _on_nip_entered(body: Node3D) -> void:
	if is_stunned or _nip_cooldown_left > 0.0:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_nip_cooldown_left = nip_cooldown
	var away := body.global_position - global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
	if body.has_method("apply_knockback"):
		body.apply_knockback(away * nip_power + Vector3.UP * nip_up, 0.6)
	guard_nipped.emit(body)
