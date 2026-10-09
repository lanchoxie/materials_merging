extends "res://tests/capture_earth_ux.gd"
## Screenshot helper (not a test) for v0.36 incidents and specimens. Run windowed:
##   ... --script res://tests/capture_incidents.gd -- --release-ui-test --tag=X

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/earth-ux"))
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	v.world.elapsed=20.0
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._select_region("meadow"); panel._enter(); panel._equip_item("tool:collect")
	var t=v.construction.terrain; var at=Vector2(14,16)
	look(panel,at,Vector3(4,t.ground(Vector2(4,4))+1.0,4)); await settle(panel)
	await shot("clear")
	v.incidents.warn(v,"storm",1)
	for i in range(3): v.world.elapsed+=1; v._step()
	panel._sync(); for i in range(120): await process_frame
	await shot("storm")
	v.incidents.active={}; v.incidents.last_end=-1
	v.incidents.warn(v,"drought",1)
	for i in range(3): v.world.elapsed+=1; v._step()
	panel._sync(); for i in range(150): await process_frame
	await shot("drought")
	v.specimens.record("marsh_fish","湿地"); v.specimens.record("oak","森林"); v.specimens.record("woodland_boar","森林")
	panel._enter(); await process_frame
	panel._tab("era"); for i in range(5): await process_frame
	await shot("era-weather")
	panel._tab("journal"); for i in range(5): await process_frame
	await shot("journal-specimens")
	game.queue_free(); await process_frame
	print("INCIDENT CAPTURE done (%s)" % tag); quit(0)
