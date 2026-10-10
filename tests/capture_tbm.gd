extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.45: the 盾构机 parked on the planet, boring underground
## (chase camera + dashboard), the tunnel on foot, and 星锻岛's gear card.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v045"))
	root.get_texture().get_image().save_png("res://artifacts/v045/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	for i in range(20): await process_frame
	preload("res://scripts/test_mode.gd").give_tbm(s)
	game._show_planet_v2(); await process_frame; var panel=game.modal
	v.world.paused=true
	panel._enter(); for i in range(10): await process_frame
	panel.test_teleport(Vector2(60,-40),"矿区"); for i in range(20): await process_frame
	var w=panel.view.walker; w.yaw=0.0; v.tbm_at={}; panel._sync(); for i in range(10): await process_frame
	# Step back and to the side to see the whole machine.
	var c: Vector3i=panel.view.tbm.cell
	w.position=Vector2(c.x+4.5,c.z+6.0); w.reset_height(); var to=Vector2(c.x,c.z)-w.position; w.yaw=atan2(-to.x,-to.y); w.pitch=-0.05
	for i in range(30): await process_frame
	await shot("parked")
	w.position=Vector2(c.x,c.z+2.6); w.reset_height(); w.yaw=0.0; panel._collect(); for i in range(5): await process_frame
	var m=panel.view.tbm
	m.grade=-1
	for i in range(14): m.advance(v); m.busy=0.0
	m.grade=0
	for i in range(8): m.advance(v); m.busy=0.0
	m.message="掘进1米 · 切下9格"; for i in range(5): await process_frame
	m.movement=Vector2(0,-1); await create_timer(1.2).timeout; m.movement=Vector2.ZERO
	for i in range(30): await process_frame
	panel._aim()
	await shot("boring")
	panel._collect(); for i in range(10): await process_frame
	w.yaw=PI; w.pitch=0.1
	for i in range(30): await process_frame
	await shot("tunnel")
	game._close_all(); await process_frame
	game._show_starforge(); for i in range(3): await process_frame
	game.modal._tab("gear"); for i in range(5): await process_frame
	await shot("gear")
	print("V045 CAPTURE done (%s)" % tag); quit(0)
