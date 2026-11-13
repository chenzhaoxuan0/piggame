class_name FarmPlaything
extends Node3D

## Body-driven farm easter eggs - the mountain road's playground props.
## One component, many kinds; every reaction is triggered by the pig's BODY
## (walk in, sprint into, jump into), never an F-prompt, and never through
## the "interactable" group (that count is pinned by tests). Detection is the
## house pattern: this side owns an Area3D with collision_mask 2 (player).
##
## The parent (farm_grounds) builds the visuals/colliders it wants and adds a
## FarmPlaything child configured with kind + gag lines; the component adds
## the sense area and reports back through `played` for counting/achievements.

signal played(kind: String, detail)
## 反应台词上屏幕：世界里的漂浮小字在镜头拉远后几乎不可读，
## 所以每句 gag 同时经此上报，由关卡层汇总成右下角通知。
signal noticed(text: String)

enum Kind { GRASS, TIPPABLE, CABBAGE, HAYSTACK, BEEHIVE, MAILBOX, HORN, MUDPIT, NEST, POTATO, APPLE_TREE, METEOR_BUTTON }

const UI = preload("res://scripts/ui/ui_kit.gd")

# Cabbage punt tuning: horizontal hoof strength (≈3 m of roll per kick after
# damping) and the upward lift that makes it hop. Struck off-centre so the same
# impulse also spins the ball - it rolls, not slides.
const CABBAGE_KICK_SPEED := 2.2
const CABBAGE_KICK_LIFT := 1.35

@export var kind: Kind = Kind.GRASS
## Rotating gag lines (tippables / grass). Empty = use the per-kind default.
@export var gag_lines: Array[String] = []
## Tippables only: require a sprinting or dodging pig to topple.
@export var need_charge := false
## Sense box size (the Area3D footprint).
@export var sense_size := Vector3(2.4, 2.4, 2.4)
## Per-thing cooldown so one walk-by doesn't machine-gun the gag.
@export var cooldown := 2.0

var _cool_timer := 0.0
var _one_shot_done := false
var _nest_count := 0
var _buffed_speed := 0.0
var _apples_eaten := 0
# The visual prop (this node's parent) as built - the meteor reset snaps every
# pen prop back here and re-arms its one-shot gag.
var _home_transform := Transform3D.IDENTITY
# The prop's in-flight motion tween (topple / kick): a meteor landing mid-
# animation must kill it first, or the dying tween overwrites the reset
# transform a frame later and the prop stays wrecked forever.
var _prop_tween: Tween = null

func _ready() -> void:
	var parent := get_parent() as Node3D
	if parent != null:
		_home_transform = parent.transform
	var area := Area3D.new()
	area.name = "SenseArea"
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sense_size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_sense)

func _physics_process(delta: float) -> void:
	if _cool_timer > 0.0:
		_cool_timer = maxf(0.0, _cool_timer - delta)

func _ready_cool() -> bool:
	if _cool_timer > 0.0:
		return false
	_cool_timer = cooldown
	return true

func _on_sense(body: Node3D) -> void:
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	if not body.control_mode in ["explore", "chase"]:
		return
	match kind:
		Kind.GRASS: _react_grass()
		Kind.TIPPABLE: _react_tippable(body)
		Kind.CABBAGE: _react_cabbage(body)
		Kind.HAYSTACK: _react_haystack(body)
		Kind.BEEHIVE: _react_beehive(body)
		Kind.MAILBOX: _react_mailbox()
		Kind.HORN: _react_horn()
		Kind.MUDPIT: _react_mudpit(body)
		Kind.NEST: _react_nest()
		Kind.POTATO: _react_potato()
		Kind.APPLE_TREE: _react_apple_tree(body)
		Kind.METEOR_BUTTON: _react_meteor_button()

# ------------------------------------------------------------- reactions
func _react_grass() -> void:
	if not _ready_cool():
		return
	_gag(_gag_or(["嚼嚼……真嫩。", "嚼嚼——这丛带着露水！", "嗯，山坡下段的更甜。"]))
	played.emit("grass", "")

func _react_tippable(body: Node3D) -> void:
	if _one_shot_done:
		return
	if need_charge and not (body.is_sprinting or body.dodge_timer > 0.0):
		_gag("（普通走路推不动——试试按住 Shift 冲过来！）", 1.6)
		return
	_one_shot_done = true
	# Fall away from the pig: yaw toward the shove, then tip 90 degrees.
	# (The visual prop is this node's PARENT - the plaything is its brain.)
	var prop := get_parent() as Node3D
	var away := (global_position - body.global_position)
	away.y = 0.0
	var yaw := atan2(away.x, away.z) if away.length_squared() > 0.01 else prop.rotation.y
	var fall := Basis(Vector3.RIGHT, PI * 0.5)
	var tween := create_tween()
	_prop_tween = tween
	tween.tween_property(prop, "basis", Basis(Vector3.UP, yaw) * fall, 0.4)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_gag(_gag_or(["咣当！它滚了三圈。", "哗啦——另一件农具殉职。", "轰隆。农场主不知道，猪知道。"]))
	played.emit("tippable", name)

func _react_cabbage(body: Node3D) -> void:
	# The kick: a punt impulse on the rigid ball - horizontal away from the pig
	# plus a touch of lift, struck a touch below the equator so the same
	# impulse also applies torque (the ball comes off the hoof spinning and
	# rolls). One punt per touch. The old tween-hop path is gone: tweens and
	# physics fought over the body every frame.
	if not _ready_cool():
		return
	var away := global_position - body.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.BACK
	away = away.normalized()
	var ball := get_parent() # the cabbage body this plaything rides in
	if ball is RigidBody3D:
		var rigid := ball as RigidBody3D
		var radius := 0.4
		var shape_node := rigid.get_node_or_null("CollisionShape3D")
		if shape_node != null and shape_node.shape is SphereShape3D:
			radius = shape_node.shape.radius
		rigid.sleeping = false # a resting ball must still take the punt
		var impulse := (away * CABBAGE_KICK_SPEED + Vector3.UP * CABBAGE_KICK_LIFT) * rigid.mass
		rigid.apply_impulse(impulse, Vector3(0.0, -radius * 0.2, 0.0))
	_gag("咚！（卷心菜被踢出去一大步）", 1.2)

func _react_haystack(body: Node3D) -> void:
	# A real dive needs downward speed - walking in does not score.
	if body.velocity.y > -4.0:
		return
	if not _ready_cool():
		return
	var score := float(randi_range(7, 10))
	var splash: String = ["草屑四溅！", "完美压线！", "水花式草花！", "观众……都是麻雀。"].pick_random()
	_gag("跳水打分：%d 分！%s" % [int(score), splash])
	if score >= 10.0:
		played.emit("perfect_dive", score)
	else:
		played.emit("dive", score)

func _react_beehive(body: Node3D) -> void:
	if not _ready_cool():
		return
	_gag("嗡——！！")
	if _buffed_speed <= 0.0 and body is CharacterBody3D:
		_buffed_speed = body.move_speed
		body.move_speed = _buffed_speed * 1.35
		_gag("被蛰的猪跑得更快！（3 秒）")
		played.emit("bee", "")
		var timer := get_tree().create_timer(3.0)
		timer.timeout.connect(func():
			if is_instance_valid(body):
				body.move_speed = _buffed_speed
			_buffed_speed = 0.0)

func _react_mailbox() -> void:
	if _one_shot_done:
		return
	_one_shot_done = true
	# The flag flips up: the pig noses the mailbox open (flag lives on the
	# mailbox prop, this node's parent).
	var flag := get_parent().get_node_or_null("MailFlag")
	if flag != null:
		var tween := create_tween()
		tween.tween_property(flag, "rotation:x", -1.2, 0.25)
	_gag("掉出一张纸——「运牲车调度单：明早 6:00 准时，装车口 B。」")
	_gag("！！", 1.6, Vector3(0, 2.6, 0))
	played.emit("mailbox", "")

func _react_horn() -> void:
	if not _ready_cool():
		return
	_gag("广播：「047 号肉猪，请于明早六点，到称重台报到——」")
	# Panic of sparrows: a few labels flap away from the pole.
	for i in 3:
		var bird := UI.world_label("﹏", 20, UI.WHITE, UI.INK)
		bird.position = Vector3(randf_range(-1.5, 1.5), 2.2 + i * 0.4, randf_range(-1.0, 1.0))
		add_child(bird)
		var t := create_tween()
		t.tween_property(bird, "position", bird.position + Vector3(randf_range(-6, 6), 6, randf_range(-6, 6)), 0.9)
		t.parallel().tween_property(bird, "modulate:a", 0.0, 0.9)
		t.tween_callback(bird.queue_free)
	played.emit("horn", "")

func _react_mudpit(body: Node3D) -> void:
	if not _ready_cool():
		return
	var vis: Node3D = body.get_node_or_null("VisualMesh")
	if vis != null:
		var tween := create_tween()
		tween.tween_property(vis, "rotation:x", TAU, 0.9).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(vis, "rotation:x", 0.0, 0.05)
	_gag("猪的本能：打滚。无与伦比。")
	played.emit("mud", "")

func _react_nest() -> void:
	if not _ready_cool():
		return
	_nest_count += 1
	if _nest_count <= 3:
		_gag("拱出一枚蛋。（%d / 3）" % _nest_count)
		played.emit("egg", _nest_count)
	else:
		_one_shot_done = true
		var chick := UI.world_label("叽！！", 24, Color("F7C948"), UI.INK)
		chick.position = Vector3(0, 1.2, 0)
		add_child(chick)
		var t := create_tween()
		t.tween_property(chick, "position:y", 4.0, 0.8)
		t.parallel().tween_property(chick, "modulate:a", 0.0, 0.8)
		t.tween_callback(chick.queue_free)
		_gag("第四下拱出来一只小鸡。它看了你一眼，飞走了。", 2.4)
		played.emit("chick", "")

func _react_potato() -> void:
	# One nose-dig per mound: the potato pops out and lands beside the furrow.
	if _one_shot_done or not _ready_cool():
		return
	_one_shot_done = true
	var potato := MeshInstance3D.new()
	potato.name = "DugPotato"
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	potato.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("B98A5A")
	mat.roughness = 0.95
	potato.material_override = mat
	add_child(potato)
	potato.position = Vector3(0.3, 0.1, 0.3)
	var tween := create_tween()
	tween.tween_property(potato, "position:y", 1.1, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(potato, "position:x", 0.9, 0.3)
	tween.tween_property(potato, "position:y", 0.1, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	_gag("拱出一颗土豆！个头还不小。")
	played.emit("potato", "")

func _react_apple_tree(body: Node3D) -> void:
	# A charged shove rains three apples; each apple is its own tiny pickup -
	# walk over one to crunch it. All three eaten = the achievement beat.
	if _one_shot_done:
		return
	if not (body.is_sprinting or body.dodge_timer > 0.0):
		_gag("（树纹丝不动——用 Shift 冲过来撞树干！）", 1.6)
		return
	_one_shot_done = true
	_gag("哗啦啦——下了一场苹果雨！", 2.2)
	for i in 3:
		var apple := Node3D.new()
		apple.name = "ApplePickup%d" % i
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("D94F3D")
		mat.roughness = 0.6
		mesh.material_override = mat
		apple.add_child(mesh)
		var land := Vector3(randf_range(-1.2, 1.2), 0.16, randf_range(-1.2, 1.2))
		apple.position = Vector3(randf_range(-1.0, 1.0), 3.2, randf_range(-1.0, 1.0))
		add_child(apple)
		var tween := create_tween()
		tween.tween_property(apple, "position:y", land.y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(apple, "position:x", land.x, 0.5)
		tween.parallel().tween_property(apple, "position:z", land.z, 0.5)
		var sense := Area3D.new()
		sense.name = "AppleSense"
		sense.collision_layer = 0
		sense.collision_mask = 2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.1, 1.2, 1.1)
		shape.shape = box
		sense.add_child(shape)
		apple.add_child(sense)
		sense.body_entered.connect(_on_apple_eaten.bind(apple))
	played.emit("apple_shake", "")

func _on_apple_eaten(body: Node3D, apple: Node3D) -> void:
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	if not is_instance_valid(apple) or apple.get_meta("eaten", false):
		return
	apple.set_meta("eaten", true)
	_apples_eaten += 1
	noticed.emit("咔嚓——真甜。（%d / 3）" % _apples_eaten)
	var crunch := UI.world_label("咔嚓——真甜。（%d / 3）" % _apples_eaten, 20, UI.WHITE, UI.INK)
	crunch.position = apple.position + Vector3(0, 0.8, 0)
	add_child(crunch)
	var t := create_tween()
	t.tween_property(crunch, "position:y", crunch.position.y + 0.6, 1.2)
	t.parallel().tween_property(crunch, "modulate:a", 0.0, 1.1)
	t.tween_callback(crunch.queue_free)
	var shrink := create_tween()
	shrink.tween_property(apple, "scale", Vector3.ZERO, 0.15)
	shrink.tween_callback(apple.queue_free)
	if _apples_eaten >= 3:
		_gag("三颗全吃完了。牛顿没告诉你的是：猪不用等苹果掉。", 2.6)
		played.emit("apples_all", "")

# ------------------------------------------------------------- helpers
func _gag_or(defaults: Array) -> String:
	if not gag_lines.is_empty():
		return gag_lines.pick_random()
	return defaults.pick_random()

func _gag(text: String, life := 1.8, offset := Vector3(0, 1.9, 0)) -> void:
	noticed.emit(text)
	var label := UI.world_label(text, 22, UI.WHITE, UI.TEAL_DEEP)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = offset
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", offset.y + 0.7, life)
	t.parallel().tween_property(label, "modulate:a", 0.0, life * 0.9)
	t.tween_callback(label.queue_free)

func _react_meteor_button() -> void:
	# The pen's red reset button: a hoof-weight press clicks the cap down and
	# calls the sky. The meteor itself is level-side (farm_grounds owns the
	# fall + prop reset); this only fires the "meteor" beat, rate-limited so a
	# dancing pig cannot summon a meteor shower.
	if not _ready_cool():
		return
	var cap := get_parent().get_node_or_null("ButtonCap") as Node3D
	if cap != null:
		var press := create_tween()
		press.tween_property(cap, "position:y", 0.12, 0.08)
		press.tween_property(cap, "position:y", 0.22, 0.2)
	_gag("咔哒。……天上有个小点在变大。", 2.2)
	played.emit("meteor", "")

func reset_prop() -> void:
	# Meteor impact: snap the parent prop back to its built transform and
	# re-arm one-shot gags (a toppled bucket stands back up, kicked cabbage
	# returns home, the mailbox flag re-lowers next time). Kill any in-flight
	# motion first - a living topple/kick tween would overwrite this transform
	# on its next step and leave the prop wrecked with its gag re-armed-dead.
	if _prop_tween != null and _prop_tween.is_valid():
		_prop_tween.kill()
	_prop_tween = null
	var parent := get_parent() as Node3D
	if parent != null:
		parent.transform = _home_transform
		if parent is RigidBody3D:
			# A rigid prop (the cabbage balls) keeps its momentum after the
			# transform snap - zero it, or the "reset" ball rolls straight
			# back out of its home spot.
			parent.linear_velocity = Vector3.ZERO
			parent.angular_velocity = Vector3.ZERO
	_one_shot_done = false
	_cool_timer = 0.0
