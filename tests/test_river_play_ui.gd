extends SceneTree
const Main=preload("res://scripts/main.gd")
var checks:=0
var failures=[]
var game
func check(ok: bool,msg: String)->void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func button(node: Node,text: String):
	if node is Button and node.text.contains(text): return node
	for child in node.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
func _initialize()->void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(50).timeout.connect(func(): quit(2))
func _run()->void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._show_planet_v2(); await process_frame; await process_frame
	var panel=game.modal; var v=game.state.planet.v2
	v.world.paused=true; panel._select_region("meadow"); panel._enter(); await process_frame; await process_frame
	check(panel.view.first_person and panel.play_bar.visible,"first person shows build and jump controls")
	check(panel.aim_label.visible and panel.aim_label.text.contains("E"),"first person shows an actionable aim prompt")
	# Reproduce the reported reset through the complete input dispatch path.
	panel.view.travel(Vector2(15,14)); await process_frame
	var walked=panel.view.walker.position; var heading=panel.view.walker.yaw
	await game._test_pointer(Vector2(730,440),true); await game._test_pointer(Vector2(730,440),false)
	check(panel.view.walker.position.is_equal_approx(walked) and is_equal_approx(panel.view.walker.yaw,heading),"left click after walking preserves position and heading")
	var build_button=panel.hotbar_slots[1].get_global_rect().get_center()
	await game._test_pointer(build_button,true); await game._test_pointer(build_button,false)
	check(panel.build_mode=="remove" and panel.view.walker.position.is_equal_approx(walked),"toolbar click selects an equipped tool without teleporting")
	panel.view.travel(walked); panel._select_region("meadow")
	check(panel.view.walker.position.is_equal_approx(walked),"selecting the current region does not respawn the walker")
	panel._map_click(Vector2(400,280))
	check(panel.view.walker.position.is_equal_approx(walked),"first-person map selection is ignored defensively")
	heading=panel.view.walker.yaw; panel._enter(); panel._enter()
	check(panel.view.walker.position.is_equal_approx(walked) and is_equal_approx(panel.view.walker.yaw,heading),"god view round trip resumes the same walking location")
	await _construction_inputs(panel)
	panel._tool("block"); await process_frame
	check(panel.build_mode=="block" and panel.action_button.text=="放置 E","construction tool selects place action")
	panel._tool("remove"); await process_frame
	check(panel.build_mode=="remove" and panel.action_button.text=="拆回 E","construction tool selects dismantle action")
	panel._toggle_details(); await process_frame; panel._tab("build"); await process_frame
	check(panel.right_panel.visible and button(panel,"拆回自己的构件")!=null,"build tab gives material return path")
	panel._tab("era"); await process_frame
	check(button(panel,"建立农耕聚落")!=null and panel.widgets.era.text.contains("木构"),"era tab exposes the next chapter requirements")
	check(panel.view.settlement_view.members.is_empty(),"no settlers appear before the agrarian chapter")
	button(panel,"回草甸营地").pressed.emit()
	check(panel.view.walker.position.is_equal_approx(panel.view.terrain.LANDMARKS.home.at),"explicit return-to-camp still travels even within the same region")
	panel._select_region("highland")
	check(panel.view.walker.position.is_equal_approx(panel.view.terrain.spawn("highland")),"explicit choice of another region still enters its spawn")
	panel._enter(); game.queue_free(); await process_frame
	print("RIVER PLAY UI: ",checks," checks, ",failures.size()," failures")
	FileAccess.open("res://artifacts/river-play-ui-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func _construction_inputs(panel) -> void:
	var s=game.state; var pg=s.planet; var c=pg.v2.construction
	s.coins=10000
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,5)
	pg.command(s,"join"); pg.command(s,"qualify",{"batch_id":sample.id})
	pg.command(s,"buy_feed",{"input":pg.recipe("frame_bundle").input})
	pg.command(s,"pack",{"recipe":"frame_bundle"}); pg.tick(60)
	check(c.available("block",pg.products)==8,"construction begins with a real factory package")
	panel.view.travel(Vector2(15,17)); panel.view.walker.yaw=0; panel.view.walker.pitch=-0.9
	panel.view._camera(0); panel._tool("block"); panel._sync(); await process_frame
	var pos=panel.view.walker.position; var wallet=s.coins
	var target=panel.explore_input.global_position+panel.explore_input.size*0.5
	await game._test_pointer(target,true); await game._test_pointer(target,false)
	check(c.blocks.size()==1 and c.available("block",pg.products)==7,"a short left click places exactly one owned component")
	check(s.coins==wallet and panel.view.walker.position.is_equal_approx(pos),"click construction neither charges coins nor moves player")
	panel._aim()
	check(panel.hotbar_slots[pg.v2.inventory.selected].item.quantity==7,"toolbar reflects remaining component units")
	var blocks=c.blocks.size(); var heading=panel.view.walker.yaw
	await game._test_pointer(target,true)
	var motion=InputEventMouseMotion.new(); motion.position=target+Vector2(80,0); motion.relative=Vector2(80,0); motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion); await process_frame
	await game._test_pointer(motion.position,false)
	check(c.blocks.size()==blocks and panel.view.walker.yaw!=heading and panel.view.walker.position.is_equal_approx(pos),"left drag turns camera without placing or teleporting")
	await game._test_pointer(target,true); await game._test_pointer(Vector2(1435,890),false)
	check(c.blocks.size()==blocks and not panel.explore_input.primary_down and not panel.explore_input.mouse_look,"release outside the scene cancels click construction")
	await game._test_pointer(target,true); panel.explore_input.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await game._test_pointer(target,false)
	check(c.blocks.size()==blocks,"focus loss cancels pending construction click")
	await game._test_pointer(target,true); panel.explore_input.primary_started-=int(panel.view.terrain.rules.click_hold_ms)+1
	await game._test_pointer(target,false)
	check(c.blocks.size()==blocks,"holding the view does not become an accidental placement")
	# Native touch and its emulated mouse events must never double-build.
	await game._test_touch(target,true); await game._test_touch(target,false)
	check(c.blocks.size()==blocks and panel.view.walker.position.is_equal_approx(pos),"touch camera gesture does not place an unintended block")
	panel.view.walker.yaw=0; panel.view._camera(0); panel._tool("remove")
	await game._test_pointer(target,true); await game._test_pointer(target,false)
	check(c.blocks.is_empty() and c.available("block",pg.products)==8,"a dismantle click returns the exact component to its source package")
	panel._tool("block"); await game._test_pointer(target,true); await game._test_pointer(target,false)
	if DisplayServer.get_name()!="headless":
		game.toast_panel.hide(); await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/river-play-click-build.png")
