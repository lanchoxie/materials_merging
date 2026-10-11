extends Control
const TestInput = preload("res://scripts/core/test_input.gd")

const UI = preload("res://scripts/ui.gd")
const Model = preload("res://scripts/lab_state.gd")
const World = preload("res://scripts/world_view.gd")
const Editor = preload("res://scripts/atom_editor.gd")
const ScienceChart = preload("res://scripts/science_chart.gd")
const SandboxEditor = preload("res://scripts/sandbox_editor.gd")
const BuildingDrag=preload("res://scripts/building_drag.gd")
var building_drag=BuildingDrag.new()
const TownBuild=preload("res://scripts/town_build_mode.gd")
const Town=preload("res://scripts/island_town.gd")
var town_build=TownBuild.new()
## Courtyard item picked in the world or sidebar: its uid, 0 for the main building, -1 for none.
var selected_item: int=-1
## v0.31: plot whose recycle button was tapped once (a second tap confirms); -1 when none.
var town_recycle_armed: int=-1
var town_shop_category="building"
const CampusView = preload("res://scripts/campus_view.gd")
const IslandPanel=preload("res://scripts/island_panel.gd")
const FactoryPanel=preload("res://scripts/factory_panel.gd")
const PlanetV2Panel=preload("res://scripts/planet_v2_panel.gd")
const IslandWalk=preload("res://scripts/island_walk_panel.gd")
const RefineryPanel=preload("res://scripts/refinery_panel.gd")
const FabricatorPanel=preload("res://scripts/fabricator_panel.gd")
const StarforgePanel=preload("res://scripts/starforge_panel.gd")
const StarforgeWalk=preload("res://scripts/starforge_walk_panel.gd")
const ReactorLook=preload("res://scripts/reactor_look.gd")
const Coach=preload("res://scripts/coach.gd")
const CoachTours=preload("res://scripts/coach_tours.gd")
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
var rank_label: Label
var rank_bar: ProgressBar
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
## v0.28 navigation: screens that stepped aside for the current one (island walk, planet). They keep
## their camera, position and mode; closing the current screen resumes the top one.
var return_stack: Array=[]
## The screen the current one returns to (kept for older callers and tests).
var editor_return_view: Control:
	get: return _top_suspended()
var refresh_clock: float = 0
var save_clock: float = 0
var toast_clock: float = 0
var snapshot_mode: bool = false
var visual_test: bool = false
var coach: CanvasLayer
## Tours start by themselves in the real game; script-driven runs (tests, captures) opt in.
var coach_autostart: bool = Engine.get_main_loop() != null and Engine.get_main_loop().get_script() == null
var help_panel: Control
var live_badge: Label
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
var research_open: bool = false
var move_source: int = -1
var last_factory_recipe="standard_water_crate"
var light_bridge
var light_bridge_busy=false
var miniature_view
const IslandFeedback=preload("res://scripts/island_feedback.gd")
var feedback=IslandFeedback.new()
var pointer_position: Vector2=Vector2(720,450)
var shown_coins: float=-1.0
var sound_button: Button
const Codex = preload("res://scripts/codex.gd")
const ChemIndex = preload("res://scripts/chem_index.gd")
const ChemIndexView = preload("res://scripts/chem_index_view.gd")
const INDEX_PAGE = 16
## v0.29 index browser: current tab, element filter, found-only toggle and page.
var index_kind: String = "molecule"
var index_filter: Array = []
var index_found_only: bool = false
var index_page: int = 0
var index_tabs: HBoxContainer
var index_chips: HFlowContainer
var index_grid: GridContainer
var index_count: Label
var index_pager: HBoxContainer
var index_credits_button: Button
const Milestones=preload("res://scripts/milestones.gd")
const TestMode=preload("res://scripts/test_mode.gd")
const DayCycle = preload("res://scripts/core/day_cycle.gd")
var goal_button: Button
var goal_bar: ProgressBar
var welcome: Dictionary={}

func _ready() -> void:
	if Engine.get_main_loop().get_script() != null: state.default_slot_enabled = false
	if TestMode.enabled(): state.save_name = TestMode.SAVE_NAME
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
		if state.load_game(): welcome=state.offline_catch_up(int(Time.get_unix_time_from_system()))
	theme = UI.make_theme()
	_build_ui()
	building_drag.setup(self)
	town_build.setup(self)
	_sync_world()
	_select_plot(4)
	_update_labels()
	feedback.capture(state)
	if not snapshot_mode: _ambience("amb_island")
	coach = Coach.new(); add_child(coach)
	coach.finished.connect(_coach_finished)
	if snapshot_mode or visual_test: coach_autostart = false
	_coach("island")
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	if snapshot_mode:
		_capture_demo.call_deferred()
	if visual_test and "--release-ui-test" not in OS.get_cmdline_user_args():
		_run_visual_test.call_deferred()
	if "--river-preview" in OS.get_cmdline_user_args() and not visual_test and not snapshot_mode:
		_show_planet_v2.call_deferred()
	elif not welcome.is_empty():
		_show_welcome.call_deferred(welcome)

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
	# v0.34 岛主等级: a visible XP bar; "+XP" pops rise from it.
	var rank_box = UI.column(h, 4)
	rank_box.custom_minimum_size.x = 176
	rank_label = UI.label("岛主 Lv.1", 12, UI.LILAC)
	rank_box.add_child(rank_label)
	rank_bar = ProgressBar.new(); rank_bar.show_percentage = false; rank_bar.custom_minimum_size = Vector2(170, 12); rank_bar.max_value = 1.0
	rank_box.add_child(rank_bar)
	var supplies = UI.column(h, 3)
	supplies.custom_minimum_size.x = 250
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
	sound_button = UI.button("♪ 开" if _sfx() == null or _sfx().enabled else "♪ 关", _toggle_sound)
	sound_button.custom_minimum_size.x = 70
	sound_button.tooltip_text = "声音开关"
	h.add_child(sound_button)
	var save = UI.button("保存", func(): _toast(state.save_game()))
	save.custom_minimum_size.x = 66
	h.add_child(save)
	if TestMode.enabled():
		var tester = UI.button("测试", _show_test_panel)
		tester.custom_minimum_size.x = 66
		h.add_child(tester)
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
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = UI.paragraph("", 15, UI.TEXT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	toast_panel.hide()
	save_label = UI.label("v0.49 溪石部落 · 原住民盖房 · 交谈与交易" + ("  ·  测试版（独立存档）" if TestMode.enabled() else ""), 11, UI.GOLD if TestMode.enabled() else UI.MUTED)
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
	# Sits over the sea since v0.25: an outline keeps it readable in any light.
	land_label.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.1, 0.9))
	land_label.add_theme_constant_override("outline_size", 5)
	add_child(land_label)
	live_badge = UI.label("●  LIVE  /  生长中", 12, UI.MINT)
	live_badge.position = Vector2(897,146)
	add_child(live_badge)
	var quest = UI.box(self, Rect2(248,689,796,68),Color("192e39"))
	quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var q = UI.row(quest,14)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.add_child(UI.label("↗",25,UI.GOLD))
	# The claim button sits left of the toast's footprint so it stays visible after every action.
	goal_button = UI.button("领取", _claim_goal, true)
	goal_button.custom_minimum_size.x = 66
	goal_button.hide()
	q.add_child(goal_button)
	var goal_column = VBoxContainer.new()
	goal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_column.alignment = BoxContainer.ALIGNMENT_CENTER
	goal_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_column.add_theme_constant_override("separation", 5)
	q.add_child(goal_column)
	quest_label = UI.paragraph("",14)
	quest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_column.add_child(quest_label)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.max_value = 1.0
	goal_bar.step = 0.0
	goal_bar.custom_minimum_size.y = 5
	goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in [["background", Color("0f2029")], ["fill", UI.GOLD]]:
		var bar_style: StyleBoxFlat = UI.style(part[1], 3, part[1])
		bar_style.set_content_margin_all(0)
		goal_bar.add_theme_stylebox_override(part[0], bar_style)
	goal_column.add_child(goal_bar)
	var all_goals = UI.button("目标", _show_goals)
	all_goals.custom_minimum_size.x = 66
	q.add_child(all_goals)

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
		["精炼厂", _show_refinery],
		["制造台", _show_fabricator],
		["星锻岛", _show_starforge],
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
	if event is InputEventMouseMotion and town_build.active and not world_pointer_down:
		town_build.hover(event.position)
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
	if town_build.active:
		building_drag.cancel(); town_build.press(pos)
	elif _on_light_bridge(pos): building_drag.cancel()
	else: building_drag.begin(pos)
	world_pointer_down = true
	world_pointer_start = pos
	world_pointer_last = pos
	world_pointer_dragged = false

func _move_world_pointer(pos: Vector2) -> void:
	if not world_pointer_down: return
	if town_build.active:
		if pos.distance_to(world_pointer_start) > 10.0: world_pointer_dragged = true
		town_build.hover(pos)
		world_pointer_last = pos
		return
	if building_drag.move(pos):
		world_pointer_last=pos
		return
	if pos.distance_to(world_pointer_start) > 10.0: world_pointer_dragged = true
	if world_pointer_dragged:
		world.pan_view((world_pointer_last - pos) * world.camera.size / (world_box.size.y * World.PITCH))
	world_pointer_last = pos

func _end_world_pointer(pos: Vector2) -> void:
	if town_build.active:
		if world_pointer_down: town_build.release(pos, world_pointer_dragged)
		world_pointer_down = false
		return
	if building_drag.release(pos):
		world_pointer_down=false
		return
	if world_pointer_down and not world_pointer_dragged:
		_pick_world(pos)
	world_pointer_down = false

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed: pointer_position = event.position
	if not is_instance_valid(world_box): return
	# A release outside the viewport must not leave a captured drag behind.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not world_box.get_global_rect().has_point(event.position):
			world_pointer_down = false
			town_build.painting = false
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
		# v0.31: a footprint can spill over a plot edge, so the tap selects the item's own plot.
		var hit: Array = _item_under(screen_position)
		if hit.is_empty(): _select_plot(plot_index, -1)
		else: _select_plot(int(hit[0]), int(hit[1]))
		_tap_harvest(plot_index)

## Courtyard item under a tap: [owner plot, uid] (uid 0 = main building), or [] for open ground.
func _item_under(screen_position: Vector2) -> Array:
	var point = world.screen_point(screen_position)
	if point == null: return []
	var hit: Dictionary = state.town_at(Town.global_at(point))
	if hit.is_empty(): return []
	var p: Dictionary = state.plots[int(hit.plot)]
	if not p.unlocked or p.kind == "plaza" or p.kind in Town.LEGACY_WHOLE: return []
	if str(hit.id).is_valid_int(): return [int(hit.plot), int(hit.id)]
	if hit.id == "p" and Town.is_building(str(p.kind)): return [int(hit.plot), 0]
	return []

## Tapping a reactor that has something ready collects it right there in the world.
func _tap_harvest(plot_index: int) -> void:
	var p: Dictionary = state.plots[plot_index]
	if p.kind != "reactor": return
	var r: Dictionary = state.reactors[int(p.rid)]
	if float(r.build_left) <= 0.0 and (int(r.get("pending", 0)) > 0 or float(r.stored_coins) >= 1.0):
		_action(state.harvest(int(p.rid)))

func _on_light_bridge(local_position: Vector2) -> bool:
	return is_instance_valid(light_bridge) and light_bridge.hit(world.camera,local_position*Vector2(world_viewport.size)/world_box.size)

func _enter_light_bridge() -> void:
	if light_bridge_busy or is_instance_valid(modal): return
	# v0.39: once the present-day camp is farming, the bridge becomes a time gate with an era dial.
	if state.planet.gate_ready(): _show_time_gate(); return
	_cross_light_bridge()

func _show_time_gate() -> void:
	var body=_dialog("时间之门 · 彩虹光桥","同一条河湾，不同的时代。背包里的原料、种子、矿物和标本图鉴跟着你走；建筑、营地和动物留在各自的时代。")
	var here=str(state.planet.v2.epoch)
	if state.planet.v2.planet!="earth":
		body.add_child(UI.paragraph("时间之门只连着地球的各个时代。你现在在%s：彩虹光桥直接通往这里的着陆点；要穿越时代，先乘飞船回地球。" % str(state.planet.v2.planet_info().name),16))
		body.add_child(UI.button("走过光桥",func(): _close_modal(); _cross_light_bridge(),true))
		return
	for id in state.planet.v2.rules.epochs:
		var e: Dictionary=state.planet.v2.rules.epochs[id]
		var card=PanelContainer.new(); card.add_theme_stylebox_override("panel",UI.style(Color("213c45") if id!=here else Color("2b4d4a"),14)); body.add_child(card)
		var col=UI.column(card,6)
		col.add_child(UI.label("%s · %s%s" % [e.name,e.get("era",""),"（你在这里）" if id==here else ""],20,UI.MINT if id==here else Color("bfe6ff")))
		if e.has("story"): col.add_child(UI.paragraph(str(e.story),15))
		if e.has("note"): col.add_child(UI.paragraph(str(e.note),12,UI.MUTED))
		col.add_child(UI.button("回到%s的河湾" % e.name if id==here else "穿越到%s" % e.name,func(): _through_gate(id),true))

## v0.48 星图: every planet with its globe map; the current one is marked. Launching jumps the ship
## (Wh from its battery), swaps the world and reopens the planet view in orbit over the destination.
func _show_voyage() -> void:
	var Shape=preload("res://scripts/planet_shape.gd"); var Globe=preload("res://scripts/planet_globe.gd")
	var ind=state.industry; var here=str(state.planet.v2.planet)
	var body=_dialog("星图 · 星际航行","飞船电量 %.0f / %.0f Wh · 每次跃迁 %.0f Wh。背包、种子、矿物和标本跟着你走；每颗星球上的建筑、地形和生灵留在原地。" % [float(ind.ship_state.charge),float(ind.ship_state.cap),float(ind.rules().ship.jump_wh)],true)
	for id in Shape.planets().order:
		var info: Dictionary=Shape.profile_of(id)
		var card=PanelContainer.new(); card.add_theme_stylebox_override("panel",UI.style(Color("2b4d4a") if id==here else Color("213c45"),14)); body.add_child(card)
		var row=UI.row(card,14)
		var env=preload("res://scripts/planet_environment.gd").new(); env.set_profile({} if id=="earth" else info)
		var map=TextureRect.new(); map.texture=Globe.equirect(env); map.custom_minimum_size=Vector2(300,150); map.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; map.stretch_mode=TextureRect.STRETCH_SCALE; row.add_child(map)
		var col=UI.column(row,6); col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		col.add_child(UI.label("%s · %s%s" % [info.name,info.title,"（你在这里）" if id==here else ""],21,UI.MINT if id==here else Color("e8c8ff")))
		col.add_child(UI.paragraph(str(info.description),15))
		var go=UI.button("留在%s" % info.name if id==here else "跃迁到%s" % info.name,func(): _launch(id),true)
		go.disabled=id==here or float(ind.ship_state.charge)<float(ind.rules().ship.jump_wh); col.add_child(go)

func _launch(id: String) -> void:
	var message: String=state.planet.voyage(state,id)
	if not message.begins_with("跃迁完成"): _toast(message); return
	_close_all(); state.sync_gear()
	_show_planet_v2(); _toast(message)

func _through_gate(id: String) -> void:
	_close_modal()
	if id!=str(state.planet.v2.epoch):
		var message: String=state.planet.travel(id)
		state.sync_gear(); _toast(message)
	_cross_light_bridge()

func _cross_light_bridge() -> void:
	if light_bridge_busy: return
	light_bridge_busy=true; light_bridge.activate(); building_drag.cancel()
	var veil=ColorRect.new(); veil.color=Color(0.60,0.88,0.96,0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(veil)
	var tween=create_tween(); tween.tween_property(veil,"color:a",1.0,0.3)
	await tween.finished
	_show_planet_v2(); modal.enter_first_person(); veil.move_to_front()
	tween=create_tween(); tween.tween_property(veil,"color:a",0.0,0.35)
	await tween.finished
	veil.queue_free(); light_bridge_busy=false

func _select_plot(index: int, item: int=-1) -> void:
	if index < 0 or index >= state.plots.size(): return
	if index != selected_plot: town_recycle_armed = -1
	selected_plot = index
	selected_item = item
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
		side.add_child(UI.button("＋  反应炉   100 金币 + 元素",func(): _show_templates(true),true))
		var gate: Dictionary = state.install_status()
		side.add_child(UI.paragraph("选择初始结构，消耗结构里的元素；工程师建炉，博士装炉。\n基础建造时间12秒，多人协作更快。" if gate.ok else "⚠ " + str(gate.message),13,UI.MUTED if gate.ok else UI.GOLD))
		UI.spacer(side,18)
		side.add_child(UI.label("给小岛一点温度",15,UI.LILAC))
		side.add_child(UI.button("住宅 · 院所 · 食堂 · 公园",_show_campus.bind("build"),true))
		side.add_child(UI.paragraph("一块地是12×12格，每一格都能用：可以并排盖好几栋建筑，再摆装饰、围栅栏、放展台。建筑和装饰可以跨过地块边缘。",13))
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
		var look: Dictionary = ReactorLook.tier_info(int(r.level))
		side.add_child(UI.label("%s   Lv.%d · %s" % [r.id,r.level,look.name],14,Color(str(look.accent))))
		var formula_row = UI.row(side,10)
		formula_row.add_child(UI.label(tpl.formula,32,UI.MINT))
		var phase_id: String = state.reactor_phase(r)
		var badge := PanelContainer.new(); badge.name = "PhaseBadge"
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_theme_stylebox_override("panel",UI.style(Color(str(ReactorLook.PHASE_COLORS.get(phase_id,"5b6f73"))).darkened(0.55),10,Color(str(ReactorLook.PHASE_COLORS.get(phase_id,"8aa0a4")))))
		badge.add_child(UI.label(ReactorLook.PHASE_NAMES.get(phase_id,"未鉴定"),15,Color(str(ReactorLook.PHASE_COLORS.get(phase_id,"c8d4d6")))))
		badge.tooltip_text = ReactorLook.phase_text(str(tpl.get("reference_id",""))) if not phase_id.is_empty() else "结构未收录，物态未鉴定"
		formula_row.add_child(badge)
		badge.pivot_offset = Vector2(24,14); badge.scale = Vector2(0.6,0.6)
		badge.create_tween().tween_property(badge,"scale",Vector2.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		side.add_child(UI.paragraph(tpl.name,16,UI.TEXT))
		side.add_child(UI.paragraph(badge.tooltip_text,12,UI.MUTED))
		var found: Dictionary = tpl.get("index",{})
		var index_line = UI.paragraph(ChemIndex.summary(found),12,UI.GOLD if ChemIndex.is_find(found) else UI.MUTED)
		index_line.name = "IndexLine"
		side.add_child(index_line)
		if ChemIndex.is_find(found): side.add_child(UI.button("查看真实数据  →",_show_index_entry.bind(str(found.key))))
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
		side.add_child(UI.button("有机物 · 反应釜合成",_show_organic_synthesis.bind(selected_reactor)))
		var h = UI.row(side,8)
		var harvest = UI.button("收获",func(): _action(state.harvest(selected_reactor)))
		harvest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(harvest)
		var switch_b = UI.button("更换配方",func(): _show_templates(false))
		h.add_child(switch_b)
		side.add_child(UI.button("升级   %d 金币 + 1 催化晶" % state.upgrade_cost(r),_upgrade_reactor))
		var next_look: int = ReactorLook.next_tier_level(int(r.level))
		if next_look > 0: side.add_child(UI.paragraph("Lv.%d 解锁新外观「%s」" % [next_look,ReactorLook.tier_info(next_look).name],12,UI.MUTED))
		side.add_child(UI.paragraph("本等级编辑固定 %d 金币 / 次\n样品指纹  %s" % [state.edit_cost(r),state.signature(r).substr(0,10)],12))
		UI.spacer(side,4)
		if not r.get("installation",{}).is_empty():
			var job: Dictionary = r.installation
			var parts: Array = []
			for symbol in job.elements: parts.append("%s×%d" % [symbol,int(job.elements[symbol])])
			side.add_child(UI.paragraph("博士装炉中：%s 悬在炉口，装完才落进腔体 · 旧炉继续运转" % "、".join(parts) if float(job.remaining)<float(state.island_rules.logistics.installation_seconds) else "新样品（%s）等待博士装炉 · 旧炉继续运转" % "、".join(parts),14,UI.GOLD))
			side.add_child(UI.button("取消装炉并退款",func(): _action(state.cancel_installation(selected_reactor))))
		side.add_child(UI.paragraph("收获后产物收入工具箱。订单请到广场邮箱查看，或点击来客头顶气泡。",14))

	if p.unlocked:
		var find_kind=str(state.storage.finds.get(str(selected_plot),""))
		if not find_kind.is_empty() and find_kind!="collected": side.add_child(UI.button("拾取 · "+str(state.layout.config.props[find_kind].name),func(): _action(state.collect_find(selected_plot)),true))
		if p.kind=="doctor_dorm": side.add_child(UI.button("公寓补给 · 泡面 / 可乐",func(): _show_toolbox(); modal._tab("supplies"),true))
		_town_sidebar(p)
		side.add_child(UI.button("建筑升级 · 小镇",_show_campus.bind("build")))
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
	if not state.refinery_notice.is_empty():
		_toast(state.refinery_notice)
		state.refinery_notice=""
	if not covered and not state.industry_notice.is_empty():
		_toast(state.industry_notice); state.industry_notice=""
	_xp_pop()
	if not state.phase_notice.is_empty():
		_announce_phase(state.phase_notice)
		state.phase_notice={}
	if not state.index_notice.is_empty():
		var fx = get_node_or_null("/root/Fx")
		if fx: fx.banner("化学索引新收录", "%s  %s" % [state.index_notice.formula, state.index_notice.name], UI.GOLD)
		state.index_notice={}
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
	_roll_coins(delta)
	feedback.capture(state)

## The coin counter rolls toward the real value instead of jumping.
func _roll_coins(delta: float) -> void:
	if gold_label == null: return
	if shown_coins < 0.0 or absf(state.coins - shown_coins) < 1.0: shown_coins = state.coins
	else: shown_coins = lerpf(shown_coins, state.coins, clampf(delta * 9.0, 0.0, 1.0))
	gold_label.text = "%d" % int(shown_coins)

## Autoloads are looked up by path: scripts preloaded by --script tests compile before autoload globals exist.
func _sfx() -> Node:
	return get_node_or_null("/root/Sfx")

func _ambience(sound: String) -> void:
	if _sfx(): _sfx().ambience(sound)

## Goal track in the quest bar. A finished goal always wins the bar; otherwise the planet
## journey (once joined) keeps its place, and the goal in progress shows with its bar.
func _update_goal() -> void:
	var goal: Dictionary = Milestones.current(state)
	var ready: bool = not goal.is_empty() and Milestones.done(state, goal)
	var was_ready: bool = goal_button.visible
	goal_button.visible = ready
	goal_bar.visible = not goal.is_empty()
	if ready and not was_ready:
		var fx = get_node_or_null("/root/Fx")
		if fx: fx.punch(goal_button, 0.25, 0.4)
	var count := "目标 %d/%d" % [Milestones.claimed_count(state) + (1 if not goal.is_empty() else 0), Milestones.all().size()]
	if ready:
		quest_label.text = "%s · 已完成「%s」 · 领取 %s" % [count, goal.title, Milestones.reward_text(goal)]
		goal_bar.value = 1.0
	elif state.planet.joined:
		var journey=preload("res://scripts/material_journey.gd").next(state)
		quest_label.text="材料路线 %d/6 · %s · 邮箱查看下一步" % [journey.index,journey.title]
		goal_bar.visible = false
	elif goal.is_empty():
		quest_label.text = "所有目标都已完成 · 继续收集结构图鉴，或穿过光桥去河湾探索"
	else:
		quest_label.text = "%s · %s：%s  (%s)" % [count, goal.title, goal.hint, Milestones.progress_text(state, goal)]
		var value := Milestones.stat(state, str(goal.stat))
		goal_bar.value = clampf(value / maxf(float(goal.target), 0.0001), 0.0, 1.0)

func _claim_goal() -> void:
	var goal: Dictionary = Milestones.current(state)
	if goal.is_empty() or not Milestones.done(state, goal): return
	if is_instance_valid(goal_button): pointer_position = goal_button.get_global_rect().get_center()
	_action(Milestones.claim(state))

func _show_goals() -> void:
	var body = _dialog("小岛目标", "按顺序完成目标，领取金币、建材与催化晶。进度随时从小岛实况读取。")
	var current: Dictionary = Milestones.current(state)
	for goal in Milestones.all():
		var claimed: bool = str(goal.id) in state.milestones_claimed
		var is_current: bool = not current.is_empty() and goal.id == current.id
		var row = PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.style(Color("1d3a45") if is_current else Color("152a33"), 12))
		body.add_child(row)
		var h = UI.row(row, 12)
		var mark = "✓" if claimed else ("★" if is_current else "·")
		h.add_child(UI.label(mark, 20, UI.MINT if claimed else (UI.GOLD if is_current else UI.MUTED)))
		var text = UI.column(h, 2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UI.label(str(goal.title), 17, UI.TEXT if claimed or is_current else UI.MUTED))
		text.add_child(UI.paragraph("%s · 奖励 %s" % [goal.hint, Milestones.reward_text(goal)], 13))
		if is_current:
			if Milestones.done(state, goal): h.add_child(UI.button("领取", func(): _close_modal(); _claim_goal(), true))
			else: h.add_child(UI.label(Milestones.progress_text(state, goal), 15, UI.GOLD))

func _show_welcome(away: Dictionary) -> void:
	if is_instance_valid(modal) or away.is_empty(): return
	var minutes := int(float(away.away) / 60.0)
	var span := "%d 小时 %d 分" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d 分钟" % minutes
	var body = _dialog("欢迎回来！", "你离开了 %s。离线时反应炉以半速运转（最多计 2 小时），伙伴不工作也不领薪。" % span, false, 340)
	body.add_child(UI.label("反应炉新产出  %d 份" % int(away.units), 22, UI.MINT))
	body.add_child(UI.label("待收金币  +%d" % int(away.coins), 22, UI.GOLD))
	if bool(away.capped): body.add_child(UI.paragraph("离开超过 2 小时的部分不计入；满仓的反应炉会暂停，记得常回来收获。", 13))
	elif int(away.units) == 0: body.add_child(UI.paragraph("反应炉已满仓，收获后才会继续生产。", 13))
	body.add_child(UI.button("去收获", _close_modal, true))
	var sfx = _sfx()
	if sfx: sfx.play("discovery")

func _toggle_sound() -> void:
	if _sfx() == null: return
	var on: bool = _sfx().toggle()
	sound_button.text = "♪ 开" if on else "♪ 关"
	if on: _sfx().play("ui")
	_toast("声音已开启" if on else "声音已关闭")

func _update_labels() -> void:
	if gold_label == null:
		return
	if shown_coins < 0.0: gold_label.text = "%s" % int(state.coins)
	material_label.text = "星砂 %d   晶露 %d   合金 %d" % state.materials
	var standing: Dictionary = state.industry.rank_of(state.industry.xp)
	rank_label.text = "岛主 Lv.%d  ·  %d / %d XP" % [standing.rank, standing.into, standing.need]
	rank_bar.value = float(standing.into) / maxf(1.0, float(standing.need))
	if live_badge != null and world != null: live_badge.text = "●  LIVE  /  %s" % DayCycle.label(world.day_phase)
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
	_update_goal()
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

func _upgrade_reactor() -> void:
	var before: int = ReactorLook.tier(int(state.reactors[selected_reactor].level))
	var message: String = state.upgrade_reactor(selected_reactor)
	var level: int = int(state.reactors[selected_reactor].level)
	if ReactorLook.tier(level) != before:
		var look: Dictionary = ReactorLook.tier_info(level)
		var fx = get_node_or_null("/root/Fx")
		if fx: fx.banner(look.name, "Lv.%d · %s" % [level,look.blurb], Color(str(look.accent)))
	_action(message)

## A doctor's installation changed what the chamber holds: say so loudly, in words and colour.
func _announce_phase(notice: Dictionary) -> void:
	var names: Dictionary = ReactorLook.PHASE_NAMES
	var before: String = names.get(str(notice.from),"未鉴定")
	var after: String = names.get(str(notice.to),"未鉴定")
	var color: Color = Color(str(ReactorLook.PHASE_COLORS.get(str(notice.to),"f9c868")))
	var fx = get_node_or_null("/root/Fx")
	if fx: fx.banner("物态变化", "%s  %s → %s" % [notice.formula,before,after], color)
	_update_labels()

func _sync_world() -> void:
	world.sync(state.plots,state.reactor_views(),state.templates,state.elements,state.engineers)
	if is_instance_valid(campus_view): campus_view.sync()
	if is_instance_valid(light_bridge): light_bridge.sync(state)
	if is_instance_valid(miniature_view): miniature_view.sync(state)

func _action(message: String) -> void:
	feedback.react(self, message)
	_toast(message)
	_sync_world()
	_rebuild_sidebar()
	_update_goal()
	if not snapshot_mode and not visual_test:
		state.save_game()

func _toast(message: String) -> void:
	toast_label.text = message
	toast_panel.show()
	toast_panel.move_to_front()
	toast_clock = 4.0

## Close the current screen and go back to whatever it covered: a suspended walk or planet, else the island.
func _close_modal() -> void:
	_discard_modal()
	_resume_suspended()

## Leave every screen, suspended ones included, and show the island management view.
func _close_all() -> void:
	_discard_modal()
	for view in return_stack:
		if is_instance_valid(view): view.queue_free()
	return_stack.clear()
	_resume_suspended()

## Make room for a new screen. A walk or planet steps aside instead of being destroyed.
func _replace_modal() -> void:
	if is_instance_valid(modal) and modal.has_method("set_editor_open") and not modal.is_queued_for_deletion() and not return_stack.has(modal):
		modal.set_editor_open(true); return_stack.append(modal); modal=null
	_discard_modal()

func _discard_modal() -> void:
	building_drag.cancel()
	research_open = false
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null
	market_rows.clear()
	shop_buttons.clear()

func _top_suspended() -> Control:
	while not return_stack.is_empty() and (not is_instance_valid(return_stack.back()) or return_stack.back().is_queued_for_deletion()): return_stack.pop_back()
	return null if return_stack.is_empty() else return_stack.back()

func _resume_suspended() -> void:
	var view: Control=_top_suspended()
	if view==null:
		if not snapshot_mode: _ambience("amb_island")
		if is_instance_valid(world_viewport): world_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		_coach("island")
		return
	return_stack.pop_back(); modal=view
	view.set_editor_open(false)
	if not snapshot_mode: _ambience("amb_river" if view is PlanetV2Panel else "amb_island")

## A full-screen panel closed itself: return to the screen underneath.
func _screen_closed(panel: Control) -> void:
	if modal!=panel: return
	modal=null
	_resume_suspended()

## Label for a close button that returns to a suspended screen ("" = the island).
func _return_label() -> String:
	var view: Control=_top_suspended()
	if view==null: return ""
	if view.has_method("return_title"): return "返回"+view.return_title()
	return "返回河湾" if view is PlanetV2Panel else "返回漫步"

func _label_return(panel: Control) -> void:
	var text=_return_label()
	if not text.is_empty() and panel.has_method("set_return_label"): panel.set_return_label(text)

## Bring a suspended screen of this script back to the front, closing what is above it.
func _resume_existing(script: Script) -> bool:
	var index=-1
	for i in range(return_stack.size()):
		if is_instance_valid(return_stack[i]) and return_stack[i].get_script()==script: index=i
	if index<0: return false
	_discard_modal()
	while return_stack.size()>index+1:
		var above=return_stack.pop_back()
		if is_instance_valid(above): above.queue_free()
	_resume_suspended()
	return true

func _dialog(title: String, subtitle: String, wide: bool = false, height: int = 668) -> VBoxContainer:
	town_build.cancel()
	_replace_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var dim = ColorRect.new()
	dim.color = Color(0.015,0.03,0.05,0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var w = 930 if wide else 600
	var panel = UI.box(modal,Rect2((1440-w)/2,106 if height>=668 else (900-height)/2,w,height))
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
	var body = _dialog("选择初始结构", "新炉需要100金币和结构里的全部元素，由博士装炉；键长与角度需要自己调节。更换配方预付25金币和新增的元素，等待博士装炉；旧批次保留。")
	var gate: Dictionary = state.install_status()
	if not gate.ok:
		var banner = UI.paragraph("⚠ " + str(gate.message) + "。没有博士时不能建新炉、换配方或替换元素，只能在原子工作台微调坐标。",15,UI.GOLD)
		banner.name = "DoctorBanner"
		body.add_child(banner)
	_custom_reactor_cards(body,build)
	body.add_child(UI.label("预设结构",19,UI.MINT))
	for key in state.templates:
		if state.templates[key].get("substitution_only",false) and key not in state.campus.unlocked_materials: continue
		var tpl: Dictionary = state.templates[key]
		var quote: Dictionary = state.reactor_quote(selected_plot,key) if build else state.template_quote(selected_reactor,key)
		var panel = PanelContainer.new()
		body.add_child(panel)
		var v = UI.column(panel,6)
		v.add_child(UI.label("%s   %s" % [tpl.formula,tpl.name],20,Color(tpl.color)))
		var profile: Dictionary = state.economy.profile(tpl)
		v.add_child(UI.paragraph("%s章节  ·  %d个可编辑原子\n复杂度 %.2f  ·  满匹配Lv.1产出 %.2f金币/秒" % [tpl.chapter,tpl.atoms.size(),profile.complexity,profile.base_rate],13))
		var needs: Array = []
		for symbol in quote.required: needs.append("%s×%d（有%d）" % [symbol,int(quote.required[symbol]),int(state.element_inventory.get(symbol,0))])
		v.add_child(UI.paragraph("需要元素：" + ("、".join(needs) if not needs.is_empty() else "无新增"),13,UI.MINT if quote.ready else UI.MUTED))
		var choose = UI.button("建造此反应炉  ·  100金币" if build else "装载初始结构  ·  25金币",_choose_template.bind(key,build))
		choose.disabled = not quote.ready
		v.add_child(choose)
		if not quote.ready and quote.message != str(gate.message): v.add_child(UI.paragraph(str(quote.message),12,Color("ffb4a8")))

## v0.41.1: a blank reactor to build from scratch, and 我的炉型 next to the presets.
func _custom_reactor_cards(body: VBoxContainer, build: bool) -> void:
	if build:
		var blank=PanelContainer.new(); body.add_child(blank); var b=UI.column(blank,6)
		b.add_child(UI.label("空白反应炉 · 自己搭",20,UI.GOLD))
		b.add_child(UI.paragraph("打开结构工坊，从零放原子、连键；搭成化学索引里的真实分子就能按参考几何调键长、看匹配度和收益。建好后自动存进「我的炉型」。",13))
		b.add_child(UI.button("开始搭建（100金币 + 用到的元素）",func(): _open_sandbox_editor(state.new_sandbox_structure("我的反应炉"),selected_plot),true))
	if state.player_templates.is_empty():
		body.add_child(UI.paragraph("我的炉型：在结构工坊点「存为我的炉型」，自己的设计就会出现在这里，和预设一样一键建造。",13,UI.MUTED))
		return
	body.add_child(UI.label("我的炉型  ·  %d 个" % state.player_templates.size(),19,UI.LILAC))
	for t in state.player_templates:
		var work: Dictionary=t.work
		var probe: Dictionary=state.design_probe(work)
		var info: Dictionary=state.structure_data(probe)
		var tuned=bool(info.get("known",false)) or info.has("geometry_ref")
		var panel=PanelContainer.new(); body.add_child(panel); var v=UI.column(panel,6)
		v.add_child(UI.label("%s   %s" % [state.sandbox_formula(work),t.name],19,UI.LILAC))
		v.add_child(UI.paragraph("%d个原子 · %s" % [work.atoms.size(),("几何匹配 %d%% · 现在约 %.2f 金币/秒 · 参考：%s" % [roundi(state.quality(probe)*100),state.income(probe),str(info.get("reference_name",info.get("name","")))]) if tuned else "探索作品（无参考几何）· %.2f 金币/秒" % state.income(probe)],13))
		var row=UI.row(v,8)
		if build:
			var quote: Dictionary=state.custom_reactor_quote(selected_plot,work)
			var needs: Array=[]
			for symbol in quote.required: needs.append("%s×%d（有%d）" % [symbol,int(quote.required[symbol]),int(state.element_inventory.get(symbol,0))])
			v.add_child(UI.paragraph("需要元素："+"、".join(needs),13,UI.MINT if quote.ready else UI.MUTED))
			var go=UI.button("建造此反应炉  ·  100金币",func(): var m=state.place_custom_reactor(selected_plot,work); _close_modal(); _select_plot(selected_plot); _action(m))
			go.disabled=not quote.ready; row.add_child(go)
			row.add_child(UI.button("先调一调再建",func(): _open_sandbox_editor(work.duplicate(true),selected_plot)))
			if not quote.ready and quote.message!=str(state.install_status().message): v.add_child(UI.paragraph(str(quote.message),12,Color("ffb4a8")))
		else:
			row.add_child(UI.button("装载到这座炉（在工坊里确认）",func(): _open_sandbox_editor(work.duplicate(true))))
		row.add_child(UI.button("删除",func(): _action(state.remove_player_template(str(t.id))); _show_templates(build)))

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
	if not tpl.known and tpl.has("geometry_ref"):
		body.add_child(UI.paragraph("这是化学索引里的真实分子：按 PubChem 三维坐标作参考几何，和预设一样按复杂度、几何匹配和等级计算，再乘 %.2f。" % float(state.economy.rules.get("index_geometry_factor",0.8)),17,UI.MINT))
		body.add_child(UI.label("几何匹配  %d%%" % roundi(state.quality(r)*100),22,UI.MINT))
		body.add_child(UI.paragraph("%.2f 基础速率 × %.3f 几何反馈 × %.2f 等级加成 × %.2f" % [b.base_rate,b.geometry_factor,b.level_factor,float(state.economy.rules.get("index_geometry_factor",0.8))],16,UI.TEXT))
		return
	if not tpl.known:
		body.add_child(UI.label("探索津贴 · 每秒%.2f金币" % b.rate,23,UI.MINT))
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
			var line=UI.row(body,8)
			line.add_child(UI.button("☆ %s  ·  %s  ·  打开作品" % [work.name,work.formula],_open_sandbox_editor.bind(work)))
			line.add_child(UI.button("存为我的炉型",func(): _action(state.save_player_template(work))))
	body.add_child(UI.paragraph("工作台支持增删原子、增加/移除连接、命名保存；晶胞和周期边界将在后续结构章节加入。",13,UI.MUTED))
	_coach("sandbox")

func _open_sandbox_editor(structure: Dictionary, build_plot: int=-1) -> void:
	var editor = SandboxEditor.new()
	_begin_structure_editor(editor)
	editor.setup(state,structure,selected_reactor if build_plot<0 else -1,build_plot)
	_label_return(editor)
	editor.saved.connect(func(): _toast("作品已保存，可以继续编辑或装入炉子"))
	editor.applied.connect(func():
		if editor.build_plot>=0: _select_plot(editor.build_plot); _action("新反应炉开始建造，已存进「我的炉型」"); return
		_action("已提交博士装炉；旧炉继续生产，完成后切换新分子" if not state.reactors[editor.reactor_index].get("installation",{}).is_empty() else "坐标已保存，反应釜继续生产"))
	editor.synthesis_requested.connect(func(): _show_organic_synthesis(editor.reactor_index))
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
	_replace_modal()
	var panel=IslandPanel.new(); add_child(panel); modal=panel
	panel.setup(state,selected_plot,page,visitor)
	_label_return(panel)
	panel.acted.connect(_action)
	panel.dismissed.connect(_screen_closed.bind(panel))
	panel.arrange.connect(func(kind): _show_campus("build"); modal.prop_choice=kind; modal._show("build"))
	panel.factory_requested.connect(_show_factory)
	panel.planet_v2_requested.connect(_show_planet_v2)
	panel.material_navigation.connect(_navigate_materials)

func _navigate_materials(route: String) -> void:
	match route:
		"elements", "refinery": _show_refinery()
		"fabricator": _show_fabricator()
		"sandbox": _show_sandbox()
		"research": _show_campus("research")
		"mail": _show_market()
		"island": _close_all()
		"materials": _show_factory(); modal.dossier_family=true; modal._open_dossiers()
		"workshop":
			_show_factory()
			for id in state.planet.materials.designs:
				if state.planet.materials.designs[id].basis=="family_model": modal._choose_recipe(id); return
			modal.dossier_family=true; modal._open_dossiers()
		_: _show_factory()

func _show_factory(recipe_id: String="") -> void:
	_replace_modal()
	if not recipe_id.is_empty(): last_factory_recipe=recipe_id
	var panel=FactoryPanel.new(); add_child(panel); modal=panel
	panel.setup(state)
	_label_return(panel)
	panel._choose_recipe(last_factory_recipe)
	panel.acted.connect(_action)
	panel.mail_requested.connect(_show_market)
	panel.planet_requested.connect(func(): last_factory_recipe=panel.selected_recipe; _show_planet_v2())
	panel.synthesis_requested.connect(func(): _show_organic_synthesis())
	panel.campus_requested.connect(func(tab):
		last_factory_recipe=panel.selected_recipe
		if tab=="build":
			for i in range(state.plots.size()):
				if state.plots[i].kind=="workshop": _select_plot(i); _show_campus("build"); return
			_show_build_menu()
		else: _show_campus(tab))
	panel.dismissed.connect(func():
		last_factory_recipe=panel.selected_recipe
		_screen_closed(panel)
		if not snapshot_mode and not visual_test: state.save_game())

func _show_planet_v2() -> void:
	# The planet you left for the workshop or reactor is still there, with your position and view.
	if _resume_existing(PlanetV2Panel): return
	_replace_modal()
	var panel=PlanetV2Panel.new(); add_child(panel); modal=panel
	panel.setup(state)
	panel.acted.connect(_action)
	panel.workshop_requested.connect(_show_factory)
	panel.synthesis_requested.connect(func(): _show_organic_synthesis())
	panel.test_requested.connect(func(): _show_test_panel(panel))
	panel.voyage_requested.connect(_show_voyage)
	_ambience("amb_river")
	panel.dismissed.connect(func():
		_screen_closed(panel)
		if not snapshot_mode and not visual_test: state.save_game())

func _show_organic_synthesis(index: int=-1) -> void:
	var panel=preload("res://scripts/organic_reactor_panel.gd").new()
	_begin_structure_editor(panel)
	panel.setup(state,index)
	_label_return(panel)
	panel.acted.connect(_action)
	panel.dismissed.connect(func(): _finish_structure_editor(panel))
	panel.campus_requested.connect(_show_campus)
	panel.planet_requested.connect(_show_planet_v2)
	panel.refinery_requested.connect(_show_refinery)
	panel.edit_requested.connect(func(i): _select_plot(int(state.reactors[i].plot)); _open_editor())
	_coach("organic")

func _deliver_market(index: int) -> void:
	_action(state.deliver(index))
	_show_market()

## v0.28: elements are refined from planet minerals or extracted on the island (no coin shop).
func _show_refinery(symbol: String="") -> void:
	_replace_modal()
	var panel=RefineryPanel.new(); add_child(panel); modal=panel
	panel.setup(state,symbol)
	_label_return(panel)
	panel.acted.connect(_action)
	panel.dismissed.connect(_screen_closed.bind(panel))
	panel.planet_requested.connect(_show_planet_v2)
	_coach("refinery")

## v0.34: the second island. Locked saves see the unlock card; open saves see the factories.
func _show_starforge() -> void:
	_replace_modal()
	var panel=StarforgePanel.new(); add_child(panel); modal=panel
	panel.setup(state)
	_label_return(panel)
	panel.acted.connect(_action)
	panel.dismissed.connect(_screen_closed.bind(panel))
	panel.walk_requested.connect(_show_starforge_walk)

## v0.43: walk 星锻岛 in first person. E on a factory opens its management (the walk waits on the
## return stack); leaving the walk goes back to the management screen.
func _show_starforge_walk() -> void:
	if not state.industry.unlocked: return
	if _resume_existing(StarforgeWalk): return
	_replace_modal()
	var panel=StarforgeWalk.new(); add_child(panel); modal=panel; panel.setup(state)
	panel.dismissed.connect(func():
		_screen_closed(panel)
		if modal==null: _show_starforge())
	panel.requested.connect(func(kind: String,index: int):
		if kind=="manage": _show_starforge(); modal.focus_plot(index))

## "+N XP" rises from the rank bar, and a banner marks each new 岛主 rank.
func _xp_pop() -> void:
	var ind=state.industry
	if ind.pending_xp<=0 or rank_bar==null: return
	var before: int=ind.rank_of(ind.xp-ind.pending_xp).rank
	var fx = get_node_or_null("/root/Fx")
	if fx:
		fx.pop_text(rank_bar.global_position+Vector2(rank_bar.size.x*0.5,0),"+%d XP" % ind.pending_xp,UI.LILAC)
		if ind.rank()>before: fx.banner("岛主升级！","岛主等级 Lv.%d" % ind.rank(),UI.LILAC)
	ind.pending_xp=0
	_update_labels()

## v0.30: stored crystals → pick heads (hardness) and solar panels (band gap) with real properties.
func _show_fabricator() -> void:
	_replace_modal()
	var panel=FabricatorPanel.new(); add_child(panel); modal=panel
	panel.setup(state)
	_label_return(panel)
	panel.acted.connect(_action)
	panel.dismissed.connect(_screen_closed.bind(panel))
	panel.refinery_requested.connect(_show_refinery)
	_coach("fabricator")

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
	_replace_modal()
	var panel=CampusPanel.new()
	modal=panel
	add_child(panel)
	panel.setup(state,selected_plot)
	_label_return(panel)
	panel.changed.connect(_action)
	panel.factory_requested.connect(_show_factory)
	panel.dismissed.connect(_screen_closed.bind(panel))
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
	var total := Codex.total_stars(state)
	var body = _dialog("结构图鉴", "已发现 %d / %d   ·   图鉴星 %d / %d   ·   收获时记录每种结构的最佳几何匹配" % [state.discovered.size(), state.templates.size(), total, Codex.max_stars(state)], true)
	var next: Dictionary = Codex.next_reward(state)
	var goal = PanelContainer.new()
	goal.add_theme_stylebox_override("panel", UI.style(Color("1d3a45"), 12))
	body.add_child(goal)
	var g = UI.column(goal, 6)
	if next.is_empty():
		g.add_child(UI.label("图鉴奖励已全部领取 · 感谢你认真调好每一个结构", 16, UI.MINT))
	else:
		g.add_child(UI.label("下一份图鉴奖励：%s   ·   %d / %d ★" % [Codex.reward_text(state, next), total, int(next.stars)], 16, UI.GOLD))
		var bar = ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = float(next.stars)
		bar.value = float(total)
		var fill = StyleBoxFlat.new(); fill.bg_color = UI.GOLD; fill.set_corner_radius_all(3)
		var track = StyleBoxFlat.new(); track.bg_color = Color("0f1e26"); track.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill); bar.add_theme_stylebox_override("background", track)
		g.add_child(bar)
		g.add_child(UI.paragraph("奖励的摆件直接放进工具箱，可在「装饰」里免费布置。每种结构最多 ★★★（几何匹配 98%）。", 12))
	body.add_child(UI.button("化学索引 · 真实数据库   已收录 %d / %d   →" % [state.index_found.size(), ChemIndex.size()], _show_index, true))
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for key in state.templates:
		grid.add_child(_codex_card(str(key)))

func _codex_card(key: String) -> Control:
	var tpl: Dictionary = state.templates[key]
	var tier: Dictionary = Codex.rarity(tpl)
	var tint := Color(str(tier.color))
	var unlocked: bool = state.discovered.has(key)
	var card = Button.new()
	card.custom_minimum_size = Vector2(206, 150)
	card.focus_mode = Control.FOCUS_NONE
	# Like UI.button: let a finger swipe that starts on a card scroll the codex.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var face := UI.style(Color("1b2f3a") if unlocked else Color("121f27"), 14, tint if unlocked else Color(tint, 0.25))
	face.set_border_width_all(2 if unlocked else 1)
	var hover := face.duplicate(); hover.bg_color = face.bg_color.lightened(0.08)
	card.add_theme_stylebox_override("normal", face)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.pressed.connect(_show_codex_entry.bind(key))
	var v = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14; v.offset_right = -14; v.offset_top = 10; v.offset_bottom = -10
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var stars := Codex.best_stars(state, key)
	for line in [
		["%s · %d 原子" % [tier.name, tpl.atoms.size()], 12, tint if unlocked else UI.MUTED],
		[str(tpl.formula) if unlocked else "？？？", 26, Color(tpl.color) if unlocked else Color(UI.MUTED, 0.55)],
		[str(tpl.name) if unlocked else ("元素替换可得" if tpl.get("substitution_only", false) else "建造并收获即可解锁"), 13, UI.TEXT if unlocked else UI.MUTED],
		[Codex.stars_text(stars) if unlocked else "", 18, UI.GOLD],
		["最佳 %d%%" % roundi(float(state.best_fit.get(key, 0.0)) * 100.0) if unlocked else "", 11, UI.MUTED]]:
		if str(line[0]).is_empty(): continue
		var l = UI.label(line[0], line[1], line[2])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true
		v.add_child(l)
	return card

func _show_codex_entry(key: String) -> void:
	var tpl: Dictionary = state.templates[key]
	var tier: Dictionary = Codex.rarity(tpl)
	var unlocked: bool = state.discovered.has(key)
	var body = _dialog("%s   %s" % [tpl.formula, tpl.name] if unlocked else "未发现的结构", "%s · %d 个原子 · %s章节" % [tier.name, tpl.atoms.size(), tpl.chapter], false, 500)
	if unlocked:
		var best := float(state.best_fit.get(key, 0.0))
		body.add_child(UI.label("图鉴最佳  %s   几何匹配 %d%%" % [Codex.stars_text(Codex.stars(best)), roundi(best * 100.0)], 18, UI.GOLD))
		if Codex.stars(best) < 3: body.add_child(UI.paragraph("把这个结构调到 %d%% 以上再收获一批，即可点亮下一颗星。" % roundi([Codex.GOOD_FIT, Codex.PREMIUM_FIT, Codex.PERFECT_FIT][Codex.stars(best)] * 100.0), 14))
		body.add_child(UI.paragraph(tpl.description, 16, UI.TEXT))
		body.add_child(UI.paragraph("参考来源：" + tpl.source, 11))
		for r in state.reactors:
			if state.reference_id(r) == key:
				body.add_child(UI.label("我的样品   %s  ·  %s  ·  当前 %d%%" % [r.id, state.signature(r), roundi(state.quality(r) * 100.0)], 13, UI.MINT))
		var found: Dictionary = state.structure_data({"template":key,"atoms":tpl.atoms}).get("index",{})
		if ChemIndex.is_find(found): body.add_child(UI.button("化学索引：%s   查看真实数据  →" % ChemIndex.formula(found.entry), _show_index_entry.bind(str(found.key))))
	else:
		body.add_child(UI.paragraph("通过元素替换得到此组成，再收获第一份产物，即可解锁。" if tpl.get("substitution_only", false) else "建造或换装这个结构，并收获第一份产物，即可解锁科普卡。", 16, UI.TEXT))
	body.add_child(UI.button("返回图鉴", _show_collection, true))

## v0.29 chemistry index browser: PubChem molecules and Materials Project crystals, bundled offline.
func _show_index() -> void:
	var body = _dialog("化学索引", "真实数据库  ·  分子 %d / %d（PubChem）  ·  晶体 %d / %d（Materials Project）  ·  做出来并收获一次即收录" % [ChemIndex.found_count(state,"molecule"), ChemIndex.molecules().size(), ChemIndex.found_count(state,"crystal"), ChemIndex.crystals().size()], true)
	index_tabs = UI.row(body, 8)
	index_chips = HFlowContainer.new()
	index_chips.add_theme_constant_override("h_separation", 6)
	index_chips.add_theme_constant_override("v_separation", 6)
	body.add_child(index_chips)
	index_count = UI.label("", 14, UI.MUTED)
	body.add_child(index_count)
	index_grid = GridContainer.new()
	index_grid.columns = 4
	index_grid.add_theme_constant_override("h_separation", 10)
	index_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(index_grid)
	index_pager = UI.row(body, 10)
	_refresh_index()
	_coach("index")

## Tabs, filters and pages refill the same dialog, so a running tour keeps its targets.
func _refresh_index() -> void:
	if not is_instance_valid(index_grid): return
	for box in [index_tabs, index_chips, index_grid, index_pager]:
		for child in box.get_children():
			box.remove_child(child); child.queue_free()
	for tab in [["molecule","分子  %d" % ChemIndex.molecules().size()], ["crystal","晶体  %d" % ChemIndex.crystals().size()]]:
		index_tabs.add_child(UI.button(tab[1], func(): index_kind = tab[0]; index_page = 0; _refresh_index(), index_kind == tab[0]))
	index_tabs.add_child(UI.button("✓ 只看已收录" if index_found_only else "只看已收录", func(): index_found_only = not index_found_only; index_page = 0; _refresh_index(), index_found_only))
	var gap = Control.new(); gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; index_tabs.add_child(gap)
	index_credits_button = UI.button("数据来源与致谢", _show_index_credits)
	index_tabs.add_child(index_credits_button)
	index_tabs.add_child(UI.button("返回图鉴", _show_collection))
	for symbol in state.elements.keys():
		var chip = UI.button(str(symbol), _toggle_index_element.bind(str(symbol)), str(symbol) in index_filter)
		chip.custom_minimum_size = Vector2(56, 40)
		index_chips.add_child(chip)
	if not index_filter.is_empty(): index_chips.add_child(UI.button("清除筛选", func(): index_filter.clear(); index_page = 0; _refresh_index()))
	var list: Array = ChemIndex.filtered(index_kind, index_filter, index_found_only, state)
	var pages := maxi(1, ceili(float(list.size()) / INDEX_PAGE))
	index_page = clampi(index_page, 0, pages - 1)
	index_count.text = "共 %d 条%s  ·  第 %d / %d 页" % [list.size(), "（含 %s）" % "、".join(index_filter) if not index_filter.is_empty() else "", index_page + 1, pages]
	if list.is_empty():
		index_count.text += "  ·  " + ("还没有收录这一类。做出一个真实存在的物质，收获一次就会出现在这里。" if index_found_only else "没有同时含这些元素的条目，少选一个元素试试。")
	for i in range(index_page * INDEX_PAGE, mini(list.size(), (index_page + 1) * INDEX_PAGE)):
		var e: Dictionary = list[i]
		index_grid.add_child(ChemIndexView.card(e, state.index_found.has(str(e.key)), _show_index_entry.bind(str(e.key))))
	var prev = UI.button("上一页", func(): index_page -= 1; _refresh_index())
	prev.disabled = index_page <= 0
	index_pager.add_child(prev)
	var next = UI.button("下一页", func(): index_page += 1; _refresh_index())
	next.disabled = index_page >= pages - 1
	index_pager.add_child(next)

func _toggle_index_element(symbol: String) -> void:
	if symbol in index_filter: index_filter.erase(symbol)
	else: index_filter.append(symbol)
	index_page = 0
	_refresh_index()

func _show_index_entry(key: String) -> void:
	var e: Dictionary = ChemIndex.entry_by_key(key)
	if e.is_empty(): return
	var molecule: bool = e.has("cid")
	var found: bool = state.index_found.has(key)
	var body = _dialog("%s   %s" % [ChemIndex.formula(e), str(e.name) if molecule else str(e.spacegroup)], ("%s · PubChem CID %d" % [str(e.group), int(e.cid)]) if molecule else ("%s晶系 · %s · %s" % [ChemIndex.CRYSTAL_SYSTEMS.get(str(e.crystal_system), ""), str(e.id), ChemIndex.stability(e).name]), true)
	var top = UI.row(body, 16)
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.style(Color("0f1e26"), 14, UI.LINE))
	top.add_child(frame)
	frame.add_child(ChemIndexView.preview(e, state.elements))
	var facts = UI.column(top, 4)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_child(UI.label("✓ 你已经做出过它" if found else "尚未收录 · 做出来并收获一次", 16, UI.GOLD if found else UI.MUTED))
	for row in ChemIndex.properties(e):
		var line = UI.row(facts, 8)
		var name_label = UI.label(str(row[0]), 14, UI.MUTED)
		name_label.custom_minimum_size = Vector2(118, 0)
		line.add_child(name_label)
		var value = UI.label(str(row[1]), 14, UI.TEXT)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(value)
	if molecule and not str(e.get("name_en", "")).is_empty(): facts.add_child(UI.paragraph(str(e.name_en), 12))
	body.add_child(UI.paragraph(ChemIndex.how_to_build(e), 15, UI.TEXT))
	if not molecule: body.add_child(UI.paragraph("图中金色线是晶胞边界，球的大小只是示意。性质来自密度泛函理论（DFT）计算，与实验值可能有偏差。", 12))
	body.add_child(UI.paragraph(ChemIndex.source_line(e), 12, UI.MINT))
	var buttons = UI.row(body, 10)
	buttons.add_child(UI.button("返回化学索引", _show_index, true))
	buttons.add_child(UI.button("数据来源与致谢", _show_index_credits))

func _show_index_credits() -> void:
	var body = _dialog("数据来源与致谢", "化学索引在开发时离线整理并随游戏打包：游戏里没有密钥，也不联网。没有来源的数值一律写「未测」，不会编造。", true)
	for s in ChemIndex.sources():
		body.add_child(UI.label(str(s.name_zh), 20, UI.GOLD))
		body.add_child(UI.paragraph("%s  ·  许可：%s" % [str(s.url), str(s.licence)], 14, UI.TEXT))
		body.add_child(UI.paragraph(str(s.scope_zh), 14))
		body.add_child(UI.paragraph(str(s.changes_zh), 13))
		body.add_child(UI.paragraph("引用：" + str(s.citation), 12, UI.MINT))
	body.add_child(UI.paragraph("Materials Project 数据库版本 %s。物态、熔点和沸点仍来自各条目标注的文献（见反应釜侧栏）。" % ChemIndex.db_version(), 13))
	body.add_child(UI.button("返回化学索引", _show_index, true))

## Shows a screen's first-time tour once the screen has laid itself out.
func _coach(id: String) -> void:
	if coach_autostart and is_instance_valid(coach) and not state.coach_seen.has(id): _start_coach.call_deferred(id)

func _start_coach(id: String) -> void:
	await get_tree().process_frame
	if state.coach_seen.has(id): return
	coach.stop_if_stale()
	if coach.active(): return
	var owner: Control = modal
	# A weak reference: the tour may outlive its screen for a frame, and a freed capture logs an error.
	var screen: WeakRef = weakref(owner)
	var alive: Callable = (func(): return modal == null) if id == "island" else (func(): var o = screen.get_ref(); return o != null and modal == o and o.is_visible_in_tree())
	if not alive.call(): return
	coach.start(id, CoachTours.steps(self, id), alive)

func _coach_finished(id: String, skipped: bool) -> void:
	state.coach_seen[id] = true
	if skipped: _toast("已跳过指引。「怎么玩？」里可以重新播放。")
	if not snapshot_mode and not visual_test: state.save_game()

func _replay_coach() -> void:
	state.coach_seen.clear()
	_close_all()
	coach_autostart = true
	_coach("island")

func _show_help() -> void:
	var body = _dialog("欢迎来到原子工坊", "一座可以经营、收集和自由摆放的科学小岛。")
	for entry in [
		["01  调整原子", "选择反应炉 → 原子工作台。拖动彩球，观察产率；确认修改时按炉等级扣费。旧批次保留；换元素需要博士装炉。"],
		["02  收获与扩张", "点击注入微光赚金币。炉子持续产生待收金币和产物；收获时概率获得星砂、晶露、合金片。点击虚线地块开拓。"],
		["03  带伙伴来", "先造住宅，再招募伙伴。工程师到岗后才施工；科研小镇可以查看性格、日薪和生活心愿。"],
		["04  接一张订单", "每次到访可交付一次，之后等待20秒。库存达到3份即可交付。种类相符且几何响应与目标相差≤5个百分点，获得精品催化晶，用来升级炉子。"],
		["05  元素从哪里来", "海水、空气和水在精炼厂自动产出 H、C、N、O、Na、Cl、Br；铜、铝、铅、铁、锡、硫、氟、锂、铯要去星球地下采矿，再到精炼厂提炼。工作台选择位点 → 预览替换，应用时扣库存与一次编辑费。"],
		["06  解锁新知识", "先造科研院所和博士公寓，再招募博士生开展基础课题。院士增加进阶课题名额，教授可选带队提效；研究站保留势函数和一维DFT教学任务。"],
		["07  化学索引", "图鉴里的「化学索引」收了一千多种真实物质：分子来自 PubChem，晶体来自 Materials Project。做出其中任何一种并收获一次，就会收录并得到金币；没收录的结构保持「假说」，不编造性质。"],
		["08  制造台", "化学索引认得的晶体可以在制造台做成装备：硬度高的做镐头，深层硬岩挖得更快；有合适带隙的做太阳能板，装到精炼厂屋顶加快精炼。数值都来自真实性质。"]
	]:
		body.add_child(UI.label(entry[0],20,UI.GOLD))
		body.add_child(UI.paragraph(entry[1],16))
	body.add_child(UI.button("重新播放新手指引",_replay_coach))
	body.add_child(UI.button("数据来源与致谢",_show_index_credits))
	body.add_child(UI.button("开始我的小岛",_close_modal,true))

## v0.33.1 测试版 panel. From the planet, `planet` is that panel, so teleports can use its view.
func _show_test_panel(planet: Control = null) -> void:
	var from_planet: bool = planet != null and is_instance_valid(planet)
	var body = _overlay_dialog("测试面板", "测试版专用 · 存档写入 %s，不影响正式存档" % TestMode.SAVE_NAME) if from_planet else _dialog("测试面板", "测试版专用 · 存档写入 %s，不影响正式存档" % TestMode.SAVE_NAME, true)
	var run = func(message: String) -> void:
		if from_planet: planet.acted.emit(message); planet._sync()
		else: _action(message)
	body.add_child(UI.label("资源", 20, UI.GOLD))
	var row = UI.row(body, 8)
	row.add_child(UI.button("金币 +10万", func(): run.call(TestMode.grant_coins(state, 100000))))
	row.add_child(UI.button("建材各 +500", func(): run.call(TestMode.grant_materials(state, 500))))
	row.add_child(UI.button("元素各 +500", func(): run.call(TestMode.grant_elements(state, 500))))
	row.add_child(UI.button("矿物各 +50", func(): run.call(TestMode.grant_minerals(state, 50))))
	row.add_child(UI.button("星球原料 +50", func(): run.call(TestMode.grant_planet_stock(state, 50))))
	body.add_child(UI.label("浮岛", 20, UI.GOLD))
	row = UI.row(body, 8)
	row.add_child(UI.button("开拓 +9 块地", func(): run.call(TestMode.unlock_plots(state, 9))))
	row.add_child(UI.button("精炼厂满级", func(): run.call(TestMode.max_refinery(state))))
	row.add_child(UI.button("招募博士", func(): run.call(state.campus_hire("doctor"))))
	row.add_child(UI.button("招募工程师", func(): run.call(state.campus_hire("engineer"))))
	row.add_child(UI.button("开放星锻岛 +300信用", func(): run.call(TestMode.open_starforge(state, 300))))
	row.add_child(UI.button("时间之门：切换冰河期/当代", func(): run.call(TestMode.toggle_epoch(state))))
	row.add_child(UI.button("员工满年限", func(): run.call(TestMode.finish_service(state))))
	row = UI.row(body, 8)
	row.add_child(UI.button("浮岛快进 1 小时", func(): run.call(TestMode.skip_island(state, 3600))))
	row.add_child(UI.button("浮岛快进 8 小时", func(): run.call(TestMode.skip_island(state, 8 * 3600))))
	row.add_child(UI.button("硅钙磷原料包", func(): run.call(TestMode.silicon_kit(state))))
	row.add_child(UI.button("盾构机（派往地球）", func(): run.call(TestMode.give_tbm(state))))
	row.add_child(UI.button("小飞机（派往地球）", func(): run.call(TestMode.give_plane(state))))
	row.add_child(UI.button("星际飞船", func(): run.call(TestMode.give_ship(state))))
	row.add_child(UI.button("芯片原料包", func(): run.call(TestMode.chip_kit(state))))
	row.add_child(UI.button("电池原料包", func(): run.call(TestMode.battery_kit(state))))
	row.add_child(UI.button("越野车", func(): run.call(TestMode.rover_kit(state))))
	body.add_child(UI.label("地球", 20, UI.GOLD))
	row = UI.row(body, 8)
	row.add_child(UI.button("快进 1 天", func(): run.call(TestMode.skip_planet(state, 60))))
	row.add_child(UI.button("快进 1 季", func(): run.call(TestMode.skip_planet(state, 240))))
	row.add_child(UI.button("推进时代", func(): run.call(TestMode.force_era(state))))
	for kind in [["storm","暴风雨"],["flood","洪水"],["drought","干旱"]]:
		row.add_child(UI.button("10秒后%s" % kind[1], func(): run.call("测试："+state.planet.v2.incidents.warn(state.planet.v2,kind[0],10.0))))
	if from_planet:
		body.add_child(UI.label("传送（进入第一人称）", 16, UI.MUTED))
		row = UI.row(body, 8)
		var close = func(): body.get_meta("overlay").queue_free()
		row.add_child(UI.button("营地", func(): close.call(); planet.test_teleport(Vector2(14, 16), "营地")))
		var env = state.planet.v2.environment
		for biome in TestMode.BIOMES:
			var spot: Vector2 = TestMode.biome_spot(env, biome)
			if spot == Vector2.INF: continue
			var label: String = env.biome_name(biome)
			row.add_child(UI.button(label, func(): close.call(); planet.test_teleport(spot, label)))
		body.add_child(UI.button("关闭", close, true))
	else:
		body.add_child(UI.paragraph("在地球界面右上角也有「测试」按钮，可以快进时间、传送到各个群系。", 14))
		body.add_child(UI.button("关闭", _close_modal, true))

## A dialog drawn over the current modal instead of replacing it (the planet stays open underneath).
func _overlay_dialog(title: String, subtitle: String) -> VBoxContainer:
	var shade = ColorRect.new(); shade.color = Color(0, 0, 0, 0.55); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(shade)
	var box = UI.box(shade, Rect2(240, 120, 960, 640))
	var body = UI.column(box, 10)
	body.add_child(UI.label(title, 26, UI.GOLD)); body.add_child(UI.paragraph(subtitle, 14))
	body.set_meta("overlay", shade)
	return body

func _open_editor() -> void:
	if selected_reactor < 0:
		return
	if state.reactors[selected_reactor].get("sandbox",false):
		_open_sandbox_editor(state.reactor_work(state.reactors[selected_reactor]))
		return
	var editor = Editor.new()
	_begin_structure_editor(editor)
	editor.setup(state,selected_reactor)
	_label_return(editor)
	editor.applied.connect(func(): _finish_structure_editor(editor); _action("修改已提交；更换元素等待博士装炉，已有产物会保留。"))
	editor.dismissed.connect(func(): _finish_structure_editor(editor))
	editor.synthesis_requested.connect(func(): _show_organic_synthesis(editor.reactor_index))
	_coach("editor")

func _begin_structure_editor(editor: Control) -> void:
	# A walk or planet caller steps aside and comes back with its camera and position.
	_replace_modal()
	add_child(editor); modal=editor

func _finish_structure_editor(editor: Control,return_to_library: bool=false) -> void:
	if modal!=editor: return
	editor.queue_free(); modal=null
	if _top_suspended()==null and return_to_library: _show_sandbox()
	else: _resume_suspended()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		world_pointer_down = false
		world_touch_index = -1
		building_drag.cancel()
		if not snapshot_mode and not visual_test:
			state.save_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if light_bridge_busy: return
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
	var undo_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z and event.is_command_or_control_pressed()
	if town_build.active and not is_instance_valid(modal):
		if event.is_action_pressed("ui_cancel"): town_build.finish(); return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and town_build.rotatable(): town_build.rotate(); return
		if undo_key: town_build.undo(); return
	if undo_key and not is_instance_valid(modal) and not state.town_journal.is_empty(): _town_undo(); return
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
	# v0.31: building reactors needs an installing doctor and the recipe's elements.
	if not state.install_status().ok: state.campus.people.append(state.campus._new_person("doctor",-1,true))
	for symbol in state.elements: state.element_inventory[symbol] = 500
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
	TestInput.send(motion)
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
	TestInput.send(touch_drag)
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
	TestInput.send(map_drag)
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
	state.planet.v2.nature.minerals["halite"]=int(state.planet.v2.nature.minerals.get("halite",0))+3
	_show_refinery("Cl")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/refinery-v028.png")
	var old_chlorine: int = state.element_inventory.Cl
	var old_wallet: float = state.coins
	var refine_button: Button = null
	for b in modal.processes.find_children("*","Button",true,false):
		if b.text=="开始精炼" and b.get_parent().get_child(0).text.begins_with("岩盐熔融电解"): refine_button=b
	var refine_position: Vector2 = refine_button.get_global_rect().get_center()
	await _test_pointer(refine_position,true)
	await _test_pointer(refine_position,false)
	for i in range(2): state.refinery.start(state,"halite_electrolysis")
	state.refinery.tick(state,3.0*float(state.refinery.process("halite_electrolysis").seconds))
	assert(state.element_inventory.Cl >= old_chlorine+6 and state.coins == old_wallet,"Refining three halite adds chlorine without spending coins")
	old_chlorine = state.element_inventory.Cl
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
	assert(state.element_inventory.Cl == old_chlorine,"Canceling grouped substitution spends no elements")
	_close_modal()
	print("UI SMOKE PASS: existing island/market/touch flows, refinery electrolysis, element palette, free preview, substitution commit, unknown labeling, undo, Android back, grouped halide preview and cancel")
	get_tree().quit()

func _test_pointer(pos: Vector2, down: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	TestInput.send(event)
	await get_tree().process_frame

func _test_touch(pos: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.position = pos
	event.index = 0
	event.pressed = down
	TestInput.send(event)
	await get_tree().process_frame


func _show_island_walk() -> void:
	if _resume_existing(IslandWalk): return
	_replace_modal()
	var panel=IslandWalk.new(); add_child(panel); modal=panel; panel.setup(state)
	world_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	panel.dismissed.connect(func(): _screen_closed(panel))
	panel.requested.connect(func(kind: String,index: int):
		if kind=="planet": _show_planet_v2(); modal.enter_first_person()
		elif kind=="miniatures": _show_miniatures()
		elif kind=="workshop": _show_factory()
		elif kind=="reactor": _select_plot(index); _open_editor()
		elif kind in ["engineer_house","doctor_dorm","professor_apartment","academician_villa","house"]:
			if not panel.enter_residence(index): _close_modal(); _select_plot(index)
		else: _close_modal(); _select_plot(index))

func _show_miniatures() -> void:
	var body=_dialog("河湾作品 · 把探索带回家", "星球上装备微缩器，瞄准自建作品装箱。作品会从原地搬走；「复刻」只做展示用的复制品。",true)
	var boxes=state.planet.home().construction.miniatures
	if boxes.is_empty():
		body.add_child(UI.paragraph("还没有带回来的作品。先用工艺车间做出的构件搭一座小屋、一段桥或雕塑，再用背包里的微缩器收纳。\n每件最多64块、8×8×8格；有作物的种植箱先收获。",18))
		body.add_child(UI.button("走过光桥去河湾",_show_planet_v2,true)); return
	body.add_child(UI.paragraph("每块地可以放一座角落展台；也可以在“布置庭院”里买石展台、旋转展台或玻璃展柜，一块地摆很多件。展品仍属于你：收回后可在河湾重新展开。",16,UI.MUTED))
	for id in boxes:
		var item=boxes[id]; var card=PanelContainer.new(); card.add_theme_stylebox_override("panel",UI.style(Color("213c45"),14)); body.add_child(card)
		var row=UI.row(card,12); row.add_child(UI.label("%s · %d块" % [item.name,item.blocks.size()],19,UI.MINT))
		if item.get("replica",false): row.add_child(UI.label("复刻 · 仅展示",14,UI.LILAC))
		var copy_cost=preload("res://scripts/river_miniatures.gd").replica_cost(state.planet.home().construction,id)
		var copy=UI.button("复刻 · %d金币" % copy_cost,func(): _action(state.replicate_miniature(id)); _show_miniatures())
		copy.disabled=boxes.size()>=16 or state.coins<copy_cost; copy.tooltip_text="做一份只用于展示的复制品；原作仍可在星球展开"
		if int(item.plot)==-2: row.add_child(UI.label("摆在庭院展台上 · 在地块物品列表收回",16,UI.GOLD)); row.add_child(copy); continue
		var options=OptionButton.new(); options.custom_minimum_size=Vector2(380,48); row.add_child(options)
		options.add_item("留在背包",0); options.set_item_metadata(0,-1)
		for i in range(state.plots.size()):
			var p=state.plots[i]
			if not p.unlocked or p.kind=="plaza": continue
			options.add_item("地块 (%d,%d) · %s" % [p.x,p.z,p.kind]); var at=options.item_count-1; options.set_item_metadata(at,i)
			if item.plot==i: options.select(at)
		row.add_child(UI.button("摆放 / 收回",func():
			_action(state.planet.command(state,"v2_mini_exhibit",{"id":id,"plot":options.get_item_metadata(options.selected)})); _show_miniatures(),true))
		row.add_child(copy)
	body.add_child(UI.button("走近展台看看",_show_island_walk))


# --- 0.27 Hometown: courtyard list, item actions and the coin shop ---------------------------
func _town_sidebar(p: Dictionary) -> void:
	if p.kind == "plaza" or p.kind in Town.LEGACY_WHOLE: return
	UI.spacer(side,6)
	var items: Array = p.get("items",[])
	side.add_child(UI.label("庭院 · %d件" % items.size(),15,UI.LILAC))
	side.add_child(UI.button("布置庭院 · 商店",_show_town_shop,true))
	var tools = UI.row(side,6)
	tools.add_child(UI.button("擦除小路/装饰",town_build.start_erase))
	var last: String = state.town_undo_text()
	if not last.is_empty():
		var undo_button = UI.button("↶ 撤销",_town_undo)
		undo_button.tooltip_text = "撤销：" + last
		tools.add_child(undo_button)
	var recyclable: int = state.town_recyclable(selected_plot).size()
	if recyclable > 0:
		var armed: bool = town_recycle_armed == selected_plot
		side.add_child(UI.button("再点一次确认回收%d件" % recyclable if armed else "回收本地块装饰与小路（%d）" % recyclable,_town_recycle.bind(selected_plot),armed))
	if selected_item >= 0: _town_item_actions(p)
	var buildings: Array = []
	var decor: Dictionary = {}
	for item in items:
		if Town.is_building(str(item.kind)) or bool(Town.info(str(item.kind)).get("display",false)): buildings.append(item)
		else: decor[item.kind] = int(decor.get(item.kind,0)) + 1
	if Town.is_building(str(p.kind)) and selected_item != 0:
		side.add_child(UI.button("主建筑 · %s  Lv%d" % [state.town_name(str(p.kind)),int(p.get("building_level",1))],_pick_item.bind(0)))
	for item in buildings:
		if int(item.uid) == selected_item: continue
		var text = state.town_name(str(item.kind))
		if item.has("level"): text += "  Lv%d" % int(item.level)
		var show: Dictionary = item.get("show",{})
		if bool(Town.info(str(item.kind)).get("display",false)): text += "  · " + (_exhibit_name(show) if not show.is_empty() else "空展台")
		side.add_child(UI.button(text,_pick_item.bind(int(item.uid))))
	if not decor.is_empty():
		var names: Array = []
		for kind in decor: names.append("%s×%d" % [state.town_name(str(kind)),int(decor[kind])])
		side.add_child(UI.paragraph("、".join(names) + "\n点世界里的装饰可单独挪动、收起或出售。",12))

## v0.31 one-click recycle: the first tap arms, the second puts everything in the toolbox.
func _town_recycle(plot: int) -> void:
	if town_recycle_armed != plot:
		town_recycle_armed = plot; _rebuild_sidebar(); return
	town_recycle_armed = -1
	selected_item = -1
	_action(state.town_recycle(plot))

func _town_undo() -> void:
	town_recycle_armed = -1
	selected_item = -1
	_action(state.town_undo())

func _pick_item(uid: int) -> void:
	selected_item = uid
	_rebuild_sidebar()

func _exhibit_name(show: Dictionary) -> String:
	if show.get("type") == "mineral": return str(preload("res://scripts/planet_geology.gd").info(str(show.id)).get("name",show.id))
	var mini: Dictionary = state.planet.home().construction.miniatures.get(str(show.get("id","")),{})
	return str(mini.get("name","河湾作品"))

func _town_item_actions(p: Dictionary) -> void:
	var plot = selected_plot
	var uid = selected_item
	var card = UI.box(side,Rect2(),Color("2b4a4f"))
	var v = UI.column(card,6)
	if uid == 0:
		if not Town.is_building(str(p.kind)): selected_item = -1; card.queue_free(); return
		var info: Dictionary = state.layout.building_info(str(p.kind))
		var level = int(p.get("building_level",1))
		v.add_child(UI.label("主建筑 · %s" % info.name,17,UI.MINT))
		v.add_child(UI.paragraph("%d层 · %s · 占地%d×%d格" % [level,state.TIER_NAMES[Town.tier(level,int(info.max_level))-1],Town.size(str(p.kind)).x,Town.size(str(p.kind)).y],12))
		var row = UI.row(v,6)
		row.add_child(UI.button("挪动位置",func(): town_build.start_move(plot,0)))
		var up = UI.button("升级 %d金币" % (int(info.upgrade_cost)*level),func(): _action(state.town_upgrade(plot,0)))
		up.disabled = level >= int(info.max_level)
		row.add_child(up)
		return
	var item: Dictionary = state.town_item(plot,uid)
	if item.is_empty(): selected_item = -1; card.queue_free(); return
	var kind = str(item.kind)
	v.add_child(UI.label(state.town_name(kind),17,UI.MINT))
	var row = UI.row(v,6)
	row.add_child(UI.button("挪动",func(): town_build.start_move(plot,uid)))
	if Town.is_building(kind):
		var info: Dictionary = state.layout.building_info(kind)
		var level = int(item.level)
		v.add_child(UI.paragraph("%d层 · %s · 与同地块的同类建筑共用容量" % [level,state.TIER_NAMES[Town.tier(level,int(info.max_level))-1]],12))
		var up = UI.button("升级 %d" % (int(info.upgrade_cost)*level),func(): _action(state.town_upgrade(plot,uid)))
		up.disabled = level >= int(info.max_level)
		row.add_child(up)
	else:
		row.add_child(UI.button("收起",func(): selected_item = -1; _action(state.town_store(plot,uid))))
	row.add_child(UI.button("出售",func(): selected_item = -1; _action(state.town_sell(plot,uid))))
	if bool(Town.info(kind).get("display",false)):
		var show: Dictionary = item.get("show",{})
		if show.is_empty():
			v.add_child(UI.paragraph("展台空着：放上星球采掘的矿物标本，或微缩的河湾作品。",12))
			v.add_child(UI.button("选择展品",_show_exhibit_picker.bind(plot,uid),true))
		else:
			v.add_child(UI.paragraph("展出：" + _exhibit_name(show),13,UI.GOLD))
			var shows = UI.row(v,6)
			shows.add_child(UI.button("更换展品",_show_exhibit_picker.bind(plot,uid)))
			shows.add_child(UI.button("收回",func(): _action(state.town_unexhibit(plot,uid))))

func _show_town_shop() -> void:
	var body = _dialog("庭院商店","选好后点地块上的空格摆放，可以跨过地块边缘。绿色格子可以放，红色是被占用或超出了已开拓的土地。摆错了点「↶ 撤销」（Ctrl+Z）；收起的装饰进入工具箱，再次摆放免费；出售退回一半金币。",true)
	var tabs = UI.row(body,8)
	for category in Town.rules().categories:
		var id = str(category.id)
		tabs.add_child(UI.button(str(category.name),func(): town_shop_category = id; _show_town_shop(),id == town_shop_category))
	var grid = GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12)
	body.add_child(grid)
	var kinds: Array = []
	if town_shop_category == "building": kinds = state.layout.building_kinds()
	else:
		for kind in Town.rules().items:
			if str(Town.info(kind).category) == town_shop_category: kinds.append(kind)
	for kind in kinds:
		var card = UI.box(grid,Rect2(),Color("22403f"))
		card.custom_minimum_size = Vector2(282,0)
		var v = UI.column(card,6)
		v.add_child(UI.label(state.town_name(kind),18,UI.MINT))
		var footprint: Vector2i = Town.size(kind)
		var stored = int(state.storage.decorations.get(kind,0))
		var price_text = "工具箱里有%d件 · 免费" % stored if stored > 0 else "%d 金币" % state.town_price(kind)
		v.add_child(UI.label(price_text,15,UI.GOLD))
		var note = "占地%d×%d格" % [footprint.x,footprint.y]
		if Town.is_building(kind): note += " · 容量%d人 · 5级分三种外观" % int(state.layout.building_info(kind).capacity)
		elif bool(Town.info(kind).get("paint",false)): note += " · 可拖动连续铺设"
		elif bool(Town.info(kind).get("display",false)): note += " · 可展出矿物或河湾作品"
		v.add_child(UI.paragraph(note,12))
		var locked = state.town_locked(kind) if stored <= 0 and not Town.is_building(kind) else ""
		var place = UI.button(locked if not locked.is_empty() else "摆放",func(): town_build.start_place(kind),locked.is_empty())
		place.disabled = not locked.is_empty() or (stored <= 0 and state.coins < state.town_price(kind))
		v.add_child(place)

func _show_exhibit_picker(plot: int, uid: int) -> void:
	var body = _dialog("选择展品","矿物标本来自星球地下采掘的背包库存；河湾作品需要先在星球上用微缩器装盒。展出的东西随时可以收回。",false)
	var any = false
	body.add_child(UI.label("矿物标本",18,UI.GOLD))
	var Geology = preload("res://scripts/planet_geology.gd")
	for id in state.planet.v2.nature.minerals:
		if int(state.planet.v2.nature.minerals[id]) <= 0 or id in ["topsoil","bedrock"]: continue
		var spec: Dictionary = Geology.info(str(id))
		if spec.is_empty(): continue
		any = true
		body.add_child(UI.button("%s  %s  ·  背包%d" % [spec.name,spec.get("formula",""),int(state.planet.v2.nature.minerals[id])],func(): _close_modal(); _action(state.town_exhibit(plot,uid,{"type":"mineral","id":str(id)}))))
	body.add_child(UI.label("河湾作品",18,UI.LILAC))
	for id in state.planet.home().construction.miniatures:
		var mini: Dictionary = state.planet.home().construction.miniatures[id]
		if int(mini.plot) != -1: continue
		any = true
		body.add_child(UI.button("%s · %d块" % [mini.name,mini.blocks.size()],func(): _close_modal(); _action(state.town_exhibit(plot,uid,{"type":"mini","id":str(id)}))))
	if not any: body.add_child(UI.paragraph("背包里还没有可展出的东西。去星球挖一块石灰岩、黏土或矿石，或把自己搭的作品装进微缩盒吧。",15))
