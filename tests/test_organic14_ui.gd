extends "res://tests/test_ranch13_ui.gd"

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; var v=s.planet.v2; var o=v.organics
	v.construction.blocks.clear(); v.construction.sources.clear()
	var water=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(water,8)
	var urea=s.product_snapshot(s._new_reactor(4,"urea",0)); s.storage.add_product(urea,8)
	var tank=put(v,"mixing_tank",Vector2(12,12)); var plot=put(v,"planter",Vector2(14,12)); var control=put(v,"planter",Vector2(16,12))
	v.field.plant(plot,v.world,v.construction); v.field.plant(control,v.world,v.construction)
	v.field.gardens[plot].moisture=0.8; v.field.gardens[control].moisture=0.8
	game._show_planet_v2(); await process_frame; var panel=game.modal; v.world.paused=true; panel._select_region("meadow"); panel._enter(); panel._equip_item("tool:collect")
	var target=Vector3(12,v.construction.blocks[tank].y+0.5,12)
	look(panel,Vector2(12,14.6),target); panel._sync(); await process_frame
	check(v.Target.query(v).get("key")==tank,"first-person ray picks visible mixing tank")
	await key(KEY_E); await process_frame; await process_frame
	check(panel.section=="organics" and panel.show_details,"glove E opens real aimed tank panel")
	check(panel.widgets.has("organic_stats") and button(panel,"加尿素")!=null,"panel lists actual reactor batches")
	for id in panel.tabs: check(panel.tabs[id].get_global_rect().end.x<panel.right_panel.get_global_rect().end.x,"tab fits organic navigation: "+id)
	var old=panel.view.walker.position
	button(panel,"加水").pressed.emit(); await process_frame; await process_frame
	button(panel,"加尿素").pressed.emit(); await process_frame; await process_frame
	check(o.tanks[tank].solid_g==5 and o.tanks[tank].water_l==1,"visible add buttons consume shared water and urea")
	check(s.storage.batch(urea.id).quantity==7 and s.storage.batch(water.id).quantity==7,"one button click means one sample debit")
	check(panel.view.walker.position==old and panel.view.first_person,"mixing does not reset view or position")
	panel._sync(); await process_frame
	check(panel.view.organic_view.liquid.mesh!=null and panel.view.organic_view.crystals.mesh!=null,"tank visibly contains water and undissolved white grains")
	await capture("organic14-crystals")
	v.advance(10); panel._sync(); panel._redraw(); await process_frame; await process_frame
	check(panel.view.organic_view.crystals.mesh==null and o.tanks[tank].dissolved_g==5,"crystal geometry disappears only after material dissolves")
	check(not button(panel,"分装250").disabled,"dissolved liquid can be bottled through real UI")
	button(panel,"分装250").pressed.emit(); await process_frame; await process_frame
	check(o.bottles.size()==1 and is_equal_approx(o.tanks[tank].water_l,0.75),"UI bottling subtracts one finite aliquot")
	await capture("organic14-mixing")
	button(panel,"拿起已分装").pressed.emit(); await process_frame
	check(v.inventory.slots[v.inventory.selected]=="solution:1" and not panel.show_details,"bottle button equips in existing hotbar")
	look(panel,Vector2(14,14.6),Vector3(14,v.construction.blocks[plot].y+0.7,12)); panel._sync(); await process_frame
	check(panel.action_button.text.contains("施肥"),"touch action explicitly shows fertilizer use")
	var tap=panel.action_button.get_global_rect().get_center(); await game._test_touch(tap,true); await game._test_touch(tap,false)
	check(o.soils.has(plot) and not o.soils.has(control) and o.bottles.is_empty(),"touch application affects only aimed crop and consumes bottle once")
	v.advance(35); panel._sync(); await process_frame
	check(v.field.gardens[plot].growth>v.field.gardens[control].growth,"rendered comparison crop follows distinct model growth")
	look(panel,Vector2(12,14.6),target); panel._equip_item("sample:"+urea.id); await key(KEY_E); await key(KEY_E)
	check(o.tanks[tank].solid_g==10,"handheld urea reaches tank through first-person input")
	v.advance(20); panel._equip_item("tool:collect"); await key(KEY_E); await process_frame; await process_frame
	button(panel,"分装250").pressed.emit(); await process_frame; await process_frame
	button(panel,"拿起已分装").pressed.emit(); await process_frame
	look(panel,Vector2(14,14.6),Vector3(14,v.construction.blocks[plot].y+0.7,12)); await key(KEY_E); panel._sync(); await process_frame
	check(o.injury(plot)>0 and o.bottles.is_empty(),"concentrated bottle is consumed and produces persistent leaf injury")
	panel._equip_item("tool:collect"); panel._aim()
	check(panel.aim_label.text.contains("叶尖受损"),"aim feedback explains injured crop instead of generic toxicity")
	panel.show_details=true; panel._exploration_layout(); panel._tab("organics"); await process_frame; await process_frame
	check(panel.widgets.organic_plots.text.contains("叶片受损"),"observation card displays dose-specific crop response")
	await capture("organic14-garden")
	panel.show_details=false; panel._exploration_layout(); panel._open_backpack(); await process_frame; await process_frame
	check(panel.backpack.items.has("sample:"+urea.id),"organic samples remain in existing backpack sample category")
	game.queue_free(); await process_frame
	print("ORGANIC14 UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
