extends RefCounted
# UiKit — 《一口猪在金牌农场》卡通欢乐 UI 套件（缝线补丁风）。
# 参考 Piece by Piece 的奶油纸片 + 虚线缝线 + 圆体字，配色取自农场本身：
# 奶油纸 / 深青墨 / 鼠尾草绿 / 湖青 / 珊瑚橙 / 向日葵黄 / 粉色缝线。
# 用法：const UI = preload("res://scripts/ui/ui_kit.gd")
# （不注册 class_name：headless 测试跑在全局类缓存重扫之前，preload 才稳。）

const PAPER := Color("FFF6E0")
const PAPER_DEEP := Color("F3E7C8")
const PAPER_EDGE := Color("E2D0A4")
const INK := Color("28525E")
const INK_SOFT := Color("6E858B")
const SAGE := Color("A9CFA0")
const SAGE_DEEP := Color("7DB874")
const TEAL := Color("3E8E9C")
const TEAL_DEEP := Color("2C6E7A")
const CORAL := Color("F08A5D")
const RED := Color("E4573D")
const SUNNY := Color("F7C948")
const PINK := Color("F2A9BC")
const WHITE := Color("FFFDF6")
const SHADOW := Color(0.16, 0.26, 0.24, 0.20)

static var _font_regular: Font
static var _font_bold: Font
static var _emoji_font: FontFile
static var _theme: Theme
static var _toggle_textures: Dictionary = {}

# ------------------------------------------------------------- fonts

static func font() -> Font:
	if _font_regular == null:
		var base := load("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf") as FontFile
		if base == null:
			var sys := SystemFont.new()
			sys.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
			_font_regular = sys
		else:
			var fbs: Array[Font] = []
			# 桌面优先走系统字体（与历史渲染一致，Segoe 的 CBDT 彩色 emoji 照旧）。
			# Web 端引擎拿不到任何系统字体，SystemFont 缺字形时 UI 符号/emoji 会渲染成
			# 码点豆腐块（如「25B6」），因此再挂内嵌开源子集字体兜底：
			# 1) 彩色 emoji（CBDT 位图，与桌面 Segoe 同通道，Web 也能出彩色）；
			# 2) 文本符号；3) 单色 emoji；4) 箭头/数学/带圈数字。
			# 注意 Godot 4.3 只支持 CBDT/CBLC 与 SVG 彩色字体，不支持 COLR/CPAL——
			# 取的是 noto-emoji v2.051 的 CBDT 构建，不是 Google Fonts 现发的 COLRv1 版。
			# 子集与许可见 assets/fonts/ 与 assets/fonts/licenses/。
			var fb := SystemFont.new()
			fb.font_names = PackedStringArray(["Segoe UI Emoji", "Segoe UI Symbol", "Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
			fbs.append(fb)
			for font_path in [
				"res://assets/fonts/NotoColorEmoji-GameSubset.ttf",
				"res://assets/fonts/NotoSansSymbols2-GameSubset.ttf",
				"res://assets/fonts/NotoEmoji-GameSubset.ttf",
				"res://assets/fonts/DejaVuSans-GameSubset.ttf",
			]:
				var extra := load(font_path) as FontFile
				if extra != null:
					fbs.append(extra)
			base.fallbacks = fbs
			_font_regular = base
	return _font_regular

static func font_bold() -> Font:
	if _font_bold == null:
		var v := FontVariation.new()
		v.base_font = font()
		v.variation_embolden = 0.65
		_font_bold = v
	return _font_bold

# 彩色 emoji 字体直引用。孤立纯 emoji 的 Label（前后无其他文字）在回退链上
# 会被 Godot 的 emoji-run 解析路径跳过位图字体、落到单色轮廓字体（成就弹窗
# 奖牌变线描的根因），此类场景直接用本字体做主字体即可稳定出彩色。
static func emoji_font() -> FontFile:
	if _emoji_font == null:
		_emoji_font = load("res://assets/fonts/NotoColorEmoji-GameSubset.ttf") as FontFile
	return _emoji_font

# ------------------------------------------------------------- styleboxes

static func pill(bg: Color, radius: int = 24, border: Color = Color.TRANSPARENT, border_w: int = 0, margin: Vector2 = Vector2(18, 8), shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = margin.x
	s.content_margin_right = margin.x
	s.content_margin_top = margin.y
	s.content_margin_bottom = margin.y
	if shadow:
		s.shadow_color = SHADOW
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 3)
	return s

static func patch(radius: int = 18, bg: Color = PAPER, margin: Vector2 = Vector2(24, 18), shadow_size: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = PAPER_EDGE
	s.set_border_width_all(2)
	s.content_margin_left = margin.x
	s.content_margin_right = margin.x
	s.content_margin_top = margin.y
	s.content_margin_bottom = margin.y
	s.shadow_color = SHADOW
	s.shadow_size = shadow_size
	s.shadow_offset = Vector2(0, 5)
	return s

# 缝线补丁面板：奶油纸 + 内圈虚线缝线（参考图的招牌细节）。
static func patch_panel(radius: int = 18, bg: Color = PAPER, stitch: Color = PINK, margin: Vector2 = Vector2(24, 18)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", patch(radius, bg, margin))
	stitch_rect(p, stitch, 8.0, float(radius) - 5.0)
	return p

# 在面板内容区里叠一层虚线缝线（负 inset 补偿内容边距，画到面板边缘内侧）。
static func stitch_rect(parent: Control, color: Color, from_edge: float = 8.0, radius: float = 12.0) -> StitchRect:
	var st := StitchRect.new()
	st.color = color
	st.radius = radius
	var sb := parent.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		st.inset_x = from_edge - sb.content_margin_left
		st.inset_y = from_edge - sb.content_margin_top
	else:
		st.inset_x = from_edge
		st.inset_y = from_edge
	parent.add_child(st)
	return st

class StitchRect extends Control:
	var color := Color("F2A9BC")
	var inset_x := -16.0
	var inset_y := -10.0
	var radius := 12.0
	var dash := 8.0
	var gap := 6.0
	var width := 2.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2(inset_x, inset_y), size - Vector2(inset_x * 2.0, inset_y * 2.0))
		if rect.size.x < radius * 2.0 + 4.0 or rect.size.y < radius * 2.0 + 4.0:
			return
		var pts := PackedVector2Array()
		var seg := 6
		var tl := rect.position + Vector2(radius, radius)
		var tr := Vector2(rect.end.x - radius, rect.position.y + radius)
		var br := rect.end - Vector2(radius, radius)
		var bl := Vector2(rect.position.x + radius, rect.end.y - radius)
		for corner in [tl, tr, br, bl]:
			var start_angle := PI + PI * 0.5 * float([tl, tr, br, bl].find(corner))
			for i in range(seg + 1):
				var a := start_angle + (PI * 0.5) * float(i) / float(seg)
				pts.append(corner + Vector2(cos(a), sin(a)) * radius)
		pts.append(pts[0])
		var drawing := true
		var carry := 0.0
		for i in range(pts.size() - 1):
			var a2 := pts[i]
			var b2 := pts[i + 1]
			var seglen := a2.distance_to(b2)
			if seglen <= 0.001:
				continue
			var t := 0.0
			while t < seglen - 0.001:
				var phase_len := (dash if drawing else gap) - carry
				var step := minf(phase_len, seglen - t)
				if drawing:
					draw_line(a2.lerp(b2, t / seglen), a2.lerp(b2, (t + step) / seglen), color, width, true)
				t += step
				carry += step
				if carry >= (dash if drawing else gap) - 0.001:
					carry = 0.0
					drawing = not drawing

# ------------------------------------------------------------- widgets

static func label(text: String, size: int = 18, color: Color = INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font_bold() if bold else font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# 大标题/倒计时：圆体加粗 + 粗描边 + 软阴影，卡通综艺感。
static func banner(text: String, size: int = 44, color: Color = WHITE, outline: Color = TEAL_DEEP) -> Label:
	var l := label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.add_theme_color_override("font_shadow_color", Color(0.10, 0.20, 0.20, 0.28))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l

static func button(text: String, callback: Callable = Callable(), primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 46
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		b.add_theme_stylebox_override("normal", pill(TEAL, 24, Color.TRANSPARENT, 0, Vector2(18, 8), true))
		b.add_theme_stylebox_override("hover", pill(TEAL_DEEP, 24, Color.TRANSPARENT, 0, Vector2(18, 8), true))
		b.add_theme_stylebox_override("pressed", pill(TEAL_DEEP.darkened(0.12), 24))
		b.add_theme_stylebox_override("focus", pill(TEAL_DEEP, 24, SUNNY, 3))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, WHITE)
	if callback.is_valid():
		b.pressed.connect(callback)
	return b

# 键帽：白底青边、底边加厚，像一颗可以按下去的糖。
static func keycap(text: String, font_size: int = 18, accent: Color = TEAL) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = WHITE
	s.border_color = accent
	s.set_border_width_all(2)
	s.border_width_bottom = 5
	s.set_corner_radius_all(9)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	s.shadow_color = SHADOW
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, font_size, accent, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

# NPC 名牌 / 小标签胶囊。
static func name_tag(text: String, bg: Color = SAGE, text_color: Color = INK, size: int = 17) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pill(bg, 14, Color.TRANSPARENT, 0, Vector2(14, 3), true))
	var l := label(text, size, text_color, true)
	# ZCOOL 的 hhea lineGap 高达 ~0.77em，行高被撑到 1.77 倍字号且空隙全落在
	# 基线下方——胶囊因此底重顶轻。负 spacing_bottom 按字号比例收紧行尾空隙。
	var vf := FontVariation.new()
	vf.base_font = font_bold()
	vf.spacing_bottom = -int(round(size * 0.55))
	l.add_theme_font_override("font", vf)
	p.add_child(l)
	return p

# 参考图右下角的 "Ⓐ Select"：湖青胶囊 + 白色圆键 + 动作名。
static func key_hint(key: String, action: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", pill(TEAL, 20, Color.TRANSPARENT, 0, Vector2(12, 5), true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var circle := PanelContainer.new()
	var kw := maxi(26, key.length() * 12 + 10)
	circle.custom_minimum_size = Vector2(kw, 26)
	circle.add_theme_stylebox_override("panel", pill(WHITE, 13, Color.TRANSPARENT, 0, Vector2.ZERO))
	var kl := label(key, 14, TEAL_DEEP, true)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kl.custom_minimum_size = Vector2(kw, 26)
	circle.add_child(kl)
	row.add_child(circle)
	row.add_child(label(action, 16, WHITE, true))
	return p

static func progress_bar(value: float = 0.0, max_value: float = 1.0, fill_color: Color = SAGE_DEEP, min_size: Vector2 = Vector2(160, 16)) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", pill(PAPER_DEEP, 9, PAPER_EDGE, 2, Vector2.ZERO))
	bar.add_theme_stylebox_override("fill", pill(fill_color, 9, Color.TRANSPARENT, 0, Vector2.ZERO))
	return bar

# ------------------------------------------------------------- world text

static func world_label(text: String, size: int = 40, color: Color = WHITE, outline: Color = TEAL_DEEP) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font_bold()
	l.font_size = size
	l.modulate = color
	l.outline_modulate = outline
	l.outline_size = maxi(6, size / 5)
	l.shaded = false
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l

# ------------------------------------------------------------- theme

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Button", font_bold())
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", WHITE)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.38))
	t.set_stylebox("normal", "Button", pill(Color.TRANSPARENT, 24))
	t.set_stylebox("hover", "Button", pill(SAGE, 24))
	t.set_stylebox("pressed", "Button", pill(SAGE_DEEP, 24))
	t.set_stylebox("focus", "Button", pill(SAGE, 24, TEAL, 2))
	t.set_stylebox("disabled", "Button", pill(Color(PAPER_DEEP, 0.55), 24))
	t.set_font("font", "CheckButton", font())
	t.set_font_size("font_size", "CheckButton", 18)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", TEAL_DEEP)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_focus_color", "CheckButton", INK)
	t.set_icon("checked", "CheckButton", _toggle_tex(true))
	t.set_icon("unchecked", "CheckButton", _toggle_tex(false))
	t.set_icon("checked_disabled", "CheckButton", _toggle_tex(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _toggle_tex(false, true))
	t.set_stylebox("normal", "CheckButton", pill(Color.TRANSPARENT, 14, Color.TRANSPARENT, 0, Vector2(8, 4)))
	t.set_stylebox("hover", "CheckButton", pill(Color(SAGE, 0.35), 14, Color.TRANSPARENT, 0, Vector2(8, 4)))
	t.set_stylebox("pressed", "CheckButton", pill(Color(SAGE, 0.5), 14, Color.TRANSPARENT, 0, Vector2(8, 4)))
	t.set_stylebox("focus", "CheckButton", pill(Color(SAGE, 0.35), 14, TEAL, 2, Vector2(8, 4)))
	t.set_stylebox("background", "ProgressBar", pill(PAPER_DEEP, 9, PAPER_EDGE, 2, Vector2.ZERO))
	t.set_stylebox("fill", "ProgressBar", pill(SAGE_DEEP, 9, Color.TRANSPARENT, 0, Vector2.ZERO))
	var line := StyleBoxLine.new()
	line.color = Color(PAPER_EDGE, 0.9)
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 10)
	t.set_stylebox("panel", "TooltipPanel", patch(10, PAPER, Vector2(12, 8), 4))
	t.set_color("font_color", "TooltipLabel", INK)
	_theme = t
	return t

static func apply(root: Control) -> void:
	root.theme = theme()

# 手绘感开关贴图：鼠尾草绿轨道 + 白色圆钮（运行时生成，零外部资源）。
static func _toggle_tex(on: bool, disabled: bool = false) -> ImageTexture:
	var key := "%s_%s" % [on, disabled]
	if _toggle_textures.has(key):
		return _toggle_textures[key]
	var w := 56
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := SAGE_DEEP if on else Color("D8CBA6")
	if disabled:
		track = Color(track, 0.5)
	var r := h * 0.5
	var center := Vector2(w * 0.5, h * 0.5)
	var half := Vector2(w * 0.5 - r, h * 0.5 - r)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := (p - center).abs() - half
			var sd := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0) - r
			var col := Color.TRANSPARENT
			if sd <= -1.0:
				col = track
				var kx := (w - r) if on else r
				var kd := p.distance_to(Vector2(kx, h * 0.5)) - (r - 4.0)
				if kd <= 0.0:
					col = WHITE if not disabled else Color(WHITE, 0.7)
				elif kd <= 1.5:
					col = Color(0, 0, 0, 0.10)
			elif sd <= 0.5:
				col = Color(track.darkened(0.18), 0.9)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_toggle_textures[key] = tex
	return tex