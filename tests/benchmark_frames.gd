extends "res://tests/capture_earth_ux.gd"
## Performance probe (not a test): frame time, script time, draw calls and memory in the main
## scenes. Run windowed:  ... --script res://tests/benchmark_frames.gd -- --release-ui-test

func measure(label: String,frames: int=240,walk=null) -> void:
	for i in range(30): await process_frame
	var times=[]; var scripts=[]; var calls=0
	for i in range(frames):
		if walk!=null: walk.call(i)
		var t0=Time.get_ticks_usec(); await process_frame; times.append(Time.get_ticks_usec()-t0)
		scripts.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		calls=maxi(calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	times.sort(); scripts.sort()
	var avg=0.0
	for t in times: avg+=t
	avg/=times.size()
	print("BENCH %-18s avg %5.1f ms  p95 %5.1f ms  script p95 %5.1f ms  draws %4d  mem %4d MB  objs %d" % [label,avg/1000.0,times[int(times.size()*0.95)]/1000.0,scripts[int(scripts.size()*0.95)],calls,
		int(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576),int(Performance.get_monitor(Performance.OBJECT_COUNT))])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	await measure("island")
	v.world.elapsed=20.0
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._select_region("meadow"); panel._enter(); panel._equip_item("tool:collect")
	var w=panel.view.walker
	await measure("planet-home",240,func(i): w.movement=Vector2(0,-1))
	w.stop(); panel.test_teleport(Vector2(900,-400),"hills"); for i in range(60): await process_frame
	await measure("planet-hills-walk",240,func(i): w.movement=Vector2(0.3,-1); w.running=true)
	w.stop()
	v.incidents.warn(v,"storm",1); for i in range(3): v.world.elapsed+=1; v._step()
	panel._sync()
	await measure("planet-storm")
	v.incidents.active={}; panel._sync()
	panel.closing=true; game._close_all(); await process_frame
	preload("res://scripts/test_mode.gd").open_starforge(s,300); s.coins=30000
	s.industry.build(s,0,"metal_works"); s.industry.build(s,1,"polymer_works"); s.industry.build(s,2,"trade_hub")
	game._show_starforge()
	await measure("starforge")
	game.queue_free(); await process_frame
	print("BENCH done"); quit(0)
