extends RefCounted
## Ecology-specific presentation and controls, separate from island transactions.
const UI=preload("res://scripts/ui.gd")
const Chart=preload("res://scripts/planet_ecology_chart.gd")

static func build(p) -> void:
	var program=p.state.planet; var w=program.worlds.get_world()
	var row=UI.row(p.body,8)
	for entry in [["microbe","厌氧池"],["fish","鱼湾"]]:
		row.add_child(UI.button(entry[1],func(): p.eco_site=entry[0]; p._redraw(); p._live(),p.eco_site==entry[0]))
	p._text(str(program.worlds.ecology.rules[p.eco_site].name),23,UI.MINT)
	var stats=UI.paragraph("",16,UI.TEXT); p.body.add_child(stats); p.eco_widgets.stats=stats
	var controls=UI.row(p.body,8)
	controls.add_child(UI.button("继续观察" if w.paused else "暂停观察",func(): p._do("pause"),true))
	controls.add_child(UI.button("回到当前" if p.replay_index>=0 else "回看过程",func(): p._replay()))
	if p.replay_index>=0:
		p._text("历史预览 · 不修改当前世界",15,UI.GOLD)
		var slider=HSlider.new(); slider.min_value=0; slider.max_value=maxi(0,w.ecology.history.size()-1); slider.step=1; slider.value=p.replay_index; slider.custom_minimum_size.y=36
		p.body.add_child(slider)
		slider.value_changed.connect(func(value): p.replay_index=int(value); p._live())
	var chart=Chart.new(); p.body.add_child(chart); p.eco_widgets.chart=chart
	p._text("金线：氧指标 0—100\n绿线：敏感菌毯覆盖 / 鱼湾占群体比例",12)
	var r=w.ecology.regions[p.eco_site]
	var devices=UI.row(p.body,8)
	var power=UI.button("关闭供氧" if r.enabled else "开启供氧",func(): p._do("ecology",{"site":p.eco_site,"control":"power"}))
	power.disabled=not r.device or p.replay_index>=0; devices.add_child(power)
	var flow=UI.button("流量 %s倍" % str(r.flow),func(): p._do("ecology",{"site":p.eco_site,"control":"flow"}))
	flow.disabled=not r.device or p.replay_index>=0; devices.add_child(flow)
	var intervention="接通避难池" if p.eco_site=="microbe" and r.get("sealed",false) else "隔离避难池"
	if p.eco_site=="fish": intervention="关闭外湾通道" if r.gate_open else "开放外湾通道"
	p._button(intervention,func(): p._do("ecology",{"site":p.eco_site,"control":"refuge" if p.eco_site=="microbe" else "gate"}),false,p.replay_index>=0)
	p._text("粉色菌毯退缩，绿色耐受群体扩张。小池隔离保种；主池恢复低氧后，接通可重新定殖。" if p.eco_site=="microbe" else "鱼群可以游到外湾，通道关闭就无法逃离。失去的鱼不会凭空补回。",14)
	p._text("窄槽支架 · 截面≤1 cm²，材料≤100 g" if p.eco_site=="microbe" else "轻量支架 · 材料≤54 g，截面≤2 cm²",14,UI.GOLD)
	p._button("比较与制作导热芯",func(): p._open_materials())
	var heat_rules=program.lab.data.thermal_game
	p._text("热负载为游戏指标：达到%.0f暂停，降至%.0f恢复。打开材料对照台会暂停当前世界。" % [heat_rules.cutoff,heat_rules.restart],13)
	p._text("世界与对照",21,UI.MINT); p._world_controls(w)
	for other in program.worlds.worlds:
		var m=other.ecology.regions.microbe; var f=other.ecology.regions.fish
		p._text("%s · %d秒\n敏感菌毯 %.0f%% · 湾内鱼群 %.1f" % [other.name,int(other.seconds),m.sensitive,f.bay],15,UI.TEXT)
	p._events(w)
	p._text("两个生态舱是隔离的教学环境。厌氧池参考早期不耐氧群落，鱼湾作为需氧动物对照，并非同一时代的复原。",14)
	p._text("氧是局部教学指标，不是mg/L；未模拟全球大气。温度、盐度与食物在本实验中保持适宜，外湾是固定的可生存边界。",14)
	p._text("依据：Smithsonian 早期生命；NOAA 低氧水域。阈值、速率与种群数量均为游戏参数。",13)

static func live(p) -> void:
	if p.eco_widgets.is_empty(): return
	var w=p.display_snapshot(); var r=w.ecology.regions[p.eco_site]
	var rules=p.state.planet.worlds.ecology.rules
	var total=float(rules.fish.initial_bay)+float(rules.fish.initial_outer)
	var machine="尚未安装供氧器"
	if r.device:
		machine="已关闭" if not r.enabled else ("补给耗尽" if r.gas<=0 else ("保护冷却中" if r.cooling else "运行 %.1f倍 · 可供%.0f秒" % [r.flow,ceil(r.gas/r.flow)]))
	if r.device:
		machine+="\n热负载 %.1f/100 · 停机%d次\n导热芯：%s" % [r.heat,int(r.trips),"基础散热" if r.component.is_empty() else p.state.planet.recipe(str(r.component.recipe)).name]
	var life="敏感菌毯 %.0f%% · 耐受群落 %.0f%%\n避难池幸存覆盖 %.0f%%" % [r.get("sensitive",0),r.get("tolerant",0),float(r.get("refuge",0))/float(rules.microbe.refuge_capacity)*100.0]
	if p.eco_site=="fish": life="湾内 %.1f · 外湾 %.1f\n累计损失 %.1f · 总群体 %.0f" % [r.bay,r.outer,r.dead,total]
	p.eco_widgets.stats.text="%d秒 · 氧指标 %.1f / 100\n%s\n供氧器：%s" % [int(w.seconds),r.oxygen,life,machine]
	var chart=p.eco_widgets.chart
	chart.samples=p.state.planet.worlds.get_world().ecology.history; chart.site=p.eco_site; chart.selected=p.replay_index; chart.fish_total=total; chart.queue_redraw()
