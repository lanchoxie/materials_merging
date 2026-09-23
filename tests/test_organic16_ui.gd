extends "res://tests/test_ranch13_ui.gd"

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; s.coins=10000
	s.campus_build(5,"institute"); s.campus_road(5); s.campus_build(7,"doctor_dorm"); s.campus_road(7); s.campus_hire("doctor"); s.campus.elapsed=100; s.tick(1)
	game._show_organic_synthesis(); await process_frame; await process_frame
	var panel=game.modal
	check(panel.reference_menu.item_count==3,"visible compound selector exposes three organic routes")
	for i in [1,2]:
		panel.reference_menu.select(i); panel.reference_menu.item_selected.emit(i); await process_frame
		var ref=panel.reference; var name=panel.flow.rules.references[ref].name
		check(panel.molecule_title.text.contains(name) and panel.molecule_description.text.contains("互溶"),"selection updates formula and sourced use description")
		panel.buy_button.pressed.emit(); await process_frame
		var at=panel.start_button.get_global_rect().get_center(); await game._test_touch(at,true); await game._test_touch(at,false); await process_frame
		check(s.reactors[0].has("installation"),"touch starts paid doctor installation of selected organic")
		for tick in range(180):
			if not s.reactors[0].has("installation"): break
			s.tick(1)
		for tick in range(90):
			if s.reactors[0].pending>0: break
			s.tick(1)
		panel.refresh(); await process_frame; await process_frame
		check(panel.contents.text.contains(name) and panel.harvest_button.text.contains(name),"real reactor molecule and harvest label match selected compound")
		check(panel.preview.seen==s.signature(s.reactors[0]),"3D preview follows actual reactor, never substitutes selected recipe")
		if ref=="glycerol": await capture("organic16-reactor")
		at=panel.harvest_button.get_global_rect().get_center(); await game._test_touch(at,true); await game._test_touch(at,false); await process_frame
		check(panel.flow.stock(s,ref)==1,"touch collects one actual produced organic into shared backpack")
	var v=s.planet.v2; var batch=s.planet.sample_candidates(s,"ethanol")[0]
	var water=s.product_snapshot(s._new_reactor(4,"water",0)); s.storage.add_product(water,2)
	game._show_planet_v2(); await process_frame; var river=game.modal
	var tank=put(v,"mixing_tank",Vector2(12,12)); river._enter(); river._equip_item("sample:"+batch.id)
	look(river,Vector2(12,14.6),Vector3(12,v.construction.blocks[tank].y+0.5,12)); river._sync(); await process_frame
	await key(KEY_E); await process_frame
	check(batch.quantity==0 and v.organics.substance(v.organics.tanks[tank])=="ethanol","first person feeds actual ethanol batch into visible tank")
	river._equip_item("sample:"+water.id); await key(KEY_E); await process_frame
	v.advance(10); river._tab("organics"); await process_frame; await process_frame
	check(button(river,"加甘油")!=null and button(river,"加甘油").disabled,"mixing menu disables other species before consuming backpack")
	check(river.widgets.organic_stats.text.contains("乙醇") and river.widgets.organic_stats.text.contains("待混液体"),"liquid material is labelled as liquid rather than crystals")
	button(river,"分装250").pressed.emit(); await process_frame; await process_frame
	var id=str(v.organics.serial-1); check(v.organics.bottles.has(id),"panel bottles ethanol with real remaining quantity")
	await capture("organic16-mixing")
	river._equip_item("solution:"+id); look(river,Vector2(12,14.6),Vector3(12,v.construction.blocks[tank].y+0.5,12)); river._sync(); await process_frame
	check(river.action_button.text.contains("倒回") and not river.aim_label.text.contains("施肥"),"ethanol first-person hints never claim fertilizer use")
	await key(KEY_E); await process_frame
	check(not v.organics.bottles.has(id) and v.organics.tanks[tank].dissolved_g==5,"first person pours bottle back into same tank")
	game.queue_free(); await process_frame
	print("ORGANIC16 UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
