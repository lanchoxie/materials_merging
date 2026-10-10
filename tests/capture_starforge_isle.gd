extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.43: the grown deck with decorations and staff, the deck map,
## the staff tab with stamina, the first-person walk, placing a decoration, and 星锻公寓 inside.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v043"))
	root.get_texture().get_image().save_png("res://artifacts/v043/%s-%s.png" % [file,tag])

func look(walk,from: Vector2,to: Vector3,pitch: float) -> void:
	walk.walker.position=from; walk.walker.reset_height()
	walk.walker.yaw=atan2(-(to.x-from.x),-(to.z-from.y)); walk.walker.pitch=pitch; walk._camera()

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var ind=s.industry
	for i in range(20): await process_frame
	preload("res://scripts/test_mode.gd").open_starforge(s,800); s.coins=900000; ind.credits=990; ind.gain(20000)
	for c in [Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),Vector2i(1,2)]: ind.buy_plot_at(s,c)
	ind.build(s,0,"staff_housing"); ind.build(s,1,"metal_works"); ind.build(s,2,"trade_hub"); ind.build(s,3,"polymer_works")
	ind.build(s,4,"staff_lounge"); ind.build(s,7,"home_studio")
	ind.staff.append({"id":1,"name":"林工","role":"engineer","specialty":"","home":0,"factory":1,"energy":72.0,"resting":false})
	ind.staff.append({"id":2,"name":"周博","role":"doctor","specialty":"","home":0,"factory":3,"energy":18.0,"resting":true})
	ind.staff.append({"id":3,"name":"许工","role":"engineer","specialty":"","home":0,"factory":3,"energy":95.0,"resting":false})
	ind.staff_serial=4
	ind.buildings["1"].jobs=[{"recipe":"steel","left":30.0}] if ind.rules().recipes.has("steel") else []
	for k in ["flower_bed","bench","street_lamp","young_tree","fountain","stone_path"]: s.storage.decorations[k]=int(s.storage.decorations.get(k,0))+3
	ind.place_decor(s,5,"fountain",Vector2i(4,4),0); ind.place_decor(s,5,"bench",Vector2i(4,9),0); ind.place_decor(s,5,"street_lamp",Vector2i(1,1),0)
	ind.place_decor(s,6,"young_tree",Vector2i(2,2),0); ind.place_decor(s,6,"flower_bed",Vector2i(7,7),0); ind.place_decor(s,8,"stone_path",Vector2i(5,0),0); ind.place_decor(s,8,"stone_path",Vector2i(5,2),0)
	game._show_starforge(); for i in range(10): await process_frame
	await shot("deck")
	game.modal._tab("staff"); for i in range(5): await process_frame
	await shot("staff")
	game.modal._tab("deck"); game.modal.walk_button.pressed.emit(); for i in range(30): await process_frame
	var walk=game.modal
	var hub=ind.plot_center(2); var fountain=ind.plot_center(5)
	look(walk,Vector2(fountain.x+1.2,fountain.z+1.3),hub+Vector3(0,0.4,0),0.12); for i in range(20): await process_frame
	await shot("walk-factories")
	look(walk,Vector2(fountain.x-0.6,fountain.z+1.4),fountain,-0.05); for i in range(20): await process_frame
	await shot("walk-decor")
	var empty=ind.plot_center(8)
	walk._hold("flower_bed"); look(walk,Vector2(empty.x-1.2,empty.z+0.4),empty,-0.45); for i in range(20): await process_frame
	await shot("walk-place")
	walk._hold("")
	var flats=ind.plot_center(0)
	look(walk,Vector2(flats.x,flats.z+1.45),flats+Vector3(0,0.6,0),0.0); walk._interact(); for i in range(30): await process_frame
	walk.walker.yaw=0.0; walk.walker.pitch=-0.1; walk._camera(); for i in range(10): await process_frame
	await shot("apartment")
	print("V043 CAPTURE done (%s)" % tag); quit(0)
