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
	create_timer(60).timeout.connect(func(): push_error("Watershed UI timeout"); quit(2))
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
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v013.png")
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
	await button("领取合作"); await button("河流湿地"); await button("开启晚泥盆纪")
	var panel=game.modal; await create_timer(0.6).timeout
	check(panel.view.display_mode=="watershed" and panel.view.watershed_view.sites.size()==3 and not panel.view.globe.visible,"connected landscape replaces old isolated globe geometry")
	check(p.worlds.get_world().paused and p.worlds.get_world().watershed.enabled,"chapter starts paused for deliberate preparation")
	await capture("watershed-devonian")
	await select_product("screen_station"); await button("生产工坊"); await button("提交水样"); await button("补充1份供料"); await button("开始制作")
	p.tick(30); await create_timer(0.3).timeout
	check(p.available_products("screen_station")==1 and p.feed==2,"specialized filter kit does not consume starter water supply")
	await drop("headwater")
	check(p.worlds.get_world().watershed.regions.headwater.screen and p.available_products("screen_station")==0,"touch places actual manufactured screen upstream")
	await select_product("screen_cartridge"); await button("补充1份供料"); await button("开始制作"); p.tick(22); await create_timer(0.3).timeout
	await drop("headwater",false)
	check(p.worlds.get_world().watershed.regions.headwater.screen_energy==80,"mouse deploys finite filter charge")
	await button("观察 / 对照"); await button("上游")
	for i in range(6): await button("观察30秒")
	await button("河口"); await create_timer(0.4).timeout
	check(panel.watershed_widgets.stats.text.contains("底栖") and panel.watershed_widgets.chart.samples.size()>30,"connected observations expose algae, detritus, oxygen and benthos")
	check(p.worlds.get_world().watershed.regions.estuary.oxygen<10,"visible downstream episode follows the simulated upstream input")
	await capture("watershed-hypoxia")
	await button("回看过程"); panel.replay_index=0; panel._live(); await process_frame
	var now=p.serialize()
	check(panel.view.watershed_view.snapshot.watershed.elapsed==0 and p.worlds.get_world().watershed.elapsed==180,"replay displays old state without rewinding current world")
	panel._do("watershed",{"control":"source"}); panel._begin_drag(panel.tray.get_global_rect().get_center())
	check(Same.same(now,p.serialize()) and not panel.dragging,"history blocks nutrient controls and deployment")
	await button("回到当前"); await button("关闭上游营养输入")
	check(not p.worlds.get_world().watershed.source_open,"source gate is an actual control")
	await button("新实验：晚石炭纪"); await create_timer(0.4).timeout
	check(p.worlds.get_world().watershed.era=="carboniferous" and p.worlds.get_world().mode=="experiment","different epoch opens an independent experimental world")
	await capture("watershed-carboniferous")
	await select_product("buffer_raft"); await drop("marsh")
	check(p.worlds.get_world().watershed.regions.marsh.buffer and p.available_products("buffer_raft")==0,"trial uses independent virtual buffer stock")
	await button("湿地"); await button("下次收割"); await select_product("harvest_box"); await drop("marsh")
	check(not p.worlds.get_world().watershed.regions.marsh.harvest.is_empty(),"harvest crate schedules a visible bounded job")
	await button("继续观察"); await create_timer(0.5).timeout
	check(panel.view.watershed_view.sites.marsh.boat.visible,"harvest job has an animated collecting boat")
	await button("暂停观察"); await capture("watershed-harvest")
	await button("新实验：晚泥盆纪")
	check(not p.worlds.can_step_pair(),"UI distinguishes different epoch baseline comparisons")
	check(panel.body.size.x<=360 and panel.watershed_menu.get_global_rect().end.x<=1008,"menu and sidebar stay within horizontal layout")
	panel.handle_back(); await process_frame; check(game.modal==null and not p.observing,"exit preserves island and suspends world observation")
	s.close_science(); print("WATERSHED UI: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
