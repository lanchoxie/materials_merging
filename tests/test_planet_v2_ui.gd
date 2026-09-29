extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	Input.emulate_touch_from_mouse=true
	root.size=Vector2i(1440,900); _run.call_deferred()
	create_timer(45).timeout.connect(func(): push_error("v2 UI timeout"); quit(2))
func button(node: Node,text: String):
	if node is Button and node.text.contains(text): return node
	for child in node.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
func press(text: String) -> void:
	var b=button(game.modal,text); check(b!=null,"button exists: "+text)
	if b!=null: b.pressed.emit()
	await process_frame; await process_frame
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+path+".png")
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var p=s.planet
	s.storage.add_product(s.product_snapshot(s._new_reactor(3,"water",0.0)),4)
	game._show_market(); await process_frame
	await press("上帝星球")
	var panel=game.modal
	check(p.v2.active and panel.view.terrain_root.get_child_count()>0,"new planet opens through mailbox")
	check(panel.time_label.text.begins_with("第 "),"clock is visible")
	await press("暂停")
	var elapsed=p.v2.world.elapsed; p.tick(2); check(elapsed==p.v2.world.elapsed,"pause button stops simulation")
	await capture("v021-river-overview")
	await create_timer(0.4).timeout
	var ground=panel.view.terrain.ground(Vector2(10,-10))
	var point=panel.viewport_box.global_position+panel.view.camera.unproject_position(Vector3(10,ground,-10))
	await game._test_pointer(point,true); await game._test_pointer(point,false)
	check(p.v2.world.current_region=="highland","map click selects the projected terrain region")
	await press("河畔草甸"); await press("近看")
	check(panel.view.close_view and p.v2.world.current_region=="meadow","regional view shares world")
	panel._tab("bag"); await process_frame
	var coins=s.coins; var water=p.v2.region().water
	panel.backpack.selected_id="sample:"+str(s.storage.batches[0].id); panel.backpack.refresh()
	await press("投放当前区域")
	check(p.v2.region().water>water and s.coins==coins,"UI deploys real sample without planet coin cost")
	panel._close_backpack(); await process_frame
	await press("生命"); await press("播谷物")
	check(p.v2.region().crops.size()==2,"planting uses visible world")
	var seed_count=p.v2.world.seeds
	var start=button(panel,"播谷物").get_global_rect().get_center()
	await game._test_touch(start,true)
	for i in range(1,7):
		var e=InputEventScreenDrag.new(); e.index=0; e.position=start+Vector2(0,-140)*i/6.0; e.relative=Vector2(0,-140)/6.0; Input.parse_input_event(e); await process_frame
	await game._test_touch(start+Vector2(0,-140),false)
	check(panel.scroll.scroll_vertical>60 and seed_count==p.v2.world.seeds,"native swipe scrolls without planting")
	await create_timer(0.8).timeout; panel.scroll.scroll_vertical=0
	p.v2.advance(300); panel._redraw(); panel._sync()
	await press("收获成熟")
	check(p.v2.world.food>0,"harvest closes the crop loop")
	await capture("v021-river-region")
	var living=panel.view.animal_nodes.size(); var node_count=panel.view.terrain_root.get_child_count()
	for i in range(12): panel._sync()
	check(panel.view.animal_nodes.size()==living and panel.view.terrain_root.get_child_count()==node_count,"render refresh reuses nodes rather than spawning copies")
	await press("年鉴")
	check(panel.body.get_child_count()>0,"chronicle renders")
	await capture("v021-river-chronicle")
	panel._tab("bag"); await process_frame
	await press("工艺\n车间")
	await process_frame
	check(not p.v2.active,"switching to workshop stops river simulation")
	game._show_planet_v2(); await process_frame; await press("返回浮岛"); await process_frame
	check(not p.v2.active and game.modal==null,"close clears observer")
	game.queue_free(); await process_frame
	print("PLANET_V2_UI: %d checks, %d failures" % [checks,failures.size()])
	FileAccess.open("res://artifacts/v021-ui-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}, "\t"))
	quit(0 if failures.is_empty() else 1)
