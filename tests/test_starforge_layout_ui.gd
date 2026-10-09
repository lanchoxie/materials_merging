extends SceneTree
## v0.37.1 (phone report "第二个浮岛被截断"): with every building kind, staff and lots on the deck,
## no 星锻岛 tab grows past its right-hand panel. Needs real fonts, so the runner opens a window
## (it waits for RenderingServer.frame_post_draw once).
const Main=preload("res://scripts/main.gd")
const Industry=preload("res://scripts/industry.gd")
var checks=0
var failures=[]
var game

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
	create_timer(120).timeout.connect(func(): push_error("starforge layout timeout"); quit(2))

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var ind=s.industry
	await process_frame; await RenderingServer.frame_post_draw
	preload("res://scripts/test_mode.gd").open_starforge(s,900); ind.gain(Industry.step(14)); ind.solar=[0.3,0.3,0.3,0.3,0.3,0.3]
	s.coins=900000; ind.plots=12
	var kinds=["metal_works","polymer_works","trade_hub","home_studio","staff_housing","inorganic_works","silicon_works","test_bench"]
	for i in range(kinds.size()): ind.build(s,i,kinds[i])
	preload("res://scripts/test_mode.gd").finish_service(s)
	for i in range(3): s.campus_hire("engineer")
	preload("res://scripts/test_mode.gd").finish_service(s)
	for row in ind.candidates(s):
		if row.ready: s.campus_promote(int(row.id))
	ind.items={"steel_ingot":3,"duralumin":2,"glass":2,"pe":4,"chair_nova":1}
	for id in ind.items.keys(): ind._reconcile(id)
	ind.tick(s,0.1)
	game._show_starforge(); var panel=game.modal
	var box: Control=panel.scroll.get_parent().get_parent()
	for tab in ["deck","factory","staff","market","gear"]:
		panel._tab(tab); await process_frame; await process_frame
		var widest=box.get_global_rect().end.x
		for node in panel.body.find_children("*","Control",true,false):
			if node.is_visible_in_tree(): widest=maxf(widest,node.get_global_rect().end.x)
		check(widest<=1413.0,"the %s tab stays inside its panel (%.0f px of 1412)" % [tab,widest])
	check(panel.header.get_global_rect().end.x<=panel.close_button.get_global_rect().position.x+1,"the header never runs under the return button")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("STARFORGE LAYOUT OK (%d checks)" % checks); quit(0)
	else: print("STARFORGE LAYOUT FAILED: ",failures); quit(1)
