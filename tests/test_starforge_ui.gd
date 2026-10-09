extends SceneTree
## v0.34 星锻岛 screen: the toolbar opens it, a locked save sees the unlock card, and an open island
## builds, queues, sells and equips through the panel's own buttons. The top bar shows the XP bar.
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
	create_timer(90).timeout.connect(func(): push_error("starforge ui timeout"); quit(2))

func button(node: Node,prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix) and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found=button(child,prefix)
		if found!=null: return found
	return null

func _gone(node) -> bool:
	await process_frame; await process_frame
	return not is_instance_valid(node) and game.modal==null

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; await process_frame; await process_frame
	check(game.rank_label.text.begins_with("岛主 Lv.") and game.rank_bar!=null,"the top bar shows 岛主 rank and an XP bar")
	var open=button(game,"星锻岛")
	check(open!=null,"the toolbar has a 星锻岛 button")
	open.pressed.emit(); await process_frame
	var panel=game.modal
	check(panel!=null and panel.get_script()==preload("res://scripts/starforge_panel.gd"),"it opens the 星锻岛 screen")
	var go=button(panel,"开放星锻岛")
	check(go!=null and go.disabled,"a new save sees the unlock card with the button disabled")
	preload("res://scripts/test_mode.gd").open_starforge(s,400); s.coins=30000
	panel._redraw(); await process_frame
	var build=button(panel,"建冶金工厂")
	check(build!=null and not build.disabled,"an open island offers to build the metallurgy works")
	build.pressed.emit(); await process_frame
	check(s.industry.count("metal_works")==1,"the build button builds it")
	button(panel,"建星港交易所").pressed.emit(); await process_frame
	s.index_found[Industry._keys_for("Fe3C")[0]]=true; s.element_inventory["Fe"]=12; s.element_inventory["C"]=4
	panel._tab("factory"); await process_frame
	var feed=button(panel,"投料")
	check(feed!=null,"the factory tab offers a ready recipe")
	feed.pressed.emit(); await process_frame
	check(s.industry.buildings["0"].jobs.size()==1,"投料 queues a job")
	s.industry.tick(s,60.0); panel._tab("market"); await process_frame
	var sell=button(panel,"卖 1")
	check(sell!=null,"the market lists the made ingots")
	var coins=s.coins; sell.pressed.emit(); await process_frame
	check(s.coins>coins,"selling pays coins")
	s.industry.items["steel_bit"]=1; panel._tab("gear"); await process_frame
	button(panel,"装备到星球").pressed.emit(); await process_frame
	check(s.industry.bit=="steel_bit" and is_equal_approx(s.planet.v2.nature.pick_hv,s.industry.gear_hv("steel_bit")),"the gear tab equips the bit for the planet")
	game._xp_pop(); check(s.industry.pending_xp==0,"XP pops are consumed by the top bar")
	# v0.35: the 科研小镇 晋升 tab approves a promotion into a 星锻公寓 bed.
	s.coins=30000; s.industry.plots=6; s.industry.build(s,5,"staff_housing")
	preload("res://scripts/test_mode.gd").finish_service(s)
	var eng=s.industry.candidates(s).filter(func(x): return x.ready)
	game._show_campus("promotion"); await process_frame
	var approve=button(game.modal,"批准晋升")
	check(not eng.is_empty() and approve!=null and not approve.disabled,"the 晋升 tab offers approval to a ready engineer")
	if approve!=null: approve.pressed.emit(); await process_frame
	check(s.industry.staff.size()==1,"approving moves them to 星锻岛")
	game._show_starforge(); await process_frame
	game.modal._tab("staff"); await process_frame
	var send=button(game.modal,"派到1号冶金工厂")
	check(send!=null,"the staff tab can send them to a factory")
	if send!=null: send.pressed.emit(); await process_frame
	check(int(s.industry.staff[0].factory)==0,"they work at the metallurgy works")
	game.modal._tab("market"); await process_frame
	check(button(game.modal,"换一批合同")!=null,"the market shows the contract board")
	# v0.37.1 (phone report): 返回浮岛 Ⅰ really leaves (layout width: test_starforge_layout_ui, windowed).
	s.industry.plots=10; s.coins=300000; s.industry.credits=900; s.industry.gain(Industry.step(12))
	for kind in ["polymer_works","home_studio","inorganic_works","silicon_works","test_bench"]:
		for i in range(s.industry.plots):
			if not s.industry.buildings.has(str(i)): s.industry.build(s,i,kind); break
	panel=game.modal
	var back=button(panel,"返回浮岛")
	check(back!=null,"the return button is there")
	if back!=null: back.pressed.emit(); await process_frame; await process_frame
	check(game.modal==null and not is_instance_valid(panel),"返回浮岛 Ⅰ closes 星锻岛 and gives the island back")
	game._show_starforge(); await process_frame
	panel=game.modal
	check(panel.handle_back() and (await _gone(panel)),"the Android back button leaves 星锻岛 too")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("STARFORGE UI OK (%d checks)" % checks); quit(0)
	else: print("STARFORGE UI FAILED: ",failures); quit(1)
