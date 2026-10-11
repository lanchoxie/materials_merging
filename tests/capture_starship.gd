extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.48: the ship on Earth, the star map, 赤砂星 from orbit, and
## on the ground there.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v048"))
	root.get_texture().get_image().save_png("res://artifacts/v048/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	for i in range(20): await process_frame
	preload("res://scripts/test_mode.gd").give_ship(s)
	game._show_planet_v2(); await process_frame; var panel=game.modal
	s.planet.v2.world.paused=true
	panel._enter(); for i in range(20): await process_frame
	panel._sync(); for i in range(10): await process_frame
	var w=panel.view.walker; var at=panel.view.ship_at
	w.position=at+Vector2(9,11); w.reset_height(); var to=at-w.position; w.yaw=atan2(-to.x,-to.y); w.pitch=0.0
	for i in range(30): await process_frame
	await shot("ship-earth")
	w.position=at+Vector2(3.5,0); w.reset_height(); panel._collect(); for i in range(10): await process_frame
	await shot("star-map")
	game._launch("ember"); for i in range(40): await process_frame
	await shot("ember-orbit")
	var orbit=game.modal; s.planet.v2.world.paused=true
	orbit._enter(); for i in range(30): await process_frame
	orbit._sync(); for i in range(10): await process_frame
	var ow=orbit.view.walker; var ship=orbit.view.ship_at
	var spot=ship+Vector2(-12,7)
	for k in range(24):
		var cand=ship+Vector2.from_angle(k*TAU/24.0)*13.0
		if not orbit.view.terrain.blocked(cand,[]) and not orbit.view.terrain.blocked(cand+(ship-cand).normalized()*2.0,[]): spot=cand; break
	ow.position=spot; ow.reset_height(); var to2=ship-ow.position; ow.yaw=atan2(-to2.x,-to2.y); ow.pitch=0.06
	s.planet.v2.world.elapsed=int(s.planet.v2.world.elapsed)+30; orbit._sync()
	for i in range(60): await process_frame
	await shot("ember-ground")
	print("V048 CAPTURE done (%s)" % tag); quit(0)
