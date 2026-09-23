extends RefCounted
const UI=preload("res://scripts/ui.gd")
const Chart=preload("res://scripts/planet_watershed_chart.gd")

static func build(p) -> void:
	var program=p.state.planet; var world=program.worlds.get_world(); var w=world.watershed; var rules=program.worlds.watershed.rules
	if not program.joined:
		p._text("河流记得你投下的东西",23,UI.MINT)
		p._text("先领取合作，再选择时代水域，追踪上游的材料如何改变下游。",17)
		p._button("领取合作与首次供料",func(): p._do("join"),true); return
	if not w.enabled:
		p._text("选择河流的起点",23,UI.MINT)
		p._text("这是古生态灵感沙盘。时代改变植被与初始存量，设备来自你的浮岛。",17)
		for era in rules.eras:
			p._button("开启"+str(rules.eras[era].name),func(): p._do("activate_watershed",{"era":era}),true)
		p._text("新水域不会改动旧版试验舱。开始后可在实验副本另选时代。",14); return
	p._text(str(rules.eras[w.era].name),22,UI.MINT)
	var row=UI.row(p.body,8)
	for pair in [["headwater","上游"],["marsh","湿地"],["estuary","河口"]]: row.add_child(UI.button(pair[1],func(): p.watershed_site=pair[0]; p._redraw(); p._live(),p.watershed_site==pair[0]))
	var stats=UI.paragraph("",16,UI.TEXT); p.body.add_child(stats); p.watershed_widgets.stats=stats
	var buttons=UI.row(p.body,8)
	buttons.add_child(UI.button("继续观察" if world.paused else "暂停观察",func(): p._do("pause"),true))
	buttons.add_child(UI.button("回到当前" if p.replay_index>=0 else "回看过程",func(): p._replay()))
	if p.replay_index>=0:
		p._text("历史预览 · 不改变当前库存",14,UI.GOLD)
		var slider=HSlider.new(); slider.min_value=0; slider.max_value=maxi(0,w.history.size()-1); slider.step=1; slider.value=p.replay_index; slider.custom_minimum_size.y=36; p.body.add_child(slider)
		slider.value_changed.connect(func(value): p.replay_index=int(value); p._live())
	else: p._button("观察30秒 · 推进后暂停",func(): p._do("step_world"))
	var chart=Chart.new(); p.body.add_child(chart); p.watershed_widgets.chart=chart
	p._text("金：氧指标0—100　绿：藻类0—40\n棕：碎屑0—40（营养当量，超出图高截顶）",12)
	p._button("关闭上游营养输入" if w.source_open else "开放上游营养输入",func(): p._do("watershed",{"control":"source"}),false,p.replay_index>=0)
	p._button("改道绕过湿地" if not w.bypass else "恢复流经湿地",func(): p._do("watershed",{"control":"bypass"}),false,p.replay_index>=0)
	var r=w.regions[p.watershed_site]
	if r.device:
		var equipment=UI.row(p.body,8)
		var power=UI.button("关闭供氧" if r.enabled else "开启供氧",func(): p._do("watershed",{"site":p.watershed_site,"control":"power"})); power.disabled=p.replay_index>=0; equipment.add_child(power)
		var flow=UI.button("流量%s倍" % str(r.flow),func(): p._do("watershed",{"site":p.watershed_site,"control":"flow"})); flow.disabled=p.replay_index>=0; equipment.add_child(flow)
	if r.screen: p._button("暂停过滤" if r.screen_enabled else "继续过滤",func(): p._do("watershed",{"site":p.watershed_site,"control":"screen"}),false,p.replay_index>=0)
	p._button("下次收割："+("藻类" if r.harvest_target=="algae" else "植被"),func(): p._do("watershed",{"site":p.watershed_site,"control":"harvest_target"}),false,p.replay_index>=0)
	p._button("关闭鱼群外缘通道" if w.migration_open else "开放鱼群外缘通道",func(): p._do("watershed",{"control":"migration"}),false,p.replay_index>=0)
	p._text("水域产品与去向",21,UI.MINT)
	p._text("下方菜单选择过滤机、滤盒、缓冲带或收割箱，再拖到水域。水箱会暂时冲洗，污染随水流转移；不会凭空消失。",14)
	p._text("滤网只截留颗粒。溶解营养仍会通过；水清不代表可饮用。已吸收的营养可能随植被死亡归还，所以需要收割。",14,UI.GOLD)
	p._button("查看物质账本" if not p.watershed_details else "收起物质账本",func(): p.watershed_details=not p.watershed_details; p._redraw())
	if p.watershed_details:
		p._text("输入舱 %.1f · 域外流出 %.1f\n封存收集物 %.1f · 新增输入 %.1f" % [w.source,w.exported,w.waste,w.added],15,UI.TEXT)
		p._text("所有物质池为同一种教学营养当量，不是实际N/P比例。氧为独立指标；供料来自有限舱体，植物和藻只转移营养。参考NOAA营养污染、EPA湿地与处理概述。",13)
	p._text("时代与实验副本",21,UI.MINT)
	if program.worlds.worlds.size()<3:
		p._button("复制当前河流为实验",func(): p._do("fork"))
		for era in rules.eras: p._button("新实验："+str(rules.eras[era].name),func(): p._do("fork",{"era":era}))
	else: p._button("两个实验同步推进10秒",func(): p._do("step_pair"),false,not program.worlds.can_step_pair())
	if world.mode=="experiment":
		p._button("重置本实验 · 回到起点",func(): p._do("reset_trial"))
		for era in rules.eras: p._button("重置为"+str(rules.eras[era].name),func(): p._do("reset_trial",{"era":era,"fresh":true}))
	p._text("不同年代的初始条件不同，不能视为严格同条件对照；同一年代同起点副本可同步比较。",13)
	p._events(world)

static func live(p) -> void:
	if p.watershed_widgets.is_empty(): return
	var world=p.display_snapshot(); var w=world.watershed; var r=w.regions[p.watershed_site]
	var rules=p.state.planet.worlds.watershed.rules; var bottom_capacity=0.0
	for region in rules.regions:
		if region.id==p.watershed_site: bottom_capacity=float(region.benthos)
	var machine=""
	if r.screen: machine+="\n滤盒 %.1f/%.0f · 动力%.0f秒" % [r.retained,float(rules.devices.screen_capacity),r.screen_energy]
	if r.device: machine+="\n供氧 %.0f份 · 热负载%.1f%s" % [r.gas,r.heat,"（冷却中）" if r.cooling else ""]
	if not r.harvest.is_empty(): machine+="\n正在收割%s · 剩余%d秒" % ["藻类" if r.harvest.target=="algae" else "植被",int(r.harvest.left)]
	p.watershed_widgets.stats.text="水域运行%d秒 · 氧 %.1f/100\n溶解营养 %.1f · 藻 %.1f\n碎屑 %.1f · 植被 %.1f\n本地鱼 %.1f · 底栖 %.1f/%.0f\n外缘鱼 %.1f · 累计鱼损失 %.1f%s" % [int(w.elapsed),r.oxygen,r.nutrient,r.algae,r.detritus,r.plants,r.fish,r.benthos,bottom_capacity,w.refuge,w.dead,machine]
	var chart=p.watershed_widgets.chart; chart.samples=p.state.planet.worlds.get_world().watershed.history; chart.site=p.watershed_site; chart.selected=p.replay_index; chart.queue_redraw()
