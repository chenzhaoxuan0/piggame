extends Node3D

# Opening key-test scene - the boot main menu. A cozy hilltop pen where the
# REAL PigController answers every key live (WASD walk, Space hop, Shift
# sprint/dodge, F/E/K trough snorts, click-to-move) so players learn the
# controls before the nightmare. The menu cards stay on the mouse: every
# button is FOCUS_NONE and never grabs focus, so the keyboard reaches the pig
# (a focused button would swallow Space/Enter as ui_accept).
# Hand-off: buttons set GameManager.pending_boot ("dream"/"farm") and switch
# to office_level_1, which consumes the flag in its _ready instead of showing
# its own start menu.

const UI = preload("res://scripts/ui/ui_kit.gd")
const PIG_SCENE = preload("res://scenes/characters/pig.tscn")
const ISO_CAMERA = preload("res://scripts/core/isometric_camera.gd")

const MUD := Color("8A6F4D")
const WOOD := Color("B98A5A")
const WOOD_DARK := Color("8F6A42")
const STRAW := Color("E8C86A")

var pig: PigController
var trough: StaticBody3D
var _keycaps := {} # action/key tag -> Array[PanelContainer]

func _ready() -> void:
	_build_stage()
	_build_pig()
	_build_camera()
	_build_ui()

# ------------------------------------------------------------- stage
func _build_stage() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.62, 0.72)
	sky_mat.sky_horizon_color = Color(0.96, 0.84, 0.68)
	sky_mat.ground_bottom_color = Color(0.32, 0.34, 0.26)
	sky_mat.ground_horizon_color = Color(0.88, 0.82, 0.66)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -55, 0)
	sun.light_color = Color(1.0, 0.9, 0.72)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)

	# Mud platform (collision layer 1: the pig's floor mask).
	_solid("PenFloor", Vector3(12, 1, 12), Vector3(0, -0.5, 0), MUD)
	# Low fence ring: tall enough to keep the pig in, low enough to see over.
	for rail in [
		{"name": "FenceN", "size": Vector3(12.4, 0.8, 0.4), "pos": Vector3(0, 0.4, -6.0)},
		{"name": "FenceS", "size": Vector3(12.4, 0.8, 0.4), "pos": Vector3(0, 0.4, 6.0)},
		{"name": "FenceW", "size": Vector3(0.4, 0.8, 12.4), "pos": Vector3(-6.0, 0.4, 0)},
		{"name": "FenceE", "size": Vector3(0.4, 0.8, 12.4), "pos": Vector3(6.0, 0.4, 0)},
	]:
		_solid(rail["name"], rail["size"], rail["pos"], WOOD)
	# Fence posts on the corners for a hand-built look (no collision needed,
	# they sit inside the rail line).
	for post in [Vector3(-6, 0.55, -6), Vector3(6, 0.55, -6), Vector3(-6, 0.55, 6), Vector3(6, 0.55, 6)]:
		_solid("FencePost", Vector3(0.55, 1.1, 0.55), post, WOOD_DARK)
	# Straw piles to hop over.
	for straw in [Vector3(-2.5, 0.28, -1.5), Vector3(3.2, 0.22, -2.8), Vector3(-3.4, 0.24, 2.8)]:
		var pile := _solid("Straw", Vector3(1.4, 0.55, 1.1), straw, STRAW)
		pile.rotation.y = randf() * TAU

	# The food trough: the one true interactable, so F/E/K get a real snort.
	trough = StaticBody3D.new()
	trough.name = "Trough"
	trough.position = Vector3(3.8, 0.35, 3.8)
	trough.collision_layer = 1
	trough.collision_mask = 0
	trough.set_meta("interaction_id", "trough")
	trough.add_to_group("interactable")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.7, 0.9)
	shape.shape = box
	trough.add_child(shape)
	var mesh := MeshInstance3D.new()
	var mesh_box := BoxMesh.new()
	mesh_box.size = box.size
	mesh.mesh = mesh_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WOOD_DARK
	mat.roughness = 0.9
	mesh.material_override = mat
	trough.add_child(mesh)
	add_child(trough)
	var tag := UI.world_label("食槽 · 按 F / E / K 拱一下", 22, UI.WHITE, UI.TEAL_DEEP)
	tag.position = Vector3(0, 1.5, 0)
	trough.add_child(tag)

func _solid(node_name: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	mesh.mesh = mesh_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body

# ------------------------------------------------------------- pig & camera
func _build_pig() -> void:
	pig = PIG_SCENE.instantiate() as PigController
	pig.position = Vector3(0, 0.6, 0)
	add_child(pig)
	# reset_at clears both flags, so arm them after the pig settles in.
	pig.set_dash_enabled(true) # Shift sprint with no skill gate - it's a demo pen
	pig.force_dodge_available = true # Tap-Shift dodge without a dog threat
	pig.reached_interactable.connect(_on_pig_interacted)
	pig.dodge_succeeded.connect(func(_dog):
		_snort("闪避！好身手！")
	)

func _build_camera() -> void:
	# No target_path needed: the isometric camera falls back to the first node
	# in the "player" group, and the pig is it.
	var cam := Camera3D.new()
	cam.name = "OpeningCamera"
	cam.set_script(ISO_CAMERA)
	add_child(cam)

# ------------------------------------------------------------- reactions
func _on_pig_interacted(target: Node3D) -> void:
	if target != trough:
		return
	_snort("哼哼！（拱得食槽哐当响）")
	var squash := create_tween()
	squash.tween_property(trough, "scale", Vector3(1.12, 0.72, 1.12), 0.08)
	squash.tween_property(trough, "scale", Vector3.ONE, 0.18)

func _snort(text: String) -> void:
	var popup := UI.world_label(text, 26, UI.WHITE, UI.TEAL_DEEP)
	popup.position = pig.global_position + Vector3(0, 1.8, 0)
	popup.modulate.a = 0.0
	add_child(popup)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(popup, "position:y", popup.position.y + 0.8, 0.8)
	t.tween_property(popup, "modulate:a", 1.0, 0.15)
	t.chain().tween_property(popup, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(popup.queue_free)

# ------------------------------------------------------------- UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "OpeningUI"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply(root)
	layer.add_child(root)

	# Menu card, left of centre - the pen stage stays visible behind it.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left = 72
	column.offset_top = -230
	root.add_child(column)

	var title := UI.banner("一口猪在金牌农场", 46)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(title)
	var subtitle := UI.name_tag("A PIG IN GOLDEN FARM · 今晚就逃离农场", UI.SUNNY, UI.INK, 15)
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(subtitle)

	var card := UI.patch_panel(22, UI.PAPER, UI.PINK, Vector2(26, 22))
	card.custom_minimum_size = Vector2(380, 0)
	column.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var btn_start := UI.button("▶  开始游戏（入梦序章）", _boot_to.bind("dream"), true)
	btn_start.name = "StartButton"
	btn_start.custom_minimum_size.y = 52
	vbox.add_child(btn_start)
	var btn_skip := UI.button("跳过序章，直接出圈", _boot_to.bind("farm"))
	btn_skip.name = "SkipIntroButton"
	btn_skip.custom_minimum_size.y = 36
	btn_skip.add_theme_font_size_override("font_size", 16)
	vbox.add_child(btn_skip)
	var btn_quit := UI.button("✕  退出游戏", func(): get_tree().quit())
	btn_quit.name = "QuitButton"
	btn_quit.custom_minimum_size.y = 40
	vbox.add_child(btn_quit)
	var hint := UI.label("菜单用鼠标点——键盘留给场上的猪 🐷", 14, UI.INK_SOFT)
	vbox.add_child(hint)
	# The whole point of this scene: keys must reach the pig, so no button
	# ever takes focus (a focused button eats Space/Enter as ui_accept).
	for btn in [btn_start, btn_skip, btn_quit]:
		btn.focus_mode = Control.FOCUS_NONE

	# Key-test strip along the bottom: keycap per bound key, lights up while
	# held (see _process).
	var strip := UI.patch_panel(18, UI.PAPER, UI.TEAL, Vector2(20, 12))
	strip.name = "KeyTestStrip"
	# MINSIZE preset centers the panel's own size on the bottom anchor (a plain
	# preset pins a zero-size box at the anchor and grows it off-screen).
	strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	strip.offset_top -= 24
	strip.offset_bottom -= 24
	root.add_child(strip)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	strip.add_child(rows)
	var caption := UI.label("开演前先试试蹄子——按键当场生效", 16, UI.TEAL_DEEP, true)
	caption.name = "KeyTestCaption"
	rows.add_child(caption)
	var line1 := HBoxContainer.new()
	line1.add_theme_constant_override("separation", 12)
	rows.add_child(line1)
	_key_group(line1, ["W", "A", "S", "D"], "移动", ["move_up", "move_left", "move_down", "move_right"])
	_key_group(line1, ["空格"], "跳跃", ["action_jump"])
	var line2 := HBoxContainer.new()
	line2.add_theme_constant_override("separation", 12)
	rows.add_child(line2)
	_key_group(line2, ["Shift"], "长按冲刺 · 点按闪避", ["action_dash"])
	_key_group(line2, ["F", "E", "K"], "拱食槽", ["action_interact", "action_interact", "action_interact"])
	_key_group(line2, ["🖱+"], "点击走位", ["__mouse__"])

func _key_group(row: HBoxContainer, keys: Array, desc: String, actions: Array) -> void:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	row.add_child(group)
	for i in keys.size():
		var cap := UI.keycap(keys[i], 15, UI.TEAL)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(cap)
		var tag: String = actions[i] if actions[i] != "__mouse__" else "__mouse__"
		if not _keycaps.has(tag):
			_keycaps[tag] = []
		_keycaps[tag].append(cap)
	var label := UI.label(" " + desc, 15, UI.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(label)

func _process(_delta: float) -> void:
	# Held-key highlight: every bound action lights its keycaps while down.
	for tag in _keycaps:
		var pressed := false
		if tag == "__mouse__":
			pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		else:
			pressed = Input.is_action_pressed(tag)
		var tint := UI.SUNNY if pressed else UI.WHITE
		for cap in _keycaps[tag]:
			cap.modulate = tint

# ------------------------------------------------------------- hand-off
func _boot_to(intent: String) -> void:
	GameManager.pending_boot = intent
	get_tree().change_scene_to_file("res://scenes/levels/office_level_1.tscn")
