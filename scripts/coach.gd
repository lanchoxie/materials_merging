extends CanvasLayer
## v0.28 coach marks: dim everything except one control, explain it, then move on.
## Clicks outside the highlight are blocked; the highlighted control itself stays usable.
## A tour ends by itself when its screen is closed or covered (the `alive` check).
signal finished(tour: String, skipped: bool)
const UI=preload("res://scripts/ui.gd")
const DIM=Color(0.02,0.06,0.08,0.66)

var tour: String=""
var steps: Array=[]
var index: int=0
var alive: Callable
var target: Control
var hole: Rect2
var dims: Array=[]
var frame: Panel
var card: PanelContainer
var count_label: Label
var title_label: Label
var body_label: Label
var next_button: Button
var skip_button: Button
var clock: float=0.0

func _init() -> void:
	layer=80
	visible=false

func _ready() -> void:
	for i in range(4):
		var dim=ColorRect.new(); dim.color=DIM; dim.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(dim); dims.append(dim)
	frame=Panel.new(); frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new(); style.bg_color=Color(0,0,0,0); style.set_border_width_all(3); style.border_color=UI.GOLD; style.set_corner_radius_all(12)
	frame.add_theme_stylebox_override("panel",style); add_child(frame)
	card=PanelContainer.new(); card.mouse_filter=Control.MOUSE_FILTER_STOP; card.custom_minimum_size=Vector2(400,0)
	var card_style=UI.style(Color("1d3440"),16,UI.GOLD); card_style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel",card_style); add_child(card)
	var column=VBoxContainer.new(); column.add_theme_constant_override("separation",8); card.add_child(column)
	var head=HBoxContainer.new(); column.add_child(head)
	title_label=UI.label("",22,UI.GOLD); title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; head.add_child(title_label)
	count_label=UI.label("",14,UI.MUTED); head.add_child(count_label)
	body_label=UI.paragraph("",16,UI.TEXT); body_label.custom_minimum_size.x=364; column.add_child(body_label)
	var buttons=HBoxContainer.new(); buttons.add_theme_constant_override("separation",10); column.add_child(buttons)
	skip_button=UI.button("跳过指引",func(): _finish(true)); buttons.add_child(skip_button)
	var gap=Control.new(); gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL; buttons.add_child(gap)
	next_button=UI.button("下一步",_next,true); next_button.custom_minimum_size.x=120; buttons.add_child(next_button)

func active() -> bool:
	return not tour.is_empty()

## steps: [{"target": Callable -> Control or null, "title": String, "text": String}]
func start(id: String, list: Array, alive_check: Callable) -> void:
	if list.is_empty(): return
	tour=id; steps=list; alive=alive_check; index=0; visible=true
	_show_step()

## Ends a tour whose screen is gone; returns true if one was stopped.
func stop_if_stale() -> bool:
	if active() and alive.is_valid() and not alive.call():
		_finish(false); return true
	return false

func _show_step() -> void:
	_release_target()
	var step: Dictionary=steps[index]
	target=step.target.call() if step.get("target") is Callable else null
	if target is BaseButton: target.pressed.connect(_target_pressed)
	title_label.text=str(step.title); body_label.text=str(step.text)
	count_label.text="%d / %d" % [index+1,steps.size()]
	next_button.text="完成" if index==steps.size()-1 else "下一步"
	card.reset_size()
	card.modulate.a=0.0; card.create_tween().tween_property(card,"modulate:a",1.0,0.25)
	_layout()

func _release_target() -> void:
	if is_instance_valid(target) and target is BaseButton and target.pressed.is_connected(_target_pressed):
		target.pressed.disconnect(_target_pressed)
	target=null

func _target_pressed() -> void:
	# Pressing the highlighted control counts as "got it".
	_next.call_deferred()

func _next() -> void:
	if not active(): return
	index+=1
	if index>=steps.size(): _finish(false)
	else: _show_step()

func _finish(skipped: bool) -> void:
	if not active(): return
	_release_target()
	var id=tour; tour=""; steps=[]; visible=false
	finished.emit(id,skipped)

func _process(delta: float) -> void:
	if not active(): return
	if stop_if_stale(): return
	clock+=delta
	_layout()
	frame.modulate.a=0.65+0.35*sin(clock*4.0)

func _layout() -> void:
	var screen: Vector2=get_viewport().get_visible_rect().size
	hole=Rect2()
	if is_instance_valid(target) and target.is_visible_in_tree():
		var area: Rect2=target.get_global_rect()
		# Long lists inside a scroll box: highlight only the visible part.
		var parent: Node=target.get_parent()
		while parent is Control:
			if parent is ScrollContainer: area=area.intersection(parent.get_global_rect())
			parent=parent.get_parent()
		hole=area.grow(8).intersection(Rect2(Vector2.ZERO,screen))
	if hole.size.x<=1:
		dims[0].position=Vector2.ZERO; dims[0].size=screen
		for i in range(1,4): dims[i].size=Vector2.ZERO
		frame.visible=false
		card.position=(screen-card.size)/2
		return
	dims[0].position=Vector2.ZERO; dims[0].size=Vector2(screen.x,hole.position.y)
	dims[1].position=Vector2(0,hole.end.y); dims[1].size=Vector2(screen.x,screen.y-hole.end.y)
	dims[2].position=Vector2(0,hole.position.y); dims[2].size=Vector2(hole.position.x,hole.size.y)
	dims[3].position=Vector2(hole.end.x,hole.position.y); dims[3].size=Vector2(screen.x-hole.end.x,hole.size.y)
	frame.visible=true; frame.position=hole.position; frame.size=hole.size
	# Card goes below the highlight when there is room, else above, else beside it.
	var at=Vector2(hole.get_center().x-card.size.x/2,hole.end.y+14)
	if at.y+card.size.y>screen.y-8: at.y=hole.position.y-card.size.y-14
	if at.y<8:
		at.y=clampf(hole.get_center().y-card.size.y/2,8,screen.y-card.size.y-8)
		at.x=hole.end.x+14 if hole.end.x+14+card.size.x<screen.x else hole.position.x-card.size.x-14
	card.position=Vector2(clampf(at.x,8,maxf(8,screen.x-card.size.x-8)),clampf(at.y,8,maxf(8,screen.y-card.size.y-8)))
