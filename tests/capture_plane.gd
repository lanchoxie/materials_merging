extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.47: the floatplane at the shore, then in flight over the
## coast (far terrain, curved horizon) at two altitudes.
const Shape=preload("res://scripts/planet_shape.gd")

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v047"))
	root.get_texture().get_image().save_png("res://artifacts/v047/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	for i in range(20): await process_frame
	preload("res://scripts/test_mode.gd").give_plane(s)
	game._show_planet_v2(); await process_frame; var panel=game.modal
	v.world.paused=true
	panel._enter(); for i in range(10): await process_frame
	var shore=Vector2.INF
	for i in range(1,900):
		var q=Vector2(-i*4.0,445.0)
		if Shape.is_ocean(q.x,q.y): shore=q; break
	panel.test_teleport(shore+Vector2(8,0),"海岸"); for i in range(10): await process_frame
	var w=panel.view.walker; w.position=shore+Vector2(9,4); w.reset_height()
	v.plane_at={"x":shore.x-2.0,"z":shore.y,"heading":PI/2}; panel.view.park_plane(Vector2(shore.x-2.0,shore.y),PI/2)
	var to=Vector2(shore.x-2.0,shore.y)-w.position; w.yaw=atan2(-to.x,-to.y); w.pitch=-0.12
	for i in range(40): await process_frame
	await shot("parked")
	w.position=shore+Vector2(2.5,0); w.reset_height(); panel._collect(); for i in range(5): await process_frame
	var p=panel.view.plane
	# Over the sea, heading east toward the continent, climbing.
	p.position=shore+Vector2(-700,200); p.heading=-PI/2-0.25; p.airborne=true; p.altitude=150.0; p.speed=50.0; p.throttle=0.8; p.pitch_target=0.0
	for i in range(80): await process_frame
	await shot("flight-150")
	p.altitude=380.0; p.position=shore+Vector2(-1200,-300); p.heading=-PI/2+0.4
	panel.view.far_terrain.centre=Vector2.INF
	for i in range(90): await process_frame
	await shot("flight-380")
	print("V047 CAPTURE done (%s)" % tag); quit(0)
