extends "res://tests/test_ranch13_ui.gd"
## Screenshot helper (not a test) for the v0.33 visual polish pass: island residents, first-person
## hands and tools, planet animals, villagers, water and biomes. Run windowed with a suffix:
##   ... --script res://tests/capture_polish.gd -- --release-ui-test --tag=before
var tag="now"
var exp=""

func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): tag=a.get_slice("=",1)
		if a.begins_with("--exp="): exp=a.get_slice("=",1)
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(200).timeout.connect(func(): quit(2))

func shot(file: String) -> void:
	await create_timer(0.6).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/polish/%s-%s.png" % [file,tag])

func settle(panel) -> void:
	panel._sync(); await process_frame
	while not panel.view.stream.pending.is_empty(): await process_frame
	await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/polish"))
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=60000; s.materials=[10000,10000,10000]
	# --- Island: houses, residents and the walk view.
	for i in [0,1,2,6,7,8]:
		if not s.plots[i].unlocked: s.buy_plot(i)
	s.town_place(3,"engineer_house",0,0); s.town_place(3,"canteen",6,0); s.town_place(3,"doctor_dorm",0,6)
	s.town_place(3,"street_lamp",6,6); s.town_place(3,"young_tree",8,7)
	s.campus_build(5,"institute")
	s.campus.elapsed=90; s.campus.day_time=90
	s.campus_hire("engineer"); s.campus_hire("engineer"); s.campus_hire("doctor")
	game._sync_world(); await process_frame
	await shot("island-overview")
	game._show_island_walk(); var walk=game.modal
	var p=s.plots[3]
	walk.walker.position=Vector2(p.x*3+1.4,p.z*3+1.6); walk.walker.reset_height()
	var d=Vector3(p.x*3-0.4,0.4,p.z*3-0.4)-walk.walker.eye(); walk.walker.yaw=atan2(-d.x,-d.z); walk.walker.pitch=atan2(d.y,Vector2(d.x,d.z).length()); walk._camera()
	for i in range(30): await process_frame
	await shot("island-walk")
	var campus=walk.world.get_node_or_null("CampusLife")
	if campus!=null and not campus.actors.is_empty():
		var n: Node3D=campus.actors.values()[0].node
		var front: Vector3=n.global_transform.basis.z.normalized()*1.5
		walk.walker.position=Vector2(n.global_position.x+front.x,n.global_position.z+front.z); walk.walker.reset_height()
		d=n.global_position+Vector3(0,0.4,0)-walk.walker.eye(); walk.walker.yaw=atan2(-d.x,-d.z); walk.walker.pitch=atan2(d.y,Vector2(d.x,d.z).length()); walk._camera()
		campus.set_process(false)
		for i in range(5): await process_frame
		await shot("island-resident")
		campus.set_process(true)
	game._close_modal(); await process_frame
	# --- Planet: the home meadow with animals, villagers, a pen and the river.
	var v=s.planet.v2; var t=v.construction.terrain
	v.field.stock={"timber":16,"stone":16,"fiber":8,"fruit":12,"grain":12,"soil":0}
	game._show_planet_v2(); await process_frame; var panel=game.modal
	v.world.elapsed=20.0; v.world.paused=false
	v.settlement.era=1; v.settlement.people=[{"id":1,"name":"禾苗","health":1.0,"hunger":0.1,"x":15.0,"z":14.0,"task":"安家"},{"id":2,"name":"石川","health":1.0,"hunger":0.1,"x":14.0,"z":15.0,"task":"安家"}]
	panel._select_region("meadow"); panel._enter(); panel._equip_item("tool:collect")
	look(panel,Vector2(16,19),Vector3(13,1,12)); panel._sync()
	if exp.contains("noshadow"): panel.view.sun.shadow_enabled=false
	if exp.contains("nosky"): panel.view.env.background_mode=Environment.BG_COLOR
	if exp.contains("nofill"): panel.view.fill.visible=false
	if exp.contains("nofog"): panel.view.env.fog_enabled=false
	for i in range(40): await process_frame
	await shot("meadow-villagers")
	var herd=v.world.regions.meadow.animals
	if not herd.is_empty():
		var c: Vector3=panel.view.CENTERS.meadow; var a=herd[0]
		var at=Vector2(c.x+float(a.x)*2.2,c.z+float(a.z)*2.2)
		look(panel,at+Vector2(2.2,1.6),Vector3(at.x,t.ground(at)+0.3,at.y)); panel._sync()
		for i in range(30): await process_frame
		await shot("meadow-animals")
	var wet: Vector3=panel.view.CENTERS.wetland
	var rx=t.river_x(wet.z)
	look(panel,Vector2(rx+3.5,wet.z+3),Vector3(rx,0.2,wet.z-6)); panel._sync()
	for i in range(30): await process_frame
	await shot("river")
	var bird: Node3D=panel.view.flock.get_child(0)
	look(panel,Vector2(rx+3.5,wet.z+3),bird.global_position)
	await shot("birds")
	# --- Hands and tools.
	look(panel,Vector2(10,10),Vector3(10,t.ground(Vector2(10,4))+1.0,4)); panel._sync()
	panel._equip_item("tool:remove"); for i in range(10): await process_frame
	await shot("hands-hammer")
	panel._equip_item("tool:scan"); for i in range(10): await process_frame
	await shot("hands-scan")
	# --- Wild boars in the 千米林海 and a far forest.
	panel._equip_item("tool:collect")
	look(panel,Vector2(1348,1354),Vector3(1348,t.ground(Vector2(1348,1346))+0.6,1346)); await settle(panel)
	for i in range(40): await process_frame
	await shot("forest-boars")
	for key in panel.view.life_view.moving:
		if not str(key).contains("/animal/"): continue
		var n: Node3D=panel.view.life_view.moving[key]; var g=n.global_position
		var side: Vector3=n.global_transform.basis.x.normalized()*2.2-n.global_transform.basis.z.normalized()*1.2
		look(panel,Vector2(g.x+side.x,g.z+side.z),g+Vector3(0,0.35,0))
		panel.view.life_view.set_process(false)
		for i in range(10): await process_frame
		await shot("wild-close"); panel.view.life_view.set_process(true); break
	game.queue_free(); await process_frame
	print("POLISH CAPTURE done (%s)" % tag); quit(0)
