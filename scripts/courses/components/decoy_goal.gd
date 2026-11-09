extends CourseTrap
class_name DecoyGoal

@export var bounce_power: float = 7.0
@export var bounce_up: float = 4.0
@export var cooldown: float = 1.2
@export var real_exit_hint_path: NodePath

var _timer := 0.0
var _triggered_once := false

func _ready() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.5, 1.0)
	shape.shape = box
	shape.position.y = 1.25
	area.add_child(shape)
	area.body_entered.connect(_on_enter)
	add_child(area)
	var hint := get_node_or_null(real_exit_hint_path) as Node3D
	if hint:
		hint.visible = false

func _physics_process(delta: float) -> void:
	_timer = maxf(0.0, _timer - delta)

func _on_enter(body: Node3D) -> void:
	if not _is_player(body) or _timer > 0.0:
		return
	_timer = cooldown
	var dir := _flat_dir(global_position, body.global_position, Vector3.BACK)
	_knock(body, dir * bounce_power + Vector3.UP * bounce_up, 0.6)
	if not _triggered_once:
		_triggered_once = true
		_meme(meme_id, global_position)
		var hint := get_node_or_null(real_exit_hint_path) as Node3D
		if hint:
			hint.visible = true
	else:
		_meme(telegraph_meme_id, global_position)