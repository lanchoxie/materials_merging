extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900); _run.call_deferred()
func point(index: int) -> Vector2:
	var p=game.state.plots[index]
	return game.world_box.global_position+game.world.camera.unproject_position(Vector3(p.x*3.0,0.08,p.z*3.0))*game.world_box.size/Vector2(game.world_viewport.size)
func move_touch(at: Vector2,from: Vector2) -> void:
	var event=InputEventScreenDrag.new(); event.index=0; event.position=at; event.relative=at-from
	Input.parse_input_event(event); await process_frame
func capture(label: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+label+"-v010.png")
func _run() -> void:
	game=Main.new(); root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=20000; s.materials=[200,200,200]
	s.campus_build(3,"academician_villa")
	s.campus_build(7,"professor_apartment"); s.campus_upgrade(7)
	s.buy_plot(0); s.campus_build(0,"park")
	s.buy_plot(1); s.campus_build(1,"doctor_dorm")
	game._sync_world(); game._select_plot(3)
	await create_timer(0.5).timeout
	game.toast_panel.hide(); game.order_bubbles.hide(); game.order_bubbles.set_process(false)
	await capture("architecture")
	check(game.campus_view.scenery.get_node("Plot_0/Building").get_meta("architecture")=="park","park has a visible model")
	check(game.campus_view.scenery.get_node("Plot_3/Building").get_meta("architecture")=="academician_villa","villa has its own architecture")
	# A real touch must lift and move, without panning the camera.
	var start=point(3); var destination=point(5); var camera_before=game.world.camera.position
	await game._test_touch(start,true)
	await create_timer(0.58).timeout
	check(game.building_drag.active,"hold lifts a building")
	await move_touch(destination,start)
	await capture("building-drag")
	await game._test_touch(destination,false)
	check(s.plots[5].kind=="academician_villa" and s.plots[3].kind=="empty","release moves villa to empty destination")
	check(game.world.camera.position.is_equal_approx(camera_before),"building drag does not pan")
	# Occupied destinations and releases outside the map preserve the original building.
	start=point(5); destination=point(4)
	await game._test_touch(start,true); await create_timer(0.55).timeout
	await move_touch(destination,start); await game._test_touch(destination,false)
	check(s.plots[5].kind=="academician_villa" and s.plots[4].kind=="reactor","occupied drop cancels")
	await game._test_touch(point(5),true); await create_timer(0.55).timeout
	await game._test_touch(Vector2(20,450),false)
	check(not game.building_drag.active and s.plots[5].kind=="academician_villa","outside release cancels gesture")
	start=point(5)
	await game._test_touch(start,true); await move_touch(start+Vector2(50,0),start)
	await create_timer(0.55).timeout
	check(not game.building_drag.active,"quick drag remains map panning")
	await game._test_touch(start+Vector2(50,0),false)
	# Camera gestures do not rebuild geometry each frame.
	await create_timer(0.4).timeout
	var before=game.world.geometry_rebuilds
	for i in range(20):
		game.world.pan_view(Vector2(0.07,0)); await process_frame
	check(game.world.geometry_rebuilds==before,"no geometry rebuild during continuous camera gesture")
	await create_timer(0.4).timeout
	check(game.world.geometry_rebuilds<=before+1,"at most one rebuild after settling")
	game._show_toolbox(); await process_frame; await process_frame
	check(game.world_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"covered island stops drawing behind modal")
	game._close_modal(); await process_frame; await process_frame
	check(game.world_viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"closing modal restores island rendering")
	game._select_plot(4); game._show_build_menu()
	check(game.state.plots[game.modal.selected_plot].kind=="empty","global building menu opens an empty parcel")
	await capture("build-menu")
	game._close_modal()
	s.close_science(); print("POLISH UI: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
