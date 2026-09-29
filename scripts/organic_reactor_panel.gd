extends Control
signal dismissed
signal acted(message: String)
signal edit_requested(index: int)
signal campus_requested(tab: String)
signal planet_requested
const UI=preload("res://scripts/ui.gd")
const Flow=preload("res://scripts/organic_synthesis.gd")
var flow=Flow.new()
var state
var reactor_index=0
var reference="urea"
var reference_menu: OptionButton
var molecule_title: Label
var molecule_description: Label
var reactor_menu: OptionButton
var heading: Label
var phase_label: Label
var detail: Label
var stocks: Label
var contents: Label
var requirements: Label
var help: Label
var feedback: Label
var progress: ProgressBar
var progress_caption: Label
var start_button: Button
var buy_button: Button
var harvest_button: Button
var edit_button: Button
var cancel_button: Button
var return_button: Button
var preview
var clock=0.0
var last_phase=""

func setup(model,index: int=-1) -> void:
	state=model
	reactor_index=clampi(index,0,maxi(0,state.reactors.size()-1))
	if index<0:
		for i in range(state.reactors.size()):
			if state.reference_id(state.reactors[i])==reference or flow.installation_reference(state,state.reactors[i])==reference: reactor_index=i; break
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=UI.make_theme()
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	heading=UI.label("反应釜 · 有机合成",30,UI.MINT); heading.position=Vector2(36,25); add_child(heading)
	var sub=UI.paragraph("元素入库 → 博士装炉 → 反应釜合成 → 收获到背包 → 河湾配料",17); sub.position=Vector2(38,73); sub.size=Vector2(1150,32); add_child(sub)
	return_button=UI.button("返回浮岛  ×",func(): dismissed.emit()); return_button.position=Vector2(1220,25); return_button.size=Vector2(184,48); add_child(return_button)
	var left=UI.box(self,Rect2(28,118,700,708)); var col=UI.column(left,14)
	reference_menu=OptionButton.new(); reference_menu.custom_minimum_size.y=44; col.add_child(reference_menu)
	for id in flow.reference_ids(): reference_menu.add_item(flow.rules.references[id].name+" · "+flow.rules.references[id].formula)
	reference_menu.item_selected.connect(func(i): select_reference(str(flow.reference_ids()[i])))
	molecule_title=UI.label("",24,UI.MINT); col.add_child(molecule_title)
	molecule_description=UI.paragraph("",16); col.add_child(molecule_description)
	contents=UI.paragraph("",16,UI.LILAC); col.add_child(contents)
	var box=SubViewportContainer.new(); box.custom_minimum_size=Vector2(650,235); box.stretch=true; col.add_child(box)
	var viewport=SubViewport.new(); viewport.size=Vector2i(650,235); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; box.add_child(viewport)
	preview=preload("res://scripts/organic_reactor_view.gd").new(); viewport.add_child(preview)
	stocks=UI.paragraph("",19,UI.GOLD); col.add_child(stocks)
	col.add_child(UI.paragraph("反应釜完成的分子先留在炉内；收获后才成为可用样品。每罐选一种有机物加水，分装后仍保留物质身份。",16))
	var right=UI.box(self,Rect2(748,118,660,708)); var outer=UI.column(right,12)
	reactor_menu=OptionButton.new(); reactor_menu.fit_to_longest_item=false; reactor_menu.custom_minimum_size=Vector2(0,46); outer.add_child(reactor_menu)
	for r in state.reactors: reactor_menu.add_item("%s · %s · Lv.%d" % [r.id,state.structure_data(r).formula,r.level])
	if not state.reactors.is_empty(): reactor_menu.select(reactor_index)
	reactor_menu.item_selected.connect(func(i): reactor_index=i; feedback.text=""; refresh())
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; outer.add_child(scroll)
	var body=UI.column(scroll,10); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	phase_label=UI.paragraph("",22,UI.MINT); body.add_child(phase_label)
	detail=UI.paragraph("",17); body.add_child(detail)
	progress_caption=UI.paragraph("",14,UI.MUTED); body.add_child(progress_caption)
	progress=ProgressBar.new(); progress.custom_minimum_size.y=18; body.add_child(progress)
	requirements=UI.paragraph("",17,UI.GOLD); body.add_child(requirements)
	buy_button=UI.button("购齐缺少元素",func(): _act("buy")); body.add_child(buy_button)
	start_button=UI.button("提交分子装炉",func(): _act("start"),true); body.add_child(start_button)
	harvest_button=UI.button("收获尿素到背包",func(): _act("harvest"),true); body.add_child(harvest_button)
	edit_button=UI.button("进入原子工作台 · 调节结构",func(): edit_requested.emit(reactor_index)); body.add_child(edit_button)
	cancel_button=UI.button("取消装炉 · 退回预留元素和费用",func(): _act("cancel")); body.add_child(cancel_button)
	help=UI.paragraph("",15,UI.MUTED); body.add_child(help)
	var support=UI.row(body,8)
	support.add_child(UI.button("博士与生产岗位",func(): campus_requested.emit("people")))
	support.add_child(UI.button("小路与博士公寓",func(): campus_requested.emit("build")))
	body.add_child(UI.button("带背包产物前往河湾",func(): planet_requested.emit()))
	feedback=UI.paragraph("",16,UI.GOLD); feedback.position=Vector2(32,845); feedback.size=Vector2(1370,45); add_child(feedback)
	refresh()

func select_reference(id: String) -> void:
	if not flow.rules.references.has(id): return
	reference=id; reference_menu.select(flow.reference_ids().find(id)); feedback.text=""
	refresh()

func _act(action: String) -> void:
	match action:
		"buy": feedback.text=flow.buy_missing(state,reactor_index,reference)
		"start": feedback.text=flow.start(state,reactor_index,reference)
		"harvest": feedback.text=flow.harvest(state,reactor_index,reference)
		"cancel": feedback.text=state.cancel_installation(reactor_index)
	var result=feedback.text
	acted.emit(result); refresh(); feedback.text=result

func refresh() -> void:
	var q=flow.status(state,reactor_index,reference)
	var spec=flow.rules.references[reference]
	molecule_title.text=spec.name+" · "+spec.formula
	molecule_description.text=spec.gameplay.description+"\n复用炉内同种元素，博士装炉后由你调节结构。"
	if q.phase!=last_phase: feedback.text=""; last_phase=q.phase
	for i in range(state.reactors.size()):
		var r=state.reactors[i]
		reactor_menu.set_item_text(i,"%s · %s · Lv.%d" % [r.id,state.structure_data(r).formula,r.level])
	var phases={"choose":"选择反应釜","building":"反应釜建造中","prepare":"① 准备元素与分子结构","installing":"② 博士正在装炉","busy":"等待当前装炉任务","producing":"③ 反应釜合成中","ready":"④ 成品待收获"}
	phase_label.text=phases[q.phase]; detail.text=q.message
	stocks.text="背包%s %d份 · 本炉待收 %d份\n收获后，同一背包可供河湾配料罐取用" % [spec.name,q.stock,q.pending]
	progress.visible=q.phase in ["installing","producing","ready"]; progress.value=float(q.progress)*100
	progress_caption.visible=progress.visible
	progress_caption.text="博士装炉进度" if q.phase=="installing" else "下一份合成进度 · 已完成%d份待收" % q.pending
	var needs=[]
	for symbol in q.required: needs.append("%s ×%d（库存%d）" % [symbol,q.required[symbol],state.element_inventory.get(symbol,0)])
	requirements.text="需新增："+("\n".join(needs) if not needs.is_empty() else "现有炉中元素可复用")
	requirements.visible=q.phase=="prepare"
	buy_button.visible=q.phase=="prepare" and not q.missing.is_empty(); buy_button.disabled=not q.can_buy; buy_button.text="购齐缺少元素 · %d金币" % q.element_cost
	start_button.visible=q.phase=="prepare"; start_button.disabled=not q.start_ready; start_button.text="提交分子装炉 · %d金币" % q.fee
	harvest_button.visible=q.phase in ["producing","ready"]; harvest_button.disabled=q.pending<=0; harvest_button.text="收获%s到背包 · %d份" % [spec.name,q.pending]
	edit_button.visible=q.phase in ["producing","ready"]; cancel_button.visible=q.phase in ["installing","busy"]
	help.text="装炉只预留一次元素和本等级编辑费。旧炉继续工作，旧批次保留；取消时原数退回。"
	if q.phase in ["producing","ready"]:
		help.text="几何匹配 %.0f%% · 下一份约 %d秒\n达到容量后暂停；博士收集需公寓泡面/可乐，手动收获始终可用。" % [q.quality*100,q.eta]
	elif q.phase=="prepare" and q.valid: help.text+="\n"+flow.logistics(state,reactor_index)
	if q.valid:
		var r=state.reactors[reactor_index]
		contents.text="%s 当前炉内：%s · %s" % [r.id,state.structure_data(r).formula,state.structure_data(r).name]
		preview.sync(state,r,q.phase)

func set_return_label(text: String) -> void:
	return_button.text=text+"  ×"

func _process(dt: float) -> void:
	clock+=dt
	if clock>=0.5: clock=0; refresh()

func handle_back() -> bool:
	dismissed.emit(); return true
