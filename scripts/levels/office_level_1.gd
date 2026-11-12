extends Node3D

const CHASE_SCRIPT = preload("res://scripts/chase/simple_chase.gd")
const ART_2D = preload("res://scripts/art/art_2d.gd")
const L = preload("res://scripts/levels/farm_layout.gd")
const POKEMON_SHOWDOWN = preload("res://scripts/battle/pokemon_showdown.gd")
const GAME_HUD = preload("res://scripts/ui/game_hud.gd")
const GAME_MENUS = preload("res://scripts/ui/menus.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")
const COURSE_SCENES = {
	"course_0": preload("res://scenes/courses/course_00_nightmare.tscn"),
	"course_1": preload("res://scenes/courses/course_01_ox_field.tscn"),
	"chase_1_course": preload("res://scenes/courses/course_01_ox_field.tscn"),
	"course_2": preload("res://scenes/courses/course_02_creek.tscn"),
	"chase_2_course": preload("res://scenes/courses/course_02_creek.tscn"),
	"course_3": preload("res://scenes/courses/course_03_woodland.tscn"),
	"chase_3_course": preload("res://scenes/courses/course_03_woodland.tscn"),
	"course_4": preload("res://scenes/courses/course_04_courtyard.tscn"),
	"chase_4_course": preload("res://scenes/courses/course_04_courtyard.tscn"),
	"chase_final_course": preload("res://scenes/courses/course_04_courtyard.tscn"),
}

@onready var player: PigController = $Pig
@onready var camera: IsometricCamera = $IsometricCamera
@onready var farm: Node3D = $Farm

var pokemon_battle: Control = null

var chase: SimpleChase
var active_course: Node3D = null
var _farm_removed := false
var hud: Control
var objective: Label # removed with the top title bar; guidance lives in the todo notebook
var status: Label
var prompt: Label
var dialogue_panel: PanelContainer
var speaker_label: Label
var content_label: Label
var line_hint: Label
var options: VBoxContainer
var overlay: ColorRect
var overlay_title: Label
var overlay_text: Label
var overlay_buttons: VBoxContainer
var dialogue_open := false
var cinematic := false
var paused := false
var busy := false
var current_dialogue := ""
var current_options: Array = []
var dialogue_lines: Array = []
var line_index := 0
var pressure := 999.0
var pin_visual: Node3D
var portrait: TextureRect
var ending_art: TextureRect

var in_start_menu := true
var in_settings := false
var settings_from_start := false
var achievements_from_start := false
var start_menu: Control
var pause_menu: Control
var settings_menu: Control
var achievements_menu: Control

# Untitled Goose Game Style UI Extensions
var todo_notebook: PanelContainer
var todo_vbox: VBoxContainer
var todo_toggle_btn: Button
var todo_folded := false
var qte_panel: PanelContainer
var qte_btn_label: Label
var qte_desc_label: Label
var qte_counter_label: Label
var qte_bar: ProgressBar
var qte_timer_bar: ProgressBar
var toast_panel: PanelContainer
var toast_title: Label
var toast_desc: Label
var dash_gauge: Control
var dash_bar: ProgressBar

# Skill Unlock Card Modal
var skill_card_modal: PanelContainer
var skill_card_title: Label
var skill_card_subtitle: Label
var skill_card_key_label: Label
var skill_card_desc_label: Label
var skill_card_btn: Button
var in_skill_card := false

# Chase & QTE logic state
var current_chase_id := ""
var in_qte := false
var current_qte_dog: ChaseDog = null
var qte_hits := 0
const QTE_TARGET_HITS := 5
var qte_time_remaining := 3.5
const QTE_TIME_TOTAL := 3.5

func _ready() -> void:
	GameManager.reset_run()
	chase = CHASE_SCRIPT.new()
	add_child(chase)
	chase.finished.connect(_on_chase_finished)
	chase.pressure_changed.connect(func(value: float): pressure = value)
	chase.qte_requested.connect(_on_qte_requested)
	
	player.reached_interactable.connect(_on_interact)
	player.qte_tapped.connect(_on_qte_tapped)
	player.dash_state_changed.connect(_on_player_dash_changed)
	player.dodge_succeeded.connect(_on_player_dodge_succeeded)
	
	farm.chase_entered.connect(_start_chase)
	if farm.has_signal("chase_triggered"):
		farm.chase_triggered.connect(_on_farm_chase_triggered)
	if farm.has_signal("stage_chase_completed"):
		farm.stage_chase_completed.connect(_on_farm_gate_passed)
	if farm.has_signal("secret_pipe_entered"):
		farm.secret_pipe_entered.connect(_on_secret_pipe_entered)
		
	GameManager.state_changed.connect(_refresh_hud)
	
	_build_hud()
	_build_pin()
	player.reset_at(farm.get_spawn_position())
	camera.snap_to_target()
	_refresh_hud()
	# The opening key-test scene hands off through GameManager.pending_boot
	# (survives the reset_run() above by design). No flag means a direct
	# instantiate - tests and captures still get the classic start menu.
	match GameManager.pending_boot:
		"dream":
			GameManager.pending_boot = ""
			_start_dream_intro()
		"farm":
			GameManager.pending_boot = ""
			skip_dream_intro()
		_:
			_show_start_menu()

func _build_pin() -> void:
	pin_visual = preload("res://scripts/art/asset_library.gd").make("PROP_03")
	if pin_visual == null:
		pin_visual = MeshInstance3D.new()
		_build_fallback_pin(pin_visual)
	player.get_node("VisualMesh").add_child(pin_visual)
	pin_visual.position = Vector3(0, 0.55, -0.9)
	preload("res://scripts/art/asset_library.gd").attach_to_bone(player.get_node_or_null("VisualMesh/CHAR_01"), "Head", pin_visual, pin_visual.position)
	pin_visual.visible = false

func _build_fallback_pin(mesh_node: MeshInstance3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.08, 0.08)
	mesh_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c9984d")
	mesh_node.material_override = material

func _style(bg: Color, border: Color = Color(0.40, 0.38, 0.30), radius: int = 12) -> StyleBoxFlat:
	return UI.patch(radius, bg)

func _label(text_value: String, font_size: int = 18) -> Label:
	return UI.label(text_value, font_size)

func _button(text_value: String, callback: Callable, align_left: bool = false) -> Button:
	var button := UI.button(text_value, callback)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if align_left:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button

func _build_hud() -> void:
	# UI construction lives in scripts/ui/game_hud.gd and scripts/ui/menus.gd; this
	# level script keeps the state, signal wiring and behavior that drive those nodes.
	GAME_HUD.build_all(self)
	_wire_dialogue_panel()
	_build_pokemon_battle()
	GAME_MENUS.build_all(self)
	achievements_menu = GAME_MENUS.build_achievements_menu(hud, _close_achievements)

func _wire_dialogue_panel() -> void:
	dialogue_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if dialogue_open and not busy and not cinematic and (pokemon_battle == null or not pokemon_battle.battle_active):
				_advance_dialogue()
	)

func _build_pokemon_battle() -> void:
	pokemon_battle = POKEMON_SHOWDOWN.new()
	pokemon_battle.name = "PokemonShowdown"
	hud.add_child(pokemon_battle)
	pokemon_battle.battle_completed.connect(_on_pokemon_battle_finished)

# -------------------------------------------------------------
# Untitled Goose Game Style: To-Do Notebook
# -------------------------------------------------------------
func _refresh_todo_list() -> void:
	if not is_instance_valid(todo_vbox): return
	_clear_children(todo_vbox)
	var items: Array[Dictionary] = GameManager.get_to_do_items()
	
	# Show active item and recent items in Goose Game fashion
	var shown_count := 0
	for item in items:
		var is_done: bool = item.get("done", false)
		var text: String = str(item.get("text", ""))
		
		# Skip far future tasks to keep the notebook concise
		if not is_done and shown_count >= 3:
			continue
			
		var item_label := UI.label("", 15)
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		if is_done:
			item_label.text = "✓  " + text
			item_label.add_theme_color_override("font_color", Color(UI.INK_SOFT, 0.75))
		else:
			item_label.text = "●  " + text
			item_label.add_theme_color_override("font_color", UI.INK)
			shown_count += 1

		todo_vbox.add_child(item_label)

		if is_done:
			var strike_rect := ColorRect.new()
			strike_rect.color = Color(UI.CORAL, 0.8)
			strike_rect.custom_minimum_size = Vector2(0, 2)
			item_label.add_child(strike_rect)
			strike_rect.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			strike_rect.offset_top = 0
			strike_rect.offset_bottom = 2
			strike_rect.offset_left = 18
			strike_rect.offset_right = 260

# -------------------------------------------------------------
# Untitled Goose Game Style: QTE Struggle Panel
# -------------------------------------------------------------
func _on_qte_requested(dog: ChaseDog) -> void:
	if in_qte or dialogue_open or cinematic or paused:
		# Roll the course runner back: it sets in_qte before emitting, and a refused
		# request would otherwise wedge its grapple system until a fatal respawn.
		if is_instance_valid(active_course) and active_course.runner.in_qte:
			active_course.runner.reject_qte(dog)
		return
	in_qte = true
	current_qte_dog = dog
	qte_hits = 0
	qte_time_remaining = QTE_TIME_TOTAL
	qte_bar.value = 0
	qte_timer_bar.value = QTE_TIME_TOTAL
	if is_instance_valid(qte_counter_label):
		qte_counter_label.text = "0 / %d" % QTE_TARGET_HITS
	
	if GameManager.has_struggle_skill:
		qte_btn_label.text = "【 狂按空格键 / SPACE 】"
		qte_desc_label.text = "借老牛坚韧硬骨气 · 狂敲按键挣脱重负！"
	else:
		qte_btn_label.text = "【 狂按空格键 / SPACE 拼命挣扎 】"
		qte_desc_label.text = "被过往阴影缠住！拼命按空格尝试挣脱！"
		
	qte_panel.visible = true
	if is_instance_valid(prompt): prompt.visible = false
	player.set_control_mode("qte")
	
	# Bounce punch animation on QTE pop
	qte_panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.tween_property(qte_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_qte_tapped() -> void:
	if not in_qte: return
	qte_hits += 1
	qte_bar.value = qte_hits
	if is_instance_valid(qte_counter_label):
		qte_counter_label.text = "%d / %d" % [qte_hits, QTE_TARGET_HITS]
	
	# Punch pop on hit
	var tween := create_tween()
	tween.tween_property(qte_btn_label, "scale", Vector2(1.15, 1.15), 0.04)
	tween.tween_property(qte_btn_label, "scale", Vector2.ONE, 0.08)
	
	if qte_hits >= QTE_TARGET_HITS:
		_finish_qte(true)

func _finish_qte(success: bool) -> void:
	if not in_qte: return
	in_qte = false
	qte_panel.visible = false
	var dog := current_qte_dog
	current_qte_dog = null
	if success:
		AchievementManager.unlock("grapple_escape")

	if is_instance_valid(active_course):
		active_course.runner.resolve_qte(dog, success)
		player.set_control_mode("chase")
		if success:
			_show_toast("挣脱成功！", "借老牛之力震退恶犬，继续闯关！")
		return

	if success:
		var toast_desc_text := "借老牛之力震退恶犬，继续跑！" if GameManager.has_struggle_skill else "挣脱了恶犬的纠缠，快跑！"
		_show_toast("挣脱成功！", toast_desc_text)
		chase.resolve_qte(dog, true)
		player.set_control_mode("chase")
	else:
		chase.resolve_qte(dog, false)

# -------------------------------------------------------------
# Untitled Goose Game Style: Skill Unlock Modal
# -------------------------------------------------------------
func _show_skill_unlock(title_text: String, subtitle_text: String, key_text: String, desc_text: String) -> void:
	in_skill_card = true
	player.set_control_mode("cinematic")
	skill_card_title.text = title_text
	skill_card_subtitle.text = subtitle_text
	skill_card_key_label.text = key_text
	skill_card_desc_label.text = desc_text
	skill_card_modal.visible = true
	skill_card_btn.grab_focus()
	
	# Pop scale spring animation
	skill_card_modal.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.tween_property(skill_card_modal, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _dismiss_skill_card() -> void:
	if not in_skill_card: return
	in_skill_card = false
	skill_card_modal.visible = false
	_restore_control()
	_refresh_hud()

# -------------------------------------------------------------
# Dash Sprint Gauge (Horse Pasture Power)
# -------------------------------------------------------------
func _on_player_dash_changed(remaining: float, _cooldown: float) -> void:
	if not is_instance_valid(dash_gauge): return
	var battle_on: bool = is_instance_valid(pokemon_battle) and pokemon_battle.battle_active
	if not GameManager.has_dash_skill or battle_on:
		dash_gauge.visible = false
		return
	dash_gauge.visible = true
	if is_instance_valid(dash_bar):
		var max_val: float = player.max_stamina if is_instance_valid(player) else 3.0
		dash_bar.max_value = max_val
		dash_bar.value = remaining
		var fill_style: StyleBoxFlat = dash_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if is_instance_valid(player) and player.is_sprinting:
				fill_style.bg_color = Color(0.95, 0.55, 0.18) # Active sprint energetic orange
			elif remaining < max_val:
				fill_style.bg_color = Color(0.85, 0.70, 0.25) # Recharging warm gold
			else:
				fill_style.bg_color = Color(0.42, 0.75, 0.38) # Full stamina green

func _on_player_dodge_succeeded(_dog: Node3D) -> void:
	AchievementManager.unlock("first_dodge")
	_show_toast("★ 闪避成功！", "灵巧侧身闪过恶犬扑杀！")

# -------------------------------------------------------------
# Ambient Toast Banner (Goose Game Subtitle)
# -------------------------------------------------------------
func _place_toast() -> void:
	if not is_instance_valid(toast_panel): return
	# 对话打开时横幅上移到对话面板上方，避免盖住台词与选项。
	if is_instance_valid(dialogue_panel) and dialogue_panel.visible:
		toast_panel.offset_top = -386
		toast_panel.offset_bottom = -322
	else:
		toast_panel.offset_top = -142
		toast_panel.offset_bottom = -78

func _show_toast(title_text: String, desc_text: String) -> void:
	if not is_instance_valid(toast_panel): return
	toast_title.text = title_text
	toast_desc.text = desc_text
	_place_toast()
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.5)
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): toast_panel.visible = false)

# -------------------------------------------------------------
# Menus: Start, Pause, Settings
# -------------------------------------------------------------
func _select_level_from_settings(target_id: String) -> void:
	_close_settings()
	if is_instance_valid(start_menu):
		start_menu.visible = false
		in_start_menu = false
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
	paused = false
	if is_instance_valid(overlay):
		overlay.visible = false

	if target_id == "farm":
		if is_instance_valid(player):
			player.set_meta("in_stealth_box", false)
			for child in player.find_children("*", "CardboardBoxProp", true, false):
				child.queue_free()
		if is_instance_valid(active_course):
			_exit_course()
		if is_instance_valid(camera):
			camera.set_camera_mode(IsometricCamera.CameraMode.ISOMETRIC)
		player.reset_at(Vector3(38.0, 24.1, 52.0))
		_restore_control()
		camera.snap_to_target()
		_show_toast("已切换到：农场主线世界", "自由探索与老牛/伙伴互动")
	else:
		if is_instance_valid(player):
			player.set_meta("in_stealth_box", false)
			for child in player.find_children("*", "CardboardBoxProp", true, false):
				child.queue_free()
		if is_instance_valid(active_course):
			_exit_course()
		match target_id:
			"course_0":
				current_chase_id = "intro" # The dream: no chase bookkeeping
			"course_1":
				current_chase_id = "chase_1"
			"course_2":
				current_chase_id = "chase_2"
			"course_3":
				current_chase_id = "chase_3"
			"course_4":
				current_chase_id = "chase_final"
			_:
				current_chase_id = "chase_1"
		if target_id != "course_1" and target_id != "course_0":
			# Demo shortcut must satisfy start_stage_chase's pin requirement for chase_2+,
			# otherwise completing the course jumps stage to exploring without the pin
			# and the ending becomes unreachable. The dream is pre-story: no pin.
			GameManager.has_pin = true
		# Companion skills come from the course's own setup() as course-scoped loans;
		# writing them here used to tick the farm story's companion quests for free.
		_enter_course(target_id)
		if target_id == "course_1":
			# Course 1 sits before the Ox quest in story order, so its setup() lends
			# nothing; the demo shortcut keeps the struggle QTE available there.
			GameManager.grant_course_skills(["struggle"])
		camera.snap_to_target()

func start_game() -> void:
	_start_game()

func start_dream_intro() -> void:
	_start_dream_intro()

func skip_dream_intro() -> void:
	# Skip path: the dream never plays, but the 6am truck deadline is still the
	# story's inciting incident - mark the prologue beat as known.
	GameManager.mark_intro_dream_done()
	_start_game()

func _start_dream_intro() -> void:
	# Boot path: close the start menu, fall asleep, and enter the nightmare.
	# Tests keep calling start_game() directly (straight to the farm); the skip
	# button goes through skip_dream_intro().
	if is_instance_valid(active_course):
		return
	_start_game()
	current_chase_id = "intro"
	_enter_course("course_0")
	_show_toast("……（入梦）", "冰冷的地面，铁锈味，远处有铁链声。……这里是哪？")
	_refresh_hud()

func _start_game() -> void:
	in_start_menu = false
	if is_instance_valid(start_menu):
		start_menu.visible = false
	if in_settings:
		_close_settings()
	_restore_control()
	_refresh_hud()

func _show_start_menu() -> void:
	in_start_menu = true
	in_settings = false
	if is_instance_valid(start_menu):
		start_menu.visible = true
		var start_btn: Button = start_menu.find_child("StartButton", true, false)
		if is_instance_valid(start_btn):
			start_btn.grab_focus()
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
	if is_instance_valid(overlay):
		overlay.visible = false
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	if is_instance_valid(todo_notebook):
		todo_notebook.visible = false
	player.set_control_mode("cinematic")

func _show_pause_menu() -> void:
	paused = true
	in_settings = false
	if is_instance_valid(pause_menu):
		pause_menu.visible = true
		var resume_btn: Button = pause_menu.find_child("ResumeButton", true, false)
		if is_instance_valid(resume_btn):
			resume_btn.grab_focus()
	# Keep overlay and TestHighCamera compatibility for tests
	_clear_children(overlay_buttons)
	var toggle := CheckButton.new()
	toggle.name = "TestHighCamera"
	toggle.text = "测试用高视角（原高度 / 原视野）"
	toggle.button_pressed = camera.test_high_view
	toggle.toggled.connect(camera.set_test_high_view)
	overlay_buttons.add_child(toggle)
	# 暂停时覆盖层只当暗色背景：藏起结算卡片，收掉待办与体力条。
	overlay.color = Color(0, 0, 0, 0)
	overlay.get_child(0).visible = false
	if is_instance_valid(todo_notebook): todo_notebook.visible = false
	if is_instance_valid(dash_gauge): dash_gauge.visible = false
	overlay.visible = true

func _show_pause_settings() -> void:
	_show_pause_menu()

func _open_settings(from_start: bool = false) -> void:
	in_settings = true
	settings_from_start = from_start
	# The wall and the settings card are sibling modals - never both at once.
	if is_instance_valid(achievements_menu):
		achievements_menu.visible = false
	if from_start:
		if is_instance_valid(start_menu): start_menu.visible = false
	else:
		if is_instance_valid(pause_menu): pause_menu.visible = false
	if is_instance_valid(settings_menu):
		var toggle_cam: CheckButton = settings_menu.find_child("TestHighCamera", true, false)
		if is_instance_valid(toggle_cam):
			toggle_cam.button_pressed = camera.test_high_view
		settings_menu.visible = true
		var back_btn: Button = settings_menu.find_child("BackButton", true, false)
		if is_instance_valid(back_btn):
			back_btn.grab_focus()

func _close_settings() -> void:
	in_settings = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
	if settings_from_start:
		if is_instance_valid(start_menu):
			start_menu.visible = true
			var settings_btn: Button = start_menu.find_child("SettingsButton", true, false)
			if is_instance_valid(settings_btn):
				settings_btn.grab_focus()
	else:
		if is_instance_valid(pause_menu):
			pause_menu.visible = true
			var settings_btn: Button = pause_menu.find_child("SettingsButton", true, false)
			if is_instance_valid(settings_btn):
				settings_btn.grab_focus()

func _open_achievements(from_start: bool = false) -> void:
	achievements_from_start = from_start
	if in_settings:
		_close_settings()
	if is_instance_valid(achievements_menu):
		GAME_MENUS.refresh_achievements_menu(achievements_menu)
		achievements_menu.visible = true
		var back_btn: Button = achievements_menu.find_child("BackButton", true, false)
		if is_instance_valid(back_btn):
			back_btn.grab_focus()
	if from_start:
		if is_instance_valid(start_menu): start_menu.visible = false
	else:
		if is_instance_valid(pause_menu): pause_menu.visible = false

func _close_achievements() -> void:
	if is_instance_valid(achievements_menu):
		achievements_menu.visible = false
	if achievements_from_start:
		if is_instance_valid(start_menu):
			start_menu.visible = true
			var achv_btn: Button = start_menu.find_child("AchievementsButton", true, false)
			if is_instance_valid(achv_btn):
				achv_btn.grab_focus()
	else:
		if is_instance_valid(pause_menu):
			pause_menu.visible = true
			var achv_btn: Button = pause_menu.find_child("AchievementsButton", true, false)
			if is_instance_valid(achv_btn):
				achv_btn.grab_focus()

func _return_to_main_menu() -> void:
	# The opening key-test scene IS the main menu now (it lives in its own
	# scene so the boot flow can offer the key playground before the dream).
	paused = false
	in_settings = false
	GameManager.pending_boot = ""
	get_tree().change_scene_to_file("res://scenes/ui/opening_scene.tscn")

func _resume() -> void:
	paused = false
	in_settings = false
	if is_instance_valid(pause_menu): pause_menu.visible = false
	if is_instance_valid(settings_menu): settings_menu.visible = false
	overlay.visible = false
	chase.set_active(GameManager.is_in_chase())
	if is_instance_valid(active_course) and active_course.runner.started and not active_course.runner.completed:
		active_course.runner.set_dogs_active(true)
	_restore_control()
	_refresh_hud()

func _process(delta: float) -> void:
	if in_qte:
		qte_time_remaining -= delta
		if is_instance_valid(qte_timer_bar):
			qte_timer_bar.value = maxf(0.0, qte_time_remaining)
		if is_instance_valid(qte_btn_label):
			var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.06
			qte_btn_label.scale = Vector2(pulse, pulse)
		if qte_time_remaining <= 0.0:
			_finish_qte(false)
		return

	if not is_instance_valid(prompt): return
	if in_start_menu or paused or in_settings or dialogue_open or (overlay.visible and not paused) or cinematic or in_skill_card:
		prompt.visible = false
		return
	if GameManager.is_in_chase():
		prompt.text = "犬队逼近 %.1f m ｜ Shift 闪避 · 空格 跳跃 · 被咬狂按空格" % pressure
	else:
		var target := player.get_nearest_interactable()
		if is_instance_valid(target):
			var id: String = str(target.get_meta("interaction_id", ""))
			var names := {"goat": "老岩羊", "ox": "老牛", "sheep": "小羊", "horse": "追风", "farmer": "农场主", "record_board": "纪录牌", "cablecar": "索道"}
			prompt.text = "[ F ]  " + str(names.get(id, "调查"))
		else:
			prompt.text = ""
	prompt.visible = not prompt.text.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if in_skill_card:
		var dismiss: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("action_jump") \
			or event.is_action_pressed("action_interact") \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
		if dismiss:
			_dismiss_skill_card()
			get_viewport().set_input_as_handled()
			return

	if dialogue_open and not busy and not cinematic and (pokemon_battle == null or not pokemon_battle.battle_active):
		var advance: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("action_interact") \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if advance:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
			return
			
	if event.is_action_pressed("ui_cancel") and not cinematic and GameManager.stage != "ending":
		if achievements_menu != null and is_instance_valid(achievements_menu) and achievements_menu.visible:
			_close_achievements()
			get_viewport().set_input_as_handled()
			return
		if in_settings:
			_close_settings()
			get_viewport().set_input_as_handled()
			return
		if in_start_menu:
			return
		if in_skill_card:
			_dismiss_skill_card()
			get_viewport().set_input_as_handled()
			return
		if overlay.visible and not paused: return
		if in_qte:
			# Pausing mid-QTE would keep its real-time countdown running while the
			# player's input is blocked, silently failing the struggle.
			return
		paused = not paused
		if paused:
			player.set_control_mode("paused")
			chase.set_active(false)
			if is_instance_valid(active_course):
				active_course.runner.set_dogs_active(false)
			_show_pause_menu()
		else:
			_resume()
		get_viewport().set_input_as_handled()

func _refresh_hud() -> void:
	# The skill getter (not npc_completed) so a course-scoped dash loan also enables sprint.
	player.set_dash_enabled(GameManager.has_dash_skill)
	if is_instance_valid(pin_visual): pin_visual.visible = GameManager.has_pin
	if is_instance_valid(todo_notebook):
		var battle_on: bool = is_instance_valid(pokemon_battle) and pokemon_battle.battle_active
		todo_notebook.visible = not in_start_menu and not paused and not overlay.visible and not battle_on
		if todo_notebook.visible:
			_refresh_todo_list()

func _on_interact(target: Node3D) -> void:
	if dialogue_open or overlay.visible or cinematic or GameManager.is_in_chase() or GameManager.stage == "ending": return
	if not is_instance_valid(target): return
	var id := str(target.get_meta("interaction_id", ""))
	if id == "farmer":
		if GameManager.stage == "showdown" or (GameManager.has_pin and GameManager.npc_completed.get("horse", false) and GameManager.stage != "cablecar_ready" and GameManager.stage != "ending"):
			if GameManager.stage != "showdown":
				GameManager.stage = "showdown"
			_start_farmer_showdown()
			return
	var entry: String = DialogueManager.get_entry_for(id)
	if GameManager.npc_met.has(id): GameManager.npc_met[id] = true
	if not entry.is_empty(): open_dialogue(entry)

func open_dialogue(key: String) -> void:
	if in_start_menu:
		in_start_menu = false
		if is_instance_valid(start_menu):
			start_menu.visible = false
	if paused:
		_resume()
	if key == "ordeal_encounter":
		if GameManager.stage != "showdown":
			GameManager.stage = "showdown"
		_start_farmer_showdown()
		return
	var data: Dictionary = DialogueManager.get_dialogue_node(key)
	if data.is_empty():
		push_error("Missing dialogue: " + key)
		close_dialogue()
		return
	current_dialogue = key
	dialogue_open = true
	player.set_control_mode("dialogue")
	dialogue_panel.visible = true
	if is_instance_valid(toast_panel) and toast_panel.visible: _place_toast()
	speaker_label.text = str(data.get("speaker", "")) + "  /  " + str(data.get("title", ""))
	portrait.texture = ART_2D.PORTRAITS.get(str(data.get("speaker", "")))
	portrait.visible = portrait.texture != null
	dialogue_lines = _split_lines(str(data.get("content", "")))
	line_index = 0
	current_options = data.get("options", [])
	_clear_children(options)
	_show_current_line()

func _start_farmer_showdown() -> void:
	if is_instance_valid(pokemon_battle) and pokemon_battle.battle_active: return
	if in_start_menu:
		in_start_menu = false
		if is_instance_valid(start_menu): start_menu.visible = false
	if paused: _resume()
	dialogue_open = true
	player.set_control_mode("dialogue")
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	if is_instance_valid(prompt):
		prompt.visible = false
	if is_instance_valid(todo_notebook):
		todo_notebook.visible = false
	if is_instance_valid(dash_gauge):
		dash_gauge.visible = false
	if is_instance_valid(pokemon_battle):
		pokemon_battle.start_battle(self)

func _on_pokemon_battle_finished(success: bool) -> void:
	dialogue_open = false
	_clear_children(options)
	if success:
		var ok := GameManager.complete_showdown()
		if ok: farm.set_gate_open(true)
		_show_toast("意志对决胜利！铁门轰然开启！", "农场主掌控欲彻底瓦解，快穿过大铁门登上后山索道！")
	_restore_control()
	_refresh_hud()

func _split_lines(content: String) -> Array:
	var lines := []
	for line in content.split("\n"):
		var text := str(line).strip_edges()
		if not text.is_empty():
			lines.append(text)
	if lines.is_empty():
		lines.append("")
	return lines

func _show_current_line() -> void:
	content_label.text = str(dialogue_lines[line_index])
	var on_last_line := line_index >= dialogue_lines.size() - 1
	line_hint.visible = not on_last_line
	if on_last_line and options.get_child_count() == 0:
		for index in range(current_options.size()):
			var option: Dictionary = current_options[index]
			options.add_child(_button(str(option.get("text", "继续")), _select_option.bind(index), true))
		if options.get_child_count() > 0:
			options.get_child(0).grab_focus()

func _advance_dialogue() -> void:
	if not dialogue_open or busy:
		return
	if is_instance_valid(pokemon_battle) and pokemon_battle.battle_active:
		return
	if line_index < dialogue_lines.size() - 1:
		line_index += 1
		_show_current_line()
	elif current_options.is_empty():
		close_dialogue()

func _select_option(index: int) -> void:
	if busy or index < 0 or index >= current_options.size(): return
	busy = true
	for button in options.get_children(): button.disabled = true
	var option: Dictionary = current_options[index].duplicate()
	var event_id: String = str(option.get("event", ""))
	var ok := true
	match event_id:
		"choose_red":
			ok = GameManager.choose_red()
			if ok:
				farm.set_pigpen_open(true)
				_show_toast("迈出第一步！", "身后的过往在紧追不放，沿山路逃往牛耕地！")
		"choose_blue":
			ok = GameManager.choose_blue()
			if ok:
				close_dialogue()
				_show_ending()
		"complete_ox", "complete_sheep", "complete_horse":
			var id := event_id.trim_prefix("complete_")
			if not GameManager.npc_completed.get(id, false):
				farm.set_npc_completed(id)
				await get_tree().create_timer(0.85).timeout
				ok = GameManager.complete_npc(id)
				if id == "ox":
					farm.set_named_gate_open("ox", true)
					_show_skill_unlock(
						"【 坚 韧 挣 脱 】",
						"借老牛坚忍不屈的硬骨气 · 挣脱命运的死锁",
						"【核心按键】 被咬住时狂按 [ 空格键 / SPACE ] 或 [ E ]",
						"被恶犬扑咬纠缠时，在 3.5 秒内猛敲空格 5 次，即可爆发巨力震退恶犬 6 米并使其眩晕！"
					)
				elif id == "sheep":
					farm.set_named_gate_open("sheep", true)
					_show_skill_unlock(
						"【 破 妄 明 眸 】",
						"借小羊清澈明辨的目光 · 看穿虚张声势的恐吓",
						"【被动视觉】 幻影恶犬将显现为半透明紫灰虚影",
						"幻影恶犬无法阻拦你，穿过虚影会使其化作烟尘消散！专心避开实体黑犬即可！"
					)
				elif id == "horse":
					farm.set_named_gate_open("horse", true)
					_show_skill_unlock(
						"【 疾 风 冲 刺 】",
						"借追风骏马四蹄翻腾的疾速 · 踏碎一切围追堵截",
						"【核心按键】 长按 [ Shift 键 ] 消耗体力加速",
						"长按多久就加速多久，松开即刻自动恢复体力！在恶犬红圈扑杀时按 Shift 灵巧闪避！"
					)
			else: ok = false
		"read_record": GameManager.read_record()
		"complete_showdown":
			ok = GameManager.complete_showdown()
			if ok: farm.set_gate_open(true)
		"launch_cablecar":
			ok = GameManager.can_launch_cablecar()
			if ok:
				close_dialogue()
				_launch_cablecar()
		"": pass
		_:
			ok = false
			push_error("Unknown event: " + event_id)
	await get_tree().process_frame
	busy = false
	if GameManager.stage == "ending" or cinematic: return
	if not ok:
		close_dialogue()
		return
	var next_key := str(option.get("next", ""))
	if next_key.is_empty(): close_dialogue()
	else: open_dialogue(next_key)

func close_dialogue() -> void:
	if in_start_menu:
		in_start_menu = false
		if is_instance_valid(start_menu):
			start_menu.visible = false
	dialogue_open = false
	dialogue_panel.visible = false
	if is_instance_valid(toast_panel) and toast_panel.visible: _place_toast()
	_restore_control()
	_refresh_hud()

func _restore_control() -> void:
	if in_start_menu: player.set_control_mode("cinematic")
	elif in_skill_card: player.set_control_mode("cinematic")
	elif cinematic: player.set_control_mode("cinematic")
	elif paused: player.set_control_mode("paused")
	elif in_qte: player.set_control_mode("qte")
	elif GameManager.stage == "ending" or (overlay.visible and not paused): player.set_control_mode("ending")
	elif dialogue_open: player.set_control_mode("dialogue")
	else: player.set_control_mode("chase" if GameManager.is_in_chase() else "explore")

# -------------------------------------------------------------
# Multi-Stage Chase System
# -------------------------------------------------------------
func _on_farm_chase_triggered(stage_id: String) -> void:
	if dialogue_open or cinematic or overlay.visible or GameManager.is_in_chase(): return
	if GameManager.chase_completed.get(stage_id, false): return
	
	# Pre-requisite checks
	if stage_id == "chase_2" and not GameManager.npc_completed.get("ox", false): return
	if stage_id == "chase_3" and not GameManager.npc_completed.get("sheep", false): return
	
	start_stage_chase(stage_id)

func start_stage_chase(stage_id: String) -> void:
	current_chase_id = stage_id
	if COURSE_SCENES.has(stage_id):
		_enter_course(stage_id)
		return
	if not GameManager.start_stage_chase(stage_id): return
	player.set_control_mode("chase")
	
	var config: Dictionary = L.CHASE_CONFIGS.get(stage_id, {})
	var route_name: String = str(config.get("route", "chase"))
	var points: Array[Vector3] = L.path(route_name)
	
	_show_toast(str(config.get("title", "追逐开始！")), str(config.get("desc", "向前跑！")))
	chase.start_stage(stage_id, player, config, points)
	_refresh_hud()

func _on_secret_pipe_entered(course_id: String) -> void:
	if dialogue_open or cinematic or overlay.visible or is_instance_valid(active_course):
		return
	if is_instance_valid(chase) and chase.active:
		chase.stop_chase()
	match course_id:
		"course_1": current_chase_id = "chase_1"
		"course_2": current_chase_id = "chase_2"
		"course_3": current_chase_id = "chase_3"
		"course_4": current_chase_id = "chase_final"
		_: current_chase_id = "chase_1"
	_show_toast("【发现隐藏捷径！】", "钻入神秘管道，逃入隐藏试炼赛道！")
	AchievementManager.unlock("pipe_explorer")
	_enter_course(course_id)

func enter_secret_course(course_id: String = "course_1") -> void:
	_on_secret_pipe_entered(course_id)

func _start_chase() -> void:
	# Standard entrance trigger for the final courtyard chase
	if dialogue_open or cinematic or overlay.visible: return
	start_stage_chase("chase_final")

# -------------------------------------------------------------
# Course Mode (Fall Guys-style obstacle courses)
# -------------------------------------------------------------
func _enter_course(stage_id: String) -> void:
	if is_instance_valid(active_course): return
	var scene_res = COURSE_SCENES.get(stage_id, COURSE_SCENES.get("course_1"))
	active_course = scene_res.instantiate()
	add_child(active_course)
	if is_instance_valid(farm) and farm.get_parent() == self:
		remove_child(farm)
		_farm_removed = true
	active_course.setup(player)
	player.set_control_mode("explore")
	if is_instance_valid(camera):
		camera.set_camera_mode(IsometricCamera.CameraMode.THIRD_PERSON)
		# Linear Fall Guys-style track: camera-relative input feeding yaw auto-follow
		# spins the camera when strafing or backpedaling, so lock yaw to the track axis.
		camera.tp_auto_follow_yaw = false
	camera.snap_to_target(active_course.runner.respawn_yaw())
	active_course.runner.course_started.connect(_on_course_started)
	active_course.runner.course_completed.connect(_on_course_completed)
	active_course.runner.qte_requested.connect(_on_qte_requested)
	# Course dogs report pressure through the runner, not the farm SimpleChase;
	# without this the chase prompt kept showing the last farm value (999.0 m).
	active_course.runner.pressure_changed.connect(func(value: float): pressure = value)
	active_course.runner.player_respawned.connect(func(_pos: Vector3): camera.snap_to_target(active_course.runner.respawn_yaw()))
	# The intro gets its own dream-entry toast instead: the title banner would
	# land on the same frame and overwrite it in the shared toast panel.
	if current_chase_id != "intro":
		_show_toast(active_course.runner.config.title, active_course.runner.config.desc)
	_refresh_hud()

func _on_course_started() -> void:
	GameManager.start_stage_chase(current_chase_id)
	player.set_control_mode("chase")
	_refresh_hud()

func _on_course_completed() -> void:
	if current_chase_id == "intro":
		# The dream ends without any stage bookkeeping: the run state stays in
		# the prologue exactly as if the pig had never slept.
		_finish_course_deferred.call_deferred()
		return
	GameManager.complete_stage_chase(current_chase_id)
	# Defer the world swap out of the physics callback so the pig's reset position
	# is not overwritten by the same frame's move_and_slide.
	_finish_course_deferred.call_deferred()

func _finish_course_deferred() -> void:
	var completed_id := current_chase_id
	_exit_course()
	if completed_id == "intro":
		# Wake up in the pen: cold sweat, hooks still flashing, decision made.
		# The prologue story beat lands on the to-do notebook's first line.
		GameManager.mark_intro_dream_done()
		_show_toast("……！！", "你一身冷汗地从泥窝里弹起来。梦里的铁钩还在眼前晃。")
		await get_tree().create_timer(2.7).timeout
		_show_toast("天快亮了。", "运牲车，明早六点就到。今晚——就今晚。（山顶残墙上的老岩羊在等你，它见过外面的事。）")
		_restore_control()
		_refresh_hud()
		return
	# Chapter transitions: each course exit narrates where the story just landed
	# and who the pig should find next, so the escape reads as one story.
	match completed_id:
		"chase_1":
			_show_toast("甩掉了！", "阴影被关在管道外——牛耕地到了。去找那头拉犁的老牛。")
		"chase_2":
			_show_toast("冲出溪谷！", "狗群的嚎叫留在身后——草甸上那只躲着光的小羊在等你。")
		"chase_3":
			_show_toast("穿过了迷雾！", "幻影散了——马场就在前方，去见守着旧纪录的烈马。")
		"chase_final":
			_show_toast("大铁门开了！", "最后的了断——农场主就在门后。（走上前，按 F）")
	_refresh_hud()

func _exit_course() -> void:
	var completed_id := current_chase_id
	GameManager.clear_course_skills()
	if is_instance_valid(player):
		# Drop a borrowed dash right away: not every exit path refreshes the HUD.
		player.set_dash_enabled(GameManager.has_dash_skill)
	if is_instance_valid(active_course):
		var old_course = active_course
		active_course = null
		if old_course.get_parent() == self:
			remove_child(old_course)
		old_course.queue_free()
	if _farm_removed and is_instance_valid(farm):
		add_child(farm)
		_farm_removed = false
	for id in GameManager.npc_completed:
		if GameManager.npc_completed[id]:
			farm.set_npc_completed(id)
	if GameManager.chase_completed.get("chase_1", false):
		farm.set_named_gate_open("ox", true)
	if GameManager.chase_completed.get("chase_2", false):
		farm.set_named_gate_open("sheep", true)
	if GameManager.chase_completed.get("chase_3", false):
		farm.set_named_gate_open("horse", true)

	var exit_pos := Vector3(38.0, 24.1, 52.0)
	if completed_id == "intro":
		# Waking up from the nightmare drops the pig back into its pen.
		exit_pos = farm.get_spawn_position()
	match completed_id:
		"chase_1":
			exit_pos = Vector3(38.0, 24.1, 52.0)
		"chase_2":
			exit_pos = Vector3(-38.0, 16.1, -20.0)
		"chase_3":
			exit_pos = Vector3(16.0, 8.1, -88.0)
		"chase_final":
			exit_pos = Vector3(-78.0, 2.1, -220.0)
	player.reset_at(exit_pos)
	if is_instance_valid(player):
		player.set_meta("in_stealth_box", false)
		for child in player.find_children("*", "CardboardBoxProp", true, false):
			child.queue_free()
	player.set_control_mode("explore")
	if is_instance_valid(camera):
		camera.tp_auto_follow_yaw = true
		camera.set_camera_mode(IsometricCamera.CameraMode.ISOMETRIC)
	camera.snap_to_target()

func _on_farm_gate_passed(gate_id: String) -> void:
	# Player safely crossed a zone gate!
	if GameManager.is_in_chase():
		chase.stop_chase()
		var completed_id := current_chase_id
		GameManager.complete_stage_chase(completed_id)
		player.set_control_mode("explore")
		_show_toast("成功脱险！", "大门已轰然锁上，恶犬被挡在门外。")
		_refresh_hud()

func _on_chase_finished(success: bool) -> void:
	if success:
		chase.stop_chase()
		GameManager.complete_stage_chase(current_chase_id)
		player.set_control_mode("explore")
		_refresh_hud()
	else:
		player.set_control_mode("ending")
		var tip := "沿小路奔跑，按空格越过倒木障碍！被恶犬咬住时狂按空格拼命挣脱！"
		if GameManager.has_struggle_skill:
			tip = "【坚韧挣脱】已激活：被咬住时，在 3.5 秒内狂敲 [空格键 / SPACE] 5 次即可震退恶犬！"
		_show_overlay("被犬队追上了", tip, [{"text": "从本段起点重试", "call": _retry}, {"text": "从头开始", "call": _restart}])

func _retry() -> void:
	chase.stop_chase()
	in_qte = false
	overlay.visible = false
	
	var config: Dictionary = L.CHASE_CONFIGS.get(current_chase_id, {})
	var retry_pos: Vector3 = config.get("retry", farm.RETRY_POSITION)
	
	player.reset_at(retry_pos)
	farm._checkpoint = retry_pos
	camera.snap_to_target()
	
	if current_chase_id == "chase_final" or current_chase_id == "chase":
		GameManager.retry_chase()
	else:
		GameManager.stage = "exploring"
		
	_restore_control()
	_refresh_hud()

func _launch_cablecar() -> void:
	cinematic = true
	player.set_control_mode("cinematic")
	var cabin: Node3D = farm.get_cablecar()
	player.global_position = cabin.global_position + Vector3(0, 0.5, 0)
	player.set_physics_process(false)
	var tween := create_tween().set_parallel(true)
	var direction: Vector3 = farm.CABLECAR_TRAVEL
	tween.tween_property(cabin, "position", cabin.position + direction, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "global_position", player.global_position + direction, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	GameManager.finish_escape()
	cinematic = false
	_show_ending()

func _show_ending() -> void:
	player.set_control_mode("ending")
	if GameManager.ending == "stay":
		_show_overlay("安稳的肉馅", "甜料很暖，明早的车还很远。\n\n你选择留在猪圈。也可以再走一次另一条路。", [{"text": "重新选择", "call": _restart}])
	else:
		_show_overlay("旷野归途", "金牌是农场的，但命是你自己的。\n\n风从麦浪上吹来。前面没有围栏与食槽。", [{"text": "重新出发", "call": _restart}])
	ending_art.texture = ART_2D.ENDINGS.get(GameManager.ending)
	ending_art.visible = ending_art.texture != null

func _show_overlay(title: String, body: String, buttons: Array) -> void:
	ending_art.hide()
	overlay.color = Color(UI.PAPER, 0.96)
	overlay.get_child(0).visible = true
	if is_instance_valid(todo_notebook): todo_notebook.visible = false
	if is_instance_valid(dash_gauge): dash_gauge.visible = false
	overlay_title.text = title
	overlay_text.text = body
	_clear_children(overlay_buttons)
	for item in buttons:
		overlay_buttons.add_child(_button(item["text"], item["call"]))
	overlay.visible = true
	if overlay_buttons.get_child_count() > 0: overlay_buttons.get_child(0).grab_focus()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _restart() -> void:
	get_tree().reload_current_scene()
