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
	create_timer(75).timeout.connect(func(): push_error("Industry UI timeout"); quit(2))
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
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v016.png")
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
	await button("领取合作"); await button("工业港"); await button("一战背景")
	var panel=game.modal; await create_timer(0.6).timeout
	check(panel.view.display_mode=="industry" and panel.view.industry_view.people.size()==6 and not panel.view.globe.visible,"industrial scene contains six bounded residents")
	check(p.worlds.get_world().paused and p.worlds.get_world().industry.enabled,"industrial career starts paused")
	await capture("industry-start")
	await button("导线对照"); await button("记录电学对照"); await button("同金属重量"); await button("记录电学对照")
	check(p.circuit_reports.size()==2 and panel.section=="circuits","both electrical constraints record independent scientific evidence")
	await capture("industry-circuits")
	await button("制作铝线"); await button("补充1份供料"); await button("开始制作")
	p.tick(24); await create_timer(0.3).timeout; await drop("industry_clinic")
	check(p.available_products("aluminum_wire_mass")==1,"narrow clinic rejects oversized cable without spending product")
	await drop("industry_factory")
	check(p.available_products("aluminum_wire_mass")==0 and p.worlds.get_world().industry.cables.factory=="aluminum_wire_mass","touch drop installs manufactured cable at compatible factory")
	await select_product("generator_set"); await button("提交水样"); await button("补充1份供料"); await button("开始制作")
	p.tick(45); await create_timer(0.3).timeout; await drop("industry_power"); await process_frame; await process_frame
	check(p.worlds.get_world().industry.engine and panel.view.industry_view.engine.visible,"installed engine appears in actual scene")
	await button("观察 / 对照"); await button("复制工业港")
	for id in ["fuel_can","heat_recovery","industry_stock"]:
		await select_product(id); await drop("industry_power" if id=="heat_recovery" else "industry_depot",false)
	for site in ["homes","clinic","signal"]:
		await select_product("copper_wire"); await drop("industry_"+site)
	await button("生产优先"); await button("工业港观察30秒"); await button("工业港观察30秒"); await button("工业港观察30秒")
	var w=p.worlds.get_world().industry
	check(w.generated_W>0 and w.shipped.civil>0 and w.transport_fuel_kg>0,"rendered industrial world powers factory and delivers finite fuel cargo")
	check(panel.view.industry_view.windows.factory.material_override.albedo_color==Color("edcf91"),"factory window responds to real allocated power")
	await capture("industry-running")
	await button("工业港观察30秒")
	check(w.integrity.signal==0 and w.repair.target=="signal" and panel.industry_widgets.lines.text.contains("工程师检修"),"broken communication line creates an actual repair task in scene and sidebar")
	await button("回看过程"); panel.replay_index=0; panel._live(); await process_frame
	var before=p.serialize(); panel._do("industry",{"control":"blackout"}); panel._begin_drag(panel.tray.get_global_rect().get_center())
	check(Same.same(before,p.serialize()) and not panel.dragging,"historical industrial view rejects controls and deployment")
	check(panel.view.industry_view.snapshot.industry.elapsed<w.elapsed,"replay displays an older industrial state")
	await button("回到当前"); await button("展开能量账本")
	check(panel.industry_widgets.ledger.text.contains("运输燃料"),"ledger includes nonfree logistics energy")
	await button("新实验 · 二战背景")
	for item in [["generator_set","power"],["heat_recovery","power"],["fuel_can","depot"],["copper_wire","homes"],["copper_wire","clinic"],["copper_wire","factory"],["copper_wire","signal"]]:
		await select_product(item[0]); await drop("industry_"+item[1])
	await button("生产优先")
	for i in range(5): await button("工业港观察30秒")
	w=p.worlds.get_world().industry; await create_timer(0.3).timeout
	check(w.era=="ww2" and w.alert and panel.view.industry_view.truck.visible and not panel.view.industry_view.train.visible,"second historical background uses truck and air-raid shelter response")
	var sheltered=0
	for person in w.people: sheltered+=int(person.task=="shelter")
	check(sheltered==6 and w.integrity.power==0.35,"all people actually shelter after walking during warning")
	await capture("industry-alert")
	var scroll=panel.body.get_parent(); scroll.scroll_vertical=0; await process_frame
	var at=scroll.global_position+Vector2(160,310)
	await game._test_touch(at,true)
	for i in range(1,7):
		var drag=InputEventScreenDrag.new(); drag.index=0; drag.position=at+Vector2(0,-180)*i/6; drag.relative=Vector2(0,-30); Input.parse_input_event(drag); await process_frame
	await game._test_touch(at+Vector2(0,-180),false); await process_frame
	check(scroll.scroll_vertical>90 and w.policy=="production","finger scroll moves industrial controls without changing policy")
	check(panel.body.size.x<=360 and panel.watershed_menu.get_global_rect().end.x<=1008,"industrial sidebar and inventory fit their panels")
	check(find_button(panel,"工业港").get_global_rect().end.x<=1024,"six chapter buttons fit separately from sidebar")
	game._close_modal(); s.close_science(); print("INDUSTRY UI: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
