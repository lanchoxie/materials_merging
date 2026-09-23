extends RefCounted
const UI=preload("res://scripts/ui.gd")

static func build(panel) -> void:
	var v=panel.state.planet.v2; var o=v.organics
	var intro=panel._card("一片新叶 · 有机物")
	intro.add_child(UI.paragraph("反应釜的尿素和水 → 配料罐 → 背包中的溶液 → 种植箱。留一箱不施肥，对比相同湿度下的生长。",16))
	intro.add_child(UI.button("到工艺车间制造配料罐",func(): panel.workshop_requested.emit("field_mixing_tank")))
	var target=v.Target.query(v)
	if target.get("kind")!="mixing_tank":
		var guide=panel._card("走近你的配料罐")
		guide.add_child(UI.paragraph("车间使用2份木料、3份散石，做出可放置的罐。背包拿起，在地面放下；换采集手套，对准罐按 E 查看。\n尿素在反应釜的结构工作台选择「尿素 · 一片新叶」，调整结构后收集产物。",16))
	else:
		var key=str(target.key); var card=panel._card("配料罐 · "+key)
		var stats=UI.paragraph("",16,UI.MINT); card.add_child(stats); panel.widgets["organic_stats"]=stats
		card.add_child(UI.paragraph("1份尿素 + 1份水，等待晶粒溶解后分装。再加尿素会变浓；加水可稀释，最多2教学升。",15))
		for reference in ["water","urea"]:
			var found=false
			for batch in panel.state.planet.sample_candidates(panel.state,reference):
				if batch.quantity<1: continue
				found=true
				var label=("加水" if reference=="water" else "加尿素")+" · "+str(batch.id).left(22)+" ×"+str(int(batch.quantity))
				var payload={"key":key,"batch_id":str(batch.id),"token":panel.state.planet.shipment_serial}
				var button=UI.button(label,func(): panel._act("organic_add",payload)); card.add_child(button)
				button.disabled=not o.input_error(key,reference,str(batch.id),v.construction).is_empty()
			if not found: card.add_child(UI.paragraph("还没有"+("水样" if reference=="water" else "尿素")+"：去反应釜收集，存入同一个背包。",15,UI.MUTED))
		var payload={"key":key,"token":panel.state.planet.shipment_serial}
		var bottle=UI.button("分装250 mL到背包",func(): panel._act("organic_bottle",payload),true); card.add_child(bottle); bottle.disabled=not o.bottle_error(key).is_empty()
		card.add_child(UI.button("拿起已分装的溶液",func():
			if not o.bottles.is_empty(): panel._equip_item("solution:"+str(o.bottles.keys()[-1]))
			else: panel.message="先等待溶解，再分装一瓶"; panel._live()))
		card.add_child(UI.button("封存余料 · 腾空罐",func(): panel._act("organic_drain",payload)))
	var observation=panel._card("苗圃观察")
	var plots=UI.paragraph("",15); observation.add_child(plots); panel.widgets["organic_plots"]=plots
	var evidence=panel._card("物性与实验记录")
	evidence.add_child(UI.paragraph("尿素 CH₄N₂O · 易溶于水，可作氮肥。当前只开放种植箱补肥；浓液和反复施用可能伤苗，不代表对所有动物都有相同毒性。\n本罐为20°C教学条件；g、mL用于配料比较，溶解速度和伤苗阈值为游戏设定。未启用饱和溶解度外推或通用毒性分数。",15))
	var ledger=UI.paragraph("",14,UI.MUTED); evidence.add_child(ledger); panel.widgets["organic_ledger"]=ledger
	live(panel)

static func live(panel) -> void:
	var v=panel.state.planet.v2; var o=v.organics; var target=v.Target.query(v)
	if panel.widgets.has("organic_stats"):
		var t=o.tanks.get(str(target.get("key","")),{})
		panel.widgets.organic_stats.text="罐是空的，先加入水样或尿素" if t.is_empty() else "水量 %.2f / 2 L · 晶粒 %.2f g\n已溶 %.2f g · %.2f g/L · 20°C" % [t.water_l,t.solid_g,t.dissolved_g,o.concentration(t)]
	if panel.widgets.has("organic_plots"):
		var lines=[]; var at=panel._observer_position()
		for key in v.field.gardens:
			var b=v.construction.blocks[key]
			if Vector2(b.x,b.z).distance_to(at)>20: continue
			lines.append("箱%s · 生长%.0f%%\n%s" % [key,v.field.gardens[key].growth*100,o.describe_soil(key)])
			if lines.size()>=6: break
		panel.widgets.organic_plots.text="附近还没有播种的箱子；摆两箱，种下相同种子。" if lines.is_empty() else "\n\n".join(lines)
	if panel.widgets.has("organic_ledger"):
		var total=o.balance()
		panel.widgets.organic_ledger.text="配入 %.1f g / %.2f L · 背包溶液 %d瓶\n作物利用 %.2f g当量 · 封存余料 %.2f g / %.2f L\n物性出处：OECD尿素评估；明尼苏达大学尿素施肥资料。" % [total.input_g,total.input_l,o.bottles.size(),o.spent_g,o.waste_g,o.waste_l]
