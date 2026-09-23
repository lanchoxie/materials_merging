extends Control
signal dismissed
signal acted(message: String)
signal mail_requested
signal planet_requested
signal synthesis_requested
signal campus_requested(tab: String)
const UI=preload("res://scripts/ui.gd")
const WorkshopAccess=preload("res://scripts/workshop_access.gd")
var state
var view
var body: VBoxContainer
var scroll: ScrollContainer
var status: Label
var caption: Label
var progress: ProgressBar
var progress_text: Label
var laminate_progress: Label
var section="workshop"
var selected_recipe="standard_water_crate"
var material_mode="same_size"
var material_details=false
var circuit_mode="same_size"
var dossier_family=true
var laminate_orientation="parallel"
var laminate_details=false
var dossier_id=""
var dossier_kind="sink"
var dossier_mode="same_size"
var dossier_draft={"density_kg_m3":null,"conductivity_W_mK":null,"resistivity_ohm_m":null}
var dossier_quote: Label
var dossier_save: Button
var fingerprint=""
var clock=0.0
var recipe_menu: OptionButton
var workshop_status: Label
var scroll_memory=preload("res://scripts/panel_scroll.gd").new()

func setup(model) -> void:
	state=model; dossier_draft=state.planet.materials.fixture.unknown()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var title=UI.label("工艺车间 · 材料制造",30,UI.MINT); title.position=Vector2(28,24); add_child(title)
	var close=UI.button("返回浮岛",_close); close.position=Vector2(1288,22); close.size=Vector2(124,48); add_child(close)
	var nav=UI.row(self,10); nav.position=Vector2(28,98)
	for item in [["workshop","生产车间"],["dossiers","我的材料"],["materials","导热对照"],["circuits","导线对照"]]:
		nav.add_child(UI.button(item[1],_section.bind(item[0])))
	nav.add_child(UI.button("进入星球",func(): planet_requested.emit(),true))
	var box=SubViewportContainer.new(); box.position=Vector2(28,164); box.size=Vector2(770,602); box.stretch=true; add_child(box)
	var viewport=SubViewport.new(); viewport.size=Vector2i(770,602); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; box.add_child(viewport)
	view=preload("res://scripts/factory_view.gd").new(); viewport.add_child(view)
	var turn=UI.row(self,10); turn.position=Vector2(48,707)
	turn.add_child(UI.button("↶",func(): view.rotate_display(-0.4)))
	turn.add_child(UI.button("↷",func(): view.rotate_display(0.4)))
	caption=UI.paragraph("",17,UI.MUTED); caption.position=Vector2(38,783); caption.size=Vector2(750,64); add_child(caption)
	var right=UI.box(self,Rect2(822,98,590,741)); var col=UI.column(right,12)
	workshop_status=UI.paragraph("",16,UI.GOLD); col.add_child(workshop_status)
	var management=UI.row(col,8)
	management.add_child(UI.button("建造 / 连通车间",func(): campus_requested.emit("build")))
	management.add_child(UI.button("安排工程师",func(): campus_requested.emit("people")))
	recipe_menu=OptionButton.new(); recipe_menu.custom_minimum_size=Vector2(0,46); recipe_menu.fit_to_longest_item=false; col.add_child(recipe_menu)
	recipe_menu.add_item("选择制造配方…")
	for id in WorkshopAccess.recipe_ids(state.planet):
		recipe_menu.add_item(str(state.planet.recipe(id).name)); recipe_menu.set_item_metadata(recipe_menu.item_count-1,id)
	recipe_menu.item_selected.connect(func(i):
		if i>0: _choose_recipe(str(recipe_menu.get_item_metadata(i))))
	scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; col.add_child(scroll)
	body=UI.column(scroll,12); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status=UI.paragraph("生产消耗供料，成品进入同一个工具箱。",15,UI.GOLD); status.position=Vector2(32,859); status.size=Vector2(1370,36); add_child(status)
	_redraw()

func _section(id: String) -> void:
	section=id; _redraw(true)

func _open_dossiers() -> void:
	_section("dossiers")

func _open_materials() -> void:
	_section("materials")

func _choose_recipe(id: String) -> void:
	if state.planet.recipe(id).is_empty(): return
	recipe_menu.select(0)
	for i in range(1,recipe_menu.item_count):
		if recipe_menu.get_item_metadata(i)==id: recipe_menu.select(i); break
	selected_recipe=id; _section("workshop")

func _key() -> String:
	var p=state.planet; var batches=[]; var research=[]
	var affordable=state.coins>=float(p.recipe(selected_recipe).get("fee",0))
	for batch in state.storage.batches: batches.append([batch.id,batch.quantity])
	for job in state.campus.research_jobs: research.append([job.id,int(job.progress)/5])
	return str([affordable,WorkshopAccess.status(state).ready,p.production_mode,p.joined,p.qualified,p.extra_qualifications,p.reports,p.circuit_reports,p.products.size(),p.job.get("id",0),p.supplies,p.feed,p.v2.field.stock,p.materials.records.size(),p.materials.designs.size(),p.laminates.stock,p.laminates.feed,p.laminates.job.get("id",0),state.campus.unlocked_materials,research,batches])

func _redraw(reset_scroll: bool=false) -> void:
	scroll_memory.refresh(scroll,reset_scroll)
	UI.clear(body); fingerprint=_key(); view.set_mode(section)
	match section:
		"dossiers": preload("res://scripts/player_material_panel.gd").build(self)
		"materials": view.material_view.set_mode(material_mode); preload("res://scripts/material_lab_panel.gd").build(self)
		"circuits": _circuits()
		_:
			view.show_product(selected_recipe)
			if state.planet.materials.designs.get(selected_recipe,{}).get("basis")=="family_model":
				view.set_mode("dossiers"); var d=state.planet.materials.designs[selected_recipe]
				view.player_view.show_record(state.planet.materials.records[d.record_id],state.elements); view.player_view.show_laminate(d)
			_workshop()
	_live()

func _text(text: String,size: int=16,color: Color=UI.MUTED) -> void:
	body.add_child(UI.paragraph(text,size,color))

func _button(text: String,callback: Callable,primary: bool=false,disabled: bool=false) -> Button:
	var button=UI.button(text,callback,primary); button.disabled=disabled; body.add_child(button); return button

func _circuits() -> void:
	var p=state.planet; var mode=circuit_mode
	_text("铜与铝 · 导线计算",23,UI.MINT)
	var row=UI.row(body,8)
	for value in ["same_size","same_mass"]: row.add_child(UI.button("同截面" if value=="same_size" else "同重量",func(): circuit_mode=value; _redraw()))
	for id in ["copper","aluminum"]:
		var d=p.electrical.calculate(id,mode)
		_text("%s · 往返电阻 %.4f Ω · 材料 %.1f g" % ["铜" if id=="copper" else "铝",d.resistance_ohm,d.mass_kg*1000],18,UI.TEXT)
	_text("20°C恒温直流模型。参考材料的密度与电阻率，不能直接赋给玩家未知结构。",15)
	if not p.joined: _button("领取合作与首次供料",func(): _do("join"),true)
	elif not p.circuit_reports.has(mode): _button("记录导线对照",func(): _do("compare_circuits",{"mode":mode}),true)
	else: _text("已保存对照结果。新的星球设备用途会逐步接入。",16,UI.MINT)

func _do(action: String,payload: Dictionary={}) -> void:
	if action=="pack": payload=payload.duplicate(); payload.production_mode="island"
	var message=state.planet.command(state,action,payload)
	status.text=message; acted.emit(message); _redraw()

func _live() -> void:
	var p=state.planet
	var access=WorkshopAccess.status(state)
	workshop_status.text="已连通车间 %d · 生产岗位 %d人 · 到岗效率 %.2f倍\n%s" % [access.connected,access.assigned,access.rate,access.message]
	caption.text="留存原始结构，保存模型依据；制造出的成品归入工具箱。" if section=="dossiers" else "工艺车间加工 → 工具箱收纳 → 星球搭建 / 订单交付"
	if is_instance_valid(laminate_progress) and not p.laminates.job.is_empty(): laminate_progress.text="本岛装配 · 余%.1f工秒\n工程师到岗速率 %.2f倍" % [p.laminates.job.left,state.campus.industrial_rate(state.campus_context())]
	if is_instance_valid(progress) and not p.job.is_empty():
		progress.value=100*(1-float(p.job.left)/float(p.job.duration)); progress_text.text="%s · 余%d秒标准工时" % [p.recipe(str(p.job.recipe)).name,ceili(float(p.job.left))]

func _process(dt: float) -> void:
	if state==null: return
	clock+=dt
	if clock<0.5: return
	clock=0
	if fingerprint!=_key(): _redraw()
	else: _live()

func handle_back() -> bool:
	_close(); return true

func _close() -> void:
	dismissed.emit(); queue_free()

func _workshop() -> void:
	var p=state.planet; var rules=p.config.workshop
	if p.materials.designs.get(selected_recipe,{}).get("basis")=="family_model": preload("res://scripts/laminate_panel.gd").workshop(self,selected_recipe); return
	var info=p.recipe(selected_recipe); var ref=str(info.reference)
	if info.has("natural_inputs"):
		_natural_workshop(info); return
	if not p.joined:
		_text("第一封星际来信",23,UI.MINT)
		_text("把浮岛的结构样品变成有用途的成品，在星球上观察它们带来的变化。",17,UI.TEXT)
		_text("领取%d份标准供料，在本岛工艺车间安排工程师加工。不需要先招募院士。" % int(rules.starter_feed))
		_button("领取合作与首次供料",func(): _do("join"),true)
		return
	_text(str(info.name),23,UI.MINT); _text(str(p.v2.rules.products.get(selected_recipe,info).description),16,UI.TEXT)
	var access=WorkshopAccess.status(state)
	_text("本岛工艺车间加工；工程师行路、用餐和休息时暂停，预留材料不会丢失。",14)
	if not p.job.is_empty() and p.production_mode=="partner": _text("旧合作订单正在继续完成；下一笔新订单交由本岛车间。",15,UI.GOLD)
	if selected_recipe=="frame_bundle": _text("星球用途：1包可搭8块木构，也可整体用作动物围栏；两种用法共用这一件成品。",15,UI.MINT)
	elif selected_recipe in ["modern_silicon","modern_perovskite"]: _text("星球用途：安装1块光伏构件，支持聚落生态站的白天供能。",15,UI.MINT)
	if ref.begins_with("circuit:") and not p.qualified_for(ref):
		_text("先在导线对照记录同截面或同重量的结果。",17,UI.GOLD)
		_button("打开导线对照",func(): section="circuits"; _redraw(),true); return
	if ref.begins_with("fixture:") and not p.qualified_for(ref):
		_text("先到材料对照台选择约束，记录计算结果。",17,UI.GOLD)
		_button("打开材料对照",_open_materials,true)
		return
	if not p.qualified_for(ref):
		var sample_name="水样" if ref=="water" else "氧气 O₂ 样品"
		_text("① 提交%s" % sample_name,21,UI.MINT)
		_text("需要同一批次的%d份已收集样品。身份验证消耗样品；批量供料另计。" % int(rules.samples_required))
		var candidates=p.sample_candidates(state,ref)
		if candidates.is_empty(): _text("在浮岛建造%s反应炉并收获，或在沙盒正确搭出对应结构。" % ("水分子" if ref=="water" else "氧气 O₂"),16,UI.GOLD)
		for batch in candidates:
			_button("提交%s · 库存%d份" % [sample_name,int(batch.quantity)],func(): _do("qualify",{"batch_id":str(batch.id),"reference":ref}),true,int(batch.quantity)<int(rules.samples_required))
	else:
		_text("② 准备供料与制作",21,UI.MINT)
		_text("1份供料 + %d金币 → 1件成品\n标准工时%d秒 · 由工程师到岗效率决定耗时" % [int(info.fee),int(info.seconds)],17,UI.TEXT)
		_text("供料 %d份  /  成品 %d件\n金币 %d" % [p.input_count(info.input),p.available_products(selected_recipe),int(state.coins)],18,UI.GOLD)
		if p.job.is_empty():
			_button(("开始装罐" if info.input=="feed" else "开始制作")+" · %d金币" % int(info.fee),func(): _do("pack",{"recipe":selected_recipe}),true,not access.ready or p.input_count(info.input)<1 or state.coins<float(info.fee))
		else:
			progress_text=UI.paragraph("",17,UI.MINT); body.add_child(progress_text)
			progress=ProgressBar.new(); progress.custom_minimum_size.y=12; progress.show_percentage=false; body.add_child(progress)
			_button("取消制作 · 退供料，费用不退",func(): _do("cancel_pack"))
	var input_info={"name":"标准水供料","price":int(rules.feed_cost)} if info.input=="feed" else p.config.supplies[info.input]
	_text("%s · 库存%d份" % [input_info.name,p.input_count(info.input)],16,UI.MINT)
	_button("补充1份供料 · %d金币" % int(input_info.price),func(): _do("buy_feed",{"input":info.input}))
	_text("工业构件采用295 K参考物性和已对照几何；供料包含对应预切件。它不是玩家分子的实测性能。" if ref.begins_with("fixture:") else "结构身份不等于宏观纯度。标准组件、气源与已充能模块由合作方供给。",14)
	if ref.begins_with("fixture:"): _button("更换设计 · 材料对照",_open_materials)
	if info.get("domain","") in ["watershed","village","habitat","industry","modern"]: _text("水样只用于合作入门资格；组件与供料规格由合作方提供，不由水分子几何推出。",14,UI.GOLD)
	_button("前往星球 · 使用现有成品",func(): planet_requested.emit(),true)

func _natural_workshop(info: Dictionary) -> void:
	if selected_recipe=="field_mixing_tank":
		_text("尿素由浮岛反应釜合成；这里制造用来配水的设备。",16,UI.MINT)
		_button("前往反应釜 · 合成尿素",func(): synthesis_requested.emit(),true)
	var p=state.planet; var access=WorkshopAccess.status(state); var field=p.v2.field
	_text(str(info.name),24,UI.MINT); _text(str(info.description),17,UI.TEXT)
	_text("星球采集 → 背包原料 → 工程师加工 → 回星球搭建",16,UI.GOLD)
	for id in info.natural_inputs:
		_text("%s  %d / %d份" % [field.rules.resources[id].name,field.stock[id],info.natural_inputs[id]],18,UI.MINT if int(field.stock[id])>=int(info.natural_inputs[id]) else UI.GOLD)
	_text("预留上述原料，标准工时%d秒。没有额外原料购买费；工程师继续按原规则领取薪酬。取消时原料全部退回。" % int(info.seconds),15)
	if not p.joined: _button("登记车间合作",func(): _do("join"),true)
	elif p.job.is_empty(): _button("加工采集材料",func(): _do("pack",{"recipe":selected_recipe}),true,not access.ready or not field.crafting_error(selected_recipe).is_empty())
	else:
		progress_text=UI.paragraph("",17,UI.MINT); body.add_child(progress_text)
		progress=ProgressBar.new(); progress.custom_minimum_size.y=12; progress.show_percentage=false; body.add_child(progress)
		_button("取消当前加工 · 退还预留材料",func(): _do("cancel_pack"))
	_text("主仓库：%d包；每包%d块，可在星球背包装备。" % [p.available_products(selected_recipe),p.v2.construction.rules.recipes[selected_recipe].units],17,UI.MINT)
	_button("前往星球 · 采集 / 使用成品",func(): planet_requested.emit(),true)

