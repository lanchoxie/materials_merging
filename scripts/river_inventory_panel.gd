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
	var tabs=GridContainer.new(); tabs.columns=6; tabs.position=Vector2(238,176); tabs.add_theme_constant_override("h_separation",4); tabs.add_theme_constant_override("v_separation",4); add_child(tabs)
	for id in model.rules.categories:
		var tab=UI.button(str(model.rules.categories[id]),func(): category=id; refresh(true)); tab.custom_minimum_size=Vector2(86,28); tab.add_theme_font_size_override("font_size",13); tabs.add_child(tab)
	scroll=ScrollContainer.new(); scroll.position=Vector2(238,290); scroll.size=Vector2(614,304); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	grid=GridContainer.new(); grid.mouse_filter=Control.MOUSE_FILTER_PASS; grid.columns=7; grid.add_theme_constant_override("h_separation",7); grid.add_theme_constant_override("v_separation",7); scroll.add_child(grid)
	var box=UI.box(self,Rect2(875,184,325,410))
	detail_scroll=ScrollContainer.new(); detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(detail_scroll)
	detail=UI.column(detail_scroll,10); detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	# v0.69: equipment rack — shows currently worn items on a 3D figure and lets you remove them.
	var rack_title=UI.label("装备中的外设",16,UI.MINT); detail.add_child(rack_title)
	# 3D figure preview via SubViewport.
	var svc=SubViewportContainer.new(); svc.custom_minimum_size=Vector2(140,180); svc.stretch=true
	detail.add_child(svc)
	var vp=SubViewport.new(); vp.size=Vector2i(140,180); vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; svc.add_child(vp)
	var fig_root=Node3D.new(); vp.add_child(fig_root)
	var fig_cam=Camera3D.new(); fig_cam.position=Vector3(0,0.9,3.2); fig_cam.fov=28; fig_root.add_child(fig_cam)
	var fig_env=Environment.new(); fig_env.background_mode=Environment.BG_COLOR; fig_env.background_color=Color(0.08,0.10,0.13)
	var fig_we=WorldEnvironment.new(); fig_we.environment=fig_env; fig_root.add_child(fig_we)
	var fig_light=DirectionalLight3D.new(); fig_light.position=Vector3(2,3,2); fig_root.add_child(fig_light); fig_light.look_at(Vector3.ZERO)
	_build_figure(fig_root)
	var equipped=state.planet.v2.get("equipped")
	if equipped is Dictionary and not equipped.is_empty():
		for eid in equipped:
			var names={"headlamp":"探照灯头盔","insulated_suit":"隔热绝缘服","power_drill":"电钻"}
			var row=UI.row(detail,8)
			row.add_child(UI.label(names.get(eid,eid),15))
			var rm=UI.button("卸下",func():
				var equipped2=state.planet.v2.get("equipped")
				if equipped2 is Dictionary: equipped2.erase(eid)
				refresh())
			rm.add_theme_font_size_override("font_size",13); row.add_child(rm)
			detail.add_child(row)
	else:
		detail.add_child(UI.paragraph("（未装备任何外设。装备栏会显示头盔、绝缘服、电钻等穿戴效果。）",13,UI.MUTED))

## v0.71: build a blocky 3D figure showing equipped wearables.
func _build_figure(root: Node3D) -> void:
	var skin=Color("d8a878"); var cloth=Color("3a4a5a")
	var mat=StandardMaterial3D.new(); mat.albedo_color=cloth
	var body=MeshInstance3D.new(); var bm=BoxMesh.new(); bm.size=Vector3(0.5,0.7,0.28)
	body.mesh=bm; body.material_override=mat; body.position=Vector3(0,0.45,0); root.add_child(body)
	var head_mat=StandardMaterial3D.new(); head_mat.albedo_color=skin
	var head=MeshInstance3D.new(); var hm=BoxMesh.new(); hm.size=Vector3(0.28,0.3,0.28)
	head.mesh=hm; head.material_override=head_mat; head.position=Vector3(0,1.0,0); root.add_child(head)
	# Legs
	for side in [-1,1]:
		var leg=MeshInstance3D.new(); var lm=BoxMesh.new(); lm.size=Vector3(0.16,0.5,0.18)
		leg.mesh=lm; leg.material_override=mat; leg.position=Vector3(side*0.13,0.0,0); root.add_child(leg)
	# Arms
	for side in [-1,1]:
		var arm=MeshInstance3D.new(); var am=BoxMesh.new(); am.size=Vector3(0.14,0.55,0.16)
		arm.mesh=am; arm.material_override=mat; arm.position=Vector3(side*0.32,0.5,0); root.add_child(arm)
	# Equipped wearables
	var eq=state.planet.v2.get("equipped")
	if eq is Dictionary:
		if eq.has("headlamp"):
			var lamp=MeshInstance3D.new(); var lmesh=BoxMesh.new(); lmesh.size=Vector3(0.24,0.08,0.1)
			lamp.mesh=lmesh; lamp.material_override=StandardMaterial3D.new()
			lamp.material_override.albedo_color=Color("ffd040"); lamp.position=Vector3(0,1.12,0.12); root.add_child(lamp)
		if eq.has("insulated_suit"):
			body.material_override.albedo_color=Color("e8e8f0")
		if eq.has("power_drill"):
			var drill=MeshInstance3D.new(); var dm=BoxMesh.new(); dm.size=Vector3(0.06,0.2,0.06)
			drill.mesh=dm; drill.material_override=StandardMaterial3D.new()
			drill.material_override.albedo_color=Color("88aabb"); drill.position=Vector3(0.42,0.25,0.15); root.add_child(drill)
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
	if not item.action.is_empty():
		var type=str(item.action.type)
		var b=UI.button("拿在手上",func(): use_requested.emit(selected_id,""),true); b.disabled=item.quantity==0; detail.add_child(b)
		var steps="关闭背包后，对准目标按 E 或点使用按钮。"
		if type=="build": steps="拿起 → 对准5米内地面或构件 → 绿色预览时点放置。红色预览会说明原因；每次消耗1块。"
		elif type in ["sample","product"]: steps="先拿起再瞄准使用；水样可浇树苗、种植箱或补充水槽。装到手上不会消耗。"
		elif type=="plant": steps="拿起 → 对准空种植箱 → 点种植。"
		elif type in ["place_rock","fill"]: steps="拿起 → 对准5米内地面或岩壁的一个面 → 点放置，每次放下1格。"
		elif type=="scan": steps="拿起 → 对准岩土、树木或采集点 → 点扫描，读出真实成分。"
		elif type=="dig": steps="拿起 → 对准地面或岩壁 → 连续敲击；硬的岩石需要敲更多下。"
		elif type=="tree_plant": steps="拿起 → 对准近处空地 → 点种植，树苗会慢慢长大。"
		elif type=="strike": steps="瞄准3.2米内的生物，E/F或攻击按钮挥拳；手套也可左键攻击、E查看。"
		detail.add_child(UI.paragraph(steps,15,UI.MINT))
		detail.add_child(UI.paragraph(item.description,15))
		if type in ["sample","product"]: detail.add_child(UI.button("投放当前区域 · 1份",func(): use_requested.emit(selected_id,"deploy")))
		if type=="plant": detail.add_child(UI.button("当前区域播谷物 · 1种",func(): use_requested.emit(selected_id,"region")))
		if type=="plant": detail.add_child(UI.button("改种芦苇 · 1种",func(): use_requested.emit(selected_id,"reed")))
		if type=="feed": detail.add_child(UI.button("送1份到粮仓",func(): use_requested.emit(selected_id,"pantry")))
		if type in ["eat","feed"] and str(item.action.get("resource",""))!="grain": detail.add_child(UI.button("吃一份",func(): use_requested.emit(selected_id,"eat")))
		if type=="build" and state.planet.v2.rules.products.has(item.action.recipe):
			detail.add_child(UI.button("整包搭成围栏",func(): use_requested.emit(selected_id,"deploy")))
	else:
		detail.add_child(UI.paragraph("保留在库存中 · 当前不能直接放置",14,UI.GOLD))
		detail.add_child(UI.paragraph(item.description,15))
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
