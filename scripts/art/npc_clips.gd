extends RefCounted
## Runtime bone clips for the farm NPCs, built on the shared 8-bone rig
## (Root/Body/Head/Tail + LegLF/LegLB/LegRF/LegRB, farmer swaps legs for
## LegL/LegR + ArmL/ArmR). Keys are composed against each bone's rest pose so
## the clips layer cleanly onto the imported GLB skeleton. The models face -Z:
## a negative X euler pitches a head/neck DOWN toward the facing direction.
## No class_name on purpose: fresh class names are invisible to headless runs
## until the editor rescans the global class cache (see patrol_guard_dog.gd).

static func _skeleton(visual: Node3D) -> Skeleton3D:
	if visual == null: return null
	for candidate in visual.find_children("*", "Skeleton3D", true, false):
		return candidate
	return null

static func _rot_track(anim: Animation, visual: Node3D, skel: Skeleton3D, bone: String, keys: Array) -> void:
	var idx := skel.find_bone(bone)
	if idx < 0: return
	var track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, NodePath(str(visual.get_path_to(skel)) + ":" + bone))
	# get_rotation_quaternion() 先正交化：个别骨骼 rest 矩阵带镜像/缩放，
	# 直接 Quaternion(basis) 会报 "must be normalized" 并产生垃圾姿态。
	var rest_q := skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	for key in keys:
		anim.rotation_track_insert_key(track, key[0], rest_q * Quaternion.from_euler(key[1]))

static func _pos_track(anim: Animation, visual: Node3D, skel: Skeleton3D, bone: String, keys: Array) -> void:
	var idx := skel.find_bone(bone)
	if idx < 0: return
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath(str(visual.get_path_to(skel)) + ":" + bone))
	var rest := skel.get_bone_rest(idx).origin
	for key in keys:
		anim.position_track_insert_key(track, key[0], rest + key[1])

static func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)

## 老牛耕地：对角步态慢走 + 低头弓背拉犁 + 尾巴甩动。3.6s 循环。
static func plow(visual: Node3D) -> Animation:
	var skel := _skeleton(visual)
	if skel == null: return null
	var a := Animation.new()
	a.length = 3.6
	var swing_a := [[0.0, _v(0.32, 0, 0)], [0.9, _v(-0.28, 0, 0)], [1.8, _v(0.32, 0, 0)], [2.7, _v(-0.28, 0, 0)], [3.6, _v(0.32, 0, 0)]]
	var swing_b := [[0.0, _v(-0.28, 0, 0)], [0.9, _v(0.32, 0, 0)], [1.8, _v(-0.28, 0, 0)], [2.7, _v(0.32, 0, 0)], [3.6, _v(-0.28, 0, 0)]]
	_rot_track(a, visual, skel, "LegLF", swing_a)
	_rot_track(a, visual, skel, "LegRB", swing_a)
	_rot_track(a, visual, skel, "LegRF", swing_b)
	_rot_track(a, visual, skel, "LegLB", swing_b)
	_rot_track(a, visual, skel, "Head", [[0.0, _v(-0.5, 0, 0)], [1.8, _v(-0.42, 0, 0.04)], [3.6, _v(-0.5, 0, 0)]])
	_rot_track(a, visual, skel, "Body", [[0.0, _v(-0.1, 0, 0)], [1.8, _v(-0.14, 0, 0)], [3.6, _v(-0.1, 0, 0)]])
	_rot_track(a, visual, skel, "Tail", [[0.0, _v(0, 0.25, 0)], [1.8, _v(0, -0.25, 0)], [3.6, _v(0, 0.25, 0)]])
	_pos_track(a, visual, skel, "Body", [[0.0, Vector3.ZERO], [0.9, _v(0, -0.02, 0)], [1.8, Vector3.ZERO], [2.7, _v(0, -0.02, 0)], [3.6, Vector3.ZERO]])
	return a

## 小羊闷闷不乐：耷拉着脑袋、慢慢摇晃、轻轻呼吸。6s 循环。
static func mope(visual: Node3D) -> Animation:
	var skel := _skeleton(visual)
	if skel == null: return null
	var a := Animation.new()
	a.length = 6.0
	_rot_track(a, visual, skel, "Head", [[0.0, _v(-0.55, 0.06, 0)], [3.0, _v(-0.5, -0.06, 0)], [6.0, _v(-0.55, 0.06, 0)]])
	_rot_track(a, visual, skel, "Body", [[0.0, _v(0, 0, 0.035)], [3.0, _v(0, 0, -0.035)], [6.0, _v(0, 0, 0.035)]])
	_rot_track(a, visual, skel, "Tail", [[0.0, _v(0.35, 0, 0)]])
	_pos_track(a, visual, skel, "Body", [[0.0, Vector3.ZERO], [1.5, _v(0, 0.02, 0)], [3.0, Vector3.ZERO], [4.5, _v(0, 0.02, 0)], [6.0, Vector3.ZERO]])
	return a

## 小羊叹气：头抬一下又垂得更低，身子跟着塌下去。2.4s 单次。
static func sigh(visual: Node3D) -> Animation:
	var skel := _skeleton(visual)
	if skel == null: return null
	var a := Animation.new()
	a.length = 2.4
	_rot_track(a, visual, skel, "Head", [[0.0, _v(-0.55, 0, 0)], [0.7, _v(-0.2, 0, 0)], [1.6, _v(-0.62, 0, 0)], [2.4, _v(-0.55, 0, 0)]])
	_pos_track(a, visual, skel, "Body", [[0.0, Vector3.ZERO], [0.7, _v(0, 0.03, 0)], [1.6, _v(0, -0.035, 0)], [2.4, Vector3.ZERO]])
	return a

## 追风原地刨蹄甩头：等人对话时的小动作。1.5s 单次。
static func stamp(visual: Node3D) -> Animation:
	var skel := _skeleton(visual)
	if skel == null: return null
	var a := Animation.new()
	a.length = 1.5
	_rot_track(a, visual, skel, "LegLF", [[0.0, Vector3.ZERO], [0.3, _v(0.75, 0, 0)], [0.55, _v(-0.15, 0, 0)], [0.8, _v(0.3, 0, 0)], [1.0, Vector3.ZERO], [1.5, Vector3.ZERO]])
	_rot_track(a, visual, skel, "Head", [[0.0, _v(-0.1, 0, 0)], [0.5, _v(0.25, 0, 0)], [1.0, _v(-0.15, 0, 0)], [1.5, _v(-0.1, 0, 0)]])
	_pos_track(a, visual, skel, "Body", [[0.0, Vector3.ZERO], [0.55, _v(0, -0.05, 0)], [1.0, Vector3.ZERO], [1.5, Vector3.ZERO]])
	return a

## 农场主拄棍警戒：重心换脚、电击棍手臂轻晃、抬头环视。4.5s 循环。
static func guard(visual: Node3D) -> Animation:
	var skel := _skeleton(visual)
	if skel == null: return null
	var a := Animation.new()
	a.length = 4.5
	_rot_track(a, visual, skel, "Body", [[0.0, _v(0, 0, 0.03)], [2.25, _v(0, 0, -0.03)], [4.5, _v(0, 0, 0.03)]])
	_rot_track(a, visual, skel, "ArmL", [[0.0, _v(0.12, 0, 0)], [1.1, _v(-0.2, 0, 0)], [2.25, _v(0.12, 0, 0)], [3.4, _v(-0.05, 0, 0)], [4.5, _v(0.12, 0, 0)]])
	_rot_track(a, visual, skel, "ArmR", [[0.0, _v(-0.05, 0, 0)], [2.25, _v(0.08, 0, 0)], [4.5, _v(-0.05, 0, 0)]])
	_rot_track(a, visual, skel, "Head", [[0.0, _v(0, 0.14, 0)], [2.25, _v(0, -0.14, 0)], [4.5, _v(0, 0.14, 0)]])
	return a

## 猪猪拱地嗅嗅： idle 太久时自己找乐子。1.9s 单次。
static func snuffle(visual: Node3D) -> Animation:
	var skel := _skeleton(visual)
	if skel == null: return null
	var a := Animation.new()
	a.length = 1.9
	_rot_track(a, visual, skel, "Head", [[0.0, Vector3.ZERO], [0.35, _v(-0.4, 0, 0)], [0.7, _v(-0.15, 0, 0)], [1.05, _v(-0.42, 0, 0)], [1.4, _v(-0.1, 0, 0)], [1.9, Vector3.ZERO]])
	_rot_track(a, visual, skel, "Tail", [[0.0, Vector3.ZERO], [0.3, _v(0, 0.5, 0)], [0.6, _v(0, -0.5, 0)], [0.9, _v(0, 0.5, 0)], [1.2, _v(0, -0.5, 0)], [1.9, Vector3.ZERO]])
	_pos_track(a, visual, skel, "Body", [[0.0, Vector3.ZERO], [0.5, _v(0, -0.02, 0)], [1.2, _v(0, -0.02, 0)], [1.9, Vector3.ZERO]])
	return a
