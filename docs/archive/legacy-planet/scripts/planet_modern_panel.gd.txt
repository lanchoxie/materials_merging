extends RefCounted
const UI=preload("res://scripts/ui.gd")
static func build(p) -> void:
	var program=p.state.planet; var world=program.worlds.get_world(); var w=world.modern; var rules=program.worlds.modern.rules
	p._text("现代城市 · 白昼之后",23,UI.MINT)
	if not program.joined: p._button("领取合作与首次供料",func(): p._do("join"),true); return
	if not w.enabled:
		p._text("先装光伏，再安排储能与计算。夜晚没有阳光，空电池不能发电；计算会产生需要排出的热。",17,UI.TEXT)
		p._button("开启现代城市并暂停",func(): p._do("activate_modern"),true); return
	var row=UI.row(p.body,6)
	row.add_child(UI.button("继续观察" if world.paused else "暂停观察",func(): p._do("pause"),true))
	row.add_child(UI.button("回到当前" if p.replay_index>=0 else "回看过程",func(): p._replay()))
	if p.replay_index>=0:
		var slider=HSlider.new(); slider.min_value=0; slider.max_value=w.history.size()-1; slider.step=1; slider.value=p.replay_index; slider.custom_minimum_size.y=36; p.body.add_child(slider)
		slider.value_changed.connect(func(v): p.replay_index=int(v); p._live())
		p._text("回看只显示旧状态，不返回电量、物品或再生件。",14,UI.GOLD)
	else: p._button("城市观察30秒 · 推进后暂停",func(): p._do("step_world"))
	var label=UI.paragraph("",16,UI.TEXT); p.body.add_child(label); p.modern_widgets.status=label
	if p.replay_index<0:
		p._text("有限的电先给谁",20,UI.MINT); row=UI.row(p.body,4)
		for id in {"residents":"居民优先","compute":"算力优先","circular":"回收优先"}:
			row.add_child(UI.button({"residents":"居民优先","compute":"算力优先","circular":"回收优先"}[id],func(): p._do("modern",{"control":"policy","id":id}),w.policy==id))
		row=UI.row(p.body,4)
		for id in {"auto":"自动储能","reserve":"保留电量","off":"关闭储能"}:
			row.add_child(UI.button({"auto":"自动储能","reserve":"保留电量","off":"关闭储能"}[id],func(): p._do("modern",{"control":"storage","id":id}),w.storage_mode==id))
		p._text("保留模式只充不放，关闭模式不充不放；充放各90%，往返81%。出厂电池为空。",14)
	p._text("算力要有实际用途",20,UI.MINT)
	label=UI.paragraph("",15,UI.TEXT); p.body.add_child(label); p.modern_widgets.jobs=label
	if p.replay_index<0:
		row=UI.row(p.body,4)
		for id in rules.jobs: row.add_child(UI.button(str(rules.jobs[id].name),func(): p._do("modern",{"control":"job","id":id}),w.job_kind==id))
		p._button("暂停计算" if w.running else "继续计算",func(): p._do("modern",{"control":"compute"}))
	p._text("当前任务完成后，对应需求降低25%、持续180秒。切换只改变下一项，效果不能叠加。不是实际AI能耗预测。",14)
	p._text("组件与循环材料",20,UI.MINT)
	label=UI.paragraph("",15,UI.TEXT); p.body.add_child(label); p.modern_widgets.materials=label
	if p.replay_index<0:
		var choices=OptionButton.new(); choices.custom_minimum_size.y=44; p.body.add_child(choices); choices.add_item("选择要制造的城市组件…")
		for id in rules.trial_products: choices.add_item(str(program.recipe(id).name)); choices.set_item_metadata(choices.item_count-1,id)
		choices.item_selected.connect(func(i):
			if i>0: p._choose_recipe(str(choices.get_item_metadata(i))))
		p._button("暂停回收" if w.recycling else "继续回收",func(): p._do("modern",{"control":"recycle"}))
		if not w.park: p._button("暂停公园施工" if w.park_requested else "用4份再生件建口袋公园",func(): p._do("modern",{"control":"park"}))
	p._text("屋顶6 m²、承重35 kg；地面10 m²、承重180 kg。组件替换留下废构件，回收率70%，残渣保留。散热芯先记录等重铜铝对照，再生产。",14)
	p._button("收起能量与来源" if p.modern_details else "展开能量与来源",func(): p.modern_details=not p.modern_details; p._redraw(); p._live())
	if p.modern_details:
		label=UI.paragraph("",14,UI.TEXT); p.body.add_child(label); p.modern_widgets.ledger=label
		p._text(str(rules.science_note)+" 光伏20%/24%、质量和衰减均是虚构供应商方案，不是实测；不会从带隙或键长推出整块电池效率。",14)
		p._text("DOE光伏/钙钛矿资料提供原理与稳定性背景；NLR SAM给出往返效率定义；DOE数据中心指南支持供电、散热和IT负载共同考虑。",14)
	p._text("同起点对照",20,UI.MINT)
	if program.worlds.worlds.size()<3: p._button("复制城市为独立实验",func(): p._do("fork"),false,p.replay_index>=0)
	else: p._button("两个实验同步推进10秒",func(): p._do("step_pair"),false,p.replay_index>=0 or not program.worlds.can_step_pair())
	if world.mode=="experiment": p._button("重置城市实验 · 回到起点",func(): p._do("reset_trial"),false,p.replay_index>=0)
	p._events(world)
static func live(p) -> void:
	if p.modern_widgets.is_empty(): return
	var w=p.display_snapshot().modern; var rules=p.state.planet.worlds.modern.rules
	var phase=posmod(int(w.elapsed),int(rules.day.period)); var day="夜晚" if phase>=rules.day.daylight else "云影经过" if phase>=rules.day.cloud_start and phase<rules.day.cloud_end else "白昼"
	p.modern_widgets.status.text="%s · 周期%d / %d秒\n光照 %.0f W/m² · 光伏 %.0f W\n储能 %.1f / %.0f kJ\n充电 %.0f W / 放电 %.0f W\n居民用电 %.0f W · 服务 %.0f\n计算 %.0f W · 风冷 %.0f W" % [day,phase,int(rules.day.period),w.irradiance,w.solar_W,w.battery_J/1000,float(rules.battery.capacity_J)/1000,w.charge_W,w.discharge_W,w.flow.homes,w.service,w.flow.compute,w.flow.fan]
	p.modern_widgets.jobs.text="%s · %.0f / %.0f工时\n%s · 积热 %.1f kJ\n照明调度余%d秒 / 冷却排程余%d秒\n累计完成 %d 项 · 过热停机 %d 次" % [rules.jobs[w.job.kind].name,w.job.progress,rules.jobs[w.job.kind].work,"冷却等待" if w.tripped else ("计算暂停" if not w.running else "等待设备/人员/电力" if w.flow.compute<=0 else "正在计算"),w.heat_J/1000,maxi(0,w.boost_until.lighting-w.elapsed),maxi(0,w.boost_until.cooling-w.elapsed),w.completed.lighting+w.completed.cooling,w.trips]
	var lines=[]
	for id in rules.solar:
		var panel=w.panels[id]; lines.append("%s：%s" % [rules.names[id],"未安装" if panel.recipe.is_empty() else "%s · 保留性能%.0f%%" % [rules.panels[panel.recipe].name,panel.quality*100]])
	lines.append("散热芯："+(("铜铝分层模型 · " if w.custom_sink.basis=="family_model" else "玩家假设 · ")+str(w.custom_sink.id).right(5) if not w.get("custom_sink",{}).is_empty() else "未安装" if w.sink.is_empty() else str(rules.sinks[w.sink].name)))
	lines.append("废构件 %.1f / 再生件 %.1f / 残渣 %.1f\n回收 %.0f / %.0f工时 · 公园%s" % [w.scrap,w.parts,w.residue,w.recycle_progress,rules.recycling.work,"已建成" if w.park else "施工%.0f / %.0f" % [w.park_progress,rules.recycling.park_work]])
	for person in w.people:
		var target=person.route[-1] if not person.route.is_empty() else person.at
		lines.append("居民%d · %s%s" % [person.id+1,"前往" if not person.route.is_empty() else "驻留",rules.names[target]])
	p.modern_widgets.materials.text="\n".join(lines)
	if p.modern_widgets.has("ledger"):
		p.modern_widgets.ledger.text="累计 kJ\n入射光 %.1f = 发电 %.1f + 未转电 %.1f\n电负载 %.1f / 弃电 %.1f\n充入 %.1f / 放出 %.1f / 储能损耗 %.1f\n计算热 %.1f = 积热 %.1f + 散出 %.1f\n再生件 %.1f / 建园耗用 %.1f\n残渣 %.1f（不自动消失）" % [w.sun_J/1000,w.pv_J/1000,w.unconverted_J/1000,w.load_J/1000,w.curtailed_J/1000,w.charged_J/1000,w.discharged_J/1000,w.battery_loss_J/1000,w.compute_J/1000,w.heat_J/1000,w.removed_heat_J/1000,w.recovered,w.park_spent,w.residue]
