extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900); _run.call_deferred()
	create_timer(45).timeout.connect(func(): push_error("Planet UI test timeout"); quit(2))
func find_button(node: Node,text: String):
	if node is Button and node.text.contains(text): return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null: return found
	return null
func press_button(text: String) -> void:
	var button=find_button(game.modal,text)
	check(button!=null,"button exists: "+text)
	if button==null: return
	# Press through the UI's connected command path; drag checks below use actual input.
	button.pressed.emit(); await process_frame; await process_frame
func capture(name: String) -> void:
	game.toast_panel.hide()
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v011.png")
func move_touch(at: Vector2,from: Vector2) -> void:
	var event=InputEventScreenDrag.new(); event.index=0; event.position=at; event.relative=at-from
	Input.parse_input_event(event); await process_frame
func site_point(panel,id: String) -> Vector2:
	return panel.viewport_box.global_position+panel.view.project_site(id)*panel.viewport_box.size/Vector2(panel.viewport.size)
func mouse_button(at: Vector2,down: bool) -> void:
	var event=InputEventMouseButton.new(); event.position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
	Input.parse_input_event(event); await process_frame
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=1200
	var batch=s.product_snapshot(s.reactors[0]); s.storage.add_product(batch,4)
	game._show_market(); await process_frame
	await press_button("进入材料试验星球")
	var panel=game.modal
	check(panel.has_method("_begin_drag") and s.planet.observing,"mail opens planet and observing begins")
	await press_button("领取合作与首次供料")
	await press_button("提交水样")
	await press_button("开始装罐")
	s.planet.tick(25); await create_timer(0.4).timeout
	check(s.planet.products.size()==1,"product ready in tray")
	await capture("planet-dry")
	var start=panel.tray.get_global_rect().get_center()
	var target=site_point(panel,"deep")
	await game._test_touch(start,true)
	check(panel.dragging,"real touch lifts inventory water crate")
	await move_touch(target,start)
	check(panel.view.highlighted=="deep","hover highlights the deep basin")
	await capture("planet-drag")
	await game._test_touch(target,false)
	check(s.planet.products.is_empty() and s.planet.worlds.get_world().zones[0].target==1,"touch drop spends exactly one crate in correct region")
	s.planet.tick(9); await create_timer(0.7).timeout
	check(panel.view.sites.deep.water.visible,"deployed water appears on planet")
	await capture("planet-water")
	await press_button("观察 / 对照")
	await press_button("从干燥盆地创建实验")
	check(s.planet.worlds.active_id=="trial_a","experiment A opened")
	start=panel.tray.get_global_rect().get_center()
	var allowance=s.planet.worlds.get_world().allowance
	await game._test_touch(start,true); await move_touch(Vector2(12,870),start); await game._test_touch(Vector2(12,870),false)
	check(s.planet.worlds.get_world().allowance==allowance and not panel.dragging,"outside touch drop cancels without charge")
	await game._test_touch(start,true); target=site_point(panel,"deep")
	await move_touch(target,start); await game._test_touch(target,false)
	await press_button("从干燥盆地创建实验")
	start=panel.tray.get_global_rect().get_center(); target=site_point(panel,"shelf")
	await game._test_touch(start,true); await move_touch(target,start); await game._test_touch(target,false)
	await press_button("两个实验同步推进10秒")
	check(s.planet.worlds.get_world("trial_a").zones[0].water==1 and s.planet.worlds.get_world("trial_b").zones[1].water==1,"same-time forks preserve independent layouts")
	await create_timer(0.5).timeout; await capture("planet-comparison")
	check(not panel.view.sites.deep.water.visible,"switching to B does not display A's water")
	check(panel.body.size.x<=360,"side panel fits available width")
	var rotation=panel.view.target_yaw
	await game._test_touch(Vector2(350,350),true); await move_touch(Vector2(430,360),Vector2(350,350)); await game._test_touch(Vector2(430,360),false)
	check(panel.view.target_yaw!=rotation,"touch drag rotates planet")
	panel.view.reset_camera(); await create_timer(0.5).timeout
	start=panel.tray.get_global_rect().get_center()
	await game._test_touch(start,true); await game._test_touch(start,false)
	check(panel.armed,"tap crate enables accessible tap-to-place")
	panel.handle_back(); check(not panel.armed and is_instance_valid(panel),"back cancels placement before exiting")
	start=panel.tray.get_global_rect().get_center(); target=site_point(panel,"deep")
	await mouse_button(start,true)
	var motion=InputEventMouseMotion.new(); motion.position=target; motion.relative=target-start; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion); await process_frame
	await mouse_button(target,false)
	check(s.planet.worlds.get_world().zones[0].target==1,"desktop mouse drag delivers to the same hit-tested sites")
	panel.handle_back(); await process_frame
	check(not s.planet.observing and game.modal==null,"return pauses planet and restores island")
	await process_frame
	check(game.world_viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"island viewport resumes after planet")
	game._show_toolbox(); game.modal._tab("industrial"); await process_frame
	check(find_button(game.modal,"前往试验湾")!=null,"industrial products have their own toolbox section")
	game._close_modal(); s.close_science()
	print("PLANET UI: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
