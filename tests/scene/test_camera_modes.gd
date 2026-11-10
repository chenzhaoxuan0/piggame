extends SceneTree
# Third-person chase camera regression tests:
# - mode switch resets the RMB drag state and aligns yaw to the track
# - with auto-follow disabled (course mode) sideways velocity never rotates the camera
# - with auto-follow enabled the deadzone smoothing still tracks the move direction
# - snap_to_target(yaw) aims the basis exactly and keeps zero roll
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("CAMERA_MODES_TEST %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func _run() -> void:
	var world := Node3D.new()
	world.name = "CameraTestWorld"
	root.add_child(world)

	var pig := CharacterBody3D.new()
	pig.add_to_group("player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 0.9
	shape.shape = capsule
	pig.add_child(shape)
	world.add_child(pig)
	pig.global_position = Vector3(0, 1, 0)

	var camera: Camera3D = load("res://scripts/core/isometric_camera.gd").new()
	camera.mode = 0 # ISOMETRIC
	world.add_child(camera)
	camera.target = pig
	await physics_frame
	await physics_frame

	_check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "starts orthographic in farm mode")

	# Simulate a stuck right-drag from before the world switch.
	camera._rmb_dragging = true
	camera.set_camera_mode(1) # THIRD_PERSON
	_check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "switches to perspective in course mode")
	_check(camera._rmb_dragging == false, "mode switch clears a stale right-drag state")
	_check(absf(camera._tp_yaw) < 0.001, "course entry yaw looks down the track (-Z)")

	# Locked yaw: the pig runs sideways (camera right = +X at yaw 0); the camera must not turn.
	camera.tp_auto_follow_yaw = false
	for i in 60:
		pig.velocity = Vector3(4.0, 0.0, 0.0)
		pig.move_and_slide()
		await physics_frame
	_check(absf(wrapf(camera._tp_yaw, -PI, PI)) < 0.001, "auto-follow off: sustained sideways running keeps the yaw locked")

	# Auto-follow enabled: a 45-degree course change must rotate the camera through the
	# deadzone smoothing (regression guard for the follow math itself).
	camera.tp_auto_follow_yaw = true
	for i in 60:
		pig.velocity = Vector3(3.2, 0.0, -3.2)
		pig.move_and_slide()
		await physics_frame
	_check(camera._tp_yaw < -0.05, "auto-follow on: a sustained diagonal rotates yaw toward the move direction (got %.3f)" % camera._tp_yaw)

	# snap_to_target(yaw) aims the basis exactly, with zero roll (right axis stays horizontal).
	camera.snap_to_target(PI / 2.0)
	var forward := -camera.global_basis.z
	_check(forward.x < -0.95 and absf(forward.z) < 0.05, "snap aims the basis at the requested yaw")
	_check(absf(camera.global_basis.x.y) < 0.01, "snapped basis keeps the horizon level (zero roll)")

	print("CAMERA_MODES_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
