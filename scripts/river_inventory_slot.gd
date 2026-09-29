extends Button
## Reusable slot: drawing and drag intent only; never owns an item quantity.
signal item_dropped(id: String)
const UI=preload("res://scripts/ui.gd")
var item: Dictionary={}
var number=0
var chosen=false
var drop_enabled=false
var caption: Label
var count_label: Label
var number_label: Label
var touch_gesture=false

func _ready() -> void:
	focus_mode=Control.FOCUS_NONE; mouse_filter=Control.MOUSE_FILTER_PASS
	custom_minimum_size=Vector2(76,80)
	caption=UI.label("",11); caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; add_child(caption)
	count_label=UI.label("",13,UI.GOLD); count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; add_child(count_label)
	number_label=UI.label("",11,UI.MUTED); add_child(number_label)
	resized.connect(_layout); _layout(); _refresh()

func set_item(data: Dictionary,index: int=0,active: bool=false) -> void:
	item=data; number=index; chosen=active
	if is_node_ready(): _refresh()

func _layout() -> void:
	caption.position=Vector2(3,size.y-22); caption.size=Vector2(size.x-6,18)
	count_label.position=Vector2(20,3); count_label.size=Vector2(size.x-26,20)
	number_label.position=Vector2(6,3)
	queue_redraw()

func _refresh() -> void:
	caption.text=str(item.get("name","空格")); number_label.text=str(number) if number>0 else ""
	count_label.text=_count(int(item.quantity)) if not item.is_empty() and int(item.quantity)>=0 else ""
	tooltip_text="空格 · 打开背包装备" if item.is_empty() else str(item.name)+"\n"+str(item.description)
	add_theme_stylebox_override("normal",UI.style(Color("25493f") if chosen else Color("142d34"),7,UI.MINT if chosen else Color("34525a")))
	modulate=Color(0.62,0.66,0.69) if not item.is_empty() and item.quantity==0 else Color.WHITE
	queue_redraw()

func _count(quantity: int) -> String:
	if quantity>=10000: return "%.1f万" % (quantity/10000.0)
	if quantity>=1000: return "%.1fk" % (quantity/1000.0)
	return str(quantity)

func _draw() -> void:
	if item.is_empty(): return
	var p=Vector2(size.x*0.5,34); var color=Color("d7af7a")
	match item.get("icon",""):
		"block", "crate", "planter", "floor", "roof":
			if item.icon=="floor": color=Color("a7b7b8")
			elif item.icon=="roof": color=Color("cabc7e")
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-15),p+Vector2(17,-6),p+Vector2(0,3),p+Vector2(-17,-6)]),color.lightened(0.2))
			draw_colored_polygon(PackedVector2Array([p+Vector2(-17,-6),p+Vector2(0,3),p+Vector2(0,20),p+Vector2(-17,11)]),color.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,3),p+Vector2(17,-6),p+Vector2(17,11),p+Vector2(0,20)]),color)
			if item.icon=="planter": draw_colored_polygon(PackedVector2Array([p+Vector2(0,-11),p+Vector2(12,-6),p+Vector2(0,-1),p+Vector2(-12,-6)]),Color("705b43"))
		"fence":
			for x in [-14,14]: draw_line(p+Vector2(x,-13),p+Vector2(x,20),color,6)
			for y in [-5,10]: draw_line(p+Vector2(-17,y),p+Vector2(17,y),color,5)
		"solar":
			draw_rect(Rect2(p-Vector2(19,11),Vector2(38,26)),Color("8663a2") if str(item.id).contains("perovskite") else Color("4976a0"))
			for x in [-12,0,12]: draw_line(p+Vector2(x,-11),p+Vector2(x,15),UI.MINT,1)
			draw_line(p+Vector2(-19,2),p+Vector2(19,2),UI.MINT,1)
		"sample":
			draw_circle(p+Vector2(0,5),10,Color("7fcce2")); draw_circle(p+Vector2(-14,-5),6,Color("f1e9cf")); draw_circle(p+Vector2(14,-6),6,Color("f1e9cf"))
			draw_line(p,p+Vector2(-11,-3),UI.TEXT,3); draw_line(p,p+Vector2(11,-3),UI.TEXT,3)
		"stone":
			draw_colored_polygon(PackedVector2Array([p+Vector2(-18,12),p+Vector2(-13,-8),p+Vector2(7,-15),p+Vector2(20,2),p+Vector2(10,17)]),Color("a7b7b8"))
			draw_line(p+Vector2(-12,-7),p+Vector2(11,6),Color("dae4df"),3)
		"fruit":
			draw_circle(p+Vector2(-6,6),11,Color("e58f57")); draw_circle(p+Vector2(9,3),9,Color("eab86c")); draw_line(p+Vector2(0,-2),p+Vector2(6,-14),UI.MINT,4)
		"seed", "food":
			draw_line(p+Vector2(0,18),p+Vector2(0,-10),Color("93b881"),3)
			for i in range(3):
				draw_circle(p+Vector2(-6,-8+i*8),5,Color("e4c878")); draw_circle(p+Vector2(6,-12+i*8),5,Color("e4c878"))
		"hammer":
			draw_line(p+Vector2(-9,19),p+Vector2(7,-8),color,7); draw_line(p+Vector2(-4,-12),p+Vector2(19,0),Color("a8c4cf"),11)
		"hand":
			draw_circle(p+Vector2(0,7),10,UI.MINT)
			for x in [-8,-2,4,10]: draw_line(p+Vector2(x,5),p+Vector2(x,-12+abs(x)*0.5),UI.MINT,5)

func _get_drag_data(_at: Vector2):
	# Native touch swipes belong to ScrollContainer. Touch equips with two taps.
	if item.is_empty() or touch_gesture: return null
	var preview=Label.new(); preview.text=str(item.name); set_drag_preview(preview)
	return {"river_inventory_item":str(item.id)}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed: touch_gesture=true
	if event is InputEventMouseButton and event.pressed: touch_gesture=event.device<0

func _can_drop_data(_at: Vector2,data) -> bool:
	return drop_enabled and data is Dictionary and data.get("river_inventory_item") is String

func _drop_data(at: Vector2,data) -> void:
	if _can_drop_data(at,data): item_dropped.emit(data.river_inventory_item)
