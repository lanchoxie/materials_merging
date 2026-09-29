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
	if "--release-ui-test" not in OS.get_cmdline_user_args(): push_error("Use -- --release-ui-test to isolate UI tests from player saves"); quit(2); return
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(75).timeout.connect(func(): push_error("Modern UI timeout"); quit(2))
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
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v017.png")
func select_product(id: String) -> void:
	var menu=game.modal.watershed_menu
	for i in range(1,menu.item_count):
		if menu.get_item_metadata(i)==id: menu.select(i); menu.item_selected.emit(i); break
	await process_frame; await process_frame
func run() -> void:
	Input.emulate_touch_from_mouse=true
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=9000; var p=s.planet
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,2)
	game._show_planet(); await process_frame
	await button("领取合作"); await button("现代城市"); await button("开启现代城市并暂停")
	var panel=game.modal; await create_timer(.6).timeout
	check(panel.view.modern_view.people.size()==6 and p.worlds.get_world().paused and not panel.view.industry_view.visible,"modern scene has six residents and starts paused")
	await capture("modern-start")
	await select_product("modern_silicon"); await button("生产工坊"); await button("提交水样"); await button("补充1份供料"); await button("开始制作")
	p.tick(32); await create_timer(.3).timeout
	await drop("modern_roof"); check(p.available_products("modern_silicon")==1,"touch rejects heavy silicon on light roof without spending")
	await drop("modern_field"); await process_frame; await process_frame
	check(p.available_products("modern_silicon")==0 and panel.view.modern_view.panels.field.root.visible,"actual manufactured solar array appears at valid ground site")
	await select_product("modern_aluminum_sink"); await button("打开材料对照")
	check(panel.material_return_mode=="modern" and panel.material_mode=="same_mass","city thermal qualification opens same-mass reference in correct context")
	await button("记录对照"); await button("制作等重铝散热芯")
	check(panel.view.display_mode=="modern" and panel.selected_recipe=="modern_aluminum_sink","reference confirmation returns directly to modern sink production")
	await button("补充1份供料"); await button("开始制作"); p.tick(24); await create_timer(.3).timeout
	await drop("modern_cooling")
	check(p.worlds.get_world().modern.sink=="modern_aluminum_sink","manufactured sink enters dedicated closed material ledger")
	await button("观察 / 对照"); await button("复制城市")
	for item in [["modern_perovskite","roof"],["modern_battery","battery"],["modern_server","compute"],["modern_fan","cooling"],["modern_recycler","recycle"],["modern_scrap","recycle"]]:
		await select_product(item[0]); await drop("modern_"+item[1],item[1]!="recycle")
	await button("回收优先"); await button("用4份再生件建口袋公园")
	await button("城市观察30秒"); await button("城市观察30秒")
	var w=p.worlds.get_world().modern
	check(w.battery_J>0 and w.flow.compute>0 and panel.view.modern_view.servers[0].visible,"daylight powers real computation and charges finite surplus")
	await capture("modern-day")
	await button("城市观察30秒"); await button("城市观察30秒"); await button("城市观察30秒"); await button("城市观察30秒")
	check(w.irradiance==0 and w.discharge_W>0 and panel.modern_widgets.status.text.contains("夜晚"),"night consumes stored energy and is identified in live sidebar")
	check(panel.view.modern_view.moon.visible and not panel.view.modern_view.sun.visible,"day-night scene markers follow actual forcing")
	await capture("modern-night")
	await button("回看过程"); panel.replay_index=0; panel._live(); await process_frame
	var prior=p.serialize(); panel._do("modern",{"control":"storage","id":"off"}); panel._begin_drag(panel.tray.get_global_rect().get_center())
	check(Same.same(prior,p.serialize()) and not panel.dragging,"historical view cannot change policy or deploy an item")
	check(panel.view.modern_view.snapshot.modern.elapsed<w.elapsed,"historical view consumes older state only")
	await button("回到当前")
	for i in range(15): await button("城市观察30秒")
	check(w.park and panel.view.modern_view.park.visible and not panel.view.modern_view.scaffold.visible,"real recycler constructs visible park from finite recovered parts")
	check(w.completed.lighting>0 and w.residue>0,"city tasks produce useful optimization while recycling keeps visible residue")
	await capture("modern-park")
	await button("展开能量与来源")
	check(panel.modern_widgets.ledger.text.contains("储能损耗") and panel.modern_widgets.ledger.text.contains("残渣"),"energy ledger exposes storage losses and persistent waste")
	var scroll=panel.body.get_parent(); scroll.scroll_vertical=0; await process_frame
	var at=scroll.global_position+Vector2(160,310); var policy=w.policy
	await game._test_touch(at,true)
	for i in range(1,7):
		var drag=InputEventScreenDrag.new(); drag.index=0; drag.position=at+Vector2(0,-180)*i/6; drag.relative=Vector2(0,-30); Input.parse_input_event(drag); await process_frame
	await game._test_touch(at+Vector2(0,-180),false); await process_frame
	check(scroll.scroll_vertical>90 and w.policy==policy,"finger swipes scroll long city panel without triggering policies")
	check(panel.body.size.x<=360 and panel.watershed_menu.get_global_rect().end.x<=1008,"long product names and city controls stay in layout")
	check(find_button(panel,"现代城市").get_global_rect().end.x<=1024,"seven scene buttons fit before observation sidebar")
	game._close_modal(); s.close_science(); print("MODERN UI: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
