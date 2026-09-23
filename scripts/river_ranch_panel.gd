extends RefCounted
const UI=preload("res://scripts/ui.gd")
static func describe(v,target: Dictionary) -> String:
	if target.has("entity"):
		var e=target.entity; var l=v.ranch.life(e.key)
		if l.is_empty(): return target.name
		var text=str(target.name)+" · "+("旅行商人" if e.type=="visitor" else (v.ranch.role(int(e.id)) if e.type=="resident" else l.task))
		if e.type in ["resident","visitor"]:
			if e.type=="resident": text+="\n"+v.ranch.job_label(int(e.id))+" · 饥饿%.0f%%" % (e.row.get("hunger",0)*100)
			text+="\n警惕 %.0f%% · 信任 %+.0f" % [l.fear*100,l.trust*100]
		else: text+="\n饥饿 %.0f%% · 口渴 %.0f%% · 疲劳 %.0f%%\n害怕 %.0f%% · 信任 %+.0f" % [e.row.get("hunger",0)*100,l.thirst*100,l.fatigue*100,l.fear*100,l.trust*100]
		if not l.memory.is_empty(): text+="\n"+"\n".join(l.memory)
		return text
	return "手套瞄准动物或居民按 E，查看近况与记忆。"

static func build(panel) -> void:
	var s=panel.state; var v=s.planet.v2; var r=v.ranch; r.sync(v)
	var intro=panel._card("河湾牧场与村庄")
	intro.add_child(UI.paragraph("工艺车间：散石 → 饮水槽；木料＋纤维 → 饲草架。\n摆到动物能走到的空地，补充水和谷穗。圈养时要保留通往食物的路。",15))
	for recipe in ["field_trough","field_feeder"]:
		intro.add_child(UI.button("去制作 · "+str(s.planet.recipe(recipe).name),func(): panel.workshop_requested.emit(recipe)))
	var target=v.Target.query(v)
	if target.has("entity"):
		var card=panel._card("眼前的伙伴"); card.add_child(UI.paragraph(describe(v,target),15))
		if target.entity.type=="visitor":
			card.add_child(UI.paragraph("本次余货 %d/2；每2份谷穗换1颗松树种子。" % (2-int(r.trades.get(target.entity.key,0))),15))
			card.add_child(UI.button("交换树种",func(): panel._act("v2_ranch_trade")))
	var depot=panel._card("公共仓库 · 玩家自行补给")
	depot.add_child(UI.paragraph("村民只使用这里的补给；背包中的东西仍属于你。\n水：%d / %d份 · 喂村民用野果或谷穗" % [r.depot.water,r.rules.depot_capacity],15))
	var names={"seed":"种子","timber":"木料","stone":"散石","fruit":"野果","grain":"谷穗","ration":"原粮仓口粮"}
	for item in names:
		var available=v.world.seeds if item=="seed" else (v.world.food if item=="ration" else v.field.stock[item])
		depot.add_child(UI.paragraph("%s · 仓库%d / 背包%d" % [names[item],r.depot[item],available],15))
		var row=UI.row(depot,6)
		for n in [1,5,-1]:
			var b=UI.button("存%d" % n if n>0 else "取1",panel._act.bind("v2_ranch_transfer",{"item":item,"amount":n}))
			b.disabled=available<n if n>0 else r.depot[item]<1; row.add_child(b)
	for batch in s.storage.batches:
		if batch.quantity<1 or s.sandbox_reference(batch.work).get("reference_id")!="water": continue
		depot.add_child(UI.button("存1份水样 · "+str(batch.id).left(14),panel._act.bind("v2_ranch_water",{"batch_id":batch.id,"token":s.planet.shipment_serial})))
	for product in s.planet.products:
		if product.recipe!="standard_water_crate": continue
		depot.add_child(UI.button("存1份工艺水箱",panel._act.bind("v2_ranch_water",{"product_id":product.id,"token":s.planet.shipment_serial})))
		break
	var staff=panel._card("谁在照料这里")
	if v.settlement.people.is_empty(): staff.add_child(UI.paragraph("先在时代页满足住房、收获与食物条件，邀请两位居民定居。",15))
	for p in v.settlement.people:
		var label=UI.paragraph("",15); staff.add_child(label); panel.widgets["worker:"+str(int(p.id))]=label
	var facilities=panel._card("设施 · 有限储料与维护")
	if r.facilities.is_empty(): facilities.add_child(UI.paragraph("从工艺车间制作后，放入快捷栏，进入第一人称放置。",15))
	for key in r.facilities:
		var f=r.facilities[key]; var spec=r.rules.facilities[f.kind]
		facilities.add_child(UI.paragraph("%s [%s]\n储料%d/%d · 完好%.0f%%" % [spec.name,key,f.stock,spec.capacity,f.integrity*100],15))
		facilities.add_child(UI.button("回仓并翻修 · 磨损时耗1"+str(v.field.rules.resources[spec.repair].name),panel._act.bind("v2_ranch_empty",{"key":key})))
		if facilities.get_child_count()>25: break
	panel.body.add_child(UI.paragraph("本版使用可调节的游戏份数。溶解度、生态毒性和有机物反应会在后续版本加入，不把未知材料默认当作安全饮水。",14,UI.MUTED))
