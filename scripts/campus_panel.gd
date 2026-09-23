extends Control
## Campus UI delegates all transactions to the model facade.
signal changed(message: String)
signal dismissed
signal factory_requested
const UI=preload("res://scripts/ui.gd")
var state
var selected_plot=-1
var current_tab="overview"
var body: VBoxContainer
var scroll: ScrollContainer
var title: Label
var clock_label: Label
var prop_choice="flower"
var live_labels: Array=[]
var live_quotes: Array=[]
var refresh_clock=0.0
var scroll_memory=preload("res://scripts/panel_scroll.gd").new()

func setup(model, plot: int=-1) -> void:
	state=model; selected_plot=plot
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background=ColorRect.new(); background.color=UI.BG; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var panel=UI.box(self,Rect2(30,24,1380,850))
	var outer=UI.column(panel,12)
	var head=UI.row(outer)
	title=UI.label("科研小镇 · 每个人都有自己的生活",26,UI.MINT); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; head.add_child(title)
	head.add_child(UI.button("回到小岛",_close))
	head.add_child(UI.button("工艺车间",func(): factory_requested.emit()))
	clock_label=UI.label("",15,UI.GOLD); outer.add_child(clock_label)
	var tabs=UI.row(outer)
	for entry in [["overview","小镇概览"],["people","居民与招募"],["build","建筑与庭院"],["research","团队研发"],["requests","居民心愿"]]:
		var button=UI.button(entry[1],_show.bind(entry[0])); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tabs.add_child(button)
	scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; outer.add_child(scroll)
	body=UI.column(scroll,12); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_show("overview")

func _show(tab: String, keep_position: bool=false) -> void:
	scroll_memory.refresh(scroll,not keep_position)
	current_tab=tab; UI.clear(body); live_labels.clear(); live_quotes.clear()
	match tab:
		"overview": _overview()
		"people": _people()
		"build": _buildings()
		"research": _research()
		"requests": _requests()
	_update_live()

func _card(heading: String) -> VBoxContainer:
	var panel=PanelContainer.new(); body.add_child(panel)
	var content=UI.column(panel,8); content.add_child(UI.paragraph(heading,22,UI.MINT)); return content

func _overview() -> void:
	body.add_child(UI.paragraph("工程师去工地施工、维护或送餐；教授在公寓、食堂和科研院所之间生活，博士按性格去公园休息，院士专注住宅与研究所。小路连通后，居民才能使用建筑。",18,UI.TEXT))
	var context: Dictionary=state.campus_context()
	var counts=[]
	for role in state.campus.config.roles: counts.append("%s %d人" % [state.campus.role_data(role).name,state.campus.role_count(role)])
	body.add_child(UI.label("  ·  ".join(counts),21,UI.GOLD))
	var tasks=[
		["1. 收获第一份产物",state.total_harvests>0,"选择反应炉收获，积累金币和建材。"],
		["2. 给工程师一个家",not state.layout.buildings(state.plots).filter(func(b): return b.kind=="engineer_house").is_empty(),"点击空地，建工程师小窝并铺路。"],
		["3. 建科研院所",not context.buildings.filter(func(b): return b.kind=="institute" and b.connected).is_empty(),"院所需要小路连接迎客广场。"],
		["4. 招募博士",state.campus.role_count("doctor")>0,"先建博士公寓；住房和院所都要有空位。"],
		["5. 开展第一个课题",not state.campus.unlocked_materials.is_empty(),"1名博士生可研究基础配方；进阶课题需要院士和2名博士生，教授可带队提效。"]]
	for item in tasks:
		var card=_card(("已完成 · " if item[1] else "进行中 · ")+item[0]); card.add_child(UI.paragraph(item[2],16))
	body.add_child(UI.paragraph("游戏一天8分钟。全岛每天最多3条心愿，同一人至少隔一天再提；可以暂缓，不会不断弹窗。当前只在小镇面板查看心愿。",16,UI.LILAC))

func _people() -> void:
	var context: Dictionary=state.campus_context()
	var finances=UI.paragraph("",18,UI.GOLD); body.add_child(finances); live_labels.append({"kind":"payroll","label":finances})
	body.add_child(UI.paragraph("所有角色都有招募费和持续薪酬。按实际在岛时间计薪，每游戏日自动结算；离线不计薪。经费不足时记录欠薪，工作效率暂降至75%，补齐即恢复。博士生领取低额津贴。",16))
	body.add_child(UI.button("补发欠薪",func(): _done(state.campus_pay_arrears())))
	var hires=UI.row(body,10)
	for role in state.campus.config.roles:
		var info: Dictionary=state.campus.role_data(role)
		var quote: Dictionary=state.campus.quote_hire(role,context)
		var panel=PanelContainer.new(); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; hires.add_child(panel)
		var card=UI.column(panel,8); card.add_child(UI.label(info.name,21,UI.MINT)); card.add_child(UI.label("招募%d · 日薪%d" % [info.cost,info.daily_pay],18,UI.GOLD))
		card.add_child(UI.paragraph(info.description,14))
		var quote_label=UI.paragraph(quote.message,14); card.add_child(quote_label)
		var button=UI.button("招募入住",_hire.bind(role)); button.disabled=not quote.ready; card.add_child(button)
		live_quotes.append({"kind":"hire","id":role,"label":quote_label,"button":button})
	for usage in state.campus.housing_usage(context):
		body.add_child(UI.paragraph("%s · %s：%d / %d床位 · %s" % [state.plot_label(int(usage.plot)),state.campus.role_data(usage.role).name,usage.used,usage.capacity,"道路已连通" if usage.connected else "尚未连接广场"],15))
	for p in state.campus.people:
		var card=_card("%s  ·  %s  ·  擅长%s" % [p.name,state.campus.role_data(p.role).name,p.specialty])
		card.add_child(UI.paragraph("认真程度 %d%% · 休闲倾向 %d%% · 社交倾向 %d%%\n性格影响工作效率与日程；休息可以恢复心情。" % [roundi(float(p.traits.diligence)*100),roundi(float(p.traits.leisure)*100),roundi(float(p.traits.sociability)*100)],16))
		var activity=UI.paragraph("",17,UI.GOLD); card.add_child(activity); live_labels.append({"kind":"person","id":int(p.id),"label":activity})
		var posts=UI.row(card,8)
		for post in state.campus.posts_for(str(p.role)):
			posts.add_child(UI.button(str(state.campus.config.posts[post]),func(): _done(state.campus_assign_post(int(p.id),str(post))),p.post==post))
		card.add_child(UI.paragraph("住所："+(state.plot_label(int(p.home_plot)) if int(p.home_plot)>=0 else "旧居民临时宿舍（可建住宅安排入住）"),15))
		if int(p.get("supervisor_id",-1))>=0:
			var supervisor: Dictionary=state.campus.person(int(p.supervisor_id))
			if not supervisor.is_empty(): card.add_child(UI.label("导师："+str(supervisor.name),15,UI.LILAC))
		card.add_child(UI.button("请这位居民离岛…",_confirm_dismiss.bind(int(p.id))))

func _buildings() -> void:
	var picker=OptionButton.new(); picker.custom_minimum_size.y=44; picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(picker)
	var selected=0
	for i in range(state.plots.size()):
		if not state.plots[i].unlocked: continue
		if i==selected_plot: selected=picker.item_count
		var kind: String=state.plots[i].kind
		var label=state.layout.building_info(kind).get("name",{"empty":"空地","reactor":"反应炉","plaza":"迎客广场"}.get(kind,"装饰"))
		picker.add_item("%s · %s" % [state.plot_label(i),str(label)],i)
	picker.select(selected)
	if picker.item_count>0: selected_plot=picker.get_selected_id()
	picker.item_selected.connect(func(index): selected_plot=picker.get_item_id(index); _show("build"))
	if selected_plot<0: return
	var plot: Dictionary=state.plots[selected_plot]
	var connected=selected_plot in state.layout.reachable(state.plots)
	body.add_child(UI.paragraph("道路已连接迎客广场" if connected else "此处还未连接迎客广场，请把相邻地块的小路连起来。",18,UI.MINT if connected else UI.GOLD))
	var road=UI.button("铺设连通小路 · %d金币" % int(state.layout.config.roads.cost),_road)
	road.disabled=bool(plot.get("road",false)); body.add_child(road)
	if plot.kind=="empty":
		var building_choices: Array=state.layout.building_kinds()
		building_choices.erase("park"); building_choices.push_front("park")
		for kind in building_choices:
			var info: Dictionary=state.layout.building_info(kind)
			var card=_card("%s · %d金币 · 初始容量%d人" % [info.name,info.cost,info.capacity])
			card.add_child(UI.paragraph(info.description,15)); card.add_child(UI.button("在所选地块建造",_build.bind(kind)))
	else:
		var info: Dictionary=state.layout.building_info(plot.kind)
		if not info.is_empty():
			var level=int(plot.get("building_level",1))
			body.add_child(UI.label("%s · %d层 · 容量%d人" % [info.name,level,state.layout.capacity(plot)],22,UI.MINT))
			var upgrade=UI.button("改造至下一层 · %d金币" % (int(info.upgrade_cost)*level),_upgrade)
			upgrade.disabled=level>=int(info.max_level); body.add_child(upgrade)
			if plot.kind=="workshop": body.add_child(UI.button("进入工艺车间 · 制造材料",func(): factory_requested.emit(),true))
	if plot.kind=="plaza":
		body.add_child(UI.paragraph("公共交通入口保留通行空间；可在广场外的地块布置道路、护栏与庭院。",18)); return
	body.add_child(UI.label("庭院小物件 · 与主建筑共用地块",23,UI.LILAC))
	var choices=GridContainer.new(); choices.columns=3; body.add_child(choices)
	for kind in state.layout.config.props:
		var info: Dictionary=state.layout.config.props[kind]
		choices.add_child(UI.button("%s %d金币%s" % [info.name,info.cost," · 已选" if kind==prop_choice else ""],_pick_prop.bind(kind)))
	body.add_child(UI.paragraph("成就杯：完成3次交付后解锁。小物件位于建筑外围8个位置，不占整块土地；收纳存入工具箱，再次摆放免费。",15))
	var positions=["西北角","北侧","东北角","东侧","东南角","南侧","西南角","西侧"]
	for slot in range(8):
		var existing=""
		for prop in plot.get("props",[]):
			if int(prop.slot)==slot: existing=prop.kind
		var row=UI.row(body); var label=UI.label(positions[slot]+" · "+("空位" if existing.is_empty() else str(state.layout.config.props[existing].name)),17); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
		row.add_child(UI.button("摆放所选物件" if existing.is_empty() else "收入工具箱",_prop.bind(slot,existing.is_empty())))

func _research() -> void:
	body.add_child(UI.paragraph("博士生承担研发，基础课题可独立开展；每名院士同时主持一个进阶课题。教授在部分基础课题中可选，在分层方法等课题中必需；到岗时让同课题博士生效率提升50%（最多4人），每人只参加一个课题。研究解锁工艺能力；换元素是博士的装炉任务，键长仍由你调整。",18,UI.TEXT))
	var capacity=UI.label("",20,UI.GOLD); body.add_child(capacity); live_labels.append({"kind":"capacity","label":capacity})
	for job in state.campus.research_jobs:
		var label=UI.paragraph("",19,UI.MINT); body.add_child(label); live_labels.append({"kind":"job","id":int(job.id),"label":label})
	for project in state.campus.config.projects:
		if state.campus.config.projects[project].get("legacy",false): continue
		var quote: Dictionary=state.campus.quote_research(project,state.campus_context())
		var info: Dictionary=state.campus.config.projects[project]
		var card=_card(info.name)
		var requirements=[]
		for role in info.requires: requirements.append("%s%d人" % [state.campus.role_data(role).name,info.requires[role]])
		card.add_child(UI.paragraph(" + ".join(requirements)+"\n%d金币 · %d有效研究秒（生活日程会影响完成时间）" % [info.cost,info.seconds],18,UI.GOLD))
		if info.get("optional",{}).has("professor"): card.add_child(UI.paragraph("可选教授1名 · 有空闲导师时自动加入",15,UI.LILAC))
		card.add_child(UI.paragraph(info.note,15))
		var quote_label=UI.paragraph(quote.message,16,UI.LILAC); card.add_child(quote_label)
		var button=UI.button("安排团队研发",_start_research.bind(project)); button.disabled=not quote.ready; card.add_child(button)
		live_quotes.append({"kind":"research","id":project,"label":quote_label,"button":button})

func _requests() -> void:
	body.add_child(UI.paragraph("他们也有生活目标。暂缓不会扣心情，过期会自然收起。家庭探亲是临时小聚，不产生额外永久居民或虚假床位。",17))
	if state.campus.pending_requests.is_empty(): body.add_child(UI.label("今天还没有待处理的心愿。",23,UI.MINT))
	for request in state.campus.pending_requests:
		var person: Dictionary=state.campus.person(int(request.person_id))
		var info: Dictionary=state.campus.config.events.types[request.kind]
		var card=_card(str(person.get("name","居民"))+" · "+str(info.title))
		card.add_child(UI.paragraph("%s\n满足需要%d金币，心情增加%d。" % [info.detail,info.cost,info.morale],17))
		var row=UI.row(card)
		for entry in [["accept","帮助完成"],["later","暂缓处理"],["decline","婉拒请求"]]: row.add_child(UI.button(entry[1],_resolve.bind(int(request.id),entry[0])))

func _update_live() -> void:
	clock_label.text="第%d天 · %02d:%02d  |  金币%d  |  居民%d / %d  |  待处理心愿%d" % [int(state.campus.elapsed/float(state.campus.config.day_seconds))+1,int(state.campus.day_time/float(state.campus.config.day_seconds)*24),int(fmod(state.campus.day_time/float(state.campus.config.day_seconds)*1440,60)),int(state.coins),state.campus.people.size(),int(state.campus.config.max_people),state.campus.pending_requests.size()]
	for item in live_quotes:
		if not is_instance_valid(item.button): continue
		var quote: Dictionary=state.campus.quote_hire(item.id,state.campus_context()) if item.kind=="hire" else state.campus.quote_research(item.id,state.campus_context())
		item.label.text=quote.message; item.button.disabled=not quote.ready
	for item in live_labels:
		if not is_instance_valid(item.label): continue
		if item.kind=="payroll":
			item.label.text="预计每日薪酬 %.0f金币 · 本期累计 %.1f · 欠薪 %.1f · 下次结算 %d秒" % [state.payroll.daily_cost(state.campus.people,state.campus.config.roles),state.payroll.accrued,state.payroll.arrears,ceili(float(state.campus.config.payroll.period_seconds)-state.payroll.clock)]
		elif item.kind=="capacity":
			var capacity: Dictionary=state.campus.research_capacity()
			item.label.text="进阶课题 %d / %d · 每名院士提供1个主持名额（本版提供2项进阶课题）" % [capacity.active,capacity.capacity]
		elif item.kind=="person":
			var p: Dictionary=state.campus.person(item.id)
			if not p.is_empty():
				var activity=("沿小路前往"+state.plot_label(int(p.target_plot))) if p.get("moving",false) else str(p.activity_label)
				item.label.text="%s · 心情%d · 饥饿%d · 效率%.0f%%" % [activity,roundi(p.morale),roundi(p.hunger),state.campus.person_efficiency(item.id)*100]
		else:
			for job in state.campus.research_jobs:
				if int(job.id)==item.id: item.label.text="%s · %.0f%% · %s" % [state.campus.config.projects[job.template_id].name,float(job.progress)/float(job.required)*100,{"working":"研发中","resting":"团队休息中","waiting_team":"等待补员","waiting_institute":"等待连通院所","complete":"配方已解锁"}.get(job.status,job.status)]

func _done(message: String) -> void:
	changed.emit(message)
	_show(current_tab,true)
func _hire(role: String) -> void: _done(state.campus_hire(role))
func _build(kind: String) -> void: _done(state.campus_build(selected_plot,kind))
func _upgrade() -> void: _done(state.campus_upgrade(selected_plot))
func _road() -> void: _done(state.campus_road(selected_plot))
func _pick_prop(kind: String) -> void: prop_choice=kind; _show("build",true)
func _prop(slot: int, empty: bool) -> void: _done(state.campus_prop(selected_plot,slot,prop_choice) if empty else state.campus_remove_prop(selected_plot,slot))
func _resolve(id: int, choice: String) -> void: _done(state.campus_resolve_request(id,choice))
func _start_research(project: String) -> void: _done(state.campus_start_research(project))
func _confirm_dismiss(id: int) -> void:
	var person: Dictionary=state.campus.person(id)
	scroll_memory.refresh(scroll,true)
	UI.clear(body); live_labels.clear()
	body.add_child(UI.label("确认请%s离岛？" % person.get("name","这位居民"),27,UI.GOLD))
	body.add_child(UI.paragraph("招募费用不退还，床位会空出；其所在研发团队将等待补员。",19))
	body.add_child(UI.button("确认解约并离岛",func(): _done(state.campus_dismiss(id))))
	body.add_child(UI.button("保留这位居民",_show.bind("people"),true))
func _process(delta: float) -> void:
	if state==null: return
	refresh_clock+=delta
	if refresh_clock>=1: refresh_clock=0; _update_live()
func handle_back() -> bool:
	_close(); return true
func _close() -> void:
	dismissed.emit(); queue_free()
