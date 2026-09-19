extends RefCounted

const BG = Color("0d1721")
const PANEL = Color("162631")
const INNER = Color("20343e")
const LINE = Color("334952")
const TEXT = Color("eaf2ed")
const MUTED = Color("94abb0")
const MINT = Color("a5efd1")
const GOLD = Color("ffd18c")
const LILAC = Color("bbbcff")

static func style(color: Color = PANEL, radius: int = 18, border: Color = LINE) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func make_theme() -> Theme:
	var t = Theme.new()
	var font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf").duplicate()
	font.fallbacks=[ThemeDB.fallback_font]
	t.default_font = font
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", MINT)
	t.set_color("font_disabled_color", "Button", Color("668086"))
	t.set_stylebox("normal", "Button", style(INNER, 12))
	t.set_stylebox("hover", "Button", style(Color("2b4850"), 12, MINT.darkened(0.35)))
	t.set_stylebox("pressed", "Button", style(Color("31574f"), 12, MINT))
	t.set_stylebox("disabled", "Button", style(Color("182a33"), 12, Color("263e47")))
	t.set_stylebox("focus", "Button", style(Color(0,0,0,0), 12, MINT))
	t.set_stylebox("panel", "PanelContainer", style())
	var track = style(Color("0f202b"), 4, Color("0f202b"))
	var fill = style(MINT, 4, MINT)
	for bar_style in [track,fill]:
		bar_style.content_margin_top = 0
		bar_style.content_margin_bottom = 0
		bar_style.content_margin_left = 0
		bar_style.content_margin_right = 0
	t.set_stylebox("background", "ProgressBar", track)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	return t

static func label(text: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func paragraph(text: String, font_size: int = 14, color: Color = MUTED) -> Label:
	var l = label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var b = Button.new()
	# Native touch must bubble to an enclosing ScrollContainer. Its scroll-begin
	# notification cancels the pending button press, so a swipe is never a purchase.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.text = text
	b.custom_minimum_size.y = 44
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	if primary:
		b.add_theme_stylebox_override("normal", style(MINT, 12, MINT))
		b.add_theme_stylebox_override("hover", style(MINT.lightened(0.15), 12, MINT))
		b.add_theme_stylebox_override("pressed", style(MINT.darkened(0.12), 12, MINT))
		b.add_theme_color_override("font_color", Color("153d37"))
		b.add_theme_color_override("font_hover_color", Color("153d37"))
	return b

static func box(parent: Node, rect: Rect2, color: Color = PANEL) -> PanelContainer:
	var p = PanelContainer.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", style(color))
	parent.add_child(p)
	return p

static func column(parent: Node, separation: int = 10) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	if parent is PanelContainer: parent.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", separation)
	parent.add_child(v)
	return v

static func row(parent: Node, separation: int = 10) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	if parent is PanelContainer: parent.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_theme_constant_override("separation", separation)
	parent.add_child(h)
	return h

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

static func spacer(parent: Node, height: float = 8.0) -> void:
	var c = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size.y = height
	parent.add_child(c)
