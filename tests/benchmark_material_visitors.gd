extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): push_error("Benchmark save isolation required"); quit(2); return
	root.size=Vector2i(1440,900)
	_run.call_deferred()
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var state=game.state
	state.coins=1000000; state.materials=[100000,100000,100000]
	while state.unlocked_plot_count()<128:
		var next=-1
		for i in range(state.plots.size()):
			if state.can_expand(i): next=i; break
		if next<0: break
		state.buy_plot(next)
	for i in range(state.plots.size()):
		if not state.plots[i].unlocked or state.plots[i].kind!="empty": continue
		state.campus_road(i)
		if i%4==0:
			state.place_reactor(i,"water"); state.reactors[-1].build_left=0
		else: state.campus_build(i,["institute","engineer_house","doctor_dorm"][i%3])
		for slot in [0,2,4,6]: state.campus_prop(i,slot,"flower")
	state.campus.setup(80,16); state._sync_campus_counts()
	for n in range(140): state.tick(1)
	game._sync_world()
	await create_timer(3).timeout
	var frames=[]; var previous=Time.get_ticks_usec()
	var static_before=game.campus_view.static_rebuilds
	for n in range(240):
		await process_frame
		var now=Time.get_ticks_usec(); frames.append(float(now-previous)/1000.0); previous=now
	frames.sort()
	assert(game.campus_view.actors.size()<=24)
	assert(game.world._detailed_plots.size()<=36)
	assert(game.campus_view.static_rebuilds==static_before)
	var report={"device":RenderingServer.get_video_adapter_name(),"viewport":"1440x900","plots":state.unlocked_plot_count(),"residents":state.campus.people.size(),"reactors":state.reactors.size(),"rendered_residents":game.campus_view.actors.size(),"detailed_plots":game.world._detailed_plots.size(),"frames":frames.size(),"median_frame_ms":frames[120],"p95_frame_ms":frames[228],"static_rebuilds_during_sample":game.campus_view.static_rebuilds-static_before,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"object_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"note":"Local Windows rendering sample only; not Android or browser FPS."}
	FileAccess.open("res://artifacts/campus-performance-v020.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campus-stress-v020.png")
	print("PERFORMANCE: ",JSON.stringify(report))
	state.close_science(); quit()
