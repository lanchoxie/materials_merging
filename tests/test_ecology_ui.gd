extends SceneTree
const Main=preload("res://scripts/main.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(45).timeout.connect(func(): push_error("Ecology UI timeout"); quit(2))
func find_button(node: Node,text: String):
	if node is Button and node.text.begins_with(text): return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null: return found
	return null
func button(text: String) -> void:
	var b=find_button(game.modal,text); check(b!=null,"button: "+text)
	if b!=null: b.pressed.emit()
	await process_frame; await process_frame
func drop(site: String,touch: bool=true) -> void:
	var p=game.modal; var start=p.tray.get_global_rect().get_center()
	var finish=p.viewport_box.global_position+p.view.project_site(site)*p.viewport_box.size/Vector2(p.viewport.size)
	if touch:
		await game._test_touch(start,true)
		var move=InputEventScreenDrag.new(); move.index=0; move.position=finish; move.relative=finish-start; Input.parse_input_event(move); await process_frame
		await game._test_touch(finish,false)
	else:
		var down=InputEventMouseButton.new(); down.position=start; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; Input.parse_input_event(down); await process_frame
		var move=InputEventMouseMotion.new(); move.position=finish; move.relative=finish-start; move.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(move); await process_frame
		var up=InputEventMouseButton.new(); up.position=finish; up.button_index=MOUSE_BUTTON_LEFT; Input.parse_input_event(up); await process_frame
func capture(name: String) -> void:
	game.toast_panel.hide(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v012.png")
func run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=5000; var p=s.planet
	var sample=s.product_snapshot(s._new_reactor(3,"oxygen",0)); s.storage.add_product(sample,2)
	game._show_planet(); await process_frame
	await button("领取合作"); await button("供氧器")
	var panel=game.modal
	check(panel.view.display_mode=="ecology" and panel.view.ecology_view.visible and not panel.view.sites.deep.root.visible,"ecology replaces water geometry without layering scenes")
	await button("提交氧气"); await button("补充1份供料"); await button("开始制作")
	p.tick(35); await create_timer(0.3).timeout
	check(p.available_products("oxygen_station")==1,"O2 sample through workshop produces a distinct device")
	await drop("fish")
	check(p.worlds.get_world().ecology.regions.fish.device and p.available_products("oxygen_station")==0,"touch installs actual device in fish bay")
	await button("补给盒"); await button("补充1份供料"); await button("开始制作")
	p.tick(25); await create_timer(0.3).timeout; await drop("fish",false)
	check(p.worlds.get_world().ecology.regions.fish.gas>58 and p.available_products("oxygen_cartridge")==0,"mouse installs charge in existing device")
	await button("观察 / 对照"); await button("鱼湾")
	p.tick(55); await create_timer(0.4).timeout
	check(panel.view.ecology_view.sites.fish.station.visible,"installed supply device is visible")
	check(panel.eco_widgets.stats.text.contains("湾内") and panel.eco_widgets.chart.samples.size()>8,"live cohort readout and time trace present")
	await capture("ecology-fish")
	await button("回看过程")
	var now=p.serialize(); var current=int(p.worlds.get_world().seconds)
	panel.replay_index=0; panel._live(); await process_frame
	check(panel.view.snapshot.seconds==0 and p.worlds.get_world().seconds==current,"replay changes display time only")
	panel._begin_drag(panel.tray.get_global_rect().get_center()); panel._do("ecology",{"site":"fish","control":"gate"})
	check(not panel.dragging and Same.same(now,p.serialize()),"replay blocks deployment and controls without rollback or resource effects")
	await capture("ecology-replay")
	await button("回到当前")
	check(panel.replay_index==-1 and panel.view.snapshot.seconds==current and p.worlds.get_world().paused,"leaving replay returns to paused present")
	await button("从初始生态创建实验")
	await button("供氧器"); await drop("microbe"); await button("补给盒"); await drop("microbe")
	await button("从初始生态创建实验")
	await button("供氧器"); await drop("fish"); await button("补给盒"); await drop("fish")
	for i in range(6): await button("两个实验同步")
	check(p.worlds.get_world("trial_a").ecology.regions.microbe.sensitive<40 and p.worlds.get_world("trial_b").ecology.regions.fish.bay>5,"same-time interventions visibly yield opposite biological outcomes")
	await button("实验 A"); await button("厌氧池"); await create_timer(0.5).timeout
	check(panel.view.ecology_view.sites.microbe.sensitive[0].scale.x<0.75,"sensitive mat physically shrinks")
	check(not panel.view.ecology_view.sites.microbe.bubbles[0].visible,"spent device stops bubble animation")
	await capture("ecology-microbe")
	check(panel.body.size.x<=360 and panel.tray.get_global_rect().end.y<=850,"ecology controls and inventory remain within layout")
	var sealed=p.worlds.get_world().ecology.regions.microbe.sealed
	await button("接通避难池")
	check(not p.worlds.get_world().ecology.regions.microbe.sealed and sealed,"refuge control is connected to simulation")
	await button("流量")
	check(p.worlds.get_world().ecology.regions.microbe.flow==2,"flow control changes equipment setting")
	panel.handle_back(); await process_frame
	check(game.modal==null and not p.observing,"exit suspends ecology and restores island")
	s.close_science(); print("ECOLOGY UI: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
