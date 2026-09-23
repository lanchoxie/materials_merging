extends Control

const UI = preload("res://scripts/ui.gd")
const Model = preload("res://scripts/lab_state.gd")
const World = preload("res://scripts/world_view.gd")
const Editor = preload("res://scripts/atom_editor.gd")
const ScienceChart = preload("res://scripts/science_chart.gd")
const SandboxEditor = preload("res://scripts/sandbox_editor.gd")
const BuildingDrag=preload("res://scripts/building_drag.gd")
var building_drag=BuildingDrag.new()
const CampusView = preload("res://scripts/campus_view.gd")
const IslandPanel=preload("res://scripts/island_panel.gd")
const FactoryPanel=preload("res://scripts/factory_panel.gd")
const PlanetV2Panel=preload("res://scripts/planet_v2_panel.gd")
const OrderBubbles=preload("res://scripts/order_bubbles.gd")
var order_bubbles
const CampusPanel = preload("res://scripts/campus_panel.gd")
var campus_view
var state = Model.new()
var world
var world_box: SubViewportContainer
var world_viewport: SubViewport
var selected_plot: int = 4
var selected_reactor: int = 0
var side: VBoxContainer
var gold_label: Label
var material_label: Label
var people_label: Label
var income_label: Label
var rate_label: Label
var stock_label: Label
var quality_label: Label
var progress_bar: ProgressBar
var quest_label: Label
var save_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var modal: Control
var editor_return_view: Control
var refresh_clock: float = 0
var save_clock: float = 0
var toast_clock: float = 0
var snapshot_mode: bool = false
var visual_test: bool = false
var help_panel: Control
var land_label: Label
var order_quote_label: Label
var visitor_status_label: Label
var market_rows: Array = []
var world_pointer_down: bool = false
var world_pointer_start: Vector2
var world_pointer_last: Vector2
var world_pointer_dragged: bool = false
var world_touch_index: int = -1
var shop_buttons: Dictionary = {}
var purchase_confirm_button: Button
var research_open: bool = false
var move_source: int = -1
var last_factory_recipe="standard_water_crate"
var light_bridge
var light_bridge_busy=false
var miniature_view

func _ready() -> void:
	if OS.has_feature("web"):
		state.layout.config.performance.visible_people=int(state.layout.config.performance.web_visible_people)
		state.layout.config.performance.visible_buildings=int(state.layout.config.performance.web_visible_buildings)
	if OS.has_feature("android"):
		state.layout.config.performance.visible_people=int(state.layout.config.performance.mobile_visible_people)
		state.layout.config.performance.visible_buildings=int(state.layout.config.performance.mobile_visible_buildings)
		Engine.max_fps=int(state.layout.config.performance.mobile_max_fps)
	snapshot_mode = "--capture" in OS.get_cmdline_user_args()
	visual_test = "--visual-test" in OS.get_cmdline_user_args() or "--release-ui-test" in OS.get_cmdline_user_args()
	if not snapshot_mode and not visual_test:
		state.load_game()
	theme = UI.make_theme()
	_build_ui()
	building_drag.setup(self)
	_sync_world()
	_select_plot(4)
	_update_labels()
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	if snapshot_mode:
		_capture_demo.call_deferred()
	if visual_test and "--release-ui-test" not in OS.get_cmdline_user_args():
		_run_visual_test.call_deferred()
	if "--river-preview" in OS.get_cmdline_user_args() and not visual_test and not snapshot_mode:
		_show_planet_v2.call_deferred()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var top = UI.box(self, Rect2(24,20,1392,88))
	var h = UI.row(top, 24)
	var brand = UI.column(h, 0)
	brand.custom_minimum_size.x = 272
	brand.add_child(UI.label("☆  原子工坊", 27, UI.MINT))
	brand.add_child(UI.label("ATOM ATELIER   /   好奇心驱动的小岛", 11, UI.MUTED))
	var gold = UI.column(h, 0)
	gold.custom_minimum_size.x = 140
	gold.add_child(UI.label("◇  金币", 12, UI.GOLD))
	gold_label = UI.label("220", 25, UI.GOLD)
	gold.add_child(gold_label)
	var supplies = UI.column(h, 3)
	supplies.custom_minimum_size.x = 298
	supplies.add_child(UI.label("岛屿建材", 12, UI.MUTED))
	material_label = UI.label("", 17)
	supplies.add_child(material_label)
	var people = UI.column(h, 3)
	people.custom_minimum_size.x = 164
	people.add_child(UI.label("岛上的伙伴", 12, UI.MUTED))
	people_label = UI.label("", 17, UI.LILAC)
	people.add_child(people_label)
	var income = UI.column(h, 0)
	income.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	income.add_child(UI.label("预计总产出", 12, UI.MUTED))
	income_label = UI.label("", 24, UI.MINT)
	income.add_child(income_label)
	var save = UI.button("保存", func(): _toast(state.save_game()))
	save.custom_minimum_size.x = 66
	h.add_child(save)
	_build_left()
	_build_world()
	var side_panel = UI.box(self, Rect2(1086,126,330,654))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(scroll)
	side = UI.column(scroll, 9)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_toolbar()
	order_bubbles=OrderBubbles.new(); add_child(order_bubbles); order_bubbles.setup(self)
	toast_panel = UI.box(self, Rect2(365, 710, 650, 60), Color("29494a"))
	toast_label = UI.paragraph("", 15, UI.TEXT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	toast_panel.hide()
	save_label = UI.label("v0.21 河湾与浮岛  ·  种树 · 改造地形 · 带回自己的作品", 11, UI.MUTED)
	save_label.position = Vector2(36, 880)
	add_child(save_label)

func _build_left() -> void:
	var panel = UI.box(self, Rect2(24,126,184,654))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v = UI.column(scroll, 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label("探索手册", 13, UI.MUTED))
	UI.spacer(v, 2)
	v.add_child(UI.label("每一章\n都是新世界", 21))
	UI.spacer(v, 8)
	v.add_child(UI.label("浮岛经营",19,UI.MINT))
	v.add_child(UI.paragraph("分子与晶体\n用结构点亮生活",15))
	UI.spacer(v, 8)
	v.add_child(UI.label("你的发现", 13, UI.MUTED))
	v.add_child(UI.button("▧   结构图鉴", _show_collection))
	v.add_child(UI.button("☆   研究站", _show_research))
	v.add_child(UI.button("走进浮岛",_show_island_walk))
	v.add_child(UI.button("河湾作品",_show_miniatures))
	v.add_child(UI.paragraph("元素与物品统一放在工具箱。\n公园在下方建造菜单。",13))
	var help_button = UI.button("怎么玩  ?", _show_help)
	v.add_child(help_button)

func _build_world() -> void:
	var panel = UI.box(self, Rect2(224,126,846,654), Color("152e37"))
	panel.add_theme_stylebox_override("panel", UI.style(Color("152e37"),20,Color("34505a")))
	world_box = SubViewportContainer.new()
	world_box.stretch = true
	world_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(world_box)
	world_viewport = SubViewport.new()
	world_viewport.size = Vector2i(814,630)
	world_viewport.own_world_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = Viewport.MSAA_2X
	if OS.has_feature("android") or OS.has_feature("web"): world_viewport.msaa_3d = Viewport.MSAA_DISABLED
	world_box.add_child(world_viewport)
	world = World.new()
	world.campus_life_enabled = true
	world.detail_budget = clampi(int(state.layout.config.performance.visible_buildings),1,72)
	world_viewport.add_child(world)
	campus_view = CampusView.new()
	campus_view.setup(state,world)
	light_bridge=preload("res://scripts/island_light_bridge.gd").new()
	light_bridge.setup(world,state)
	miniature_view=preload("res://scripts/island_miniature_view.gd").new(); world.add_child(miniature_view); miniature_view.sync(state)
	world.plot_clicked.connect(_select_plot)
	world_box.gui_input.connect(_world_input)
	var eyebrow = UI.label("YOUR LITTLE SCIENCE ISLAND", 11, UI.MINT)
	eyebrow.position = Vector2(251,145)
	add_child(eyebrow)
	var title = UI.label("好奇心所至，小岛继续生长。", 27)
	title.position = Vector2(248,164)
	add_child(title)
	var caption = UI.label("拖地图 · 长按建筑搬迁 · 滚轮缩放", 13, UI.MUTED)
	if OS.has_feature("android"):
		caption.text = "拖地图 · 长按建筑搬迁 · 轻触地块建造"
	caption.position = Vector2(251,211)
	add_child(caption)
	var camera_controls = HBoxContainer.new()
	camera_controls.position = Vector2(746, 239)
	camera_controls.add_theme_constant_override("separation", 10)
	add_child(camera_controls)
	for entry in [["← 左转", 0.28], ["右转 →", -0.28]]:
		var turn_button = UI.button(entry[0], func(): world.orbit(entry[1]))
		turn_button.custom_minimum_size = Vector2(142, 44)
		camera_controls.add_child(turn_button)
	var map_controls = HBoxContainer.new()
	map_controls.position = Vector2(251, 239)
	map_controls.add_theme_constant_override("separation", 8)
	add_child(map_controls)
	for entry in [["边缘", _show_map], ["回家", func(): world.reset_view()], ["−", func(): world.zoom_view(1.22)], ["＋", func(): world.zoom_view(0.82)]]:
		var b = UI.button(entry[0], entry[1])
		b.custom_minimum_size = Vector2(84, 44)
		map_controls.add_child(b)
	land_label = UI.label("", 13, UI.GOLD)
	land_label.position = Vector2(254, 654)
	add_child(land_label)
	var badge = UI.label("●  LIVE  /  生长中", 12, UI.MINT)
	badge.position = Vector2(897,146)
	add_child(badge)
	var quest = UI.box(self, Rect2(248,689,796,68),Color("192e39"))
	quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var q = UI.row(quest,14)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.add_child(UI.label("↗",25,UI.GOLD))
	quest_label = UI.paragraph("",14)
	quest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q.add_child(quest_label)

func _build_toolbar() -> void:
	var panel = UI.box(self, Rect2(24,798,1392,78))
	var h = UI.row(panel,12)
	var click_b = UI.button("☆  注入微光   +2", func(): _action(state.click_energy()), true)
	click_b.custom_minimum_size.x = 214
	h.add_child(click_b)
	var buttons = [
		["↓  收获全部", func(): _action(state.harvest_all())],
		["＋  建造 / 公园", _show_build_menu],
		["◇  探索盲盒", _show_crate],
		["科研小镇", _show_crew],
		["工具箱", _show_toolbox],
		["□  结构工坊", _show_sandbox]
	]
	for entry in buttons:
		var b = UI.button(entry[0], entry[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)

func _world_input(event: InputEvent) -> void:
	if light_bridge_busy: return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		world.orbit(-event.relative.x * 0.008)
		return
	if event is InputEventScreenTouch:
		if event.pressed and world_touch_index == -1:
			world_touch_index = event.index
			_begin_world_pointer(event.position)
		elif not event.pressed and event.index == world_touch_index:
			_end_world_pointer(event.position)
			world_touch_index = -1
		world_box.accept_event()
	if event is InputEventScreenDrag and event.index == world_touch_index:
		_move_world_pointer(event.position)
		world_box.accept_event()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin_world_pointer(event.position)
			else: _end_world_pointer(event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			world.zoom_view(0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14)
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_move_world_pointer(event.position)

func _begin_world_pointer(pos: Vector2) -> void:
	if _on_light_bridge(pos): building_drag.cancel()
	else: building_drag.begin(pos)
	world_pointer_down = true
	world_pointer_start = pos
	world_pointer_last = pos
	world_pointer_dragged = false

func _move_world_pointer(pos: Vector2) -> void:
	if not world_pointer_down: return
	if building_drag.move(pos):
		world_pointer_last=pos
		return
	if pos.distance_to(world_pointer_start) > 10.0: world_pointer_dragged = true
	if world_pointer_dragged:
		world.pan_view((world_pointer_last - pos) * world.camera.size / (world_box.size.y * World.PITCH))
	world_pointer_last = pos

func _end_world_pointer(pos: Vector2) -> void:
	if building_drag.release(pos):
		world_pointer_down=false
		return
	if world_pointer_down and not world_pointer_dragged:
		_pick_world(pos)
	world_pointer_down = false

func _input(event: InputEvent) -> void:
	if not is_instance_valid(world_box): return
	# A release outside the viewport must not leave a captured drag behind.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not world_box.get_global_rect().has_point(event.position):
			world_pointer_down = false
			building_drag.cancel()
	if event is InputEventScreenTouch and not event.pressed and event.index == world_touch_index:
		if not world_box.get_global_rect().has_point(event.position):
			world_touch_index = -1
			world_pointer_down = false
			building_drag.cancel()

func _pick_world(local_position: Vector2) -> void:
	if _on_light_bridge(local_position): _enter_light_bridge(); return
	var screen_position = local_position * Vector2(world_viewport.size) / world_box.size
	var plot_index: int = world.screen_pick(screen_position)
	if plot_index >= 0:
		_select_plot(plot_index)

func _on_light_bridge(local_position: Vector2) -> bool:
	return is_instance_valid(light_bridge) and light_bridge.hit(world.camera,local_position*Vector2(world_viewport.size)/world_box.size)

func _enter_light_bridge() -> void:
	if light_bridge_busy or is_instance_valid(modal): return
	light_bridge_busy=true; light_bridge.activate(); building_drag.cancel()
	var veil=ColorRect.new(); veil.color=Color(0.60,0.88,0.96,0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(veil)
	var tween=create_tween(); tween.tween_property(veil,"color:a",1.0,0.3)
	await tween.finished
	_show_planet_v2(); modal._enter(); veil.move_to_front()
	tween=create_tween(); tween.tween_property(veil,"color:a",0.0,0.35)
	await tween.finished
	veil.queue_free(); light_bridge_busy=false

func _select_plot(index: int) -> void:
	if index < 0 or index >= state.plots.size(): return
	selected_plot = index
	selected_reactor = int(state.plots[index].rid) if state.plots[index].kind == "reactor" else -1
	world.select_plot(index)
	_rebuild_sidebar()

func _rebuild_sidebar() -> void:
	UI.clear(side)
	rate_label = null
	stock_label = null
	progress_bar = null
	quality_label = null
	order_quote_label = null
	var p: Dictionary = state.plots[selected_plot]
	side.add_child(UI.label("%s  /  %s" % [state.plot_label(selected_plot), "已开拓" if p.unlocked else "待探索"],12,UI.MUTED))
	if not p.unlocked:
		side.add_child(UI.label("向未知，再走一步",23,UI.MINT))
		side.add_child(UI.paragraph("这里可以成为下一间实验室，或一处安静的小花园。",15))
		UI.spacer(side,18)
		side.add_child(UI.label("开拓需要",16))
		var cost: int = state.plot_cost(selected_plot)
		side.add_child(UI.paragraph("星砂 × %d\n晶露 × %d\n合金片 × %d" % [cost,cost,cost],19,UI.GOLD))
		var expand_button = UI.button("开拓这块土地",func(): _action(state.buy_plot(selected_plot)),true)
		expand_button.disabled = not state.can_expand(selected_plot)
		side.add_child(expand_button)
		side.add_child(UI.paragraph("沿已开拓土地的相邻边缘延伸；越远建材越多。" if state.can_expand(selected_plot) else "先开拓相邻土地，才能到达这里。",13))
		side.add_child(UI.paragraph("收集已知产物有%d%%概率掉落建材，\n连续%d份无掉落则补给最少的一种。" % [roundi(float(state.island_rules.production.drop_probability)*100),int(state.island_rules.production.drop_pity)],13))
	elif p.kind == "empty":
		side.add_child(UI.label("一块充满可能的空地",21,UI.MINT))
		side.add_child(UI.paragraph("选一个新邻居，让小岛热闹起来。"))
		UI.spacer(side,15)
		side.add_child(UI.label("生产设施",15,UI.GOLD))
		side.add_child(UI.button("＋  反应炉   100 金币",func(): _show_templates(true),true))
		side.add_child(UI.paragraph("选择初始结构；工程师会来建造。\n基础建造时间12秒，多人协作更快。",13))
		UI.spacer(side,18)
		side.add_child(UI.label("给小岛一点温度",15,UI.LILAC))
		side.add_child(UI.button("住宅 · 院所 · 食堂 · 公园",_show_campus.bind("build"),true))
		side.add_child(UI.paragraph("每块地可放一栋主建筑和8件庭院小物。小路沿地块边缘自动衔接。",13))
	elif p.kind != "reactor":
		var building=state.layout.building_info(p.kind)
		side.add_child(UI.label("迎客广场" if p.kind=="plaza" else str(building.get("name",state.DECORATIONS.get(p.kind,{"name":"岛屿装饰"}).name)),24,UI.LILAC))
		side.add_child(UI.paragraph("让实验与生活，在同一座小岛上发生。",15))
		if p.kind=="workshop":
			side.add_child(UI.button("制造材料与器件",_show_factory,true))
			side.add_child(UI.paragraph("构件、光伏与生态设备都在这里加工。工程师到岗后推进，完工自动收入工具箱。",14))
			side.add_child(UI.button("安排车间工程师",_show_campus.bind("people")))
		if p.kind!="plaza": side.add_child(UI.button("搬迁到另一块空地",_show_relocation,true))
		else:
			side.add_child(UI.paragraph("收购商骑车或乘车来访。交付或送客后，等待下一班来客。",16))
			side.add_child(UI.button("迎接收购商",_show_market,true))
	else:
		var r: Dictionary = state.reactors[selected_reactor]
		var tpl: Dictionary = state.structure_data(r)
		side.add_child(UI.label("%s   Lv.%d" % [r.id,r.level],14,UI.MUTED))
		side.add_child(UI.label(tpl.formula,32,UI.MINT))
		side.add_child(UI.paragraph(tpl.name,16,UI.TEXT))
		UI.spacer(side,3)
		rate_label = UI.label("",26,UI.GOLD)
		side.add_child(rate_label)
		progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size.y = 8
		progress_bar.show_percentage = false
		side.add_child(progress_bar)
		stock_label = UI.label("",13,UI.MUTED)
		side.add_child(stock_label)
		quality_label = UI.label("",13,UI.MINT)
		side.add_child(quality_label)
		side.add_child(UI.button("查看收益构成", _show_income))
		side.add_child(UI.paragraph("长按炉子可拿起搬迁",13,UI.MUTED))
		var edit_b = UI.button("进入原子工作台   →", _open_editor,true)
		edit_b.disabled = float(r.build_left) > 0
		side.add_child(edit_b)
		var h = UI.row(side,8)
		var harvest = UI.button("收获",func(): _action(state.harvest(selected_reactor)))
		harvest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(harvest)
		var switch_b = UI.button("更换配方",func(): _show_templates(false))
		h.add_child(switch_b)
		side.add_child(UI.button("升级   %d 金币 + 1 催化晶" % state.upgrade_cost(r),func(): _action(state.upgrade_reactor(selected_reactor))))
		side.add_child(UI.paragraph("本等级编辑固定 %d 金币 / 次\n样品指纹  %s" % [state.edit_cost(r),state.signature(r).substr(0,10)],12))
		UI.spacer(side,4)
		if not r.get("installation",{}).is_empty():
			side.add_child(UI.paragraph("新样品等待博士装炉 · 旧炉继续运转",14,UI.GOLD))
			side.add_child(UI.button("取消装炉并退款",func(): _action(state.cancel_installation(selected_reactor))))
		side.add_child(UI.paragraph("收获后产物收入工具箱。订单请到广场邮箱查看，或点击来客头顶气泡。",14))

	if p.unlocked:
		var find_kind=str(state.storage.finds.get(str(selected_plot),""))
		if not find_kind.is_empty() and find_kind!="collected": side.add_child(UI.button("拾取 · "+str(state.layout.config.props[find_kind].name),func(): _action(state.collect_find(selected_plot)),true))
		if p.kind=="doctor_dorm": side.add_child(UI.button("公寓补给 · 泡面 / 可乐",func(): _show_toolbox(); modal._tab("supplies"),true))
		side.add_child(UI.button("小路 · 庭院 · 建筑升级",_show_campus.bind("build")))
	_update_labels()

func _process(delta: float) -> void:
	if world_pointer_down: building_drag.tick(delta)
	var covered=is_instance_valid(modal)
	world_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if covered else SubViewport.UPDATE_ALWAYS
	world.process_mode=Node.PROCESS_MODE_DISABLED if covered else Node.PROCESS_MODE_INHERIT
	state.tick(delta)
	if not state.planet.notice.is_empty():
		_toast(state.planet.notice); state.planet.notice=""
		if not snapshot_mode and not visual_test: state.save_game()
	if not state.campus_notice.is_empty():
		_toast(state.campus_notice)
		state.campus_notice=""
	if not state.science_notice.is_empty():
		_toast(state.science_notice)
		state.science_notice = ""
		if research_open: _show_research()
		if not snapshot_mode and not visual_test: state.save_game()
	refresh_clock += delta
	save_clock += delta
	if refresh_clock > float(state.layout.config.performance.world_refresh_seconds):
		refresh_clock = 0
		_update_labels()
		if not building_drag.active and not covered: _sync_world()
	if save_clock > 20:
		save_clock = 0
		if not snapshot_mode and not visual_test:
			state.save_game()
	if toast_clock > 0:
		toast_clock -= delta
		if toast_clock <= 0:
			toast_panel.hide()

func _update_labels() -> void:
	if gold_label == null:
		return
	gold_label.text = "%s" % int(state.coins)
	material_label.text = "星砂 %d   晶露 %d   合金 %d" % state.materials
	people_label.text = "工程师 %d   科研 %d" % [state.engineers,state.campus.people.size()-state.engineers]
	income_label.text = "%.1f / s" % state.total_income()
	land_label.text = "已开拓 %d 块  /  沿边缘继续探索" % state.unlocked_plot_count()
	if is_instance_valid(rate_label) and selected_reactor >= 0:
		var r: Dictionary = state.reactors[selected_reactor]
		rate_label.text = "%.2f  金币 / 秒" % (state.income(r) if int(r.pending)<state.reactor_capacity(r) else 0.0)
		progress_bar.value = float(r.progress) * 100
		stock_label.text = "待收 %d 金币 · 待领取 %d / %d 份" % [int(r.stored_coins),r.pending,state.reactor_capacity(r)]
		quality_label.text = "满仓暂停 · 请手动收获或安排博士收集" if int(r.pending)>=state.reactor_capacity(r) else "建造中  %.1f 秒" % r.build_left if r.build_left > 0 else ("几何匹配  %d%%   ·   持续生长中" % roundi(state.quality(r)*100) if not state.reference_id(r).is_empty() else "探索样品 · 科学匹配未知 · 可制作展示品")
		if is_instance_valid(order_quote_label):
			var quote: Dictionary = state.delivery_quote(selected_reactor)
			order_quote_label.text = "%s预报价  %d 金币%s" % ["精品" if quote.premium else "普通", quote.payment, " + 催化晶" if quote.premium else ""] if quote.known or quote.get("exploration",false) else "探索样品可等待创意收购商来访"
		# A construction button becomes available immediately when engineers finish.
		for c in side.get_children():
			if c is Button and c.text.begins_with("进入原子"):
				c.disabled = r.build_left > 0
	var steps = ["第一步：进入原子工作台，移动彩球，观察金币 / 秒的变化。", "下一步：收获产物，打开免费探索箱，招募第二位工程师。", "下一步：开拓土地，建一座新反应炉，发现不同结构。", "下一步：完成精品订单，获得催化晶，升级你的反应炉。"]
	var step = 0
	if state.total_harvests > 0: step = 1
	if state.engineers > 1: step = 2
	if state.reactors.size() > 1: step = 3
	quest_label.text = steps[step]
	if state.planet.joined:
		var journey=preload("res://scripts/material_journey.gd").next(state)
		quest_label.text="材料路线 %d/6 · %s · 邮箱查看下一步" % [journey.index,journey.title]
	for entry in market_rows:
		if is_instance_valid(entry.button):
			var quote: Dictionary = state.delivery_quote(entry.index)
			var r: Dictionary = state.reactors[entry.index]
			entry.label.text = "%s\n库存 %d / %d  ·  预报价 %d 金币%s" % [state.economy.ranking_reason(quote), r.stock,quote.quantity,quote.payment," + 1催化晶" if quote.premium else ""] if quote.known or quote.get("exploration",false) else "探索组合 · 等待每四位一轮的创意收购商"
			entry.button.disabled = not quote.ready or not state.visitor_available()
	if not market_rows.is_empty() and is_instance_valid(market_rows[0].card):
		var container: Node=market_rows[0].card.get_parent()
		var first=container.get_child_count()
		for entry in market_rows: first=mini(first,entry.card.get_index())
		var ranking: Array=state.market_candidates()
		for rank in range(ranking.size()):
			for entry in market_rows:
				if entry.index==ranking[rank].index:
					container.move_child(entry.card,first+rank)
					var reactor: Dictionary=state.reactors[entry.index]
					entry.heading.text="%d  ·  %s   %s   Lv.%d" % [rank+1,reactor.id,state.structure_data(reactor).formula,reactor.level]
	if is_instance_valid(visitor_status_label):
		visitor_status_label.text = state.visitor_countdown_text()

func _sync_world() -> void:
	var views: Array = []
	for r in state.reactors:
		var info: Dictionary = state.structure_data(r)
		var view: Dictionary = r.duplicate(false)
		view.atoms = info.atoms
		view.atom_contexts = info.atom_contexts
		view.bonds = info.bonds
		if info.known: view.template = info.reference_id
		views.append(view)
	world.sync(state.plots,views,state.templates,state.elements,state.engineers)
	if is_instance_valid(campus_view): campus_view.sync()
	if is_instance_valid(light_bridge): light_bridge.sync(state)
	if is_instance_valid(miniature_view): miniature_view.sync(state)

func _action(message: String) -> void:
	_toast(message)
	_sync_world()
	_rebuild_sidebar()
	if not snapshot_mode and not visual_test:
		state.save_game()

func _toast(message: String) -> void:
	toast_label.text = message
	toast_panel.show()
	toast_panel.move_to_front()
	toast_clock = 4.0

func _close_modal() -> void:
	if is_instance_valid(world_viewport): world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	building_drag.cancel()
	research_open = false
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null
	if is_instance_valid(editor_return_view): editor_return_view.queue_free()
	editor_return_view = null
	market_rows.clear()
	shop_buttons.clear()
	purchase_confirm_button = null

func _dialog(title: String, subtitle: String, wide: bool = false) -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var dim = ColorRect.new()
	dim.color = Color(0.015,0.03,0.05,0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var w = 930 if wide else 600
	var panel = UI.box(modal,Rect2((1440-w)/2,106,w,668))
	var outer = UI.column(panel,13)
	var head = UI.row(outer)
	var label = UI.label(title,27,UI.MINT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	head.add_child(UI.button("×",_close_modal))
	outer.add_child(UI.paragraph(subtitle,14))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var body = UI.column(scroll,14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return body

func _show_templates(build: bool) -> void:
	var body = _dialog("选择初始结构", "新炉包含初始元素，键长与角度需要自己调节。更换配方预付25金币，等待博士装炉；旧批次保留。")
	for key in state.templates:
		if state.templates[key].get("substitution_only",false) and key not in state.campus.unlocked_materials: continue
		var tpl: Dictionary = state.templates[key]
		var panel = PanelContainer.new()
		body.add_child(panel)
		var v = UI.column(panel,6)
		v.add_child(UI.label("%s   %s" % [tpl.formula,tpl.name],20,Color(tpl.color)))
		var profile: Dictionary = state.economy.profile(tpl)
		v.add_child(UI.paragraph("%s章节  ·  %d个可编辑原子\n复杂度 %.2f  ·  满匹配Lv.1产出 %.2f金币/秒" % [tpl.chapter,tpl.atoms.size(),profile.complexity,profile.base_rate],13))
		v.add_child(UI.button("建造此反应炉  ·  100金币" if build else "装载初始结构  ·  25金币",_choose_template.bind(key,build)))

func _show_map(_frontier: bool=true) -> void:
	# Expansion is performed on the island, never in a separate matrix.
	var options=[]
	for i in range(state.plots.size()):
		if state.can_expand(i): options.append(i)
	if options.is_empty(): _toast("当前没有可开拓边缘"); return
	var next=options[(options.find(selected_plot)+1)%options.size()]
	_select_plot(next); world.focus_plot(next)

func _locate_plot(index: int) -> void:
	_close_modal()
	_select_plot(index)
	world.focus_plot(index)

func _show_income() -> void:
	if selected_reactor < 0: return
	var r: Dictionary = state.reactors[selected_reactor]
	var tpl: Dictionary = state.structure_data(r)
	var b: Dictionary = state.income_breakdown(r)
	var body = _dialog("每一枚金币，从哪里来", "%s · %s · Lv.%d" % [r.id,tpl.formula,r.level])
	body.add_child(UI.label("%.2f  金币 / 秒" % b.rate,38,UI.GOLD))
	if not tpl.known:
		body.add_child(UI.label("探索津贴 · 每秒0.15金币",23,UI.MINT))
		body.add_child(UI.paragraph("你已创造新的元素组合。目前没有适用的参考几何，无法判断科学匹配度。",18))
		body.add_child(UI.paragraph("探索津贴不随复杂度或炉等级放大；自创作品另有展示品库存，等待创意收购商，不掉落建材。",17))
		body.add_child(UI.paragraph("可以继续摆放、替换和保存；恢复为受支持的组成后，重新按该结构的参考几何生产。",17))
		return
	body.add_child(UI.paragraph("%.2f 基础速率 × %.3f 几何反馈 × %.2f 等级加成" % [b.base_rate,b.geometry_factor,b.level_factor],18,UI.TEXT))
	body.add_child(UI.label("01  结构复杂度  %.2f" % b.complexity,22,UI.MINT))
	body.add_child(UI.paragraph("计量原子数 %.2f · 元素种类 %d · 几何约束 %d\n原子数与约束数的奖励逐渐放缓，复杂度最高计4.0。" % [b.atoms,b.elements,b.constraints],16))
	if tpl.has("cell"):
		body.add_child(UI.paragraph("晶胞按占位计数：角点和面心共享，所以15个展示球只计5个原子；不能靠复制展示球提高复杂度。",15,UI.LILAC))
	body.add_child(UI.label("02  几何匹配  %d%%" % roundi(state.quality(r)*100),22,UI.MINT))
	body.add_child(UI.paragraph("让已有结构的键长与键角接近参考，能提高产率；原子重叠会扣分。复杂度相同，摆放仍会影响收益。",16))
	body.add_child(UI.label("03  反应炉等级  ×%.2f" % b.level_factor,22,UI.MINT))
	body.add_child(UI.paragraph("每升一级，增加45%的基础产能。完成精品订单可以获得升级所需的催化晶。",16))
	body.add_child(UI.paragraph("这些系数是游戏奖励规则。几何匹配不等于能量、稳定性或真实材料价值。",13,UI.MUTED))

func _show_sandbox() -> void:
	var works: Array = state.list_sandbox_structures()
	var body = _dialog("结构工坊", "SANDBOX STUDIO   /   从初始结构开始，自由调整原子和连接", true)
	body.add_child(UI.paragraph("配方提供元素与连接，初始坐标尚未调优。自己调整键长和角度，或解锁适用的科研方法来辅助优化；保存过的作品保留你的坐标。",15,UI.TEXT))
	body.add_child(UI.button("＋ 新建空白探索作品", func(): _open_sandbox_editor(state.new_sandbox_structure("未命名探索")), true))
	body.add_child(UI.label("初始配方  ·  %d 个" % state.baseline_ids().size(),20,UI.MINT))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	body.add_child(grid)
	for baseline_id in state.baseline_ids():
		var info: Dictionary = state.baseline_data(baseline_id)
		var card = PanelContainer.new()
		grid.add_child(card)
		var v = UI.column(card,7)
		v.add_child(UI.label("%s   %s" % [info.formula,info.name],18,UI.GOLD))
		v.add_child(UI.paragraph("%s · %d个原子 · %d条连接" % [baseline_id,info.atoms.size(),info.bonds.size()],13))
		var actions = UI.row(v, 8)
		actions.add_child(UI.button("开始调节", func(): _open_sandbox_editor(state.sandbox_from_baseline(baseline_id, "我的%s" % str(info.formula)))))
		actions.add_child(UI.button("保存初始草稿",_save_baseline_work.bind(baseline_id)))
	if works.size() > 0:
		body.add_child(UI.label("我的作品库  ·  %d 件" % works.size(),20,UI.LILAC))
		for work in works:
			body.add_child(UI.button("☆ %s  ·  %s  ·  打开作品" % [work.name,work.formula],_open_sandbox_editor.bind(work)))
	body.add_child(UI.paragraph("工作台支持增删原子、增加/移除连接、命名保存；晶胞和周期边界将在后续结构章节加入。",13,UI.MUTED))

func _open_sandbox_editor(structure: Dictionary) -> void:
	var editor = SandboxEditor.new()
	_begin_structure_editor(editor)
	editor.setup(state,structure,selected_reactor)
	if is_instance_valid(editor_return_view): editor.set_return_label("返回漫步")
	editor.saved.connect(func(): _toast("作品已保存，可以继续编辑或装入炉子"))
	editor.applied.connect(func(): _action("作品已应用，反应炉开始新一轮生产"))
	editor.dismissed.connect(func(): _finish_structure_editor(editor,true))

func _save_baseline_work(baseline_id: String) -> void:
	var info: Dictionary = state.baseline_data(baseline_id)
	var name := "我的%s" % str(info.formula)
	var result := state.save_sandbox_structure(name, state.sandbox_from_baseline(baseline_id, name))
	_action(result)
	_show_sandbox()

func _show_market() -> void:
	_show_island_panel("mail")

func _show_toolbox() -> void:
	_show_island_panel("toolbox")

func _show_island_panel(page: String, visitor: int=-1) -> void:
	_close_modal()
	var panel=IslandPanel.new(); add_child(panel); modal=panel
	panel.setup(state,selected_plot,page,visitor)
	panel.acted.connect(_action)
	panel.dismissed.connect(func(): if modal==panel: modal=null)
	panel.arrange.connect(func(kind): _show_campus("build"); modal.prop_choice=kind; modal._show("build"))
	panel.factory_requested.connect(_show_factory)
	panel.planet_v2_requested.connect(_show_planet_v2)
	panel.material_navigation.connect(_navigate_materials)

func _navigate_materials(route: String) -> void:
	match route:
		"elements": _show_toolbox(); modal._tab("elements")
		"sandbox": _show_sandbox()
		"research": _show_campus("research")
		"mail": _show_market()
		"island": _close_modal()
		"materials": _show_factory(); modal.dossier_family=true; modal._open_dossiers()
		"workshop":
			_show_factory()
			for id in state.planet.materials.designs:
				if state.planet.materials.designs[id].basis=="family_model": modal._choose_recipe(id); return
			modal.dossier_family=true; modal._open_dossiers()
		_: _show_factory()

func _show_factory(recipe_id: String="") -> void:
	_close_modal()
	if not recipe_id.is_empty(): last_factory_recipe=recipe_id
	var panel=FactoryPanel.new(); add_child(panel); modal=panel
	panel.setup(state)
	panel._choose_recipe(last_factory_recipe)
	panel.acted.connect(_action)
	panel.mail_requested.connect(_show_market)
	panel.planet_requested.connect(func(): last_factory_recipe=panel.selected_recipe; _show_planet_v2())
	panel.campus_requested.connect(func(tab):
		last_factory_recipe=panel.selected_recipe
		if tab=="build":
			for i in range(state.plots.size()):
				if state.plots[i].kind=="workshop": _select_plot(i); _show_campus("build"); return
			_show_build_menu()
		else: _show_campus(tab))
	panel.dismissed.connect(func():
		last_factory_recipe=panel.selected_recipe
		if modal==panel: modal=null
		if not snapshot_mode and not visual_test: state.save_game())

func _show_planet_v2() -> void:
	_close_modal()
	var panel=PlanetV2Panel.new(); add_child(panel); modal=panel
	panel.setup(state)
	panel.acted.connect(_action)
	panel.workshop_requested.connect(_show_factory)
	panel.dismissed.connect(func():
		if modal==panel: modal=null
		if not snapshot_mode and not visual_test: state.save_game())

func _deliver_market(index: int) -> void:
	_action(state.deliver(index))
	_show_market()

func _show_elements() -> void:
	var body = _dialog("元素仓库", "ELEMENT DEPOT   /   %d 种元素  /  钱包 %d 金币" % [state.elements.size(),int(state.coins)],true)
	body.add_child(UI.paragraph("一份原料可以替换一个显示位点。先买入仓库，再到原子工作台预览替换；应用时才消耗。",16,UI.TEXT))
	body.add_child(UI.paragraph("入门补给：H×2、O×1、S×1、Cl×2，新开局或从旧版升级时发放一次。试试把水分子的O换成S。",14,UI.LILAC))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	body.add_child(grid)
	for symbol in state.elements:
		var item: Dictionary = state.elements[symbol]
		var card = PanelContainer.new()
		card.custom_minimum_size.x = 438
		grid.add_child(card)
		var v = UI.column(card,8)
		v.add_child(UI.label("%s   %s     库存 %d" % [symbol,item.name,state.element_inventory.get(symbol,0)],24,Color(item.color)))
		v.add_child(UI.paragraph("参考半径 %.2f Å · %s" % [item.radius,item.radius_type],14))
		var price: int = int(state.economy.rules.element_shop.prices[symbol])
		var actions = UI.row(v,10)
		for quantity in [1,5]:
			var b = UI.button("买%d份 · %d金币" % [quantity,quantity*price],_confirm_element_purchase.bind(symbol,quantity))
			b.custom_minimum_size.y = 48
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(b)
			shop_buttons[symbol+str(quantity)] = b
	body.add_child(UI.paragraph("金币价格是游戏设定。半径要连同价态和配位环境使用，工作台会按当前体系显示。所有元素均为虚拟游戏道具。",14))

func _confirm_element_purchase(symbol: String, quantity: int) -> void:
	var quote: Dictionary = state.purchase_quote(symbol,quantity)
	var item: Dictionary = state.elements[symbol]
	var body = _dialog("准备入库", "%s  /  %s" % [symbol,item.name])
	body.add_child(UI.label(symbol,90,Color(item.color)))
	body.add_child(UI.label("%d 份原料  ·  %d 金币" % [quantity,quote.total],28,UI.GOLD))
	body.add_child(UI.paragraph("仓库现有 %d 份 → 购买后 %d 份\n钱包现有 %d 金币" % [state.element_inventory.get(symbol,0),state.element_inventory.get(symbol,0)+quantity,int(state.coins)],19,UI.TEXT))
	body.add_child(UI.paragraph("购买只放入仓库，不会立即修改反应炉。你可以在工作台选择替换位点并预览消耗。",16))
	purchase_confirm_button = UI.button("确认购买 · %d 金币" % quote.total,_buy_element.bind(symbol,quantity),true)
	purchase_confirm_button.disabled = not quote.ready
	body.add_child(purchase_confirm_button)
	if not quote.ready: body.add_child(UI.paragraph(quote.message,16,UI.GOLD))
	body.add_child(UI.button("取消，返回仓库",_show_elements))

func _buy_element(symbol: String, quantity: int) -> void:
	_action(state.buy_elements(symbol,quantity))
	_show_elements()

func _choose_template(key: String, build: bool) -> void:
	if not build and selected_reactor < 0:
		_close_modal()
		_toast("先选择反应炉，或点击空地建造晶体反应炉。")
		return
	var message = state.place_reactor(selected_plot,key) if build else state.change_template(selected_reactor,key)
	_close_modal()
	_select_plot(selected_plot)
	_action(message)

func _show_crate() -> void:
	var body = _dialog("一箱未知的小惊喜", "EXPLORER'S SUPPLY   /   第 %d 次探索" % (state.crate_count+1))
	var star = UI.label("◇",110,UI.GOLD)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(star)
	body.add_child(UI.paragraph("也许是一捧金币，也许是岛上的新伙伴。\n所有探索箱只消耗游戏金币。工程师需要空床位；\n住房不足时伙伴奖励折为85金币。",18,UI.TEXT))
	body.add_child(UI.paragraph(state.catalog.crate_probabilities.description,14))
	body.add_child(UI.label("距离保底伙伴奖励还有 %d 箱" % (10-state.crate_count%10),15,UI.LILAC))
	body.add_child(UI.button("打开首箱  ·  免费" if state.crate_count == 0 else "打开探索箱  ·  45 金币",_open_crate,true))

func _open_crate() -> void:
	var previous: int = state.crate_count
	var message = state.open_crate()
	_action(message)
	if state.crate_count == previous:
		return
	var body = _dialog("惊喜抵达！", "给每一次好奇，一个小小的奖励。")
	var reward = UI.label("☆",96,UI.GOLD)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(reward)
	body.add_child(UI.paragraph(message,24,UI.MINT))
	body.add_child(UI.button("带回小岛",_close_modal,true))
	body.add_child(UI.button("再看一箱",_show_crate))
	var tween = create_tween()
	reward.modulate.a = 0
	tween.tween_property(reward,"modulate:a",1.0,0.5)

func _show_crew() -> void:
	_show_campus("people")

func _show_build_menu() -> void:
	# The global build entry opens an available parcel, so parks are not hidden by reactor management.
	if state.plots[selected_plot].kind!="empty" or not state.plots[selected_plot].unlocked:
		for i in range(state.plots.size()):
			if state.plots[i].unlocked and state.plots[i].kind=="empty":
				_select_plot(i)
				break
	_show_campus("build")

func _show_campus(tab: String="overview") -> void:
	_close_modal()
	var panel=CampusPanel.new()
	modal=panel
	add_child(panel)
	panel.setup(state,selected_plot)
	panel.changed.connect(_action)
	panel.factory_requested.connect(_show_factory)
	panel.dismissed.connect(func(): modal=null)
	panel._show(tab)

func _show_research() -> void:
	var body = _dialog("把猜测，变成发现", "RESEARCH STATION   /   选中反应炉 → 解锁方法 → 计算 → 查看结果",true)
	research_open = true
	body.add_child(UI.paragraph("结构与产率的基础评分来自参考几何。下面的研究会实际进行数值计算，各方法只在标注范围内使用。",16))
	body.add_child(UI.label("科学家  %d / 3  ·  %s" % [state.scientists,state.science_summary()],18,UI.GOLD))
	if state.scientists < 3:
		body.add_child(UI.button("前往小镇 · 招募博士、教授与院士",_show_crew))
	if not state.science_pending.is_empty():
		body.add_child(UI.label("计算中 · 可以关闭窗口，继续经营小岛",19,UI.MINT))
		body.add_child(UI.button("取消本次研究",func(): _action(state.cancel_science()); _show_research()))
	if not state.science_runs.is_empty():
		body.add_child(UI.label("研究记录  /  最近24次",21,UI.LILAC))
		for i in range(state.science_runs.size()):
			var record: Dictionary = state.science_runs[i]
			body.add_child(UI.button("%s · %s · %s  →" % [record.reactor,state.science_method(record.method).name,"完成" if record.result.get("success",false) else "未完成"],_show_science_result.bind(i)))
	for method_id in state.science_method_ids():
		var info: Dictionary = state.science_method(method_id)
		var card = PanelContainer.new()
		body.add_child(card)
		var v = UI.column(card,7)
		v.add_child(UI.label(info.name,21,UI.MINT if method_id in state.science_unlocked else UI.MUTED))
		v.add_child(UI.paragraph("适用元素：%s · 最多%d原子\n%s" % [", ".join(info.elements),int(info.max_atoms),info.note],14))
		var status: Dictionary = state.science_method_status(method_id,selected_reactor)
		if not state.science_method_unlocked(method_id):
			v.add_child(UI.button("解锁 · %d金币 + %d催化晶 · 需%d位科学家" % [int(info.cost),int(info.catalysts),int(info.requires_scientists)],_unlock_science.bind(method_id)))
		else:
			v.add_child(UI.paragraph(str(status.message),14,UI.GOLD))
			var run = UI.button("计算所选反应炉样品 · 免费",_run_science.bind(method_id))
			run.disabled = not bool(status.supported) or not state.science_pending.is_empty()
			v.add_child(run)

func _show_science_result(index: int) -> void:
	if index<0 or index>=state.science_runs.size(): return
	var record: Dictionary = state.science_runs[index]
	var result: Dictionary = record.result
	var body = _dialog("研究结果", "%s  /  %s  /  %s" % [record.reactor,state.science_method(record.method).name,record.time],true)
	body.add_child(UI.paragraph(str(result.get("message","")),18,UI.MINT))
	body.add_child(UI.paragraph(str(result.get("notes","")),15,UI.GOLD))
	if result.has("energy"):
		body.add_child(UI.label("模型能量  %.7f %s" % [float(result.energy),result.get("units","")],24,UI.MINT))
	var history: Array = result.get("history",[])
	if history.size()>1:
		var samples: Array=[]
		for i in range(history.size()): samples.append([i,float(history[i].energy)])
		var chart = ScienceChart.new()
		body.add_child(chart)
		chart.setup(samples,"能量随迭代变化",str(result.get("units",""))+" · 横轴：迭代次数")
	if result.has("validation_rmse"):
		body.add_child(UI.paragraph("训练点 %d · 独立验证点 %d\n验证 RMSE %.7f eV · 最大误差 %.7f eV\n训练来源为人工 Morse 曲线，只在0.55–1.35 Å范围内使用。" % [result.training_count,result.validation_count,result.validation_rmse,result.validation_max_error],17,UI.LILAC))
	if result.get("density",[]).size()>1:
		var chart = ScienceChart.new()
		body.add_child(chart)
		chart.setup(result.density,"一维电子密度","密度：电子 / bohr · 横轴：位置 / bohr")
		body.add_child(UI.paragraph("密度积分 %.6f 个电子。此一维模型结果不应用到三维反应炉坐标。" % float(result.get("integrated_electrons",0)),15))
	if result.get("success",false) and result.get("can_apply",false):
		var reactor_index = -1
		for i in range(state.reactors.size()):
			if state.reactors[i].id==record.reactor: reactor_index=i
		var current = reactor_index>=0 and state.signature(state.reactors[reactor_index])==record.signature
		body.add_child(UI.paragraph("应用前自动收好旧批次与金币。计算不收费；应用按当前炉等级收取一次编辑费。" if current else "原样品已变化，这份结果已经过期，请重新计算。",15,UI.GOLD))
		if current:
			body.add_child(UI.button("应用优化坐标 · %d金币" % state.edit_cost(state.reactors[reactor_index]),_confirm_science_apply.bind(index),true))
	body.add_child(UI.button("返回研究站",_show_research))

func _confirm_science_apply(index: int) -> void:
	var body = _dialog("应用优化结构？","确认后按反应炉等级扣除固定编辑费，并保留原批次和待收金币。")
	body.add_child(UI.paragraph("这不会额外扣除元素。预览和计算均免费，只有结构实际改变时才收取编辑费。",18))
	body.add_child(UI.button("确认应用",func(): _action(state.apply_science_result(index)); _show_science_result(index),true))
	body.add_child(UI.button("返回结果，不作修改",_show_science_result.bind(index)))

func _show_relocation() -> void:
	move_source=selected_plot
	var body = _dialog("为建筑找个新位置","免费搬迁；反应炉结构、等级和库存都保留。")
	var count=0
	for i in range(state.plots.size()):
		if state.plots[i].unlocked and state.plots[i].kind=="empty":
			count+=1
			body.add_child(UI.button(state.plot_label(i)+" · 搬到这里",_relocate.bind(i)))
	if count==0: body.add_child(UI.paragraph("目前没有空地，先沿岛屿边缘开拓一格。",18))

func _relocate(target: int) -> void:
	var message: String=state.move_building(move_source,target)
	_close_modal()
	_select_plot(target)
	_action(message)
	world.focus_plot(target)

func _unlock_science(method_id: String) -> void:
	_action(state.unlock_science_method(method_id))
	_show_research()

func _run_science(method_id: String) -> void:
	_action(state.run_science_task(method_id,selected_reactor))
	_show_research()

func _show_collection() -> void:
	var body = _dialog("收藏的，是发现的瞬间", "FIELD NOTES   /   %d / %d 张结构卡片" % [state.discovered.size(),state.templates.size()],true)
	for key in state.templates:
		var tpl: Dictionary = state.templates[key]
		var panel = PanelContainer.new()
		body.add_child(panel)
		var v = UI.column(panel,9)
		var unlocked: bool = state.discovered.has(key)
		v.add_child(UI.label("%s   %s   %s" % [tpl.formula,tpl.name,"已发现" if unlocked else "待收集"],23,Color(tpl.color) if unlocked else UI.MUTED))
		v.add_child(UI.paragraph(tpl.description if unlocked else ("通过元素替换得到此组成，再收获第一份产物，即可解锁。" if tpl.get("substitution_only",false) else "建造或换装这个结构，并收获第一份产物，即可解锁科普卡。"),15))
		if unlocked:
			v.add_child(UI.paragraph("参考来源："+tpl.source,11))
			for r in state.reactors:
				if state.reference_id(r) == key:
					v.add_child(UI.label("我的样品   %s  ·  %s" % [r.id,state.signature(r)],12,UI.MINT))

func _show_help() -> void:
	var body = _dialog("欢迎来到原子工坊", "一座可以经营、收集和自由摆放的科学小岛。")
	for entry in [
		["01  调整原子", "选择反应炉 → 原子工作台。拖动彩球，观察产率；确认修改时按炉等级扣费。旧批次保留；换元素需要博士装炉。"],
		["02  收获与扩张", "点击注入微光赚金币。炉子持续产生待收金币和产物；收获时概率获得星砂、晶露、合金片。点击虚线地块开拓。"],
		["03  带伙伴来", "先造住宅并铺路，再招募伙伴。工程师到岗后才施工；科研小镇可以查看性格、日薪和生活心愿。"],
		["04  接一张订单", "每次到访可交付一次，之后等待20秒。库存达到3份即可交付。种类相符且几何响应与目标相差≤5个百分点，获得精品催化晶，用来升级炉子。"],
		["05  元素替换", "元素仓库购买原料 → 工作台选择位点 → 预览替换。应用时扣库存与一次编辑费；未识别的探索组合不参与精品订单。"],
		["06  解锁新知识", "先造科研院所和博士公寓，再招募博士生开展基础课题。院士增加进阶课题名额，教授可选带队提效；研究站保留势函数和一维DFT教学任务。"]
	]:
		body.add_child(UI.label(entry[0],20,UI.GOLD))
		body.add_child(UI.paragraph(entry[1],16))
	body.add_child(UI.button("开始我的小岛",_close_modal,true))

func _open_editor() -> void:
	if selected_reactor < 0:
		return
	if state.reactors[selected_reactor].get("sandbox",false):
		_open_sandbox_editor(state.reactor_work(state.reactors[selected_reactor]))
		return
	var editor = Editor.new()
	_begin_structure_editor(editor)
	editor.setup(state,selected_reactor)
	if is_instance_valid(editor_return_view): editor.set_return_label("返回漫步")
	editor.applied.connect(func(): _finish_structure_editor(editor); _action("修改已提交；更换元素等待博士装炉，已有产物会保留。"))
	editor.dismissed.connect(func(): _finish_structure_editor(editor))

func _begin_structure_editor(editor: Control) -> void:
	# Keep the caller's camera and scene alive only for this editor visit.
	var return_view: Control=modal if is_instance_valid(modal) and modal.has_method("set_editor_open") else null
	if is_instance_valid(return_view):
		return_view.set_editor_open(true)
		modal=null
	_close_modal()
	editor_return_view=return_view
	if is_instance_valid(return_view): world_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(editor); modal=editor

func _finish_structure_editor(editor: Control,return_to_library: bool=false) -> void:
	if modal!=editor: return
	editor.queue_free(); modal=null
	if is_instance_valid(editor_return_view):
		modal=editor_return_view; editor_return_view=null
		modal.set_editor_open(false)
		world_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	elif return_to_library: _show_sandbox()
	else: world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		world_pointer_down = false
		world_touch_index = -1
		building_drag.cancel()
		if not snapshot_mode and not visual_test:
			state.save_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(modal):
			if modal.has_method("handle_back") and modal.handle_back(): return
			_close_modal()
		else:
			_toast(state.save_game())
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not snapshot_mode and not visual_test:
			state.save_game()
		state.close_science()
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if light_bridge_busy: return
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal) and modal.has_method("handle_back") and modal.handle_back(): return
		_close_modal()

func _capture_demo() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/demo.png")
	print("SCREENSHOT: artifacts/demo.png")
	get_tree().quit()

func _run_visual_test() -> void:
	await get_tree().create_timer(1.0).timeout
	# Exercise real Godot input dispatch, not just model methods.
	var plot_screen: Vector2 = world.camera.unproject_position(Vector3(-3,0.08,-3))
	await _test_pointer(world_box.get_global_transform() * plot_screen, true)
	await _test_pointer(world_box.get_global_transform() * plot_screen, false)
	assert(selected_plot == 0,"Mouse picking must select the visible plot")
	var touch_plot: Vector2 = world.camera.unproject_position(Vector3(3,0.08,-3))
	await _test_touch(world_box.get_global_transform() * touch_plot, true)
	await _test_touch(world_box.get_global_transform() * touch_plot, false)
	assert(selected_plot == 2,"Native touch must select the visible plot")
	var initial_camera: Vector3 = world.camera.position
	await _test_pointer(Vector2(808, 265), true)
	await _test_pointer(Vector2(808, 265), false)
	assert(not world.camera.position.is_equal_approx(initial_camera),"Island rotation button must work without a right click")
	_select_plot(4)
	state.tick(28)
	_action(state.harvest(0))
	_select_plot(3)
	_action(state.place_reactor(3,"perovskite"))
	state.tick(20)
	_select_plot(5)
	_action(state.place_decoration(5,"garden"))
	_select_plot(4)
	toast_panel.hide()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/demo-developed.png")
	_open_editor()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/editor.png")
	var editor = modal
	var old_point: Array = editor.points[1].duplicate()
	var atom_screen: Vector2 = editor.camera.unproject_position(editor.atom_nodes[1].position)
	var atom_global: Vector2 = editor.viewbox.get_global_transform() * atom_screen
	await _test_pointer(atom_global,true)
	var motion = InputEventMouseMotion.new()
	motion.position = atom_global + Vector2(20,10)
	motion.global_position = motion.position
	motion.relative = Vector2(20,10)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await _test_pointer(motion.position,false)
	assert(editor.points[1] != old_point,"Dragging a visible atom must change its coordinates")
	var before_touch: Array = editor.points[1].duplicate()
	atom_screen = editor.camera.unproject_position(editor.atom_nodes[1].position)
	atom_global = editor.viewbox.get_global_transform() * atom_screen
	await _test_touch(atom_global, true)
	var touch_drag = InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = atom_global + Vector2(22, 14)
	touch_drag.relative = Vector2(22, 14)
	Input.parse_input_event(touch_drag)
	await get_tree().process_frame
	await _test_touch(touch_drag.position, false)
	assert(editor.points[1] != before_touch,"Native touch drag must move an atom")
	assert(editor.active_touch == -1 and not editor.dragging,"Touch release clears atom capture")
	var old_camera: Vector3 = editor.camera.position
	var old_zoom: float = editor.camera.size
	await _test_pointer(Vector2(122, 740), true)
	await _test_pointer(Vector2(122, 740), false)
	await _test_pointer(Vector2(688, 740), true)
	await _test_pointer(Vector2(688, 740), false)
	assert(not editor.camera.position.is_equal_approx(old_camera),"Editor rotation button must work")
	assert(editor.camera.size < old_zoom,"Editor zoom button must work")
	var previous = state.coins
	modal._apply()
	assert(state.coins < previous,"Editor must charge on confirmed change")
	await get_tree().process_frame
	_show_collection()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/collection.png")
	_close_modal()
	_show_crate()
	_open_crate()
	assert(state.crate_count == 1,"Crate UI should open first free crate")
	_close_modal()
	_show_crew()
	_close_modal()
	_show_research()
	_close_modal()
	_select_plot(3)
	_open_editor()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/crystal-editor.png")
	_close_modal()
	# Version 0.2: quote/transaction agreement and live order controls.
	state.reactors[0].stock = 3
	_show_market()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/market-v02.png")
	var advertised: Dictionary = state.delivery_quote(0)
	var before_sale: float = state.coins
	var before_deliveries: int = state.deliveries
	var sell_position: Vector2 = market_rows[0].button.get_global_rect().get_center()
	await _test_pointer(sell_position,true)
	await _test_pointer(sell_position,false)
	assert(state.deliveries == before_deliveries + 1 and state.coins == before_sale + advertised.payment,"Order button must charge stock and pay the preview price")
	_close_modal()
	state.coins = 2500
	state.materials = [200,200,200]
	for x in range(2,6): state.buy_plot(state.plot_at(x,0))
	var distant: int = state.plot_at(4,0)
	state.place_reactor(distant,"methane")
	state.tick(20)
	_sync_world()
	_locate_plot(distant)
	await get_tree().process_frame
	var distant_position: Vector2 = world_box.get_global_transform() * world.camera.unproject_position(Vector3(12.8,0.08,0.7))
	await _test_touch(distant_position,true)
	await _test_touch(distant_position,false)
	assert(selected_plot == distant,"Expanded plots must accept native touch after camera movement")
	var before_pan: Vector3 = world.camera.position
	var before_selection: int = selected_plot
	await _test_touch(Vector2(630,490),true)
	var map_drag = InputEventScreenDrag.new()
	map_drag.index = 0
	map_drag.position = Vector2(540,490)
	map_drag.relative = Vector2(-90,0)
	Input.parse_input_event(map_drag)
	await get_tree().process_frame
	await _test_touch(map_drag.position,false)
	assert(not world.camera.position.is_equal_approx(before_pan) and selected_plot == before_selection,"Map swipes move the camera without purchasing or selecting a plot")
	assert(not world_pointer_down and world_touch_index == -1,"Map touch capture releases")
	world.reset_view()
	world.zoom_view(1.55)
	world.focus_plot(state.plot_at(1,0))
	toast_panel.hide()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/expanded-v02.png")
	_show_income()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/income-v02.png")
	_show_map()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/map-v02.png")
	_close_modal()
	_show_elements()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/warehouse-v03.png")
	_confirm_element_purchase("Cl",5)
	await get_tree().process_frame
	var old_chlorine: int = state.element_inventory.Cl
	var old_wallet: float = state.coins
	var purchase_position: Vector2 = purchase_confirm_button.get_global_rect().get_center()
	await _test_pointer(purchase_position,true)
	await _test_pointer(purchase_position,false)
	assert(state.element_inventory.Cl == old_chlorine+5 and state.coins == old_wallet-40,"Purchase confirmation charges coins and adds exactly five Cl")
	_close_modal()
	_select_plot(4)
	_open_editor()
	await get_tree().process_frame
	var substitution_editor = modal
	substitution_editor.picked = 0
	substitution_editor._show_palette()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/palette-v03.png")
	var sulfur_position: Vector2 = substitution_editor.palette_buttons.S.get_global_rect().get_center()
	var sulfur_before: int = state.element_inventory.S
	old_wallet = state.coins
	await _test_pointer(sulfur_position,true)
	await _test_pointer(sulfur_position,false)
	assert(state.reference_id(substitution_editor.draft) == "hydrogen_sulfide" and state.reference_id(state.reactors[0]) == "water","Palette updates draft reference without mutating the reactor")
	assert(state.element_inventory.S == sulfur_before and state.coins == old_wallet,"Element preview is free")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/substitution-v03.png")
	var commit_position: Vector2 = substitution_editor.apply_button.get_global_rect().get_center()
	await _test_pointer(commit_position,true)
	await _test_pointer(commit_position,false)
	assert(state.reference_id(state.reactors[0]) == "hydrogen_sulfide" and state.element_inventory.S == sulfur_before-1 and state.coins == old_wallet-12,"Editor commit atomically applies the substitution")
	_open_editor()
	await get_tree().process_frame
	var undo_editor = modal
	undo_editor.picked = 1
	undo_editor._replace_element("Cl")
	assert(state.reference_id(undo_editor.draft).is_empty(),"Mixed unknown draft has no scientific reference")
	assert(undo_editor.response_label.text.contains("未知"),"Unknown draft is visibly labeled unknown")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/exploration-v03.png")
	undo_editor._restore()
	assert(state.reference_id(undo_editor.draft) == "hydrogen_sulfide" and state.edit_quote(0,undo_editor.points,undo_editor.symbols).required.is_empty(),"Undo restores both coordinates and composition without element costs")
	undo_editor._show_palette()
	assert(undo_editor.handle_back() and not is_instance_valid(undo_editor.palette),"Android back first dismisses the element picker")
	undo_editor._cancel()
	await get_tree().process_frame
	# All six halide display sites are charged when applying a group replacement.
	_select_plot(3)
	_open_editor()
	await get_tree().process_frame
	var crystal_editor = modal
	crystal_editor.picked = 9
	crystal_editor.replace_group = true
	crystal_editor._replace_element("Cl")
	var group_quote: Dictionary = state.edit_quote(selected_reactor,crystal_editor.points,crystal_editor.symbols)
	assert(group_quote.ready and group_quote.required.Cl == 6 and group_quote.reference_id == "perovskite_chloride","Group preview shows six chlorine units and the new crystal reference")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/chloride-v03.png")
	crystal_editor._cancel()
	await get_tree().process_frame
	assert(state.element_inventory.Cl == old_chlorine+5,"Canceling grouped substitution spends no elements")
	_close_modal()
	print("UI SMOKE PASS: existing island/market/touch flows, warehouse purchase, element palette, free preview, substitution commit, unknown labeling, undo, Android back, grouped halide preview and cancel")
	get_tree().quit()

func _test_pointer(pos: Vector2, down: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)
	await get_tree().process_frame

func _test_touch(pos: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.position = pos
	event.index = 0
	event.pressed = down
	Input.parse_input_event(event)
	await get_tree().process_frame


func _show_island_walk() -> void:
	_close_modal()
	var panel=preload("res://scripts/island_walk_panel.gd").new(); add_child(panel); modal=panel; panel.setup(state)
	world_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	panel.dismissed.connect(func():
		if modal==panel: modal=null
		world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS)
	panel.requested.connect(func(kind: String,index: int):
		if kind=="planet": _show_planet_v2(); modal._enter()
		elif kind=="miniatures": _show_miniatures()
		elif kind=="workshop": _show_factory()
		elif kind=="reactor": _select_plot(index); _open_editor()
		else: _close_modal(); _select_plot(index))

func _show_miniatures() -> void:
	var body=_dialog("河湾作品 · 把探索带回家", "星球上装备微缩器，瞄准自建作品装箱。作品会从原地搬走，材料不会复制。",true)
	var boxes=state.planet.v2.construction.miniatures
	if boxes.is_empty():
		body.add_child(UI.paragraph("还没有带回来的作品。先用工艺车间做出的构件搭一座小屋、一段桥或雕塑，再用背包里的微缩器收纳。\n每件最多64块、8×8×8格；有作物的种植箱先收获。",18))
		body.add_child(UI.button("走过光桥去河湾",_show_planet_v2,true)); return
	body.add_child(UI.paragraph("每块地可以放一座展台，摆在地块角落。展品仍属于你：收回后可在河湾重新展开。",16,UI.MUTED))
	for id in boxes:
		var item=boxes[id]; var card=PanelContainer.new(); card.add_theme_stylebox_override("panel",UI.style(Color("213c45"),14)); body.add_child(card)
		var row=UI.row(card,12); row.add_child(UI.label("%s · %d块" % [item.name,item.blocks.size()],19,UI.MINT))
		var options=OptionButton.new(); options.custom_minimum_size=Vector2(380,48); row.add_child(options)
		options.add_item("留在背包",0); options.set_item_metadata(0,-1)
		for i in range(state.plots.size()):
			var p=state.plots[i]
			if not p.unlocked or p.kind=="plaza": continue
			options.add_item("地块 (%d,%d) · %s" % [p.x,p.z,p.kind]); var at=options.item_count-1; options.set_item_metadata(at,i)
			if item.plot==i: options.select(at)
		row.add_child(UI.button("摆放 / 收回",func():
			_action(state.planet.command(state,"v2_mini_exhibit",{"id":id,"plot":options.get_item_metadata(options.selected)})); _show_miniatures(),true))
	body.add_child(UI.button("走近展台看看",_show_island_walk))
