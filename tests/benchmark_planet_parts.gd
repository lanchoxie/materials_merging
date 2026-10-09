extends "res://tests/capture_earth_ux.gd"
## Performance probe (not a test): what each planet system costs per call, in the hills.

func clock(label: String,n: int,f: Callable) -> void:
	var worst=0; var total=0
	for i in range(n):
		var t0=Time.get_ticks_usec(); f.call(i); var dt=Time.get_ticks_usec()-t0
		total+=dt; worst=maxi(worst,dt)
	print("PART %-28s avg %7.2f ms  worst %7.2f ms" % [label,total/1000.0/n,worst/1000.0])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	v.world.elapsed=20.0
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._select_region("meadow"); panel._enter()
	panel.test_teleport(Vector2(900,-400),"hills"); for i in range(90): await process_frame
	var view=panel.view; var t=view.terrain; var w=view.walker
	w.movement=Vector2(0.3,-1); w.running=true
	await clock("walker.step",120,func(i): w.step(1.0/60))
	w.stop()
	var key=t.chunk_at(w.position)
	await clock("stream._build (cached terrain)",6,func(i): view.stream._build(key+Vector2i(i%3,i/3)))
	t._height_cache.clear(); t._cave_columns.clear()
	await clock("stream._build (cold terrain)",6,func(i): view.stream._build(key+Vector2i(5+i%3,i/3)))
	await clock("planet tick 1s (v._step)",20,func(i): v.world.elapsed+=1; v._step())
	await clock("panel._sync",30,func(i): panel._sync())
	await clock("panel._live",30,func(i): panel._live())
	await clock("panel._aim",30,func(i): panel._aim())
	await clock("panel._update_actor",30,func(i): panel._update_actor())
	await clock("Target.query",20,func(i): v.Target.query(v))
	await clock("construction.trace",20,func(i): v.construction.trace(v.actor.eye,v.actor.direction))
	await clock("construction_view.preview",20,func(i): view.construction_view.preview(v.construction,v.actor,"observe",s.planet.products,""))
	await clock("field.nodes",20,func(i): v.field.nodes(w.position,6))
	await clock("combat.entities",20,func(i): v.combat.entities(v))
	await clock("tree_records x9",20,func(i): for dz in range(-1,2): for dx in range(-1,2): t.tree_records(t.chunk_at(w.position)+Vector2i(dx,dz)))
	await clock("combat.tick",60,func(i): v.combat.tick(1.0/60,v,true))
	await clock("journey.track",60,func(i): v.journey.track(w.position+Vector2(i*9,0)))
	await clock("state.tick (island) 1/60",60,func(i): s.tick(1.0/60))
	await clock("view._terrain",30,func(i): view._terrain(0))
	await clock("population.observe",30,func(i): v.population.observe(w.position))
	game.queue_free(); await process_frame
	print("PART done"); quit(0)
