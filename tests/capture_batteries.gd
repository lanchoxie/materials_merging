extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.40: the battery works on the deck, the LFP thickness slider
## with its laws, the drill and storage cards.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v040"))
	root.get_texture().get_image().save_png("res://artifacts/v040/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var ind=s.industry
	for i in range(20): await process_frame
	preload("res://scripts/test_mode.gd").open_starforge(s,900); ind.gain(Industry.step(14)); s.coins=900000; ind.plots=10; ind.solar=[0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3]
	for k in ["battery_works","metal_works","packaging_plant","polymer_works","trade_hub"]: ind.build(s,ind.buildings.size(),k)
	preload("res://scripts/test_mode.gd").battery_kit(s)
	ind.set_knob("lfp_cell","t",90); ind.start(s,0,"lfp_cell"); ind.start(s,0,"lead_acid"); ind.tick(s,200.0)
	ind.start(s,0,"lfp_cell"); ind.tick(s,200.0)
	ind.start(s,0,"battery_pack"); ind.start(s,1,"motor"); ind.tick(s,200.0)
	ind.start(s,2,"power_drill"); ind.tick(s,200.0)
	ind.equip_drill("power_drill"); s.sync_gear(); ind.drill_state.charge=float(ind.drill_state.cap)*0.7
	ind.set_knob("lfp_cell","t",150); ind.start(s,0,"lead_acid"); ind.tick(s,200.0)
	game._show_starforge(); var panel=game.modal
	panel._redraw(); for i in range(40): await process_frame
	await shot("deck")
	panel._tab("factory"); await process_frame
	panel.laws_open["lfp_cell"]=true; panel._redraw(); await process_frame
	await shot("battery-works")
	panel._tab("gear"); await process_frame
	await shot("gear-drill")
	print("V040 CAPTURE done (%s)" % tag); quit(0)
