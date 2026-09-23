extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	_run.call_deferred()
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campus-"+label+".png")
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	s.coins=20000; s.materials=[10000,10000,10000]; s.deliveries=3
	for entry in [[3,"engineer_house"],[5,"institute"],[7,"doctor_dorm"],[0,"professor_apartment"],[1,"academician_villa"],[2,"canteen"],[6,"park"]]:
		if not s.plots[entry[0]].unlocked: s.buy_plot(entry[0])
		s.campus_build(entry[0],entry[1]); s.campus_road(entry[0])
	for role in ["engineer","doctor","doctor","professor","academician"]: s.campus_hire(role)
	s.campus_prop(3,0,"flower"); s.campus_prop(3,3,"lamp"); s.campus_prop(3,5,"trophy")
	s.campus_start_research("perovskite_chloride")
	s.campus.day_time=90
	game._sync_world()
	await create_timer(6).timeout
	await capture("island-v08")
	assert(game.world._workers.is_empty(),"legacy circular workers disabled")
	for tab in ["overview","people","build","research","requests"]:
		game._show_campus(tab)
		assert(game.modal.current_tab==tab)
		await capture(tab+"-v08")
	game._show_campus("people")
	await process_frame
	var hire_button=game.modal.live_quotes[0].button
	var before=s.engineers
	var price=s.campus.config.roles.engineer.cost
	var wallet=s.coins
	var tap=hire_button.get_global_rect().get_center()
	await game._test_touch(tap,true)
	await game._test_touch(tap,false)
	await process_frame
	assert(s.engineers==before+1 and is_equal_approx(s.coins,wallet-price),"touch hire pays once and adds resident")
	game._close_modal()
	game._show_market(); await capture("market-v08")
	game._close_modal()
	var rebuilds=game.campus_view.static_rebuilds
	await create_timer(2).timeout
	assert(game.campus_view.static_rebuilds==rebuilds,"ordinary ticks do not rebuild scenery")
	s.close_science()
	print("PASS: v0.8 campus tabs, island, market, legacy animation removal and stable scenery")
	quit()
