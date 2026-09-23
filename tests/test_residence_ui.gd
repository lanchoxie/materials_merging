extends "res://tests/test_river_field_ui.gd"

var panel
var outside: Vector2
var facing: float
var pitch: float

func enter_from_street() -> void:
	var plot=game.state.plots[3]
	panel.walker.position=Vector2(plot.x*3,plot.z*3+1.35); panel.walker.yaw=0; panel.walker.pitch=-0.08; panel.walker.reset_height(); panel._camera()
	outside=panel.walker.position; facing=panel.walker.yaw; pitch=panel.walker.pitch
	panel.input.grab_focus(); await key(KEY_E); await process_frame
	check(game.modal==panel and panel.interior_mode,"real building E route retains same first-person host")
	check(panel.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and panel.world.process_mode==Node.PROCESS_MODE_DISABLED,"island rendering and actors pause inside")
	check(panel.room_viewport.find_world_3d()!=panel.viewport.find_world_3d(),"room lights and camera have an isolated world")

func point_at(item: Dictionary) -> void:
	var origin=panel.interior_surface.spawn(""); var queue=[Vector2i.ZERO]; var seen={Vector2i.ZERO:true}; var index=0
	var destination=item.box.get_center()+Vector3(0,0.12,0)
	while index<queue.size():
		var k=queue[index]; index+=1; var at=origin+Vector2(k)*0.25; var eye=Vector3(at.x,1.67,at.y)
		if eye.distance_to(destination)<2.0 and panel.interior.query(eye,(destination-eye).normalized()).get("index",-1)==int(item.id):
			panel.walker.position=at; panel.walker.reset_height(); var delta=destination-panel.walker.eye()
			panel.walker.yaw=atan2(-delta.x,-delta.z); panel.walker.pitch=atan2(delta.y,Vector2(delta.x,delta.z).length()); panel._camera(); panel.input.grab_focus(); return
		for delta in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next=k+delta
			if seen.has(next) or panel.interior_surface.blocked(origin+Vector2(next)*0.25): continue
			seen[next]=true; queue.append(next)
	check(false,"fixture is reachable: "+item.title)

func find_fixture(type: String) -> Dictionary:
	for item in panel.interior_layout.fixtures:
		if item.type==type: return item
	return {}

func assert_return() -> void:
	check(game.modal==panel and not panel.interior_mode,"exit returns to walking, not management")
	check(panel.walker.position.is_equal_approx(outside) and is_equal_approx(panel.walker.yaw,facing) and is_equal_approx(panel.walker.pitch,pitch),"entry position and full orientation restored")
	check(panel.world.camera.current and panel.input.walking and panel.input.has_focus(),"island camera and controls resume")
	check(panel.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS and panel.world.process_mode==Node.PROCESS_MODE_INHERIT,"island simulation rendering resumes")

func touch_action(label: String) -> void:
	var b=button(panel,label); check(b!=null,"touch action exists: "+label)
	if b==null: return
	var pos=b.get_global_rect().get_center()
	await game._test_touch(pos,true); await game._test_touch(pos,false); await process_frame

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; s.coins=10000; s.campus_build(3,"engineer_house")
	game._show_island_walk(); await process_frame; panel=game.modal
	await enter_from_street(); await capture("residence-engineer-l1")
	var coins=s.coins; var capacity=s.layout.capacity(s.plots[3])
	for type in ["chair","bed"]:
		var item=find_fixture(type); point_at(item); var old=panel.walker.position
		await touch_action("互动 E")
		check(panel.walker.resting==type,"touch anchors observer on "+type)
		check(panel.walker.position.distance_to(Vector2(item.at.x,item.at.z))<0.7,"resting position is furniture, not interaction origin")
		var rest_position=panel.walker.position
		var press=InputEventKey.new(); press.physical_keycode=KEY_W; press.pressed=true; Input.parse_input_event(press)
		await create_timer(0.4).timeout
		check(panel.walker.position==rest_position,"held movement cannot slide resting observer")
		press=InputEventKey.new(); press.physical_keycode=KEY_W; Input.parse_input_event(press)
		await capture("residence-rest-"+type)
		await key(KEY_SPACE)
		check(panel.walker.resting.is_empty() and panel.walker.position==old and not panel.terrain.blocked(old),"keyboard jump stands beside furniture safely")
		point_at(item); await key(KEY_E); await touch_action("跳跃")
		check(panel.walker.resting.is_empty(),"mobile jump also stands from "+type)
	check(s.coins==coins and s.layout.capacity(s.plots[3])==capacity,"furniture visits do not alter wallet or residential capacity")
	panel.walker.position=panel.terrain.spawn(""); panel.walker.reset_height(); panel.walker.yaw=PI; panel.walker.pitch=0; panel._camera()
	await touch_action("互动 E"); await create_timer(0.45).timeout
	check(panel.interior.door_open and is_equal_approx(panel.interior_surface.door_angle,PI/2),"mobile E opens physical door without duplicate click")
	await capture("residence-open-door")
	var e=InputEventKey.new(); e.physical_keycode=KEY_W; e.pressed=true; Input.parse_input_event(e)
	for frame in range(90):
		await process_frame
		if not panel.interior_mode: break
	e=InputEventKey.new(); e.physical_keycode=KEY_W; Input.parse_input_event(e)
	assert_return()
	# Upgrade via the existing paid campus command. The next visit derives its layout from this same plot.
	s.campus_upgrade(3); s.campus_upgrade(3); await enter_from_street()
	check(panel.interior_layout.level==3 and not find_fixture("sofa").is_empty(),"paid upgrades add the level-three living area")
	await capture("residence-engineer-l3"); point_at(find_fixture("sofa")); await key(KEY_E)
	check(panel.walker.resting=="sofa","sofa is a real seat")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST); await process_frame
	check(panel.interior_mode and panel.walker.resting.is_empty(),"Android back first stands up")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST); await process_frame; assert_return()
	# Exercise every residential route, all floors and repeated view ownership.
	for kind in ["doctor_dorm","professor_apartment","academician_villa"]:
		s.plots[3].kind=kind; s.plots[3].building_level=int(s.layout.building_info(kind).max_level); s.layout.mark_changed()
		await enter_from_street()
		await capture("residence-"+kind)
		var floor_count=panel.interior_layout.floors
		for i in range(floor_count):
			if floor_count<=1: break
			point_at(find_fixture("lift")); await key(KEY_E)
			check(panel.interior_layout.floor_number==((i+1)%floor_count)+1,"physical floor terminal cycles only purchased floors")
			check(not panel.terrain.blocked(panel.walker.position),"arrival is clear on every floor")
		await touch_action("离开住宅"); assert_return()
	check(panel.get_child_count()<20,"repeated visits release room viewports")
	# Non-residential clicks retain their original route.
	s.plots[3].kind="institute"; s.layout.mark_changed(); panel.walker.position=Vector2(-3,1.35); panel.walker.reset_height(); panel.walker.yaw=0; panel.walker.pitch=-0.08; panel._camera(); panel.input.grab_focus()
	await key(KEY_E); await process_frame
	check(game.modal==null and not is_instance_valid(panel),"other campus buildings still open management")
	game.queue_free(); await process_frame
	print("RESIDENCE UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
