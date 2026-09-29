extends CanvasLayer
## Screen-space "juice" (autoload "Fx"): floating numbers, coin bursts, sparkles, banners.
## Everything is tween-driven on one top canvas layer, so it is cheap on mobile/web and
## never blocks input. Positions are in the same design space as the game's Controls.

const GOLD = Color("ffd18c")
const MINT = Color("a5efd1")
const LILAC = Color("bbbcff")
const MAX_LIVE_NODES = 160

var _font: Font
var _flash: ColorRect

class Dot extends Node2D:
	var radius: float = 5.0
	var color: Color = Color.WHITE
	var glow: bool = true
	func _draw() -> void:
		if glow: draw_circle(Vector2.ZERO, radius * 2.2, Color(color, 0.18))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, Color(1, 1, 1, 0.7))

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)

func _busy() -> bool:
	return get_child_count() > MAX_LIVE_NODES

func _label(text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font: l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.07, 0.1, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	return l

## Floating text that pops, rises and fades. Used for "+12", "COMBO ×8", "+1 星砂"…
func pop_text(pos: Vector2, text: String, color: Color = GOLD, size: int = 26, rise: float = 70.0, delay: float = 0.0) -> void:
	if _busy(): return
	var l = _label(text, size, color)
	add_child(l)
	l.reset_size()
	l.pivot_offset = l.size / 2
	l.position = pos - l.size / 2 + Vector2(randf_range(-10, 10), 0)
	l.scale = Vector2(0.4, 0.4)
	l.modulate.a = 0.0
	var t = create_tween()
	t.tween_interval(delay)
	t.tween_property(l, "modulate:a", 1.0, 0.06)
	t.parallel().tween_property(l, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.08)
	t.parallel().tween_property(l, "position:y", l.position.y - rise, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.5)
	t.tween_callback(l.queue_free)

## Coins (or any tokens) fly on an arc from `from` to `to`. `on_arrive` runs once per token.
func burst(from: Vector2, to: Vector2, count: int = 6, color: Color = GOLD, on_arrive: Callable = Callable()) -> void:
	count = clampi(count, 1, 14)
	for i in range(count):
		if _busy(): return
		var d = Dot.new()
		d.color = color
		d.radius = randf_range(4.5, 7.0)
		d.position = from
		add_child(d)
		var spread = Vector2(randf_range(-70, 70), randf_range(-90, -20))
		var control = from.lerp(to, 0.35) + spread + Vector2(0, -80)
		var duration = randf_range(0.45, 0.7)
		var t = create_tween()
		t.tween_interval(i * 0.035)
		t.tween_method(func(k: float): d.position = _bezier(from + spread * 0.25, control, to, k), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(d, "scale", Vector2(0.55, 0.55), duration)
		if on_arrive.is_valid(): t.tween_callback(on_arrive)
		t.tween_callback(d.queue_free)

func _bezier(a: Vector2, b: Vector2, c: Vector2, k: float) -> Vector2:
	return a.lerp(b, k).lerp(b.lerp(c, k), k)

## Radial sparkle burst at a point.
func sparkle(pos: Vector2, color: Color = MINT, count: int = 12, distance: float = 70.0) -> void:
	for i in range(clampi(count, 1, 32)):
		if _busy(): return
		var d = Dot.new()
		d.color = color.lightened(randf_range(0.0, 0.35))
		d.radius = randf_range(2.5, 5.0)
		d.position = pos
		add_child(d)
		var angle = TAU * i / count + randf_range(-0.2, 0.2)
		var target = pos + Vector2.from_angle(angle) * distance * randf_range(0.6, 1.2)
		var t = create_tween().set_parallel(true)
		t.tween_property(d, "position", target, 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(d, "modulate:a", 0.0, 0.55).set_delay(0.15)
		t.chain().tween_callback(d.queue_free)

## Quick scale "punch" on a Control or Node2D, anchored at its centre.
func punch(node: CanvasItem, amount: float = 0.14, duration: float = 0.22) -> void:
	if not is_instance_valid(node): return
	if node is Control: node.pivot_offset = node.size / 2
	if node.has_meta("fx_punch"):
		var old: Tween = node.get_meta("fx_punch")
		if old and old.is_valid(): old.kill()
	node.scale = Vector2.ONE * (1.0 + amount)
	var t = node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	node.set_meta("fx_punch", t)

## A reusable label (e.g. a combo meter) that updates in place, punches, and fades when idle.
var _counters: Dictionary = {}

func counter(key: String, pos: Vector2, text: String, color: Color = MINT, size: int = 30, linger: float = 1.0) -> void:
	var l: Label = _counters.get(key)
	if not is_instance_valid(l):
		l = _label(text, size, color)
		add_child(l)
		_counters[key] = l
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.reset_size()
	l.position = pos - l.size / 2
	l.modulate.a = 1.0
	punch(l, 0.25, 0.25)
	if l.has_meta("fx_fade"):
		var old: Tween = l.get_meta("fx_fade")
		if old and old.is_valid(): old.kill()
	var t = l.create_tween()
	t.tween_interval(linger)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	l.set_meta("fx_fade", t)

## Brief full-screen colour flash.
func flash(color: Color = Color(1, 1, 1), alpha: float = 0.35, duration: float = 0.35) -> void:
	_flash.color = Color(color, alpha)
	var t = create_tween()
	t.tween_property(_flash, "color:a", 0.0, duration)

## Big centred celebration ("完美契合!", "升级!", "新发现!").
func banner(title: String, subtitle: String = "", color: Color = GOLD, center: Vector2 = Vector2(-1, -1)) -> void:
	if center.x < 0: center = get_viewport().get_visible_rect().size / 2 + Vector2(0, -60)
	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var head = _label(title, 54, color)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	if not subtitle.is_empty():
		var sub = _label(subtitle, 20, Color("eaf2ed"))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	add_child(box)
	box.reset_size()
	box.position = center - box.size / 2
	box.pivot_offset = box.size / 2
	box.scale = Vector2(0.3, 0.3)
	box.modulate.a = 0.0
	sparkle(center, color, 20, 180.0)
	var t = create_tween()
	t.tween_property(box, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(box, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(box, "position:y", box.position.y - 30, 0.35)
	t.tween_callback(box.queue_free)
