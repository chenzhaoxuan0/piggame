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
const DIALOGUE_VO_SCRIPT := preload("res://scripts/core/dialogue_vo.gd")
var dialogue_vo = null # 对话节点配音：开哪个节点播 assets/audio/vo/{id}.mp3
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
var _dialogue_focus := 0  # W/S 键盘导航的当前选项（2026-11-17 实机反馈）
var dialogue_lines: Array = []
var line_index := 0
var pressure := 999.0
var pin_visual: Node3D
var portrait: TextureRect
var ending_art: TextureRect

var in_start_menu := true
var key_strip: Control = null
var key_strip_caps := {}
var in_settings := false
var settings_from_start := false
var settings_from_hub := false # 猪圈枢纽（标题卡）打开的设置：关闭时直接回落，不弹暂停
var achievements_from_start := false
var achievements_from_hub := false # 同上，枢纽打开的成就墙
var start_menu: Control
var pause_menu: Control
var settings_menu: Control
var achievements_menu: Control
var credits_panel: Control # 设置菜单「关于游戏」打开的致谢面板（BGM 署名等）

# Untitled Goose Game Style UI Extensions
var todo_hub: Control
var todo_notebook: PanelContainer
var todo_vbox: VBoxContainer
var todo_toggle_btn: Button
var keys_toggle_btn: Button
var todo_folded := true # 默认折叠：初始状态右上角只露按钮
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

# 右下角触发通知流（彩蛋台词、技能解锁/借得通知的屏幕端统一出口）
var notice_feed: VBoxContainer
const LOAN_SKILL_TEXTS := {
	"struggle": {
		"title": "【 坚 韧 挣 脱 】",
		"subtitle": "借老牛坚忍不屈的硬骨气 · 本关与你同行",
		"key": "【核心按键】 被咬住时狂按 [ 空格键 / SPACE ] 或 [ E ]",
		"desc": "被恶犬扑咬纠缠时，在时限内猛敲空格，即可爆发巨力震退恶犬并使其眩晕！"
	},
	"discern": {
		"title": "【 破 妄 明 眸 】",
		"subtitle": "借小羊清澈明辨的目光 · 本关与你同行",
		"key": "【被动视觉】 幻影恶犬将显现为半透明紫灰虚影",
		"desc": "幻影恶犬无法阻拦你，穿过虚影会使其化作烟尘消散！专心避开实体黑犬即可！"
	},
	"dash": {
		"title": "【 疾 风 冲 刺 】",
		"subtitle": "借追风骏马四蹄翻腾的疾速 · 本关与你同行",
		"key": "【核心按键】 长按 [ Shift 键 ] 消耗体力加速",
		"desc": "长按多久就加速多久，松开即刻恢复体力！恶犬红圈扑杀时按 Shift 灵巧闪避！"
	}
}

# Chase & QTE logic state
var current_chase_id := ""
var in_qte := false
var current_qte_dog: ChaseDog = null
var qte_hits := 0
# 2026-11 tuning: 6 hits in 3.2 s let players stroll through the struggle.
# 8 hits in 2.2 s (~3.6 taps/s) means only real mashing escapes; failing now
# costs a checkpoint rerun instead of a game-over menu.
const QTE_TARGET_HITS := 8
var qte_time_remaining := 2.4
const QTE_TIME_TOTAL := 2.2
var _checkpoint_retries := 0

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
	if farm.has_signal("playground_event"):
		farm.playground_event.connect(_on_playground_event)
		
	GameManager.state_changed.connect(_refresh_hud)
	if GameManager.has_signal("course_skill_granted"):
		GameManager.course_skill_granted.connect(_on_course_skill_granted)

	_build_hud()
	_build_pin()
	# 二周目开局提示：档案里逃出去过一次，全部伙伴之力醒来即随身。
	if GameManager.begin_ng_plus_if_earned():
		_show_toast("二周目 · 伙伴之力随身", "坚韧挣脱 · 破妄明眸 · 疾风冲刺，从泥窝醒来的第一秒全都回来。")
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
			MusicManager.play("farm")
			_start_pigpen_tutorial()
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
	dialogue_vo = DIALOGUE_VO_SCRIPT.new()
	dialogue_vo.name = "DialogueVO"
	add_child(dialogue_vo)
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
	
	# Show active item and recent items in Goose Game fashion. The notebook's
	# height now follows the entry count, so the caps below double as the
	# height ceiling: at most 3 active + the 2 most recently completed rows.
	var done_count := 0
	for i in range(items.size() - 1, -1, -1):
		if items[i].get("done", false):
			done_count += 1
			if done_count > 2:
				items.remove_at(i)
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

## 进出隐藏赛道会整体切换世界并强制改写猪的控制模式：若恶犬恰在这一瞬间
## 咬住猪（追逐段末段就是赛道入口，这是实际会发生的事），QTE 面板会挂
## 在半空——空格监听只在 qte 模式下生效，进关后它既关不掉也打不满，
## 只能干等倒计时归零（2026-11-15 实机反馈 #8/#9）。世界一换，追捕本身
## 就结束了：立刻收场。不走 _finish_qte：成功分支白付 grapple_escape，
## 失败分支在农场侧会罚回检查点——玩家只是钻进了洞口。所有者侧用
## reject_qte 回滚（进洞路径 stop_chase 已清 _player/狗，resolve 的击退
## 演出既会空访问也没有观众），否则它们的 in_qte 卡 true，之后的扑咬
## QTE 会被自己拒绝。
func _dismiss_qte_for_world_switch() -> void:
	if not in_qte:
		return
	in_qte = false
	if is_instance_valid(qte_panel):
		qte_panel.visible = false
	var dog := current_qte_dog
	current_qte_dog = null
	if is_instance_valid(active_course):
		active_course.runner.reject_qte(dog)
	elif chase != null:
		chase.reject_qte(dog)

# -------------------------------------------------------------
# Skill notices (bottom-right feed): permanent unlocks and course
# loans both land as feed cards - no center modal, no locked pig,
# no dismiss button, they fade out on their own.
# -------------------------------------------------------------
func _show_skill_unlock(title_text: String, subtitle_text: String, key_text: String, desc_text: String) -> void:
	_notify_skill("SkillNoticeCard", "★ 领悟伙伴新技能 ★", title_text, subtitle_text, key_text, desc_text, 5.0, UI.CORAL)

func _on_course_skill_granted(skill_id: String) -> void:
	var text: Dictionary = LOAN_SKILL_TEXTS.get(skill_id, {})
	if text.is_empty():
		return
	_notify_skill("LoanSkillNotice", "★ 本关借得伙伴之力 ★", str(text.get("title", "")), str(text.get("subtitle", "")), str(text.get("key", "")), str(text.get("desc", "")), 4.0, UI.TEAL)

func _notify_skill(card_name: String, tag_text: String, title_text: String, subtitle_text: String, key_text: String, desc_text: String, hold: float, accent: Color) -> void:
	# 技能通知：压进右下角通知流的富卡片（标签/标题/副题/键位/描述），与
	# 彩蛋台词共用同一列堆叠与淡出节律——不再挡住画面中央，也不锁猪。
	if not is_instance_valid(notice_feed): return
	while notice_feed.get_child_count() >= 4:
		var oldest: Node = notice_feed.get_child(0)
		oldest.queue_free()
		await get_tree().process_frame
		if not is_instance_valid(notice_feed): return # 关卡在等待帧期间被释放
	var card: PanelContainer = UI.patch_panel(16, UI.PAPER, accent, Vector2(18, 12))
	card.name = card_name
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	card.custom_minimum_size = Vector2(340, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.add_child(UI.name_tag(tag_text, accent, UI.WHITE, 13))
	var title_label := UI.label(title_text, 20, UI.TEAL_DEEP, true)
	title_label.name = "SkillTitle"
	box.add_child(title_label)
	box.add_child(UI.label(subtitle_text, 14, UI.INK_SOFT))
	var key_label := UI.label(key_text, 14, UI.RED, true)
	key_label.name = "SkillKey"
	box.add_child(key_label)
	var desc_label := UI.label(desc_text, 13, UI.INK)
	desc_label.name = "SkillDesc"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY # 中文长句无处断词，任意处换行
	desc_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(desc_label)
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5) # 布局定尺寸后以中心为轴弹入
	notice_feed.add_child(card)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.18).from(Vector2(0.92, 0.92)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold)
	tween.tween_property(card, "modulate:a", 0.0, 0.35)
	tween.tween_callback(card.queue_free)

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
	# 对话打开或键位教学条占着底部时，横幅上移到对话面板那一行，
	# 避免盖住台词、选项或键位条（键位条随 HUD 增长，恰好在同一格）。
	var lifted := (is_instance_valid(dialogue_panel) and dialogue_panel.visible) \
		or (is_instance_valid(key_strip) and key_strip.visible)
	if lifted:
		toast_panel.offset_top = -386
		toast_panel.offset_bottom = -322
	else:
		toast_panel.offset_top = -142
		toast_panel.offset_bottom = -78

var _toast_tween: Tween = null

func _show_toast(title_text: String, desc_text: String) -> void:
	if not is_instance_valid(toast_panel): return
	toast_title.text = title_text
	toast_desc.text = desc_text
	_place_toast()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill() # 新一拍顶掉旧一拍：两条 toast 不再抢同一个 modulate
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0
	var tween := create_tween()
	_toast_tween = tween
	tween.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.5)
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): toast_panel.visible = false)

func _show_notice(text: String) -> void:
	# 彩蛋触发台词的右下角通知：缝线小补丁卡片，BACK 弹入，3.2s 后淡出。
	# 同屏最多 4 条，超出先撤最旧一条，防止连触彩蛋刷屏。
	if not is_instance_valid(notice_feed): return
	while notice_feed.get_child_count() >= 4:
		var oldest: Node = notice_feed.get_child(0)
		oldest.queue_free()
		await get_tree().process_frame
		if not is_instance_valid(notice_feed): return # 关卡在等待帧期间被释放
	var card: PanelContainer = UI.patch_panel(14, UI.PAPER, UI.TEAL, Vector2(14, 9))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	var label: Label = UI.label(text, 16, UI.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY # 中文长句无处可断词，任意处换行
	card.add_child(label)
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5) # 布局定尺寸后以中心为轴弹入
	notice_feed.add_child(card)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.18).from(Vector2(0.92, 0.92)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.2)
	tween.tween_property(card, "modulate:a", 0.0, 0.35)
	tween.tween_callback(card.queue_free)

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
		# 2026-11-15 实机反馈 #16：返回点不再固定在牛耕地——回猪所在主线
		# 世界的上一个存档点（farm._checkpoint 随走随记），没走过就兜底原点。
		var farm_return := Vector3(38.0, 24.1, 52.0)
		if is_instance_valid(farm) and farm._checkpoint != Vector3.ZERO:
			farm_return = farm._checkpoint
		player.reset_at(farm_return)
		_restore_control()
		camera.snap_to_target()
		_show_toast("已切换到：农场主线世界", "回到上一个落脚点（卡住了随时按 R）")
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
	# In-game 开始菜单按钮（menus.gd 绑定）。猪圈语境（教程沙盒在跑）走统一
	# 入口：脑洞问答 → 睡着演出 → 入梦；其余语境（直连实例的经典开始菜单，
	# 测试与截图用）维持直接入梦——那里没有可以睡的猪圈演出。
	if GameManager.tutorial_free_roam:
		_begin_dream_from_pigpen()
		return
	_start_dream_intro()

## 二周目跳过序章（2026-11-15 实机反馈 #15）：噩梦 + 键位教学整个流程只在
## 一周目演一次。二周目 F 老岩羊 → 直接拿插销、开圈门、进入探索（intro_
## dream_done 早在猪圈开机时点过，噩梦纪念章一周目已到手）。
func _skip_prologue_for_ng_plus() -> void:
	# 2026-11-17 实机反馈：二周目不再直接出圈——保留岩羊的红/蓝选择对话，
	# 「温热的泥浆」（蓝色安稳结局）在二周目以后也必须能完成。噩梦与键位
	# 教学仍然跳过（每会话只演一次），只把最后的选择权还给玩家。
	GameManager.tutorial_free_roam = false
	in_start_menu = false
	if is_instance_valid(start_menu):
		start_menu.visible = false
	# 2026-11-16 实机反馈：标题卡必须一并收走——教学旗清了但卡还挂左上角，
	# 二周目全程左上角都是"开始游戏"，对话停稳 3 秒后它还会淡回来。
	_dismiss_title_card()
	if not GameManager.has_dash_skill:
		player.set_dash_enabled(false)
	_hide_key_strip()
	_show_notice("二周目：噩梦与键位教学只演一次——但两条路仍然由你选。")
	if is_instance_valid(player):
		player.set_control_mode("explore")
	open_dialogue("cliff_goat_choice")

func skip_dream_intro() -> void:
	# Skip path (the in-game start menu's 跳过序章 button): the dream never
	# plays, and "starting the game" now means the pigpen tutorial - same
	# landing as the boot menu's skip.
	_start_pigpen_tutorial()

func _start_pigpen_tutorial() -> void:
	# pending_boot == "farm": the game has NOT started yet. No more floating
	# key-test pen - the pig wakes up in its real pigpen on the farm: roam,
	# hop, dash, snuffle the trough, but NPCs won't talk and the pen gate stays
	# bolted. "Starting the game" (title card button or F on the goat) now means
	# falling asleep into the dream prologue - see _begin_dream_from_pigpen.
	GameManager.mark_intro_dream_done()
	GameManager.tutorial_free_roam = true
	in_start_menu = false
	if is_instance_valid(start_menu):
		start_menu.visible = false
	player.set_dash_enabled(true) # try Shift freely; story gating resumes on start
	player.set_control_mode("explore")
	camera.snap_to_target()
	# 键位说明默认隐藏：玩家点右上『键位说明』才展开（10 秒自动收起）。
	_todo_idle_time = 0.0
	_show_toast("山顶猪圈 · 演出开始前", "蹄子还听使唤吗？先在猪圈里练练——点右上『键位说明』随时查看按键；练累了就回窝眯一觉：点左上『开始游戏』，或来找山羊按 [ F ] 入梦。")
	if is_instance_valid(key_strip):
		# 键位条的默认引导写在 game_hud.gd（「按 F 开始今天的农场」），这里
		# 覆盖成入梦指引：两条入口（标题卡 / F 山羊）都通向「睡着→入梦」。
		var caption: Label = key_strip.find_child("KeyTestCaption", true, false) as Label
		if caption != null:
			caption.text = "开演前先试试蹄子——按键当场生效 ｜ 练累了回窝眯一觉：左上『开始游戏』或找山羊按 [ F ] 入梦"
	_build_title_card()
	_refresh_hud()

# ------------------------------------------------------------- brain hole
# 开演前的脑洞校准：一个选择题，问「这个游戏好玩吗」。只有选「不」才能
# 通过——预期被放到地板上，后面每一秒都是惊喜（选「好玩」会被告知答错）。
var _brain_quiz: Control = null
var _brain_hint: Label = null
var _brain_hole_done := false
var _brain_quiz_x := 0.0
var _brain_shake: Tween = null
# 答完题后要去做的事（"dream" = 标题卡的开始游戏被脑洞校准挡了一道）。
var _quiz_next := ""

func _show_brain_hole_quiz() -> void:
	if _brain_hole_done:
		return # already answered once this session - the hole stays calibrated
	if is_instance_valid(_brain_quiz):
		_brain_quiz.queue_free()
	var panel: PanelContainer = UI.patch_panel(18, UI.PAPER, UI.PINK, Vector2(28, 22))
	panel.name = "BrainHoleQuiz"
	# 顶部中央：屏幕中心会和键位条/横幅叠在底部一格，右上是待办本，左上是标题卡。
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 90
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UI.label("开演前 · 脑洞校准", 24, UI.INK, true))
	var question := UI.label("这个游戏好玩吗？", 19, UI.INK)
	question.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	column.add_child(question)
	_brain_hint = UI.label("（友情提示：这是一款毫无用处的无厘头搞笑游戏，请据此作答）", 15, Color("8A8177"))
	_brain_hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	column.add_child(_brain_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	row.add_child(UI.button("好玩", _answer_brain_hole.bind(false)))
	row.add_child(UI.button("不", _answer_brain_hole.bind(true), true))
	# The quiz owns the screen centre: hold the pig still until it's answered.
	player.set_control_mode("locked")
	# 模态让位（同对话的 2026-11-16 反馈）：quiz 挂屏期间标题卡淡出、按钮
	# 不可点——否则左上角"开始游戏"还能被点，跟脑洞校准抢入口。
	if is_instance_valid(_title_card) and not _ui_auto_hidden:
		_set_ui_auto_hidden(true)
	hud.add_child(panel)
	_brain_quiz = panel
	_brain_quiz_x = panel.position.x # shake baseline - a re-shake mid-shake restarts from home, never drifts

func _answer_brain_hole(lower: bool) -> void:
	if not is_instance_valid(_brain_quiz):
		return
	if not lower:
		# 答错了。预期没有降下来，不能开演——面板抖一下，提示只有「不」是对的。
		# 抖动始终以 _brain_quiz_x 为基准且先杀上一个：连点两次也不会把面板抖离中心。
		if _brain_shake != null and _brain_shake.is_valid():
			_brain_shake.kill()
		_brain_shake = create_tween()
		_brain_shake.tween_property(_brain_quiz, "position:x", _brain_quiz_x + 10.0, 0.05)
		_brain_shake.tween_property(_brain_quiz, "position:x", _brain_quiz_x - 10.0, 0.05)
		_brain_shake.tween_property(_brain_quiz, "position:x", _brain_quiz_x, 0.05)
		_brain_hint.text = "不对，再想想——这么个没用的搞笑游戏，怎么会『好玩』呢？选『不』就对啦。"
		return
	_brain_hole_done = true
	_brain_quiz.queue_free()
	if GameManager.tutorial_free_roam:
		player.set_control_mode("explore")
	else:
		_restore_control() # paused/cinematic/ending states win over a blind explore
	_show_toast("脑洞已校准", "预期已放到地板上。从现在起，每一秒都是惊喜——反正这只是头猪的一场毫无用处的美梦。")
	if _quiz_next == "dream":
		_quiz_next = ""
		_proceed_dream()
		return

# ------------------------------------------------------------- title card
# 开场标题卡：boot 直进猪圈后，主菜单的标题与四个入口（入梦序章 / 游戏设置 /
# 成就墙 / 退出）作为左上角悬浮卡留在画面里——猪照常跑动，按钮随时可点。
# 不再提供「收起菜单」：右上角挂件（待办/键位说明）自带按钮，屏幕本来就让位。
var _title_card: Control = null

func _build_title_card() -> void:
	if is_instance_valid(_title_card):
		return
	var column := VBoxContainer.new()
	column.name = "TitleCard"
	# 顶端与右上角挂件组对齐（todo_hub offset_top 24），不再吊在画面中段。
	column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	column.offset_left = 24
	column.offset_top = 24
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE # 只有按钮本身吃鼠标，跑动点击照常
	var title := UI.banner("一口猪在金牌农场", 38)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(title)
	var subtitle := UI.name_tag("A PIG IN GOLDEN FARM · 今晚就逃离农场", UI.SUNNY, UI.INK, 14)
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(subtitle)
	var card := UI.patch_panel(18, UI.PAPER, UI.PINK, Vector2(20, 16))
	card.custom_minimum_size = Vector2(330, 0)
	column.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	var btn_start := UI.button("▶  开始游戏（入梦序章）", _title_start_dream, true)
	btn_start.name = "TitleStartButton"
	btn_start.custom_minimum_size.y = 46
	vbox.add_child(btn_start)
	var btn_settings := UI.button("⚙  游戏设置【ESC】", _open_hub_settings)
	btn_settings.name = "TitleSettingsButton"
	btn_settings.custom_minimum_size.y = 38
	btn_settings.add_theme_font_size_override("font_size", 15)
	vbox.add_child(btn_settings)
	var btn_achv := UI.button("🏅  成就墙", _open_hub_achievements)
	btn_achv.name = "TitleAchievementsButton"
	btn_achv.custom_minimum_size.y = 38
	vbox.add_child(btn_achv)
	var btn_quit := UI.button("✕  退出游戏", func(): get_tree().quit())
	btn_quit.name = "TitleQuitButton"
	btn_quit.custom_minimum_size.y = 38
	vbox.add_child(btn_quit)
	for btn in [btn_start, btn_settings, btn_achv, btn_quit]:
		btn.focus_mode = Control.FOCUS_NONE # F/Enter/Space belong to the pig, never the card
	hud.add_child(column)
	_title_card = column

func _dismiss_title_card() -> void:
	if is_instance_valid(_title_card):
		_title_card.queue_free()

func _title_start_dream() -> void:
	# 开始游戏（标题卡按钮）：走统一入口——先过脑洞校准（只有这时才出题，
	# 开场猪圈随时可玩），答完「不」再睡着入梦。已答过的会话直接入睡。
	_begin_dream_from_pigpen()

func _begin_dream_from_pigpen() -> void:
	# 三扇「开始游戏」门的统一入口：标题卡按钮、猪圈里 F 山羊、（猪圈语境下的）
	# in-game 开始菜单按钮。都先过脑洞校准（每会话一次），再走同一场睡着演出
	# 入梦——谁也不能绕过入睡直接改写叙事顺序（旧行为：硬切噩梦 / 直开红路对话）。
	if in_settings:
		_close_settings() # 枢纽设置开着也能直接开演（兜底；正常路径被遮罩挡住）
	if is_instance_valid(start_menu):
		start_menu.visible = false
		in_start_menu = false
	if not _brain_hole_done:
		_quiz_next = "dream"
		_show_brain_hole_quiz()
		return
	_proceed_dream()

func _proceed_dream() -> void:
	_end_pigpen_tutorial()
	_dismiss_title_card()
	_play_sleep_then_dream()

# ------------------------------------------------------------- sleep beat
# 睡着演出（总长约 3.5 秒，趴下之后可 F/点击快进）：锁操作 → 就地趴下打呼 →
# 画面淡黑 → 入梦 → 梦境淡入。梦醒的「弹起身」在 _finish_course_deferred 的
# intro 分支里反向播放，呼应入睡。
var sleep_playing := false
var _sleep_skip := false
var _sleep_skip_allowed := false
var _sleep_fade: ColorRect = null

func _play_sleep_then_dream() -> void:
	if sleep_playing or is_instance_valid(active_course):
		return
	sleep_playing = true
	_sleep_skip = false
	_sleep_skip_allowed = false
	cinematic = true
	player.set_control_mode("cinematic")
	if is_instance_valid(notice_feed): notice_feed.visible = false
	_show_toast("困意上来了……", "蹄子练开了，眼皮却越来越沉——就地一歪，眯一觉。（F / 点击可快进）")
	await _sleep_beat(0.3, false) # 打哈欠的半拍，太短不值得跳
	_sleep_skip_allowed = true
	# 趴下：身体侧倾下沉（tween 做可见的放倒），Z z z 挂到猪身上
	var lie := player.play_sleep_pose(0.85)
	player.show_zzz(true)
	await _sleep_tween_or_skip(lie)
	if _sleep_skip:
		player.snap_sleep_pose()
	await _sleep_beat(0.8)
	_show_toast("呼——噜——", "呼——噜——（泥窝里传出均匀的鼾声）")
	await _sleep_beat(0.6)
	# 淡黑 → 全黑时换场进噩梦（reset_at 会把猪拉正，观众只看见黑场后的梦）
	var fade := _get_sleep_fade()
	fade.color.a = 0.0
	fade.visible = true
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.7)
	await _sleep_tween_or_skip(fade_out)
	fade.color.a = 1.0
	_start_game()
	current_chase_id = "intro"
	_enter_course("course_0")
	cinematic = false
	sleep_playing = false
	player.show_zzz(false)
	# course_0 的进场对话节拍自带"冰冷的地面"台词卡；有节拍时不再弹同款
	# toast，避免两张卡叠着把同一句话说两遍。
	if not (is_instance_valid(active_course) and active_course.runner.beat_active()):
		_show_toast("……（入梦）", "冰冷的地面，铁锈味，远处有铁链声。……这里是哪？")
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 0.7)
	await fade_in.finished
	if is_instance_valid(fade):
		fade.visible = false
	_refresh_hud()

func _sleep_beat(seconds: float, skippable := true) -> void:
	# 睡着序列里的定时停顿；快进（F/点击）时立即塌缩。
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(seconds)
	if not skippable:
		await timer.timeout
		return
	while timer.time_left > 0.0 and not _sleep_skip:
		tree = get_tree()
		if tree == null:
			return
		await tree.process_frame

func _sleep_tween_or_skip(tween: Tween) -> void:
	# 等 tween 放完；中途快进则杀掉并交还调用方落位。
	if tween == null:
		return
	while tween.is_valid() and not _sleep_skip:
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame
	if tween.is_valid():
		tween.kill()

func _get_sleep_fade() -> ColorRect:
	if not is_instance_valid(_sleep_fade):
		_sleep_fade = ColorRect.new()
		_sleep_fade.name = "SleepFade"
		_sleep_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sleep_fade.color = Color(0.02, 0.02, 0.05, 0.0)
		_sleep_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(_sleep_fade)
		# 盖住整个 HUD 但让位于 toast 横幅：「……（入梦）」要在黑场上可读。
		if is_instance_valid(toast_panel):
			hud.move_child(_sleep_fade, toast_panel.get_index())
	return _sleep_fade

func fast_forward_sleep() -> void:
	# 测试/自动化钩子：等效于玩家的 F/点击快进。
	if sleep_playing:
		_sleep_skip = true

func _end_pigpen_tutorial() -> void:
	if not GameManager.tutorial_free_roam:
		return
	GameManager.tutorial_free_roam = false
	_dismiss_title_card()
	if not GameManager.has_dash_skill:
		player.set_dash_enabled(false) # dash belongs to 追风's loan again
	_hide_key_strip()

func _snuffle_trough(target: Node3D) -> void:
	# The trough gag from the old floating pen, now living in the real pigpen.
	AchievementManager.unlock("trough_sniff")
	_show_notice("哼哼！（拱得食槽哐当响）")
	var squash := create_tween()
	squash.tween_property(target, "scale", Vector3(1.12, 0.72, 1.12), 0.08)
	squash.tween_property(target, "scale", Vector3.ONE, 0.18)

func _start_dream_intro() -> void:
	# Direct dream entry (no sleep beat): the "dream" boot intent from the
	# opening menu and the classic start menu outside the pigpen context.
	# The pigpen's 开始游戏 doors all go through _play_sleep_then_dream() instead.
	# Tests keep calling start_game() directly (straight to the farm); the skip
	# button goes through skip_dream_intro().
	if is_instance_valid(active_course):
		return
	_start_game()
	current_chase_id = "intro"
	_enter_course("course_0")
	# 同 _play_sleep_then_dream：有进场节拍时节拍卡已说这句话，别再叠一张 toast。
	if not (is_instance_valid(active_course) and active_course.runner.beat_active()):
		_show_toast("……（入梦）", "冰冷的地面，铁锈味，远处有铁链声。……这里是哪？")
	_refresh_hud()

func _start_game() -> void:
	in_start_menu = false
	if is_instance_valid(start_menu):
		start_menu.visible = false
	if in_settings:
		_close_settings()
	settings_from_hub = false
	achievements_from_hub = false
	_restore_control()
	_refresh_hud()

func _show_start_menu() -> void:
	in_start_menu = true
	in_settings = false
	settings_from_hub = false
	achievements_from_hub = false
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
	if dialogue_vo != null:
		dialogue_vo.stop()
	_set_todo_hub_visible(false)
	player.set_control_mode("cinematic")

func _show_pause_menu() -> void:
	paused = true
	in_settings = false
	settings_from_hub = false
	achievements_from_hub = false
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
	_set_todo_hub_visible(false)
	if is_instance_valid(dash_gauge): dash_gauge.visible = false
	overlay.visible = true

func _show_pause_settings() -> void:
	_show_pause_menu()

func _open_settings(from_start: bool = false) -> void:
	in_settings = true
	settings_from_start = from_start
	settings_from_hub = false # 常规入口先清掉枢纽标记，hub 专用包装函数随后再置位
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

# 猪圈枢纽（标题卡 / ESC）打开的设置：关闭时直接回落枢纽，不弹暂停菜单。
func _open_hub_settings() -> void:
	_open_settings(false)
	settings_from_hub = true

func _close_settings() -> void:
	in_settings = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
	# ESC 从致谢面板直接退出时把两层一起收掉，避免致谢面板悬在暂停菜单上。
	if is_instance_valid(credits_panel):
		credits_panel.visible = false
	if settings_from_start:
		if is_instance_valid(start_menu):
			start_menu.visible = true
			var settings_btn: Button = start_menu.find_child("SettingsButton", true, false)
			if is_instance_valid(settings_btn):
				settings_btn.grab_focus()
	elif settings_from_hub:
		settings_from_hub = false # 枢纽从未离开画面，无需恢复任何菜单
	else:
		if is_instance_valid(pause_menu):
			pause_menu.visible = true
			var settings_btn: Button = pause_menu.find_child("SettingsButton", true, false)
			if is_instance_valid(settings_btn):
				settings_btn.grab_focus()

# 设置菜单的「关于游戏」：挂起设置打开致谢面板（BGM CC BY 署名等），关闭后回到设置。
func _open_credits_from_settings() -> void:
	if credits_panel == null:
		credits_panel = GAME_MENUS.build_credits_menu(hud, _close_credits_from_settings)
	if is_instance_valid(settings_menu):
		settings_menu.visible = false
	credits_panel.visible = true

func _close_credits_from_settings() -> void:
	if is_instance_valid(credits_panel):
		credits_panel.visible = false
	if is_instance_valid(settings_menu):
		settings_menu.visible = true
		var back_btn: Button = settings_menu.find_child("BackButton", true, false)
		if is_instance_valid(back_btn):
			back_btn.grab_focus()

func _open_achievements(from_start: bool = false) -> void:
	achievements_from_start = from_start
	achievements_from_hub = false # 常规入口先清掉枢纽标记，hub 专用包装函数随后再置位
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

# 猪圈枢纽（标题卡）打开的成就墙：关闭时直接回落枢纽，不弹暂停菜单。
func _open_hub_achievements() -> void:
	_open_achievements(false)
	achievements_from_hub = true

func _close_achievements() -> void:
	if is_instance_valid(achievements_menu):
		achievements_menu.visible = false
	if achievements_from_start:
		if is_instance_valid(start_menu):
			start_menu.visible = true
			var achv_btn: Button = start_menu.find_child("AchievementsButton", true, false)
			if is_instance_valid(achv_btn):
				achv_btn.grab_focus()
	elif achievements_from_hub:
		achievements_from_hub = false # 枢纽从未离开画面，无需恢复任何菜单
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
	settings_from_hub = false
	achievements_from_hub = false
	if is_instance_valid(pause_menu): pause_menu.visible = false
	if is_instance_valid(settings_menu): settings_menu.visible = false
	overlay.visible = false
	chase.set_active(GameManager.is_in_chase())
	if is_instance_valid(active_course) and active_course.runner.started and not active_course.runner.completed:
		active_course.runner.set_dogs_active(true)
	_restore_control()
	_refresh_hud()

# ------------------------------------------------------------- ui auto-hide
# 农场枢纽的常驻挂件在猪跑动时让位给画面，停稳后再回到玩家眼前：
# · 标题卡照旧淡出，停稳 UI_SHOW_IDLE 秒淡回；淡出期间按钮停止吃鼠标，
#   点击走位不会被看不见的按钮截走。
# · 今日待办改成折叠补丁状态机：跑动即折叠，右上角按钮永远可点（被藏起来
#   时的「随时可查」途径）；静止时按钮闪烁招引点击，静止满 UI_SHOW_IDLE 秒
#   仍无人点击才替玩家自动展开。
# · 键位说明是手动挂件：右上角按钮点开展示 KEY_STRIP_SHOW 秒自动收起，
#   默认隐藏，不参与跑动淡出。只动 modulate/visible，进关/暂停等状态自己
#   管挂件组的 visible，两边不打架。
const UI_HIDE_SPEED := 0.5
const UI_SHOW_IDLE := 3.0
var _ui_auto_hidden := false
var _ui_idle_time := 0.0
var _ui_fade_tween: Tween = null
var _todo_idle_time := 0.0
var _todo_blink_tween: Tween = null

func _update_ui_auto_hide(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var blocked: bool = in_start_menu or paused or in_settings or dialogue_open or cinematic or is_instance_valid(_brain_quiz)
	if blocked:
		_ui_idle_time = 0.0
		_todo_idle_time = 0.0
		# 对话/脑洞问答期间不把标题卡亮回来（2026-11-16 实机反馈）——左上角
		# 的"开始游戏"该给台词让位；其余模态（开始菜单/暂停/设置/演出）维持
		# 亮回，供玩家随时回枢纽。
		if _ui_auto_hidden and not dialogue_open and not is_instance_valid(_brain_quiz):
			_set_ui_auto_hidden(false)
		_stop_todo_blink()
		return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	# 标题卡：跑动淡出，停稳 3 秒淡回（只在猪圈枢纽存在，进关后随卡消失；
	# 模态期间的亮回/冻结在上方 blocked 分支里处理）。
	if is_instance_valid(_title_card):
		if speed > UI_HIDE_SPEED:
			_ui_idle_time = 0.0
			if not _ui_auto_hidden:
				_set_ui_auto_hidden(true)
		elif _ui_auto_hidden:
			_ui_idle_time += delta
			if _ui_idle_time >= UI_SHOW_IDLE:
				_set_ui_auto_hidden(false)
	# 今日待办：跑动折叠、静止闪烁、久站自动展开（枢纽与赛道内都生效）。
	if is_instance_valid(todo_hub) and todo_hub.visible:
		if speed > UI_HIDE_SPEED:
			_todo_idle_time = 0.0
			_set_todo_folded(true)
			_stop_todo_blink()
		else:
			_todo_idle_time += delta
			if todo_folded:
				_start_todo_blink()
				if _todo_idle_time >= UI_SHOW_IDLE:
					_set_todo_folded(false) # 静止 3 秒无人点击，替玩家展开
			else:
				_stop_todo_blink()

func _set_ui_auto_hidden(hidden: bool) -> void:
	_ui_auto_hidden = hidden
	_ui_idle_time = 0.0
	if not is_instance_valid(_title_card):
		return
	if _ui_fade_tween != null and _ui_fade_tween.is_valid():
		_ui_fade_tween.kill()
	_ui_fade_tween = create_tween()
	_ui_fade_tween.tween_property(_title_card, "modulate:a", 0.0 if hidden else 1.0, 0.25)
	_title_card_buttons_clickable(not hidden)

func _title_card_buttons_clickable(clickable: bool) -> void:
	if not is_instance_valid(_title_card):
		return
	for btn in _title_card.find_children("*", "Button", true, false):
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE

# ------------------------------------------------------------- todo folding
# 待办折叠状态机：按钮是唯一常驻入口，展开态由它与跑动/久站共同决定。
func _set_todo_folded(folded: bool) -> void:
	todo_folded = folded
	if is_instance_valid(todo_notebook):
		todo_notebook.visible = not folded
	if folded:
		_stop_todo_blink()

func _toggle_todo() -> void:
	if todo_folded:
		_set_todo_folded(false)
	else:
		_set_todo_folded(true)
		# 刚收起就重新起算闪烁窗口：静止中手动收起不会被下一帧立刻弹回。
		_todo_idle_time = 0.0

# 待办按钮闪烁：静止且折叠时的招引脉冲（0.45s 半程），展开/跑动/收起即停。
func _start_todo_blink() -> void:
	if _todo_blink_tween != null and _todo_blink_tween.is_valid():
		return
	_todo_blink_tween = create_tween().set_loops()
	_todo_blink_tween.tween_property(todo_toggle_btn, "modulate:a", 0.35, 0.45)
	_todo_blink_tween.tween_property(todo_toggle_btn, "modulate:a", 1.0, 0.45)

func _stop_todo_blink() -> void:
	if _todo_blink_tween != null and _todo_blink_tween.is_valid():
		_todo_blink_tween.kill()
	_todo_blink_tween = null
	if is_instance_valid(todo_toggle_btn):
		todo_toggle_btn.modulate.a = 1.0

# 挂件组（按钮 + 待办）随进关/暂停/菜单整体显隐；每次藏起都回到折叠默认态，
# 重见天日时永远是「只露按钮」的干净初始状态。
func _set_todo_hub_visible(shown: bool) -> void:
	if is_instance_valid(todo_hub):
		todo_hub.visible = shown
	if not shown:
		_set_todo_folded(true)
		_todo_idle_time = 0.0

# ------------------------------------------------------------- key strip
# 键位说明：右上角按钮点开展示 10 秒自动收起；再点一次立即收起（开关语义）。
const KEY_STRIP_SHOW := 10.0
var _key_strip_time_left := 0.0

func _toggle_key_strip() -> void:
	if is_instance_valid(key_strip) and key_strip.visible:
		_hide_key_strip()
	else:
		_show_key_strip_timed()

func _show_key_strip_timed() -> void:
	if not is_instance_valid(key_strip):
		return
	key_strip.visible = true
	_key_strip_time_left = KEY_STRIP_SHOW

func _hide_key_strip() -> void:
	_key_strip_time_left = 0.0
	if is_instance_valid(key_strip):
		key_strip.visible = false

func _process(delta: float) -> void:
	_update_ui_auto_hide(delta)
	# 键位说明的 10 秒展示窗（QTE 提前返回也要继续倒数，所以放在最前）。
	if _key_strip_time_left > 0.0:
		_key_strip_time_left -= delta
		if _key_strip_time_left <= 0.0:
			_hide_key_strip()
	# Key-test strip highlight (pigpen tutorial): bound actions light their keycaps.
	if is_instance_valid(key_strip) and key_strip.visible:
		for tag in key_strip_caps:
			var pressed := false
			if tag == "__mouse__":
				pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			elif tag == "__squeal__":
				pressed = Input.is_action_pressed("action_dash") and Input.is_action_pressed("action_jump")
			else:
				pressed = Input.is_action_pressed(tag)
			var tint := UI.SUNNY if pressed else UI.WHITE
			for cap in key_strip_caps[tag]:
				cap.modulate = tint
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
	if in_start_menu or paused or in_settings or dialogue_open or (overlay.visible and not paused) or cinematic:
		prompt.visible = false
		return
	if GameManager.is_in_chase():
		prompt.text = "犬队逼近 %.1f m ｜ Shift 闪避 · 空格 跳跃 · 被咬狂按空格" % pressure
	else:
		var target := player.get_nearest_interactable()
		if is_instance_valid(target):
			var id: String = str(target.get_meta("interaction_id", ""))
			var names := {"goat": "老岩羊", "ox": "老牛", "sheep": "小羊", "horse": "追风", "farmer": "农场主", "record_board": "纪录牌", "cablecar": "索道", "trough": "食槽"}
			prompt.text = "[ F ]  " + str(names.get(id, "调查"))
		else:
			prompt.text = ""
	prompt.visible = not prompt.text.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if sleep_playing and _sleep_skip_allowed:
		# 睡着演出的后半段（趴下之后）可快进：F/空格/回车/点击任一即跳。
		var fast_forward: bool = event.is_action_pressed("action_interact") or event.is_action_pressed("action_jump") \
			or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
		if fast_forward:
			_sleep_skip = true
			get_viewport().set_input_as_handled()
			return

	# R 键自救（2026-11-15 实机反馈 #16）：农场漫游态里卡墙/卡栏杆时回到
	# 上一个存档点。追逐与赛道期间不生效（那里有自己的重试/重生规则）。
	if event.is_action_pressed("action_respawn") and not event.is_echo():
		if not in_start_menu and not paused and not dialogue_open and not cinematic \
				and not is_instance_valid(active_course) and not GameManager.is_in_chase() \
				and is_instance_valid(player) and player.control_mode == "explore" \
				and is_instance_valid(farm) and farm._checkpoint != Vector3.ZERO:
			player.reset_at(farm._checkpoint)
			camera.snap_to_target()
			_show_toast("回到上一个落脚点", "卡住了就按 R——路是自己走出来的，也是自己退回去的。")
			get_viewport().set_input_as_handled()
			return

	# W/S 在选项间循环移动（2026-11-17 实机反馈：键盘玩家不碰鼠标也能选）；
	# 空格交给焦点按钮激活（GUI 层先于 unhandled，不会误推进台词）。
	if dialogue_open and not busy and not cinematic and (pokemon_battle == null or not pokemon_battle.battle_active):
		if options.get_child_count() > 0 and (event.is_action_pressed("move_up") or event.is_action_pressed("move_down")):
			var step := -1 if event.is_action_pressed("move_up") else 1
			var target := posmod(_dialogue_focus + step, options.get_child_count())
			(options.get_child(target) as Control).grab_focus()
			get_viewport().set_input_as_handled()
			return
		var advance: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("action_interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
		if advance and options.get_child_count() == 0:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
			return
			
	if event.is_action_pressed("ui_cancel") and not cinematic and GameManager.stage != "ending":
		# The brain-hole quiz owns the screen centre until it is answered - ESC
		# cannot open the pause menu underneath it (its buttons sit under the
		# quiz panel, and unpausing later would un-lock the pig mid-question).
		if is_instance_valid(_brain_quiz):
			return
		if achievements_menu != null and is_instance_valid(achievements_menu) and achievements_menu.visible:
			_close_achievements()
			get_viewport().set_input_as_handled()
			return
		if in_settings:
			_close_settings()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(_title_card):
			# 猪圈枢纽：ESC 直开游戏设置——标题卡按钮上的【ESC】就是这个承诺，
			# 不经暂停菜单（进关后标题卡消失，ESC 恢复为暂停开关）。
			_open_hub_settings()
			get_viewport().set_input_as_handled()
			return
		if in_start_menu:
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
	# The pigpen tutorial sandbox arms dash too - otherwise every refresh here
	# would re-lock it mid-tutorial (it did, before the flag existed).
	player.set_dash_enabled(GameManager.has_dash_skill or GameManager.tutorial_free_roam)
	if is_instance_valid(pin_visual): pin_visual.visible = GameManager.has_pin
	if is_instance_valid(todo_hub):
		var battle_on: bool = is_instance_valid(pokemon_battle) and pokemon_battle.battle_active
		_set_todo_hub_visible(not in_start_menu and not paused and not overlay.visible and not battle_on)
		if todo_hub.visible:
			_refresh_todo_list()

func _on_interact(target: Node3D) -> void:
	# 2026-11-17 实机反馈：从墙缺口进牛耕地绕过了门口安全区，追逐不结束，
	# 牛就永远说不上话——NPC（牛/羊/马/岩羊）在追逐中也可交互；对话打开的
	# 瞬间脱险（open_dialogue 内停狗），狗不可能在对话里咬猪。
	var target_id := str(target.get_meta("interaction_id", "")) if is_instance_valid(target) else ""
	var npc_talk_in_chase: bool = GameManager.is_in_chase() and target_id in ["ox", "sheep", "horse", "goat"]
	if dialogue_open or overlay.visible or cinematic or GameManager.stage == "ending": return
	if GameManager.is_in_chase() and not npc_talk_in_chase: return
	if not is_instance_valid(target): return
	var id := str(target.get_meta("interaction_id", ""))
	if id == "trough":
		_snuffle_trough(target)
		return
	if GameManager.tutorial_free_roam:
		# Pre-game sandbox: nobody talks, nothing opens. F on the goat routes into
		# the SAME door as the title card's 开始游戏 (brain-hole quiz → fall asleep
		# → dream); the cliff_goat_intro story beat only plays AFTER the dream,
		# when tutorial_free_roam is already false - the narrative order survives.
		# 2026-11-15 实机反馈 #15：二周目不再重演序章（键位教学整个流程只演
		# 一次）——F 老岩羊直接拿插销开圈出逃。
		if id == "goat":
			if GameManager.ng_plus:
				_skip_prologue_for_ng_plus()
			else:
				_begin_dream_from_pigpen()
		else:
			_show_notice("（现在还不能对话——先在猪圈里把蹄子练开，练累了回窝眯一觉：点左上『开始游戏』，或来找山羊按 [ F ] 入梦。）")
		return
	if id == "farmer":
		if GameManager.stage == "showdown" or (GameManager.has_pin and GameManager.npc_completed.get("horse", false) and GameManager.stage != "cablecar_ready" and GameManager.stage != "ending"):
			if GameManager.stage != "showdown":
				GameManager.stage = "showdown"
			_start_farmer_showdown()
			return
	var entry: String = DialogueManager.get_entry_for(id)
	if GameManager.npc_met.has(id): GameManager.npc_met[id] = true
	# 马的截停只认对话：靠近按 F 才停，对话结束继续自主跑圈。
	if id == "horse" and not entry.is_empty():
		farm.set_horse_halted(true)
	if not entry.is_empty(): open_dialogue(entry)

func open_dialogue(key: String) -> void:
	if in_start_menu:
		in_start_menu = false
		if is_instance_valid(start_menu):
			start_menu.visible = false
	# 追逐中打开任何对话 = 跑到了伙伴/牌旁，恶犬不再上前（与过门脱险同一
	# 语义：停狗、记完成、回探索态）。咬住中的 QTE 不该进对话（qte 模式下
	# 交互不来），这里只处理"追着但没咬住"。
	if GameManager.is_in_chase():
		chase.stop_chase()
		var rescued_chase := current_chase_id
		GameManager.complete_stage_chase(rescued_chase)
		if is_instance_valid(player):
			player.set_control_mode("explore")
		# 关上本段追逐的区域门（牛/羊/马），门栓横上——「狗被挡在门外」的
		# 视觉答案，走墙缺口进来的人也能看到。
		var gate_for_chase := {"chase_1": "ox", "chase_2": "sheep", "chase_3": "horse"}
		if gate_for_chase.has(rescued_chase) and is_instance_valid(farm):
			farm.set_named_gate_open(gate_for_chase[rescued_chase], false)
		# 眼前屏障：走缺口的人看不到身后的门关了——在猪的来路方向弹起
		# 一道木栅栏，狗被挡住的视觉答案就在眼前。
		if is_instance_valid(farm) and is_instance_valid(player):
			var facing := player.global_position - player.velocity.normalized() if player.velocity.length_squared() > 0.1 else player.global_position + Vector3.FORWARD
			farm.spawn_rescue_barrier(player.global_position, facing)
		_show_toast("恶犬不敢上前", "跑到了伙伴身边——猎犬在几步外徘徊着退开了。")
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
	# 通知流加在对话面板之后（渲染在上层），对话期间藏起，避免残留卡片压住台词。
	if is_instance_valid(notice_feed): notice_feed.visible = false
	# 标题卡同样让位（2026-11-16 实机反馈）：对话读台词时左上角不该挂着
	# "开始游戏"，按钮也不再可点。关掉对话后停稳 3 秒它自然淡回（枢纽期）。
	if is_instance_valid(_title_card) and not _ui_auto_hidden:
		_set_ui_auto_hidden(true)
	if is_instance_valid(toast_panel) and toast_panel.visible: _place_toast()
	speaker_label.text = str(data.get("speaker", "")) + "  /  " + str(data.get("title", ""))
	portrait.texture = ART_2D.PORTRAITS.get(str(data.get("speaker", "")))
	portrait.visible = portrait.texture != null
	if dialogue_vo != null:
		dialogue_vo.play_for(str(data.get("id", current_dialogue)))
	var world := get_tree().get_first_node_in_group("farm_world")
	if world != null and world.has_method("play_npc_action"):
		world.play_npc_action(str(data.get("speaker", "")), "talk")
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
	if is_instance_valid(notice_feed): notice_feed.visible = false # 同上：对决期间不压界面
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	if is_instance_valid(prompt):
		prompt.visible = false
	_set_todo_hub_visible(false)
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
		if player.has_method("play_victory_animation"):
			player.play_victory_animation()
		_show_toast("意志对决胜利！铁门轰然开启！", "农场主掌控欲彻底瓦解，快穿过大铁门登上后山索道！")
		_restore_control()
	else:
		# Failure ending beat: dragged back to the pen in front of the gate,
		# the 6am truck looming - then the pig grits its teeth and goes again.
		# The stage stays "showdown", so a retry is a seamless re-challenge.
		player.set_control_mode("paused")
		_show_overlay("败下阵来",
			"电击棍的麻意还没散。你被拖索拽回铁门前，项圈上多了一道勒痕。\n“明早的车不等人。”\n\n（黎明之前——把话说得再硬一点。）",
			[
				{"text": "再战一场", "call": _retry_farmer_showdown},
				{"text": "从头开始", "call": _restart},
			])
		return
	_refresh_hud()

func _retry_farmer_showdown() -> void:
	if is_instance_valid(overlay):
		overlay.visible = false
	_start_farmer_showdown()

func _split_lines(content: String) -> Array:
	var lines := []
	for line in content.split("\n"):
		var text := str(line).strip_edges()
		if not text.is_empty():
			lines.append(text)
	if lines.is_empty():
		lines.append("")
	return lines

## 对话选项的键盘高亮：W/S 移动焦点（真实 grab_focus，空格/回车由焦点
## 按钮在 GUI 层吃掉），同时用 modulate 画出选中态——主题没有可见的
## focus 样式，纯焦点玩家看不见选到哪一行。
func _on_dialogue_focus_moved(index: int) -> void:
	_dialogue_focus = index
	_refresh_dialogue_focus()

func _refresh_dialogue_focus() -> void:
	for i in options.get_child_count():
		var button: Button = options.get_child(i)
		button.modulate = Color(1.15, 1.08, 0.85) if i == _dialogue_focus else Color(0.82, 0.82, 0.82)

func _show_current_line() -> void:
	content_label.text = str(dialogue_lines[line_index])
	var on_last_line := line_index >= dialogue_lines.size() - 1
	line_hint.visible = not on_last_line
	if on_last_line and options.get_child_count() == 0:
		for index in range(current_options.size()):
			var option: Dictionary = current_options[index]
			var option_button := _button(str(option.get("text", "继续")), _select_option.bind(index), true)
			# 高亮完全由焦点驱动（2026-11-17 review P2-4）：方向键在 GUI 层挪
			# 真实焦点、鼠标点击也先取焦点——单一事实源，W/S 只是 grab_focus。
			option_button.focus_entered.connect(_on_dialogue_focus_moved.bind(index))
			options.add_child(option_button)
		if options.get_child_count() > 0:
			_dialogue_focus = 0
			options.get_child(0).grab_focus()
			_refresh_dialogue_focus()

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
	for button in options.get_children():
		button.disabled = true
		button.modulate = Color(1, 1, 1)
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
						"被恶犬扑咬纠缠时，在 2.2 秒内猛敲空格 8 次，即可爆发巨力震退恶犬 6 米并使其眩晕！"
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
		"start_race":
			# 2026-11-15 实机反馈 #4/#5：纪录牌对话开赛（马场计时赛）。
			close_dialogue()
			ok = farm.begin_race_trial(player)
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
	if is_instance_valid(farm):
		farm.set_horse_halted(false)
	if dialogue_vo != null:
		dialogue_vo.stop()
	if is_instance_valid(notice_feed): notice_feed.visible = true
	if is_instance_valid(toast_panel) and toast_panel.visible: _place_toast()
	_restore_control()
	_refresh_hud()

## 对决界面（pokemon_showdown）借用：按对话节点 id 播 assets/audio/vo/ 下的同款配音。
func play_dialogue_vo(node_id: String) -> void:
	if dialogue_vo != null:
		dialogue_vo.play_for(node_id)

func _restore_control() -> void:
	if in_start_menu: player.set_control_mode("cinematic")
	elif cinematic: player.set_control_mode("cinematic")
	# The brain-hole quiz keeps the pig locked while it is up - falling through
	# to "explore" here (ESC pause/resume, settings level jumps) would free the
	# pig behind the panel that still blocks the screen centre.
	elif is_instance_valid(_brain_quiz): player.set_control_mode("locked")
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
	if stage_id != current_chase_id:
		_checkpoint_retries = 0 # the fail counter is per leg; re-arms keep it
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

func _on_playground_event(kind: String, _detail) -> void:
	# Farm playground easter eggs report here for the celebratory toasts
	# (achievements unlock farm-side; this is the presentation layer).
	# "gag" = 触发台词：不走中央横幅，弹右下角通知（地图上的世界小字不可读）。
	if kind == "gag":
		_show_notice(str(_detail))
		return
	match kind:
		"cabbage_goal":
			_show_toast("GOOOAL！", "卷心菜应声入网——牛耕地球会记你一功！")
		"second_path":
			_show_toast("第二条路！", "倒木被顶开了——跳，或者撞，都是你的路。")
		"perfect_dive":
			_show_toast("满分入坑！", "10 分！麻雀评委全体起立。")
		"demolition_crew":
			_show_toast("拆家小队！", "全农场的农具都记住了这头猪。")
		"lawn_mower":
			_show_toast("除草机！", "十二株杂草，寸草不留——绵羊目瞪口呆。")
		"pig_paddle":
			_show_toast("落水猪！", "扑通——猪猪的第一次戏水，满分。")
		"steady_lap":
			_show_toast("稳稳一圈！", "规规矩矩沿跑道跑完一整圈——值得尊重。")
		"record_breaker":
			_show_toast("35 秒新纪录！", "马场计时赛——真·猪跑出来的圈速。")
		"fence_breaker":
			_show_toast("越狱惯犯！", "围栏的缺口是留给会钻的猪的。")
		"grass_gourmet":
			_show_toast("食草动物的本分", "六丛嫩草，一丛不落。")
		"potato_harvest":
			_show_toast("春耕的馈赠", "五颗土豆，全是从犁沟里拱出来的。")
		"apple_rain":
			_show_toast("牛顿的苹果！", "苹果雨 + 当场吃完 = 猪的科学发现。")

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
func _notification(what: int) -> void:
	# 赛道期间农场被 remove_child 暂存在树外（见 _enter_course）。这时关游戏、
	# 回主菜单或重开，引擎的树清理够不着这棵脱树子树：整座农场的物理体、
	# 网格、贴图全成孤儿——退出时刷出数千行 RID 泄漏报错，甚至直接崩溃。
	# 本节点销毁前亲手把它释放掉。
	if what == NOTIFICATION_PREDELETE and _farm_removed and is_instance_valid(farm) and not farm.is_inside_tree():
		farm.free()

func _enter_course(stage_id: String) -> void:
	if is_instance_valid(active_course): return
	_dismiss_qte_for_world_switch() # 洞口前被咬住：换世界即脱险，QTE 面板不跟着进关
	var scene_res = COURSE_SCENES.get(stage_id, COURSE_SCENES.get("course_1"))
	active_course = scene_res.instantiate()
	add_child(active_course)
	# 分区 BGM：赛道各自成曲（追逐腿也走赛道场景，统一在这里换）。
	# intro 梦境（course_0）从这里拿到 nightmare 曲；文件缺失时静默不播。
	if active_course.runner != null and active_course.runner.config != null:
		var track_id := MusicManager.track_for_course(active_course.runner.config.course_id)
		if not track_id.is_empty():
			MusicManager.play(track_id)
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
		# 弹起身（入睡演出的反向 tween）：_exit_course 的 reset_at 已把猪拉回
		# 站姿，这里先瞬间摆回趴姿再弹起——下面两条故事 toast 讲「从泥窝里
		# 弹起来」时，画面里真的在弹。
		player.snap_sleep_pose()
		player.play_wake_pose(0.55)
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
	_dismiss_qte_for_world_switch() # 对称保险：出赛道同样立刻收掉挂着的 QTE
	GameManager.clear_course_skills()
	MusicManager.play("farm") # 出赛道回农场：田园基调接回
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
	# Exit drops match the visual exit stubs in FarmGrounds; each lands deep in
	# the next meadow (>= 26 m from its hidden entrance, clear of gates/fences).
	match completed_id:
		"chase_1":
			exit_pos = Vector3(38.0, 24.1, 52.0)
		"chase_2":
			exit_pos = Vector3(-44.0, 16.1, -37.0)
		"chase_3":
			exit_pos = Vector3(27.0, 8.1, -103.5)
		"chase_final":
			exit_pos = Vector3(-75.5, 2.1, -223.5)
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
		_checkpoint_retry_chase()

# Caught without breaking free: no game-over menu any more. The pig is dropped
# back at the last trail checkpoint of this chase (farm._checkpoint trails the
# journey within 14 m, so it is "上一个检查点" by construction) and the same
# stage re-arms itself after a short beat - the pressure is the mash clock,
# the penalty is re-running the leg, not reading a menu.
func _checkpoint_retry_chase() -> void:
	chase.stop_chase()
	in_qte = false
	_checkpoint_retries += 1
	var retry_pos: Vector3 = farm._checkpoint
	player.reset_at(retry_pos)
	GameManager.retry_chase()
	_restore_control()
	camera.snap_to_target()
	_show_toast("被扑住了！", "第 %d 次没挣脱——回到检查点，重新跑这段路！" % _checkpoint_retries)
	_refresh_hud()
	await get_tree().create_timer(1.4).timeout
	# Re-arm only when the world is calm; a refused QTE request would wedge the
	# runner (same guard as _on_qte_requested).
	if is_inside_tree() and not dialogue_open and not cinematic and not overlay.visible and not paused and not GameManager.is_in_chase():
		start_stage_chase(current_chase_id)

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
		MusicManager.play("ending")
		_show_overlay("旷野归途", "金牌是农场的，但命是你自己的。\n\n风从麦浪上吹来。前面没有围栏与食槽。", [{"text": "重新出发", "call": _restart}])
	ending_art.texture = ART_2D.ENDINGS.get(GameManager.ending)
	ending_art.visible = ending_art.texture != null

func _show_overlay(title: String, body: String, buttons: Array) -> void:
	ending_art.hide()
	overlay.color = Color(UI.PAPER, 0.96)
	overlay.get_child(0).visible = true
	_set_todo_hub_visible(false)
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
	# 从头开始 goes back to the top: the pigpen tutorial, the game's front door
	# (not the dimmed start-menu over the world - the boot flow skips it now).
	GameManager.pending_boot = "farm"
	get_tree().reload_current_scene()
