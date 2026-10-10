extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.41.1: the build menu with 空白反应炉 and 我的炉型, the
## structure studio in build mode with the match % / income line and a target bond length.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v0411"))
	root.get_texture().get_image().save_png("res://artifacts/v0411/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	for i in range(20): await process_frame
	s.campus.people.append(s.campus._new_person("doctor",-1,true))
	for el in ["C","O","H","N"]: s.element_inventory[el]=20
	s.coins=2000
	var work={"version":1,"name":"我的甲醇","baseline_id":"","atoms":["C","O","H","H","H","H"],
		"positions":[[0,0,0],[1.43,0,0],[-0.36,1.0,0],[-0.36,-0.5,0.87],[-0.36,-0.5,-0.87],[1.75,0.9,0]],
		"bonds":[[0,1,1],[0,2,1],[0,3,1],[0,4,1],[1,5,1]],"mode":"science","periodic":false,"cell":[6.0,6.0,6.0]}
	s.save_player_template(work)
	var plot=-1
	for i in range(s.plots.size()):
		if s.plots[i].unlocked and s.plots[i].kind=="empty": plot=i; break
	game._select_plot(plot); game._show_templates(true); for i in range(5): await process_frame
	await shot("build-menu")
	game._close_modal(); game._open_sandbox_editor(work.duplicate(true),plot); for i in range(10): await process_frame
	var ed=game.modal
	if ed!=null and ed.has_method("_update_bond_text"):
		ed.pair_a.select(0); ed.pair_b.select(1); ed._update_bond_text(); ed._update_readout()
	await shot("studio-build")
	print("V0411 CAPTURE done (%s)" % tag); quit(0)
