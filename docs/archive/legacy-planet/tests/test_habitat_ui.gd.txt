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
	if "--release-ui-test" not in OS.get_cmdline_user_args(): push_error("Use -- --release-ui-test to isolate UI tests from player saves"); quit(2); return
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("Habitat UI timeout"); quit(2))
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
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v015.png")
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
	await button("领取合作"); await button("白垩纪"); await button("开启蕨林河谷并暂停")
	var panel=game.modal; await create_timer(0.6).timeout
	check(panel.view.display_mode=="habitat" and panel.view.habitat_view.animals.size()==10 and not panel.view.globe.visible,"ten bounded procedural dinosaurs occupy a separate visible chapter")
	check(p.worlds.get_world().paused and p.worlds.get_world().habitat.enabled,"new ecology opens paused for intervention")
	await capture("habitat-start")
	await select_product("habitat_bridge"); await button("生产工坊"); await button("提交水样"); await button("补充1份供料"); await button("开始制作")
	p.tick(32); await create_timer(0.3).timeout
	await drop("crossing_fern_ridge")
	check(p.worlds.get_world().habitat.edges.fern_ridge.built and p.available_products("habitat_bridge")==0,"touch drop at gold crossing commits the actual manufactured bridge")
	await button("观察 / 对照"); await button("复制栖地为独立实验")
	await select_product("shade_canopy"); await drop("habitat_fern",false)
	await process_frame; await process_frame
	check(p.worlds.get_world().habitat.regions.fern.shade and panel.view.habitat_view.regions.fern.canopy.visible,"mouse drop installs actual shade and displays a canopy")
	panel._choose_recipe("standard_water_crate"); await process_frame
	check(panel.view.display_mode=="habitat","selecting a water crate preserves habitat scene")
	await drop("habitat_fern")
	check(p.worlds.get_world().habitat.regions.fern.added==38,"touch water delivery uses finite independent experiment allowance")
	await button("栖地观察30秒"); await button("栖地观察30秒"); await button("栖地观察30秒")
	var w=p.worlds.get_world().habitat
	check(w.migrations>0 and panel.habitat_widgets.people.text.contains("→"),"live sidebar describes actual migrations")
	await capture("habitat-migration")
	var before_positions=[]
	for animal in panel.view.habitat_view.animals: before_positions.append(animal.root.position)
	for i in range(8): await button("栖地观察30秒")
	var changed=false
	for i in range(before_positions.size()): changed=changed or before_positions[i].distance_to(panel.view.habitat_view.animals[i].root.position)>0.1
	check(changed and w.elapsed==330,"visual representatives follow advancing ecological state")
	await button("关闭 · 蕨地连接桥")
	check(not w.edges.fern_ridge.open and panel.view.habitat_view.crossings.fern_ridge.gate.visible,"closing bridge changes route and visible barrier")
	await button("回看过程"); panel.replay_index=0; panel._live(); await process_frame
	var before=p.serialize(); panel._do("habitat",{"id":"fern_ridge"}); panel._begin_drag(panel.tray.get_global_rect().get_center())
	check(Same.same(before,p.serialize()) and not panel.dragging,"historical habitat cannot spend products, change gates or revive state")
	check(panel.view.habitat_view.snapshot.habitat.elapsed<w.elapsed,"history displays older trajectories without changing live world")
	await button("回到当前"); await button("展开资源账本")
	check(panel.habitat_widgets.ledger.text.contains("游戏资源当量"),"resource ledger labels teaching units")
	check(panel.body.size.x<=360 and panel.watershed_menu.get_global_rect().end.x<=1008,"new controls fit sidebar and inventory")
	var scene_button=find_button(panel,"白垩纪")
	check(scene_button.get_global_rect().end.x<=1024 and panel.world_tabs.get_global_rect().end.x<=scene_button.get_parent().position.x,"all chapter and world navigation remain separate")
	await capture("habitat-late")
	panel.handle_back(); await process_frame
	s.close_science(); print("HABITAT UI: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
