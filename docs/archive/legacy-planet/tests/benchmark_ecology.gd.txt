extends SceneTree
const Main=preload("res://scripts/main.gd")
func _initialize() -> void:
	root.size=Vector2i(1440,900); run.call_deferred()
func run() -> void:
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._show_planet(); var p=game.state.planet
	p.command(game.state,"join")
	for i in range(12): p.worlds.tick_world(p.worlds.get_world(),60)
	p.command(game.state,"fork"); p.command(game.state,"fork")
	var w=p.worlds.get_world()
	for id in ["microbe","fish"]:
		p.worlds.ecology.deploy(w.ecology,id,"oxygen_station"); p.worlds.ecology.deploy(w.ecology,id,"oxygen_cartridge")
	w.paused=false; game.modal._choose_recipe("oxygen_cartridge"); game.modal.section="observe"; game.modal._redraw()
	await create_timer(1).timeout
	var frames=[]; var last=Time.get_ticks_usec(); var peak_draws=0
	for i in range(240):
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-last)/1000.0); last=now
		peak_draws=maxi(peak_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	frames.sort()
	var report={"platform":OS.get_name(),"renderer":"native OpenGL compatibility","resolution":"1440x900","frames":240,"worlds":3,"history_per_world":120,"median_ms":frames[120],"p95_ms":frames[228],"peak_draw_calls":peak_draws,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"planet_save_bytes":JSON.stringify(p.serialize()).to_utf8_buffer().size(),"not_tested":["Android physical device","Web browser"]}
	FileAccess.open("res://artifacts/ecology-benchmark-v012.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")); print(JSON.stringify(report))
	game._close_modal(); game.state.close_science(); quit()
