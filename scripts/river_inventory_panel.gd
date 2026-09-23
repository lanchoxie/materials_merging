extends Control
## Modal view over the shared inventory adapter; actions go back to the planet coordinator.
signal dismissed
signal use_requested(id: String,alternate: String)
signal workshop_requested
signal changed
const UI=preload("res://scripts/ui.gd")
const Slot=preload("res://scripts/river_inventory_slot.gd")
var state
var model
var items={}
var category="all"
var selected_id=""
var grid: GridContainer
var scroll: ScrollContainer
var detail: VBoxContainer
var detail_scroll: ScrollContainer
var detail_memory=preload("res://scripts/panel_scroll.gd").new()
var detail_id=""
var shortcuts: HBoxContainer
var feedback: Label
var signature=""
var clock=0.0
var scroll_memory=preload("res://scripts/panel_scroll.gd").new()

func setup(s) -> void:
	state=s; model=s.planet.v2.inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new(); shade.color=Color(0.02,0.06,0.09,0.86); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	UI.box(self,Rect2(208,100,1024,692))
	var title=UI.label("行囊",30,UI.MINT); title.position=Vector2(238,122); add_child(title)
	var sub=UI.label("与浮岛共享库存 · 从材料到一片新世界",15,UI.MUTED); sub.position=Vector2(322,135); add_child(sub)
	var close=UI.button("返回世界  B",_close); close.position=Vector2(1050,119); close.size=Vector2(150,44); add_child(close)
	var tabs=UI.row(self,8); tabs.position=Vector2(238,184)
	for id in model.rules.categories:
		tabs.add_child(UI.button(str(model.rules.categories[id]),func(): category=id; refresh(true)))
	scroll=ScrollContainer.new(); scroll.position=Vector2(238,246); scroll.size=Vector2(614,348); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	grid=GridContainer.new(); grid.mouse_filter=Control.MOUSE_FILTER_PASS; grid.columns=7; grid.add_theme_constant_override("h_separation",7); grid.add_theme_constant_override("v_separation",7); scroll.add_child(grid)
	var box=UI.box(self,Rect2(875,184,325,410))
	detail_scroll=ScrollContainer.new(); detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(detail_scroll)
	detail=UI.column(detail_scroll,10); detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	feedback=UI.paragraph("点选物品，再点下方格子装备；电脑也可直接拖入。",15,UI.GOLD); feedback.position=Vector2(238,611); feedback.size=Vector2(960,40); add_child(feedback)
	shortcuts=UI.row(self,7); shortcuts.position=Vector2(238,657)
	var clear=UI.button("清空\n当前格",_clear_slot); clear.position=Vector2(1010,657); clear.size=Vector2(90,80); add_child(clear)
	var factory=UI.button("工艺\n车间",func(): workshop_requested.emit()); factory.position=Vector2(1110,657); factory.size=Vector2(90,80); add_child(factory)
	var help=UI.label("快捷栏只保存物品引用，整理不会消耗或复制材料。1—9 选格；B / Tab 关闭。",13,UI.MUTED); help.position=Vector2(238,756); add_child(help)
	selected_id=str(model.slots[model.selected]); refresh()

func refresh(reset: bool=false) -> void:
	items=model.entries(state); signature=str([items,model.serialize()])
	scroll_memory.refresh(scroll,reset); UI.clear(grid); UI.clear(shortcuts)
	for id in items:
		var item: Dictionary=items[id]
		if category!="all" and item.category!=category: continue
		var slot=Slot.new(); slot.set_item(item,0,id==selected_id); grid.add_child(slot)
		slot.pressed.connect(func(): selected_id=id; refresh())
	# Empty cells are visual breathing room, never a second storage capacity limit.
	for i in range(maxi(0,28-grid.get_child_count())):
		var empty=Slot.new(); empty.disabled=true; grid.add_child(empty)
	for i in range(model.slots.size()):
		var id=str(model.slots[i]); var item: Dictionary={} if id.is_empty() else items.get(id,model.missing(id))
		var slot=Slot.new(); slot.set_item(item,i+1,i==model.selected); slot.drop_enabled=true; shortcuts.add_child(slot)
		slot.item_dropped.connect(func(key): _assign(i,key))
		slot.pressed.connect(func():
			if not selected_id.is_empty(): _assign(i,selected_id)
			else: model.selected=i; refresh(); changed.emit())
	_details()

func _details() -> void:
	detail_memory.refresh(detail_scroll,detail_id!=selected_id); detail_id=selected_id
	UI.clear(detail)
	if selected_id.is_empty():
		detail.add_child(UI.paragraph("选一件带在手上",23,UI.MINT)); detail.add_child(UI.paragraph("工具可反复使用。构件按块计数，样品按批次分格，使用时才扣除实际库存。",16)); return
	var item: Dictionary=items.get(selected_id,model.missing(selected_id))
	detail.add_child(UI.paragraph(item.name,23,UI.MINT))
	detail.add_child(UI.paragraph("不限次数" if item.quantity<0 else "现有 %d" % int(item.quantity),16,UI.GOLD))
	detail.add_child(UI.paragraph(item.description,15))
	if not item.action.is_empty():
		var type=str(item.action.type); var label="拿在手上" if type in ["build","collect","remove","feed"] else "在当前区域使用 1份"
		if type in ["plant","sample","product"]: detail.add_child(UI.button("装备到当前快捷格",func(): _assign(model.selected,selected_id)))
		var b=UI.button(label,func(): use_requested.emit(selected_id,""),true); b.disabled=item.quantity==0; detail.add_child(b)
		if type=="plant": detail.add_child(UI.button("改种芦苇 · 1种",func(): use_requested.emit(selected_id,"reed")))
		if type=="feed": detail.add_child(UI.button("送1份到粮仓",func(): use_requested.emit(selected_id,"pantry")))
		if type=="build" and state.planet.v2.rules.products.has(item.action.recipe):
			detail.add_child(UI.button("整包搭成围栏",func(): use_requested.emit(selected_id,"deploy")))
	else: detail.add_child(UI.paragraph("保留在库存中 · 当前不能直接放置",14,UI.GOLD))
	if str(item.id).begins_with("recipe:"):
		detail.add_child(UI.button("到车间补充",func(): workshop_requested.emit()))
	if str(item.id).begins_with("raw:"): detail.add_child(UI.button("带到工艺车间加工",func(): workshop_requested.emit()))

func _assign(index: int,id: String) -> void:
	if model.bind_slot(index,id,items):
		selected_id=""; feedback.text="已装备到第%d格。关闭背包后，按 E 或点操作按钮使用。" % (index+1)
		changed.emit(); refresh()

func _clear_slot() -> void:
	model.bind_slot(model.selected,"",items); selected_id=""; changed.emit(); refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if code in [KEY_B,KEY_TAB,KEY_ESCAPE]: get_viewport().set_input_as_handled(); _close()
	elif code>=KEY_1 and code<=KEY_9:
		get_viewport().set_input_as_handled()
		if not selected_id.is_empty(): _assign(code-KEY_1,selected_id)
		else: model.selected=code-KEY_1; changed.emit(); refresh()

func _process(dt: float) -> void:
	clock+=dt
	if clock<0.5: return
	clock=0
	var latest=model.entries(state)
	if signature!=str([latest,model.serialize()]): refresh()

func _close() -> void:
	dismissed.emit(); queue_free()
