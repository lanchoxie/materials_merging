extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	root.size=Vector2i(1440,900); run.call_deferred()
func run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._show_planet()
	var p=game.state.planet
	p.command(game.state,"join"); p.command(game.state,"fork",{"dry":true})
	p.command(game.state,"deploy",{"world_id":"trial_a","site_id":"shelf","token":p.shipment_serial})
	p.command(game.state,"pause")
	await create_timer(1.0).timeout
	var frames=[]; var last=Time.get_ticks_usec(); var peak_draws=0
	for i in range(180):
		await process_frame
		var now=Time.get_ticks_usec(); frames.append((now-last)/1000.0); last=now
		peak_draws=maxi(peak_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	frames.sort()
	var report={"platform":OS.get_name(),"renderer":"native OpenGL compatibility","resolution":"1440x900","frames":frames.size(),"median_ms":frames[90],"p95_ms":frames[171],"peak_draw_calls":peak_draws,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"not_tested":["Android physical device","Web browser"]}
	FileAccess.open("res://artifacts/planet-benchmark-v011.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	game._close_modal(); game.state.close_science(); quit()
