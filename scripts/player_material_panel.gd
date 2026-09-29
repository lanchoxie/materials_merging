extends RefCounted
const UI=preload("res://scripts/ui.gd")
static func menu(parent: Node) -> OptionButton:
	var select=OptionButton.new(); select.mouse_filter=Control.MOUSE_FILTER_PASS; select.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE; select.custom_minimum_size=Vector2(0,44); select.size_flags_horizontal=Control.SIZE_EXPAND_FILL; select.fit_to_longest_item=false; parent.add_child(select); return select
static func build(p) -> void:
	var program=p.state.planet; var archive=program.materials; var f=archive.fixture
	p._text("我的材料档案",23,UI.LILAC)
	p._text("留存结构 → 选择方法 → 制作与用途",16,UI.TEXT)
	var tabs=UI.row(p.body,6)
	for item in [[false,"自由假设"],[true,"铜铝分层研发"]]: tabs.add_child(UI.button(item[1],func(): p.dossier_family=item[0]; p._redraw(),p.dossier_family==item[0]))
	if not program.joined: p._button("领取合作与首次供料",func(): p._do("join"),true); return
	var batches=p.state.storage.batches
	if not batches.is_empty():
		var choose=menu(p.body); choose.add_item("选择仓库样品 · 留档消耗1份")
		for batch in batches: choose.add_item("%s ×%d" % [batch.name,batch.quantity]); choose.set_item_metadata(choose.item_count-1,batch.id)
		choose.item_selected.connect(func(i):
			if i>0:
				var id=str(choose.get_item_metadata(i)); var source=p.state.storage.batch(id)
				if not source.is_empty(): p.dossier_id=archive.identity(source.work); p.dossier_draft=f.unknown()
				p._do("archive_material",{"batch_id":id}))
	else: p._text("先在浮岛收集反应炉完成的样品，再来留档。",15)
	if archive.records.is_empty():
		p._text("未知结构也能留档。档案保留原子位置与连接；名字相同不代表同一种结构。",16,UI.TEXT)
		p.view.player_view.show_record({},p.state.elements); return
	if not archive.records.has(p.dossier_id): p.dossier_id=str(archive.records.keys()[-1])
	var records=menu(p.body)
	for id in archive.records:
		records.add_item(str(archive.records[id].name)+" · "+id.substr(0,6)); records.set_item_metadata(records.item_count-1,id)
		if id==p.dossier_id: records.select(records.item_count-1)
	records.item_selected.connect(func(i): p.dossier_id=str(records.get_item_metadata(i)); p.dossier_draft=f.unknown(); p._redraw())
	var record=archive.records[p.dossier_id]
	p.view.player_view.show_record(record,p.state.elements)
	p._text("%s · %d个原子" % [record.formula,record.work.atoms.size()],21,UI.MINT)
	p._text("结构指纹 "+record.id.substr(0,12)+"\n"+("几何身份匹配："+str(p.state.templates.get(record.reference,{}).get("name",record.reference)) if not record.reference.is_empty() else "身份：未匹配参考的玩家作品"),14)
	p._text("原始结构物性仍未知；下面的模型只适用于另行装配的标准层料构件。" if p.dossier_family else "档案物性：密度、导热率、电阻率均未知。身份匹配与键长分数不能证明这些性质。",15,UI.GOLD)
	if p.dossier_family: preload("res://scripts/laminate_panel.gd").build(p,record); return
	p.view.player_view.hide_laminate()
	p._text("建立一个有条件的方案",20,UI.LILAC)
	var kind=menu(p.body)
	for item in [["sink","散热芯计算"],["wire","导线计算"]]: kind.add_item(item[1]); kind.set_item_metadata(kind.item_count-1,item[0])
	kind.select(0 if p.dossier_kind=="sink" else 1)
	kind.item_selected.connect(func(i): p.dossier_kind=str(kind.get_item_metadata(i)); p._redraw())
	var row=UI.row(p.body,6)
	for item in [["same_size","同尺寸"],["same_mass","同重量"]]: row.add_child(UI.button(item[1],func(): p.dossier_mode=item[0]; p._redraw(),p.dossier_mode==item[0]))
	p._text("热学：295 K、长10 cm；定截面1 cm²或定重54 g。" if p.dossier_kind=="sink" else "电学：293.15 K、往返40 m；定截面2.5 mm²或定重889 g。",14)
	var required="conductivity_W_mK" if p.dossier_kind=="sink" else "resistivity_ohm_m"
	for key in ["density_kg_m3",required]:
		var spec=f.rules.properties[key]; var scale=1e9 if key=="resistivity_ohm_m" else 1.0
		p._text("假设"+str(spec.name)+"（"+("nΩ·m" if scale>1 else str(spec.unit))+"）",15,UI.TEXT)
		row=UI.row(p.body,6)
		var known=CheckButton.new(); known.mouse_filter=Control.MOUSE_FILTER_PASS; known.text="填写"; known.button_pressed=p.dossier_draft[key]!=null; row.add_child(known)
		var input=SpinBox.new(); input.min_value=float(spec.min)*scale; input.max_value=float(spec.max)*scale; input.step=.01 if key!="density_kg_m3" else 1; input.allow_greater=false; input.custom_minimum_size=Vector2(155,44); row.add_child(input)
		input.editable=known.button_pressed; input.value=float(spec.min)*scale if p.dossier_draft[key]==null else float(p.dossier_draft[key])*scale
		input.value_changed.connect(func(v): p.dossier_draft[key]=v/scale; update_quote(p))
		known.toggled.connect(func(on): input.editable=on; p.dossier_draft[key]=input.value/scale if on else null; update_quote(p))
	p.dossier_quote=UI.paragraph("",15,UI.MINT); p.body.add_child(p.dossier_quote)
	p.dossier_save=p._button("保存假设方案",func(): p._do("propose_material",{"record_id":p.dossier_id,"kind":p.dossier_kind,"mode":p.dossier_mode,"properties":p.dossier_draft}),true)
	update_quote(p)
	p._text("输入由你假设；结果是条件计算，不是实测，也不验证结构稳定性。原始档案仍标为未知。",14,UI.GOLD)
	p._text("已保存方案",20,UI.LILAC)
	var count=0
	for id in archive.designs:
		var d=archive.designs[id]
		if d.record_id!=p.dossier_id or d.basis!="player_hypothesis": continue
		count+=1
		p._text("假设密度 %.0f kg/m³；%s\n截面 %.3f mm² · 质量 %.2f g" % [d.properties.density_kg_m3,"导热率 %.2f W/(m·K) · 295 K" % d.properties.conductivity_W_mK if d.kind=="sink" else "电阻率 %.3f nΩ·m · 293.15 K" % (d.properties.resistivity_ohm_m*1e9),d.result.area_m2*1e6,d.result.mass_kg*1000],14)
	if count==0: p._text("尚无方案。填写所需性质后可保存。",14)
	p._text("假设方案只保存条件计算，不生成可出售库存，也不能当作已验证材料投放星球。",14)
	p._text("铜/铝参考在「导热对照」和「导线对照」中。毒性、比热、强度、带隙、寿命和误差仍未知。",14)

static func update_quote(p) -> void:
	if not is_instance_valid(p.dossier_quote): return
	var r=p.state.planet.materials.fixture.calculate(p.dossier_kind,p.dossier_mode,p.dossier_draft)
	p.dossier_save.disabled=r.is_empty()
	if r.is_empty(): p.dossier_quote.text="所需性质未知，暂不能计算。勾选填写后，输入你的假设。"; return
	var units="截面 %.3f mm² · 质量 %.2f g\n" % [r.area_m2*1e6,r.mass_kg*1000]
	p.dossier_quote.text=units+("构件热导 %.4f W/K\n含接触/外部热阻 %.4f W/K" % [r.conductance_W_K,r.assembly_conductance_W_K] if p.dossier_kind=="sink" else "往返电阻 %.4f Ω" % r.resistance_ohm)
