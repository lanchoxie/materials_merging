extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.39 冰河期: the time gate dialog, the ice-age river by day,
## mammoths and woolly rhinos, a winter night with the cold HUD, a campfire, a blizzard, the suit card.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v039"))
	root.get_texture().get_image().save_png("res://artifacts/v039/%s-%s.png" % [file,tag])

func face(panel,target: Vector2) -> void:
	var w=panel.view.walker; var d=Vector2(target.x,target.y)-Vector2(w.position.x,w.position.y)
	w.yaw=atan2(-d.x,-d.y); w.pitch=-0.12

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	for i in range(20): await process_frame
	s.planet.v2.settlement.era=1
	game._enter_light_bridge(); for i in range(5): await process_frame
	await shot("gate")
	game._through_gate("ice"); await create_timer(2.0).timeout
	var panel=game.modal; var v=s.planet.v2
	v.world.elapsed=60.0*4+30   # summer noon
	panel._sync(); for i in range(40): await process_frame
	await shot("ice-summer")
	# Find a wild herd and stand 9 m from it.
	v.population.observe(Vector2(120,-60))
	var herd=null
	for site in v.population.sites.values():
		if not site.home and not site.animals.is_empty(): herd=site; break
	print("HERD ",herd.id if herd!=null else "none"," ",herd.animals.map(func(a): return a.species) if herd!=null else [])
	if herd!=null:
		var at=Vector2(herd.x,herd.z)
		panel.test_teleport(at+Vector2(9,6),"tundra"); for i in range(60): await process_frame
		face(panel,at+Vector2(herd.animals[0].x,herd.animals[0].z)); panel._sync(); for i in range(30): await process_frame
		await shot("mammoths")
	# Winter night at camp: cold HUD, then a campfire.
	panel.test_teleport(Vector2(4,6),"meadow"); for i in range(40): await process_frame
	v.world.elapsed=60.0*12+3   # winter, about 01:00
	panel._sync(); for i in range(30): await process_frame
	print("FELT ",v.combat.felt)
	await shot("winter-night-cold")
	var c=v.construction; var feet=v.actor.feet
	var product={"id":int(s.planet.serial),"recipe":"field_campfire","recipe_version":1,"source_batch":"river:"+str(int(s.planet.serial))}
	v.field.crafts[str(int(product.id))]={"recipe":"field_campfire","complete":true,"inputs":v.field.rules.recipes.field_campfire.natural_inputs.duplicate()}; s.planet.serial+=1
	c.sources[str(int(product.id))]={"product":product,"remaining":1}
	var fx=Vector3i(roundi(feet.x)-1,0,roundi(feet.z)-3); fx.y=c.base(fx)
	c.blocks[c.key(fx)]={"x":fx.x,"y":fx.y,"z":fx.z,"kind":"campfire","source":str(int(product.id))}; c.revision+=1
	face(panel,Vector2(fx.x,fx.z)); panel._sync(); for i in range(30): await process_frame
	print("FELT fire ",v.combat.felt)
	await shot("campfire")
	v.incidents.warn(v,"blizzard",1); for i in range(3): v.world.elapsed+=1; v._step()
	v.world.elapsed=60.0*12+30; panel._sync(); for i in range(90): await process_frame
	await shot("blizzard")
	panel._close() if panel.has_method("_close") else game._close_all(); await process_frame
	# The 保温服 on 星锻岛.
	preload("res://scripts/test_mode.gd").open_starforge(s,300); s.industry.items["insulated_suit"]=1; s.industry.equip_suit("insulated_suit"); s.sync_gear()
	game._close_all(); await process_frame
	game._show_starforge(); var sf=game.modal; sf._tab("gear"); for i in range(10): await process_frame
	await shot("suit")
	print("V039 CAPTURE done (%s)" % tag); quit(0)
