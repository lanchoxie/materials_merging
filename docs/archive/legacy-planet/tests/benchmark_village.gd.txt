extends SceneTree
const Main=preload("res://scripts/main.gd")
func _initialize() -> void:
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("Village benchmark timeout"); quit(2))
func run() -> void:
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var p=s.planet; p.command(s,"join"); p.command(s,"activate_watershed",{"era":"carboniferous"}); p.command(s,"activate_village")
	var m=p.worlds.village; var w=p.worlds.get_world()
	for id in ["mill","market"]: p.command(s,"village",{"control":"approve","id":id})
	for i in range(4):
		for id in ["frame_bundle","tool_chest","drinking_barrel","standard_water_crate"]: m.deploy(w.village,id)
	var started=Time.get_ticks_usec()
	for i in range(30): p.worlds.tick_world(w,60)
	var sim_ms=(Time.get_ticks_usec()-started)/1000.0
	assert(m.valid(w.village,w.seconds)); p.command(s,"fork"); p.command(s,"fork"); w=p.worlds.get_world(); w.paused=false
	game._show_planet(); game.modal._scene("village"); await create_timer(1).timeout
	var frames=[]; var last=Time.get_ticks_usec(); var peak_draws=0
	for i in range(240):
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-last)/1000.0); last=now
		peak_draws=maxi(peak_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	frames.sort()
	var report={"device":RenderingServer.get_video_adapter_name(),"platform":OS.get_name(),"renderer":"native OpenGL compatibility","resolution":"1440x900","frames":240,"worlds":3,"simulated_seconds":1800,"simulation_ms":sim_ms,"village_history_per_world":60,"watershed_history_per_world":120,"median_ms":frames[120],"p95_ms":frames[228],"peak_draw_calls":peak_draws,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"planet_save_bytes":JSON.stringify(p.serialize()).to_utf8_buffer().size(),"not_tested":["Android physical device","Web browser","30 minute real-time thermal run"]}
	FileAccess.open("res://artifacts/village-benchmark-v014.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")); print(JSON.stringify(report))
	game._close_modal(); s.close_science(); quit()
