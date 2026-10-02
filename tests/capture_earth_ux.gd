extends "res://tests/capture_polish.gd"
## Screenshot helper (not a test) for the v0.33.1 Earth usability pass: the god view, biomes and
## anything odd on the ground. Run windowed: ... --script res://tests/capture_earth_ux.gd -- --release-ui-test --tag=X
const TestMode=preload("res://scripts/test_mode.gd")

func shot(file: String) -> void:
	await create_timer(0.6).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/earth-ux/%s-%s.png" % [file,tag])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/earth-ux"))
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2; var t=v.construction.terrain
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._select_region("meadow"); panel._enter(); panel._equip_item("tool:collect")
	var spots=[["camp",Vector2(16,22)],["woods",Vector2(-124,68)],["ridge",Vector2(196,-188)],["frontier",Vector2(1348,1348)]]
	for b in TestMode.BIOMES: spots.append([b,TestMode.biome_spot(v.environment,b)])
	for row in spots:
		var at: Vector2=row[1]
		look(panel,at,Vector3(at.x+6,t.ground(at+Vector2(6,-8))+0.2,at.y-8)); await settle(panel)
		for i in range(20): await process_frame
		print("SPOT %s at %s biome %s" % [row[0],at,v.environment.biome_at(at)])
		await shot("fp-"+row[0])
	# A walk from home to the ridge with a waypoint and a hut there, then the god view and the map.
	var j=v.journey
	for i in range(0,80): j.track(Vector2(16,22).lerp(Vector2(190,-180),i/79.0)+Vector2(sin(i*0.4)*6,0))
	j.points["1"]={"x":190.0,"z":-180.0,"name":"我的路标 1"}; j.serial=2; j.revision+=1
	j.points["2"]={"x":40.0,"z":30.0,"name":"我的路标 2"}; j.serial=3; j.revision+=1
	var c=v.construction
	for dx in range(3):
		for dy in range(3):
			var x=196+dx; var z=-184; var y=c.base(Vector3i(x,0,z))+dy
			c.blocks[c.key(Vector3i(x,y,z))]={"x":x,"y":y,"z":z,"kind":"block","source":"t"}
	c.sources["t"]={"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"test"},"remaining":0}
	c.revision+=1
	look(panel,Vector2(192,-176),Vector3(197,c.base(Vector3i(197,0,-184))+1,-184)); await settle(panel)
	for i in range(20): await process_frame
	await shot("fp-beacon")
	panel._equip_item("tool:collect")
	panel._enter(); await settle(panel); for i in range(30): await process_frame
	await shot("god-ridge")
	panel._open_world_map(); for i in range(5): await process_frame
	await shot("world-map")
	var map=panel.get_child(panel.get_child_count()-1); map._zoom_to(map.SCALES[0]); for i in range(3): await process_frame
	await shot("world-map-full")
	map.queue_free(); await process_frame
	panel._select_region("meadow"); for i in range(30): await process_frame
	await shot("god-home")
	panel.view.close_view=true; for i in range(30): await process_frame
	await shot("god-close")
	panel._tab("era"); await process_frame; panel._sync(); await process_frame
	await shot("era-tab")
	# The 公共仓库 in first person.
	var depot: Vector2=v.ranch.depot_at(v)+Vector2(0,-1.3)
	v.world.food=4
	look(panel,depot+Vector2(0,2.6),Vector3(depot.x,t.ground(depot)+0.6,depot.y)); await settle(panel)
	for i in range(10): await process_frame
	await shot("depot-aim")
	print("DEPOT prompt: ",panel.aim_label.text)
	panel._collect(); print("DEPOT result: ",panel.message)
	game.queue_free(); await process_frame
	print("EARTH UX CAPTURE done (%s)" % tag); quit(0)
