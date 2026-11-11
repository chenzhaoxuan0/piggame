extends Node3D

# Drowsy fog - the nightmare prologue's opening pressure. Inside a dream, the
# real antagonist is falling asleep again: a tall translucent wall of fog that
# creeps forward at fog_speed. Catching the pig is NOT lethal and does not
# respawn it - the course jolts the pig forward and calls retreat() - so the
# fog can never soft-lock a run, it only punishes dawdling.
# stop_and_fade() is the "slammed door" ending: the fog stops, dissolves, and
# frees itself (dream logic: the door blocks the fog, not the butcher).
# (No class_name self-references: fresh class names are invisible to headless
# runs until the editor rescans the global class cache - see race_timer.gd.)

signal fog_touched(player: Node3D)

@export var wall_width: float = 13.0
@export var wall_height: float = 6.0
@export var fog_speed: float = 2.0
@export var touch_cooldown: float = 1.5

const COLOR_FOG := Color("6D5A8C")
const COLOR_FOG_DEEP := Color("4A3B68")

var chasing: bool = true
var stopped: bool = false

var _touch_cooldown_left: float = 0.0
var _layers: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_wall()
	_build_touch_area()

func _physics_process(delta: float) -> void:
	_touch_cooldown_left = maxf(0.0, _touch_cooldown_left - delta)
	if chasing and not stopped:
		global_position.z -= fog_speed * delta
	# Slow churning wobble so the wall reads as fog, not a sliding pane.
	for i in _layers.size():
		var wobble := sin(Time.get_ticks_msec() * 0.002 + float(i) * 1.7) * 0.25
		_layers[i].position.z = wobble - 0.35 * float(i)

func retreat(distance: float = 6.0) -> void:
	# After a catch: fall back behind the pig and re-arm the touch.
	global_position.z += distance
	_touch_cooldown_left = touch_cooldown

func stop_and_fade() -> void:
	if stopped:
		return
	stopped = true
	chasing = false
	var tween := create_tween()
	for layer in _layers:
		var mat := layer.material_override as StandardMaterial3D
		if mat != null:
			tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tween.tween_interval(0.1)
	tween.tween_callback(queue_free)

func _build_wall() -> void:
	# Two offset translucent layers + a drifting "困……" for the dream read.
	for i in 2:
		var layer := MeshInstance3D.new()
		layer.name = "FogLayer%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(wall_width - 0.6 * float(i), wall_height - 0.4 * float(i), 0.7)
		layer.mesh = box
		layer.position = Vector3(0, box.size.y * 0.5, -0.35 * float(i))
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(COLOR_FOG.r, COLOR_FOG.g, COLOR_FOG.b, 0.5 - 0.12 * float(i))
		mat.emission_enabled = true
		mat.emission = COLOR_FOG_DEEP
		mat.emission_energy_multiplier = 0.5
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		layer.material_override = mat
		add_child(layer)
		_layers.append(layer)

	var label := Label3D.new()
	label.name = "DrowsyLabel"
	label.text = "困……\n困……"
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("B7A6D9")
	label.outline_modulate = Color("241D1B")
	label.outline_size = 8
	label.position = Vector3(0, wall_height * 0.55, 0.4)
	add_child(label)

func _build_touch_area() -> void:
	var area := Area3D.new()
	area.name = "FogTouchArea"
	area.collision_layer = 0
	area.collision_mask = 2 # Player
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(wall_width, wall_height, 1.4)
	col.shape = box
	col.position.y = wall_height * 0.5
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _on_body_entered(body: Node3D) -> void:
	if stopped or _touch_cooldown_left > 0.0:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	_touch_cooldown_left = touch_cooldown
	fog_touched.emit(body)
