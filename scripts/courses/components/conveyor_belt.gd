extends Area3D

const ASSETS = preload("res://scripts/art/asset_library.gd")

# Slaughterhouse conveyor belt: continuously carries whoever stands on it
# along belt_direction at belt_speed. The carry is a positional drift each
# physics frame (the same mechanism the voxel push tweens use), NOT a velocity
# push: the pig's controller corrects velocity toward its own target at a
# constant rate, so any sustained push accel would ramp the speed without
# bound. Positional drift composes cleanly instead - standing still is carried
# at belt_speed, running against it wades at (move_speed - belt_speed), running
# with it rides at (move_speed + belt_speed). Non-lethal, purely positional
# comedy like every other hazard.
# (No class_name self-references: fresh class names are invisible to headless
# runs until the editor rescans the global class cache - see race_timer.gd.)

signal belt_entered(body: Node3D)

@export var belt_size: Vector3 = Vector3(3.2, 0.35, 8.0)
@export var belt_direction: Vector3 = Vector3(0, 0, 1) # World direction, normalized on use
@export var belt_speed: float = 2.5
@export var stripe_count: int = 8
# Optional zone dressing: when set (course 0 realistic line), the deck mesh is
# replaced by the zone's Lux3D conveyor model scaled to the belt footprint -
# the hazard stripes keep scrolling above it as the direction cue.
@export var lux_asset_id: String = ""

const COLOR_FRAME := Color("263238") # Dark machine frame
const COLOR_BELT := Color("37474F") # Belt surface
const COLOR_STRIPE := Color("FFB300") # Hazard amber stripes

var _dir := Vector3.BACK
var _stripes_root: Node3D

func _ready() -> void:
	_dir = belt_direction.normalized()
	if _dir.length_squared() < 0.5:
		_dir = Vector3.BACK
	collision_layer = 0
	collision_mask = 2 # Player
	_setup_frame()
	_setup_push_area()
	_setup_stripes()
	body_entered.connect(func(body): belt_entered.emit(body))

func _physics_process(delta: float) -> void:
	# Positional carry (see header): drift every overlapping body along the
	# belt. Velocity stays the pig's own, so walking animations and knockbacks
	# behave normally on top of the drift.
	for body in get_overlapping_bodies():
		if body is CharacterBody3D:
			body.global_position += _dir * belt_speed * delta

func _setup_frame() -> void:
	# Static machine frame + belt deck the pig walks on.
	var deck := StaticBody3D.new()
	deck.name = "BeltDeck"
	deck.collision_layer = 1
	deck.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = belt_size
	col.shape = box
	col.position.y = belt_size.y * 0.5
	deck.add_child(col)

	var deck_mesh := MeshInstance3D.new()
	var deck_box := BoxMesh.new()
	deck_box.size = belt_size
	deck_mesh.mesh = deck_box
	deck_mesh.position = col.position
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = COLOR_FRAME
	frame_mat.roughness = 0.6
	frame_mat.metallic = 0.3
	deck_mesh.material_override = frame_mat
	deck.add_child(deck_mesh)

	# Zone dressing: scale the Lux3D conveyor model (normalized to 10 x 7.2 x
	# 0.7, belt surface on top) onto the deck footprint and sink it so its belt
	# top lands at the collision deck top. The scrolling stripes stay.
	if not lux_asset_id.is_empty():
		var lux := ASSETS.make(lux_asset_id)
		if lux != null:
			lux.scale = Vector3(belt_size.x / 10.0, 1.0, belt_size.z / 7.2)
			lux.position = Vector3(0, belt_size.y - 0.7, 0)
			deck_mesh.visible = false
			deck.add_child(lux)
	add_child(deck)

func _setup_push_area() -> void:
	# Detection volume reaching ~1.2 m above the deck surface.
	var col := CollisionShape3D.new()
	col.name = "BeltCol"
	var box := BoxShape3D.new()
	box.size = Vector3(belt_size.x, 1.2, belt_size.z)
	col.shape = box
	col.position.y = 0.6
	add_child(col)

func _setup_stripes() -> void:
	# Moving hazard stripes: a looping tween slides them along the belt so the
	# direction is readable at a glance (which way it carries you). Stripes lay
	# out along the belt's LONG axis, whichever that is - lateral transfer
	# belts (dir +-X) get bars across their run instead of along it.
	_stripes_root = Node3D.new()
	_stripes_root.name = "Stripes"
	add_child(_stripes_root)

	var lateral := absf(_dir.x) > absf(_dir.z)
	var long_size: float = belt_size.x if lateral else belt_size.z
	var stripe_gap: float = long_size / float(stripe_count)
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = COLOR_STRIPE
	stripe_mat.emission_enabled = true
	stripe_mat.emission = COLOR_STRIPE
	stripe_mat.emission_energy_multiplier = 0.6
	for i in stripe_count:
		var stripe := MeshInstance3D.new()
		var box := BoxMesh.new()
		if lateral:
			box.size = Vector3(stripe_gap * 0.45, 0.03, belt_size.z * 0.92)
		else:
			box.size = Vector3(belt_size.x * 0.92, 0.03, stripe_gap * 0.45)
		stripe.mesh = box
		var along: float = -long_size * 0.5 + stripe_gap * (float(i) + 0.5)
		stripe.position = Vector3(along, belt_size.y + 0.02, 0) if lateral else Vector3(0, belt_size.y + 0.02, along)
		stripe.material_override = stripe_mat
		_stripes_root.add_child(stripe)

	var axis := "x" if lateral else "z"
	var axis_dir: float = _dir.x if lateral else _dir.z
	var scroll := _stripes_root.create_tween()
	scroll.set_loops()
	scroll.tween_property(_stripes_root, "position:" + axis, axis_dir * stripe_gap, stripe_gap / maxf(0.1, belt_speed))
	scroll.tween_callback(func():
		var pos: Vector3 = _stripes_root.position
		if lateral:
			pos.x -= axis_dir * stripe_gap
		else:
			pos.z -= axis_dir * stripe_gap
		_stripes_root.position = pos
	)
