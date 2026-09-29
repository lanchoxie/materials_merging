extends RefCounted
const UI=preload("res://scripts/ui.gd")
static func build(p,record: Dictionary) -> void:
	var program=p.state.planet; var workshop=program.laminates; var model=workshop.model
	p._text("铜铝层芯 · 选择传热方向",21,UI.MINT)
	var project=str(model.rules.project)
	if not workshop.unlocked(p.state):
		p._text("先研发热阻网络方法：教授1人指导博士2人，必须到达已连路的科研院所；休息、行路不计科研工时。",15)
		var job={}
		for item in p.state.campus.research_jobs:
			if item.template_id==project: job=item
		if job.is_empty():
			var q=p.state.campus.quote_research(project,p.state.campus_context())
			p._text(str(q.message),15,UI.GOLD)
			p._button("研发分层方法 · %d金币" % p.state.campus.config.projects[project].cost,func(): p._do("laminate_research"),true,not q.ready)
		else: p._text("团队进度 %.0f / %.0f工时\n当前到岗速率 %.2f倍" % [job.progress,job.required,p.state.campus.research_rate(job)],17,UI.GOLD)
		p._text("到浮岛的科研小镇招募人员、建院所与住宅；工资、吃饭和休息沿用日常规则。研发完成开放计算方法，不凭空创造实测数据。",14)
	var c=model.counts(record.work)
	if c.is_empty():
		p.view.player_view.hide_laminate()
		p._text("当前结构不适用：只接受同时含Cu、Al且没有其他元素的投料提案。",17,UI.GOLD)
		p._text("铜和铝已加入元素商店。去结构工坊搭一个铜铝作品，装炉、收集，再回到这里留档。其他作品仍可用假设实验。",15); return
	p._text("投料摩尔比 Cu : Al = %d : %d" % [c.Cu,c.Al],16,UI.MINT)
	var row=UI.row(p.body,6)
	for item in [["parallel","顺着层片"],["series","横穿层片"]]: row.add_child(UI.button(item[1],func(): p.laminate_orientation=item[0]; p._redraw(),p.laminate_orientation==item[0]))
	row=UI.row(p.body,6)
	for item in [["same_size","同尺寸"],["same_mass","同重量"]]: row.add_child(UI.button(item[1],func(): p.dossier_mode=item[0]; p._redraw(),p.dossier_mode==item[0]))
	var d=model.build(record.id,c,p.laminate_orientation,p.dossier_mode)
	p.view.player_view.show_laminate(d)
	p._text("构件热导 %.4f W/K\n截面 %.3f cm² · 质量 %.2f g\n方向导热率 %.1f W/(m·K)" % [d.result.conductance_W_K,d.result.area_m2*10000,d.result.mass_kg*1000,d.properties.conductivity_W_mK],16,UI.TEXT)
	p._button("保存模型方案",func(): p._do("propose_laminate",{"record_id":record.id,"orientation":p.laminate_orientation,"mode":p.dossier_mode}),true,not workshop.unlocked(p.state))
	for id in program.materials.designs:
		var saved=program.materials.designs[id]
		if saved.record_id!=record.id or saved.basis!="family_model": continue
		p._button("装配 "+model.name(saved),func(): p.section="workshop"; p._choose_recipe(id))
	p._button("收起方法说明" if p.laminate_details else "方法与适用范围",func(): p.laminate_details=not p.laminate_details; p._redraw())
	if p.laminate_details:
		p._text("将原子数比用作标准铜、铝层料的投料摩尔比，再由摩尔质量和密度换算体积分数。层片保持分离，原子坐标不认证合金晶相。",14)
		p._text("铜体积分数 %.1f%% · 模型密度 %.0f kg/m³\n两种理想方向 %.1f—%.1f W/(m·K)" % [d.volume_fraction_Cu*100,d.properties.density_kg_m3,d.bounds_W_mK[0],d.bounds_W_mK[1]],14)
		p._text("295 K常数物性、致密、无化学反应、层间理想接触。方向区间不是测量误差；不含界面阻力、腐蚀或寿命。电导率仍未知。",14,UI.GOLD)
		p._text("参考：NIST 295 K铜/铝密度与导热率；MIT串并联热阻；RSC原子量。模型结果用于游戏内合同，不等于现实产品认证。",14)

static func workshop(p,id: String) -> void:
	var program=p.state.planet; var factory=program.laminates; var d=program.materials.designs[id]; var r=factory.model.rules.manufacturing
	p._text(factory.model.name(d),22,UI.MINT)
	p._text("模型构件 · 标准层料装配\n来源提案 "+str(program.materials.records[d.record_id].name),16,UI.TEXT)
	p._text("每件预留 Cu %.2f g / Al %.2f g\n库存 Cu %.2f g / Al %.2f g\n成品库存 %d件 · %d标准工秒" % [d.feed_kg.Cu*1000,d.feed_kg.Al*1000,factory.feed.Cu*1000,factory.feed.Al*1000,factory.count(id),r.seconds],16)
	var row=UI.row(p.body,6)
	for element in ["Cu","Al"]: row.add_child(UI.button("%s %dg · %d金币" % [element,r.pack_kg*1000,r.feed_price[element]],func(): p._do("laminate_buy",{"element":element})))
	p._text("仅本岛工程师到工艺车间后加工。与其他本岛订单共用到岗人手，标准订单优先；合作工坊不代工新设计。",14)
	if factory.job.is_empty(): p._button("装配1件 · %d金币" % r.fee,func(): p._do("laminate_pack",{"design_id":id}),true)
	else:
		p.laminate_progress=UI.paragraph("",16,UI.GOLD); p.body.add_child(p.laminate_progress)
		p._button("取消装配 · 退回层料",func(): p._do("laminate_cancel"))
	p._button("查看我的材料",p._open_dossiers)
	p._text("构件可交给广场收购商；星球上的设备用途将逐步开放。",15)
	p._text("交付给广场收购商",20,UI.MINT)
	p._text("订单统一在浮岛邮箱。客人乘车到场后，亮起的头顶气泡可交付最合适的成品；缺货时点击气泡查看条件。",15)
	p._button("前往邮箱 · 查看性质订单",func(): p.mail_requested.emit(),true)
	if factory.cooldown>0: p._text("性质采购冷却还剩约%d秒；结束后等待下一轮来访。" % ceili(factory.cooldown),15,UI.GOLD)
