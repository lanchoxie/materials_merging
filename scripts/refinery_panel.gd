extends Control
## v0.28 精炼厂: mined minerals → element units; island extractors → common elements.
## Three columns: element stock (with where-to-get), extractors, mineral processes.
signal dismissed
signal acted(message: String)
signal planet_requested
const UI=preload("res://scripts/ui.gd")
const Geology=preload("res://scripts/planet_geology.gd")
var state
var close_button: Button
var guide: HBoxContainer
var stock_grid: GridContainer
var extractors: VBoxContainer
var processes: VBoxContainer
var queue_box: VBoxContainer
var level_label: Label
var upgrade_button: Button
var status: Label
var tiles: Dictionary={}        # symbol -> PanelContainer
var bars: Dictionary={}         # extractor id -> ProgressBar
var job_bar: ProgressBar
var fingerprint=""
var clock=0.0
var focus_symbol=""
var last_seen: Dictionary={}

func setup(model,symbol: String="") -> void:
	state=model; focus_symbol=symbol; last_seen=state.element_inventory.duplicate()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=UI.make_theme()
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var title=UI.label("精炼厂 · 矿物变元素",30,UI.MINT); title.position=Vector2(28,22); add_child(title)
	level_label=UI.label("",18,UI.GOLD); level_label.position=Vector2(360,34); add_child(level_label)
	close_button=UI.button("返回浮岛",_close); close_button.position=Vector2(1288,22); close_button.size=Vector2(124,48); add_child(close_button)
	guide=UI.row(self,8); guide.position=Vector2(28,80)
	var left=UI.box(self,Rect2(28,136,452,700)); var lcol=UI.column(left,10)
	lcol.add_child(UI.label("元素库存",22,UI.MINT))
	lcol.add_child(UI.paragraph("点一个元素，看它从哪里来。工作台替换元素、反应釜装新分子都从这里扣库存。",14))
	stock_grid=GridContainer.new(); stock_grid.columns=3; stock_grid.add_theme_constant_override("h_separation",8); stock_grid.add_theme_constant_override("v_separation",8); lcol.add_child(stock_grid)
	var middle=UI.box(self,Rect2(494,136,430,700)); var mcol=UI.column(middle,10)
	mcol.add_child(UI.label("自动提取 · 浮岛设施",22,UI.MINT))
	mcol.add_child(UI.paragraph("海水、空气和水就在身边：这些元素会慢慢自动入库，存到上限后暂停。",14))
	extractors=UI.column(mcol,8)
	upgrade_button=UI.button("",_upgrade,true); mcol.add_child(upgrade_button)
	var right=UI.box(self,Rect2(938,136,474,700)); var rcol=UI.column(right,10)
	rcol.add_child(UI.label("矿物精炼",22,UI.MINT))
	queue_box=UI.column(rcol,6)
	var scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; rcol.add_child(scroll)
	processes=UI.column(scroll,10); processes.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	status=UI.paragraph("",16,UI.GOLD); status.position=Vector2(32,850); status.size=Vector2(1370,40); add_child(status)
	_redraw()
	if not focus_symbol.is_empty(): _explain(focus_symbol)

func _fingerprint() -> String:
	var r=state.refinery
	return JSON.stringify([r.level,r.jobs.size(),state.element_inventory,state.planet.v2.nature.minerals,int(state.coins)>=r.upgrade_cost()])

func _redraw() -> void:
	fingerprint=_fingerprint()
	var r=state.refinery
	level_label.text="Lv.%d · 速度×%.2f · 自动上限%d · 队列%d" % [r.level,r.speed(),r.extractor_cap(),r.queue_limit()]
	var cost=r.upgrade_cost()
	upgrade_button.text="精炼厂已满级" if cost<0 else "升级到 Lv.%d · %d金币\n速度+25%%，自动上限+6，队列+1" % [r.level+1,cost]
	upgrade_button.disabled=cost<0 or state.coins<cost
	_guide()
	_stock()
	_extractors()
	_queue()
	_processes()

## The three-step path, with the step the player should do next highlighted.
func _guide() -> void:
	UI.clear(guide)
	var r=state.refinery; var has_mineral=false
	for id in r.rules().processes:
		if r.quote(state,id).ready: has_mineral=true
	# Next step: dig while nothing can be refined, refine while minerals wait or a batch runs, then use the elements.
	var current=1 if has_mineral or not r.jobs.is_empty() else (2 if not r.made.is_empty() else 0)
	var steps=["① 星球地下采矿","② 精炼厂提炼","③ 工作台 / 反应釜使用元素"]
	for i in range(steps.size()):
		var chip=PanelContainer.new(); chip.add_theme_stylebox_override("panel",UI.style(UI.MINT.darkened(0.55) if i==current else UI.INNER,14,UI.MINT if i==current else UI.LINE))
		var l=UI.label(steps[i],17,UI.MINT if i==current else UI.MUTED); chip.add_child(l); guide.add_child(chip)
		if i<steps.size()-1: guide.add_child(UI.label("→",20,UI.MUTED))
	guide.add_child(UI.button("进入星球采矿",func(): planet_requested.emit()))

func _stock() -> void:
	UI.clear(stock_grid); tiles.clear()
	for symbol in state.elements:
		var info: Dictionary=state.elements[symbol]; var count=int(state.element_inventory.get(symbol,0))
		var color=Color(str(info.get("color","888888"))); var bright=color.lightened(0.35)
		var tile=PanelContainer.new(); tile.custom_minimum_size=Vector2(136,72)
		tile.add_theme_stylebox_override("panel",UI.style(UI.INNER,12,bright if symbol==focus_symbol else color.darkened(0.2)))
		if count==0: tile.modulate=Color(1,1,1,0.55)
		var b=Button.new(); b.flat=true; b.mouse_filter=Control.MOUSE_FILTER_PASS; b.pressed.connect(_explain.bind(symbol))
		tile.add_child(b)
		var labels=HBoxContainer.new(); labels.mouse_filter=Control.MOUSE_FILTER_IGNORE; labels.alignment=BoxContainer.ALIGNMENT_CENTER; labels.add_theme_constant_override("separation",8); tile.add_child(labels)
		labels.add_child(UI.label(symbol,30,bright))
		var text=VBoxContainer.new(); text.mouse_filter=Control.MOUSE_FILTER_IGNORE; text.alignment=BoxContainer.ALIGNMENT_CENTER; text.add_theme_constant_override("separation",0); labels.add_child(text)
		text.add_child(UI.label(str(info.get("name",symbol)),14,UI.MUTED))
		text.add_child(UI.label("%d 份" % count,18,UI.TEXT if count>0 else UI.MUTED))
		stock_grid.add_child(tile); tiles[symbol]=tile

func _explain(symbol: String) -> void:
	var changed=focus_symbol!=symbol
	focus_symbol=symbol
	if changed and tiles.has(symbol): _stock()
	status.text="%s（%s）来源：%s" % [symbol,state.elements.get(symbol,{}).get("name",symbol),state.refinery.how_to_get(symbol)]
	if tiles.has(symbol): _punch(tiles[symbol])

func _extractors() -> void:
	UI.clear(extractors); bars.clear()
	var r=state.refinery; var rules=r.rules()
	for id in rules.extractors:
		var ex: Dictionary=rules.extractors[id]
		var full=true
		for symbol in ex.outputs:
			if int(state.element_inventory.get(symbol,0))<r.extractor_cap(): full=false
		var card=PanelContainer.new(); card.add_theme_stylebox_override("panel",UI.style(UI.INNER,12)); extractors.add_child(card)
		var c=UI.column(card,2)
		c.add_child(UI.label("%s   → %s" % [ex.name,r.format(ex.outputs)],17,UI.MUTED if full else UI.TEXT))
		c.add_child(UI.paragraph(ex.equation,13,UI.LILAC))
		var bar=ProgressBar.new(); bar.custom_minimum_size.y=10; bar.show_percentage=false; c.add_child(bar); bars[id]=bar
		if full: c.add_child(UI.paragraph("已存满%d份，暂停；用掉一些后继续" % r.extractor_cap(),13,UI.GOLD))
	_bars()

func _queue() -> void:
	UI.clear(queue_box); job_bar=null
	var r=state.refinery
	if r.jobs.is_empty():
		queue_box.add_child(UI.paragraph("炉子空闲。带回矿物后，在下面选一种工艺开始精炼。",15,UI.MUTED)); return
	for i in range(r.jobs.size()):
		var p=r.process(str(r.jobs[i].process))
		queue_box.add_child(UI.label(("正在精炼：" if i==0 else "排队 %d：" % i)+"%s → %s" % [p.name,r.format(p.outputs)],16,UI.GOLD if i==0 else UI.MUTED))
		if i==0:
			job_bar=ProgressBar.new(); job_bar.custom_minimum_size.y=16; queue_box.add_child(job_bar)
	_bars()

func _processes() -> void:
	UI.clear(processes)
	var r=state.refinery; var stock=state.planet.v2.nature.minerals
	var ids: Array=r.rules().processes.keys()
	# Ready processes first, then the rest in data order.
	ids.sort_custom(func(a,b): return r.quote(state,a).ready and not r.quote(state,b).ready)
	for id in ids:
		var p: Dictionary=r.process(id); var q=r.quote(state,id)
		var card=PanelContainer.new(); card.add_theme_stylebox_override("panel",UI.style(UI.INNER,12,UI.MINT if q.ready else UI.LINE)); processes.add_child(card)
		var c=UI.column(card,4)
		c.add_child(UI.label("%s · %s" % [p.name,p.method],18,UI.TEXT))
		var inputs=[]
		for m in p.inputs:
			var have=int(stock.get(m,0))
			inputs.append("%s ×%d（有%d）" % [Geology.info(m).get("name",m),int(p.inputs[m]),have])
		c.add_child(UI.paragraph("投入："+" ＋ ".join(inputs),15,UI.MINT if q.ready else UI.GOLD))
		c.add_child(UI.paragraph("产出：%s · %d秒" % [r.format(p.outputs),ceili(r.seconds(id))],15,UI.TEXT))
		c.add_child(UI.paragraph(p.equation,13,UI.LILAC))
		c.add_child(UI.paragraph(p.detail,13,UI.MUTED))
		var b=UI.button("开始精炼" if q.ready else q.message,_start.bind(id),q.ready); b.disabled=not q.ready
		b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		c.add_child(b)

func _bars() -> void:
	var r=state.refinery
	for id in bars:
		bars[id].value=100.0*float(r.progress.get(id,0.0))/float(r.rules().extractors[id].every)
	if job_bar!=null and not r.jobs.is_empty():
		var total=float(r.process(str(r.jobs[0].process)).seconds)
		job_bar.value=100.0*(1.0-float(r.jobs[0].left)/total)

func _start(id: String) -> void:
	var before=state.refinery.jobs.size()
	var message=state.refinery.start(state,id)
	status.text=message; acted.emit(message)
	if state.refinery.jobs.size()>before: _sparkle_center(queue_box)
	_redraw()

func _upgrade() -> void:
	var message=state.refinery.upgrade(state)
	status.text=message; acted.emit(message)
	_redraw(); _sparkle_center(upgrade_button)

func _process(dt: float) -> void:
	clock+=dt
	_bars()
	if clock<0.25: return
	clock=0.0
	if _fingerprint()!=fingerprint:
		_redraw()
		# New units glow on their tiles so the player sees what just arrived.
		for symbol in tiles:
			if int(state.element_inventory.get(symbol,0))>int(last_seen.get(symbol,0)): _punch(tiles[symbol])
	last_seen=state.element_inventory.duplicate()
	if not state.refinery_notice.is_empty():
		status.text=state.refinery_notice

func _punch(node: CanvasItem) -> void:
	var fx=get_node_or_null("/root/Fx")
	if fx: fx.punch(node)

func _sparkle_center(node: Control) -> void:
	var fx=get_node_or_null("/root/Fx")
	if fx and is_instance_valid(node): fx.sparkle(node.get_global_rect().get_center(),UI.MINT,10,50.0)

func set_return_label(text: String) -> void:
	close_button.text=text

func handle_back() -> bool:
	_close(); return true

func _close() -> void:
	dismissed.emit(); queue_free()
