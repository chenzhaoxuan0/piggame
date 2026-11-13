extends Node3D

# Opening boot menu. The old floating key-test pen lived here - it was a
# 12x12 platform with no ground below and no fall rescue, so hopping out of
# the fence meant falling forever (the 架空层 bug). The pig now learns its
# keys in the REAL pigpen instead: "farm" boot drops it into the pen with a
# key-test strip in the HUD (office_level_1._start_pigpen_tutorial), and this
# scene is a plain menu over a sky.
# Hand-off: buttons set GameManager.pending_boot ("dream"/"farm") and switch
# to office_level_1, which consumes the flag in its _ready instead of showing
# its own start menu.

const UI = preload("res://scripts/ui/ui_kit.gd")
const GAME_MENUS = preload("res://scripts/ui/menus.gd")

var _ui_root: Control
var achievements_panel: Control

func _ready() -> void:
	_build_stage()
	_build_ui()

# ------------------------------------------------------------- backdrop
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
	add_child(sun)

	# Static camera on the horizon: without any camera the 3D sky never draws
	# and the menu sits on flat grey.
	var cam := Camera3D.new()
	cam.name = "MenuCamera"
	cam.position = Vector3(0, 1.6, 0)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	add_child(cam)
	cam.current = true

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
	_ui_root = root

	# Menu card, centred left - the sky backdrop stays visible behind it.
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
	var btn_achv := UI.button("🏅  成就墙", _open_achievements_panel)
	btn_achv.name = "AchievementsButton"
	btn_achv.custom_minimum_size.y = 40
	vbox.add_child(btn_achv)
	var btn_quit := UI.button("✕  退出游戏", func(): get_tree().quit())
	btn_quit.name = "QuitButton"
	btn_quit.custom_minimum_size.y = 40
	vbox.add_child(btn_quit)
	var hint := UI.label("菜单用鼠标点——键位教学搬进了开场猪圈 🐷", 14, UI.INK_SOFT)
	vbox.add_child(hint)
	# Keyboard reaches nothing here any more, but keep buttons focus-free so
	# Enter/Space can never double-fire a focused button mid-click.
	for btn in [btn_start, btn_skip, btn_achv, btn_quit]:
		btn.focus_mode = Control.FOCUS_NONE

# ------------------------------------------------------------- hand-off
func _open_achievements_panel() -> void:
	if achievements_panel == null:
		achievements_panel = GAME_MENUS.build_achievements_menu(_ui_root, _close_achievements_panel)
	GAME_MENUS.refresh_achievements_menu(achievements_panel)
	achievements_panel.visible = true

func _close_achievements_panel() -> void:
	if achievements_panel != null:
		achievements_panel.visible = false

func _boot_to(intent: String) -> void:
	GameManager.pending_boot = intent
	get_tree().change_scene_to_file("res://scenes/levels/office_level_1.tscn")
