extends Control
signal dismissed
signal acted(message: String)
const UI=preload("res://scripts/ui.gd")
const View=preload("res://scripts/planet_view.gd")
var state
var view
var viewport: SubViewport
var viewport_box: SubViewportContainer
var body: VBoxContainer
var world_tabs: HBoxContainer
var status: Label
var caption: Label
var tray_label: Label
var tray: PanelContainer
var ghost: PanelContainer
var progress: ProgressBar
var progress_text: Label
var site_labels: Dictionary={}
var section="workshop"
var fingerprint=""
var refresh=0.0
var dragging=false
var armed=false
var rotating=false
var pointer=Vector2.ZERO
var start=Vector2.ZERO
var touch_index=-1
var token=0
var target_world=""
var closing=false

func setup(model) -> void:
	state=model; state.planet.observing=true; state.planet.observer_id=get_instance_id()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var heading=UI.label("材料试验星球",30,UI.MINT); heading.position=Vector2(32,21); add_child(heading)
	var subtitle=UI.label("EXPERIMENT 01    /    让你的第一箱水，抵达另一个世界",14,UI.MUTED); subtitle.position=Vector2(34,65); add_child(subtitle)
	var close=UI.button("返回浮岛",_close); close.position=Vector2(1285,27); close.size=Vector2(122,46); add_child(close)
	world_tabs=HBoxContainer.new(); world_tabs.position=Vector2(24,107); world_tabs.size=Vector2(1000,44); world_tabs.add_theme_constant_override("separation",10); add_child(world_tabs)
	viewport_box=SubViewportContainer.new(); viewport_box.position=Vector2(24,165); viewport_box.size=Vector2(984,550); viewport_box.stretch=true; viewport_box.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(viewport_box)
	viewport=SubViewport.new(); viewport.size=Vector2i(984,550); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport_box.add_child(viewport)
	if not OS.has_feature("web") and not OS.has_feature("android"): viewport.msaa_3d=Viewport.MSAA_2X
	view=View.new(); viewport.add_child(view)
	for id in ["deep","shelf"]:
		var badge=PanelContainer.new(); badge.add_theme_stylebox_override("panel",UI.style(Color("162f3a"),10)); badge.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(badge)
		var label=UI.label("深槽蓄水" if id=="deep" else "浅台漫流",14,UI.TEXT); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; badge.add_child(label); site_labels[id]=badge
	var camera_row=HBoxContainer.new(); camera_row.position=Vector2(40,660); camera_row.size=Vector2(550,44); camera_row.add_theme_constant_override("separation",8); add_child(camera_row)
	camera_row.add_child(UI.button("回到试验湾",func(): _cancel_gesture(); view.reset_camera()))
	camera_row.add_child(UI.button("＋",func(): view.zoom(-0.8)))
	camera_row.add_child(UI.button("－",func(): view.zoom(0.8)))
	var help=UI.label("拖动旋转 · 滚轮缩放",13,UI.MUTED); camera_row.add_child(help)
	var tray_box=UI.box(self,Rect2(24,728,984,116),UI.PANEL)
	var inventory=UI.row(tray_box,20)
	tray=PanelContainer.new(); tray.custom_minimum_size=Vector2(215,86); tray.add_theme_stylebox_override("panel",UI.style(Color("284b50"),14,UI.MINT.darkened(0.4))); inventory.add_child(tray)
	tray.mouse_default_cursor_shape=Control.CURSOR_DRAG; tray.gui_input.connect(_tray_input)
	var inside=UI.column(tray,5); inside.mouse_filter=Control.MOUSE_FILTER_PASS
	inside.add_child(UI.label("▣  标准水箱",22,UI.MINT))
	tray_label=UI.label("",14,UI.TEXT); inside.add_child(tray_label)
	var hint=UI.column(inventory,6); hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hint.add_child(UI.label("把水箱拖到深槽或浅台",21,UI.TEXT))
	caption=UI.paragraph("",15,UI.MUTED); hint.add_child(caption)
	var panel=UI.box(self,Rect2(1024,107,392,737))
	var right=UI.column(panel,12)
	var tabs=UI.row(right,8)
	tabs.add_child(UI.button("装罐工坊",func(): section="workshop"; _redraw()))
	tabs.add_child(UI.button("观察 / 对照",func(): section="observe"; _redraw()))
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; right.add_child(scroll)
	body=UI.column(scroll,12); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status=UI.paragraph("",15,UI.GOLD); status.position=Vector2(32,859); status.size=Vector2(1370,36); add_child(status)
	ghost=PanelContainer.new(); ghost.add_theme_stylebox_override("panel",UI.style(Color("345961"),12,UI.MINT)); ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE; ghost.add_child(UI.label("▣  水箱 ×1",18,UI.MINT)); add_child(ghost); ghost.hide()
	_redraw(); _live()

func _fingerprint() -> String:
	var batches=[]
	for item in state.storage.batches: batches.append([item.id,item.quantity])
	var p=state.planet; var w=p.worlds.get_world()
	return str([p.joined,p.qualified,p.feed,p.products.size(),p.job.get("id",0),w.id,w.paused,w.allowance,w.zones,w.events.size(),p.worlds.worlds.size(),batches])

func _redraw() -> void:
	if state==null: return
	UI.clear(body); UI.clear(world_tabs); progress=null; progress_text=null
	var p=state.planet
	for w in p.worlds.worlds:
		var button=UI.button(w.name,func(): _do("select",{"world_id":str(w.id)}),w.id==p.worlds.active_id)
		button.custom_minimum_size.x=185; world_tabs.add_child(button)
	var world=p.worlds.get_world()
	if section=="workshop": _workshop()
	else: _observations()
	fingerprint=_fingerprint()
	view.sync(world)

func _text(text: String,size: int=16,color: Color=UI.MUTED) -> void:
	body.add_child(UI.paragraph(text,size,color))

func _button(text: String,callback: Callable,primary: bool=false,disabled: bool=false) -> Button:
	var button=UI.button(text,callback,primary); button.disabled=disabled; body.add_child(button); return button

func _workshop() -> void:
	var p=state.planet; var rules=p.config.workshop
	_text("第一封星际来信",23,UI.MINT)
	_text("试验湾的盆地已经冷却。我们想借用你的水样，验证装罐流程，再把水送进两种地形。",17,UI.TEXT)
	if not p.joined:
		_text("合作方提供独立装罐台与%d份标准供料。不需要先招募院士。" % int(rules.starter_feed))
		_button("领取合作与首次供料",func(): _do("join"),true)
		return
	if not p.qualified:
		_text("① 提交水样，解锁装罐",21,UI.MINT)
		_text("需要同一批次的%d份已收集水样。身份验证会消耗样品；供料另计。" % int(rules.samples_required))
		var candidates=p.water_candidates(state)
		if candidates.is_empty(): _text("回到浮岛，领取水分子反应炉中的产物，再来查看。",17,UI.GOLD)
		for batch in candidates:
			_button("提交水样 · 库存%d份" % int(batch.quantity),func(): _do("qualify",{"batch_id":str(batch.id)}),true,int(batch.quantity)<int(rules.samples_required))
	else:
		_text("② 标准水箱装罐",21,UI.MINT)
		_text("1份供料 + %d金币 → 1箱水\n每箱%d秒 · 合作方独立装罐台" % [int(rules.packing_cost),int(rules.packing_seconds)],17,UI.TEXT)
		_text("供料 %d份  /  成品 %d箱\n金币 %d" % [p.feed,p.products.size(),int(state.coins)],18,UI.GOLD)
		if p.job.is_empty():
			_button("开始装罐 · %d金币" % int(rules.packing_cost),func(): _do("pack"),true)
		else:
			progress_text=UI.label("",17,UI.MINT); body.add_child(progress_text)
			progress=ProgressBar.new(); progress.custom_minimum_size.y=12; progress.show_percentage=false; body.add_child(progress)
			_button("取消装罐 · 退供料，费用不退",func(): _do("cancel_pack"))
	_button("补充1份供料 · %d金币" % int(rules.feed_cost),func(): _do("buy_feed"))
	_text("样品验证与批量供料分开。几何匹配度不等于水的纯度。",14)
	_text("③ 选择水的落点",21,UI.MINT)
	_text("深槽：集中蓄水，保留岸地。\n浅台：同样用水，铺开更宽水面。\n主世界总容量为3箱。",16,UI.TEXT)
	_button("查看观察记录与实验副本",func(): section="observe"; _redraw())

func _observations() -> void:
	var p=state.planet; var w=p.worlds.get_world()
	_text(str(w.name),24,UI.MINT)
	_text("封闭盆地 · %s\n已交付 %d / 3箱" % ["主仓库供给" if w.mode=="career" else "独立配给，无法运回出售",int(p.worlds.total(w))],17,UI.TEXT)
	_button("继续观察" if w.paused else "暂停观察",func(): _do("pause"),true)
	if w.mode=="experiment": _button("重置本实验 · 回到起点",func(): _do("reset_trial"))
	if p.worlds.worlds.size()<3:
		_button("从干燥盆地创建实验",func(): _do("fork",{"dry":true}))
		_button("复制当前状态为实验",func(): _do("fork",{"dry":false}))
	else:
		_button("两个实验同步推进10秒",func(): _do("step_pair"),false,not p.worlds.can_step_pair())
	_text("只推进当前世界；离开星球就暂停。\n返回浮岛不影响装罐。\n实验先布置，再同步观察。",14)
	_text("世界对照",21,UI.MINT)
	for other in p.worlds.worlds:
		_text("%s · %d秒\n深槽 %d箱 / 浅台 %d箱" % [other.name,int(other.seconds),int(other.zones[0].target),int(other.zones[1].target)],16,UI.TEXT)
	if p.worlds.worlds.size()==3 and not p.worlds.can_step_pair(): _text("实验起点或时刻不同，暂不能作为同条件对照。",14,UI.GOLD)
	_text("观察记录",21,UI.MINT)
	if w.events.is_empty(): _text("尚未投放。先把水箱送到一个盆地落点。")
	for i in range(w.events.size()-1,maxi(-1,w.events.size()-5),-1):
		var event=w.events[i]; _text("%ds · %s" % [int(event.at),event.message],15,UI.TEXT)
	if w.observation:
		_text("观察卡 · 水的去向",21,UI.MINT)
		_text("这一箱水改变的是局部封闭盆地。深槽和浅台的水面形状不同，水箱总量相同。",16,UI.TEXT)

func _do(action: String,data: Dictionary={}) -> void:
	_cancel_gesture()
	var message=state.planet.command(state,action,data)
	status.text=message; acted.emit(message); _redraw(); _live()

func _live() -> void:
	var p=state.planet; var w=p.worlds.get_world()
	var count=p.available_products() if w.mode=="career" else int(w.allowance)
	tray_label.text="%s %d箱 · 按住拖放" % ["主仓库" if w.mode=="career" else "实验配给",count]
	caption.text="%s · %s · 已抵达%d/3箱\n点选水箱后也可点击落点；落在空白处会取消。" % [w.name,"暂停中" if w.paused else "观察中",int(p.worlds.total(w))]
	if is_instance_valid(progress) and not p.job.is_empty():
		progress.value=100*(1-float(p.job.left)/float(p.job.duration))
		progress_text.text="装罐中 · 剩余%d秒" % ceili(float(p.job.left))
	view.sync(w)

func _begin_drag(at: Vector2) -> void:
	var p=state.planet; var w=p.worlds.get_world()
	var count=p.products.size() if w.mode=="career" else int(w.allowance)
	if not p.joined or count<1:
		status.text="先领取合作并完成装罐，或建立独立实验副本"; return
	dragging=true; armed=false; rotating=false; pointer=at; start=at
	token=p.shipment_serial; target_world=w.id; ghost.show(); ghost.move_to_front()

func _tray_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		touch_index=event.index; _begin_drag(tray.global_position+event.position); accept_event()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and touch_index<0:
		_begin_drag(get_global_mouse_position()); accept_event()

func _site_at(at: Vector2) -> String:
	if not viewport_box.get_global_rect().has_point(at): return ""
	return view.pick((at-viewport_box.global_position)*Vector2(viewport.size)/viewport_box.size)

func _end_drag(at: Vector2) -> void:
	var site=_site_at(at)
	if not site.is_empty():
		var data={"world_id":target_world,"site_id":site,"token":token}
		_do("deploy",data)
	elif start.distance_to(at)<10 and tray.get_global_rect().has_point(at):
		dragging=false; armed=true; status.text="已选中水箱，点击深槽或浅台放置；返回键取消"
	else:
		_cancel_gesture(); status.text="已取消投放，水箱没有消耗"

func _cancel_gesture() -> void:
	dragging=false; armed=false; rotating=false; touch_index=-1
	if is_instance_valid(ghost): ghost.hide()
	if is_instance_valid(view): view.highlighted=""

func _input(event: InputEvent) -> void:
	if state==null or closing: return
	var at=Vector2.ZERO; var press=false; var release=false; var motion=false
	if event is InputEventScreenTouch:
		at=event.position; press=event.pressed; release=not press
		if press and viewport_box.get_global_rect().has_point(at): touch_index=event.index
		elif event.index!=touch_index: return
	elif event is InputEventScreenDrag:
		if event.index!=touch_index: return
		at=event.position; motion=true
	elif event is InputEventMouseButton:
		if touch_index>=0: return
		at=event.position
		if viewport_box.get_global_rect().has_point(at) and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			view.zoom(-0.5 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.5); get_viewport().set_input_as_handled(); return
		if event.button_index!=MOUSE_BUTTON_LEFT: return
		press=event.pressed; release=not press
	elif event is InputEventMouseMotion:
		if touch_index>=0: return
		at=event.position; motion=true
	else: return
	if press and viewport_box.get_global_rect().has_point(at):
		# Camera buttons are ordinary controls above the viewport.
		if at.y>=660 and at.x<610 and not armed: return
		if armed: dragging=true; armed=false
		else: rotating=true
		pointer=at; start=at; get_viewport().set_input_as_handled()
	elif motion and (dragging or armed or rotating):
		if rotating: view.rotate_view(at-pointer)
		pointer=at
		if dragging or armed: view.highlighted=_site_at(pointer)
		get_viewport().set_input_as_handled()
	elif release and dragging:
		_end_drag(at); touch_index=-1; get_viewport().set_input_as_handled()
	elif release and rotating:
		rotating=false; touch_index=-1; get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if state==null or closing: return
	refresh+=dt
	if refresh>=0.25:
		refresh=0
		if fingerprint!=_fingerprint(): _redraw()
		_live()
	for id in site_labels:
		var badge: PanelContainer=site_labels[id]
		badge.visible=view.site_visible(id)
		badge.position=viewport_box.position+view.project_site(id)*viewport_box.size/Vector2(viewport.size)+Vector2(-badge.size.x*0.5,85)
	if dragging or armed:
		ghost.position=pointer+Vector2(14,-40)
		view.highlighted=_site_at(pointer)
		view.highlight_valid=state.planet.worlds.can_deploy(target_world,view.highlighted)
		ghost.get_child(0).text="盆地已满" if not view.highlighted.is_empty() and not view.highlight_valid else "▣  水箱 ×1"

func handle_back() -> bool:
	if dragging or armed: _cancel_gesture()
	else: _close()
	return true

func _close() -> void:
	if closing: return
	closing=true; _cancel_gesture(); state.planet.observing=false; dismissed.emit(); queue_free()

func _exit_tree() -> void:
	if state!=null and state.planet.observer_id==get_instance_id(): state.planet.observing=false
