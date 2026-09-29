extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func button(node: Node,text: String):
	if node is Button and node.text.contains(text): return node
	for child in node.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
func matching(node: Node,text: String) -> Array:
	var result=[]
	if node is Button and node.text.contains(text): result.append(node)
	for child in node.get_children(): result.append_array(matching(child,text))
	return result
func settle() -> void:
	for i in range(4): await process_frame
func point(at: Vector3) -> Vector2:
	return game.world_box.global_position+game.world.camera.unproject_position(at)*game.world_box.size/Vector2(game.world_viewport.size)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(70).timeout.connect(func(): quit(2))
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	await settle()
	var bridge=game.light_bridge; var s=game.state
	check(bridge.gate!=null and bridge.visible,"public light bridge appears beside the plaza")
	check(bridge._clear_site(bridge.plaza+bridge.tip,s),"landing platform avoids owned parcels")
	var ring=point(bridge.gate.global_position); var deck=point(bridge.to_global(bridge.start.lerp(bridge.tip,0.6)))
	check(game.world_box.get_global_rect().has_point(ring) and game.world_box.get_global_rect().has_point(deck),"bridge and portal fit the initial island view")
	check(game._on_light_bridge(ring-game.world_box.global_position) and game._on_light_bridge(deck-game.world_box.global_position),"visible ring and bridge deck both have matching hit targets")
	check(not game._on_light_bridge(Vector2(5,5)),"empty sky is not a portal hit")
	var builds=bridge.builds; var nodes=bridge.scenery.get_child_count(); var plots=JSON.stringify(s.plots); var wallet=s.coins
	check(bridge.orbit.get_child_count()==1,"animated runes are merged into a single mesh")
	for i in range(12): bridge.sync(s); bridge._process(0.1)
	check(bridge.builds==builds and bridge.scenery.get_child_count()==nodes,"portal animation and regular sync do not create meshes")
	game.world.orbit(0.45)
	check(game._on_light_bridge(point(bridge.gate.global_position)-game.world_box.global_position),"portal picking follows the rotated island camera")
	game.world.reset_view()
	await capture("light-bridge-island")
	await game._test_pointer(deck,true)
	game.building_drag.tick(1)
	check(not game.building_drag.active and not game.building_drag.armed,"holding the light bridge cannot pick up a building behind it")
	var motion=InputEventMouseMotion.new(); motion.position=deck+Vector2(45,0); motion.relative=Vector2(45,0); motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion); await process_frame; await game._test_pointer(motion.position,false)
	check(game.modal==null and not game.light_bridge_busy,"map dragging over the bridge does not teleport")
	game.world.reset_view(); await settle(); ring=point(bridge.gate.global_position)
	await game._test_pointer(ring,true); await game._test_pointer(ring,false)
	var bridge_openings=bridge.pulse
	game._enter_light_bridge()
	check(bridge.pulse<=bridge_openings,"repeat activation during the transition does not restart it")
	await create_timer(0.8).timeout
	check(game.modal!=null and game.modal.get_script()==preload("res://scripts/planet_v2_panel.gd") and game.modal.view.first_person,"clicking the ring transitions directly into first-person planet exploration")
	check(not game.light_bridge_busy and JSON.stringify(s.plots)==plots and s.coins==wallet,"teleport leaves plots and wallet unchanged and releases input")
	await capture("light-bridge-arrival")
	game.modal._close(); await settle(); deck=point(bridge.to_global(bridge.start.lerp(bridge.tip,0.6)))
	await game._test_touch(deck,true); await game._test_touch(deck,false); await create_timer(0.8).timeout
	check(game.modal!=null and game.modal.view.first_person,"native touch on bridge deck also teleports")
	game._close_modal(); await settle()
	s.coins=10000; s.campus_build(3,"engineer_house"); game._select_plot(3); game._show_campus("build"); await settle()
	var panel=game.modal; panel.scroll.scroll_vertical=10000; await settle()
	var scroll_before=panel.scroll.scroll_vertical
	check(scroll_before>60,"decoration test begins below the first screen")
	panel._pick_prop("fence"); await settle()
	check(absi(panel.scroll.scroll_vertical-scroll_before)<=2,"changing decoration selection preserves scroll")
	var place=matching(panel.body,"摆放所选物件")[-1]; var at=place.get_global_rect().get_center()
	check(panel.scroll.get_global_rect().has_point(at),"last garden slot is visible at saved editing position")
	await game._test_pointer(at,true); await game._test_pointer(at,false); await settle()
	check(s.plots[3].props.size()==1 and int(s.plots[3].props[0].slot)==7,"bottom-slot click actually places the selected decoration")
	check(absi(panel.scroll.scroll_vertical-scroll_before)<=2,"placing a decoration does not jump to top")
	game.toast_panel.hide(); at=button(panel.body,"收入工具箱").get_global_rect().get_center()
	await game._test_touch(at,true); await game._test_touch(at,false); await settle()
	check(s.plots[3].props.is_empty() and int(s.storage.decorations.get("fence",0))==1,"touch removal returns exactly one decoration to the toolbox")
	check(absi(panel.scroll.scroll_vertical-scroll_before)<=2,"touch removal preserves the editing position")
	panel._pick_prop("trophy"); await settle(); panel._prop(7,true); await settle()
	check(s.plots[3].props.is_empty() and absi(panel.scroll.scroll_vertical-scroll_before)<=2,"failed locked-decoration action also preserves scroll")
	await capture("decoration-keeps-scroll")
	panel._pick_prop("flower"); panel._show("people"); await settle()
	check(panel.scroll.scroll_vertical==0,"tab change cancels any stale delayed restore")
	panel._show("build"); await settle(); panel.scroll.scroll_vertical=10000; await settle()
	panel.selected_plot=4; panel._show("build"); await settle()
	check(panel.scroll.scroll_vertical==0,"choosing a different plot intentionally resets to its header")
	game._show_toolbox(); panel=game.modal; panel._tab("elements"); await settle()
	panel.scroll.scroll_vertical=380; await settle(); scroll_before=panel.scroll.scroll_vertical
	panel._redraw(); await settle()
	check(panel.scroll.scroll_vertical==scroll_before,"toolbox refresh keeps the current list position")
	panel._tab("materials"); await settle()
	check(panel.scroll.scroll_vertical==0,"toolbox category change resets position")
	game._show_factory(); panel=game.modal; panel._open_materials(); panel.material_details=true; panel._redraw(); await settle()
	panel.scroll.scroll_vertical=240; await settle(); scroll_before=panel.scroll.scroll_vertical
	panel._do("join"); await settle()
	check(scroll_before>0 and panel.scroll.scroll_vertical>0,"manufacturing action refresh preserves sidebar position")
	# New owned land under an annex moves only the public visual, not the parcel.
	game._close_modal(); var old_tip=bridge.tip
	s.plots.append({"x":int((bridge.plaza.x+old_tip.x)/3),"z":int((bridge.plaza.z+old_tip.z)/3),"unlocked":true,"kind":"empty","road":false,"rid":-1,"props":[]})
	s.layout.mark_changed(); var expanded=JSON.stringify(s.plots); bridge.sync(s)
	check(bridge.tip!=old_tip and bridge._clear_site(bridge.plaza+bridge.tip,s) and JSON.stringify(s.plots)==expanded,"island expansion keeps owned land and moves the public platform clear")
	game.queue_free(); await process_frame
	print("BRIDGE SCROLL UI: ",checks," checks, ",failures.size()," failures")
	FileAccess.open("res://artifacts/bridge-scroll-ui-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
