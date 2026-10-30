extends Camera3D

class_name IsometricCamera

# 2.5D Isometric Camera (参考 Untitled Goose Game 经典视角)
# 45度倾角 + 俯视斜角，带平滑跟随与动态距离调节

@export var target_path: NodePath
@export var smooth_speed: float = 5.0
@export var camera_offset: Vector3 = Vector3(10.0, 12.0, 10.0)
@export var look_ahead_factor: float = 1.5

var target: Node3D = null

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node(target_path)
	
	# 设置相机的斜向旋转角度
	# 俯角约 35度，水平旋转 45度
	rotation_degrees = Vector3(-35.0, 45.0, 0.0)

func _physics_process(delta: float) -> void:
	if not target:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
		else:
			return

	# 计算目标位置（包含一定前方预判）
	var target_pos = target.global_position + camera_offset
	
	# 平滑跟随
	global_position = global_position.lerp(target_pos, smooth_speed * delta)

