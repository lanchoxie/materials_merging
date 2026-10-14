extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.50: the ore grain underground, and the remembered position
## (leave first person and come back to the same spot).

func shot(file: String) -> void:
	await create_timer(0.9).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v050"))
	root.get_texture().get_image().save_png("res://artifacts/v050/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2; var t=v.construction.terrain
	for i in range(20): await process_frame
	var panel=null
	# Cut into the hematite layer and stand in the tunnel so the ore walls fill the view.
	var ore=Vector2i(60,-40)
	for ring in range(1,40):
		var found=null
		for dx in range(-ring,ring+1):
			for dz in range(-ring,ring+1):
				var q=ore+Vector2i(dx,dz)
				if t.natural_material(Vector3i(q.x,-18,q.y))=="hematite" and t.ground(Vector2(q))>2.0: found=q; break
			if found!=null: break
		if found!=null: ore=found; break
	var floor_y=floori(t.ground(Vector2(ore)))-17
	for dy in range(-2,3):
		for dx in range(-2,3):
			for dz in range(-2,3):
				var c=Vector3i(ore.x+dx,floor_y+dy,ore.y+dz)
				if dy==-2: continue
				v.nature.set_voxel(c,"",t)
	v.nature.touch(Vector2(ore),t)
	game._show_planet_v2(); await process_frame; panel=game.modal
	v.world.paused=true
	panel._enter(); for i in range(10): await process_frame
	panel.test_teleport(Vector2(ore), "矿区"); for i in range(30): await process_frame
	var w=panel.view.walker
	w.position=Vector2(ore); w.feet_y=float(floor_y); w.last_position=w.position; w.yaw=0.4; w.pitch=0.02
	panel._sync(); for i in range(40): await process_frame
	await shot("ore-grain")
	# Remember the spot: step out of first person, walk far away, and come back.
	var spot=Vector2(w.position.x,w.position.y); var yaw=w.yaw
	panel._enter(); for i in range(4): await process_frame
	w.position=Vector2(10,15); w.reset_height()
	panel._enter(); for i in range(10): await process_frame
	panel._sync(); for i in range(10): await process_frame
	w=panel.view.walker
	check_shot(w.position.distance_to(spot)<0.01 and absf(w.yaw-yaw)<0.01, spot)
	await shot("remembered-position")
	print("V050 CAPTURE done (%s)" % tag); quit(0)

func check_shot(ok: bool,spot: Vector2) -> void:
	print("V050 remember: %s (at %s)" % ["OK" if ok else "FAILED",str(spot)])
