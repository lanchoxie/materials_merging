extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.51: the 工艺路线 tab — the craftable list, a product's chain
## down to the ore (with the missing building named), and an element's sources and uses.

func shot(file: String) -> void:
	await create_timer(0.9).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v051"))
	root.get_texture().get_image().save_png("res://artifacts/v051/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	for i in range(20): await process_frame
	# A mid-game save state: one plant built, some ore and elements in hand, most factories missing.
	s.coins=20000.0
	s.industry.buildings["0"]={"kind":"metal_works","level":1,"jobs":[]}
	var v=s.planet.v2
	v.nature.minerals["hematite"]=12; v.nature.minerals["coal"]=9; v.nature.minerals["malachite"]=6
	s.element_inventory["Fe"]=8; s.element_inventory["Cu"]=4
	game._show_toolbox(); await process_frame; var panel=game.modal
	panel._tab("guide"); for i in range(10): await process_frame
	panel.guide_target="item:motor"; panel._redraw(); for i in range(10): await process_frame
	await shot("craft-chain")
	panel.guide_target="el:Cs"; panel._redraw(); for i in range(10): await process_frame
	await shot("element-cs")
	panel.guide_target="min:hematite"; panel._redraw(); for i in range(10): await process_frame
	await shot("mineral")
	print("V051 CAPTURE done (%s)" % tag); quit(0)
