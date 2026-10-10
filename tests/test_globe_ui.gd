extends SceneTree
## v0.42 地球仪 (user request): the god view is a globe with a pin where the player last stood; no
## region tabs and no far landmarks; drag turns the globe; the place line shows biome and lat/lon;
## the world map covers the whole wrap-around planet.
const Main=preload("res://scripts/main.gd")
const Shape=preload("res://scripts/planet_shape.gd")
const Globe=preload("res://scripts/planet_globe.gd")
var checks:=0
var failures=[]
var game
func check(ok: bool,msg: String)->void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func buttons(node: Node,out: Array) -> Array:
	if node is Button: out.append(node)
	for child in node.get_children(): buttons(child,out)
	return out
func _initialize()->void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(90).timeout.connect(func(): quit(2))
func _run()->void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._show_planet_v2(); for i in range(4): await process_frame
	var panel=game.modal; var v=game.state.planet.v2; var view=panel.view
	v.world.paused=true
	# God view = globe.
	check(not view.first_person and view.globe_shown and view.globe.visible,"the god view shows the globe")
	check(view.camera.cull_mask==view.GLOBE_LAYER,"only the globe layer is drawn in the god view")
	var names=[]
	for b in buttons(panel,[]): names.append(b.text)
	var region_names=[]
	for spec in v.rules.regions: region_names.append(str(spec.name))
	var tabs_left=names.filter(func(n): return n in region_names)
	check(tabs_left.is_empty(),"no region tab buttons (%s)" % str(tabs_left))
	check(not names.has("近看"),"no close-up button for fixed regions")
	panel._live()
	check(panel.where_label.text.contains("北纬") and panel.where_label.text.contains("上次所在"),"the place line shows lat/lon (%s)" % panel.where_label.text)
	# The pin sits on the globe at the last position.
	var ll=view.pin_lon_lat(); var tip=Globe.sphere_point(ll.x,ll.y,view.GLOBE_RADIUS)+view.globe.position
	check(view.globe_pin.global_position.distance_to(tip)<1.0,"the pin marks the last position on the globe")
	# Drag turns the globe; a tap never selects a region.
	var yaw=view.yaw; var pitch=view.globe_pitch
	var drag=InputEventMouseMotion.new(); drag.button_mask=MOUSE_BUTTON_MASK_LEFT; drag.relative=Vector2(60,30); drag.device=0
	panel.explore_input._map_input(drag)
	check(not is_equal_approx(view.yaw,yaw) and not is_equal_approx(view.globe_pitch,pitch),"dragging turns and tilts the globe")
	var region=str(v.world.current_region)
	panel._map_click(Vector2(400,300))
	check(str(v.world.current_region)==region and view.pick(Vector2(400,300))==view.selected,"a tap on the globe does not jump between regions")
	# Journey tab: home and own waypoints only.
	panel._tab("explore"); await process_frame
	var journey=[]
	for b in buttons(panel.body,[]): journey.append(b.text)
	check(journey.any(func(n): return n.contains("回到起始河湾")),"the journey offers the way home")
	check(not journey.any(func(n): return n.contains("六公里外") or n.contains("千米林海") or n.contains("远方高原") or n.contains("西岸林地")),"no far landmarks to jump to")
	# First person hides the globe; walking somewhere moves the pin.
	panel._enter(); for i in range(3): await process_frame
	check(view.first_person and not view.globe_shown and view.camera.cull_mask&view.GLOBE_LAYER==0,"first person draws the ground, not the globe")
	panel.test_teleport(Vector2(-2400,1200),"测试"); for i in range(3): await process_frame
	var walked=view.walker.position
	panel._live()
	check(panel.where_label.text.contains("当前位置") and panel.world_title.text.contains("°"),"walking shows the biome and coordinates (%s)" % panel.world_title.text)
	panel._enter(); for i in range(3): await process_frame
	check(view.globe_shown and view.last_position().is_equal_approx(walked),"back on the globe, the last position is where I walked")
	var ll2=view.pin_lon_lat()
	check(absf(ll2.x-Shape.longitude(walked.x))<0.01 and absf(ll2.y-Shape.latitude(walked.y))<0.01,"the pin follows to the new place")
	check(absf(view.yaw-deg_to_rad(ll2.x))<0.01,"the globe turns to face the last position")
	# World map over the whole planet.
	panel._open_world_map(); await process_frame
	var map=panel.get_children().back()
	check(map.texture!=null and map.texture.get_width()==512,"the world map uses the planet texture")
	check(map.info.text.contains("°"),"the world map reports coordinates (%s)" % map.info.text)
	map.center=Vector2(8100,0); map._refresh()
	check(map.to_screen(Vector2(-8100,0)).x>map.map_rect.get_center().x,"across the date line, the west is drawn to the east")
	map._tap(map.map_rect.get_center())
	check(map.info.text.contains("°"),"tapping the map shows the place's coordinates")
	if failures.is_empty(): print("GLOBE UI OK (%d checks)" % checks); quit(0)
	else: print("GLOBE UI FAILED: ",failures); quit(1)
