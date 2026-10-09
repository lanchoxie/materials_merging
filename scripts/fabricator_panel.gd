extends Control
## v0.30 制造台: stored crystals the chemistry index recognises → pick heads and solar panels.
## Left: materials in storage with both possible stats; middle: picks and the rock table; right: refinery roof panels.
signal dismissed
signal acted(message: String)
signal refinery_requested
const UI=preload("res://scripts/ui.gd")
const Fabricator=preload("res://scripts/fabricator.gd")
const ChemIndex=preload("res://scripts/chem_index.gd")
const Geology=preload("res://scripts/planet_geology.gd")
const ROCKS=["limestone","malachite","basalt","hematite","granite","cassiterite","spodumene","pollucite","apatite"]
var state
var close_button: Button
var sources_button: Button
var materials: VBoxContainer
var picks: VBoxContainer
var rocks: GridContainer
var panels_box: VBoxContainer
var power_label: Label
var status: Label
var overlay: Control
var craft_buttons: Dictionary={}   # "batch_id:kind" -> Button (tests and tours)
var fingerprint=""
var clock=0.0

func setup(model) -> void:
	state=model
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=UI.make_theme()
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var title=UI.label("制造台 · 化合物变装备",30,UI.MINT); title.position=Vector2(28,22); add_child(title)
	var sub=UI.label("装备的数值来自化学索引里的真实性质：硬度决定镐头，带隙决定太阳能板",16,UI.MUTED); sub.position=Vector2(380,34); add_child(sub)
	close_button=UI.button("返回浮岛",_close); close_button.position=Vector2(1288,22); close_button.size=Vector2(124,48); add_child(close_button)
	var guide=UI.row(self,8); guide.position=Vector2(28,80)
	var steps=["① 反应釜做出晶体","② 化学索引认出它","③ 按真实性质做装备"]
	for i in range(steps.size()):
		var chip=PanelContainer.new(); chip.add_theme_stylebox_override("panel",UI.style(UI.INNER,14,UI.LINE))
		chip.add_child(UI.label(steps[i],17,UI.MUTED)); guide.add_child(chip)
		if i<steps.size()-1: guide.add_child(UI.label("→",20,UI.MUTED))
	sources_button=UI.button("规则与数据来源",_show_sources); guide.add_child(sources_button)
	var left=UI.box(self,Rect2(28,136,560,700)); var lcol=UI.column(left,10)
	lcol.add_child(UI.label("仓库里的材料",22,UI.MINT))
	lcol.add_child(UI.paragraph("化学索引认得的晶体才有真实性质。每件装备用掉 %d–%d 份产物和一点加工费。" % [int(Fabricator.rules().pick.units),int(Fabricator.rules().panel.units)],14))
	var scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; lcol.add_child(scroll)
	materials=UI.column(scroll,10); materials.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var middle=UI.box(self,Rect2(602,136,400,700)); var mcol=UI.column(middle,8)
	mcol.add_child(UI.label("镐头 · 硬度",22,UI.MINT))
	mcol.add_child(UI.paragraph("镐头比岩石软就会打滑，要多敲几下。硬度都换算到维氏硬度（GPa）比较。",14))
	picks=UI.column(mcol,6)
	mcol.add_child(UI.label("岩石对照（当前镐头）",17,UI.TEXT))
	rocks=GridContainer.new(); rocks.columns=3; rocks.add_theme_constant_override("h_separation",14); rocks.add_theme_constant_override("v_separation",4); mcol.add_child(rocks)
	var right=UI.box(self,Rect2(1016,136,396,700)); var rcol=UI.column(right,8)
	rcol.add_child(UI.label("精炼厂屋顶 · 太阳能板",22,UI.MINT))
	rcol.add_child(UI.paragraph("带隙太小，电压低；带隙太大，吸收的光少。单结电池的效率上限在 1.3 eV 附近最高。",14))
	power_label=UI.label("",17,UI.GOLD); rcol.add_child(power_label)
	panels_box=UI.column(rcol,6)
	rcol.add_child(UI.button("去精炼厂看看",func(): refinery_requested.emit()))
	status=UI.paragraph("",16,UI.GOLD); status.position=Vector2(32,850); status.size=Vector2(1370,40); add_child(status)
	_redraw()

func _fingerprint() -> String:
	var counts=[]
	for b in state.storage.batches: counts.append([b.id,int(b.quantity)])
	return JSON.stringify([counts,state.fabricator.serialize(),int(state.coins)])

func _redraw() -> void:
	fingerprint=_fingerprint()
	_materials()
	_picks()
	_rocks()
	_panels()

## Crystals the index knows first, best stats first; everything else after, with the reason it can't be used.
func _materials() -> void:
	UI.clear(materials); craft_buttons.clear()
	var f=state.fabricator
	var rows=[]
	for b in state.storage.batches:
		if int(b.quantity)<=0: continue
		var found: Dictionary=state.batch_index(b)
		var score=-1.0
		if ChemIndex.is_find(found) and found.kind=="crystal":
			var p=Fabricator.pick_stats(found.entry); var s=Fabricator.panel_stats(found.entry)
			score=maxf(float(p.get("hv",0.0))/20.0 if p.ok else 0.0,float(s.get("efficiency",0.0))*3.0 if s.ok else 0.0)
		rows.append({"batch":b,"found":found,"score":score})
	rows.sort_custom(func(a,b): return float(a.score)>float(b.score))
	var any_crystal=false
	for row in rows:
		var b: Dictionary=row.batch; var found: Dictionary=row.found
		var crystal=ChemIndex.is_find(found) and found.kind=="crystal"
		any_crystal=any_crystal or crystal
		var card=PanelContainer.new(); card.add_theme_stylebox_override("panel",UI.style(UI.INNER,12,UI.MINT if float(row.score)>0.0 else UI.LINE)); materials.add_child(card)
		var c=UI.column(card,4)
		c.add_child(UI.label("%s  %s   ×%d" % [str(b.formula),str(b.name),int(b.quantity)],17,UI.TEXT))
		if not ChemIndex.is_find(found):
			c.add_child(UI.paragraph("化学索引未收录：没有真实性质，做不了装备",13,UI.MUTED)); continue
		if not crystal:
			c.add_child(UI.paragraph("分子（PubChem CID %d）：装备要用晶体材料" % int(found.entry.cid),13,UI.MUTED)); continue
		var e: Dictionary=found.entry
		c.add_child(UI.paragraph("%s %s · %s%s" % [ChemIndex.formula(e),str(e.spacegroup),str(e.id)," · 实验观测过" if bool(e.get("experimental",false)) else " · 计算预测"],13,UI.LILAC))
		for kind in ["pick","panel"]:
			var q=f.quote(state,str(b.id),kind); var s: Dictionary=q.stats
			var line=UI.row(c,8)
			var text=UI.paragraph("%s：%s" % [Fabricator.KINDS[kind],Fabricator.stat_text(kind,s)],14,UI.MINT if s.get("ok",false) else UI.MUTED)
			text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; line.add_child(text)
			if s.get("ok",false):
				var rule: Dictionary=Fabricator.rules()[kind]
				var btn=UI.button("做%s\n%d份 + %d金币" % [Fabricator.KINDS[kind],int(rule.units),int(rule.coins)],_craft.bind(str(b.id),kind),q.ready)
				btn.disabled=not q.ready; btn.tooltip_text=q.message; btn.custom_minimum_size=Vector2(132,0)
				line.add_child(btn); craft_buttons["%s:%s" % [b.id,kind]]=btn
				if not q.ready: c.add_child(UI.paragraph(q.message,13,UI.GOLD))
	if not any_crystal:
		materials.add_child(UI.paragraph("还没有化学索引认得的晶体。试试在反应釜里换元素：岩盐模板的 Na→Al、Cl→N 得到氮化铝 AlN（很硬，适合做镐头）；钙钛矿 CsPbBr₃ 有合适的带隙，可以做太阳能板。结构工坊的周期晶胞也行，比如 2 个 Al + 3 个 O 就是刚玉 Al₂O₃。",15,UI.GOLD))

func _picks() -> void:
	UI.clear(picks)
	var f=state.fabricator
	var starter: Dictionary=Fabricator.rules().starter_pick
	picks.add_child(_gear_row("%s · %.2f GPa（%s）" % [starter.name,float(starter.hv),Fabricator.mohs_text(float(starter.hv))],str(starter.note),f.pick=="",[["换上",func(): _do(f.equip(state,""))]] if f.pick!="" else []))
	for it in f.items:
		if it.kind!="pick": continue
		var id=str(it.id)
		var buttons=[["拆掉",func(): _do(f.scrap(state,id))]]
		if f.pick!=id: buttons.push_front(["换上",func(): _do(f.equip(state,id))])
		picks.add_child(_gear_row("%s镐 · %.1f GPa（%s）" % [it.formula,float(it.hv),Fabricator.mohs_text(float(it.hv))],"%s · %s · Chen 模型估算" % [it.name,"偏韧" if it.tough else "偏脆，小心崩口"],f.pick==id,buttons))

func _rocks() -> void:
	UI.clear(rocks)
	var hv=state.fabricator.pick_hv()
	for h in ["岩石","硬度","采掘"]: rocks.add_child(UI.label(h,14,UI.MUTED))
	for id in ROCKS:
		var spec: Dictionary=Geology.info(id); var rock=Fabricator.rock_hv(id)
		var need=Fabricator.dig_hits(id,int(spec.hits),hv)
		var slow=need>int(spec.hits)
		rocks.add_child(UI.label(str(spec.name),15,UI.TEXT))
		rocks.add_child(UI.label("%.1f GPa · 莫氏 %s" % [rock,_mohs(id)],14,UI.MUTED))
		rocks.add_child(UI.label(("%d 下（原 %d）" % [need,int(spec.hits)]) if slow else "%d 下 ✓" % need,14,UI.GOLD if slow else UI.MINT))

func _mohs(id: String) -> String:
	var m=Fabricator.rock_mohs(id)
	return ("%.1f" % m).trim_suffix(".0")

func _panels() -> void:
	UI.clear(panels_box)
	var f=state.fabricator
	power_label.text="已装 %d / %d 块 · 精炼速度 +%d%%" % [f.panels.size(),int(Fabricator.rules().panel.slots),roundi(100.0*f.refinery_gain())]
	var any=false
	for it in f.items:
		if it.kind!="panel": continue
		any=true
		var id=str(it.id); var on=id in f.panels
		panels_box.add_child(_gear_row("%s · 带隙 %.2f eV · 上限 %.1f%%" % [it.formula,float(it.gap),100.0*float(it.efficiency)],"%s · 精炼 +%d%%" % [it.name,roundi(100.0*float(Fabricator.rules().panel.speed_gain)*float(it.efficiency))],on,[["拆下" if on else "装上",func(): _do(f.toggle_panel(state,id))],["拆掉",func(): _do(f.scrap(state,id))]]))
	if not any: panels_box.add_child(UI.paragraph("还没有太阳能板。用有带隙的晶体做一块，装到精炼厂屋顶，精炼就会变快。",14,UI.MUTED))

func _gear_row(title: String, detail: String, active: bool, buttons: Array) -> PanelContainer:
	var card=PanelContainer.new(); card.add_theme_stylebox_override("panel",UI.style(UI.MINT.darkened(0.6) if active else UI.INNER,12,UI.MINT if active else UI.LINE))
	var c=UI.column(card,2)
	c.add_child(UI.label(("● " if active else "")+title,15,UI.MINT if active else UI.TEXT))
	c.add_child(UI.paragraph(detail,12,UI.MUTED))
	if not buttons.is_empty():
		var r=UI.row(c,6)
		for b in buttons: r.add_child(UI.button(b[0],b[1]))
	return card

func _craft(batch_id: String, kind: String) -> void:
	var before=state.fabricator.items.size()
	_do(state.fabricator.craft(state,batch_id,kind))
	if state.fabricator.items.size()>before:
		var fx=get_node_or_null("/root/Fx")
		if fx: fx.sparkle((picks if kind=="pick" else panels_box).get_global_rect().get_center(),UI.GOLD,14,70.0)

func _do(message: String) -> void:
	status.text=message; acted.emit(message)
	_redraw()

func _show_sources() -> void:
	if overlay!=null: overlay.queue_free()
	overlay=Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(overlay)
	var shade=ColorRect.new(); shade.color=Color(0,0,0,0.6); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
	var box=UI.box(overlay,Rect2(170,90,1100,720)); var c=UI.column(box,8)
	c.add_child(UI.label("制造台的规则与数据来源",24,UI.MINT))
	var r: Dictionary=Fabricator.rules()
	for text in [
		"镐头硬度：用 Materials Project 的体模量 B 和剪切模量 G，按 Chen 等（2011）的经验模型 Hv = 2(k²G)^0.585 − 3（k = G/B）估算维氏硬度。模型对韧性很强的材料不适用（G/B < %.1f，多数纯金属），这时显示“不适用”，不瞎猜。" % float(r.pick.min_pugh_k),
		"岩石硬度：莫氏硬度按 Broz 等（2006）测得的莫氏标准矿物维氏硬度换算（滑石 0.14 … 刚玉 19.6 GPa）；花岗岩、玄武岩按主要造岩矿物取值。表土、沙、黏土是松散物料，不比硬度。",
		"采掘规则（游戏简化）：镐头比岩石软时，敲击次数按硬度比增加，最多 ×%.0f。起步镐：%s" % [float(r.pick.max_slowdown),str(r.starter_pick.note)],
		"太阳能板：按 Shockley–Queisser（1961）细致平衡，数值计算单结电池的效率上限（5778 K 黑体太阳、无聚光、电池 300 K；最高 %.1f%%，在 %.2f eV）。带隙取 Materials Project 的 GGA 计算值，通常比实验值低，所以只是估算。" % [100.0*float(r.sq_model.peak_efficiency),float(r.sq_model.peak_gap_ev)],
		"每块板让精炼速度 +%.0f × 效率（游戏数值）；屋顶 %d 个板位。加工份数、金币和上限都是游戏数值。" % [float(r.panel.speed_gain),int(r.panel.slots)],
	]:
		c.add_child(UI.paragraph(text,15,UI.TEXT))
	c.add_child(UI.label("来源",18,UI.MINT))
	for s in r.sources: c.add_child(UI.paragraph("· %s  %s" % [s.name,s.url],13,UI.LILAC))
	c.add_child(UI.button("知道了",func(): overlay.queue_free(); overlay=null,true))

func _process(dt: float) -> void:
	clock+=dt
	if clock<0.3: return
	clock=0.0
	if _fingerprint()!=fingerprint: _redraw()

func set_return_label(text: String) -> void:
	close_button.text=text

func handle_back() -> bool:
	if overlay!=null:
		overlay.queue_free(); overlay=null; return true
	_close(); return true

func _close() -> void:
	dismissed.emit(); queue_free()
