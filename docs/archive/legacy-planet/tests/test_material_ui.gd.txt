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
	create_timer(60).timeout.connect(func(): push_error("Materials UI timeout"); quit(2))
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
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v0121.png")
func run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=5000; var p=s.planet
	game._show_planet(); await process_frame
	await button("领取合作"); await button("导热芯")
	var panel=game.modal
	check(panel.view.display_mode=="materials" and not panel.view.globe.visible,"material bench replaces planet for focused comparison")
	check(panel.view.material_view.parts.copper.bar.scale.x==1 and panel.view.material_view.parts.aluminum.bar.scale.x==1,"same-size view preserves geometric equality")
	await create_timer(0.7).timeout; await capture("materials-size")
	await button("记录对照"); await button("同重量")
	check(panel.view.material_view.parts.aluminum.bar.scale.x>panel.view.material_view.parts.copper.bar.scale.x,"equal-mass comparison visibly changes rod widths")
	await button("记录对照"); await capture("materials-mass")
	check(panel.body.size.x<=360,"comparison sidebar stays within screen")
	await button("制作铝芯"); await button("补充1份供料"); await button("开始制作")
	p.tick(24); await create_timer(0.3).timeout
	check(p.available_products("aluminum_light")==1 and panel.view.display_mode=="ecology","comparison leads to a real manufactured component")
	var sample=s.product_snapshot(s._new_reactor(3,"oxygen",0)); s.storage.add_product(sample,2)
	p.command(s,"qualify",{"reference":"oxygen","batch_id":sample.id})
	for id in ["oxygen_station","oxygen_cartridge"]:
		var info=p.recipe(id); p.command(s,"buy_feed",{"input":info.input}); p.command(s,"pack",{"recipe":id}); p.tick(info.seconds)
	await button("供氧器"); await drop("fish"); await button("补给盒"); await drop("fish",false)
	panel._choose_recipe("aluminum_light"); await process_frame; await drop("fish")
	check(p.worlds.get_world().ecology.regions.fish.component.recipe=="aluminum_light" and p.available_products("aluminum_light")==0,"touch installs manufactured aluminum module")
	await button("观察 / 对照"); await button("鱼湾"); await button("流量")
	p.worlds.get_world().paused=true; p.worlds.tick_world(p.worlds.get_world(),10); panel._redraw(); panel._live(); await create_timer(0.4).timeout
	check(panel.eco_widgets.stats.text.contains("铝芯") and panel.eco_widgets.stats.text.contains("热负载"),"equipment readout identifies installed design and thermal load")
	check(panel.view.ecology_view.sites.fish.core.visible,"installed metallic module appears on actual oxygen device")
	await capture("materials-installed")
	await button("回看过程"); panel.replay_index=0; panel._live(); await process_frame
	check(panel.view.snapshot.ecology.regions.fish.component.is_empty(),"historical replay shows pre-installation equipment")
	var before=p.serialize(); panel._do("deploy",{"world_id":"home","site_id":"fish","recipe":"copper_compact","token":p.shipment_serial})
	check(Same.same(before,p.serialize()),"history cannot replace equipment")
	await button("回到当前"); await button("比较与制作导热芯"); await button("查看计算依据")
	check(panel.material_details and panel.body.size.x<=360,"expandable boundary and unknown-property explanation fits")
	await button("观察 / 对照")
	check(panel.view.display_mode=="ecology" and panel.section=="observe","navigation returns from reference bench to actual world")
	panel.handle_back(); await process_frame
	check(game.modal==null and not p.observing,"closing returns to island and stops observation")
	s.close_science(); print("MATERIAL UI: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
