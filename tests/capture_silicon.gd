extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.37: material-model sliders, laws, lots and the test bench,
## the inorganic works and silicon foundry on the deck, solar and fertiliser, the 19-element palette.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v037"))
	root.get_texture().get_image().save_png("res://artifacts/v037/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var ind=s.industry
	for i in range(20): await process_frame
	preload("res://scripts/test_mode.gd").open_starforge(s,800); ind.gain(Industry.step(10)); ind.solar=[0.25,0.25,0.25,0.25]
	s.coins=300000; ind.plots=8
	ind.build(s,0,"metal_works"); ind.build(s,1,"trade_hub"); ind.build(s,2,"test_bench")
	ind.build(s,3,"inorganic_works"); ind.build(s,4,"silicon_works")
	for f in ["Fe3C","Cu3Sn","Al2Cu","LiAl","CaO","Cl3HSi","Si","H3O4P"]: s.index_found[Industry._keys_for(f)[0]]=true
	for el in ["Fe","C","Cu","Sn","Al","Li","Na","Si","H","Cl","P","S","O"]: s.element_inventory[el]=60
	var m: Dictionary=s.planet.v2.nature.minerals
	for id in ["sand","limestone","clay","apatite"]: m[id]=30
	# Lots: two steel ingots of different carbon, a peak- and an over-aged duralumin lot, one measured.
	ind.set_knob("carbon_steel","C",0.3); ind.start(s,0,"carbon_steel")
	ind.set_knob("carbon_steel","C",0.7); ind.start(s,0,"carbon_steel")
	ind.tick(s,200.0)
	ind.set_knob("steel_bit","T",200); ind.start(s,0,"steel_bit"); ind.tick(s,200.0)
	ind.set_knob("duralumin","t",10); ind.start(s,0,"duralumin"); ind.tick(s,200.0)
	ind.set_knob("duralumin","t",150); ind.start(s,0,"duralumin"); ind.tick(s,200.0)
	ind.measure(s,"duralumin",0)
	ind.equip("steel_bit"); s.sync_gear()
	ind.set_knob("n_wafer","N",15.7)
	ind.start(s,3,"soda_lime_glass"); ind.start(s,4,"polysilicon"); ind.tick(s,200.0)
	ind.start(s,4,"n_wafer"); ind.tick(s,200.0)
	ind.items["duralumin"]=int(ind.items.get("duralumin",0))+1; ind._reconcile("duralumin")
	ind.start(s,4,"solar_panel"); ind.tick(s,200.0); ind.install_solar()
	ind.start(s,3,"superphosphate"); ind.start(s,0,"carbon_steel"); ind.tick(s,10.0)
	ind.set_knob("carbon_steel","C",0.45)
	game._show_starforge(); var panel=game.modal
	panel._redraw(); for i in range(40): await process_frame
	await shot("deck")
	panel._tab("factory"); await process_frame
	await shot("factory-metal")
	panel.laws_open["steel_bit"]=true; panel._redraw(); await process_frame
	panel.scroll.scroll_vertical=520; await process_frame
	await shot("factory-laws")
	panel.laws_open={}; panel._redraw(); await process_frame
	panel.scroll.scroll_vertical=1650; await process_frame
	await shot("factory-silicon")
	panel._tab("market"); await process_frame
	panel.scroll.scroll_vertical=420; await process_frame
	await shot("market-lots")
	panel._tab("gear"); await process_frame
	await shot("gear")
	panel.dismissed.emit(); await process_frame
	game._show_refinery(); for i in range(10): await process_frame
	await shot("refinery")
	print("V037 CAPTURE done (%s)" % tag); quit(0)
