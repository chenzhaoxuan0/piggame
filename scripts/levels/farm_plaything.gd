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

enum Kind { GRASS, TIPPABLE, CABBAGE, HAYSTACK, BEEHIVE, MAILBOX, HORN, MUDPIT, NEST }

const UI = preload("res://scripts/ui/ui_kit.gd")

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

func _ready() -> void:
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
	tween.tween_property(prop, "basis", Basis(Vector3.UP, yaw) * fall, 0.4)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_gag(_gag_or(["咣当！它滚了三圈。", "哗啦——另一件农具殉职。", "轰隆。农场主不知道，猪知道。"]))
	played.emit("tippable", name)

func _react_cabbage(body: Node3D) -> void:
	# The kick: hop away from the pig with a little roll. One hop per touch.
	if not _ready_cool():
		return
	var away := global_position - body.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.BACK
	away = away.normalized()
	var hop := away * 1.7
	var ball := get_parent() # the cabbage body this plaything rides in
	var tween := create_tween()
	tween.tween_property(ball, "position:y", ball.position.y + 0.55, 0.12)
	tween.tween_property(ball, "position", ball.position + hop, 0.16)
	tween.parallel().tween_property(ball, "rotation:x", ball.rotation.x + TAU, 0.28)
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

# ------------------------------------------------------------- helpers
func _gag_or(defaults: Array) -> String:
	if not gag_lines.is_empty():
		return gag_lines.pick_random()
	return defaults.pick_random()

func _gag(text: String, life := 1.8, offset := Vector3(0, 1.9, 0)) -> void:
	var label := UI.world_label(text, 22, UI.WHITE, UI.TEAL_DEEP)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = offset
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", offset.y + 0.7, life)
	t.parallel().tween_property(label, "modulate:a", 0.0, life * 0.9)
	t.tween_callback(label.queue_free)
