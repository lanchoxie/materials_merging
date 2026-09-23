extends Control
## Screen-space buttons follow 3D visitors; grey requests remain clickable.
const UI=preload("res://scripts/ui.gd")
var game
var bubbles: Dictionary={}
var mailbox: Button
var links: Array=[]
var clock=1.0

func setup(owner_game) -> void:
	game=owner_game; mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mailbox=UI.button("邮箱 · 订单",game._show_market)
	mailbox.custom_minimum_size=Vector2(100,44); mailbox.add_theme_font_size_override("font_size",14); add_child(mailbox)

func _position(point: Vector3) -> Vector2:
	return game.world_box.global_position+game.world.camera.unproject_position(point)*game.world_box.size/Vector2(game.world_viewport.size)

func _process(dt: float) -> void:
	if game==null or not is_instance_valid(game.campus_view): return
	visible=not is_instance_valid(game.modal)
	if not visible: return
	clock+=dt
	if clock>=0.5: clock=0; _refresh()
	links.clear()
	var rect=game.world_box.get_global_rect().grow(-15)
	var mailpoint=_position(game.campus_view.mailbox_point())
	mailbox.visible=rect.has_point(mailpoint)
	mailbox.position=mailpoint+Vector2(-105,-38)
	var active=[]
	for id in bubbles:
		if not game.campus_view.guests.has(id): bubbles[id].visible=false; continue
		var head=_position(game.campus_view.guests[id].head)
		bubbles[id].visible=rect.has_point(head)
		if bubbles[id].visible: active.append({"id":id,"head":head})
	active.sort_custom(func(a,b): return a.head.x<b.head.x)
	for i in range(active.size()):
		var item: Dictionary=active[i]
		var button: Button=bubbles[item.id]
		var base: Vector2=active[int(active.size()/2)].head
		var x=clampf(base.x+(i-(active.size()-1)*0.5)*160-76,rect.position.x,rect.end.x-156)
		button.position=Vector2(x,clampf(base.y-94,rect.position.y+190,rect.end.y-140))
		links.append([button.position+Vector2(76,52),item.head])
	queue_redraw()

func _refresh() -> void:
	var ids=[]
	for v in game.state.market.visitors:
		if v.phase!="visiting": continue
		var id=int(v.id); ids.append(id)
		if not bubbles.has(id):
			var button=UI.button("",_activate.bind(id)); button.custom_minimum_size=Vector2(152,52); button.add_theme_font_size_override("font_size",14); add_child(button); bubbles[id]=button
		var rows: Array=game.state.visitor_candidates(id)
		var ready=not rows.is_empty() and bool(rows[0].ready) and bool(rows[0].matching)
		var b: Button=bubbles[id]
		b.text=game.state.market.request_text(v,game.state.templates)+("\n点击交付" if ready else ("\n冷却中 · 查看需求" if game.state.contracts.is_material(v) and game.state.planet.laminates.cooldown>0 else "\n缺货 · 查看需求"))
		b.add_theme_stylebox_override("normal",UI.style(Color("b0e2c3") if ready else Color("40505b"),12))
		b.add_theme_color_override("font_color",Color("163e36") if ready else Color("c4ccd0"))
	for id in bubbles.keys():
		if id not in ids: bubbles[id].queue_free(); bubbles.erase(id)

func _activate(id: int) -> void:
	var rows: Array=game.state.visitor_candidates(id)
	if not rows.is_empty() and rows[0].ready and rows[0].matching:
		game._action(game.state.fulfill_order(id,str(rows[0].batch_id))); _refresh()
	else: game._show_island_panel("mail",id)

func _draw() -> void:
	for link in links: draw_line(link[0],link[1],Color(0.7,0.85,0.79,0.75),1.5,true)
