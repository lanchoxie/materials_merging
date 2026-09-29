extends SceneTree
const Main=preload("res://scripts/main.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("Village UI timeout"); quit(2))
func find_button(node: Node,text: String):
	if node is Button and node.text.begins_with(text): return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null: return found
	return null
func button(text: String) -> void:
	var b=find_button(game.modal,text); check(b!=null,"button: "+text)
	if b!=null: b.pressed.emit()
	await process_frame; await process_frame
func drop(site: String,touch: bool=true) -> void:
	var p=game.modal; var start=p.tray.get_global_rect().get_center()
	var finish=p.viewport_box.global_position+p.view.project_site(site)*p.viewport_box.size/Vector2(p.viewport.size)
	if touch:
		await game._test_touch(start,true)
		var move=InputEventScreenDrag.new(); move.index=0; move.position=finish; move.relative=finish-start; Input.parse_input_event(move); await process_frame
		await game._test_touch(finish,false)
	else:
		var down=InputEventMouseButton.new(); down.position=start; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; Input.parse_input_event(down); await process_frame
		var move=InputEventMouseMotion.new(); move.position=finish; move.relative=finish-start; move.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(move); await process_frame
		var up=InputEventMouseButton.new(); up.position=finish; up.button_index=MOUSE_BUTTON_LEFT; Input.parse_input_event(up); await process_frame
func capture(name: String) -> void:
	game.toast_panel.hide(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v014.png")
func select_product(id: String) -> void:
	var menu=game.modal.watershed_menu
	for i in range(1,menu.item_count):
		if menu.get_item_metadata(i)==id: menu.select(i); menu.item_selected.emit(i); break
	await process_frame; await process_frame
func run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=9000; var p=s.planet
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,2)
	game._show_planet(); await process_frame
	await button("领取合作"); await button("河湾聚落"); await button("开启聚落并暂停")
	var panel=game.modal; await create_timer(0.6).timeout
	check(panel.view.display_mode=="village" and panel.view.village_view.people.size()==6 and not panel.view.globe.visible,"village replaces globe with six bounded representatives")
	check(p.worlds.get_world().paused and p.worlds.get_world().village.enabled,"new chapter opens paused")
	await select_product("frame_bundle"); await button("生产工坊"); await button("提交水样"); await button("补充1份供料"); await button("开始制作")
	p.tick(26); await create_timer(0.3).timeout
	await drop("village_depot")
	check(p.worlds.get_world().village.stock.frames==6 and p.available_products("frame_bundle")==0,"touch delivery transfers actual manufactured structure package")
	await button("改用本岛车间"); await button("补充1份供料"); await button("开始制作")
	var remaining=p.job.left; s.tick(2)
	check(p.job.left==remaining and p.production_mode=="island","UI island production waits without workshop workers")
	await button("交回合作方托管"); p.tick(26)
	check(p.available_products("frame_bundle")==1,"partner selection resumes the same reserved job")
	await button("观察 / 对照"); await button("复制聚落为独立实验")
	for recipe in ["frame_bundle","frame_bundle","frame_bundle","tool_chest","standard_water_crate","drinking_barrel"]:
		if recipe=="standard_water_crate": panel._choose_recipe(recipe); await process_frame
		else: await select_product(recipe)
		await drop("village_depot",false)
	await button("批准 · 河湾水磨坊"); await button("批准 · 工匠集市")
	await button("聚落观察30秒")
	check(panel.view.village_view.scaffolds.cistern.visible and not panel.view.village_view.buildings.cistern.visible,"committed unfinished building displays scaffold rather than finished structure")
	await capture("village-construction")
	for i in range(11): await button("聚落观察30秒")
	var w=p.worlds.get_world().village
	check(w.projects.road.complete and w.projects.mill.complete and w.projects.market.complete,"actual UI-approved projects complete from finite trial supplies")
	check(panel.view.village_view.buildings.market.visible and panel.village_widgets.people.text.contains("磨粮"),"finished market and residents' actual activity are visible")
	await capture("village-built")
	for i in range(120):
		if w.mill_running: break
		p.worlds.tick_world(p.worlds.get_world(),1)
	var rotation=panel.view.village_view.wheel.rotation.x
	p.worlds.get_world().paused=false; panel._live(); await create_timer(0.35).timeout
	check(w.mill_running and panel.view.village_view.wheel.rotation.x!=rotation,"working watermill produces actual wheel animation")
	p.worlds.get_world().paused=true; panel._redraw(); panel._live()
	await button("水磨引水比例"); check(w.diversion==1,"watermill control changes actual diversion")
	await button("回看过程"); panel.replay_index=0; panel._live(); await process_frame
	var before=p.serialize(); panel._do("village",{"control":"policy","id":"river"}); panel._begin_drag(panel.tray.get_global_rect().get_center())
	check(Same.same(before,p.serialize()) and not panel.dragging,"historical view cannot spend products or change policies")
	check(panel.view.village_view.snapshot.village.elapsed<w.elapsed,"history shows older resident state without rewinding live inventory")
	await button("回到当前")
	check(panel.body.size.x<=360 and panel.watershed_menu.get_global_rect().end.x<=1008,"new chapter fits the established sidebar and bottom menu")
	panel.handle_back(); await process_frame
	s.campus_build(3,"workshop"); s.campus_road(3); game._show_campus("people"); await process_frame
	await button("车间生产")
	check(s.campus.people[0].post=="workshop","resident panel changes actual engineer post")
	await capture("village-posts")
	game._close_modal(); s.close_science(); print("VILLAGE UI: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
