extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.44: a small house of the new parts (stone brick walls, glass
## windows, a wooden door, metal roof slopes, plastic roof slabs, a wooden floor), the door open,
## the planet's 建材 grid, and the workshop page of a metal window (星锻岛 inputs).

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v044"))
	root.get_texture().get_image().save_png("res://artifacts/v044/%s-%s.png" % [file,tag])

func issue(p,v,recipe: String) -> String:
	var id=int(p.serial); p.serial+=1
	var info: Dictionary=v.field.rules.recipes[recipe]
	v.field.crafts[str(id)]={"recipe":recipe,"complete":true,"inputs":info.natural_inputs.duplicate()}
	if info.has("industry_inputs"): v.field.crafts[str(id)]["industry"]=info.industry_inputs.duplicate()
	v.construction.sources[str(id)]={"product":{"id":id,"recipe":recipe,"recipe_version":1,"source_batch":"river:"+str(id)},"remaining":int(v.construction.rules.recipes[recipe].units)}
	return str(id)

var packs={}
func put(v,kind: String,x: int,y: int,z: int,extra: Dictionary={}) -> void:
	var c=v.construction; var recipe="field_"+kind
	if not packs.has(kind) or int(c.sources[packs[kind]].remaining)<=0: packs[kind]=issue(game.state.planet,v,recipe)
	var b={"x":x,"y":y,"z":z,"kind":kind,"source":packs[kind]}; b.merge(extra)
	c.blocks[c.key(Vector3i(x,y,z))]=b; c.sources[packs[kind]].remaining=int(c.sources[packs[kind]].remaining)-1

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var p=s.planet; var v=p.v2; var c=v.construction
	for i in range(20): await process_frame
	p.command(s,"join")
	# A 5×4 house on the flattest ground near home: x 18..22, z 20..23, door in the middle of the front.
	var y0=c.base(Vector3i(20,0,22))
	for x in range(18,23):
		for z in range(20,24): put(v,"slab_wood",x,y0,z)
	for x in range(18,23):
		for z in range(20,24):
			var edge=x in [18,22] or z in [20,23]
			if not edge: continue
			if z==23 and x==20: put(v,"door_wood",x,y0+1,z,{"rot":0,"open":false}); continue
			if z==23 and x in [19,21]:
				put(v,"brick_stone",x,y0+1,z); put(v,"window_stone",x,y0+2,z,{"rot":0}); continue
			if x==22 and z in [21,22]:
				put(v,"brick_stone",x,y0+1,z); put(v,"window_metal",x,y0+2,z,{"rot":1}); continue
			put(v,"brick_stone",x,y0+1,z)
			if not (z==23 and x==20): put(v,"brick_stone",x,y0+2,z)
	for x in range(18,23):
		put(v,"slope_metal",x,y0+3,23,{"rot":0}); put(v,"slope_metal",x,y0+3,20,{"rot":2})
		for z in [21,22]: put(v,"slab_plastic",x,y0+3,z)
	# A little porch: a plastic brick planter wall and metal steps.
	put(v,"brick_plastic",17,y0,24); put(v,"slab_metal",20,y0,24); put(v,"slab_metal",20,y0,25)
	c.revision+=1
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._enter(); for i in range(30): await process_frame
	var w=panel.view.walker
	w.position=Vector2(23.6,28.5); w.reset_height(); var to=Vector2(20,22)-w.position; w.yaw=atan2(-to.x,-to.y); w.pitch=0.08
	for i in range(40): await process_frame
	await shot("house")
	c.blocks[c.key(Vector3i(20,y0+1,23))].open=true; c.revision+=1
	w.position=Vector2(20.2,26.2); w.reset_height(); w.yaw=0.0; w.pitch=0.02
	for i in range(30): await process_frame
	await shot("door-open")
	w.position=Vector2(20.0,21.2); w.reset_height(); w.feet_y=y0+0.5; w.last_position=w.position; w.yaw=PI; w.pitch=0.15
	for i in range(30): await process_frame
	await shot("inside")
	panel.show_details=true; panel._exploration_layout(); panel._tab("build"); for i in range(5): await process_frame
	panel.scroll.scroll_vertical=int(panel.scroll.get_v_scroll_bar().max_value); for i in range(5): await process_frame
	await shot("build-tab")
	game._close_all(); await process_frame
	s.industry.items["steel_ingot"]=3; s.industry._reconcile("steel_ingot"); s.industry.items["glass"]=1; s.industry._reconcile("glass")
	game._show_factory(); for i in range(5): await process_frame
	game.modal._choose_recipe("field_window_metal"); for i in range(5): await process_frame
	await shot("workshop-metal-window")
	print("V044 CAPTURE done (%s)" % tag); quit(0)
