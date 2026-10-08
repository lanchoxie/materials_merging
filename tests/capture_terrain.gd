extends "res://tests/capture_earth_ux.gd"
## Screenshot helper (not a test) for v0.33.2 relief and caves. Run windowed:
##   ... --script res://tests/capture_terrain.gd -- --release-ui-test --tag=X

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/earth-ux"))
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2; var t=v.construction.terrain
	v.world.elapsed=20.0
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._select_region("meadow"); panel._enter(); panel._equip_item("tool:collect")
	# Hills: look across the far land from a high point.
	var best=Vector2(900,-400); var top=-INF
	for i in range(60):
		var p=Vector2(700+i*15,-400)
		if t.ground(p)>top: top=t.ground(p); best=p
	look(panel,best,Vector3(best.x+40,t.ground(best+Vector2(40,-30)),best.y-30)); await settle(panel)
	for i in range(20): await process_frame
	print("HILLS at %s height %.1f build %d us" % [best,top,panel.view.stream.last_build_us])
	await shot("hills")
	# A cave mouth: stand at its rim and look down into it.
	var mouth=Vector2.INF
	for x in range(400,1600,2):
		for z in range(-600,600,6):
			var p=Vector2(x,z)
			if t.column_has_cave(x,z) and t.ground(p)<t.natural_height(p)-2.5: mouth=p; break
		if mouth!=Vector2.INF: break
	print("MOUTH at %s" % mouth)
	if mouth!=Vector2.INF:
		var rim=mouth+Vector2(4,3)
		look(panel,rim,Vector3(mouth.x,t.ground(mouth),mouth.y)); await settle(panel)
		for i in range(20): await process_frame
		await shot("cave-mouth")
		# Inside: stand on the mouth floor and look along the tunnel.
		look(panel,mouth,Vector3(mouth.x+6,t.ground(mouth)+1.2,mouth.y+2)); await settle(panel)
		panel.view.walker.position=mouth; panel.view.walker.reset_height(); panel.view._camera(0)
		for i in range(20): await process_frame
		print("INSIDE feet %.1f natural %.1f" % [panel.view.walker.feet_y,t.natural_height(mouth)])
		await shot("cave-inside")
	panel._enter(); await settle(panel); for i in range(30): await process_frame
	await shot("god-hills")
	panel._open_world_map(); for i in range(5): await process_frame
	var map=panel.get_child(panel.get_child_count()-1); map._zoom_to(map.SCALES[1]); map.center=Vector2(900,-400); map._refresh()
	for i in range(3): await process_frame
	await shot("map-relief")
	map._zoom_to(map.SCALES[0]); for i in range(3): await process_frame
	await shot("map-relief-full")
	map.queue_free(); await process_frame
	var worst=0
	for k in range(6):
		var key=t.chunk_at(Vector2(800+k*16,-300)); var st=Time.get_ticks_usec(); panel.view.stream._build(key); worst=maxi(worst,Time.get_ticks_usec()-st)
	print("CHUNK worst build %d us" % worst)
	game.queue_free(); await process_frame
	print("TERRAIN CAPTURE done (%s)" % tag); quit(0)
