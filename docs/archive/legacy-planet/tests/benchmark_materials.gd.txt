extends SceneTree
const Main=preload("res://scripts/main.gd")
func _initialize() -> void:
	root.size=Vector2i(1440,900); run.call_deferred()
func run() -> void:
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._show_planet(); var p=game.state.planet
	var s=game.state; s.coins=9000
	p.command(s,"join")
	var batch=s.product_snapshot(s._new_reactor(3,"oxygen",0)); s.storage.add_product(batch,2)
	p.command(s,"qualify",{"reference":"oxygen","batch_id":batch.id})
	for mode in ["same_size","same_mass"]: p.command(s,"compare_materials",{"mode":mode})
	for site in ["microbe","fish"]:
		for id in ["oxygen_station","oxygen_cartridge","copper_compact" if site=="microbe" else "aluminum_light"]:
			var info=p.recipe(id); p.command(s,"buy_feed",{"input":info.input}); p.command(s,"pack",{"recipe":id}); p.tick(info.seconds)
			p.command(s,"deploy",{"world_id":"home","site_id":site,"recipe":id,"token":p.shipment_serial})
	for i in range(12): p.worlds.tick_world(p.worlds.get_world(),60)
	p.command(s,"fork"); p.command(s,"fork")
	var w=p.worlds.get_world()
	for id in ["microbe","fish"]:
		p.command(s,"deploy",{"world_id":w.id,"site_id":id,"recipe":"oxygen_cartridge","token":p.shipment_serial})
		p.command(s,"ecology",{"site":id,"control":"flow"})
	w.paused=false; game.modal._choose_recipe("oxygen_cartridge"); game.modal.section="observe"; game.modal._redraw()
	await create_timer(1).timeout
	var frames=[]; var last=Time.get_ticks_usec(); var peak_draws=0
	for i in range(240):
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-last)/1000.0); last=now
		peak_draws=maxi(peak_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	frames.sort()
	var report={"platform":OS.get_name(),"renderer":"native OpenGL compatibility","resolution":"1440x900","frames":240,"worlds":3,"history_per_world":120,"median_ms":frames[120],"p95_ms":frames[228],"peak_draw_calls":peak_draws,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"planet_save_bytes":JSON.stringify(p.serialize()).to_utf8_buffer().size(),"not_tested":["Android physical device","Web browser"]}
	FileAccess.open("res://artifacts/materials-benchmark-v0121.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")); print(JSON.stringify(report))
	game._close_modal(); game.state.close_science(); quit()
