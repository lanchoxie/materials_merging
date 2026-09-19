extends SceneTree
const Main=preload("res://scripts/main.gd")
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): push_error("Benchmark requires -- --release-ui-test"); quit(2); return
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("Modern benchmark timeout"); quit(2))
func run() -> void:
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var p=s.planet; p.command(s,"join"); p.command(s,"activate_watershed",{"era":"carboniferous"}); p.command(s,"activate_village"); p.command(s,"activate_habitat"); p.command(s,"activate_industry",{"era":"ww2"}); p.command(s,"activate_modern")
	var m=p.worlds.village; var w=p.worlds.get_world()
	for id in ["mill","market"]: p.command(s,"village",{"control":"approve","id":id})
	for i in range(4):
		for id in ["frame_bundle","tool_chest","drinking_barrel","standard_water_crate"]: m.deploy(w.village,id)
	var industry=p.worlds.industry
	industry.deploy(w.industry,"industry_power","generator_set"); industry.deploy(w.industry,"industry_power","heat_recovery")
	for i in range(4): industry.deploy(w.industry,"industry_depot","fuel_can")
	for id in industry.rules.loads: industry.deploy(w.industry,"industry_"+str(id),"copper_wire")
	industry.control(w.industry,"policy","production")
	var modern=p.worlds.modern
	for item in [["field","modern_silicon"],["roof","modern_perovskite"],["battery","modern_battery"],["compute","modern_server"],["cooling","modern_fan"],["cooling","modern_aluminum_sink"],["recycle","modern_recycler"],["recycle","modern_scrap"]]: modern.deploy(w.modern,"modern_"+item[0],item[1])
	modern.control(w.modern,"park")
	var started=Time.get_ticks_usec()
	for i in range(30): p.worlds.tick_world(w,60)
	var sim_ms=(Time.get_ticks_usec()-started)/1000.0
	assert(modern.valid(w.modern,w.seconds)); assert(industry.valid(w.industry,w.seconds)); assert(m.valid(w.village,w.seconds)); assert(p.worlds.habitat.valid(w.habitat,w.seconds)); p.command(s,"fork"); p.command(s,"fork"); w=p.worlds.get_world(); w.paused=false
	var sample=s.product_snapshot(s._new_reactor(20,"water",0)); s.storage.add_product(sample,1); p.command(s,"archive_material",{"batch_id":sample.id})
	var record=str(p.materials.records.keys()[0]); var values={"density_kg_m3":2700.0,"conductivity_W_mK":235.0,"resistivity_ohm_m":2.8264e-8}
	for kind in ["sink","wire"]: p.command(s,"propose_material",{"record_id":record,"kind":kind,"mode":"same_size","properties":values})
	for id in p.materials.designs:
		var d=p.materials.designs[id]; var site="modern_cooling" if d.kind=="sink" else "industry_factory"
		p.command(s,"deploy",{"world_id":w.id,"site_id":site,"recipe":id,"token":p.shipment_serial})
	for i in range(10): p.worlds.tick_world(w,60)
	var full_history_bytes=JSON.stringify(p.serialize(),"",true,true).to_utf8_buffer().size()
	var restore_start=Time.get_ticks_usec()
	assert(preload("res://scripts/planet_program.gd").new().restore(JSON.parse_string(JSON.stringify(p.serialize(),"",true,true)),s))
	var restore_ms=(Time.get_ticks_usec()-restore_start)/1000.0

	game._show_planet(); game.modal._scene("modern"); await create_timer(1).timeout
	var frames=[]; var last=Time.get_ticks_usec(); var peak_draws=0
	for i in range(240):
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-last)/1000.0); last=now
		peak_draws=maxi(peak_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	frames.sort()
	var report={"restore_ms":restore_ms,"custom_designs":p.materials.designs.size(),"device":RenderingServer.get_video_adapter_name(),"platform":OS.get_name(),"renderer":"native OpenGL compatibility","resolution":"1440x900","frames":240,"worlds":3,"simulated_seconds":1800,"simulation_ms":sim_ms,"full_history_habitat_entries_per_world":60,"render_modern_residents":w.modern.people.size(),"modern_history_per_world":60,"industry_history_per_world":60,"village_history_per_world":60,"watershed_history_per_world":120,"median_ms":frames[120],"p95_ms":frames[228],"peak_draw_calls":peak_draws,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"full_history_save_bytes":full_history_bytes,"not_tested":["Android physical device","Web browser","30 minute real-time thermal run"]}
	FileAccess.open("res://artifacts/player-benchmark-v018.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")); print(JSON.stringify(report))
	game._close_modal(); s.close_science(); quit()
