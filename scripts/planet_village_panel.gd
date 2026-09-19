extends RefCounted
const UI=preload("res://scripts/ui.gd")
const POLICIES={"care":"保生活","workshop":"工坊扩张","river":"河道保育"}
const TASKS={"rest":"休息","drink":"饮水","eat":"用餐","fetch":"取泉水","farm":"农作","mill":"磨粮","craft":"制作工艺品","build":"施工","":"准备下一项"}

static func build(p) -> void:
	var program=p.state.planet; var world=program.worlds.get_world(); var w=world.village; var rules=program.worlds.village.rules
	if not program.joined:
		p._text("河湾聚落",23,UI.MINT); p._text("把标准饮水、构件和工具交给居民，观察他们怎样改善生活。",17)
		p._button("领取合作与首次供料",func(): p._do("join"),true); return
	if not w.enabled:
		p._text("河湾聚落 · 等待来信",23,UI.MINT)
		p._text("晚中世纪英国乡村灵感：木构厅屋、农田、取水点和磨坊。六位代表居民先照顾生活，再按职责做工。",17)
		p._button("开启聚落并暂停",func(): p._do("activate_village"),true)
		p._text("历史灵感沙盘，工时和资源份额为游戏规则。标准水箱只供农作，生活饮水单独供应。",14); return
	p._text("河湾聚落 · 居民会建造",23,UI.MINT)
	var row=UI.row(p.body,8)
	row.add_child(UI.button("继续观察" if world.paused else "暂停观察",func(): p._do("pause"),true))
	row.add_child(UI.button("回到当前" if p.replay_index>=0 else "回看过程",func(): p._replay()))
	if p.replay_index>=0:
		p._text("历史预览 · 不改变库存和当前时刻",14,UI.GOLD)
		var slider=HSlider.new(); slider.min_value=0; slider.max_value=maxi(0,w.history.size()-1); slider.step=1; slider.value=p.replay_index; slider.custom_minimum_size.y=36; p.body.add_child(slider)
		slider.value_changed.connect(func(value): p.replay_index=int(value); p._live())
	else: p._button("聚落观察30秒 · 推进后暂停",func(): p._do("step_world"))
	var stats=UI.paragraph("",16,UI.TEXT); p.body.add_child(stats); p.village_widgets.stats=stats
	if p.replay_index<0:
		p._text("社区优先方向",20,UI.MINT)
		row=UI.row(p.body,6)
		for id in POLICIES:
			var button=UI.button(POLICIES[id],func(): p._do("village",{"control":"policy","id":id}),w.policy==id); button.disabled=p.replay_index>=0; row.add_child(button)
		p._text("保生活会留出社区建设的构件；工坊扩张允许工匠先用料。已承诺的项目保留投料和进度。",14)
		p._text("社区项目",20,UI.MINT)
		for item in program.worlds.village.candidates(w):
			var q=w.projects[item.id]; var spec=rules.projects[item.id]
			p._text("%s · %s" % [spec.name,item.reason],17,UI.MINT)
			p._text("结构件%.0f · 工具%.0f · 施工%.0f/%d\n%s" % [spec.inputs.frames,spec.inputs.tools,q.progress,int(spec.work),spec.benefit],14)
			if not q.approved: p._button("批准 · "+str(spec.name),func(): p._do("village",{"control":"approve","id":item.id}),true,p.replay_index>=0)
			else: p._button(("恢复 · " if q.paused else "暂停 · ")+str(spec.name),func(): p._do("village",{"control":"pause","id":item.id}),false,p.replay_index>=0)
		for id in w.projects:
			if w.projects[id].complete: p._text("已完成 · "+str(rules.projects[id].name),15,UI.MINT)
		if w.projects.mill.complete:
			p._button("水磨引水比例 · 当前%d%%" % roundi(w.diversion*100),func(): p._do("village",{"control":"diversion"}),false,p.replay_index>=0)
			p._text("提高引水比例会加快磨粮，但拦引水会降低河道通行。通行是教学指标，不是实际流量或鱼类数量。",14)
	else:
		var projects=UI.paragraph("",15,UI.MINT); p.body.add_child(projects); p.village_widgets.projects=projects
	p._text("今天在忙什么",20,UI.MINT)
	var people=UI.paragraph("",14,UI.TEXT); p.body.add_child(people); p.village_widgets.people=people
	p._text("产品与资源账本",20,UI.MINT)
	p._text("下方菜单选择聚落产品，再拖到河湾仓库。谷物由农作产出，食品需要磨粮；工具会磨损。生活饮水来自设定的有限合格泉水与标准桶，不承诺真实泉水可直接饮用。",14)
	var ledger=UI.paragraph("",13,UI.MUTED); p.body.add_child(ledger); p.village_widgets.ledger=ledger
	p._text("副本与对照",20,UI.MINT)
	if program.worlds.worlds.size()<3: p._button("复制聚落为独立实验",func(): p._do("fork"),false,p.replay_index>=0)
	else: p._button("两个实验同步推进10秒",func(): p._do("step_pair"),false,p.replay_index>=0 or not program.worlds.can_step_pair())
	if world.mode=="experiment": p._button("重置聚落实验 · 回到起点",func(): p._do("reset_trial"),false,p.replay_index>=0)
	p._text("实验库存不能带回浮岛；主世界消耗已制造的工业成品。只显示当前世界，历史回看不可交付产品。",14)
	p._events(world)

static func live(p) -> void:
	if p.village_widgets.is_empty(): return
	var world=p.display_snapshot(); var w=world.village; var model=p.state.planet.worlds.village; var rules=model.rules
	p.village_widgets.stats.text="聚落运行%d秒 · 河道通行 %.0f%%\n饮水 %.1f · 农作用水 %.1f\n谷物 %.1f · 食品 %.1f\n结构件 %.1f · 工具耐用量 %.1f\n工艺品 %.1f · 已交换%d次" % [w.elapsed,w.passage,w.stock.drink,w.stock.water,w.stock.grain,w.stock.food,w.stock.frames,w.stock.tools,w.stock.goods,w.trades]
	var list=[]
	for worker in w.people:
		var info=rules.people[int(worker.id)]; var stage="途中" if worker.route.size()>1 else ("取料" if worker.stage=="pickup" else ("送回仓库" if worker.stage=="return" else ""))
		list.append("%s · %s%s · 渴%.0f / 饿%.0f" % [info.name,TASKS[worker.task],stage,worker.thirst,worker.hunger])
	p.village_widgets.people.text="\n".join(list)
	if p.village_widgets.has("projects"):
		list=[]
		for id in w.projects:
			var q=w.projects[id]
			list.append("%s：%s" % [rules.projects[id].name,"完工" if q.complete else ("进度%.0f/%d" % [q.progress,int(rules.projects[id].work)] if q.committed else "尚未开工")])
		p.village_widgets.projects.text="当时的社区项目\n"+"\n".join(list)
	list=[]
	for id in rules.initial:
		list.append("%s：外供%.1f / 本地产出%.1f / 已用%.1f / 外换%.1f / 返程%.1f" % [rules.names[id],w.added[id],w.produced[id],w.used[id],w.exported[id],model.carried(w,id)])
	p.village_widgets.ledger.text="\n".join(list)+"\n输入在领用时计入已承诺消耗，携带标记只表示运输。任务完成后，返程产品才计入产出，入仓不重复记账。"
