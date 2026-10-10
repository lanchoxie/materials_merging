extends Control
## v0.34 星锻岛 screen: the floating island diorama on the left, and on the right the unlock card
## (before it opens) or four tabs: 甲板 (plots and buildings), 生产 (factories), 交易所 (sell and
## fuse 工业信用) and 装备 (the drill bit for the planet). All rules live in industry.gd.
signal dismissed
signal acted(message: String)
const UI=preload("res://scripts/ui.gd")
const View=preload("res://scripts/starforge_view.gd")
const Model=preload("res://scripts/material_model.gd")
var state
var view
var header: Label
var body: VBoxContainer
var scroll: ScrollContainer
var status: Label
var tabs: Dictionary={}
var section="deck"
var fingerprint=""
var clock=0.0
var bars: Array=[]
var laws_open: Dictionary={}
var close_button: Button   # recipe id -> showing its property laws

func setup(model) -> void:
	state=model
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); theme=UI.make_theme()
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var title=UI.label("星锻岛 · 浮岛 Ⅱ",30,UI.MINT); title.position=Vector2(28,22); add_child(title)
	header=UI.label("",17,UI.GOLD); header.position=Vector2(300,34); header.size=Vector2(950,30); header.clip_text=true; add_child(header)
	# v0.37.1: the button used to only emit `dismissed`, leaving this full-screen panel on top with no way back.
	close_button=UI.button("返回浮岛 Ⅰ",_close); close_button.position=Vector2(1268,22); close_button.size=Vector2(144,48); add_child(close_button)
	var frame=UI.box(self,Rect2(28,96,760,740))
	var container=SubViewportContainer.new(); container.stretch=true; container.custom_minimum_size=Vector2(736,716); frame.add_child(container)
	var viewport=SubViewport.new(); viewport.own_world_3d=true; viewport.size=Vector2i(736,716); viewport.msaa_3d=Viewport.MSAA_2X; container.add_child(viewport)
	view=View.new(); viewport.add_child(view)
	var right=UI.box(self,Rect2(806,96,606,740)); var col=UI.column(right,10)
	var nav=UI.row(col,6)
	for entry in [["deck","甲板"],["factory","生产"],["staff","人员"],["market","交易所"],["gear","装备"]]:
		var b=UI.button(entry[1],_tab.bind(entry[0])); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; nav.add_child(b); tabs[entry[0]]=b
	scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; col.add_child(scroll)
	body=UI.column(scroll,10); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status=UI.paragraph("",16,UI.GOLD); status.position=Vector2(32,848); status.size=Vector2(1370,40); add_child(status)
	_redraw()

func set_return_label(text: String) -> void:
	close_button.text=text

func handle_back() -> bool:
	_close(); return true

func _close() -> void:
	dismissed.emit(); queue_free()

## A button row that wraps instead of widening the right-hand panel past the screen edge.
func _flow(parent: Node) -> HFlowContainer:
	var f=HFlowContainer.new(); f.add_theme_constant_override("h_separation",6); f.add_theme_constant_override("v_separation",6); parent.add_child(f); return f

## Long one-line labels stacked in a column wrap too (labels in rows keep their size).
func _wrap_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label and node is VBoxContainer and child.autowrap_mode==TextServer.AUTOWRAP_OFF:
			child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_wrap_labels(child)

func _tab(id: String) -> void:
	section=id; _redraw()

func _act(message: String) -> void:
	status.text=message; acted.emit(message); _redraw()

func _fingerprint() -> String:
	var ind=state.industry
	return JSON.stringify([section,ind.unlocked,ind.rank(),ind.credits,ind.plots,ind.buildings.keys(),ind.buildings.values().map(func(b): return [b.kind,b.level,b.jobs.size(),b.get("repeat","")]),ind.items,ind.lots.hash(),ind.bit,int(state.coins)/50,state.materials,state.element_inventory.hash(),state.storage.batches.size(),
		ind.staff,ind.furnished,ind.contracts.map(func(c): return c.id),ind.airship.is_empty(),ind.arrears>0,ind.candidates(state).map(func(c): return [c.ready,c.delayed]),state.campus.people.size()])

func _process(dt: float) -> void:
	if state==null: return
	clock+=dt
	for row in bars:
		if is_instance_valid(row[0]): row[0].value=row[1].call()
	if clock<0.5: return
	clock=0.0
	if _fingerprint()!=fingerprint: _redraw()
	if not state.industry_notice.is_empty(): status.text=state.industry_notice; state.industry_notice=""

func _card(title: String,color: Color=UI.MINT) -> VBoxContainer:
	var p=PanelContainer.new(); body.add_child(p); var c=UI.column(p,6); c.add_child(UI.label(title,19,color)); return c

func _redraw() -> void:
	fingerprint=_fingerprint(); bars=[]
	var ind=state.industry; view.sync(ind)
	var r=ind.rank_of(ind.xp)
	header.text="岛主 Lv.%d · %d/%d XP   ·   工业信用 %d   ·   金币 %d   ·   电网 %d/%d   ·   员工 %d/%d床" % [r.rank,r.into,r.need,ind.credits,int(state.coins),ind.power_use(),ind.power_cap(),ind.staff.size(),ind.beds()]
	for key in tabs:
		tabs[key].modulate=UI.MINT if key==section else Color.WHITE
		tabs[key].disabled=not ind.unlocked
	UI.clear(body)
	if not ind.unlocked: _unlock(); return
	match section:
		"deck": _deck()
		"factory": _factories()
		"staff": _staff()
		"market": _market()
		"gear": _gear()
	_wrap_labels(body)

func _unlock() -> void:
	var ind=state.industry
	var card=_card("开放星锻岛",UI.GOLD)
	card.add_child(UI.paragraph("第二座浮岛是工业岛：把精炼厂的元素、反应釜的分子熔炼、聚合成合金和塑料，卖给星港买家，或做成星球上用的装备。\n只有你在原子工坊里真正做出过某种化合物（记入物质索引），对应的配方才会解锁。",15))
	for row in ind.unlock_rows(state):
		card.add_child(UI.label(("✓ " if row.ok else "✗ ")+"%s · %d / %d" % [row.label,row.value,row.need],17,UI.MINT if row.ok else UI.TEXT))
		if not row.ok: card.add_child(UI.paragraph("　"+row.hint,13))
	var go=UI.button("开放星锻岛 · 架起第二座光桥",func(): _act(ind.unlock(state)),true)
	go.disabled=not ind.unlock_rows(state).all(func(x): return x.ok); card.add_child(go)
	var xp=_card("岛主等级怎么涨")
	var w: Dictionary=ind.rules().rank.legacy
	xp.add_child(UI.paragraph("旧进度已经按一次性折算成经验，之后继续累积：\n领取里程碑 +%d · 图鉴星 +%d · 物质索引新发现 +%d · 反应釜每升一级 +%d · 开拓一块地 +%d · 精炼厂每级 +%d · 制造台每件 +%d\n星锻岛开放后：建厂、生产、卖货都会加经验。" % [w.milestone,w.codex_star,w.index_find,w.reactor_level,w.plot,w.refinery_level,w.fabricated],14))

func _deck() -> void:
	var ind=state.industry; var R=ind.rules()
	var credit=_card("工业信用 · 星锻岛的通用货币",UI.GOLD)
	credit.add_child(UI.paragraph("旧建材可以熔合成工业信用：星砂、晶露、合金片各1份 → %d 信用（单向）。现有：星砂 %d · 晶露 %d · 合金片 %d" % [int(R.credits.fuse.credits),state.materials[0],state.materials[1],state.materials[2]],14))
	var row=UI.row(credit,6)
	for n in [1,10]: row.add_child(UI.button("熔合 ×%d" % n,func(): _act(ind.fuse(state,n))))
	var c=ind.plot_cost()
	var expand=_card("甲板 · %d / %d 块地" % [ind.plots,int(R.plots.max)])
	var b=UI.button("扩建一块甲板 · %d金币 + %d信用" % [c.coins,c.credits],func(): _act(ind.buy_plot(state)))
	b.disabled=ind.plots>=int(R.plots.max); expand.add_child(b)
	expand.add_child(UI.paragraph("电网 %d/%d · 每种工厂许可证 %d 张（岛主每升%d级多一张）" % [ind.power_use(),ind.power_cap(),ind.licences(""),int(R.licences.per_ranks)],13))
	for i in range(ind.plots):
		var plot=_card("%d 号地" % (i+1))
		var mouse=func(): view.selected=i
		plot.mouse_entered.connect(mouse)
		if ind.buildings.has(str(i)):
			var bld: Dictionary=ind.buildings[str(i)]; var spec: Dictionary=R.buildings[bld.kind]
			plot.add_child(UI.label("%s Lv.%d" % [spec.name,int(bld.level)],17,Color(str(spec.accent))))
			plot.add_child(UI.paragraph(str(spec.story),13))
			if bld.kind=="staff_housing":
				var cap=ind.housing_capacity(bld); var here=ind.staff.filter(func(x): return int(x.home)==i)
				plot.add_child(UI.paragraph("住户 %d/%d · 家具 %d/%d（舒适度让员工加成最多 +%d%%）" % [here.size(),cap,int(ind.furnished.get(str(i),0)),cap,int(float(ind.rules().staff.comfort_bonus)*100)],13))
				var furn=_flow(plot)
				for id in ind.rules().items:
					if ind.rules().items[id].has("furniture") and int(ind.items.get(id,0))>0:
						furn.add_child(UI.button("摆%s" % ind.rules().items[id].name,func(): _act(ind.furnish(i,id))))
			if int(bld.level)<int(spec.max_level):
				plot.add_child(UI.button("升级 · %d金币" % int(spec.upgrade_costs[int(bld.level)-1]),func(): _act(ind.upgrade(state,i))))
			# v0.38: a factory control board automates the line.
			if bld.kind in ind.FACTORIES:
				if bld.get("board",false): plot.add_child(UI.label("⚙ 已装工厂控制板 · 速度 +%d%%" % int(float(R.automation.speed)*100),14,UI.MINT))
				elif int(ind.items.get("control_board",0))>0: plot.add_child(UI.button("装控制板 · 速度 +%d%%（仓库 %d 块）" % [int(float(R.automation.speed)*100),int(ind.items.control_board)],func(): _act(ind.install_board(i))))
		else:
			# v0.37: eight kinds of building — the build buttons wrap instead of widening the panel.
			var choices=HFlowContainer.new(); choices.add_theme_constant_override("h_separation",6); choices.add_theme_constant_override("v_separation",6); plot.add_child(choices)
			for kind in R.buildings:
				var spec: Dictionary=R.buildings[kind]; var err=ind.build_error(state,i,kind)
				var btn=UI.button("建%s\n%d金币+%d信用" % [spec.name,int(spec.cost.coins),int(spec.cost.credits)],func(): view.selected=i; _act(ind.build(state,i,kind)))
				btn.tooltip_text=err; btn.disabled=not err.is_empty(); btn.add_theme_font_size_override("font_size",13); choices.add_child(btn)

func _factories() -> void:
	var ind=state.industry; var R=ind.rules(); var any=false
	for key in ind.buildings:
		var bld: Dictionary=ind.buildings[key]
		if bld.kind=="trade_hub": continue
		any=true; var plot=int(key); var spec: Dictionary=R.buildings[bld.kind]
		var looping=str(bld.get("repeat",""))
		var card=_card("%s Lv.%d · %d 号地 · 队列 %d/%d%s" % [spec.name,int(bld.level),plot+1,bld.jobs.size(),ind.queue_limit(bld),"  ⟳ "+str(R.recipes[looping].name) if looping!="" else ""],Color(str(spec.accent)))
		for job in bld.jobs:
			var r: Dictionary=R.recipes[job.recipe]
			card.add_child(UI.label("▶ %s" % r.name,15,UI.TEXT))
			var bar=ProgressBar.new(); bar.max_value=1.0; bar.show_percentage=false; bar.custom_minimum_size=Vector2(0,8); card.add_child(bar)
			var total=ind.job_seconds(job)
			bars.append([bar,func(): return 1.0-float(job.left)/total])
		for id in R.recipes:
			var r: Dictionary=R.recipes[id]
			if r.building!=bld.kind: continue
			var q=ind.quote(state,plot,id)
			var line=VBoxContainer.new(); line.add_theme_constant_override("separation",2); card.add_child(line)
			var ins=[]; var amounts=ind.inputs(id)
			for k in amounts: ins.append("%s×%d" % [ind.input_name(state,k),int(amounts[k])])
			var outs=[]
			for k in r.outputs: outs.append("%s×%d" % [R.items[k].name,int(r.outputs[k])])
			line.add_child(UI.label("%s%s" % ["🔒 " if q.get("locked",false) else "",r.name],16,UI.MUTED if q.get("locked",false) else UI.MINT))
			line.add_child(UI.paragraph("%s → %s\n%s · %s" % ["＋".join(ins),"＋".join(outs),r.method,r.equation],12))
			if r.has("model") and not q.get("locked",false): _knobs(line,id,str(r.model))
			var go=UI.button("投料" if q.ready else str(q.message),func(): _act(ind.start(state,plot,id)))
			go.disabled=not q.ready; go.add_theme_font_size_override("font_size",13); line.add_child(go)
			if not q.get("locked",false):
				# v0.37.1: fill the queue in one tap, or loop the recipe while inputs last (also offline).
				var more=_flow(line); var room=ind.queue_room(plot)
				if q.ready and room>=2:
					var fill=UI.button("排满 ×%d" % room,func(): _act(ind.start_many(state,plot,id,room)))
					fill.add_theme_font_size_override("font_size",13); more.add_child(fill)
				var loop=CheckButton.new(); loop.text="循环生产"; loop.button_pressed=str(bld.get("repeat",""))==id
				loop.tooltip_text="原料够就自动投料，离线也继续"; loop.add_theme_font_size_override("font_size",13)
				loop.toggled.connect(func(on: bool): _act(ind.set_repeat(plot,id if on else "")))
				more.add_child(loop)
	if not any:
		var c=_card("还没有工厂")
		c.add_child(UI.paragraph("在「甲板」页选一块地，建冶金工厂或高分子工厂。",15))

## v0.37 material model: one slider per knob and a live prediction of the lot's properties.
func _knobs(line: VBoxContainer,recipe_id: String,fam: String) -> void:
	var ind=state.industry; var f=Model.family(fam)
	var predict=UI.paragraph("",13,UI.GOLD)
	var refresh=func():
		var k=ind.recipe_knobs(recipe_id)
		for knob in f.get("inherit",{}):
			var mean=ind._take_lots("item:"+str(f.inherit[knob]),int(ind.inputs(recipe_id).get("item:"+str(f.inherit[knob]),1)),true)
			if mean.has(knob): k[knob]=float(mean[knob])
		predict.text="预测：%s\n%s" % [Model.describe(fam,k,1.0,false),"（%s）" % Model.knob_text(fam,k)]
		var shown_p=Model.props(fam,k)
		if shown_p.has("wavelength"): predict.add_theme_color_override("font_color",Model.wavelength_color(float(shown_p.wavelength)).lerp(Color.WHITE,0.25))
	for knob in f.get("knobs",{}):
		var spec: Dictionary=f.knobs[knob]; var log_scale=bool(spec.get("log",false))
		var row=UI.row(line,6)
		row.add_child(UI.label(str(spec.label),13,UI.TEXT))
		var slider=HSlider.new(); slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL; slider.custom_minimum_size=Vector2(220,32)
		var lo=float(spec.min); var hi=float(spec.max); var now=float(ind.recipe_knobs(recipe_id)[knob])
		if log_scale: slider.min_value=log(lo); slider.max_value=log(hi); slider.step=0.01; slider.value=log(now)
		else: slider.min_value=lo; slider.max_value=hi; slider.step=float(spec.step); slider.value=now
		var shown=UI.label("",13,UI.MINT); shown.custom_minimum_size=Vector2(86,0)
		var show_value=func(v: float): shown.text="%s %s" % [String.num(v,2) if v<10.0 else str(int(round(v))),str(spec.unit)]
		show_value.call(now)
		slider.value_changed.connect(func(x: float):
			var v=exp(x) if log_scale else x
			ind.set_knob(recipe_id,knob,v); show_value.call(v); refresh.call())
		row.add_child(slider); row.add_child(shown)
	refresh.call(); line.add_child(predict)
	var open=bool(laws_open.get(recipe_id,false))
	var toggle=UI.button("收起规律" if open else "规律（为什么是这个数）",func(): laws_open[recipe_id]=not open; _redraw())
	toggle.add_theme_font_size_override("font_size",12); line.add_child(toggle)
	if open:
		var src: Dictionary={}
		for s in state.industry.rules().sources: src[str(s.id)]=str(s.cite)
		for law in f.get("laws",[]):
			line.add_child(UI.paragraph("· %s（%s）%s" % [law.text,law.tag,"\n　来源："+src.get(str(law.source),"") if src.has(str(law.source)) else ""],12,UI.LILAC))

func _staff() -> void:
	var ind=state.industry; var R=ind.rules()
	var pay=_card("星锻岛员工 · 日薪合计 %d 金币" % ind.daily_wages(),UI.GOLD)
	pay.add_child(UI.paragraph("员工从浮岛 Ⅰ 晋升而来，住在星锻公寓，按在岛时间计薪（每游戏日结算）。欠薪时员工加成暂停。",14))
	if ind.arrears>0: pay.add_child(UI.button("补发欠薪 %.0f 金币" % ind.arrears,func(): _act(ind.pay_arrears(state))))
	for s in ind.staff:
		var role: Dictionary=R.staff.roles[s.role]
		var card=_card("%s · %s" % [s.name,role.name],UI.MINT)
		card.add_child(UI.paragraph(str(role.story),13))
		var where="休息中" if int(s.factory)<0 else "%d号地 %s" % [int(s.factory)+1,R.buildings[ind.buildings[str(int(s.factory))].kind].name]
		card.add_child(UI.label("住 %d号地公寓 · 工作：%s · 日薪 %d" % [int(s.home)+1,where,int(role.daily_pay)],14,UI.TEXT))
		var row=_flow(card)
		for key in ind.buildings:
			if ind.buildings[key].kind not in ind.FACTORIES: continue
			var b=UI.button("派到%d号%s" % [int(key)+1,R.buildings[ind.buildings[key].kind].name],func(): _act(ind.assign(int(s.id),int(key))))
			b.disabled=int(s.factory)==int(key); b.add_theme_font_size_override("font_size",13); row.add_child(b)
	var list=_card("待晋升 · 来自浮岛 Ⅰ 科研小镇")
	var rows=ind.candidates(state)
	if rows.is_empty(): list.add_child(UI.paragraph("浮岛 Ⅰ 还没有工程师或博士生。",14))
	for row in rows:
		list.add_child(UI.label("%s（%s → %s）· %.1f / %.1f 学年%s" % [row.name,row.from,row.to,row.years,row.need,"  ·  延毕：%s" % row.reason if row.delayed else ""],14,UI.MINT if row.ready else UI.TEXT))
		var error=ind.promote_error(state,int(row.id))
		if row.ready:
			var b=UI.button("批准晋升" if error.is_empty() else error,func(): _act(state.campus_promote(int(row.id))))
			b.disabled=not error.is_empty(); list.add_child(b)

func _market() -> void:
	var ind=state.industry; var R=ind.rules()
	var hub=_card("星港交易所",UI.GOLD)
	if ind.count("trade_hub")<1:
		hub.add_child(UI.paragraph("先在「甲板」页建一座星港交易所，货运飞艇才会来收货。",15)); return
	_contracts()
	hub.add_child(UI.paragraph("买家：轨道空间站 · 城市百货。同一件货卖得越多出价越低（最低 %d%%），约 %d 分钟恢复一半。元素和原始分子不在这里卖。累计卖出 %d 金币。" % [int(float(R.market.floor)*100),int(R.market.half_life)/60,ind.earned],14))
	var any=false
	for id in R.items:
		var n=int(ind.items.get(id,0))
		if n<1: continue
		any=true; var it: Dictionary=R.items[id]
		if ind.modelled(id)!="": _lot_rows(id); continue
		var row=_card("%s × %d" % [it.name,n])
		row.add_child(UI.paragraph("当前出价 %d 金币（基础 %d · 需求 %d%%）" % [ind.price(id),int(it.sell),int(100*(1.0-float(ind.saturation.get(id,0.0))))],13))
		var h=_flow(row)
		for k in [1,5]:
			var b=UI.button("卖 %d" % k,func(): _act(ind.sell(state,id,k))); b.disabled=n-(1 if ind.bit==id else 0)<k; h.add_child(b)
		if it.has("furniture"): h.add_child(UI.button("送回浮岛 Ⅰ 摆放",func(): _act(ind.ship_home(state,id))))
	if not any: hub.add_child(UI.paragraph("仓库里还没有工业品。去「生产」页投料吧。",15))

## v0.37: a modelled item lists its lots, each with its properties, price and a test-bench button.
func _lot_rows(id: String) -> void:
	var ind=state.industry; var it: Dictionary=ind.rules().items[id]; var fam=ind.modelled(id)
	var list: Array=ind.lots_of(id)
	var card=_card("%s × %d · %d 个批次" % [it.name,int(ind.items.get(id,0)),list.size()])
	for i in range(list.size()):
		var lot: Dictionary=list[i]
		var lot_p: Dictionary=ind.lot_props(id,lot)
		var head_color=Model.wavelength_color(float(lot_p.wavelength)) if lot_p.has("wavelength") else (UI.MINT if lot.m else UI.TEXT)
		card.add_child(UI.label("%s批次 %d × %d · %s%s" % ["■ " if lot_p.has("wavelength") else "",i+1,int(lot.n),Model.knob_text(fam,lot.k),"  · 已检测 ✓" if lot.m else ""],14,head_color))
		card.add_child(UI.paragraph("%s · 出价 %d 金币" % [Model.describe(fam,lot.k,float(lot.q),bool(lot.m)),ind.lot_price(id,i)],13))
		var h=_flow(card); var spare=ind.lot_spare(id,i)
		var one=UI.button("卖 1",func(): _act(ind.sell(state,id,1,i))); one.disabled=spare<1; h.add_child(one)
		if spare>1: h.add_child(UI.button("全卖 %d" % spare,func(): _act(ind.sell(state,id,spare,i))))
		if not lot.m:
			var err=ind.measure_error(state,id,i)
			var m=UI.button("送检 · %d金币" % int(Model.rules().measure.coins) if err.is_empty() else err,func(): _act(ind.measure(state,id,i)))
			m.disabled=not err.is_empty(); m.add_theme_font_size_override("font_size",13); h.add_child(m)

func _contracts() -> void:
	var ind=state.industry
	var board=_card("合同板 · %d分钟后换一批" % int(ceil(ind.board_left/60.0)),UI.GOLD)
	if ind.airship.is_empty(): board.add_child(UI.paragraph("货运飞艇在港，一次运一份合同。合同报酬比直接卖高，还给工业信用；不做也没有惩罚。",14))
	else:
		var trip=ind.airship
		board.add_child(UI.label("飞艇在途 → %s · %d秒后结算" % [trip.contract.buyer,int(ceil(float(trip.left)))],15,UI.MINT))
		var bar=ProgressBar.new(); bar.max_value=1.0; bar.show_percentage=false; bar.custom_minimum_size=Vector2(0,8); board.add_child(bar)
		var total=float(ind.rules().contracts.trip)
		bars.append([bar,func(): return 1.0-float(ind.airship.get("left",0.0))/total])
	for c in ind.contracts:
		var lines=[]
		for item in c.lines: lines.append("%s %d/%d" % [ind.rules().items[item].name,int(ind.items.get(item,0)),int(c.lines[item])])
		board.add_child(UI.label("%s · %s" % [c.buyer,"，".join(lines)],15,UI.TEXT))
		board.add_child(UI.paragraph("%s　报酬 %d金币 + %d信用 + %dXP" % [c.story,int(c.coins),int(c.credits),int(c.xp)],13))
		var error=ind.deliver_error(int(c.id))
		var b=UI.button("装船交付" if error.is_empty() else error,func(): _act(ind.deliver(int(c.id))))
		b.disabled=not error.is_empty(); b.add_theme_font_size_override("font_size",13); board.add_child(b)
	board.add_child(UI.button("换一批合同 · %d信用" % int(ind.rules().contracts.reroll_credits),func(): _act(ind.reroll(state))))

func _gear() -> void:
	var ind=state.industry; var R=ind.rules()
	var card=_card("星球装备")
	card.add_child(UI.paragraph("工业钻头装上后，星球上的采掘镐用它的硬度：钻头比岩石硬就挖得快。制造台做的晶体镐更硬时，仍然用更硬的那把。\n现在星球采掘：%s · %.2f GPa" % [state.planet.v2.nature.pick_name,float(state.planet.v2.nature.pick_hv)],14))
	# v0.37: solar panels feed the island grid; superphosphate goes down to Earth's fields.
	var sun=_card("岛心电网 · 太阳能板 %d/%d" % [ind.solar.size(),int(R.solar.max)],Color("8fd3ff"))
	sun.add_child(UI.paragraph("硅材料厂做的太阳能板装在岛心：每 20%% 的效率给电网 +1。现在太阳能 +%d，电网 %d/%d。" % [ind.solar_power(),ind.power_use(),ind.power_cap()],14))
	var panel_btn=UI.button("装一块（自动挑效率最高的批次）· 仓库 %d" % int(ind.items.get("solar_panel",0)),func(): _act(ind.install_solar()))
	panel_btn.disabled=int(ind.items.get("solar_panel",0))<1 or ind.solar.size()>=int(R.solar.max); sun.add_child(panel_btn)
	var farm=_card("送往地球 · 磷肥",Color("cfd8a0"))
	farm.add_child(UI.paragraph("无机材料厂做的过磷酸钙磷肥：一份让地球上每块有作物的地区养分 +%d%%。仓库 %d 份。" % [int(float(R.fertilizer.nutrients)*100),int(ind.items.get("fertilizer",0))],14))
	var fert=UI.button("施一份磷肥",func(): _act(state.fertilize()))
	fert.disabled=int(ind.items.get("fertilizer",0))<1; farm.add_child(fert)
	# v0.40: battery storage on the island grid.
	var cells=_card("储能电池 · %d/%d 组 · 电网 +%d" % [ind.storage.size(),int(R.storage.max),ind.storage_power()],Color("b6ff5c"))
	cells.add_child(UI.paragraph("铅酸蓄电池 +1、锂电池包 +2（游戏数值）。接入后不能再拆。",13))
	var hooks=_flow(cells)
	for id in ["lead_acid","battery_pack"]:
		var spare=int(ind.items.get(id,0))-ind.reserved(id)
		var b=UI.button("接入%s（仓库 %d）" % [R.items[id].name,spare],func(): _act(ind.install_storage(id)))
		b.disabled=spare<1 or ind.storage.size()>=int(R.storage.max); hooks.add_child(b)
	# v0.41: the planet rover.
	for id in R.items:
		if not R.items[id].get("vehicle",false) or int(ind.items.get(id,0))<1: continue
		var out=ind.vehicle==id; ind.update_rover()
		var car=_card("%s × %d%s" % [R.items[id].name,int(ind.items[id]),"（在地球上）" if out else ""],Color("ffcf5c"))
		var best=ind.best_lot(id)
		if best>=0:
			var lot: Dictionary=ind.lots[id][best]
			car.add_child(UI.paragraph("%s\n%s" % [Model.knob_text(ind.modelled(id),lot.k),Model.describe(ind.modelled(id),lot.k,float(lot.q),bool(lot.m))],13))
		if out:
			car.add_child(UI.label("电量 %.0f / %.0f Wh · 续航 %.1f km · 回到浮岛自动充电" % [float(ind.rover_state.charge),float(ind.rover_state.cap),float(ind.rover_state.charge)/maxf(1.0,float(ind.rover_state.wh_per_km))],14,UI.MINT))
			var bar=ProgressBar.new(); bar.max_value=1.0; bar.show_percentage=false; bar.custom_minimum_size=Vector2(0,8); car.add_child(bar)
			bars.append([bar,func(): return float(ind.rover_state.charge)/maxf(1.0,float(ind.rover_state.cap))])
		car.add_child(UI.paragraph("地球第一人称：走到车旁 E 上车，WASD/摇杆驾驶，Shift 加速，空格手刹，E 下车。",13))
		car.add_child(UI.button("收回越野车" if out else "派往地球",func(): _act(ind.deploy_rover("" if out else id)); state.sync_gear()))
	# v0.40: the cordless drill.
	for id in R.items:
		if not R.items[id].get("drill",false) or int(ind.items.get(id,0))<1: continue
		var on=ind.drill==id; ind.update_drill()
		var drill_card=_card("%s × %d%s" % [R.items[id].name,int(ind.items[id]),"（已装备）" if on else ""],Color("f2b134"))
		var best=ind.best_lot(id)
		if best>=0:
			var lot: Dictionary=ind.lots[id][best]
			drill_card.add_child(UI.paragraph("最好的一把：%s\n%s" % [Model.knob_text(ind.modelled(id),lot.k),Model.describe(ind.modelled(id),lot.k,float(lot.q),bool(lot.m))],13))
		if on:
			drill_card.add_child(UI.label("电量 %.0f / %.0f Wh · 回到浮岛自动充电" % [float(ind.drill_state.charge),float(ind.drill_state.cap)],14,UI.MINT))
			var bar=ProgressBar.new(); bar.max_value=1.0; bar.show_percentage=false; bar.custom_minimum_size=Vector2(0,8); drill_card.add_child(bar)
			bars.append([bar,func(): return float(ind.drill_state.charge)/maxf(1.0,float(ind.drill_state.cap))])
		drill_card.add_child(UI.button("收起电钻" if on else "装备到星球（采掘敲击次数减少）",func(): _act(ind.equip_drill("" if on else id)); state.sync_gear()))
	for id in R.items:
		if not R.items[id].has("suit") or int(ind.items.get(id,0))<1: continue
		var worn=ind.suit==id
		var suit_card=_card("%s × %d%s" % [R.items[id].name,int(ind.items[id]),"（已穿上）" if worn else ""],Color("9fc7ff"))
		suit_card.add_child(UI.paragraph(str(R.items[id].suit.note)+"\n冰河期和北方冻原里，体感低于 0 °C 会持续掉血。",13))
		suit_card.add_child(UI.button("脱下" if worn else "穿上（星球第一人称）",func(): _act(ind.equip_suit("" if worn else id)); state.sync_gear()))
	for id in R.items:
		if not R.items[id].get("lamp",false) or int(ind.items.get(id,0))<1: continue
		var on=ind.lamp==id; var best=ind.best_lot(id)
		var lamp_card=_card("%s × %d%s" % [R.items[id].name,int(ind.items[id]),"（已戴上）" if on else ""],Color("ffe08a"))
		if best>=0:
			var lot: Dictionary=ind.lots[id][best]; var p=ind.lot_props(id,lot)
			lamp_card.add_child(UI.label("■ %s" % Model.value_text("wavelength",float(p.wavelength)),16,Model.wavelength_color(float(p.wavelength))))
			lamp_card.add_child(UI.paragraph("最好的一批：%s\n%s\n星球上夜里、暴风雨天和地下洞穴里自动亮起，光的颜色就是 LED 的发光波长。" % [Model.knob_text(ind.modelled(id),lot.k),Model.describe(ind.modelled(id),lot.k,float(lot.q),bool(lot.m))],13))
		lamp_card.add_child(UI.button("收起头灯" if on else "戴上（星球第一人称）",func(): _act(ind.equip_lamp("" if on else id))))
	for id in R.items:
		var it: Dictionary=R.items[id]
		if not it.has("gear"): continue
		var row=_card("%s × %d%s" % [it.name,int(ind.items.get(id,0)),"（已装备）" if ind.bit==id else ""])
		if ind.modelled(id)!="" and ind.best_lot(id)>=0:
			var lot: Dictionary=ind.lots[id][ind.best_lot(id)]
			var head="刃口硬度 %.2f GPa（已检测）" % ind.gear_hv(id) if lot.m else "刃口硬度约 %.2f GPa（未检测：送检后显示实测值）" % float(Model.props(ind.modelled(id),lot.k).edge)
			row.add_child(UI.paragraph("%s\n最好的一批：%s\n%s\n%s" % [head,Model.knob_text(ind.modelled(id),lot.k),Model.describe(ind.modelled(id),lot.k,float(lot.q),bool(lot.m)),it.gear.note],13))
		else: row.add_child(UI.paragraph("硬度 %.1f GPa · %s" % [float(it.gear.hv),it.gear.note],13))
		var b=UI.button("卸下" if ind.bit==id else "装备到星球",func(): _act(ind.equip("" if ind.bit==id else id)); state.sync_gear(); _redraw())
		b.disabled=int(ind.items.get(id,0))<1 and ind.bit!=id; row.add_child(b)
