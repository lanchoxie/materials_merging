extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.49: 溪石部落 building, the finished village, the chief's menu.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v049"))
	root.get_texture().get_image().save_png("res://artifacts/v049/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	for i in range(20): await process_frame
	# Let the tribe settle and build part of the village.
	for i in range(70): v.world.elapsed=int(v.world.elapsed)+1; v._step()
	game._show_planet_v2(); await process_frame; var panel=game.modal
	v.world.paused=true
	panel._enter(); for i in range(10): await process_frame
	var home: Vector2=v.natives.home
	panel.test_teleport(home+Vector2(3,12),"部落"); for i in range(20): await process_frame
	var w=panel.view.walker; w.position=home+Vector2(5,13); w.reset_height(); var to=home-w.position; w.yaw=atan2(-to.x,-to.y); w.pitch=-0.05
	panel._sync(); for i in range(40): await process_frame
	await shot("building")
	for i in range(600): v.world.elapsed=int(v.world.elapsed)+1; v._step()
	v.natives.members[0].x=home.x+1.0; v.natives.members[0].z=home.y+4.2
	w.position=home+Vector2(2,9); w.reset_height(); to=home+Vector2(0,2)-w.position; w.yaw=atan2(-to.x,-to.y); w.pitch=-0.02
	panel._sync(); for i in range(60): await process_frame
	await shot("village")
	panel._native_menu(); for i in range(10): await process_frame
	await shot("chief-menu")
	print("V049 CAPTURE done (%s)" % tag); quit(0)
