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
	check(s.industry.bit=="steel_bit" and is_equal_approx(s.planet.v2.nature.pick_hv,7.4),"the gear tab equips the bit for the planet")
	game._xp_pop(); check(s.industry.pending_xp==0,"XP pops are consumed by the top bar")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("STARFORGE UI OK (%d checks)" % checks); quit(0)
	else: print("STARFORGE UI FAILED: ",failures); quit(1)
