extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(90).timeout.connect(func(): quit(2))
func key(code: int) -> void:
	var e=InputEventKey.new(); e.physical_keycode=code; e.pressed=true; Input.parse_input_event(e); await process_frame
	e=InputEventKey.new(); e.physical_keycode=code; e.pressed=false; Input.parse_input_event(e); await process_frame
func button(node: Node,text: String):
	if node is Button and node.text.contains(text): return node
	for child in node.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func aim(panel,point: Vector3) -> void:
	# Prefer a clear ground-level approach rather than teleporting a test camera overhead.
	var options=[Vector2(0,2.6),Vector2(2.6,0),Vector2(0,-2.6),Vector2(-2.6,0)]
	for offset in options:
		var at=Vector2(point.x,point.z)+offset
		if panel.view.terrain.blocked(at): continue
		panel.view.travel(at)
		var delta=point-panel.view.walker.eye()
		panel.view.walker.yaw=atan2(-delta.x,-delta.z); panel.view.walker.pitch=atan2(delta.y,Vector2(delta.x,delta.z).length())
		panel.view._camera(0); panel._update_actor(); panel._aim()
		var target=game.state.planet.v2.Target.query(game.state.planet.v2)
		if target.get("type") in ["resource","block"]: return
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; s.coins=10000; var p=s.planet; var v=p.v2; var f=v.field
	var water=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(water,6)
	p.command(s,"join"); s.campus_build(3,"workshop"); s.campus_road(3); s.campus_assign_post(s.campus.people[0].id,"workshop")
	game._show_planet_v2(); await process_frame; await process_frame
	var panel=game.modal; v.world.paused=true; panel._select_region("meadow"); panel._enter()
	for id in ["home:0","home:1","home:2","home:3","home:4","home:5","home:6"]:
		var n=f.node(id); aim(panel,Vector3(n.x,n.y+0.3,n.z)); await process_frame
		check(panel.aim_label.text.contains(f.rules.resources[n.kind].node),"crosshair names aimed "+str(n.kind))
		if id=="home:0": await capture("field-gather-aim")
		var taps=int(f.rules.resources[n.kind].hits)
		if id=="home:0":
			var tap_at=panel.action_button.get_global_rect().get_center()
			await game._test_touch(tap_at,true); await game._test_touch(tap_at,false)
			check(f.changed.get(id,{}).get("hits")==1 and f.stock.timber==0,"mobile action button advances gathering once without an emulated duplicate")
			taps-=1
		for i in range(taps): await key(KEY_E)
		check(f.remaining(id,int(v.world.elapsed))>0,"input gathering exhausts persistent site "+id)
	check(f.stock.timber==8 and f.stock.stone==8 and f.stock.fiber==6 and f.stock.fruit==3,"real ground-level input gathers portable resources")
	panel._open_backpack(); await process_frame; await capture("field-backpack-raw")
	check(panel.backpack.items.has("raw:timber"),"new raw material appears in the same backpack")
	panel.backpack.workshop_requested.emit(); await process_frame; await process_frame
	check(not v.active and f.stock.timber==8,"travelling to island workshop keeps gathered stock")
	game.modal._choose_recipe("field_planter"); await process_frame
	check(button(game.modal,"加工采集材料")!=null and button(game.modal,"补充1份供料")==null,"natural recipe UI shows actual ingredients rather than supply purchase")
	button(game.modal,"加工采集材料").pressed.emit(); await process_frame
	check(p.job.get("recipe")=="field_planter" and f.stock.timber==5,"workshop button reserves gathered inputs")
	for i in range(180):
		if p.job.is_empty(): break
		s.tick(1)
	check(p.available_products("field_planter")==1,"engineer travel and work complete a gathered-material product")
	game.modal._redraw(); await process_frame
	await capture("field-workshop-planter")
	game._show_planet_v2(); await process_frame; panel=game.modal
	panel._select_region("meadow"); panel._equip_item("recipe:field_planter"); panel.view.travel(Vector2(15,17)); panel.view.walker.yaw=0; panel.view.walker.pitch=-0.9; panel.view._camera(0); panel._sync()
	await key(KEY_E)
	var planter_key=""
	for id in v.construction.blocks:
		if v.construction.blocks[id].kind=="planter": planter_key=id; break
	check(not planter_key.is_empty(),"first person uses manufactured planter from selected quick slot")
	if planter_key.is_empty(): quit(1); return
	var b=v.construction.blocks[planter_key]; aim(panel,Vector3(b.x,b.y+0.7,b.z)); panel._equip_item("seed:grain"); await key(KEY_E)
	check(f.gardens.has(planter_key),"seed shortcut sows the aimed physical planter")
	panel._equip_item("sample:"+water.id); var initial=s.storage.batch(water.id).quantity
	await key(KEY_E)
	check(f.gardens[planter_key].moisture>0.8 and s.storage.batch(water.id).quantity==initial-1,"water shortcut changes the local box and debits real water sample")
	v.advance(190); panel._sync(); panel._tool("observe"); await process_frame
	check(f.gardens[planter_key].growth>=1 and panel.aim_label.text.contains("收获"),"visible mature crop can be recognized at the crosshair")
	await capture("field-planter-grown")
	await key(KEY_E)
	check(f.stock.grain==3 and not f.gardens.has(planter_key),"harvest input carries crop into backpack once")
	await _build_cabin(panel)
	game._close_modal(); game._show_toolbox(); game.modal._tab("materials"); await process_frame; await process_frame
	check(button(game.modal,"取1份送入星球粮仓")!=null,"returned harvest is available in island toolbox")
	await capture("field-island-return")
	game.queue_free(); await process_frame
	print("RIVER FIELD UI: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func _build_cabin(panel) -> void:
	var s=game.state; var p=s.planet; var v=p.v2; var c=v.construction; var f=v.field
	# Revisit the same real site after regeneration, then process its yield locally.
	v.advance(480); var n=f.node("home:0"); aim(panel,Vector3(n.x,n.y+0.3,n.z))
	for i in range(3): await key(KEY_E)
	for recipe in ["field_floor","field_wall","field_roof"]:
		p.command(s,"pack",{"recipe":recipe})
		for i in range(240):
			if p.job.is_empty(): break
			s.tick(1)
		check(p.available_products(recipe)==1,"engineers provide actual cabin materials "+recipe)
	# Build a small open-front cabin: raised stone floor, four columns and six roof cells.
	for x in range(6,9):
		for z in range(12,14): _place_above(v,p,x,z,0,"floor","field_floor")
	for x in [6,8]:
		for z in [12,13]:
			for y in [1,2]: _place_above(v,p,x,z,y,"block","field_wall")
	for z in [12,13]:
		for x in [6,8]: _place_above(v,p,x,z,3,"roof","field_roof")
	for z in [12,13]:
		# Side-face placement onto the roof edge avoids a free-floating center cell.
		v.actor={"eye":Vector3(7,3.5,z),"feet":Vector3(7,1.88,z+2),"direction":Vector3.LEFT}
		p.command(s,"v2_build",{"kind":"roof","recipe":"field_roof"})
	check(c.count_kind("floor")==6 and c.count_kind("roof")==6 and c.shelter_cells(Vector2(7,12),5)>=2,"assembled cabin provides supported roofing and real standing space over its floor")
	panel._sync(); panel.view.travel(Vector2(11,20)); var point=Vector3(7,2,12.5); var delta=point-panel.view.walker.eye()
	panel.view.walker.yaw=atan2(-delta.x,-delta.z); panel.view.walker.pitch=atan2(delta.y,Vector2(delta.x,delta.z).length()); panel.view._camera(0)
	panel._sync(); await capture("field-cabin")

func _place_above(v,p,x: int,z: int,y: int,kind: String,recipe: String) -> void:
	v.actor={"eye":Vector3(x,y+4,z),"feet":Vector3(x,y+2.38,z),"direction":Vector3.DOWN}
	p.command(game.state,"v2_build",{"kind":kind,"recipe":recipe})
