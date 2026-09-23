extends SceneTree
const Main=preload("res://scripts/main.gd")
var checks=0
var failures=[]
var game
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(50).timeout.connect(func(): quit(2))
func key(code: int) -> void:
	var e=InputEventKey.new(); e.physical_keycode=code; e.pressed=true; Input.parse_input_event(e); await process_frame
	e=InputEventKey.new(); e.physical_keycode=code; e.pressed=false; Input.parse_input_event(e); await process_frame
func click(control, touch: bool=false) -> void:
	var at=control.get_global_rect().get_center()
	if touch: await game._test_touch(at,true); await game._test_touch(at,false)
	else: await game._test_pointer(at,true); await game._test_pointer(at,false)
	await process_frame; await process_frame
func item_slot(panel,id: String):
	for slot in panel.grid.get_children():
		if slot.item.get("id")==id: return slot
	return null
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; var p=s.planet; s.coins=10000
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,6)
	p.command(s,"join"); p.command(s,"qualify",{"batch_id":sample.id})
	for recipe in ["frame_bundle","modern_silicon","modern_perovskite","standard_water_crate"]:
		p.command(s,"buy_feed",{"input":p.recipe(recipe).input}); p.command(s,"pack",{"recipe":recipe}); p.tick(60)
	game._show_planet_v2(); await process_frame; await process_frame
	var panel=game.modal; var v=p.v2; var bag=v.inventory
	v.world.paused=true; panel._select_region("meadow"); panel._enter(); panel.view.travel(Vector2(15,17))
	panel.view.walker.yaw=0; panel.view.walker.pitch=-0.9; panel.view._camera(0)
	var pos=panel.view.walker.position
	await key(KEY_B)
	check(is_instance_valid(panel.backpack),"B opens the grid backpack through input dispatch")
	if not is_instance_valid(panel.backpack): quit(1); return
	var inv=panel.backpack
	check(not panel.explore_input.walking and not panel.explore_input.visible,"open backpack suspends world movement and look")
	check(inv.grid.get_child_count()>=28 and inv.shortcuts.get_child_count()==9,"grid and editable nine-slot quickbar are visible")
	await click(item_slot(inv,"recipe:frame_bundle"),true)
	check(inv.selected_id=="recipe:frame_bundle","touch selects an owned component")
	await click(inv.shortcuts.get_child(4),true)
	check(bag.slots[4]=="recipe:frame_bundle" and bag.selected==4,"touch assigns selected item to chosen quick slot")
	var wallet=s.coins; var products=p.products.duplicate(true)
	var before_count=v.construction.blocks.size()
	await key(KEY_E); await key(KEY_SPACE); await key(KEY_W)
	check(v.construction.blocks.size()==before_count and panel.view.walker.position.is_equal_approx(pos) and panel.view.walker.movement==Vector2.ZERO,"inventory keys cannot place, jump or walk behind the modal")
	var drop=inv.shortcuts.get_child(7)
	check(drop._can_drop_data(Vector2.ZERO,{"river_inventory_item":"recipe:frame_bundle"}),"quick slots accept inventory drag payloads")
	var drag_start=inv.shortcuts.get_child(4).get_global_rect().get_center(); var drag_end=drop.get_global_rect().get_center()
	await game._test_pointer(drag_start,true)
	for i in range(1,7):
		var move=InputEventMouseMotion.new(); move.position=drag_start+(drag_end-drag_start)*i/6.0; move.relative=(drag_end-drag_start)/6.0; move.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(move); await process_frame
	await game._test_pointer(drag_end,false); await process_frame
	check(bag.slots[7]=="recipe:frame_bundle" and bag.slots[4]=="","dragging a quick reference moves it to the target slot")
	check(s.coins==wallet and p.products==products,"touch and drag rearrangements do not consume or duplicate products")
	await click(item_slot(inv,"recipe:modern_perovskite")); await key(KEY_6)
	check(bag.slots[5]=="recipe:modern_perovskite","number key equips selected backpack item to that slot")
	await click(item_slot(inv,"recipe:frame_bundle")); await capture("backpack-grid")
	await key(KEY_B)
	check(not is_instance_valid(panel.backpack) and panel.explore_input.walking,"B closes inventory and restores exploration controls")
	await key(KEY_8)
	check(bag.selected==7 and panel.build_mode=="block","number key selects equipped component in world")
	var target=panel.explore_input.global_position+panel.explore_input.size*0.5
	await game._test_pointer(target,true); await game._test_pointer(target,false)
	check(v.construction.blocks.size()==1 and panel.hotbar_slots[7].item.quantity==7,"world click uses selected slot and displays seven remaining blocks")
	check(panel.view.walker.position.is_equal_approx(pos),"backpack and placement preserve player position")
	await capture("backpack-hotbar")
	await key(KEY_9); await key(KEY_E)
	check(v.construction.blocks.size()==1 and panel.message.contains("空"),"empty quick slot does not perform the previous tool action")
	# Godot's desktop scroll widget needs the touchscreen hint; Android supplies it natively.
	Input.emulate_touch_from_mouse=true
	panel._open_backpack(); await process_frame; inv=panel.backpack
	var batch_id="sample:"+sample.id
	await click(item_slot(inv,batch_id)); var quantity=s.storage.batch(sample.id).quantity; var water=v.region().water
	inv.use_requested.emit(batch_id,"deploy"); await process_frame
	check(s.storage.batch(sample.id).quantity==quantity-1 and v.region().water>water and s.coins==wallet,"backpack uses the actual selected water batch without charging coins")
	check(inv.feedback.text.contains("送达"),"modal shows the deployment result")
	# Many batches must scroll by swiping a slot, without selecting or consuming it.
	for i in range(36):
		var extra=sample.duplicate(true); extra.id="scroll-fixture-%d" % i; s.storage.add_product(extra,1)
	inv.category="samples"; inv.selected_id=""; inv.refresh(true); await process_frame; await process_frame; await process_frame
	var start=inv.scroll.global_position+Vector2(130,230); var seed_before=v.world.seeds
	await game._test_touch(start,true)
	for i in range(1,7):
		var drag=InputEventScreenDrag.new(); drag.index=0; drag.position=start+Vector2(0,-180)*i/6.0; drag.relative=Vector2(0,-30); Input.parse_input_event(drag); await process_frame
	await game._test_touch(start+Vector2(0,-180),false); await process_frame
	check(inv.scroll.scroll_vertical>60 and inv.selected_id=="" and v.world.seeds==seed_before,"native finger swipe scrolls inventory without selecting or using an item")
	var scroll_pos=inv.scroll.scroll_vertical; inv.refresh(); await process_frame; await process_frame; await process_frame
	check(absi(inv.scroll.scroll_vertical-scroll_pos)<4,"stock refresh preserves scrolled inventory position")
	panel.handle_back(); await process_frame
	check(not is_instance_valid(panel.backpack) and panel.view.first_person,"mobile back closes backpack before leaving first person")
	game.queue_free(); await process_frame
	print("RIVER INVENTORY UI: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
