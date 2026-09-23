extends Control
signal dismissed
signal acted(message: String)
signal arrange(kind: String)
signal factory_requested
signal planet_v2_requested
signal material_navigation(route: String)
const UI=preload("res://scripts/ui.gd")
var state
var selected_plot=-1
var section="products"
var mode="toolbox"
var focused_visitor=-1
var body: VBoxContainer
var scroll: ScrollContainer
var status: Label
var timers: Array=[]
var clock=0.0
var fingerprint=""
var ranked=false
var scroll_memory=preload("res://scripts/panel_scroll.gd").new()

func setup(model, plot: int, page: String="toolbox", visitor: int=-1) -> void:
	state=model; selected_plot=plot; mode=page; focused_visitor=visitor
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim=ColorRect.new(); dim.color=Color(0.02,0.04,0.07,0.93); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(dim)
	var panel=UI.box(self,Rect2(92,50,1256,800))
	var content=UI.column(panel,16)
	var heading=UI.row(content)
	var title=UI.label("浮岛邮箱 · 来访订单" if mode=="mail" else "随身工具箱",30,UI.MINT); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(title)
	heading.add_child(UI.button("返回小岛",_close))
	status=UI.label("",16,UI.GOLD); content.add_child(status)
	if mode!="mail":
		var tabs=UI.row(content,10)
		for entry in [["elements","元素"],["products","结构样品"],["industrial","工业成品"],["materials","晶石 / 建材"],["supplies","补给商店"],["decor","道具 / 装饰"]]:
			tabs.add_child(UI.button(entry[1],_tab.bind(entry[0])))
	scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; content.add_child(scroll)
	body=UI.column(scroll,16); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_redraw()

func _tab(id: String) -> void:
	section=id; _redraw(true)

func _card(title: String) -> VBoxContainer:
	var panel=PanelContainer.new(); body.add_child(panel)
	var col=UI.column(panel,10); col.add_child(UI.label(title,22,UI.MINT)); return col

func _redraw(reset_scroll: bool=false) -> void:
	scroll_memory.refresh(scroll,reset_scroll)
	UI.clear(body); timers.clear()
	fingerprint=_fingerprint()
	if mode=="mail": _mail()
	else:
		match section:
			"elements": _elements()
			"products": _products()
			"industrial": _industrial()
			"materials": _materials()
			"supplies": _supplies()
			"decor": _decor()
	_live()

func _elements() -> void:
	body.add_child(UI.paragraph("新加或替换的元素从这里购买。提交更换后，由空闲博士沿小路将样品装入反应炉；原子坐标仍由你调整。",18))
	for symbol in state.elements:
		var q: Dictionary=state.purchase_quote(symbol,1)
		if int(q.get("unit_price",0))<=0: continue
		var row=UI.row(body); var label=UI.label("%s · %s    库存 %d" % [symbol,state.elements[symbol].get("name",symbol),int(state.element_inventory.get(symbol,0))],20); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
		for n in [1,10]:
			var quote: Dictionary=state.purchase_quote(symbol,n)
			var b=UI.button("买%d · %d金币" % [n,int(quote.get("total",0))],func(): _done(state.buy_elements(symbol,n))); b.disabled=not quote.get("ready",false); row.add_child(b)

func _products() -> void:
	body.add_child(UI.paragraph("只有收集后的产物才会进入这里。每个批次保留生产时的结构和几何评分，改炉不会覆盖旧货。出售请前往广场邮箱。",18))
	if "parallel_screening" in state.campus.unlocked_materials:
		body.add_child(UI.button("几何筛选："+("按评分排序" if ranked else "按入库顺序"),func(): ranked=not ranked; _redraw(),true))
	if state.storage.batches.is_empty(): body.add_child(UI.label("工具箱还空着，去领取反应炉里的产物吧。",22,UI.GOLD))
	var items: Array=state.storage.batches.duplicate()
	if ranked: items.sort_custom(func(a,b): return float(a.quality)>float(b.quality))
	for item in items:
		var card=_card("%s · %s    ×%d" % [item.formula,item.name,int(item.quantity)])
		card.add_child(UI.paragraph("批次 %s · %s" % [item.id,"参考几何匹配 %d%%" % roundi(float(item.quality)*100) if not item.reference.is_empty() else "探索 / 展示样品 · 性质未知"],17,UI.LILAC))

func _industrial() -> void:
	var p=state.planet
	body.add_child(UI.paragraph("工业成品用于星球部署或订单交付，和反应炉的结构样品分别保管。",18))
	body.add_child(UI.button("工艺车间 · 制造成品",func(): factory_requested.emit(),true))
	body.add_child(UI.button("进入河湾 · 上帝视角",func(): planet_v2_requested.emit(),true))
	for id in p.recipe_ids():
		if p.available_products(id)==0: continue
		var info=p.recipe(id); var card=_card("%s · 主仓库 %d件" % [info.name,p.available_products(id)])
		card.add_child(UI.label("对应供料 %d份" % p.input_count(info.input),18,UI.GOLD))
		for product in p.products:
			if product.recipe==id:
				var origin="工业参考对照" if p.lab.is_component(id) else "来源样品批次"
				card.add_child(UI.paragraph("成品 #%d · %s %s" % [int(product.id),origin,str(product.source_batch)],15))
	var family=_card("我的模型构件 · %d件" % p.laminates.total())
	family.add_child(UI.paragraph("标准层料：Cu %.1fg / Al %.1fg；在制层料已单独预留。" % [p.laminates.feed.Cu*1000,p.laminates.feed.Al*1000],17))
	for id in p.materials.designs:
		var d=p.materials.designs[id]
		if d.basis=="family_model" and p.laminates.count(id)>0: family.add_child(UI.paragraph("%s · 库存%d件" % [p.laminates.model.name(d),p.laminates.count(id)],18,UI.MINT))
	family.add_child(UI.button("管理层芯装配",func(): material_navigation.emit("workshop")))

func _materials() -> void:
	var field=state.planet.v2.field
	var gathered=_card("从河湾带回的收获")
	for id in field.stock:
		gathered.add_child(UI.label("%s ×%d" % [field.rules.resources[id].name,field.stock[id]],18,UI.MINT))
		if id in ["fruit","grain"]:
			gathered.add_child(UI.button("取1份送入星球粮仓",func(): _done(state.planet.command(state,"v2_field_pantry",{"resource":id}))))
	gathered.add_child(UI.button("工艺车间 · 加工采集材料",func(): factory_requested.emit(),true))
	body.add_child(UI.paragraph("建材用于向浮岛边缘开拓；催化晶用于反应炉升级。它们与摆件、小路和生活补给分别存放。",19))
	for i in range(3):
		var card=_card(["星砂","晶露","合金片"][i]); card.add_child(UI.label("库存 %d" % int(state.materials[i]),24,UI.GOLD))
	var card=_card("精品催化晶"); card.add_child(UI.label("库存 %d · 完成精品订单获得" % int(state.upgrades),21,UI.LILAC))
	body.add_child(UI.paragraph("每份已知参考产物收集时有%d%%概率掉落1份建材；连续%d份没有掉落时，补给库存最少的建材。" % [roundi(float(state.island_rules.production.drop_probability)*100),int(state.island_rules.production.drop_pity)],16))

func _supplies() -> void:
	body.add_child(UI.paragraph("空闲博士工作时间会先装炉，再巡回收集。先购买泡面或可乐，再放进他们居住的公寓。补给耗尽后会回家等待；你仍可手动收获。",18))
	for kind in state.island_rules.consumables:
		var info: Dictionary=state.island_rules.consumables[kind]
		var card=_card("%s · 工具箱 %d份" % [info.name,int(state.storage.consumables.get(kind,0))])
		card.add_child(UI.paragraph(info.description,17))
		var row=UI.row(card)
		for amount in [1,5]: row.add_child(UI.button("购买%d份 · %d金币" % [amount,int(info.cost)*amount],func(): _done(state.buy_consumable(kind,amount))))
	var found=false
	for i in range(state.plots.size()):
		if state.plots[i].kind!="doctor_dorm": continue
		found=true
		var card=_card("博士公寓 · %s · 补给 %d / %d" % [state.plot_label(i),state.storage.food_count(i),int(state.island_rules.logistics.cupboard_capacity)])
		var row=UI.row(card)
		for kind in state.island_rules.consumables:
			var amount=int(state.storage.cupboard(i).get(kind,0))
			row.add_child(UI.button("放入%s ×1（柜内%d）" % [state.island_rules.consumables[kind].name,amount],func(): _done(state.supply_dorm(i,kind,1))))
	if not found: body.add_child(UI.paragraph("尚无博士公寓。在小岛空地建造公寓并铺路，再邀请博士入住。",19,UI.GOLD))

func _decor() -> void:
	body.add_child(UI.paragraph("在新土地上找到的3D小物件会解锁收藏。摆件与道路可收入工具箱，再免费布置；每块地有8个庭院位置。",18))
	var road=_card("星砂小路 · 库存%d" % int(state.storage.decorations.get("road",0)))
	road.add_child(UI.button("铺在当前地块（无库存时%d金币）" % int(state.layout.config.roads.cost),func(): _done(state.campus_road(selected_plot))))
	road.add_child(UI.button("收纳当前地块的小路",func(): _done(state.store_road(selected_plot))))
	for kind in state.layout.config.props:
		var info: Dictionary=state.layout.config.props[kind]
		var locked=bool(info.get("exploration",false)) and kind not in state.storage.unlocked
		var card=_card("%s · %s" % [info.name,"待探索发现" if locked else "库存%d" % int(state.storage.decorations.get(kind,0))])
		if locked: card.add_child(UI.paragraph("在浮岛边缘开拓土地，寻找发光的小物件。",17)); continue
		var button=UI.button("选择庭院位置 · 有库存免费 / 新购%d金币" % int(info.cost),func(): arrange.emit(kind); _close()); card.add_child(button)

func _mail() -> void:
	if focused_visitor<0:
		var cooperation=_card("星球探索与浮岛制造")
		cooperation.add_child(UI.paragraph("走进河湾、森林和营地，带上工具箱里的样品与工坊成品，观察土地和生命的变化。",18))
		cooperation.add_child(UI.button("上帝星球 · 河湾世界",func(): planet_v2_requested.emit(),true))
		cooperation.add_child(UI.button("工艺车间 · 制造成品",func(): factory_requested.emit()))
		var next=preload("res://scripts/material_journey.gd").next(state)
		var guide=_card("铜铝研发路线 · %d/6 · %s" % [next.index,next.title])
		guide.add_child(UI.paragraph(next.detail,17))
		if next.route!="mail": guide.add_child(UI.button(next.action,func(): material_navigation.emit(next.route)))
	else: body.add_child(UI.button("查看全部来访与研发路线",func(): focused_visitor=-1; _redraw()))
	body.add_child(UI.paragraph("来访客人最多3位，按各自的时间离岛。亮起的气泡可直接交付最合适的同类批次；灰色气泡可查看需求与替代品报价。",18))
	if state.market.visitors.is_empty(): body.add_child(UI.label("广场暂时安静，下一位客人正在路上。",23,UI.MINT))
	var visitors: Array=state.market.visitors.duplicate()
	visitors.sort_custom(func(a,b): return int(a.id)==focused_visitor and int(b.id)!=focused_visitor)
	for v in visitors:
		var card=_card(str(v.order.name)+" · 收购1件" if state.contracts.is_material(v) else "%s · %s" % [v.order.name,state.market.request_text(v,state.templates)])
		var timer=UI.label("",17,UI.GOLD); card.add_child(timer); timers.append({"id":int(v.id),"label":timer})
		card.add_child(UI.paragraph(v.order.story,17))
		if state.contracts.is_material(v):
			_material_order(card,v); continue
		if str(v.order.get("property",""))!="exhibition": card.add_child(UI.paragraph("参考几何目标%d%% · 相差≤%d个百分点为精品；替代品按折价交付。几何评分不等同于真实物性。" % [roundi(float(v.order.target_quality)*100),roundi(float(v.order.tolerance)*100)],15))
		var rows: Array=state.visitor_candidates(int(v.id))
		if rows.is_empty(): card.add_child(UI.paragraph("暂时没有入库产物。去反应炉收集，再来看看。",18,UI.GOLD))
		for i in range(mini(8,rows.size())):
			var q: Dictionary=rows[i]
			var row=UI.row(card)
			var label=UI.paragraph("%d. %s · 库存%d\n%s · 报价%d金币%s" % [i+1,q.name,q.quantity,"精品" if q.premium else ("同类样品" if q.matching else "替代样品"),q.payment," + 催化晶" if q.premium else ""],17); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
			var b=UI.button("交付%d份" % int(v.order.quantity),func(): _done(state.fulfill_order(int(v.id),str(q.batch_id))),bool(q.premium)); b.disabled=not q.ready; row.add_child(b)
		var dismiss=UI.button("送别这位客人",func(): _done(state.dismiss_market_visitor(int(v.id)))); dismiss.disabled=v.phase!="visiting"; card.add_child(dismiss)

func _material_order(card: VBoxContainer,v: Dictionary) -> void:
	var terms=v.order.terms
	card.add_child(UI.paragraph("模型热导目标 %.3f W/K · 质量≤%.1fg · 截面≤%.2fcm²\n至少达到目标%.0f%%；%.0f%%为精品。此单条件在到访时固定。" % [terms.target_G_W_K,terms.max_mass_kg*1000,terms.max_area_m2*10000,terms.minimum_ratio*100,terms.premium_ratio*100],17,UI.GOLD))
	var rows=state.visitor_candidates(int(v.id))
	if rows.is_empty(): card.add_child(UI.paragraph("尚无已保存的模型层芯。先完成方法研发，再为铜铝提案保存方案。",18))
	for q in rows.slice(0,8):
		var row=UI.row(card); var label=UI.paragraph("%s · 库存%d\n%s · %.0f%%目标 · %d金币%s" % [q.name,q.quantity,q.reason,q.ratio*100,q.payment," + %d催化晶" % q.catalysts if q.premium else ""],17)
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
		var button=UI.button("交付构件",func(): _done(state.fulfill_order(int(v.id),q.batch_id)),q.premium); button.disabled=not q.ready; row.add_child(button)
	card.add_child(UI.button("查看我的模型方案",func(): material_navigation.emit("materials")))
	var dismiss=UI.button("送别这位客人",func(): _done(state.dismiss_market_visitor(int(v.id)))); dismiss.disabled=v.phase!="visiting"; card.add_child(dismiss)

func _fingerprint() -> String:
	var visitors=[]
	for v in state.market.visitors: visitors.append([v.id,v.phase])
	var quantities=[]
	for batch in state.storage.batches: quantities.append([batch.id,batch.quantity])
	return str([visitors,quantities,state.storage.decorations,state.storage.consumables,state.storage.cupboards,state.element_inventory,state.campus.unlocked_materials,state.deliveries,state.planet.feed,state.planet.products.size(),state.planet.job.get("id",0),state.planet.materials.records.size(),state.planet.materials.designs.size(),state.planet.laminates.feed,state.planet.laminates.stock,state.planet.laminates.job.get("id",0),ceili(state.planet.laminates.cooldown)])

func _live() -> void:
	status.text="金币 %d  ·  入库批次 %d / 512  ·  已开拓土地 %d" % [int(state.coins),state.storage.batches.size(),state.unlocked_plot_count()]
	for entry in timers:
		var v: Dictionary=state.market.visitor(entry.id)
		if v.is_empty(): continue
		entry.label.text={"arriving":"车辆正在驶入广场…","leaving":"交接完成，客人正在离岛…","visiting":"还会停留 %d 秒" % maxi(0,ceili(float(state.island_rules.visitors.stay_seconds)-float(v.age)))}[v.phase]

func _process(dt: float) -> void:
	if state==null: return
	clock+=dt
	if clock<1: return
	clock=0
	if fingerprint!=_fingerprint(): _redraw()
	else: _live()

func _done(message: String) -> void:
	acted.emit(message); _redraw()

func handle_back() -> bool:
	_close(); return true

func _close() -> void:
	dismissed.emit(); queue_free()
