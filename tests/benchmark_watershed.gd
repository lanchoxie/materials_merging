extends SceneTree
const Main=preload("res://scripts/main.gd")
func _initialize() -> void:
	root.size=Vector2i(1440,900); run.call_deferred()
func run() -> void:
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._show_planet(); var p=game.state.planet
	var s=game.state; s.coins=9000
	p.command(s,"join"); p.command(s,"activate_watershed",{"era":"carboniferous"})
	for i in range(12): p.worlds.tick_world(p.worlds.get_world(),60)
	p.command(s,"fork"); p.command(s,"fork")
	var w=p.worlds.get_world()
	for site in ["headwater","marsh","estuary"]:
		for id in ["screen_station","screen_cartridge","buffer_raft"]:
			p.command(s,"deploy",{"world_id":w.id,"site_id":site,"recipe":id,"token":p.shipment_serial})
		if site!="headwater":
			for id in ["oxygen_station","oxygen_cartridge","copper_compact" if site=="marsh" else "aluminum_light"]:
				p.command(s,"deploy",{"world_id":w.id,"site_id":site,"recipe":id,"token":p.shipment_serial})
	p.command(s,"watershed",{"site":"marsh","control":"harvest_target"})
	p.command(s,"deploy",{"world_id":w.id,"site_id":"marsh","recipe":"harvest_box","token":p.shipment_serial})
	w.paused=false; game.modal._scene("watershed")
	await create_timer(1).timeout
	var frames=[]; var last=Time.get_ticks_usec(); var peak_draws=0
	for i in range(240):
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-last)/1000.0); last=now
		peak_draws=maxi(peak_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	frames.sort()
	var report={"platform":OS.get_name(),"renderer":"native OpenGL compatibility","resolution":"1440x900","frames":240,"worlds":3,"history_per_world":120,"median_ms":frames[120],"p95_ms":frames[228],"peak_draw_calls":peak_draws,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"planet_save_bytes":JSON.stringify(p.serialize()).to_utf8_buffer().size(),"not_tested":["Android physical device","Web browser"]}
	FileAccess.open("res://artifacts/watershed-benchmark-v013.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")); print(JSON.stringify(report))
	game._close_modal(); game.state.close_science(); quit()
