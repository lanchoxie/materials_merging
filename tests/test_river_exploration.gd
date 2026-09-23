extends SceneTree
const Main=preload("res://scripts/main.gd")
const Terrain=preload("res://scripts/river_terrain.gd")
const Walker=preload("res://scripts/river_walker.gd")
var checks=0
var failures=[]
var panel
var game
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("exploration timeout"); quit(2))
func key(code: int,down: bool) -> void:
	var e=InputEventKey.new(); e.physical_keycode=code; e.keycode=code; e.pressed=down; Input.parse_input_event(e); await process_frame
func touch(index: int,at: Vector2,down: bool) -> void:
	var e=InputEventScreenTouch.new(); e.index=index; e.position=at; e.pressed=down; Input.parse_input_event(e); await process_frame
func drag(index: int,at: Vector2,delta: Vector2) -> void:
	var e=InputEventScreenDrag.new(); e.index=index; e.position=at; e.relative=delta; Input.parse_input_event(e); await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide()
	while not panel.view.stream.pending.is_empty(): await process_frame
	await create_timer(0.15).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func _run() -> void:
	var t=Terrain.new(); var w=Walker.new(t)
	check(t.rules.radius>=30 and t.trees.size()>30,"expanded terrain has real walking space and woodland")
	for region in t.CENTERS:
		w.enter(region); check(not t.blocked(w.position) and t.region_at(w.position)==region,"safe spawn "+region)
	w.enter("meadow"); w.yaw=0; var before=w.position; w.movement=Vector2(0,-1)
	for i in range(60): w.step(1.0/60)
	check(absf(w.position.distance_to(before)-3.2)<0.01,"walking uses metres and frame time")
	check(is_equal_approx(w.eye().y,t.ground(w.position)+1.62),"eye stays above shared terrain surface")
	w.look(Vector2(0,100000),0.003); check(w.pitch>=-1.25,"look cannot flip camera")
	w.position=Vector2(510,0); w.yaw=0; w.movement=Vector2.RIGHT
	for i in range(120): w.step(0.1)
	check(w.position.x<=511.1 and w.position.x>510,"walking stops before expanded world edge")
	w.position=Vector2(0,5); w.barriers=[Rect2(0.8,4,0.1,2)]; w.movement=Vector2.RIGHT
	for i in range(30): w.step(0.1)
	check(w.position.x<0.6,"thin obstacles prevent tunnelling")
	w.barriers=[]; var trunk=t.trees[0]; w.position=trunk-Vector2(1,0); w.movement=Vector2.RIGHT
	for i in range(20): w.step(0.05)
	check(w.position.x<trunk.x-0.4,"tree trunks block the walker")
	w.position=Vector2(-14,0); w.movement=Vector2.RIGHT
	for i in range(50): w.step(0.05)
	check(w.position.x>-7,"footbridge can be crossed without jumping")
	var closed={"meadow":{"buildings":{"frame_bundle":1},"enclosed":true}}
	var open={"meadow":{"buildings":{"frame_bundle":1},"enclosed":false}}
	check(t.blocked(Vector2(11.3,10),t.building_barriers(closed)),"closed gate blocks entry")
	check(not t.blocked(Vector2(11.3,10),t.building_barriers(open)),"open gate permits entry")
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._show_planet_v2(); await process_frame; await process_frame; panel=game.modal
	game.state.planet.v2.world.paused=true; panel._select_region("meadow")
	var world_before=JSON.stringify(game.state.planet.v2.world); var stock_before=JSON.stringify(game.state.storage.batches); var coins=game.state.coins
	await capture("v021-expanded-overview")
	panel._enter(); await process_frame; await process_frame
	check(panel.view.first_person and panel.view.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"enter uses perspective camera")
	check(panel.viewport_box.size.x==1384 and not panel.right_panel.visible,"walking expands the viewport")
	var pos=panel.view.walker.position
	await key(KEY_W,true); await create_timer(0.3).timeout; await key(KEY_W,false)
	check(panel.view.walker.position.distance_to(pos)>0.5,"W actually walks while ecosystem is paused")
	var stop=panel.view.walker.position; await create_timer(0.1).timeout
	check(panel.view.walker.position.distance_to(stop)<0.001,"key release stops movement")
	var mouse=InputEventMouseButton.new(); mouse.position=Vector2(740,450); mouse.button_index=MOUSE_BUTTON_RIGHT; mouse.pressed=true; Input.parse_input_event(mouse); await process_frame
	var mouse_yaw=panel.view.walker.yaw
	var motion=InputEventMouseMotion.new(); motion.position=Vector2(790,450); motion.relative=Vector2(50,0); Input.parse_input_event(motion); await process_frame
	check(panel.view.walker.yaw!=mouse_yaw,"mouse drag rotates first-person camera")
	mouse.pressed=false; mouse.position=Vector2(1430,890); Input.parse_input_event(mouse); await process_frame
	check(not panel.explore_input.mouse_look,"mouse release outside map ends look")
	await capture("v021-first-person-meadow")
	var input=panel.explore_input; var origin=input.global_position
	var left=origin+input.joystick_center(); var right=origin+Vector2(730,300)
	await touch(2,left,true); await touch(3,right,true)
	var yaw=panel.view.walker.yaw
	await drag(2,left+Vector2(0,-50),Vector2(0,-50)); await drag(3,right+Vector2(80,0),Vector2(80,0))
	check(input.move_touch==2 and input.look_touch==3 and panel.view.walker.movement.length()>0.5 and panel.view.walker.yaw!=yaw,"two fingers independently move and look")
	await touch(3,Vector2(1430,890),false)
	check(input.look_touch==-1 and input.move_touch==2,"releasing look outside does not cancel joystick")
	await touch(2,Vector2(1430,890),false); await process_frame
	check(panel.view.walker.movement==Vector2.ZERO,"release outside map clears joystick")
	await key(KEY_W,true); input.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT); await process_frame
	check(panel.view.walker.movement==Vector2.ZERO and input.keys.is_empty(),"focus loss clears held keys")
	await key(KEY_W,false)
	panel.scale=Vector2(0.75,0.75); await process_frame
	var transform=input.get_global_transform_with_canvas(); left=transform*input.joystick_center(); right=transform*Vector2(730,300)
	await touch(6,left,true); await touch(7,right,true); yaw=panel.view.walker.yaw
	await drag(6,left+Vector2(0,-37.5),Vector2(0,-37.5)); await drag(7,right+Vector2(60,0),Vector2(60,0))
	check(input.stick.y<-0.8 and absf(panel.view.walker.yaw-yaw+0.32)<0.001,"scaled viewport preserves joystick and look sensitivity")
	await touch(6,Vector2(1430,890),false); await touch(7,Vector2(1430,890),false)
	panel.scale=Vector2.ONE; await process_frame
	panel._toggle_details(); await process_frame
	check(panel.right_panel.visible and panel.viewport_box.size.x==928,"materials and observation remain accessible while walking")
	yaw=panel.view.walker.yaw
	await touch(4,Vector2(1210,400),true); await drag(4,Vector2(1210,300),Vector2(0,-100)); await touch(4,Vector2(1210,300),false)
	check(panel.view.walker.yaw==yaw and input.look_touch==-1,"sidebar swipe never owns camera")
	await capture("v021-first-person-details")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false); await process_frame
	check(not panel.view.first_person and is_instance_valid(panel) and game.state.planet.v2.active,"first back returns to god view, not island")
	check(JSON.stringify(game.state.planet.v2.world)==world_before and JSON.stringify(game.state.storage.batches)==stock_before and game.state.coins==coins,"exploration and camera modes preserve ecosystem and inventory")
	panel.view.stream.drain(100); await process_frame
	var nodes=panel.view.terrain_root.get_child_count(); var chunks=panel.view.chunks.size()
	for i in range(12):
		panel.view.sync(game.state.planet.v2.world,i%4); panel.view.stream.drain(100)
	check(chunks<80 and panel.view.chunks.size()==chunks and panel.view.terrain_root.get_child_count()==nodes,"season changes reuse bounded chunk nodes")
	panel._select_region("riverbank"); panel._enter(); panel.view.walker.position=Vector2(-12,3); panel.view.walker.yaw=-2.6; panel.view.walker.pitch=-0.1
	await capture("v021-first-person-bridge")
	var frame_samples=[]
	for i in range(120):
		var start=Time.get_ticks_usec(); await process_frame; frame_samples.append((Time.get_ticks_usec()-start)/1000.0)
	frame_samples.sort()
	var metrics={"chunks":chunks,"trees":t.trees.size(),"nodes":nodes,"frame_ms_median":frame_samples[60],"frame_ms_p95":frame_samples[114],"renderer":RenderingServer.get_video_adapter_name(),"note":"Native engine, 120 frames; not Android or browser performance."}
	game.queue_free(); await process_frame
	print("RIVER_EXPLORATION: %d checks, %d failures" % [checks,failures.size()]); print(JSON.stringify(metrics))
	FileAccess.open("res://artifacts/v021-exploration-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	quit(0 if failures.is_empty() else 1)
