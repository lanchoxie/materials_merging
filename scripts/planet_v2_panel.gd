extends Control
signal dismissed
signal acted(message: String)
signal workshop_requested(recipe_id: String)
const UI=preload("res://scripts/ui.gd")
const View=preload("res://scripts/planet_v2_view.gd")
const ExplorationInput=preload("res://scripts/river_exploration_input.gd")
const InventorySlot=preload("res://scripts/river_inventory_slot.gd")
const InventoryPanel=preload("res://scripts/river_inventory_panel.gd")
var state
var view
var viewport: SubViewport
var viewport_box: SubViewportContainer
var body: VBoxContainer
var scroll: ScrollContainer
var status: Label
var time_label: Label
var info: Label
var counters: Label
var world_title: Label
var pause_button: Button
var enter_button: Button
var explore_input
var camera_bar: HBoxContainer
var right_panel: PanelContainer
var inspect_button: Button
var hint: Label
var show_details=false
var selected_region="wetland"
var section="observe"
var refresh=0.0
var fingerprint=""
var message=""
var widgets={}
var regions={}
var tabs={}
var closing=false
var build_mode="observe"
var play_bar: HBoxContainer
var action_button: Button
var aim_label: Label
var aim_clock=0.0
var hotbar_slots=[]
var inventory_items={}
var backpack=null
var scroll_memory=preload("res://scripts/panel_scroll.gd").new()

func setup(model) -> void:
	state=model; state.planet.v2.active=true; state.planet.v2.observer_id=get_instance_id()
	selected_region=str(state.planet.v2.world.current_region)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var heading=UI.label("河湾 · 一片会生长的世界",30,UI.MINT); heading.position=Vector2(28,18); add_child(heading)
	var sub=UI.label("上帝视角 ↔ 第一人称   /   0.21 开发预览 · 单星球版   /   约1公里探索区",14,UI.MUTED); sub.position=Vector2(30,62); add_child(sub)
	var close=UI.button("返回浮岛",_close); close.position=Vector2(1288,22); close.size=Vector2(124,48); add_child(close)
	time_label=UI.label("",19,UI.GOLD); time_label.position=Vector2(680,28); time_label.size=Vector2(580,38); time_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; add_child(time_label)
	var region_bar=UI.row(self,8); region_bar.position=Vector2(28,99)
	for spec in state.planet.v2.rules.regions:
		var b=UI.button(str(spec.name),_select_region.bind(str(spec.id))); b.custom_minimum_size.x=167; region_bar.add_child(b); regions[spec.id]=b
	enter_button=UI.button("第一人称进入",_enter,true); enter_button.custom_minimum_size.x=194; region_bar.add_child(enter_button)
	viewport_box=SubViewportContainer.new(); viewport_box.position=Vector2(28,158); viewport_box.size=Vector2(928,574); viewport_box.stretch=true; viewport_box.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(viewport_box)
	viewport=SubViewport.new(); viewport.size=Vector2i(928,574); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport_box.add_child(viewport)
	view=View.new(); viewport.add_child(view)
	view.region_selected.connect(_walked_region)
	explore_input=ExplorationInput.new(); explore_input.view=view; explore_input.position=viewport_box.position; explore_input.size=viewport_box.size; add_child(explore_input)
	explore_input.terrain_clicked.connect(_map_click)
	explore_input.journey_requested.connect(_open_journey)
	explore_input.collect_requested.connect(_collect)
	explore_input.build_requested.connect(_open_backpack)
	explore_input.slot_requested.connect(_select_slot)
	explore_input.slot_cycled.connect(func(direction): _select_slot(posmod(state.planet.v2.inventory.selected+direction,9)))
	explore_input.primary_requested.connect(_collect)
	explore_input.zoomed.connect(func(amount): view.zoom=clampf(view.zoom+amount,0.65,1.4))
	world_title=UI.label("",18,UI.MINT); world_title.position=Vector2(48,180); add_child(world_title)
	hint=UI.label("点选地形 · 滚轮缩放 · 第一人称走进去",13,UI.TEXT); hint.position=Vector2(48,705); add_child(hint)
	camera_bar=UI.row(self,8); camera_bar.position=Vector2(590,676)
	camera_bar.add_child(UI.button("近看",func(): view.focus(selected_region,not view.close_view); _live()))
	camera_bar.add_child(UI.button("↶",func(): view.orbit(-0.4)))
	camera_bar.add_child(UI.button("↷",func(): view.orbit(0.4)))
	camera_bar.add_child(UI.button("＋",func(): view.zoom=clampf(view.zoom-0.15,0.65,1.4)))
	camera_bar.add_child(UI.button("－",func(): view.zoom=clampf(view.zoom+0.15,0.65,1.4)))
	var time_box=UI.box(self,Rect2(28,748,928,91))
	var time_row=UI.row(time_box,10)
	pause_button=UI.button("暂停",func(): _act("v2_pause",{"paused":not state.planet.v2.world.paused})); time_row.add_child(pause_button)
	for speed in [1,4,8]: time_row.add_child(UI.button("%d×" % speed,func(): _act("v2_speed",{"speed":speed})))
	counters=UI.paragraph("",16,UI.GOLD); counters.size_flags_horizontal=Control.SIZE_EXPAND_FILL; time_row.add_child(counters)
	right_panel=UI.box(self,Rect2(976,99,436,740)); var col=UI.column(right_panel,10)
	info=UI.paragraph("",17,UI.MINT); col.add_child(info)
	var nav=UI.row(col,8)
	for entry in [["observe","生命"],["bag","背包"],["explore","远行"],["build","搭建"],["era","时代"],["journal","年鉴"]]:
		var b=UI.button(entry[1],_tab.bind(entry[0])); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; nav.add_child(b); tabs[entry[0]]=b
		b.add_theme_font_size_override("font_size",14)
	scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; col.add_child(scroll)
	body=UI.column(scroll,10); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inspect_button=UI.button("世界 / 远行",_toggle_details); inspect_button.position=Vector2(1240,170); inspect_button.size=Vector2(148,44); inspect_button.hide(); add_child(inspect_button)
	status=UI.paragraph("M前往采集坡 · 用手套采集原料 → 工艺车间加工 → 背包搭建、播种和浇水。",15,UI.GOLD); status.position=Vector2(32,853); status.size=Vector2(1370,35); add_child(status)
	play_bar=UI.row(self,4); play_bar.position=Vector2(300,656)
	for i in range(state.planet.v2.inventory.slots.size()):
		var slot=InventorySlot.new(); play_bar.add_child(slot); slot.custom_minimum_size=Vector2(56,72); hotbar_slots.append(slot)
		slot.pressed.connect(_select_slot.bind(i))
	action_button=UI.button("操作 E",_collect,true); action_button.focus_mode=Control.FOCUS_NONE; play_bar.add_child(action_button)
	var jump_button=UI.button("跳跃 ␣",func(): view.walker.jump()); jump_button.focus_mode=Control.FOCUS_NONE; play_bar.add_child(jump_button)
	var bag_button=UI.button("背包 B",_open_backpack); bag_button.focus_mode=Control.FOCUS_NONE; play_bar.add_child(bag_button)
	play_bar.hide()
	aim_label=UI.label("",15,UI.GOLD); aim_label.position=Vector2(350,628); add_child(aim_label); aim_label.hide()
	_refresh_hotbar(); _redraw(); _sync.call_deferred()

func _map_click(at: Vector2) -> void:
	# Only the map's GUI layer owns selection; its coordinates are always local.
	# A first-person click must never become a region/respawn command.
	if view.first_person: return
	var id=view.pick(at*Vector2(viewport.size)/explore_input.size)
	if not id.is_empty(): _select_region(id)

func _select_region(id: String) -> void:
	selected_region=id; message=state.planet.command(state,"v2_enter",{"region_id":id})
	view.focus(id,view.close_view); _redraw(); _sync()
	if view.first_person: explore_input.clear_input(); explore_input.grab_focus()

func _walked_region(id: String) -> void:
	if _in_wilderness(): return
	selected_region=id; state.planet.command(state,"v2_enter",{"region_id":id})
	message="步行来到"+str(state.planet.v2.region().name); _redraw()

func _enter() -> void:
	view.set_first_person(not view.first_person); explore_input.set_walking(view.first_person)
	show_details=false; _exploration_layout(); _redraw(); _sync()

func _toggle_details() -> void:
	show_details=not show_details; explore_input.clear_input(); _exploration_layout()
	if not show_details: explore_input.grab_focus()

func _exploration_layout() -> void:
	var wide=view.first_person and not show_details
	viewport_box.size=Vector2(1384 if wide else 928,574)
	explore_input.size=viewport_box.size
	right_panel.visible=not wide; camera_bar.visible=not view.first_person
	inspect_button.visible=view.first_person; inspect_button.position.x=1240 if wide else 790
	inspect_button.text="收起面板" if show_details else "世界 / 远行"
	play_bar.visible=view.first_person; aim_label.visible=view.first_person
	play_bar.position.x=300 if wide else 150; aim_label.position.x=350 if wide else 220
	hint.position=Vector2(48,214) if view.first_person else Vector2(48,705)
	hint.text="WASD走动 · 空格跳跃 · 拖动转向 · E使用 · 1—9 / 滚轮选物品 · B背包 · M远行\n触屏：左下摇杆移动，右侧滑动转向；点快捷格选物品，再点操作" if view.first_person else "点选地形 · 滚轮缩放 · 第一人称走进去"
	if not view.first_person: state.planet.v2.actor={}; view.construction_view.ghost.hide()

func _in_wilderness() -> bool:
	return view!=null and view.first_person and view.walker.position.length()>float(view.terrain.rules.home_radius)+2

func _observer_position() -> Vector2:
	return view.walker.position if view.first_person else Vector2.ZERO

func _open_journey() -> void:
	show_details=true; explore_input.clear_input(); _exploration_layout(); _tab("explore")

func _travel(id: String) -> void:
	var destination=view.terrain.LANDMARKS[id]
	view.travel(destination.at); explore_input.set_walking(true)
	show_details=false; _exploration_layout(); message="抵达"+str(destination.name)+"。M查看旅途，成熟的金色野草可以采集。"
	if id=="homestead": message="采集坡：装备手套，瞄准枯枝堆、散石或果丛按E；原料可带回工艺车间。"
	_redraw(); _sync()

func _collect() -> void:
	if is_instance_valid(backpack): return
	_update_actor()
	var id=str(state.planet.v2.inventory.slots[state.planet.v2.inventory.selected])
	if id.is_empty(): message="这一格是空的，按 B 从背包装备物品。"; _live(); return
	_use_item(id)

func _use_item(id: String,alternate: String="") -> void:
	_update_actor()
	var items=state.planet.v2.inventory.entries(state)
	var item: Dictionary=items.get(id,{})
	if item.is_empty() or item.quantity==0: message="这件物品已用完，请补充库存或换一格。"; _live(); return
	var action: Dictionary=item.action
	if action.is_empty(): message="这件物品目前不能直接在星球使用。"; _live(); return
	var type=str(action.type)
	var target=state.planet.v2.Target.query(state.planet.v2)
	if alternate=="pantry": _act("v2_field_pantry",{"resource":action.get("resource","")}); return
	if alternate=="deploy": type="product"
	if type in ["build","remove"]:
		_update_actor()
		_act("v2_dismantle" if type=="remove" else "v2_build",{"kind":action.get("kind","block"),"recipe":action.get("recipe","")})
	elif type=="plant":
		if view.first_person and alternate!="reed": _act("v2_field_plant")
		else: _act("v2_plant",{"crop":alternate if alternate=="reed" else "grain"})
	elif type=="sample":
		var local=view.first_person and target.get("kind")=="planter"
		_act("v2_field_water" if local else "v2_deploy_sample",{"batch_id":action.batch_id,"region_id":selected_region,"token":state.planet.shipment_serial})
	elif type=="product":
		var product_id=-1
		for product in state.planet.products:
			if product.recipe==action.recipe: product_id=int(product.id); break
		if product_id<0: message="没有完整的成品包；先拆回构件并在搭建页整包收纳。"; _live(); return
		var local=view.first_person and target.get("kind")=="planter" and action.recipe=="standard_water_crate"
		_act("v2_field_water" if local else "v2_deploy_product",{"product_id":product_id,"region_id":selected_region,"token":state.planet.shipment_serial})
	elif type=="collect": _act("v2_field_collect")
	elif type=="feed": _act("v2_field_feed",{"resource":action.resource})
	if not target.is_empty(): view.field_view.feedback(target.point)
	if is_instance_valid(backpack): backpack.feedback.text=message; backpack.refresh()

func _collect_wild() -> void:
	if not view.first_person:
		message="先进入第一人称，走近成熟的野生植被。"; _live(); return
	var at: Vector2=view.walker.position
	_act("v2_collect_wild",{"x":at.x,"z":at.y})

func _tool(mode: String) -> void:
	var id="tool:remove" if mode=="remove" else "tool:collect"
	if mode in ["block","solar"]:
		var c=state.planet.v2.construction
		for recipe in c.rules.recipes:
			if c.rules.recipes[recipe].kind==mode and c.available(mode,state.planet.products,recipe)>0:
				id="recipe:"+str(recipe); break
		if not id.begins_with("recipe:"): _open_backpack(); return
	_equip_item(id)

func _equip_item(id: String) -> void:
	var inventory=state.planet.v2.inventory; var items=inventory.entries(state)
	var index=inventory.slots.find(id)
	if index<0:
		index=inventory.slots.find("")
		if index<0: index=inventory.selected
		inventory.bind_slot(index,id,items)
	_close_backpack(); _select_slot(index)
	if not view.first_person: _enter()
	show_details=false; explore_input.clear_input(); _exploration_layout(); explore_input.grab_focus(); _aim()

func _select_slot(index: int) -> void:
	state.planet.v2.inventory.selected=clampi(index,0,8)
	_refresh_hotbar()
	if not is_instance_valid(backpack): explore_input.grab_focus()
	_aim()

func _refresh_hotbar() -> void:
	var inventory=state.planet.v2.inventory; inventory_items=inventory.entries(state)
	for i in range(hotbar_slots.size()):
		var id=str(inventory.slots[i])
		hotbar_slots[i].set_item({} if id.is_empty() else inventory_items.get(id,inventory.missing(id)),i+1,i==inventory.selected)
	var selected: Dictionary=inventory_items.get(inventory.slots[inventory.selected],{})
	var action: Dictionary=selected.get("action",{})
	build_mode=str(action.get("kind","")) if action.get("type")=="build" else ("remove" if action.get("type")=="remove" else "observe")

func _open_backpack() -> void:
	if is_instance_valid(backpack): return
	explore_input.set_walking(false); explore_input.hide(); view.construction_view.ghost.hide()
	backpack=InventoryPanel.new(); add_child(backpack); backpack.setup(state)
	backpack.dismissed.connect(_close_backpack)
	backpack.changed.connect(_refresh_hotbar)
	backpack.use_requested.connect(func(id,alternate):
		var item=state.planet.v2.inventory.entries(state).get(id,{})
		if alternate.is_empty() and item.get("action",{}).get("type") in ["build","collect","remove","feed"]: _equip_item(id)
		else: _use_item(id,alternate))
	backpack.workshop_requested.connect(func(): workshop_requested.emit(""))

func _close_backpack() -> void:
	if not is_instance_valid(backpack): return
	backpack.queue_free(); backpack=null
	explore_input.show(); explore_input.set_walking(view.first_person); _refresh_hotbar()

func _open_building() -> void:
	show_details=true; explore_input.clear_input(); _exploration_layout(); _tab("build")

func _update_actor() -> void:
	var v=state.planet.v2
	if not view.first_person: v.actor={}; return
	v.actor={"eye":view.walker.eye(),"direction":-view.camera.global_basis.z,"feet":Vector3(view.walker.position.x,view.walker.feet_y,view.walker.position.y)}

func _aim() -> void:
	_update_actor()
	if not view.first_person or is_instance_valid(backpack): return
	var v=state.planet.v2
	var id=str(v.inventory.slots[v.inventory.selected]); var item: Dictionary=inventory_items.get(id,{})
	var action: Dictionary=item.get("action",{})
	var target=v.Target.query(v)
	aim_label.text=view.construction_view.preview(v.construction,v.actor,build_mode,state.planet.products,str(action.get("recipe","")))
	if build_mode=="observe": aim_label.text=v.Target.prompt(v,target)
	if build_mode=="observe" and action.get("type")!="collect":
		if id.is_empty(): aim_label.text="空格 · B 打开背包"
		elif action.get("type") in ["sample","product"]:
			var water=action.get("reference")=="water" or action.get("recipe")=="standard_water_crate"
			aim_label.text=str(item.get("name","已用完"))+ (" · E 浇这一箱" if water and target.get("kind")=="planter" else (" · 这箱需要水" if target.get("kind")=="planter" else " · E 使用于"+str(v.region().name)))
		elif action.get("type")=="plant": aim_label.text=v.Target.prompt(v,target)+" · E 播种"
	action_button.text="采集 E" if action.get("type")=="collect" else ("拆回 E" if build_mode=="remove" else ("放置 E" if action.get("type")=="build" else "使用 E"))

func _tab(id: String) -> void:
	if id=="bag": _open_backpack(); return
	section=id; _redraw(true)

func _act(action: String,payload: Dictionary={}) -> void:
	if _in_wilderness() and action in ["v2_plant","v2_harvest","v2_pen","v2_deploy_sample","v2_deploy_product"]:
		message="远郊当前开放探索与野生采集。播种、设施和材料试验请返回起始河湾。"; _live(); return
	message=state.planet.command(state,action,payload); acted.emit(message); _refresh_hotbar(); _redraw(); _sync()

func _card(title: String) -> VBoxContainer:
	var p=PanelContainer.new(); body.add_child(p); var col=UI.column(p,7); col.add_child(UI.paragraph(title,19,UI.MINT)); return col

func _key() -> String:
	var v=state.planet.v2; var r=v.world.regions[selected_region]; var stock=[]
	for b in state.storage.batches: stock.append([b.id,b.quantity])
	var life=[]; var crops=[]
	for a in r.animals: life.append(a.id)
	for c in r.crops: crops.append([c.crop,c.ready])
	return str([selected_region,section,_in_wilderness(),v.population.enabled,stock,state.planet.products,life,crops,r.buildings,r.enclosed,v.world.events.size(),v.world.events[0],v.world.seeds,v.world.food,v.construction.revision,v.field.revision,v.settlement.era])

func _redraw(reset_scroll: bool=false) -> void:
	if body==null: return
	scroll_memory.refresh(scroll,reset_scroll)
	UI.clear(body); widgets={}; fingerprint=_key()
	match section:
		"observe": _observation()
		"bag": _open_backpack()
		"explore": _journey()
		"journal": _journal()
		"build": _building()
		"era": _era()
	_live()

func _observation() -> void:
	if _in_wilderness():
		var nearby=_card("远郊 · 野生栖地")
		widgets.explore=UI.paragraph("",16); nearby.add_child(widgets.explore)
		nearby.add_child(UI.button("采集附近成熟植被",_collect_wild,true))
		nearby.add_child(UI.button("远行与营地",_open_journey))
		nearby.add_child(UI.paragraph("远郊先开放游历与采集。材料投放、播种和圈养仍在起始河湾的四个试验区进行。",15))
		return
	var v=state.planet.v2; var r=v.region()
	var life=_card("这片土地上的生命")
	widgets.environment=UI.paragraph("",16,UI.TEXT); life.add_child(widgets.environment)
	widgets.herd=UI.paragraph("",16,UI.GOLD); life.add_child(widgets.herd)
	var crops=_card("种植 · 收获 · 留种")
	widgets.crops=UI.paragraph("",16,UI.TEXT); crops.add_child(widgets.crops)
	var row=UI.row(crops,6)
	row.add_child(UI.button("播谷物 · 1种",func(): _act("v2_plant",{"crop":"grain"})))
	row.add_child(UI.button("播芦苇 · 1种",func(): _act("v2_plant",{"crop":"reed"})))
	crops.add_child(UI.button("收获成熟作物",func(): _act("v2_harvest")))
	var pen=_card("圈养与设施")
	pen.add_child(UI.paragraph("从浮岛带来结构构件包搭围栏。关门后，小兽从粮仓取食；开门后恢复自然觅食。遮荫棚保水，但会减慢作物生长。",15))
	pen.add_child(UI.button("打开围栏" if r.enclosed else "关闭围栏",func(): _act("v2_pen")))
	pen.add_child(UI.button("从背包带材料过来",func(): _tab("bag"),true))
	var family=_card("动物个体与后代")
	widgets.animals=UI.paragraph("",14,UI.TEXT); family.add_child(widgets.animals)
	body.add_child(UI.paragraph("教学物种与压缩时间。溶氧等为游戏指标，不能换算成真实浓度。后代继承性状，当前尚无新物种分化。",13,UI.MUTED))

func _journey() -> void:
	var destinations=_card("沿河而行")
	destinations.add_child(UI.paragraph("约1公里宽的探索区，也可以全程步行。先用这些路标看看远方。",15))
	for id in view.terrain.LANDMARKS:
		var item=view.terrain.LANDMARKS[id]
		destinations.add_child(UI.button(str(item.name)+"  ↗",_travel.bind(id)))
	var life=_card("附近的生命")
	widgets.explore=UI.paragraph("",15); life.add_child(widgets.explore)
	life.add_child(UI.button("采集附近成熟植被",_collect_wild,true))
	var renewal=_card("世界会慢慢补充")
	renewal.add_child(UI.paragraph("草木等待再生，小兽从远处迁入；食物充足的营地会接待新旅人。迁入与繁殖有容量限制，关着的围栏不接纳外来动物。",15))
	renewal.add_child(UI.button("自然补充：开启" if state.planet.v2.population.enabled else "自然补充：关闭",func(): _act("v2_renewal",{"enabled":not state.planet.v2.population.enabled})))
	renewal.add_child(UI.paragraph("当前旅人演示进营、采集、休息和离营。远处未观察的栖地暂停计时；时代聚落与人物性格将在后续接入。",13,UI.MUTED))

func _building() -> void:
	var c=state.planet.v2.construction
	var start=_card("从一把枯枝，到第一块菜地")
	start.add_child(UI.paragraph("① 到采集坡，用手套采木料、散石和纤维。\n② 在浮岛连通工艺车间、安排工程师，加工墙、屋顶和种植箱。\n③ 把成品放入快捷栏，在星球搭建。\n④ 装备种子瞄准箱子播种，用水样或标准水箱浇这一箱；成熟后手套收获。",15))
	start.add_child(UI.button("前往采集坡",_travel.bind("homestead"),true))
	for recipe in state.planet.v2.field.rules.recipes:
		start.add_child(UI.button("加工 · "+str(state.planet.recipe(recipe).name),func(): workshop_requested.emit(recipe)))
	var card=_card("把背包材料搭成家")
	card.add_child(UI.paragraph("一包工坊结构构件可搭8块木构。打开背包，把构件装备到快捷栏；瞄准近处地面或方块表面，绿色预览后单击或按E放置。触屏点底部放置按钮。能搭台阶、墙和屋顶，也能安装车间制造的光伏组件。",15))
	card.add_child(UI.button("打开背包装备构件",_open_backpack,true))
	card.add_child(UI.button("去车间制作木构件",func(): workshop_requested.emit("frame_bundle")))
	card.add_child(UI.button("去车间制作光伏",func(): workshop_requested.emit("modern_silicon")))
	card.add_child(UI.button("拆回自己的构件",_tool.bind("remove")))
	var returns=_card("施工材料包 · 可带回浮岛")
	for id in c.sources:
		var source=c.sources[id]; var total=int(c.rules.recipes[source.product.recipe].units)
		returns.add_child(UI.paragraph("%s #%s · 余%d/%d\n来源 %s" % [state.planet.recipe(source.product.recipe).name,id,source.remaining,total,source.product.source_batch],14))
		var b=UI.button("整包收入工具箱",_act.bind("v2_repack",{"source_id":id})); b.disabled=source.remaining!=total; returns.add_child(b)
	returns.add_child(UI.paragraph("拆除退回原材料；先拆边缘，避免留下悬空建筑。地形与树木暂不能破坏。",13))

func _era() -> void:
	var s=state.planet.v2.settlement
	var card=_card(s.title())
	card.add_child(UI.paragraph(s.rules.eras[s.era].story,16))
	widgets.era=UI.paragraph("",15,UI.GOLD); card.add_child(widgets.era)
	if s.era==0: card.add_child(UI.paragraph("住处是你实际搭的建筑，不是要找一个叫‘屋檐’的物品。用木构搭立柱，再横接屋顶；屋顶正下方至少留2格空地，每格都能站直、不被方块堵住。屋顶旁露天的地面不算住处。",14))
	if s.era<2:
		card.add_child(UI.button("建立"+str(s.rules.eras[s.era+1].name),func(): _act("v2_next_era"),true))
	card.add_child(UI.button("回草甸营地",func(): _travel("home"); _tool("observe")))
	widgets.residents=UI.paragraph("",15); card.add_child(widgets.residents)
	card.add_child(UI.paragraph("这是同一世界的游戏时代章节，保留动物个体和你的建筑。史前物种、完整工业时代与未来科技仍待扩展。",13,UI.MUTED))

func _nearby_text() -> String:
	var at=_observer_position(); var v=state.planet.v2; var s=v.population.nearest(at)
	if s.is_empty(): return "这里暂未发现栖地。向林间营地走走。"
	var distance=at.distance_to(Vector2(s.x,s.z))
	var count=v.world.regions[s.id].animals.size() if s.home else s.animals.size()
	var mature=s.flora>=float(v.population.rules.harvest_maturity); var radius=float(v.population.rules.harvest_radius)
	var text="距栖地中心 %.0f米 · %d只动物\n野生植被 %.0f%% · %s\n" % [distance,count,s.flora*100,"可以采集" if mature and distance<=radius else ("走近%.0f米以内可采" % radius if mature else "等待自然再生")]
	for visitor in s.visitors: text+="%s #%d · %s\n" % [visitor.name,visitor.id,visitor.state]
	if s.camp and s.visitors.is_empty(): text+="营地正在等待下一批旅人。"
	return text

func _journal() -> void:
	var v=state.planet.v2; var events=_card("河湾年鉴")
	for e in v.world.events:
		events.add_child(UI.paragraph("第%d天  ·  %s" % [int(float(e.time)/float(v.rules.clock.day_seconds))+1,e.text],15,UI.TEXT))
	var deliveries=_card("材料足迹 · 最近8次")
	var receipts=v.world.receipts.duplicate(); receipts.reverse()
	for receipt in receipts.slice(0,8):
		var origin=str(receipt.get("batch_id",receipt.get("product",{}).get("source_batch","")))
		deliveries.add_child(UI.paragraph("%s → %s\n来源批次 %s" % [v.rules.products[receipt.use].name,v.world.regions[receipt.region].name,origin],14))
	if receipts.is_empty(): deliveries.add_child(UI.paragraph("投放第一份材料后，会在这里留下足迹。",15))

func _live() -> void:
	var v=state.planet.v2; var r=v.region()
	time_label.text=v.time_label()+" · %dx" % int(v.world.speed)
	pause_button.text="继续" if v.world.paused else "暂停"
	enter_button.text="返回上帝视角" if view.first_person else "第一人称进入"
	world_title.text=str(r.name)+(" · 徒步探索" if view.first_person else (" · 局部观察" if view.close_view else " · 河湾全景"))
	info.text=str(r.name)+"\n"+str(r.terrain)
	if _in_wilderness():
		world_title.text="远郊 · %.0f, %.0f米" % [view.walker.position.x,view.walker.position.y]
		info.text="远郊探索\n林地 · 河流 · 营地"
		if view.walker.position.length()>float(view.terrain.rules.radius)-28:
			world_title.text="海岸 · 已到当前探索区边缘"
	counters.text="种子 %d · 饲料 %d\n1分钟=1天 · 每4天换季" % [v.world.seeds,v.world.food]
	if not message.is_empty(): status.text=message
	for key in regions: regions[key].modulate=UI.MINT if key==selected_region and not _in_wilderness() else Color.WHITE
	for key in tabs: tabs[key].modulate=UI.MINT if key==section else Color.WHITE
	if widgets.has("explore"): widgets.explore.text=_nearby_text()
	if widgets.has("era"):
		widgets.era.text=v.settlement.requirements(v.world,v.construction)+"\n太阳能服务点 %.1f/60 · %s" % [v.settlement.energy,"灌溉运行中" if v.settlement.irrigation else "待机"]
		var residents=""
		for p in v.settlement.people: residents+="%s · %s · 健康%.0f%% / 饥饿%.0f%%\n" % [p.name,p.task,p.health*100,p.hunger*100]
		widgets.residents.text=residents if not residents.is_empty() else "满足住处、作物与水源条件后，旅人愿意定居。"
	if section!="observe" or not widgets.has("environment"): return
	widgets.environment.text="水位 %.0f%% · 土壤湿度 %.0f%%\n溶氧 %.0f%% · 温度 %.1f°C\n土壤营养 %.0f%% · 颗粒负担 %.0f%%" % [r.water*100,r.moisture*100,r.oxygen*100,r.temperature,r.nutrients*100,r.pollution*100]
	var generation=0
	for a in r.animals: generation=maxi(generation,int(a.generation))
	widgets.herd.text="%d只动物 · 谱系最高第%d代" % [r.animals.size(),generation+1]
	var text=""
	for plot in r.crops:
		var c=v.crop(plot.crop); var reason="成熟，等待收获" if plot.ready else ("等水分 / 温度 / 营养" if r.moisture<c.moisture_min or r.moisture>c.moisture_max or r.temperature<c.temperature_min or r.temperature>c.temperature_max or r.nutrients<=0.08 else "正在生长")
		text+="%s  %.0f%% · %s\n" % [c.name,plot.growth*100,reason]
	widgets.crops.text=text if not text.is_empty() else "空地上可以播下种子。"
	text=""
	for a in r.animals.slice(0,8):
		text+="#%d %s · 第%d代 · %s\n健康%.0f%% / 饥饿%.0f%% / 需氧阈值%.0f%%\n" % [a.id,v.species(a.species).name,a.generation+1,a.state,a.health*100,a.hunger*100,a.tolerance*100]
	widgets.animals.text=text if not text.is_empty() else "这里暂时没有动物。"

func _sync() -> void:
	if view==null: return
	var v=state.planet.v2; var at=_observer_position()
	v.population.observe(at)
	if not view.first_person: view.selected=selected_region
	view.sync(v.world,v.season())
	view.life_view.sync(v.population,at,v.world.paused)
	view.walker.barriers.append_array(view.life_view.barriers)
	v.construction.obstacles=view.walker.barriers.duplicate()
	view.walker.construction=v.construction
	view.construction_view.sync(v.construction,at)
	view.field_view.sync(v.field,v.construction,at,int(v.world.elapsed))
	view.settlement_view.sync(v.settlement,at)
	view.life_view.era=v.settlement.era
	_live(); _aim()

func _process(dt: float) -> void:
	if state==null or closing: return
	aim_clock+=dt
	if aim_clock>=0.12: aim_clock=0; _aim()
	refresh+=dt
	if refresh<0.5: return
	refresh=0
	if fingerprint!=_key(): _refresh_hotbar(); _redraw()
	_sync()

func _exit_tree() -> void:
	if state!=null and state.planet.v2.observer_id==get_instance_id(): state.planet.v2.active=false; state.planet.v2.actor={}

func handle_back() -> bool:
	if is_instance_valid(backpack): _close_backpack(); return true
	if view.first_person: _enter(); return true
	_close(); return true

func _close() -> void:
	explore_input.clear_input()
	closing=true; state.planet.v2.active=false; dismissed.emit(); queue_free()
