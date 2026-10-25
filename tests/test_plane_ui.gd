extends SceneTree
## 小飞机 in play: deployed from 星锻岛 or the backpack, parked at the shore; F boards; W opens the throttle
## and it takes off from the water; aloft the far terrain shows (curved), the flat sea plane hides,
## no wildlife sites spawn on the way and the chunk stream pauses; after landing E gets off.
const Main=preload("res://scripts/main.gd")
const Shape=preload("res://scripts/planet_shape.gd")
var checks:=0
var failures=[]
var game
func check(ok: bool,msg: String)->void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func _initialize()->void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(150).timeout.connect(func(): quit(2))
func _run()->void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	check(preload("res://scripts/test_mode.gd").give_plane(s).contains("小飞机") and s.industry.plane=="plane","the test kit deploys a charged plane")
	game._show_planet_v2(); await process_frame; var panel=game.modal
	v.world.paused=true
	panel._enter(); for i in range(4): await process_frame
	panel._sync(); await process_frame
	check(not v.plane_at.is_empty() and panel.view.plane_parked and panel.view.plane_node.visible,"the plane is parked beside you on arrival")
	# Exercise the same backpack action as the mobile Place button, then require
	# another frame to complete (a blocked placement cannot reach this assertion).
	s.industry.deploy_plane(""); panel._sync()
	panel._use_item("vehicle:plane"); await process_frame; await process_frame
	check(panel.view.plane_parked and panel.view.plane_node.visible and is_finite(panel.view.plane.altitude),"backpack placement returns and the next frame displays a parked plane")
	s.industry.recharge_plane(float(s.industry.rules().plane.recharge_seconds))
	# Move the plane and the player to the western shore (the plane on the water).
	var shore=Vector2.INF
	for i in range(1,900):
		var q=Vector2(-i*4.0,445.0)
		if Shape.is_ocean(q.x,q.y): shore=q; break
	panel.test_teleport(shore+Vector2(6,0),"海岸"); for i in range(4): await process_frame
	panel.view.walker.position=shore+Vector2(2.5,0); panel.view.walker.reset_height()
	v.plane_at={"x":shore.x-1.5,"z":shore.y,"heading":PI/2}; panel.view.park_plane(Vector2(shore.x-1.5,shore.y),PI/2)
	check(panel.near_plane(),"standing on the beach, the plane is in reach")
	panel._attack(); await process_frame
	check(panel.view.flying and v.flying and panel.view.pilot()==panel.view.plane,"F boards; the controls fly the plane")
	panel._aim()
	check(panel.aim_label.text.begins_with("小飞机") and panel.aim_label.text.contains("km/h"),"the flight panel replaces the aim line")
	var sites=v.population.sites.size()
	panel.view.plane.movement=Vector2(0,-1); panel.view.plane.pitch_target=0.25
	await create_timer(11.0).timeout
	check(panel.view.plane.airborne and panel.view.plane.height_above_ground()>25.0,"it takes off from the water and climbs (%.0f m)" % panel.view.plane.height_above_ground())
	await create_timer(4.0).timeout
	check(panel.view.far_terrain.visible and panel.view.far_terrain.mesh!=null and not panel.view.sea_node.visible,"aloft, the far terrain shows and the flat sea hides")
	check(panel.view.camera.far>=3000.0,"the camera sees kilometres")
	sites=v.population.sites.size(); panel.view.plane.position+=Vector2(-300,0)
	panel._sync(); panel._sync()
	check(v.population.sites.size()==sites,"no wildlife sites spawn under a high flight")
	var pending=panel.view.stream.pending.size(); panel.view._terrain(0)
	check(panel.view.stream.pending.size()==pending,"the chunk stream pauses aloft")
	panel._attack(); await process_frame
	check(panel.view.flying and panel.message.contains("还在空中"),"F won't drop you out of the sky")
	# Land: put it down on the sea and stop.
	var pl=panel.view.plane
	pl.airborne=false; pl.altitude=pl.floor_at(pl.position,INF); pl.speed=0.0; pl.throttle=0.0; pl.movement=Vector2.ZERO
	await process_frame
	panel._sync()
	check(float(v.plane_at.x)!=shore.x-1.5,"the planet keeps the plane's position while flying")
	# Get off near land: fly it back to the beach first (place it at the shore).
	pl.position=Vector2(shore.x-1.5,shore.y); pl.altitude=pl.floor_at(pl.position,INF)
	panel._attack(); await process_frame
	check(not panel.view.flying and not v.flying and panel.message.contains("下机"),"stopped at the shore, F gets off (%s)" % panel.message)
	check(not panel.view.far_terrain.visible and panel.view.sea_node.visible,"on foot the near world is back")
	var path="res://saves/test_plane_ui.json"
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	check(s.save_game(path).begins_with("已保存"),"the game saves with the plane parked")
	var loaded=preload("res://scripts/lab_state.gd").new()
	check(loaded.load_game(path) and loaded.industry.plane=="plane" and not loaded.planet.v2.plane_at.is_empty(),"and loads it back")
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	game.queue_free(); await process_frame
	if failures.is_empty(): print("PLANE UI OK (%d checks)" % checks); quit(0)
	else: print("PLANE UI FAILED: ",failures); quit(1)
