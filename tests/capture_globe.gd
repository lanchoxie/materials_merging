extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.42: the globe god view, a mountain range and a coast in
## first person, the pin after walking, and the world map.
const Shape=preload("res://scripts/planet_shape.gd")

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v042"))
	root.get_texture().get_image().save_png("res://artifacts/v042/%s-%s.png" % [file,tag])

## First land cell along a ray whose height test passes.
func find(from: Vector2,dir: Vector2,test: Callable) -> Vector2:
	for i in range(1,900):
		var p=from+dir*i*8.0
		if test.call(p): return p
	return Vector2.INF

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var p=s.planet
	for i in range(20): await process_frame
	p.command(s,"join")
	game._show_planet_v2(); await process_frame; var panel=game.modal
	for i in range(20): await process_frame
	await shot("globe-home")
	var t=panel.view.terrain
	var peak=find(Vector2(-4700,4200)+Vector2(-300,-300),Vector2(1,1).normalized(),func(q): return Shape.mountains(q.x,q.y,Shape.continent(q.x,q.y))>=30.0)
	print("peak ",peak)
	if peak!=Vector2.INF:
		panel.test_teleport(peak+Vector2(-18,-18),"山脉"); for i in range(60): await process_frame
		var w=panel.view.walker; var to=peak-w.position; w.yaw=atan2(-to.x,-to.y); w.pitch=0.35
		for i in range(30): await process_frame
		await shot("mountains")
	var shore=find(Vector2(0,0),Vector2(-1,0.15).normalized(),func(q): return Shape.continent(q.x,q.y)<0.0)
	print("shore ",shore)
	if shore!=Vector2.INF:
		var land=shore+Vector2(1,-0.15).normalized()*30.0
		panel.test_teleport(land,"海岸"); for i in range(60): await process_frame
		var w=panel.view.walker; var to=shore-w.position; w.yaw=atan2(-to.x,-to.y); w.pitch=-0.1
		for i in range(30): await process_frame
		await shot("coast")
	panel._enter(); for i in range(40): await process_frame
	await shot("globe-pin")
	panel._open_world_map(); for i in range(10): await process_frame
	await shot("world-map")
	var map=panel.get_children().back(); map._zoom_to(map.SCALES[0]); for i in range(5): await process_frame
	await shot("world-map-full")
	print("V042 CAPTURE done (%s) %s" % [tag,t.region_at(Vector2.ZERO)]); quit(0)
