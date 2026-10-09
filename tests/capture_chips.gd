extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.38: chip fab sliders (linewidth, LED colour), the packaging
## chain, lots with colour swatches, the headlamp card, and the planet at night with and without it.
const Model=preload("res://scripts/material_model.gd")

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v038"))
	root.get_texture().get_image().save_png("res://artifacts/v038/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var ind=s.industry
	for i in range(20): await process_frame
	preload("res://scripts/test_mode.gd").open_starforge(s,900); ind.gain(Industry.step(14)); s.coins=900000; ind.plots=10; ind.solar=[0.3,0.3,0.3,0.3,0.3,0.3]
	for k in ["polymer_works","chip_fab","packaging_plant","metal_works","trade_hub"]: ind.build(s,ind.buildings.size(),k)
	preload("res://scripts/test_mode.gd").chip_kit(s)
	ind.start(s,0,"photoresist"); ind.start(s,0,"epoxy"); ind.tick(s,200.0)
	ind.start(s,0,"photoresist"); ind.start(s,0,"epoxy"); ind.tick(s,200.0)
	ind.set_knob("logic_chip","L",0.5); ind.start(s,1,"logic_chip"); ind.start(s,1,"power_diode"); ind.tick(s,300.0)
	for x in [0.0,0.4]:
		ind.set_knob("led_chip","x",x); ind.start(s,1,"led_chip"); ind.tick(s,200.0)
	ind.start(s,2,"fr4_board"); ind.start(s,2,"ic_package"); ind.tick(s,200.0)
	ind.start(s,2,"control_board"); ind.start(s,2,"headlamp"); ind.tick(s,200.0)
	ind.install_board(3); ind.equip_lamp("headlamp")
	ind.set_knob("led_chip","x",0.3)
	game._show_starforge(); var panel=game.modal
	panel._redraw(); for i in range(40): await process_frame
	await shot("deck")
	panel._tab("factory"); await process_frame
	panel.scroll.scroll_vertical=1250; await process_frame
	await shot("chip-fab")
	panel.laws_open["led_chip"]=true; panel._redraw(); await process_frame
	panel.scroll.scroll_vertical=1650; await process_frame
	await shot("led-laws")
	panel._tab("market"); await process_frame
	panel.scroll.scroll_vertical=500; await process_frame
	await shot("market-leds")
	panel._tab("gear"); await process_frame
	await shot("gear-lamp")
	panel._close(); await process_frame
	# Night on Earth: lamp off, then on.
	var v=s.planet.v2; v.world.elapsed=60.0*3
	game._show_planet_v2(); await process_frame; var planet=game.modal
	planet._select_region("meadow"); planet._enter(); for i in range(60): await process_frame
	ind.lamp=""; planet._sync(); for i in range(10): await process_frame
	print("LAMP off: ",planet.view.lamp_on)
	await shot("night-no-lamp")
	ind.lamp="headlamp"; planet._sync(); for i in range(10): await process_frame
	print("LAMP on: ",planet.view.lamp_on," range ",planet.view.lamp.spot_range)
	await shot("night-lamp")
	print("V038 CAPTURE done (%s)" % tag); quit(0)
