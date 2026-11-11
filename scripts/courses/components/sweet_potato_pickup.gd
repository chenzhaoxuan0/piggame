extends Area3D

# Collectible golden sweet potato for the creek's cliff stairs. The stairs used
# to show identical potatoes as pure decoration; now they are a real optional
# pickup. The node itself is a dumb pickup: popup + signal, and the COURSE owns
# the speed buff - a wall-clock SceneTreeTimer here used to outlive the course
# and carried the boost into the farm, and stacking three potatoes hit 2.2x.
# (No class_name self-references: fresh class names are invisible to headless
# runs until the editor rescans the global class cache - see race_timer.gd.)

signal potato_collected(potato: Node3D, player: Node3D)

const COLOR_GOLD := Color("F59E0B")

var is_collected: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player

	var col := CollisionShape3D.new()
	col.name = "PotatoCol"
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.9, 0.7)
	col.shape = box
	col.position.y = 0.45
	add_child(col)

	var mesh := MeshInstance3D.new()
	mesh.name = "PotatoMesh"
	var potato_mesh := BoxMesh.new()
	potato_mesh.size = Vector3(0.42, 0.42, 0.42)
	mesh.mesh = potato_mesh
	mesh.position.y = 0.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_GOLD
	mat.emission_enabled = true
	mat.emission = Color("FBBF24")
	mat.emission_energy_multiplier = 1.2
	mesh.material_override = mat
	add_child(mesh)

	var spin := create_tween()
	spin.set_loops()
	spin.tween_property(mesh, "rotation:y", TAU, 1.2)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	if not body.is_in_group("player") and not body.name.to_lower().contains("pig"):
		return
	is_collected = true

	var popup := Label3D.new()
	popup.text = "🍠 +1"
	popup.font_size = 22
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.modulate = Color("FACC15")
	popup.outline_modulate = Color("78350F")
	popup.outline_size = 5
	popup.position = Vector3(0, 1.6, 0)
	body.add_child(popup)
	var tw := popup.create_tween()
	tw.tween_property(popup, "position:y", popup.position.y + 1.0, 0.8)
	tw.tween_callback(popup.queue_free)

	potato_collected.emit(self, body)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector3.ONE * 0.05, 0.15)
	pop.tween_callback(queue_free)
