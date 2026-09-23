extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	_run.call_deferred()
func capture(label: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/island-"+label+"-v09.png")
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	s.coins=20000; s.materials=[100,100,100]
	for entry in [[3,"engineer_house"],[5,"institute"],[7,"doctor_dorm"],[0,"park"],[1,"professor_apartment"],[2,"canteen"]]:
		if not s.plots[entry[0]].unlocked: s.buy_plot(entry[0])
		s.campus_build(entry[0],entry[1]); s.campus_road(entry[0])
	for role in ["doctor","doctor","professor"]: s.campus_hire(role)
	s.buy_consumable("noodles",5); s.supply_dorm(7,"noodles",3)
	s.campus_prop(3,0,"flower"); s.campus_prop(3,1,"fence"); s.campus_prop(3,2,"fence")
	s.campus.elapsed=100
	for i in range(140): s.tick(1)
	s.harvest(0)
	game._sync_world(); game._select_plot(3)
	await create_timer(2).timeout
	await capture("overview")
	assert(game.campus_view.guests.size()==3,"three 3D visitors have independent models")
	assert(game.order_bubbles.bubbles.size()==3,"three request bubbles follow the visitors")
	for bubble in game.order_bubbles.bubbles.values():
		assert(game.world_box.get_global_rect().encloses(bubble.get_global_rect()),"visitor bubbles stay inside the world viewport")
	var grey=game.order_bubbles.bubbles[3]
	var grey_tap=grey.get_global_rect().get_center()
	await game._test_touch(grey_tap,true); await game._test_touch(grey_tap,false); await process_frame
	assert(game.modal.mode=="mail" and game.modal.focused_visitor==3,"grey bubble opens its request on touch")
	game._close_modal()
	await process_frame
	var ready=game.order_bubbles.bubbles[1]
	var ready_tap=ready.get_global_rect().get_center()
	var sales=s.deliveries
	await game._test_touch(ready_tap,true); await game._test_touch(ready_tap,false); await process_frame
	assert(s.deliveries==sales+1 and s.market.visitor(1).phase=="leaving","ready bubble delivers once on touch")
	assert(not is_instance_valid(game.modal),"ready delivery needs no order dialog")
	game._show_toolbox()
	for section in ["elements","products","materials","supplies","decor"]:
		game.modal._tab(section); await capture(section)
	game._close_modal(); game._show_market(); await capture("mail")
	game._close_modal(); game._show_campus("research"); await capture("technology")
	game._close_modal(); game._select_plot(3)
	var prior=s.storage.decorations.get("crystal_fox",0)
	var button
	for child in game.side.get_children():
		if child is Button and child.text.begins_with("拾取"): button=child
	assert(button!=null)
	await process_frame
	var tap=button.get_global_rect().get_center()
	await game._test_touch(tap,true); await game._test_touch(tap,false); await process_frame
	assert(s.storage.decorations.crystal_fox==prior+1,"touch picks up find exactly once")
	game._show_toolbox(); game.modal._tab("decor"); await capture("unlocked")
	game._close_modal(); game._show_campus("build"); await capture("courtyard")
	game._close_modal(); game._select_plot(4)
	s.reactors[0].pending=5; s.reactors[0].stock=5; game._sync_world(); game._update_labels()
	await capture("full-reactor")
	assert(game.campus_view.output_markers[s.reactors[0].id].node.visible,"completed output has a visible collection crate")
	s.close_science()
	print("PASS: v0.9 3D visitors, mailbox, toolbox tabs, technology and touch discovery")
	quit()
