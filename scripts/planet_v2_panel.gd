extends Control
signal dismissed
signal acted(message: String)
signal workshop_requested(recipe_id: String)
signal synthesis_requested
signal test_requested
## v0.48: E at the starship opens the star map (handled by main: launching swaps the world).
signal voyage_requested
const UI=preload("res://scripts/ui.gd")
const View=preload("res://scripts/planet_v2_view.gd")
const ExplorationInput=preload("res://scripts/river_exploration_input.gd")
const Shape=preload("res://scripts/planet_shape.gd")
const InventorySlot=preload("res://scripts/river_inventory_slot.gd")
const InventoryPanel=preload("res://scripts/river_inventory_panel.gd")
const InteractionHelp=preload("res://scripts/river_interaction_help.gd")
var state
var view
var viewport: SubViewport
var viewport_box: SubViewportContainer
var body: VBoxContainer
var scroll: ScrollContainer
var status: Label
var time_label: Label
var info: Label
var counters: Label
var world_title: Label
var pause_button: Button
var enter_button: Button
var explore_input
var camera_bar: HBoxContainer
var right_panel: PanelContainer
var inspect_button: Button
var hint: Label
var map_button: Button
## v0.33.1: the next unfinished era requirement, shown while walking.
var goal_label: Label
var show_details=false
var selected_region="wetland"
var section="observe"
var refresh=0.0
var fingerprint=""
var message=""
var widgets={}
var regions={}
var where_label: Label
var tabs={}
var closing=false
var build_mode="observe"
var play_bar: HBoxContainer
var action_button: Button
var attack_button: Button
var aim_label: Label
var aim_clock=0.0
var hotbar_slots=[]
var inventory_items={}
var backpack=null
var encounter_hud
var faint_button
var combat_clock=0.0
var scroll_memory=preload("res://scripts/panel_scroll.gd").new()
## v0.32: whole-planet climate overlay.
var earth_map

func setup(model) -> void:
	state=model; state.planet.v2.active=true; state.planet.v2.observer_id=get_instance_id()
	selected_region=str(state.planet.v2.world.current_region)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var here_planet: Dictionary=state.planet.v2.planet_info()
	var heading=UI.label("蓝色星球 · 从河湾出发，走遍整颗星球" if state.planet.v2.planet=="earth" else "%s · %s" % [here_planet.name,here_planet.title],30,UI.MINT if state.planet.v2.planet=="earth" else Color("f0a878")); heading.position=Vector2(28,18); add_child(heading)
	var sub=UI.label("地球仪 ↔ 第一人称   /   大洋、大陆、山脉与两极冰盖，纬度决定气候与植被   /   环绕一圈约16公里",14,UI.MUTED); sub.position=Vector2(30,62); add_child(sub)
	var close=UI.button("返回浮岛",_close); close.position=Vector2(1288,22); close.size=Vector2(124,48); add_child(close)
	time_label=UI.label("",19,UI.GOLD); time_label.position=Vector2(680,28); time_label.size=Vector2(580,38); time_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; add_child(time_label)
	# v0.42: no region tabs; the four home habitats are found by walking around the river bend.
	var region_bar=UI.row(self,8); region_bar.position=Vector2(28,99)
	where_label=UI.label("",17,UI.TEXT); where_label.custom_minimum_size=Vector2(700,48); where_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; region_bar.add_child(where_label)
	enter_button=UI.button("第一人称进入",_enter,true); enter_button.custom_minimum_size.x=194; region_bar.add_child(enter_button)
	viewport_box=SubViewportContainer.new(); viewport_box.position=Vector2(28,158); viewport_box.size=Vector2(928,574); viewport_box.stretch=true; viewport_box.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(viewport_box)
	viewport=SubViewport.new(); viewport.size=Vector2i(928,574); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport_box.add_child(viewport)
	view=View.new(); view.terrain=state.planet.v2.construction.terrain; view.walker.terrain=view.terrain; viewport.add_child(view)
	view.region_selected.connect(_walked_region)
	explore_input=ExplorationInput.new(); explore_input.view=view; explore_input.position=viewport_box.position; explore_input.size=viewport_box.size
	add_child(explore_input)
	explore_input.terrain_clicked.connect(_map_click)
	explore_input.journey_requested.connect(_open_journey)
	explore_input.collect_requested.connect(_collect)
	explore_input.build_requested.connect(_open_backpack)
	explore_input.slot_requested.connect(_select_slot)
	explore_input.slot_cycled.connect(func(direction): _select_slot(posmod(state.planet.v2.inventory.selected+direction,9)))
	explore_input.primary_requested.connect(_primary)
	explore_input.attack_requested.connect(_attack)
	explore_input.zoomed.connect(func(amount): view.zoom=clampf(view.zoom+amount,0.65,1.4))
	encounter_hud=preload("res://scripts/encounter_hud.gd").new(); encounter_hud.v=state.planet.v2; encounter_hud.position=viewport_box.position; encounter_hud.size=viewport_box.size; add_child(encounter_hud); encounter_hud.hide()
	faint_button=UI.button("回营地休息",func(): state.planet.v2.combat.respawn(); _travel("home")); faint_button.position=Vector2(650,430); faint_button.hide(); add_child(faint_button)
	world_title=UI.label("",18,UI.MINT); world_title.position=Vector2(48,180); add_child(world_title)
	goal_label=UI.label("",14,UI.GOLD); goal_label.position=Vector2(48,342); goal_label.size=Vector2(560,48); goal_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	goal_label.add_theme_constant_override("outline_size",5); goal_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.75)); add_child(goal_label)
	hint=UI.label("拖动转动地球仪 · 滚轮缩放 · 第一人称走进去",13,UI.TEXT); hint.position=Vector2(48,705); add_child(hint)
	camera_bar=UI.row(self,8); camera_bar.position=Vector2(470,676)
	camera_bar.add_child(UI.button("↶",func(): view.orbit(-0.4)))
	camera_bar.add_child(UI.button("↷",func(): view.orbit(0.4)))
	camera_bar.add_child(UI.button("＋",func(): view.zoom=clampf(view.zoom-0.15,0.65,1.4)))
	camera_bar.add_child(UI.button("－",func(): view.zoom=clampf(view.zoom+0.15,0.65,1.4)))
	camera_bar.add_child(UI.button("环境图",toggle_earth_map))
	camera_bar.add_child(UI.button("世界地图",_open_world_map))
	var time_box=UI.box(self,Rect2(28,748,928,91))
	var time_row=UI.row(time_box,10)
	pause_button=UI.button("暂停",func(): _act("v2_pause",{"paused":not state.planet.v2.world.paused})); time_row.add_child(pause_button)
	for speed in [1,4,8]: time_row.add_child(UI.button("%d×" % speed,func(): _act("v2_speed",{"speed":speed})))
	counters=UI.paragraph("",16,UI.GOLD); counters.size_flags_horizontal=Control.SIZE_EXPAND_FILL; time_row.add_child(counters)
	right_panel=UI.box(self,Rect2(976,99,436,740)); var col=UI.column(right_panel,10)
	info=UI.paragraph("",17,UI.MINT); col.add_child(info)
	var nav=GridContainer.new(); nav.columns=4; nav.add_theme_constant_override("h_separation",5); col.add_child(nav)
	for entry in [["observe","生命"],["bag","背包"],["explore","远行"],["build","搭建"],["ranch","村庄"],["era","时代"],["journal","年鉴"],["organics","配料"]]:
		var b=UI.button(entry[1],_tab.bind(entry[0])); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; nav.add_child(b); tabs[entry[0]]=b
		b.add_theme_font_size_override("font_size",14); b.custom_minimum_size.x=82
	scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; col.add_child(scroll)
	body=UI.column(scroll,10); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inspect_button=UI.button("世界 / 远行",_toggle_details); inspect_button.position=Vector2(1240,170); inspect_button.size=Vector2(148,44); inspect_button.hide(); add_child(inspect_button)
	if preload("res://scripts/test_mode.gd").enabled():
		var tester=UI.button("测试",func(): test_requested.emit()); tester.focus_mode=Control.FOCUS_NONE; tester.position=Vector2(1150,108); tester.size=Vector2(80,40); add_child(tester)
	map_button=UI.button("地图",_open_world_map); map_button.focus_mode=Control.FOCUS_NONE; map_button.size=Vector2(148,44); map_button.hide(); add_child(map_button)
	attack_button=UI.button("攻击 F",_attack); attack_button.focus_mode=Control.FOCUS_NONE; attack_button.size=Vector2(148,44); attack_button.hide(); add_child(attack_button)
	status=UI.paragraph("M前往采集坡 · 用手套采集原料 → 工艺车间加工 → 背包搭建、播种和浇水。",15,UI.GOLD); status.position=Vector2(32,853); status.size=Vector2(1370,35); add_child(status)
	play_bar=UI.row(self,4); play_bar.position=Vector2(300,656)
	for i in range(state.planet.v2.inventory.slots.size()):
		var slot=InventorySlot.new(); play_bar.add_child(slot); slot.custom_minimum_size=Vector2(56,72); hotbar_slots.append(slot)
		slot.pressed.connect(_select_slot.bind(i))
	action_button=UI.button("操作 E",_collect,true); action_button.focus_mode=Control.FOCUS_NONE; play_bar.add_child(action_button)
	var jump_button=UI.button("跳跃 ␣",func(): view.pilot().jump()); jump_button.focus_mode=Control.FOCUS_NONE; play_bar.add_child(jump_button)
	var bag_button=UI.button("背包 B",_open_backpack); bag_button.focus_mode=Control.FOCUS_NONE; play_bar.add_child(bag_button)
	play_bar.hide()
	aim_label=UI.label("",15,UI.GOLD); aim_label.position=Vector2(350,606); add_child(aim_label); aim_label.hide()
	_refresh_hotbar(); _redraw(); _sync.call_deferred()

## v0.33.1 世界地图: trail, waypoints, buildings and where I am, over the whole Earth.
func _open_world_map() -> void:
	explore_input.clear_input()
	var map=preload("res://scripts/planet_world_map.gd").new(); add_child(map); map.setup(state,view)
	map.travel_requested.connect(_travel_waypoint)
	map.closed.connect(func(): if view.first_person: explore_input.grab_focus())

func toggle_earth_map() -> void:
	if is_instance_valid(earth_map) and earth_map.env==state.planet.v2.environment:
		earth_map.visible=not earth_map.visible
	else:
		if is_instance_valid(earth_map): earth_map.queue_free()
		earth_map=preload("res://scripts/earth_map.gd").new(); earth_map.name="EarthMap"
		earth_map.position=viewport_box.position+Vector2(0,-6); earth_map.size=Vector2(928,580); add_child(earth_map)
		earth_map.setup(state.planet.v2.environment,_observer_position)
	if earth_map.visible: earth_map.move_to_front()

func _map_click(at: Vector2) -> void:
	# Only the map's GUI layer owns selection; its coordinates are always local.
	# A first-person click must never become a region/respawn command.
	if view.first_person or view.globe_shown: return
	var id=view.pick(at*Vector2(viewport.size)/explore_input.size)
	if not id.is_empty(): _select_region(id)

func _select_region(id: String) -> void:
	selected_region=id; message=state.planet.command(state,"v2_enter",{"region_id":id})
	view.focus(id,view.close_view); _redraw(); _sync()
	if view.first_person: explore_input.clear_input(); explore_input.grab_focus()

func _walked_region(id: String) -> void:
	if _in_wilderness(): return
	selected_region=id; state.planet.command(state,"v2_enter",{"region_id":id})
	message="步行来到"+str(state.planet.v2.region().name); _redraw()

func _enter() -> void:
	view.set_first_person(not view.first_person); explore_input.set_walking(view.first_person)
	show_details=false; _exploration_layout(); _redraw(); _sync()

func _toggle_details() -> void:
	show_details=not show_details; explore_input.clear_input(); _exploration_layout()
	if not show_details: explore_input.grab_focus()

func _exploration_layout() -> void:
	var wide=view.first_person and not show_details
	viewport_box.size=Vector2(1384 if wide else 928,574)
	explore_input.size=viewport_box.size
	encounter_hud.size=viewport_box.size; encounter_hud.visible=view.first_person
	right_panel.visible=not wide; camera_bar.visible=not view.first_person
	inspect_button.visible=view.first_person; inspect_button.position.x=1240 if wide else 790
	attack_button.visible=view.first_person; attack_button.position=Vector2(1240 if wide else 790,224)
	map_button.visible=view.first_person; map_button.position=Vector2(1240 if wide else 790,278)
	inspect_button.text="收起面板" if show_details else "世界 / 远行"
	play_bar.visible=view.first_person; aim_label.visible=view.first_person
	play_bar.position.x=300 if wide else 56; aim_label.position.x=350 if wide else 220
	aim_label.size=Vector2(890 if wide else 710,44); aim_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.position=Vector2(48,214) if view.first_person else Vector2(48,705)
	hint.text="WASD走动 · 拖动转向 · F攻击 · E使用/查看 · B背包 · M远行\n拿手套时：左键攻击生物，E查看；手机点攻击或使用按钮" if view.first_person else "拖动转动地球仪 · 滚轮缩放 · 第一人称走进去"
	if not view.first_person: state.planet.v2.actor={}; view.construction_view.ghost.hide()

func _in_wilderness() -> bool:
	return view!=null and view.first_person and view.walker.position.length()>float(view.terrain.rules.home_radius)+2

func _observer_position() -> Vector2:
	return view.observer()

func _open_journey() -> void:
	show_details=true; explore_input.clear_input(); _exploration_layout(); _tab("explore")

func _travel(id: String) -> void:
	var destination=view.terrain.LANDMARKS[id]
	view.travel(destination.at); explore_input.set_walking(true)
	show_details=false; _exploration_layout(); message="抵达"+str(destination.name)+"。M查看旅途，成熟的金色野草可以采集。"
	if id=="homestead": message="采集坡：装备斧头砍树得木料、纤维和野果，采掘镐挖岩石得石料；原料带回工艺车间。"
	_redraw(); _sync()

## 测试版 only: jump to any point of the 16 km world.
func test_teleport(at: Vector2, label: String) -> void:
	if not view.first_person: _enter()
	if not view.travel(at): message="测试传送失败：%s附近没有落脚点" % label; _live(); return
	explore_input.set_walking(true)
	show_details=false; _exploration_layout(); message="测试传送：%s（%.0f, %.0f 米）" % [label,at.x,at.y]
	_redraw(); _sync()

func _travel_waypoint(id: String) -> void:
	var point=state.planet.v2.journey.points.get(id,{})
	if point.is_empty(): return
	if not view.travel(Vector2(point.x,point.z)): message="路标附近已被堵住，暂时无法落脚"; _live(); return
	explore_input.set_walking(true)
	show_details=false; _exploration_layout(); message="返回"+str(point.name)
	_redraw(); _sync()

func _primary() -> void:
	if is_instance_valid(backpack): return
	if view.driving: return
	_update_actor()
	var v=state.planet.v2
	var item: Dictionary=inventory_items.get(v.inventory.slots[v.inventory.selected],{})
	if item.get("action",{}).get("type")=="collect" and v.Target.query(v).has("entity"):
		_attack()
	else: _collect()

func _attack() -> void:
	if not view.first_person or view.driving or is_instance_valid(backpack) or state.planet.v2.combat.player_health<=0: return
	_update_actor()
	var v=state.planet.v2; var target=v.Target.query(v)
	var before=float(target.entity.row.get("health",1)) if target.has("entity") else 0.0
	view.hands.swing()
	_act("v2_strike")
	if target.has("entity") and float(target.entity.row.get("health",1))<before:
		encounter_hud.hit_flash=0.3
		view.field_view.feedback(target.point)

## v0.41: the rover follows the deployed vehicle; it appears beside the player the first time.
func _sync_rover() -> void:
	var v=state.planet.v2; var ind=state.industry
	view._ensure_rover(); view.rover.state=ind.rover_state
	if ind.vehicle=="":
		if view.driving: view.exit_rover()
		view.park_rover(null); v.rover_at={}; v.driving=false; return
	if view.driving:
		v.rover_at={"x":view.rover.position.x,"z":view.rover.position.y,"heading":view.rover.heading}; return
	if v.rover_at.is_empty() and view.first_person:
		var f=Vector2(-sin(view.walker.yaw),-cos(view.walker.yaw)); var side=Vector2(-f.y,f.x)
		for offset in [f*3.0+side*1.2,f*3.0-side*1.2,side*2.8,-side*2.8,-f*3.0]:
			var p=view.walker.position+offset
			if view.terrain.inside(p,3) and not view.terrain.blocked(p,view.walker.barriers):
				v.rover_at={"x":p.x,"z":p.y,"heading":view.walker.yaw}; break
	if v.rover_at.is_empty(): view.park_rover(null); return
	var at=Vector2(float(v.rover_at.x),float(v.rover_at.z))
	if not view.rover_parked or view.rover.position.distance_to(at)>0.5: view.park_rover(at,float(v.rover_at.heading))

## v0.48: the starship stands where it landed (or beside the player the first time it is commissioned).
func _sync_ship() -> void:
	var v=state.planet.v2; var ind=state.industry
	if ind.ship=="":
		view.park_ship(null); v.ship_at={}; return
	if v.ship_at.is_empty() and view.first_person:
		var f=Vector2(-sin(view.walker.yaw),-cos(view.walker.yaw)); var side=Vector2(-f.y,f.x)
		for offset in [f*9.0+side*6.0,f*9.0-side*6.0,side*9.0,-side*9.0,f*12.0]:
			var p=view.walker.position+offset
			if view.terrain.inside(p,8) and not view.terrain.blocked(p,view.walker.barriers) and not view.terrain.water_at(p):
				v.ship_at={"x":p.x,"z":p.y,"heading":view.walker.yaw}; break
	if v.ship_at.is_empty(): view.park_ship(null); return
	var at=Vector2(float(v.ship_at.x),float(v.ship_at.z))
	if not view.ship_parked or view.ship_at.distance_to(at)>0.5: view.park_ship(at,float(v.ship_at.heading))

func near_ship() -> bool:
	return view.ship_parked and view.first_person and not view.driving and not view.flying and not view.boring and view.walker.position.distance_to(view.ship_at)<=6.0

## v0.47: the plane follows the deployed aircraft; it is parked beside the player the first time.
func _sync_plane() -> void:
	var v=state.planet.v2; var ind=state.industry
	view._ensure_plane(ind.rules().plane); view.plane.state=ind.plane_state
	if ind.plane=="":
		if view.flying: view.exit_plane()
		view.park_plane(null); v.plane_at={}; v.flying=false; return
	if view.flying: v.plane_at={"x":view.plane.position.x,"z":view.plane.position.y,"heading":view.plane.heading}; return
	if v.plane_at.is_empty() and view.first_person:
		var f=Vector2(-sin(view.walker.yaw),-cos(view.walker.yaw)); var side=Vector2(-f.y,f.x)
		for offset in [f*7.0+side*3.0,f*7.0-side*3.0,side*7.0,-side*7.0,f*10.0]:
			var p=view.walker.position+offset
			if view.terrain.inside(p,6) and not view.terrain.blocked(p,view.walker.barriers):
				v.plane_at={"x":p.x,"z":p.y,"heading":view.walker.yaw}; break
	if v.plane_at.is_empty(): view.park_plane(null); return
	var at=Vector2(float(v.plane_at.x),float(v.plane_at.z))
	if not view.plane_parked or view.plane.position.distance_to(at)>0.5: view.park_plane(at,float(v.plane_at.heading))

func near_plane() -> bool:
	return view.plane_parked and not view.flying and view.walker.position.distance_to(view.plane.position)<=4.5

func _toggle_plane() -> bool:
	var v=state.planet.v2
	if view.flying:
		if view.exit_plane():
			v.flying=false; v.plane_at={"x":view.plane.position.x,"z":view.plane.position.y,"heading":view.plane.heading}
			message="下机 · 小飞机停在原地，电量 %d%%" % roundi(100*float(view.plane.state.charge)/maxf(1.0,float(view.plane.state.cap)))
		elif view.plane.airborne: message="还在空中：先降落（收油门、机头略抬，慢慢接近地面或水面）"
		else: message="先停稳再下机（S 收油门）"
		_live(); return true
	if near_plane():
		view.enter_plane(); v.flying=true
		message="登机 · W 加油门 · S 收油门 · A/D 转弯 · 上下拖动控制机头 · 空格改平 · 停稳后 E 下机"
		_live(); return true
	return false

## The flight panel (replaces the aim line while flying).
func _plane_text() -> String:
	var p=view.plane
	return "小飞机 · %s · 速度 %d km/h · 高度 %d 米 · 油门 %d%% · 电量 %d%%\n%s · 航向 %s%s" % ["飞行中" if p.airborne else ("水面滑行" if view.terrain.water_at(p.position) or view.terrain.deep_water(p.position) else "地面滑跑"),roundi(p.speed*3.6),roundi(p.height_above_ground()),roundi(p.throttle*100),roundi(100.0*float(p.state.charge)/maxf(1.0,float(p.state.cap))),Shape.coordinates(p.position),["北","东北","东","东南","南","西南","西","西北"][posmod(roundi(-p.heading/(PI/4)),8)]," · "+p.message if p.message!="" else ""]

## v0.45: the 盾构机 follows the deployed machine; it appears in front of the player the first time.
func _sync_tbm() -> void:
	var v=state.planet.v2; var ind=state.industry
	view.v2=v; view._ensure_tbm(ind.rules().tbm); view.tbm.state=ind.tbm_state
	if ind.tbm=="":
		if view.boring: view.exit_tbm()
		view.park_tbm(null); v.tbm_at={}; v.boring=false; return
	if view.boring: v.tbm_at=_tbm_record(); return
	if v.tbm_at.is_empty() and view.first_person:
		var f=Vector2(-sin(view.walker.yaw),-cos(view.walker.yaw))
		for k in [3.0,4.0,5.0]:
			var p=(view.walker.position+f*k).round()
			if view.terrain.inside(p,4) and not view.terrain.deep_water(p):
				v.tbm_at={"x":int(p.x),"y":floori(view.terrain.ground(p)+0.01),"z":int(p.y),"facing":view.walker.construction.facing_rot(Vector3(f.x,0,f.y)),"grade":0}; break
	if v.tbm_at.is_empty(): view.park_tbm(null); return
	var at=Vector3i(int(v.tbm_at.x),int(v.tbm_at.y),int(v.tbm_at.z))
	if not view.tbm_parked or view.tbm.cell!=at or view.tbm.facing!=int(v.tbm_at.facing): view.park_tbm(at,int(v.tbm_at.facing),int(v.tbm_at.grade))

func _tbm_record() -> Dictionary:
	var c: Vector3i=view.tbm.cell
	return {"x":c.x,"y":c.y,"z":c.z,"facing":view.tbm.facing,"grade":view.tbm.grade}

func near_tbm() -> bool:
	if not view.tbm_parked or view.boring: return false
	var c: Vector3i=view.tbm.cell
	return view.walker.position.distance_to(Vector2(c.x,c.z))<=3.6 and absf(view.walker.feet_y-c.y)<2.6

func _toggle_tbm() -> bool:
	var v=state.planet.v2
	if view.boring:
		if view.exit_tbm():
			v.boring=false; v.tbm_at=_tbm_record()
			message="离开盾构机 · "+view.tbm.haul_text()
		else: message="周围没有能站的地方，先后退一点"
		_live(); return true
	if near_tbm():
		view.enter_tbm(); v.boring=true; view.tbm.haul={}; view.tbm.overflow=0
		message="进入盾构机 · W 掘进 · S 后退 · A/D 转向 · 空格切换 水平/下潜/上爬 · E 离开"
		_live(); return true
	return false

## The machine's dashboard (replaces the aim line while boring).
func _tbm_text() -> String:
	var t=view.tbm; var c: Vector3i=t.cell
	var depth=floori(view.terrain.ground(Vector2(c.x,c.z)))-c.y
	return "盾构机 · %s · %s · 电量 %d%%\n%s\n%s%s" % [t.GRADES[t.grade],"地下 %d 米" % depth if depth>0 else "地面",roundi(100.0*float(t.state.charge)/maxf(1.0,float(t.state.cap))),t.preview(view.v2),t.haul_text()," · "+t.message if t.message!="" else ""]

## v0.49: talk with 溪石部落 — what they are building, their stock, friendship; gifts and trade.
var native_box: PanelContainer
func _native_menu() -> void:
	if is_instance_valid(native_box): native_box.queue_free()
	var v=state.planet.v2; var n=v.natives
	native_box=PanelContainer.new(); native_box.add_theme_stylebox_override("panel",UI.style(Color(0.08,0.07,0.05,0.95),14))
	native_box.position=viewport_box.position+Vector2(viewport_box.size.x*0.5-250,70); native_box.size=Vector2(500,10); add_child(native_box)
	var col=UI.column(native_box,8)
	col.add_child(UI.label("%s · 族长%s%s" % [n.rules.tribe.name,n.chief().get("name","")," · 🥉 青铜时代" if n.era=="bronze" else ""],20,Color("f0c890")))
	var left=n.missing(v.construction).size()
	col.add_child(UI.paragraph("友好度 %d%%（%s） · 库存 木料%d 石块%d 食物%d\n%s" % [roundi(n.friendship*100),n.mood(),int(n.stock.timber),int(n.stock.stone),int(n.stock.food),"两座小屋还差 %d 块，工匠%s正在%s" % [left,n._builder().name,n._builder().task] if left>0 else "两座小屋都已建好，部落在这里安了家"],14))
	if not n.news.is_empty(): col.add_child(UI.paragraph("近况：%s" % n.news.back(),13,UI.MUTED))
	var row=UI.row(col,6)
	row.add_child(UI.button("送食物 ×%d" % int(n.rules.gift.food_amount),func(): _native_act("v2_native_gift",{"kind":"food"})))
	row.add_child(UI.button("送木料 ×%d" % int(n.rules.gift.timber_amount),func(): _native_act("v2_native_gift",{"kind":"timber"})))
	# v0.54 Bronze: gifting malachite or copper items pushes the tribe toward the Bronze era.
	row.add_child(UI.button("送孔雀石（青铜扩散）",func(): _native_act("v2_native_gift",{"kind":"copper"})))
	col.add_child(UI.button("交易：木料×%d + 纤维×%d → 生肉×%d" % [int(n.rules.trade.give.timber),int(n.rules.trade.give.fiber),int(n.rules.trade.get.meat)],func(): _native_act("v2_native_trade",{})))
	col.add_child(UI.paragraph("友好度到 %d%% 时，族长每天回赠一只部落陶罐。拆他们的房子或对他们动手会让友好度下降。" % roundi(float(n.rules.friendship.gift_back)*100),12,UI.MUTED))
	col.add_child(UI.button("告辞",func(): native_box.queue_free()))

func _native_act(command: String,payload: Dictionary) -> void:
	message=state.planet.command(state,command,payload); _live(); _native_menu()

var cook_box: PanelContainer
func _cook_menu() -> void:
	if is_instance_valid(cook_box): cook_box.queue_free()
	var v=state.planet.v2; var C: Dictionary=v.field.rules.cooking
	cook_box=PanelContainer.new(); cook_box.add_theme_stylebox_override("panel",UI.style(Color(0.05,0.1,0.13,0.96),14))
	cook_box.position=viewport_box.position+Vector2(viewport_box.size.x*0.5-230,90); cook_box.size=Vector2(460,10); add_child(cook_box)
	var col=UI.column(cook_box,8)
	col.add_child(UI.label("篝火 · 烹饪",20,UI.GOLD))
	col.add_child(UI.paragraph("熟食回血；热食让身体暖和一阵（体感温度上升）。生肉来自打猎。",13))
	for id in C.recipes:
		var r: Dictionary=C.recipes[id]; var f: Dictionary=C.foods.get(id,{}); var parts=[]
		for k in r.inputs: parts.append("%s×%d（有%d）" % [v.field.rules.resources[k].name,int(r.inputs[k]),int(v.field.stock.get(k,0))])
		var b=UI.button("%s：%s → 回血%d · 暖身+%d°C %d秒" % [r.name,"＋".join(parts),int(f.get("heal",0)),int(f.get("warmth",0)),int(f.get("seconds",0))],func(): message=state.planet.command(state,"v2_cook",{"recipe":id}); _live(); _cook_menu())
		b.add_theme_font_size_override("font_size",13); col.add_child(b)
	col.add_child(UI.button("关闭",func(): cook_box.queue_free()))

func near_rover() -> bool:
	return view.rover_parked and not view.driving and view.walker.position.distance_to(view.rover.position)<=float(view.terrain.rules.rover.enter_distance)

func _toggle_rover() -> bool:
	var v=state.planet.v2
	if view.driving:
		if view.exit_rover():
			v.driving=false; v.rover_at={"x":view.rover.position.x,"z":view.rover.position.y,"heading":view.rover.heading}
			message="下车了 · 越野车停在原地，电量 %d%%" % roundi(100*float(view.rover.state.charge)/maxf(1.0,float(view.rover.state.cap)))
		else: message="四周没有下车的空地，往开阔处开一点"
		_live(); return true
	if near_rover():
		view.enter_rover(); v.driving=true
		message="上车 · WASD/摇杆驾驶 · Shift 加速 · 空格手刹 · 拖动看四周 · E 下车"
		_live(); return true
	return false

func _collect() -> void:
	if is_instance_valid(backpack) or state.planet.v2.combat.player_health<=0: return
	if near_ship(): message="登上星际飞船 · 打开星图"; _live(); voyage_requested.emit(); return
	if _toggle_plane(): return
	if _toggle_tbm(): return
	if _toggle_rover(): return
	# v0.41.2: E at a campfire opens the cooking menu.
	_update_actor()
	var aimed=state.planet.v2.Target.query(state.planet.v2)
	if aimed.get("kind","")=="campfire": _cook_menu(); return
	if aimed.get("entity",{}).get("type","")=="native": _native_menu(); return
	if aimed.get("kind","")=="farm_robot" and aimed.get("type","")=="block":
		var held_robot: Dictionary=state.planet.v2.inventory.entries(state).get(str(state.planet.v2.inventory.slots[state.planet.v2.inventory.selected]),{})
		if held_robot.get("action",{}).get("type","")!="remove": view.hands.swing(); _act("v2_robot",{"key":aimed.key}); return
	# v0.44: E on a door opens or shuts it (unless the hammer is out to take it down).
	if aimed.get("type","")=="block" and state.planet.v2.construction.is_door(state.planet.v2.construction.blocks.get(str(aimed.get("key","")),{})):
		var held: Dictionary=state.planet.v2.inventory.entries(state).get(str(state.planet.v2.inventory.slots[state.planet.v2.inventory.selected]),{})
		if held.get("action",{}).get("type","")!="remove":
			view.hands.swing(); _act("v2_door",{"key":aimed.key}); return
	_update_actor()
	var id=str(state.planet.v2.inventory.slots[state.planet.v2.inventory.selected])
	if id.is_empty(): message="这一格是空的，按 B 从背包装备物品。"; _live(); return
	_use_item(id)

func _use_item(id: String,alternate: String="") -> void:
	_update_actor()
	var items=state.planet.v2.inventory.entries(state)
	var item: Dictionary=items.get(id,{})
	if item.is_empty() or item.quantity==0: message="这件物品已用完，请补充库存或换一格。"; _live(); return
	var action: Dictionary=item.action
	if action.is_empty(): message="这件物品目前不能直接在星球使用。"; _live(); return
	var type=str(action.type)
	if type=="strike": _attack(); return
	var target=state.planet.v2.Target.query(state.planet.v2)
	if alternate=="pantry": _act("v2_field_pantry",{"resource":action.get("resource","")}); return
	if alternate=="eat" or type=="eat": _act("v2_eat",{"resource":action.get("resource","")}); return
	if target.get("type")=="depot" and type in ["collect","feed","sample","product","plant"]:
		view.hands.swing(); _act("v2_depot_stock"); return
	if alternate=="deploy" and type=="build": type="product"
	view.hands.set_tool(type+(":"+str(item.get("color","")) if type=="place_rock" else "")); view.hands.swing()
	if type in ["axe","dig","fill","place_rock","scan","tree_plant","mini_pack","mini_unfold"]:
		var command={"axe":"v2_chop","dig":"v2_dig","fill":"v2_fill","place_rock":"v2_place_rock","scan":"v2_scan","tree_plant":"v2_tree_plant","mini_pack":"v2_mini_pack","mini_unfold":"v2_mini_unfold"}
		_act(command[type],action)
	elif type in ["build","remove"]:
		_update_actor()
		_act("v2_dismantle" if type=="remove" else "v2_build",{"kind":action.get("kind","block"),"recipe":action.get("recipe","")})
	elif type=="plant":
		if view.first_person and alternate not in ["reed","region"]: _act("v2_field_plant")
		else: _act("v2_plant",{"crop":alternate if alternate=="reed" else "grain"})
	elif type=="organic_solution":
		_act("organic_apply",{"id":action.id,"token":state.planet.shipment_serial})
	elif type=="organic_sample" or (type=="sample" and target.get("kind")=="mixing_tank" and alternate!="deploy"):
		_act("organic_add",{"batch_id":action.batch_id,"token":state.planet.shipment_serial})
	elif type=="sample":
		var local=view.first_person and alternate!="deploy" and (target.get("kind") in ["planter","trough"] or target.get("type")=="tree")
		_act("v2_field_water" if local else "v2_deploy_sample",{"batch_id":action.batch_id,"region_id":selected_region,"token":state.planet.shipment_serial})
	elif type=="product":
		var product_id=-1
		for product in state.planet.products:
			if product.recipe==action.recipe: product_id=int(product.id); break
		if product_id<0: message="没有完整的成品包；先拆回构件并在搭建页整包收纳。"; _live(); return
		var local=view.first_person and alternate!="deploy" and (target.get("kind") in ["planter","trough"] or target.get("type")=="tree") and action.recipe=="standard_water_crate"
		_act("v2_field_water" if local else "v2_deploy_product",{"product_id":product_id,"region_id":selected_region,"token":state.planet.shipment_serial})
	elif type=="collect":
		if target.get("kind")=="mixing_tank":
			show_details=true; _exploration_layout(); _tab("organics"); _live()
		elif target.has("entity") or target.get("kind") in ["trough","feeder"]:
			show_details=true; _exploration_layout(); _tab("ranch"); message=preload("res://scripts/river_ranch_panel.gd").describe(state.planet.v2,target).split("\n")[0]; _live()
		# Nothing aimed: the hand forages nearby ripe wild plants (the hotbar rework left E without this route).
		elif target.is_empty() and view.first_person: _collect_wild()
		else: _act("v2_field_collect")
	elif type=="feed": _act("v2_field_feed",{"resource":action.resource})
	if not target.is_empty(): view.field_view.feedback(target.point)
	if is_instance_valid(backpack): backpack.feedback.text=message; backpack.refresh()

func _collect_wild() -> void:
	if not view.first_person:
		message="先进入第一人称，走近成熟的野生植被。"; _live(); return
	var at: Vector2=view.walker.position
	_act("v2_collect_wild",{"x":at.x,"z":at.y})

func _tool(mode: String) -> void:
	var id="tool:remove" if mode=="remove" else "tool:collect"
	if mode in ["block","solar"]:
		var c=state.planet.v2.construction
		for recipe in c.rules.recipes:
			if c.rules.recipes[recipe].kind==mode and c.available(mode,state.planet.products,recipe)>0:
				id="recipe:"+str(recipe); break
		if not id.begins_with("recipe:"): _open_backpack(); return
	_equip_item(id)

func _equip_item(id: String) -> void:
	var inventory=state.planet.v2.inventory; var items=inventory.entries(state)
	var index=inventory.slots.find(id)
	if index<0:
		index=inventory.slots.find("")
		if index<0: index=inventory.selected
		inventory.bind_slot(index,id,items)
	_close_backpack(); _select_slot(index)
	if not view.first_person: _enter()
	show_details=false; explore_input.clear_input(); _exploration_layout(); explore_input.grab_focus(); _aim()

func _select_slot(index: int) -> void:
	state.planet.v2.inventory.selected=clampi(index,0,8)
	_refresh_hotbar()
	if not is_instance_valid(backpack): explore_input.grab_focus()
	_aim()

func _refresh_hotbar() -> void:
	var inventory=state.planet.v2.inventory; inventory_items=inventory.entries(state)
	for i in range(hotbar_slots.size()):
		var id=str(inventory.slots[i])
		hotbar_slots[i].set_item({} if id.is_empty() else inventory_items.get(id,inventory.missing(id)),i+1,i==inventory.selected)
	var selected: Dictionary=inventory_items.get(inventory.slots[inventory.selected],{})
	var action: Dictionary=selected.get("action",{})
	build_mode=str(action.get("kind","")) if action.get("type")=="build" else ("remove" if action.get("type")=="remove" else "observe")

func _open_backpack() -> void:
	if is_instance_valid(backpack): return
	explore_input.set_walking(false); explore_input.hide(); view.construction_view.ghost.hide()
	backpack=InventoryPanel.new(); add_child(backpack); backpack.setup(state)
	backpack.dismissed.connect(_close_backpack)
	backpack.changed.connect(_refresh_hotbar)
	backpack.use_requested.connect(func(id,alternate):
		var item=state.planet.v2.inventory.entries(state).get(id,{})
		if alternate.is_empty() and not item.get("action",{}).is_empty(): _equip_item(id)
		else: _use_item(id,alternate))
	backpack.workshop_requested.connect(func(): workshop_requested.emit(""))

func _close_backpack() -> void:
	if not is_instance_valid(backpack): return
	backpack.queue_free(); backpack=null
	explore_input.show(); explore_input.set_walking(view.first_person); _refresh_hotbar()

func _open_building() -> void:
	show_details=true; explore_input.clear_input(); _exploration_layout(); _tab("build")

func _update_actor() -> void:
	var v=state.planet.v2
	if not view.first_person: v.actor={}; return
	v.actor={"eye":view.walker.eye(),"direction":-view.camera.global_basis.z,"feet":Vector3(view.walker.position.x,view.walker.feet_y,view.walker.position.y),"entity_hitboxes":view.entity_hitboxes()}

func _aim() -> void:
	_update_actor()
	if not view.first_person or is_instance_valid(backpack): return
	# v0.45: while boring the dashboard takes the hotbar's place.
	play_bar.visible=not view.boring and not view.flying; aim_label.position.y=520.0 if view.boring or view.flying else 606.0
	if view.boring: aim_label.text=_tbm_text(); view.construction_view.ghost.hide(); return
	if view.flying: play_bar.visible=false; aim_label.position.y=520.0; aim_label.text=_plane_text(); view.construction_view.ghost.hide(); return
	var v=state.planet.v2
	var id=str(v.inventory.slots[v.inventory.selected]); var item: Dictionary=inventory_items.get(id,{})
	var action: Dictionary=item.get("action",{})
	var target=v.Target.query(v)
	encounter_hud.target=target
	view.hands.set_tool(str(action.get("type","collect"))+(":"+str(item.get("color","")) if action.get("type")=="place_rock" else ""))
	aim_label.text=view.construction_view.preview(v.construction,v.actor,build_mode,state.planet.products,str(action.get("recipe","")))
	if build_mode=="observe": aim_label.text=v.Target.prompt(v,target)
	if build_mode=="observe" and action.get("type")!="collect":
		if id.is_empty(): aim_label.text="空格 · B 打开背包"
		elif action.get("type") in ["sample","product"]:
			var water=action.get("reference")=="water" or action.get("recipe")=="standard_water_crate"
			aim_label.text=str(item.get("name","已用完"))+ (" · E 浇水" if water and (target.get("kind") in ["planter","trough"] or target.get("type")=="tree") else (" · 这里需要水" if (target.get("kind") in ["planter","trough"] or target.get("type")=="tree") else " · E 使用于"+str(v.region().name)))
		elif action.get("type")=="plant": aim_label.text=v.Target.prompt(v,target)+" · E 播种"
	if action.get("type")=="mini_pack":
		var found: Dictionary=preload("res://scripts/river_miniatures.gd").survey(v.construction,target)
		view.construction_view.preview_box(found)
		aim_label.text=found.error if not found.error.is_empty() else "微缩器 · 这座作品%d块 · E 装进微缩盒，回浮岛「河湾作品」里摆放" % found.chosen.size()
	elif action.get("type")=="mini_unfold":
		# v0.37.1: a ghost shows where the boxed build will land (green) or why it can't (red).
		var found: Dictionary=preload("res://scripts/river_miniatures.gd").plan(v.construction,str(action.get("id","")),v.actor)
		view.construction_view.preview_cells(found)
		aim_label.text=found.error if not found.error.is_empty() else "%s · 绿框是展开位置 · E 展开" % str(item.get("name","作品"))
	aim_label.text=InteractionHelp.prompt(v,item,target,aim_label.text)
	action_button.text=InteractionHelp.button_text(action,target)
	if view.driving:
		var r=view.rover
		aim_label.text="越野车 · %d km/h · 电量 %d%% · 续航 %.1f km%s · E 下车" % [roundi(absf(r.speed)*3.6),roundi(100*float(r.state.charge)/maxf(1.0,float(r.state.cap))),r.range_km()," · 没电了，只能慢慢挪：回浮岛或停在太阳能方块旁充电" if float(r.state.charge)<=0.0 else (" · 撞到了" if r.bumped<0.6 else "")]
		action_button.text="下车 E"
	elif near_rover():
		aim_label.text="星球越野车 · 电量 %d%% · E 上车" % roundi(100*float(view.rover.state.charge)/maxf(1.0,float(view.rover.state.cap)))
		action_button.text="上车 E"
	attack_button.text="收拳中…" if v.combat.attack_left>0 else "攻击 F"
	attack_button.disabled=v.combat.player_health<=0 or v.combat.attack_left>0

func _tab(id: String) -> void:
	if id=="bag": _open_backpack(); return
	section=id; _redraw(true)

func _act(action: String,payload: Dictionary={}) -> void:
	if _in_wilderness() and action in ["v2_plant","v2_harvest","v2_pen","v2_deploy_sample","v2_deploy_product"]:
		message="远郊当前开放探索与野生采集。播种、设施和材料试验请返回起始河湾。"; _live(); return
	message=state.planet.command(state,action,payload); _feel(action); acted.emit(message); _refresh_hotbar(); _redraw(); _sync()

## Each tool gets its own sound; impacts nudge the first-person camera. Failures only buzz.
const ACTION_SOUNDS={"v2_chop":["chop",1.0],"v2_dig":["dig",1.0],"v2_fill":["dig",0.8],"v2_place_rock":["build",0.9],"v2_scan":["whoosh",1.4],"v2_strike":["hit",1.0],
	"v2_build":["build",1.0],"v2_dismantle":["build",0.8],"v2_tree_plant":["pop",0.9],"v2_field_plant":["pop",1.0],"v2_plant":["pop",1.0],
	"v2_field_collect":["pop",1.25],"v2_collect_wild":["pop",1.25],"v2_harvest":["harvest",1.0],"v2_field_water":["whoosh",1.2],
	"v2_field_feed":["pop",1.1],"v2_mini_pack":["close",1.0],"v2_mini_unfold":["open",1.0],"v2_deploy_product":["build",1.1]}
const KICK_ACTIONS={"v2_chop":1.0,"v2_dig":0.8,"v2_fill":0.6,"v2_place_rock":0.6,"v2_strike":1.2,"v2_build":0.5,"v2_dismantle":0.5}

func _feel(action: String) -> void:
	var sfx=get_node_or_null("/root/Sfx")
	if preload("res://scripts/island_feedback.gd").looks_like_failure(message):
		if sfx: sfx.play("error")
		return
	if sfx and ACTION_SOUNDS.has(action): sfx.play(ACTION_SOUNDS[action][0],ACTION_SOUNDS[action][1])
	if view and view.first_person and KICK_ACTIONS.has(action): view.kick(KICK_ACTIONS[action])

func _next_goal() -> String:
	var v=state.planet.v2; var s=v.settlement
	var weather: String=v.incidents.status_line(v)
	if not weather.is_empty(): return weather+"\n打开「时代」页看怎么准备"
	for row in s.checklist(v.world,v.construction):
		if row.complete: continue
		return "时代目标 · %s %s/%s
%s" % [row.label,_amount(row.value),_amount(row.required),str(row.hint).split("；")[0]]
	if s.era<s.last_era(): return "时代目标 · 条件已满足！打开「时代」页建立"+str(s.rules.eras[s.era+1].name)
	return ""

func _amount(x: float) -> String:
	return str(int(round(x))) if absf(x-round(x))<0.05 else "%.1f" % x

func _card(title: String) -> VBoxContainer:
	var p=PanelContainer.new(); body.add_child(p); var col=UI.column(p,7); col.add_child(UI.paragraph(title,19,UI.MINT)); return col

func _key() -> String:
	var v=state.planet.v2; var r=v.world.regions[selected_region]; var stock=[]
	for b in state.storage.batches: stock.append([b.id,b.quantity])
	var life=[]; var crops=[]
	for a in r.animals: life.append(a.id)
	for c in r.crops: crops.append([c.crop,c.ready])
	return str([selected_region,section,_in_wilderness(),v.population.enabled,stock,state.planet.products,life,crops,r.buildings,r.enclosed,v.world.events.size(),v.world.events[0],v.world.seeds,v.world.food,v.construction.revision,v.field.revision,v.ranch.revision,v.organics.revision,v.journey.revision,v.nature.discovered.size(),v.settlement.era,v.settlement.people.map(func(p): return [p.id,p.get("generation",0)]),v.incidents.revision,v.specimens.revision])

func _redraw(reset_scroll: bool=false) -> void:
	if body==null: return
	scroll_memory.refresh(scroll,reset_scroll)
	UI.clear(body); widgets={}; fingerprint=_key()
	match section:
		"observe": _observation()
		"bag": _open_backpack()
		"explore": _journey()
		"journal": _journal()
		"build": _building()
		"organics": preload("res://scripts/river_organic_panel.gd").build(self)
		"ranch": preload("res://scripts/river_ranch_panel.gd").build(self)
		"era": _era()
	_live()

func _observation() -> void:
	if _in_wilderness():
		var nearby=_card("远郊 · 野生栖地")
		widgets.explore=UI.paragraph("",16); nearby.add_child(widgets.explore)
		nearby.add_child(UI.button("采集附近成熟植被",_collect_wild,true))
		nearby.add_child(UI.button("远行与营地",_open_journey))
		nearby.add_child(UI.paragraph("远郊可砍树、挖填、搭建、放种植箱并配料。区域级投放与时代聚落仍在起始河湾；M可以保存路标。",15))
		return
	var v=state.planet.v2; var r=v.region()
	var life=_card("这片土地上的生命")
	widgets.environment=UI.paragraph("",16,UI.TEXT); life.add_child(widgets.environment)
	widgets.herd=UI.paragraph("",16,UI.GOLD); life.add_child(widgets.herd)
	var crops=_card("种植 · 收获 · 留种")
	widgets.crops=UI.paragraph("",16,UI.TEXT); crops.add_child(widgets.crops)
	var row=UI.row(crops,6)
	row.add_child(UI.button("播谷物 · 1种",func(): _act("v2_plant",{"crop":"grain"})))
	row.add_child(UI.button("播芦苇 · 1种",func(): _act("v2_plant",{"crop":"reed"})))
	crops.add_child(UI.button("收获成熟作物",func(): _act("v2_harvest")))
	var pen=_card("圈养与设施")
	pen.add_child(UI.paragraph("从浮岛带来结构构件包搭围栏。关门后，小兽吃背包里的口粮；开门后恢复自然觅食。遮荫棚保水，但会减慢作物生长。",15))
	pen.add_child(UI.button("打开围栏" if r.enclosed else "关闭围栏",func(): _act("v2_pen")))
	pen.add_child(UI.button("从背包带材料过来",func(): _tab("bag"),true))
	var family=_card("动物个体与后代")
	widgets.animals=UI.paragraph("",14,UI.TEXT); family.add_child(widgets.animals)
	body.add_child(UI.paragraph("教学物种与压缩时间。溶氧等为游戏指标，不能换算成真实浓度。后代继承性状，当前尚无新物种分化。",13,UI.MUTED))

func _journey() -> void:
	var destinations=_card("沿河而行")
	destinations.add_child(UI.button("打开世界地图 · 路线 / 路标 / 建筑",_open_world_map,true))
	destinations.add_child(UI.paragraph("星球东西环绕一圈约16公里，向东一直走会从西边回来；南北尽头是两极冰盖。大洋要等以后的船或飞机才能跨越。附近地形随行加载，砍树、挖土与建筑都会保留。",15))
	destinations.add_child(UI.button("回到起始河湾  ↗",_travel.bind("home")))
	destinations.add_child(UI.paragraph("没有固定的远方地点：走到哪里，就用「记住当前位置」留下自己的路标。",14,UI.MUTED))
	var marks=_card("我的路标 · %d / %d" % [state.planet.v2.journey.points.size(),view.terrain.rules.max_waypoints])
	marks.add_child(UI.button("记住当前位置",func(): _update_actor(); _act("v2_waypoint_add"),true))
	for id in state.planet.v2.journey.points:
		var point=state.planet.v2.journey.points[id]; var row=UI.row(marks,8)
		row.add_child(UI.button("%s · %.0f, %.0f米" % [point.name,point.x,point.z],_travel_waypoint.bind(id)))
		row.add_child(UI.button("移除",func(): _act("v2_waypoint_remove",{"id":id})))
	marks.add_child(UI.paragraph("M打开远行；路标会随存档保留。移除只删标记，不回收建筑。",14))
	var life=_card("附近的生命")
	widgets.explore=UI.paragraph("",15); life.add_child(widgets.explore)
	life.add_child(UI.button("采集附近成熟植被",_collect_wild,true))
	var renewal=_card("世界会慢慢补充")
	renewal.add_child(UI.paragraph("草木等待再生，小兽从远处迁入；食物充足的营地会接待新旅人。迁入与繁殖有容量限制，关着的围栏不接纳外来动物。",15))
	renewal.add_child(UI.button("自然补充：开启" if state.planet.v2.population.enabled else "自然补充：关闭",func(): _act("v2_renewal",{"enabled":not state.planet.v2.population.enabled})))
	renewal.add_child(UI.paragraph("当前旅人演示进营、采集、休息和离营。远处未观察的栖地暂停计时；时代聚落与人物性格将在后续接入。",13,UI.MUTED))

func _building() -> void:
	var c=state.planet.v2.construction
	var start=_card("从一把枯枝，到第一块菜地")
	start.add_child(UI.paragraph("① 用斧头砍树得木料、纤维和野果，用采掘镐挖岩石得石料。\n② 在浮岛连通工艺车间、安排工程师，加工墙、屋顶和种植箱。\n③ 把成品放入快捷栏，在星球搭建。\n④ 装备种子瞄准箱子播种，用水样或标准水箱浇这一箱；成熟后手套收获。",15))
	start.add_child(UI.button("前往采集坡",_travel.bind("homestead"),true))
	for recipe in state.planet.v2.field.rules.recipes:
		if state.planet.v2.field.rules.recipes[recipe].has("material"): continue
		start.add_child(UI.button("加工 · "+str(state.planet.recipe(recipe).name),func(): workshop_requested.emit(recipe)))
	# v0.44: twenty building parts — five shapes in four materials.
	var mats=_card("建材 · 木 / 石 / 塑料 / 金属")
	mats.add_child(UI.paragraph("板（半格，叠成台阶）、砖墙、门（两格高，E 开关）、窗（玻璃透光）、坡屋顶（能走上去）。木和石用星球采集的木料、石料；塑料要星锻岛的聚乙烯粒料，金属要碳钢锭，每扇窗还要一块钠钙玻璃板。门、窗和坡顶朝着你放置时面对的方向。",14))
	var grid=GridContainer.new(); grid.columns=4; grid.add_theme_constant_override("h_separation",4); grid.add_theme_constant_override("v_separation",4); mats.add_child(grid)
	for shape in state.planet.v2.construction.rules.shapes:
		for material in state.planet.v2.construction.rules.materials:
			var rid="field_%s_%s" % [shape,material]
			var b=UI.button(str(state.planet.v2.construction.rules.kinds["%s_%s" % [shape,material]].name),func(): workshop_requested.emit(rid))
			b.add_theme_font_size_override("font_size",13); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_child(b)
	var card=_card("把背包材料搭成家")
	card.add_child(UI.paragraph("一包工坊结构构件可搭8块木构。打开背包，把构件装备到快捷栏；瞄准近处地面或方块表面，绿色预览后单击或按E放置。触屏点底部放置按钮。能搭台阶、墙和屋顶，也能安装车间制造的光伏组件。",15))
	card.add_child(UI.button("打开背包装备构件",_open_backpack,true))
	card.add_child(UI.button("去车间制作木构件",func(): workshop_requested.emit("frame_bundle")))
	card.add_child(UI.button("去车间制作光伏",func(): workshop_requested.emit("modern_silicon")))
	card.add_child(UI.button("拆回自己的构件",_tool.bind("remove")))
	var returns=_card("施工材料包 · 可带回浮岛")
	for id in c.sources:
		var source=c.sources[id]; var total=int(c.rules.recipes[source.product.recipe].units)
		returns.add_child(UI.paragraph("%s #%s · 余%d/%d\n来源 %s" % [state.planet.recipe(source.product.recipe).name,id,source.remaining,total,source.product.source_batch],14))
		var b=UI.button("整包收入工具箱",_act.bind("v2_repack",{"source_id":id})); b.disabled=source.remaining!=total; returns.add_child(b)
	returns.add_child(UI.paragraph("拆除退回原材料；先拆边缘，避免留下悬空建筑。树木用林业斧砍伐，地面用地形铲挖掘，土方可填高。",13))

func _era() -> void:
	var s=state.planet.v2.settlement
	_weather_card()
	var card=_card(s.title())
	card.add_child(UI.paragraph(s.rules.eras[s.era].story,16))
	widgets.era=UI.paragraph("",15,UI.GOLD); card.add_child(widgets.era)
	# v0.33.1: one row per requirement, each with its progress and a button that does or starts it.
	for row in s.checklist(state.planet.v2.world,state.planet.v2.construction):
		var box=VBoxContainer.new(); box.add_theme_constant_override("separation",3); card.add_child(box)
		var title=UI.label("",16,UI.TEXT); box.add_child(title)
		var bar=ProgressBar.new(); bar.show_percentage=false; bar.custom_minimum_size=Vector2(0,8); bar.max_value=1.0; box.add_child(bar)
		box.add_child(UI.paragraph(str(row.hint),13))
		var buttons=UI.row(box,6)
		for b in _era_actions(str(row.id)): buttons.add_child(UI.button(b[0],b[1]))
		widgets["era_row:"+str(row.id)]=[title,bar]
	if s.era==0: card.add_child(UI.paragraph("住处是你实际搭的建筑，不是要找一个叫‘屋檐’的物品。用木构搭立柱，再横接屋顶；屋顶正下方至少留2格空地，每格都能站直、不被方块堵住。屋顶旁露天的地面不算住处。",14))
	if s.era<s.last_era():
		var promote=UI.button("建立"+str(s.rules.eras[s.era+1].name),func(): _act("v2_next_era"),true); card.add_child(promote); widgets.era_advance=promote
	card.add_child(UI.button("打开村庄 · 公共仓库补给",func(): _tab("ranch")))
	card.add_child(UI.button("去车间制作屋顶",func(): workshop_requested.emit("field_roof")))
	if s.era==1: card.add_child(UI.button("去车间制作光伏",func(): workshop_requested.emit("modern_silicon")))
	if s.era>0 and s.people.size()<2:
		var invite=UI.button("邀请新旅人 · 补充空缺岗位",func(): _act("v2_recruit_resident")); card.add_child(invite); widgets.era_recruit=invite
		card.add_child(UI.paragraph("准备可住空间、公共仓库2份食物与1份水样；消耗为新居民的安家补给。",14))
	card.add_child(UI.button("回草甸营地",func(): _travel("home"); _tool("observe")))
	widgets.residents=UI.paragraph("",15); card.add_child(widgets.residents)
	card.add_child(UI.paragraph("这是同一世界的游戏时代章节，保留动物个体和你的建筑。史前物种、完整工业时代与未来科技仍待扩展。",13,UI.MUTED))

## v0.36: the current or announced incident, how prepared the camp is, and what to build.
func _weather_card() -> void:
	var v=state.planet.v2; var inc=v.incidents
	var kind=str(inc.active.get("kind",inc.pending.get("kind","")))
	var card=_card("天气与灾害" if kind=="" else "⚠ "+str(inc.kind_info(kind).name))
	if kind=="":
		card.add_child(UI.paragraph("春夏有暴风雨和河水上涨，夏秋可能干旱，冬天有寒潮暴雪；每次都会提前一天预警（年鉴和左上角）。准备得越好损失越小，扛住后有岛主经验。现在%s的时代可能遇到：%s。" % [s_title(v),"、".join(v.incident_kinds().map(func(k): return inc.kind_info(k).name))],14))
	else:
		card.add_child(UI.label(inc.status_line(v),16,UI.GOLD))
		card.add_child(UI.paragraph("怎么准备："+str(inc.kind_info(kind).prepare),14))
	var rows=[["暴风雨 · 营地屋顶下净空","storm"],["河水上涨 · 沿河堤坝构件","flood"],["干旱 · 洒水器 + 灌溉管","drought"],["寒潮 · 篝火 + 屋顶下空地","blizzard"]]
	for row in rows:
		var p=inc.preparation(v,str(row[1]))
		var line=UI.row(card,8)
		line.add_child(UI.label("%s %d%%" % [row[0],roundi(p*100)],14,UI.MINT if p>=0.5 else UI.TEXT))
	card.add_child(UI.button("铺设灌溉管 %d/%d · 星锻岛 PVC×%d" % [inc.pipes,int(inc.rules.pipe.max),int(inc.rules.pipe.pvc)],func(): message=state.lay_pipe(); _redraw()))
	card.add_child(UI.button("去车间做屋顶或堤坝木墙",func(): workshop_requested.emit("field_roof")))
	card.add_child(UI.button("去车间做篝火（3木料 + 2石料）",func(): workshop_requested.emit("field_campfire")))
	if not inc.history.is_empty(): card.add_child(UI.paragraph("上一次："+str(inc.history[0].text),13))
	# v0.39 time gate status.
	var gate=_card("时间之门 · %s" % str(v.epoch_info().name))
	if state.planet.gate_ready():
		gate.add_child(UI.paragraph("回浮岛后走上彩虹光桥，可以在「当代」和「冰河期（约两万年前）」之间穿越。背包、种子、矿物和标本跟着你走；建筑和营地留在各自的时代。",14))
	else: gate.add_child(UI.paragraph(state.planet.gate_hint(),14,UI.GOLD))
	if v.epoch=="ice": gate.add_child(UI.paragraph("冰河期：冬天体感低于 0 °C 会持续掉血。生篝火、躲到屋顶下，或在星锻岛做保温服。猛犸象和披毛犀会反击，用分析仪记录它们的标本。",14,Color("bfe6ff")))

func s_title(v) -> String:
	return str(v.settlement.title())

## Buttons for one era requirement row: the shortest route to actually doing it.
func _era_actions(id: String) -> Array:
	var era=int(state.planet.v2.settlement.era)
	var store=["存入公共仓库",func(): _act("v2_depot_stock")]
	match id:
		"blocks": return [["去车间做木墙",func(): workshop_requested.emit("field_wall")],["背包装备构件",_open_backpack]]
		"shelter": return [["去车间做屋顶",func(): workshop_requested.emit("field_roof")],["回营地",func(): _travel("home"); _tool("observe")]]
		"harvests": return [["去车间做种植箱",func(): workshop_requested.emit("field_planter")],["去采集坡",_travel.bind("homestead")]]
		"food": return [store,["去采集坡",_travel.bind("homestead")]]
		"meals": return [store]
		"water": return [store] if era>=1 else [["倒1份水样进草甸",_water_meadow]]
		"solar": return [["去车间做光伏",func(): workshop_requested.emit("modern_silicon")],["背包装备光伏",_open_backpack]]
	return []

func _water_meadow() -> void:
	for batch in state.storage.batches:
		if batch.quantity>0 and state.sandbox_reference(batch.work).get("reference_id")=="water":
			_act("v2_deploy_sample",{"batch_id":batch.id,"region_id":"meadow","token":state.planet.shipment_serial}); return
	message="背包里没有水样。回浮岛让反应釜产出水（H₂O），收获后就会出现在背包。"; _live()

func _nearby_text() -> String:
	var at=_observer_position(); var v=state.planet.v2; var s=v.population.nearest(at)
	if s.is_empty(): return "这里暂未发现栖地。向林间营地走走。"
	var distance=at.distance_to(Vector2(s.x,s.z))
	var count=v.world.regions[s.id].animals.size() if s.home else s.animals.size()
	var mature=s.flora>=float(v.population.rules.harvest_maturity); var radius=float(v.population.rules.harvest_radius)
	var text="距栖地中心 %.0f米 · %d只动物\n野生植被 %.0f%% · %s\n" % [distance,count,s.flora*100,"可以采集" if mature and distance<=radius else ("走近%.0f米以内可采" % radius if mature else "等待自然再生")]
	for visitor in s.visitors: text+="%s #%d · %s\n" % [visitor.name,visitor.id,visitor.state]
	if s.camp and s.visitors.is_empty(): text+="营地正在等待下一批旅人。"
	return text

func _journal() -> void:
	var v=state.planet.v2; var Geology=v.nature.Geology; var all: Dictionary=Geology.rules().materials
	var book=v.specimens; var all_species: Dictionary=book.rules.species
	var specimens=_card("标本图鉴 · %d / %d" % [book.count(),all_species.size()])
	specimens.add_child(UI.paragraph("手持分析仪，瞄准动物或树木按 E。同一物种在新的群系里再扫一次，会记下新的栖地。卡片写着它在真实世界的原型。",14,UI.GOLD))
	for id in all_species:
		var sp: Dictionary=all_species[id]
		if book.found.has(id):
			specimens.add_child(UI.paragraph("◆ %s · %s · 原型 %s\n%s\n见于：%s" % [sp.name,sp.group,sp.prototype,sp.facts,"、".join(book.found[id]).replace("、、","、")],14,UI.TEXT))
		else: specimens.add_child(UI.paragraph("◇ ？？？ · %s" % sp.group,14))
	if not v.incidents.history.is_empty():
		var storms=_card("灾害记录 · 稳住了 %d 次" % v.incidents.weathered)
		for h in v.incidents.history: storms.add_child(UI.paragraph("第%d天  ·  %s" % [int(h.day)+1,h.text],14,UI.TEXT))
	var codex=_card("矿物图鉴 · %d / %d" % [v.nature.discovered.size(),all.size()])
	codex.add_child(UI.paragraph("用采掘镐向下挖，或用分析仪扫描岩壁，第一次遇到的岩土和矿物会记在这里。成分来自真实矿物学数据。",14,UI.GOLD))
	for id in all:
		var m: Dictionary=all[id]
		if v.nature.discovered.has(id):
			var have=int(v.nature.minerals.get(id,0))
			codex.add_child(UI.paragraph("◆ %s  %s%s" % [m.name,m.formula,"  · 背包 %d" % have if have>0 else ""],15,UI.TEXT))
		else: codex.add_child(UI.paragraph("◇ ？？？ · %s" % m.layer,14))
	var events=_card("河湾年鉴")
	for e in v.world.events:
		events.add_child(UI.paragraph("第%d天  ·  %s" % [int(float(e.time)/float(v.rules.clock.day_seconds))+1,e.text],15,UI.TEXT))
	var deliveries=_card("材料足迹 · 最近8次")
	var receipts=v.world.receipts.duplicate(); receipts.reverse()
	for receipt in receipts.slice(0,8):
		var origin=str(receipt.get("batch_id",receipt.get("product",{}).get("source_batch","")))
		deliveries.add_child(UI.paragraph("%s → %s\n来源批次 %s" % [v.rules.products[receipt.use].name,v.world.regions[receipt.region].name,origin],14))
	if receipts.is_empty(): deliveries.add_child(UI.paragraph("投放第一份材料后，会在这里留下足迹。",15))

func _live() -> void:
	var v=state.planet.v2; var r=v.region()
	time_label.text=v.time_label()+" · %dx" % int(v.world.speed)
	pause_button.text="继续" if v.world.paused else "暂停"
	enter_button.text="返回上帝视角" if view.first_person else "第一人称进入"
	var at=view.last_position(); var place=Shape.coordinates(at)
	var biome=v.environment.biome_name(v.environment.biome_at(at))
	world_title.text=str(r.name)+" · 徒步探索" if view.first_person else "地球仪 · 上次所在："+place
	info.text=str(r.name)+"\n"+str(r.terrain)
	where_label.text=("当前位置" if view.first_person else "上次所在")+"：%s · %s" % [biome,place]
	if _in_wilderness():
		world_title.text="%s · %s" % [biome,place]
		info.text="远郊探索\n%s · %s" % [biome,place]
		if not Shape.on_surface(at,140.0):
			world_title.text="极地边缘 · 再往前是无法通行的冰盖，可用M返回路标"
	counters.text="种子 %d · 口粮 %d\n1分钟=1天 · 每4天换季" % [v.world.seeds,v.world.food]
	if not message.is_empty(): status.text=message
	goal_label.visible=view.first_person and not show_details
	if goal_label.visible: goal_label.text=_next_goal()
	for key in regions: regions[key].modulate=UI.MINT if key==selected_region and not _in_wilderness() else Color.WHITE
	for key in tabs: tabs[key].modulate=UI.MINT if key==section else Color.WHITE
	if widgets.has("explore"): widgets.explore.text=_nearby_text()
	if widgets.has("era"):
		if widgets.has("era_recruit"): widgets.era_recruit.disabled=not v.settlement.recruit_error(v.construction).is_empty()
		if widgets.has("era_advance"): widgets.era_advance.disabled=not v.settlement.ready(v.world,v.construction)
		var rows=v.settlement.checklist(v.world,v.construction); var done=0; var todo=[]
		for row in rows:
			if row.complete: done+=1
			else: todo.append(str(row.label))
			var w=widgets.get("era_row:"+str(row.id),[])
			if w.is_empty(): continue
			w[0].text=("✓ " if row.complete else "○ ")+str(row.label)+" · %s / %s" % [_amount(row.value),_amount(row.required)]
			w[0].modulate=UI.MINT if row.complete else Color.WHITE
			w[1].value=clampf(row.value/maxf(row.required,0.001),0,1)
		widgets.era.text=("下一时代：完成 %d / %d 项" % [done,rows.size()]+("
待完成："+"、".join(todo) if not todo.is_empty() else "") if not rows.is_empty() else v.settlement.requirements(v.world,v.construction))+"\n太阳能服务点 %.1f/60 · %s" % [v.settlement.energy,"灌溉运行中" if v.settlement.irrigation else "待机"]
		var residents=""
		for p in v.settlement.people: residents+="%s · %s · 健康%.0f%% / 饥饿%.0f%%\n" % [p.name,p.task,p.health*100,p.hunger*100]
		widgets.residents.text=residents if not residents.is_empty() else "满足住处、作物与水源条件后，旅人愿意定居。"
	for p in v.settlement.people:
		var worker="worker:"+str(int(p.id))
		if widgets.has(worker): widgets[worker].text=p.name+" · "+v.ranch.role(int(p.id))+"\n"+v.ranch.job_label(int(p.id))+" · 饥饿%.0f%%" % (p.hunger*100)
	if section!="observe" or not widgets.has("environment"): return
	widgets.environment.text="水位 %.0f%% · 土壤湿度 %.0f%%\n溶氧 %.0f%% · 温度 %.1f°C\n土壤营养 %.0f%% · 颗粒负担 %.0f%%" % [r.water*100,r.moisture*100,r.oxygen*100,r.temperature,r.nutrients*100,r.pollution*100]
	widgets.environment.text+="
地球：%s · %s" % [v.environment.biome_name(v.environment.biome_at(_observer_position())),v.environment.atmosphere_text()]
	var generation=0
	for a in r.animals: generation=maxi(generation,int(a.generation))
	widgets.herd.text="%d只动物 · 谱系最高第%d代" % [r.animals.size(),generation+1]
	var text=""
	for plot in r.crops:
		var c=v.crop(plot.crop); var reason="成熟，等待收获" if plot.ready else ("等水分 / 温度 / 营养" if r.moisture<c.moisture_min or r.moisture>c.moisture_max or r.temperature<c.temperature_min or r.temperature>c.temperature_max or r.nutrients<=0.08 else "正在生长")
		text+="%s  %.0f%% · %s\n" % [c.name,plot.growth*100,reason]
	widgets.crops.text=text if not text.is_empty() else "空地上可以播下种子。"
	text=""
	for a in r.animals.slice(0,8):
		text+="#%d %s · 第%d代 · %s\n健康%.0f%% / 饥饿%.0f%% / 需氧阈值%.0f%%\n" % [a.id,v.species(a.species).name,a.generation+1,a.state,a.health*100,a.hunger*100,a.tolerance*100]
	widgets.animals.text=text if not text.is_empty() else "这里暂时没有动物。"

func _sync() -> void:
	if view==null: return
	var v=state.planet.v2; var at=_observer_position()
	# v0.47: high in the air nothing below is "observed" (no wildlife sites or camps spawn on the way).
	var aloft=view.flying and view.plane.height_above_ground()>25.0
	if not aloft: v.population.observe(at)
	if not view.first_person: view.selected=selected_region
	view.ranch=v.ranch
	view.sync(v.world,v.season())
	view.life_view.ranch=v.ranch
	if not aloft: view.life_view.sync(v.population,at,v.world.paused)
	view.walker.barriers.append_array(view.life_view.barriers)
	v.construction.obstacles=view.walker.barriers.duplicate()
	view.walker.construction=v.construction
	view.construction_view.sync(v.construction,at)
	view.field_view.sync(v.field,v.construction,at,int(v.world.elapsed),v.organics)
	view.organic_view.sync(v.organics,v.construction,at)
	if section=="organics": preload("res://scripts/river_organic_panel.gd").live(self)
	view.settlement_view.ranch=v.ranch
	view.settlement_view.construction=v.construction
	view.settlement_view.paused=v.world.paused
	view.settlement_view.depot_position=v.ranch.depot_at(v)
	view.settlement_view.sync(v.settlement,at)
	view.native_view.paused=v.world.paused
	view.native_view.sync(v.natives,at)
	view.life_view.era=v.settlement.era
	view.journey_view.sync(v.journey,at,not view.first_person)
	view.weather=v.incidents.sky(v)
	view.lamp_spec=state.industry.lamp_spec()
	_sync_rover()
	_sync_tbm()
	_sync_plane()
	_sync_ship()
	view.remember_position()
	_live(); _aim()

func _process(dt: float) -> void:
	if state==null or closing: return
	var v=state.planet.v2
	if view.first_person and not is_instance_valid(backpack):
		_update_actor()
		if v.journey.track(view.walker.position): view.journey_view.sync(v.journey,view.walker.position,false)
		v.combat.tick(minf(dt,0.1),v,not v.world.paused)
		if v.combat.player_health<=0: explore_input.clear_input()
		faint_button.visible=v.combat.player_health<=0
	else: faint_button.hide()
	aim_clock+=dt
	if aim_clock>=0.12: aim_clock=0; _aim()
	refresh+=dt
	if refresh<0.5: return
	refresh=0
	if fingerprint!=_key(): _refresh_hotbar(); _redraw()
	_sync()

func _exit_tree() -> void:
	if state!=null and state.planet.v2.observer_id==get_instance_id(): state.planet.v2.active=false; state.planet.v2.actor={}

func handle_back() -> bool:
	if is_instance_valid(backpack): _close_backpack(); return true
	# Back closes an open side panel first, then leaves first person, and only then the planet.
	if view.first_person and show_details: _toggle_details(); return true
	if view.driving: _toggle_rover(); return true
	if view.first_person: _enter(); return true
	_close(); return true

func enter_first_person() -> void:
	if not view.first_person: _enter()

## Step aside for the workshop or reactor and come back to the same spot and view (main.gd return stack).
func set_editor_open(open: bool) -> void:
	explore_input.clear_input()
	visible=not open
	process_mode=Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if open else SubViewport.UPDATE_ALWAYS
	state.planet.v2.active=not open
	if open:
		if is_instance_valid(backpack): _close_backpack()
		explore_input.set_walking(false)
		return
	state.planet.v2.observer_id=get_instance_id()
	explore_input.set_walking(view.first_person)
	fingerprint=""; _refresh_hotbar(); _redraw(); _sync()
	if view.first_person and not show_details: explore_input.grab_focus()

func _close() -> void:
	explore_input.clear_input()
	closing=true; state.planet.v2.active=false; dismissed.emit(); queue_free()
