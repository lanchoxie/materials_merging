extends "res://tests/test_ranch13_ui.gd"

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; s.coins=10000
	s.campus_build(5,"institute"); s.campus_road(5); s.campus_build(7,"doctor_dorm"); s.campus_road(7); s.campus_hire("doctor")
	s.campus.elapsed=100; s.tick(1)
	check(s.storage.batches.is_empty(),"UI flow starts with empty product backpack")
	game._show_planet_v2(); await process_frame; var river=game.modal; river._tab("organics"); await process_frame; await process_frame
	check(button(river,"回浮岛反应釜")!=null,"river mixing page offers direct reactor synthesis route")
	button(river,"回浮岛反应釜").pressed.emit(); await process_frame; await process_frame
	var panel=game.modal
	check(panel.get_script().resource_path.ends_with("organic_reactor_panel.gd") and not s.planet.v2.active,"route opens reactor production and releases river observer")
	check(panel.contents.text.contains("H₂O") and panel.preview.atoms.get_child_count()>0,"preview renders actual old water structure before installation")
	check(panel.buy_button.visible and panel.start_button.disabled,"preparation shows missing elements and blocks premature synthesis")
	panel.buy_button.pressed.emit(); await process_frame
	check(s.storage.batches.is_empty() and not panel.start_button.disabled,"buying elements does not create organic product")
	var before=s.coins; var at=panel.start_button.get_global_rect().get_center()
	await game._test_touch(at,true); await game._test_touch(at,false); await process_frame
	check(s.reactors[0].has("installation") and s.coins==before-12,"native touch submits one real reactor installation at fixed level fee")
	check(panel.phase_label.text.contains("博士") and panel.preview.seen==s.signature(s.reactors[0]),"waiting page retains actual old reactor contents and reports doctor stage")
	await capture("organic15-installing")
	var coordinates=s.reactors[0].installation.payload.work.positions.duplicate(true)
	for i in range(160):
		if not s.reactors[0].has("installation"): break
		s.tick(1)
	panel.refresh(); await process_frame; await process_frame
	check(s.reference_id(s.reactors[0])=="urea" and s.reactors[0].positions==coordinates,"real campus simulation installs exactly the authored unoptimized urea")
	check(panel.phase_label.text.contains("合成中") and panel.contents.text.contains("CH₄N₂O") and panel.harvest_button.disabled,"completed installation updates actual 3D content but harvest remains unavailable")
	check(panel.reactor_menu.get_item_text(0).contains("CH₄N₂O"),"reactor selector refreshes its molecule after the actual install")
	for i in range(85):
		if s.reactors[0].pending>0: break
		s.tick(1)
	panel.refresh(); await process_frame
	check(s.planet.sample_candidates(s,"urea").is_empty() and not panel.harvest_button.disabled,"time creates output inside reactor before it enters shared backpack")
	await capture("organic15-produced")
	at=panel.harvest_button.get_global_rect().get_center(); await game._test_touch(at,true); await game._test_touch(at,false); await process_frame
	var batches=s.planet.sample_candidates(s,"urea")
	check(batches.size()==1 and batches[0].quantity==1 and s.reactors[0].pending==0,"touch harvest transfers exactly one real produced urea")
	panel.harvest_button.pressed.emit(); await process_frame
	check(batches[0].quantity==1,"repeated harvest cannot duplicate output")
	button(panel,"带背包产物前往河湾").pressed.emit(); await process_frame; river=game.modal
	var tank=put(s.planet.v2,"mixing_tank",Vector2(12,12)); river._enter(); river._equip_item("sample:"+batches[0].id)
	look(river,Vector2(12,14.6),Vector3(12,s.planet.v2.construction.blocks[tank].y+0.5,12)); river._sync(); await process_frame
	await key(KEY_E); await process_frame
	check(s.planet.v2.organics.tanks.get(tank,{}).get("solid_g")==5 and batches[0].quantity==0,"same produced batch is equipped and consumed by the actual visible mixing tank")
	game._show_factory("field_mixing_tank"); await process_frame; await process_frame
	check(button(game.modal,"前往反应釜")!=null,"tank workshop clearly routes molecule production back to reactors")
	button(game.modal,"前往反应釜").pressed.emit(); await process_frame
	check(game.modal.reactor_index==0 and game.modal.phase_label.text.contains("合成中"),"existing urea reactor is automatically selected without restarting it")
	game._show_island_walk(); await process_frame; var island=game.modal
	island.walker.position=Vector2(0,1.3); island.walker.reset_height(); island.walker.yaw=0; island.walker.pitch=-0.1; island._camera()
	var old=island.walker.position; var yaw=island.walker.yaw; island.input.grab_focus(); await key(KEY_E); await process_frame
	var editor=game.modal
	check(editor.get_script().resource_path.contains("sandbox_editor") and button(editor,"反应釜合成")!=null,"organic reactor remains editable in existing first-person sandbox")
	button(editor,"反应釜合成").pressed.emit(); await process_frame
	check(game.editor_return_view==island and game.modal.return_button.text.contains("返回漫步"),"switching editor to production preserves first-person caller")
	game.modal.handle_back(); await process_frame
	check(game.modal==island and island.walker.position==old and island.walker.yaw==yaw and island.input.walking,"leaving production restores same first-person position and controls")
	game.queue_free(); await process_frame
	print("ORGANIC15 UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
