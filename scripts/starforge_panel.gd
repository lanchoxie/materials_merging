extends Control
## v0.34 星锻岛 screen: the floating island diorama on the left, and on the right the unlock card
## (before it opens) or four tabs: 甲板 (plots and buildings), 生产 (factories), 交易所 (sell and
## fuse 工业信用) and 装备 (the drill bit for the planet). All rules live in industry.gd.
signal dismissed
signal acted(message: String)
const UI=preload("res://scripts/ui.gd")
const View=preload("res://scripts/starforge_view.gd")
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

func setup(model) -> void:
	state=model
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); theme=UI.make_theme()
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var title=UI.label("星锻岛 · 浮岛 Ⅱ",30,UI.MINT); title.position=Vector2(28,22); add_child(title)
	header=UI.label("",17,UI.GOLD); header.position=Vector2(300,34); add_child(header)
	var close=UI.button("返回浮岛 Ⅰ",func(): dismissed.emit()); close.position=Vector2(1268,22); close.size=Vector2(144,48); add_child(close)
	var frame=UI.box(self,Rect2(28,96,760,740))
	var container=SubViewportContainer.new(); container.stretch=true; container.custom_minimum_size=Vector2(736,716); frame.add_child(container)
	var viewport=SubViewport.new(); viewport.own_world_3d=true; viewport.size=Vector2i(736,716); viewport.msaa_3d=Viewport.MSAA_2X; container.add_child(viewport)
	view=View.new(); viewport.add_child(view)
	var right=UI.box(self,Rect2(806,96,606,740)); var col=UI.column(right,10)
	var nav=UI.row(col,6)
	for entry in [["deck","甲板"],["factory","生产"],["market","交易所"],["gear","装备"]]:
		var b=UI.button(entry[1],_tab.bind(entry[0])); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; nav.add_child(b); tabs[entry[0]]=b
	scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; col.add_child(scroll)
	body=UI.column(scroll,10); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status=UI.paragraph("",16,UI.GOLD); status.position=Vector2(32,848); status.size=Vector2(1370,40); add_child(status)
	_redraw()

func _tab(id: String) -> void:
	section=id; _redraw()

func _act(message: String) -> void:
	status.text=message; acted.emit(message); _redraw()

func _fingerprint() -> String:
	var ind=state.industry
	return JSON.stringify([section,ind.unlocked,ind.rank(),ind.credits,ind.plots,ind.buildings.keys(),ind.buildings.values().map(func(b): return [b.kind,b.level,b.jobs.size()]),ind.items,ind.bit,int(state.coins)/50,state.materials,state.element_inventory.hash(),state.storage.batches.size()])

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
	header.text="岛主 Lv.%d · %d/%d XP   ·   工业信用 %d   ·   金币 %d   ·   电网 %d/%d" % [r.rank,r.into,r.need,ind.credits,int(state.coins),ind.power_use(),ind.power_cap()]
	for key in tabs:
		tabs[key].modulate=UI.MINT if key==section else Color.WHITE
		tabs[key].disabled=not ind.unlocked
	UI.clear(body)
	if not ind.unlocked: _unlock(); return
	match section:
		"deck": _deck()
		"factory": _factories()
		"market": _market()
		"gear": _gear()

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
			if int(bld.level)<int(spec.max_level):
				plot.add_child(UI.button("升级 · %d金币" % int(spec.upgrade_costs[int(bld.level)-1]),func(): _act(ind.upgrade(state,i))))
		else:
			var choices=UI.row(plot,6)
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
		var card=_card("%s Lv.%d · %d 号地 · 队列 %d/%d" % [spec.name,int(bld.level),plot+1,bld.jobs.size(),ind.queue_limit(bld)],Color(str(spec.accent)))
		for job in bld.jobs:
			var r: Dictionary=R.recipes[job.recipe]
			card.add_child(UI.label("▶ %s" % r.name,15,UI.TEXT))
			var bar=ProgressBar.new(); bar.max_value=1.0; bar.show_percentage=false; bar.custom_minimum_size=Vector2(0,8); card.add_child(bar)
			var total=float(r.seconds)
			bars.append([bar,func(): return 1.0-float(job.left)/total])
		for id in R.recipes:
			var r: Dictionary=R.recipes[id]
			if r.building!=bld.kind: continue
			var q=ind.quote(state,plot,id)
			var line=VBoxContainer.new(); line.add_theme_constant_override("separation",2); card.add_child(line)
			var ins=[]
			for k in r.inputs: ins.append("%s×%d" % [ind.input_name(state,k),int(r.inputs[k])])
			var outs=[]
			for k in r.outputs: outs.append("%s×%d" % [R.items[k].name,int(r.outputs[k])])
			line.add_child(UI.label("%s%s" % ["🔒 " if q.get("locked",false) else "",r.name],16,UI.MUTED if q.get("locked",false) else UI.MINT))
			line.add_child(UI.paragraph("%s → %s\n%s · %s" % ["＋".join(ins),"＋".join(outs),r.method,r.equation],12))
			var go=UI.button("投料" if q.ready else str(q.message),func(): _act(ind.start(state,plot,id)))
			go.disabled=not q.ready; go.add_theme_font_size_override("font_size",13); line.add_child(go)
	if not any:
		var c=_card("还没有工厂")
		c.add_child(UI.paragraph("在「甲板」页选一块地，建冶金工厂或高分子工厂。",15))

func _market() -> void:
	var ind=state.industry; var R=ind.rules()
	var hub=_card("星港交易所",UI.GOLD)
	if ind.count("trade_hub")<1:
		hub.add_child(UI.paragraph("先在「甲板」页建一座星港交易所，货运飞艇才会来收货。",15)); return
	hub.add_child(UI.paragraph("买家：轨道空间站 · 城市百货。同一件货卖得越多出价越低（最低 %d%%），约 %d 分钟恢复一半。元素和原始分子不在这里卖。累计卖出 %d 金币。" % [int(float(R.market.floor)*100),int(R.market.half_life)/60,ind.earned],14))
	var any=false
	for id in R.items:
		var n=int(ind.items.get(id,0))
		if n<1: continue
		any=true; var it: Dictionary=R.items[id]
		var row=_card("%s × %d" % [it.name,n])
		row.add_child(UI.paragraph("当前出价 %d 金币（基础 %d · 需求 %d%%）" % [ind.price(id),int(it.sell),int(100*(1.0-float(ind.saturation.get(id,0.0))))],13))
		var h=UI.row(row,6)
		for k in [1,5]:
			var b=UI.button("卖 %d" % k,func(): _act(ind.sell(state,id,k))); b.disabled=n-(1 if ind.bit==id else 0)<k; h.add_child(b)
	if not any: hub.add_child(UI.paragraph("仓库里还没有工业品。去「生产」页投料吧。",15))

func _gear() -> void:
	var ind=state.industry; var R=ind.rules()
	var card=_card("星球装备")
	card.add_child(UI.paragraph("工业钻头装上后，星球上的采掘镐用它的硬度：钻头比岩石硬就挖得快。制造台做的晶体镐更硬时，仍然用更硬的那把。\n现在星球采掘：%s · %.2f GPa" % [state.planet.v2.nature.pick_name,float(state.planet.v2.nature.pick_hv)],14))
	for id in R.items:
		var it: Dictionary=R.items[id]
		if not it.has("gear"): continue
		var row=_card("%s × %d%s" % [it.name,int(ind.items.get(id,0)),"（已装备）" if ind.bit==id else ""])
		row.add_child(UI.paragraph("硬度 %.1f GPa · %s" % [float(it.gear.hv),it.gear.note],13))
		var b=UI.button("卸下" if ind.bit==id else "装备到星球",func(): _act(ind.equip("" if ind.bit==id else id)); state.sync_gear(); _redraw())
		b.disabled=int(ind.items.get(id,0))<1 and ind.bit!=id; row.add_child(b)
