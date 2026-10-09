extends "res://tests/capture_earth_ux.gd"
## Performance probe (not a test): chunk mesh build cost at home, in the hills, with caves off.

func build_time(view,keys: Array) -> float:
	var total=0
	for k in keys:
		var t0=Time.get_ticks_usec(); view.stream._build(k); total+=Time.get_ticks_usec()-t0
	return total/1000.0/keys.size()

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v=game.state.planet.v2
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._enter(); for i in range(20): await process_frame
	var view=panel.view; var t=view.terrain
	var home=[]; var hills=[]
	for i in range(6): home.append(Vector2i(i%3,i/3)); hills.append(t.chunk_at(Vector2(900,-400))+Vector2i(i%3,i/3))
	print("CHUNK home      %.1f ms" % build_time(view,home))
	print("CHUNK hills     %.1f ms" % build_time(view,hills))
	print("CHUNK hills2    %.1f ms" % build_time(view,hills))
	var saved=t.rules.cave_begin; t.rules.cave_begin=1e9; t._cave_columns.clear()
	print("CHUNK no caves  %.1f ms" % build_time(view,hills))
	t.rules.cave_begin=saved; t._cave_columns.clear()
	var cols=0; var cave_cols=0
	for k in hills:
		for z in range(16):
			for x in range(16):
				cols+=1; cave_cols+=1 if t.column_has_cave(k.x*16+x,k.y*16+z) else 0
	print("CHUNK cave columns %d / %d" % [cave_cols,cols])
	var trees=0
	for k in hills: trees+=t.tree_records(k).size()
	print("CHUNK trees per chunk %.1f" % (trees/6.0))
	var t0=Time.get_ticks_usec(); for k in hills: t.tree_records(k)
	print("CHUNK tree_records %.2f ms" % ((Time.get_ticks_usec()-t0)/6000.0))
	game.queue_free(); await process_frame
	quit(0)
