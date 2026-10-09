extends SceneTree
## Screenshot helper (not a test) for v0.34 星锻岛. Run windowed:
##   ... --script res://tests/capture_starforge.gd -- --release-ui-test --tag=X
const Main=preload("res://scripts/main.gd")
const Industry=preload("res://scripts/industry.gd")
var game
var tag="now"

func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): tag=a.get_slice("=",1)
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(200).timeout.connect(func(): quit(2))

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/starforge/%s-%s.png" % [file,tag])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/starforge"))
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	for i in range(30): await process_frame
	await shot("island-topbar")
	game._show_starforge(); var panel=game.modal
	await shot("locked")
	var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,400)
	s.coins=40000; s.materials=[30,30,30]
	ind.build(s,0,"metal_works"); ind.build(s,1,"polymer_works"); ind.build(s,2,"trade_hub")
	ind.buy_plot(s); ind.buy_plot(s)
	for f in ["Fe3C","C2H4","Cu3Sn"]: s.index_found[Industry._keys_for(f)[0]]=true
	s.element_inventory["Fe"]=40; s.element_inventory["C"]=10; s.element_inventory["Cu"]=20; s.element_inventory["Sn"]=5
	ind.start(s,0,"carbon_steel"); ind.start(s,0,"bronze")
	ind.items={"steel_ingot":6,"pe":9,"steel_bit":1}
	panel._redraw(); for i in range(40): await process_frame
	await shot("deck")
	panel._tab("factory"); await process_frame
	await shot("factory")
	ind.sell(s,"pe",3); panel._tab("market"); await process_frame
	await shot("market")
	panel._tab("gear"); await process_frame
	await shot("gear")
	game.queue_free(); await process_frame
	print("STARFORGE CAPTURE done (%s)" % tag); quit(0)
