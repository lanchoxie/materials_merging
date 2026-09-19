extends RefCounted
const UI=preload("res://scripts/ui.gd")
const ACTIONS={"rest":"观察环境","walk":"迁徙途中","drink":"饮水","graze":"取食植被","scavenge":"取食遗骸","hunt":"捕食","lost":"已损失"}
const CAUSES={"":"","thirst":"缺水","hunger":"缺食","predation":"被捕食"}

static func build(p) -> void:
	var program=p.state.planet; var world=program.worlds.get_world(); var w=world.habitat; var model=program.worlds.habitat; var rules=model.rules
	if not program.joined:
		p._text("白垩纪 · 蕨林河谷",23,UI.MINT); p._text("连接浮岛工坊与栖地，观察水点和通道如何改变恐龙的生活。",17)
		p._button("领取合作与首次供料",func(): p._do("join"),true); return
	if not w.enabled:
		p._text("白垩纪 · 蕨林河谷",23,UI.MINT)
		p._text("蕨地正在变干，远岸台地仍有食物和水。接通远岸能分散压力，也会给霸王龙打开通路。",17,UI.TEXT)
		p._button("开启蕨林河谷并暂停",func(): p._do("activate_habitat"),true)
		p._text("海尔溪地区的生物与植物启发原创模型。十只代表个体、旱雨周期和需求均是教学设定，不是古代物种的真实耐受数据。",14); return
	p._text("蕨林河谷 · 会迁徙的生命",23,UI.MINT)
	var row=UI.row(p.body,8)
	row.add_child(UI.button("继续观察" if world.paused else "暂停观察",func(): p._do("pause"),true))
	row.add_child(UI.button("回到当前" if p.replay_index>=0 else "回看过程",func(): p._replay()))
	if p.replay_index>=0:
		p._text("历史预览 · 不回滚死亡或返还物品",14,UI.GOLD)
		var slider=HSlider.new(); slider.min_value=0; slider.max_value=w.history.size()-1; slider.step=1; slider.value=p.replay_index; slider.custom_minimum_size.y=36; p.body.add_child(slider)
		slider.value_changed.connect(func(value): p.replay_index=int(value); p._live())
	else: p._button("栖地观察30秒 · 推进后暂停",func(): p._do("step_world"))
	var stats=UI.paragraph("",16,UI.TEXT); p.body.add_child(stats); p.habitat_widgets.stats=stats
	p._text("查看一片栖地",20,UI.MINT)
	var picker=OptionButton.new(); picker.custom_minimum_size.y=44; p.body.add_child(picker)
	for id in rules.regions:
		picker.add_item(str(rules.regions[id].name)); picker.set_item_metadata(picker.item_count-1,id)
		if id==p.habitat_site: picker.select(picker.item_count-1)
	picker.item_selected.connect(func(index): p.habitat_site=str(picker.get_item_metadata(index)); p._redraw(); p._live())
	var region=UI.paragraph("",16,UI.TEXT); p.body.add_child(region); p.habitat_widgets.region=region
	if p.replay_index<0:
		row=UI.row(p.body,6)
		row.add_child(UI.button("选水箱补水",func(): p._choose_recipe("standard_water_crate")))
		row.add_child(UI.button("选遮荫保水棚",func(): p._choose_recipe("shade_canopy")))
		p._text("拖放到画面中的圆形水点。补水会吸引动物；棚能保水，但蕨类也长得更慢。",14)
	p._text("通道与远岸",20,UI.MINT)
	if p.replay_index<0:
		p._button("选择栖地连接桥",func(): p._choose_recipe("habitat_bridge"))
		for id in rules.edges:
			if w.edges[id].built: p._button(("关闭 · " if w.edges[id].open else "开放 · ")+str(rules.edges[id].name),func(): p._do("habitat",{"id":id}))
		p._text("把桥拖到金色断点。通道对所有恐龙开放；关闭后在途动物走完这一段，下一段才停止。",14)
	p._text("现在在做什么",20,UI.MINT)
	var people=UI.paragraph("",14,UI.TEXT); p.body.add_child(people); p.habitat_widgets.people=people
	p._button("收起资源账本" if p.habitat_details else "展开资源账本与科学边界",func(): p.habitat_details=not p.habitat_details; p._redraw(); p._live())
	if p.habitat_details:
		var ledger=UI.paragraph("",14,UI.MUTED); p.body.add_child(ledger); p.habitat_widgets.ledger=ledger
		p._text(str(rules.evidence)+" 死亡留下有限遗骸供捕食者利用，损失原因可查；本版没有繁殖或自动补充动物。",14)
	p._text("同起点对照",20,UI.MINT)
	if program.worlds.worlds.size()<3: p._button("复制栖地为独立实验",func(): p._do("fork"),false,p.replay_index>=0)
	else: p._button("两个实验同步推进10秒",func(): p._do("step_pair"),false,p.replay_index>=0 or not program.worlds.can_step_pair())
	if world.mode=="experiment": p._button("重置栖地实验 · 回到起点",func(): p._do("reset_trial"),false,p.replay_index>=0)
	p._text("复制同一主世界两次，在一个实验补水、另一个架桥。实验配给独立，观察食物、水与迁徙的差异。",14)
	p._events(world)

static func live(p) -> void:
	if p.habitat_widgets.is_empty(): return
	var world=p.display_snapshot(); var w=world.habitat; var model=p.state.planet.worlds.habitat; var rules=model.rules
	var until=int(rules.climate.cycle)-int(w.elapsed)%int(rules.climate.cycle) if model.wet(w) else int(rules.climate.dry_seconds)-int(w.elapsed)%int(rules.climate.cycle)
	p.habitat_widgets.stats.text="%s · %d秒后转换\n三角龙 %d / 埃德蒙顿龙 %d / 霸王龙 %d\n累计迁徙 %d 次 · 损失 %d 只" % ["雨期" if model.wet(w) else "旱期",until,model.alive(w,"triceratops"),model.alive(w,"edmontosaurus"),model.alive(w,"tyrannosaurus"),w.migrations,w.animals.size()-model.alive(w)]
	var r=w.regions[p.habitat_site]
	p.habitat_widgets.region.text="%s · 水 %.1f / 植被 %.1f\n停留：植食 %d / 捕食 %d\n%s" % [rules.regions[p.habitat_site].name,r.water,r.plants,model.occupants(w,p.habitat_site),model.occupants(w,p.habitat_site,true),"已有遮荫：蒸发降低，植被增长也降低" if r.shade else "露天水点"]
	var lines=[]
	for animal in w.animals:
		var location=str(rules.regions[animal.at].name)
		if not animal.to.is_empty(): location+=" → "+str(rules.regions[animal.to].name)
		lines.append("%s%d · %s\n%s · %s" % [rules.species[animal.species].name,int(animal.id)+1,location,ACTIONS[animal.action],"渴%.0f / 饿%.0f / 健康%.0f" % [animal.thirst,animal.hunger,animal.health] if animal.alive else CAUSES[animal.cause]])
	p.habitat_widgets.people.text="\n".join(lines)
	if p.habitat_widgets.has("ledger"):
		p.habitat_widgets.ledger.text="此地累计：补水%.1f / 降雨%.1f\n饮用%.1f / 蒸发%.1f / 生长用水%.1f / 溢出%.1f\n植被：增长%.1f / 取食%.1f / 枯萎%.1f\n遗骸：产生%.1f / 取食%.1f / 分解%.1f\n数量是游戏资源当量，非升、千克或实测生物量。" % [r.added,r.rain,r.drunk,r.evaporated,r.growth_water,r.overflow,r.grown,r.grazed,r.wilted,r.remains,r.scavenged,r.decayed]
