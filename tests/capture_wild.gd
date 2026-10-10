extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.41.2: the campfire cooking menu, the workshop 建筑复制 page,
## and the per-cell unfold preview.
const Mini=preload("res://scripts/river_miniatures.gd")

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v0412"))
	root.get_texture().get_image().save_png("res://artifacts/v0412/%s-%s.png" % [file,tag])

func issue(p,v,recipe: String) -> String:
	var id=int(p.serial); p.serial+=1
	v.field.crafts[str(id)]={"recipe":recipe,"complete":true,"inputs":v.field.rules.recipes[recipe].natural_inputs.duplicate()}
	v.construction.sources[str(id)]={"product":{"id":id,"recipe":recipe,"recipe_version":1,"source_batch":"river:"+str(id)},"remaining":int(v.construction.rules.recipes[recipe].units)}
	return str(id)

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var p=s.planet; var v=p.v2
	for i in range(20): await process_frame
	p.command(s,"join"); s.campus_build(3,"workshop"); s.campus_road(3); s.campus_assign_post(s.campus.people[0].id,"workshop")
	v.field.stock.meat=3; v.field.stock.grain=4; v.field.stock.fruit=2; v.field.stock.fiber=3; v.field.stock.timber=12
	# A 3-block wall tower, boxed, for the copy page and the unfold preview.
	var c=v.construction; var wk=issue(p,v,"field_wall"); var base=c.base(Vector3i(19,0,14))
	for dy in range(3):
		var b={"x":19,"y":base+dy,"z":14,"kind":"block","source":wk}; c.blocks[c.key(c.cell(b))]=b; c.sources[wk].remaining=int(c.sources[wk].remaining)-1
	Mini.pack(c,{"type":"block","key":c.blocks.keys()[0]})
	game._show_factory(); for i in range(5): await process_frame
	game.modal._section("copy"); for i in range(5): await process_frame
	await shot("workshop-copy")
	game._close_all(); await process_frame
	# Campfire beside the start point, then the cooking menu.
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._select_region("meadow"); panel._enter(); for i in range(40): await process_frame
	var w=panel.view.walker; var f=Vector2(-sin(w.yaw),-cos(w.yaw)); var at=w.position+f*2.0
	var fk=issue(p,v,"field_campfire"); var cell=Vector3i(roundi(at.x),c.base(Vector3i(roundi(at.x),0,roundi(at.y))),roundi(at.y))
	c.blocks[c.key(cell)]={"x":cell.x,"y":cell.y,"z":cell.z,"kind":"campfire","source":fk}; c.sources[fk].remaining=1; c.revision+=1
	w.pitch=-0.45; panel._sync(); for i in range(20): await process_frame
	panel._cook_menu(); for i in range(5): await process_frame
	await shot("cooking")
	panel.cook_box.queue_free()
	# Unfold preview: hold the boxed tower and aim at open ground.
	var mini_id=str(c.miniatures.keys()[0]); v.inventory.slots[2]="mini:"+mini_id; v.inventory.selected=2
	panel._refresh_hotbar(); w.pitch=-0.35; w.yaw+=1.2; for i in range(30): await process_frame
	panel._aim(); for i in range(5): await process_frame
	await shot("unfold-cells")
	print("V0412 CAPTURE done (%s)" % tag); quit(0)
