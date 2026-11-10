class_name CardboardBoxProp
extends Node3D

signal box_equipped(player: Node3D)
signal box_unequipped(player: Node3D)

@export var box_size: Vector3 = Vector3(1.6, 1.4, 2.0)

const COLOR_CARDBOARD := Color("B45309") # Warm cardboard kraft
const COLOR_LABEL := Color("FEF3C7")

var is_equipped: bool = false
var current_player: Node3D = null
var interact_area: Area3D
var box_mesh: MeshInstance3D

func _ready() -> void:
	_setup_visual()
	_setup_interact_area()

func _setup_visual() -> void:
	box_mesh = MeshInstance3D.new()
	box_mesh.name = "BoxMesh"
	var cube := BoxMesh.new()
	cube.size = box_size
	box_mesh.mesh = cube
	box_mesh.position.y = box_size.y * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CARDBOARD
	mat.roughness = 0.8
	box_mesh.material_override = mat
	add_child(box_mesh)

	# Label on the box
	var lbl := Label3D.new()
	lbl.name = "BoxLogo"
	lbl.text = "THE ORANGE\n一口猪专属纸箱"
	lbl.font_size = 20
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color("1E293B")
	lbl.position = Vector3(0, box_size.y + 0.3, 0)
	add_child(lbl)

func _setup_interact_area() -> void:
	interact_area = Area3D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 0
	interact_area.collision_mask = 2 # Player

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(box_size.x + 1.2, box_size.y + 1.0, box_size.z + 1.2)
	col.shape = box
	col.position.y = box_size.y * 0.5
	interact_area.add_child(col)

	interact_area.body_entered.connect(_on_player_entered)
	add_child(interact_area)

func _on_player_entered(body: Node3D) -> void:
	if is_equipped:
		return
	if body.is_in_group("player") or body.name.to_lower().contains("pig"):
		equip_box(body)

func equip_box(player: Node3D) -> void:
	if is_equipped:
		return
	is_equipped = true
	current_player = player

	# Attach visual to player
	reparent(player)
	position = Vector3(0, 0.2, 0)
	player.set_meta("in_stealth_box", true)
	box_equipped.emit(player)

func unequip_box() -> void:
	if not is_equipped or current_player == null:
		return
	is_equipped = false
	current_player.set_meta("in_stealth_box", false)
	var prev_player := current_player
	current_player = null
	box_unequipped.emit(prev_player)
	queue_free()
