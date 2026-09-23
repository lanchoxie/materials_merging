extends RefCounted
const UI=preload("res://scripts/ui.gd")

static func build(p) -> void:
	var lab=p.state.planet.lab; var mode=p.material_mode
	p._text("铜与铝 · 导热构件计算",23,UI.MINT)
	p._text("空间有限，还是重量有限？\n换一个约束，材料的优势也会改变。",16,UI.TEXT)
	var row=UI.row(p.body,8)
	for entry in [["same_size","同尺寸"],["same_mass","同重量"]]:
		row.add_child(UI.button(entry[1],func(): p.material_mode=entry[0]; p.view.material_view.set_mode(entry[0]); p._redraw(),mode==entry[0]))
	p._text("均长10 cm、截面1 cm²" if mode=="same_size" else "均长10 cm、材料重54 g；允许截面改变",16,UI.GOLD)
	for id in ["copper","aluminum"]:
		var m=lab.data.materials[id]; var r=lab.calculate(id,mode)
		p._text("%s  %.1f g · %.3f W/K" % [m.name,r.mass_kg*1000,r.conductance_W_K],20,Color(m.color))
		p._text("参考导热率 %d W/(m·K)\n密度 %d kg/m³ · 295 K\n计算截面 %.3f cm² · 温差2 K时 %.3f W" % [m.conductivity_W_mK,m.density_kg_m3,r.area_m2*10000,r.heat_flow_W],14)
	p._text("同尺寸：铜的构件热导更高。" if mode=="same_size" else "同重量：铝可做得更粗，这个设计中热导更高。",17,UI.MINT)
	if not p.state.planet.joined:
		p._button("领取合作与首次供料",func(): p._do("join"),true)
	elif not p.state.planet.reports.has(mode):
		p._button("记录对照 · 开放对应构件",func(): p._do("compare_materials",{"mode":mode}),true)
	else:
		var designs=UI.row(p.body,8)
		for id in ["copper","aluminum"]:
			var key=id+("_compact" if mode=="same_size" else "_light")
			designs.add_child(UI.button("制作"+str(p.state.planet.recipe(key).name),func(): p.section="workshop"; p._choose_recipe(key)))
	p._text("按尺寸或重量约束比较构件，保存计算依据。星球设备的具体用途会逐步接入。",15,UI.TEXT)
	p._button("收起计算依据" if p.material_details else "查看计算依据与未知性质",func(): p.material_details=not p.material_details; p._redraw())
	if p.material_details:
		p._text("参考：NIST NCNR 295 K 金属物性。\n本例 G=kA/L，质量=ρAL；两端296/294 K、侧面绝热、常数导热率的一维稳态估算。流动光点表示热流，不是升温过程。",14)
		p._text("构件热导不能直接代表整机温度；接触、气流和设备几何还需要单独的模型。",14)
		p._text("比热、电导率、毒性及误差：此数据集未收录，保留未知。工业参考材料不算玩家新发现的晶体；不据此推断任意新材料性质。",14,UI.GOLD)
