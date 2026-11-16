extends Control
class_name PokemonShowdown

## Pokemon-style Turn-Based Showdown Battle with the Farmer at the Iron Gate.
## Untitled Goose Game art style: low-poly, flat-shaded, rustic paper/parchment palette, zero texture noise.

signal battle_completed(success: bool)

const ART_2D = preload("res://scripts/art/art_2d.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")

# Battle Stats
var farmer_hp: float = 100.0
var farmer_max_hp: float = 100.0
var pig_hp: float = 100.0
var pig_max_hp: float = 100.0
var current_turn: int = 1
var is_busy: bool = false
var battle_active: bool = false

# Parent / Level reference
var level_ref: Node = null

# UI Elements
var root_box: Control = null
var background_panel: PanelContainer
var farmer_plate: PanelContainer
var farmer_hp_bar: ProgressBar
var farmer_hp_label: Label
var farmer_status_badge: Label
var farmer_portrait: TextureRect

var pig_plate: PanelContainer
var pig_hp_bar: ProgressBar
var pig_hp_label: Label
var pig_status_badge: Label
var pig_portrait: TextureRect

var console_panel: PanelContainer
var narrative_label: Label
var turn_header_label: Label
var move_buttons: Array[Button] = []
var floating_container: Control

const MOVE_ACCENTS := [Color("E8836B"), Color("A9744F"), Color("5FB8A6"), Color("8FC97A")]

const MOVES := [
	{
		"name": "【 斗 志 冲 击 】",
		"subtext": "正面冲撞 · 坚决破围 (基础威力 30)",
		"desc": "低头猛冲，用坚决的额头正面撞击！不退缩，不犹疑！",
		"damage": 30,
		"counter_round": -1
	},
	{
		"name": "【 借 牛 之 坚 】",
		"subtext": "阿牛硬骨 · 坚韧反震 (克制规训 42)",
		"desc": "“不向重负认命，骨头就是硬的！” 唤起阿牛的铁骨气，反弹压迫！",
		"damage": 36,
		"counter_round": 2
	},
	{
		"name": "【 借 羊 之 眸 】",
		"subtext": "绵绵明眸 · 破妄暴击 (克制诱惑 46)",
		"desc": "“规训只是幻影，甜料只是诱饵！” 识破虚妄之相，弱点破防！",
		"damage": 40,
		"counter_round": 1
	},
	{
		"name": "【 借 马 之 风 】",
		"subtext": "追风极速 · 闪避破门 (先制终结 41)",
		"desc": "“向着山风狂奔！” 先制极速闪避挥空的电击棍，绕后猛冲铁门！",
		"damage": 35,
		"counter_round": 3
	}
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_update_layout()
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _update_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(root_box):
		root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(console_panel):
		console_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		console_panel.offset_left = 35
		console_panel.offset_right = -35
		console_panel.offset_top = -250
		console_panel.offset_bottom = -20
	if is_instance_valid(farmer_plate):
		farmer_plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		farmer_plate.offset_left = -480
		farmer_plate.offset_right = -35
		farmer_plate.offset_top = 25
		farmer_plate.offset_bottom = 155
	if is_instance_valid(pig_plate):
		pig_plate.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		pig_plate.offset_left = 35
		pig_plate.offset_right = 480
		pig_plate.offset_top = -395
		pig_plate.offset_bottom = -265

func _build_ui() -> void:
	# Root container
	root_box = Control.new()
	root_box.name = "BattleArena"
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_box)

	floating_container = Control.new()
	floating_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floating_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floating_container)

	# 1. Opponent Plate (Top-Right: Farmer)
	farmer_plate = _create_status_plate(false)
	farmer_plate.custom_minimum_size = Vector2(440, 120)
	root_box.add_child(farmer_plate)

	# 2. Player Plate (Bottom-Left: White Piglet)
	pig_plate = _create_status_plate(true)
	pig_plate.custom_minimum_size = Vector2(440, 125)
	root_box.add_child(pig_plate)

	# 3. Bottom Battle Deck (Classic Pokemon 2-Column Command Panel)
	console_panel = PanelContainer.new()
	console_panel.name = "ConsolePanel"
	console_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	console_panel.clip_contents = true
	console_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.98, 0.96, 0.90, 0.98), Color(0.40, 0.32, 0.22), 16, 4))
	root_box.add_child(console_panel)

	var deck_row := HBoxContainer.new()
	deck_row.add_theme_constant_override("separation", 20)
	console_panel.add_child(deck_row)

	# Left Column: Battle Narrative Log Box (~56%)
	var log_box := PanelContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.size_flags_stretch_ratio = 1.25
	log_box.add_theme_stylebox_override("panel", _panel_style(Color(0.94, 0.91, 0.82), Color(0.60, 0.52, 0.40), 12, 2))
	deck_row.add_child(log_box)

	var log_vbox := VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 8)
	log_box.add_child(log_vbox)

	turn_header_label = _label("【 铁 门 前 的 决 战 · 第 1 回 合 】", 16)
	turn_header_label.add_theme_font_override("font", UI.font_bold())
	turn_header_label.add_theme_color_override("font_color", UI.CORAL)
	log_vbox.add_child(turn_header_label)

	narrative_label = _label("农场主 挡在大铁门前，手中高压电击棍滋滋作响！\n请选择一口猪的对抗招式：", 16)
	narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# autowrap 标签在布局前宽度为 0，会把「每字一行」的高度当成最小高度，
	# 把整个指挥台撑到屏幕外（技能格全_off-screen_）。钉一个最小宽度锁住换行。
	narrative_label.custom_minimum_size = Vector2(430, 0)
	narrative_label.add_theme_color_override("font_color", UI.INK)
	narrative_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_vbox.add_child(narrative_label)

	# Right Column: 2x2 Move Command Grid (~44%)
	var command_box := VBoxContainer.new()
	command_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_box.add_theme_constant_override("separation", 10)
	deck_row.add_child(command_box)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	row1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_box.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_box.add_child(row2)

	move_buttons.clear()
	for i in range(MOVES.size()):
		var move: Dictionary = MOVES[i]
		var btn := _create_move_button(i, move.name, move.subtext)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if i < 2:
			row1.add_child(btn)
		else:
			row2.add_child(btn)
		move_buttons.append(btn)

func _create_status_plate(is_player: bool) -> PanelContainer:
	var plate := UI.patch_panel(18, UI.PAPER, UI.CORAL if is_player else UI.TEAL, Vector2(16, 12))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	plate.add_child(row)

	# Avatar in a stitched patch frame
	var frame := UI.patch_panel(18, UI.WHITE, UI.SAGE, Vector2(5, 5))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(78, 78)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = ART_2D.PORTRAITS.get("一口猪" if is_player else "农场主")
	frame.add_child(portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)

	# Name + Badge Row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	col.add_child(title_row)

	var name_text := "一口猪  Lv.47" if is_player else "农场主  Lv.40"
	var name_lbl := _label(name_text, 18)
	name_lbl.add_theme_font_override("font", UI.font_bold())
	name_lbl.add_theme_color_override("font_color", UI.INK)
	title_row.add_child(name_lbl)

	var badge := _label("[ 自由意志 ]" if is_player else "[ 权威态 ]", 13)
	badge.add_theme_color_override("font_color", UI.CORAL if is_player else UI.TEAL)
	title_row.add_child(badge)

	# HP Row
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	col.add_child(hp_row)

	var tag := UI.label("HP", 14, UI.CORAL, true)
	hp_row.add_child(tag)

	var bar := UI.progress_bar(100.0, 100.0, UI.SAGE_DEEP, Vector2(170, 16))
	hp_row.add_child(bar)

	var hp_lbl := _label("100 / 100", 14)
	hp_lbl.add_theme_color_override("font_color", UI.INK_SOFT)
	hp_row.add_child(hp_lbl)

	if is_player:
		pig_hp_bar = bar
		pig_hp_label = hp_lbl
		pig_status_badge = badge
		pig_portrait = portrait

		# Companion Tags Row
		var comp_row := HBoxContainer.new()
		comp_row.add_theme_constant_override("separation", 6)
		col.add_child(comp_row)
		for tag_str in ["★ 阿牛·坚韧", "★ 绵绵·明眸", "★ 追风·疾速"]:
			var c_lbl := _label(tag_str, 12)
			c_lbl.add_theme_color_override("font_color", UI.INK_SOFT)
			comp_row.add_child(c_lbl)
	else:
		farmer_hp_bar = bar
		farmer_hp_label = hp_lbl
		farmer_status_badge = badge
		farmer_portrait = portrait

	return plate

func _create_move_button(index: int, title: String, subtext: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.custom_minimum_size = Vector2(150, 48)
	# NOTE: btn.text MUST be empty! Godot Button natively draws its own text,
	# so assigning btn.text while also adding child labels causes severe text overlap / double-rendering!
	btn.text = ""

	# 宝可梦式属性色：每招一个伙伴色系边框，聚焦时标题前亮出 ▶ 光标。
	var accent: Color = MOVE_ACCENTS[index % MOVE_ACCENTS.size()]
	var normal_style := UI.pill(UI.WHITE, 16, accent, 3, Vector2(12, 8))
	var hover_style := UI.pill(UI.SAGE, 16, UI.TEAL, 2, Vector2(12, 8))
	var pressed_style := UI.pill(UI.SAGE_DEEP, 16, Color.TRANSPARENT, 0, Vector2(12, 8))
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", hover_style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	btn.add_child(vbox)

	var base_title := "[ %d ]  %s" % [index + 1, title]
	var title_lbl := _label(base_title, 15)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", UI.font_bold())
	title_lbl.add_theme_color_override("font_color", UI.INK)
	vbox.add_child(title_lbl)

	var sub_lbl := _label(subtext, 12)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_color_override("font_color", UI.INK_SOFT)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub_lbl)

	var update_colors := func(highlighted: bool):
		if not is_instance_valid(title_lbl) or not is_instance_valid(sub_lbl): return
		if highlighted or btn.has_focus():
			title_lbl.text = "▶ " + base_title
			title_lbl.add_theme_color_override("font_color", UI.TEAL_DEEP)
			sub_lbl.add_theme_color_override("font_color", UI.INK)
		else:
			title_lbl.text = base_title
			title_lbl.add_theme_color_override("font_color", UI.INK)
			sub_lbl.add_theme_color_override("font_color", UI.INK_SOFT)

	btn.mouse_entered.connect(func(): update_colors.call(true))
	btn.mouse_exited.connect(func(): update_colors.call(false))
	btn.focus_entered.connect(func(): update_colors.call(true))
	btn.focus_exited.connect(func(): update_colors.call(false))

	btn.pressed.connect(func(): execute_move(index))
	return btn

func _panel_style(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	return UI.patch(radius, bg, Vector2(14, 10), 6)

func _label(text: String, font_size: int) -> Label:
	return UI.label(text, font_size)

# -------------------------------------------------------------
# Battle Flow Control
# -------------------------------------------------------------
func start_battle(level: Node) -> void:
	level_ref = level
	farmer_hp = 100.0
	pig_hp = 100.0
	current_turn = 1
	is_busy = false
	battle_active = true
	_update_layout()
	visible = true

	_update_hp_displays()
	_update_farmer_status("[ 权威态 ]", Color(0.50, 0.42, 0.30))
	_update_pig_status("[ 自由意志 ]", Color(0.72, 0.28, 0.18))

	turn_header_label.text = "【 铁 门 前 的 决 战 · 第 1 回 合 】"
	narrative_label.text = "野生的 农场主 (Lv.40) 挡住了去路！\n“047号！明早车就来了，老实回圈加满甜麦麸！”\n请选择一口猪的对抗招式："
	# 对决台词走自己的精简文案，配音按同义对话节点播（TTS 白盒）
	if is_instance_valid(level_ref) and level_ref.has_method("play_dialogue_vo"):
		level_ref.play_dialogue_vo("ordeal_encounter")

	_sync_dialogue_options()
	_enable_buttons(true)
	if move_buttons.size() > 0:
		move_buttons[0].grab_focus()
	_stage_battle_intro()

func execute_move(move_index: int) -> void:
	if is_busy or not battle_active or move_index < 0 or move_index >= MOVES.size():
		return
	is_busy = true
	if is_instance_valid(level_ref) and "busy" in level_ref:
		level_ref.busy = true
	_enable_buttons(false)

	var move: Dictionary = MOVES[move_index]
	var dmg: float = float(move.damage)
	var is_counter: bool = (move.counter_round == current_turn)
	# Counter system: a companion move only lands its full weight on the round
	# it counters; on any other round the farmer's pressure blunts it to 30%.
	# 斗志冲击 (counter_round -1) is honest plain damage, never a misfire.
	var is_misfire: bool = (not is_counter) and move.counter_round > 0
	if is_misfire:
		dmg *= 0.3

	# 1. Pig attack narrative
	var pig_log := ""
	match move_index:
		0:
			pig_log = "一口猪 踏地猛冲！使出【斗志冲击】！额头坚决撞击农场主的防线！"
		1:
			pig_log = "一口猪 唤起阿牛的意志：‘不向重负认命，骨头就是硬的！’【借牛之坚】反弹压迫！"
		2:
			pig_log = "一口猪 清澈明眸洞悉虚妄：‘甜料再甜也是饵，你养我只为按斤称肉！’【借羊之眸】暴击破妄！"
		3:
			pig_log = "一口猪 借追风四蹄翻腾极速：‘奔跑为了感受山风！’【借马之风】闪避电击棍并绕后猛冲！"

	_type_narrative(pig_log)
	if is_misfire:
		narrative_label.text += "\n……可是时机不对！这一招没能咬住他的话头——"
		narrative_label.visible_characters = -1
	_screen_shake()
	_stage_pig_attack(move_index)

	# Deal damage to Farmer
	farmer_hp = maxf(0.0, farmer_hp - dmg)
	_animate_hp_change(farmer_hp_bar, farmer_hp, farmer_hp_label, farmer_max_hp)

	var dmg_text := "-%d 克制破防!" % int(dmg) if is_counter else ("-%d 收效甚微…" % int(dmg) if is_misfire else "-%d 意志冲击!" % int(dmg))
	_spawn_damage_text(farmer_plate.global_position + Vector2(180, 40), dmg_text, Color(0.85, 0.25, 0.15))
	_stage_farmer_hit(dmg_text)

	await get_tree().create_timer(0.22).timeout

	# Check if Farmer defeated
	if farmer_hp <= 0.0:
		farmer_hp = 0.0
		_update_hp_displays()
		_resolve_victory()
		return

	# 2. Farmer counter-reaction (every round now - the pig's will can break)
	await get_tree().create_timer(0.12).timeout
	_farmer_counter_turn(is_counter)

func _farmer_counter_turn(was_countered: bool) -> void:
	# The threat lands full force when the pig's move did not counter this
	# round; a countered round only grazes (the pig still pays for standing
	# up to him). Numbers: full counter play leaves the pig near ~40 HP -
	# the razor's-edge win; one misfire and the pig is usually down first.
	var farmer_log := ""
	var pig_dmg := 0.0

	if current_turn == 1:
		farmer_log = "\n农场主 掏出满袋【甜麦麸】大声呵斥：“加满甜料还不够吗？！圈外没有你能吃的食槽！”"
		pig_dmg = 18.0 if was_countered else 32.0
		_update_farmer_status("[ 动摇中 ]" if was_countered else "[ 甜料攻势 ]", Color(0.75, 0.45, 0.15))
	elif current_turn == 2:
		farmer_log = "\n农场主 气急败坏高举电击棍：“肉猪的天职就是长肉！走出这道大门你什么都不是！”"
		pig_dmg = 20.0 if was_countered else 38.0
		_update_farmer_status("[ 惊愕破防 ]" if was_countered else "[ 电棍威吓 ]", Color(0.85, 0.30, 0.20))
	else:
		farmer_log = "\n农场主 挥舞电击棍扑了上来：“最后一步了——你出不了这道门！！”"
		pig_dmg = 22.0 if was_countered else 45.0
		_update_farmer_status("[ 狗急跳墙 ]", Color(0.85, 0.30, 0.20))
	# 第 2 回合的电棍威吓与对话节点 ordeal_turn_2 同义，播它的配音
	if current_turn == 2 and is_instance_valid(level_ref) and level_ref.has_method("play_dialogue_vo"):
		level_ref.play_dialogue_vo("ordeal_turn_2")

	_stage_farmer_attack()
	pig_hp = maxf(0.0, pig_hp - pig_dmg)
	_animate_hp_change(pig_hp_bar, pig_hp, pig_hp_label, pig_max_hp)
	_spawn_damage_text(pig_plate.global_position + Vector2(180, 40), "-%d 动摇" % int(pig_dmg), Color(0.55, 0.40, 0.25))
	_stage_pig_hit("-%d 动摇" % int(pig_dmg))

	narrative_label.text += farmer_log
	narrative_label.visible_characters = -1

	# The pig's will breaks first: down, or the farmer withstood all
	# three rounds. Either way the showdown is lost - and can be retried.
	if pig_hp <= 0.0 or current_turn >= 3:
		_resolve_defeat()
		return

	current_turn += 1
	turn_header_label.text = "【 铁 门 前 的 决 战 · 第 %d 回 合 】" % current_turn

	await get_tree().create_timer(0.18).timeout
	is_busy = false
	if is_instance_valid(level_ref) and "busy" in level_ref:
		level_ref.busy = false
	_enable_buttons(true)
	_sync_dialogue_options()

func _resolve_victory() -> void:
	_update_farmer_status("[ 彻底溃败 ]", Color(0.55, 0.50, 0.45))
	turn_header_label.text = "【 决 胜 · 铁 门 轰 然 敞 开 】"
	narrative_label.text = "农场主 电击棍脱手掉在地上，颓然跌坐在地……\n“跑了一头，亏了千把块……算了，圈里还有几百头。”\n\n轰——铛！！铁大门锁扣被彻底撞断！铁门轰然敞开！"
	if is_instance_valid(level_ref) and level_ref.has_method("play_dialogue_vo"):
		level_ref.play_dialogue_vo("ordeal_aftermath")
	if pig_hp <= 40.0:
		narrative_label.text += "\n\n（你浑身发抖，就剩一口喘着的气——可是门，开了。）"
	narrative_label.visible_characters = -1
	_screen_shake(8.0)
	_stage_farmer_collapse()

	await get_tree().create_timer(0.35).timeout
	is_busy = false
	if is_instance_valid(level_ref) and "busy" in level_ref:
		level_ref.busy = false
	battle_active = false
	visible = false
	battle_completed.emit(true)

func _resolve_defeat() -> void:
	_update_pig_status("[ 意志溃散 ]", Color(0.55, 0.50, 0.45))
	turn_header_label.text = "【 败 下 阵 来 】"
	narrative_label.text = "电击棍的麻意爬满四肢……你的四蹄一软，跪在了铁门前。\n农场主喘着粗气把拖索扣回你的项圈：“闹够了？回圈。明早的车，不等人。”\n\n（黎明之前，把话说得再硬一点——再来。）"
	narrative_label.visible_characters = -1
	_screen_shake(8.0)
	_stage_pig_slump()

	await get_tree().create_timer(0.35).timeout
	is_busy = false
	if is_instance_valid(level_ref) and "busy" in level_ref:
		level_ref.busy = false
	battle_active = false
	visible = false
	battle_completed.emit(false)

func _update_hp_displays() -> void:
	if is_instance_valid(farmer_hp_bar):
		farmer_hp_bar.value = farmer_hp
		farmer_hp_label.text = "%d / %d" % [int(farmer_hp), int(farmer_max_hp)]
		_style_hp_bar(farmer_hp_bar, farmer_hp)
	if is_instance_valid(pig_hp_bar):
		pig_hp_bar.value = pig_hp
		pig_hp_label.text = "%d / %d" % [int(pig_hp), int(pig_max_hp)]

func _animate_hp_change(bar: ProgressBar, target_val: float, label: Label, max_val: float) -> void:
	if not is_instance_valid(bar): return
	var tween := create_tween()
	tween.tween_property(bar, "value", target_val, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_callback(func():
		label.text = "%d / %d" % [int(target_val), int(max_val)]
		_style_hp_bar(bar, target_val)
	)

func _style_hp_bar(bar: ProgressBar, val: float) -> void:
	var col := UI.SAGE_DEEP
	if val <= 50.0:
		col = UI.SUNNY
	if val <= 20.0:
		col = UI.RED
	bar.add_theme_stylebox_override("fill", UI.pill(col, 9, Color.TRANSPARENT, 0, Vector2.ZERO))

func _update_farmer_status(text: String, col: Color) -> void:
	if is_instance_valid(farmer_status_badge):
		farmer_status_badge.text = text
		farmer_status_badge.add_theme_color_override("font_color", col)

func _update_pig_status(text: String, col: Color) -> void:
	if is_instance_valid(pig_status_badge):
		pig_status_badge.text = text
		pig_status_badge.add_theme_color_override("font_color", col)

func _enable_buttons(enabled: bool) -> void:
	for btn in move_buttons:
		if is_instance_valid(btn):
			btn.disabled = not enabled
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(0.7, 0.7, 0.7, 0.6)

func _screen_shake(intensity: float = 5.0) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)

func _spawn_damage_text(pos: Vector2, text: String, color: Color) -> void:
	if not is_instance_valid(floating_container): return
	var dmg_lbl := UI.label(text, 22, color, true)
	dmg_lbl.add_theme_color_override("font_outline_color", UI.WHITE)
	dmg_lbl.add_theme_constant_override("outline_size", 6)
	dmg_lbl.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-10, 10))
	floating_container.add_child(dmg_lbl)

	dmg_lbl.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(dmg_lbl, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(dmg_lbl, "position:y", dmg_lbl.position.y - 35, 0.45)
	tw.tween_property(dmg_lbl, "modulate:a", 0.0, 0.2)
	tw.tween_callback(dmg_lbl.queue_free)

# -------------------------------------------------------------
# Automation & Test Bridge
# Synchronize level_ref.options so automated test frameworks can click option 0
# -------------------------------------------------------------
func _sync_dialogue_options() -> void:
	if not is_instance_valid(level_ref): return
	if "options" in level_ref and is_instance_valid(level_ref.options):
		for child in level_ref.options.get_children():
			level_ref.options.remove_child(child)
			child.queue_free()
		for i in range(MOVES.size()):
			var m_data: Dictionary = MOVES[i]
			var opt_btn := Button.new()
			opt_btn.text = m_data.name + " " + m_data.subtext
			opt_btn.pressed.connect(func(): execute_move(i))
			level_ref.options.add_child(opt_btn)
	if "line_index" in level_ref and "dialogue_lines" in level_ref:
		level_ref.dialogue_lines = [narrative_label.text]
		level_ref.line_index = 0
	if "busy" in level_ref:
		level_ref.busy = false

func _unhandled_input(event: InputEvent) -> void:
	if not battle_active or is_busy: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: execute_move(0)
			KEY_2: execute_move(1)
			KEY_3: execute_move(2)
			KEY_4: execute_move(3)
			KEY_SPACE, KEY_ENTER:
				var has_btn_focus := false
				for b in move_buttons:
					if b.has_focus():
						has_btn_focus = true
						break
				if not has_btn_focus and move_buttons.size() > 0:
					execute_move(0)

# -------------------------------------------------------------
# 3D Battle Staging（宝可梦式演出层）
# 回合逻辑与时序完全不变；演出全部是视觉-only 的 tween/粒子/Label3D，
# headless 安全。每场开战先恢复上一场留下的演员变换（瘫倒/跪地）。
# -------------------------------------------------------------
var _actor_rest: Dictionary = {}

func _pig_visual() -> Node3D:
	if is_instance_valid(level_ref) and "player" in level_ref and is_instance_valid(level_ref.player):
		return level_ref.player.get_node_or_null("VisualMesh") as Node3D
	return null

func _farmer_visual() -> Node3D:
	if is_instance_valid(level_ref) and "farm" in level_ref and is_instance_valid(level_ref.farm):
		return level_ref.farm._visual_of("farmer")
	return null

func _pig_actor() -> Node:
	var visual := _pig_visual()
	if visual == null: return null
	var found := visual.find_children("ActorAnimation", "Node", true, false)
	return found[0] if not found.is_empty() else null

func _farmer_actor() -> Node:
	if is_instance_valid(level_ref) and "farm" in level_ref and is_instance_valid(level_ref.farm):
		return level_ref.farm._actor_of("farmer")
	return null

func _stage_host() -> Node3D:
	if is_instance_valid(level_ref) and level_ref is Node3D:
		return level_ref
	return null

func _stage_battle_intro() -> void:
	for key in _actor_rest:
		var node: Node3D = _actor_rest[key].node
		if is_instance_valid(node):
			node.position = _actor_rest[key].position
			node.rotation = _actor_rest[key].rotation
	_actor_rest.clear()
	for visual in [_pig_visual(), _farmer_visual()]:
		if visual != null:
			_actor_rest[visual.get_instance_id()] = {"node": visual, "position": visual.position, "rotation": visual.rotation}
	# 状态板弹入、指挥台升起、旁白打字机——宝可梦开场那一下。
	for plate in [farmer_plate, pig_plate]:
		if is_instance_valid(plate):
			plate.scale = Vector2(0.85, 0.85)
			plate.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(plate, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(plate, "modulate:a", 1.0, 0.2)
	if is_instance_valid(console_panel):
		var base_y := console_panel.position.y
		console_panel.position.y = base_y + 90.0
		console_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(console_panel, "position:y", base_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(console_panel, "modulate:a", 1.0, 0.25)
	_type_narrative(narrative_label.text)

func _type_narrative(text: String) -> void:
	narrative_label.text = text
	narrative_label.visible_characters = 0
	var tw := create_tween()
	tw.tween_property(narrative_label, "visible_characters", text.length(), 0.45)

func _lunge(visual: Node3D, toward: Vector3) -> void:
	if visual == null: return
	var local_dir := visual.global_transform.basis.inverse() * (toward - visual.global_position)
	local_dir.y = 0.0
	local_dir = local_dir.normalized() * 1.1 if local_dir.length_squared() > 0.01 else Vector3(0, 0, -1.1)
	var base := visual.position
	var tw := create_tween()
	tw.tween_property(visual, "position", base + local_dir, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "position", base, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hit_shake(visual: Node3D) -> void:
	if visual == null: return
	var base_z := visual.rotation.z
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", base_z + 0.14, 0.05)
	tw.tween_property(visual, "rotation:z", base_z - 0.1, 0.06)
	tw.tween_property(visual, "rotation:z", base_z, 0.07)

func _stage_pig_attack(move_index: int) -> void:
	var pig := _pig_visual()
	var farmer := _farmer_visual()
	var actor := _pig_actor()
	if actor != null and actor.has_method("play_oneshot"):
		actor.play_oneshot("attack", 1.3)
	if pig != null and farmer != null:
		_lunge(pig, farmer.global_position)
		var mid := (pig.global_position + farmer.global_position) * 0.5 + Vector3.UP * 1.2
		match move_index:
			0:
				_spark_burst(mid, Color("E8836B"), 18)
			1:
				_spark_burst(mid, Color("A9744F"), 22)
				_shout(mid, "哞——!", Color("A9744F"))
			2:
				_spark_burst(mid, Color("5FB8A6"), 22)
				_shout(mid, "咩!", Color("5FB8A6"))
			3:
				_spark_burst(mid, Color("8FC97A"), 22)
				_shout(mid, "嘶——!", Color("8FC97A"))

func _stage_farmer_hit(dmg_text: String) -> void:
	var farmer := _farmer_visual()
	_hit_shake(farmer)
	if farmer != null:
		_spark_burst(farmer.global_position + Vector3.UP * 1.3, Color("F2C14E"), 14)
		_float_text(farmer.global_position + Vector3.UP * 2.3, dmg_text, Color(0.85, 0.25, 0.15))

func _stage_farmer_attack() -> void:
	var farmer := _farmer_visual()
	var pig := _pig_visual()
	var actor := _farmer_actor()
	if actor != null and actor.has_method("play_oneshot"):
		actor.play_oneshot("attack", 1.3)
	if farmer != null and pig != null:
		_lunge(farmer, pig.global_position)
		_shout(pig.global_position + Vector3.UP * 2.0, "滋啦——!", Color("F2C14E"))

func _stage_pig_hit(dmg_text: String) -> void:
	var pig := _pig_visual()
	_hit_shake(pig)
	if pig != null:
		_spark_burst(pig.global_position + Vector3.UP * 1.0, Color("F2C14E"), 14)
		_float_text(pig.global_position + Vector3.UP * 2.0, dmg_text, Color(0.55, 0.40, 0.25))

func _stage_farmer_collapse() -> void:
	var farmer := _farmer_visual()
	if farmer == null: return
	var tw := create_tween()
	tw.tween_property(farmer, "rotation:x", farmer.rotation.x - 1.25, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(farmer, "position:y", farmer.position.y - 0.2, 0.4)

func _stage_pig_slump() -> void:
	var pig := _pig_visual()
	if pig == null: return
	var tw := create_tween()
	tw.tween_property(pig, "rotation:x", pig.rotation.x - 0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _spark_burst(at: Vector3, tint: Color, count: int) -> void:
	var host := _stage_host()
	if host == null: return
	# tween-mesh 火花（项目惯例）：CPUParticles3D 在 headless dummy 渲染器下
	# 会随机 segfault，演出层不能带这种风险进测试套件。
	var sparks := preload("res://scripts/art/puff_emitter.gd").new()
	sparks.tint = tint
	sparks.puff_size = 0.06
	host.add_child(sparks)
	sparks.global_position = at
	sparks.burst(count, 3.0)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(sparks.queue_free)

func _shout(at: Vector3, text: String, tint: Color) -> void:
	_float_text(at, text, tint, 26)

func _float_text(at: Vector3, text: String, tint: Color, font_size: int = 22) -> void:
	var host := _stage_host()
	if host == null: return
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = font_size
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = tint
	lbl.outline_modulate = Color("292524")
	lbl.outline_size = 5
	host.add_child(lbl)
	lbl.global_position = at
	var tw := create_tween()
	tw.tween_property(lbl, "global_position:y", at.y + 0.9, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.tween_callback(lbl.queue_free)
