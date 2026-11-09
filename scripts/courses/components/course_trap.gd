extends Node3D
class_name CourseTrap

@export var meme_id: String = ""
@export var telegraph_meme_id: String = ""

func _is_player(body: Node3D) -> bool:
	return body is PigController

func _is_dog(body: Node3D) -> bool:
	return body is ChaseDog or body.has_method("stun")

func _knock(body: Node3D, impulse: Vector3, duration: float = 0.65) -> void:
	if body.has_method("apply_knockback"):
		body.apply_knockback(impulse, duration)

func _hit_dog(dog: Node3D, stun_duration: float = 2.0, knockback: Vector3 = Vector3.ZERO) -> void:
	if dog.has_method("stun"):
		dog.stun(stun_duration, knockback)

func _meme(id: String, pos: Vector3) -> void:
	if id.is_empty():
		return
	for node in get_tree().get_nodes_in_group("meme_layer"):
		if node.has_method("play"):
			node.play(id, pos)
			return

func _flat_dir(from: Vector3, to: Vector3, fallback: Vector3 = Vector3.FORWARD) -> Vector3:
	var dir: Vector3 = to - from
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.01 else fallback
