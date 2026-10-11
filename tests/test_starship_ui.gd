extends SceneTree
## v0.48 星际飞船 in play: the commissioned ship stands beside you on the planet; E opens the star
## map (each planet's globe, which one you are on); launching jumps to 赤砂星 and reopens the planet
## view in orbit over it; first person lands at the landing site with the ship parked there.
const Main=preload("res://scripts/main.gd")
var checks:=0
var failures=[]
var game
func check(ok: bool,msg: String)->void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func button(node: Node,text: String):
	if node is Button and node.text.contains(text) and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
func _initialize()->void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(120).timeout.connect(func(): quit(2))
func _run()->void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	check(preload("res://scripts/test_mode.gd").give_ship(s).contains("星际飞船") and s.industry.ship=="starship","the test kit commissions a charged ship")
	game._show_planet_v2(); await process_frame; var panel=game.modal
	s.planet.v2.world.paused=true
	panel._enter(); for i in range(4): await process_frame
	panel._sync(); await process_frame
	check(panel.view.ship_parked and panel.view.ship_node.visible and not s.planet.v2.ship_at.is_empty(),"the ship stands beside you on arrival")
	panel.view.walker.position=panel.view.ship_at+Vector2(3.5,0); panel.view.walker.reset_height()
	check(panel.near_ship(),"close enough to board")
	panel._collect(); for i in range(3): await process_frame
	check(button(game,"跃迁到赤砂星")!=null and button(game,"留在地球")!=null,"E opens the star map: 赤砂星 to jump to, Earth marked as here")
	button(game,"跃迁到赤砂星").pressed.emit(); for i in range(4): await process_frame
	var orbit=game.modal
	check(s.planet.v2.planet=="ember" and orbit!=panel and orbit.has_method("enter_first_person"),"launching swaps the world and opens a fresh planet view")
	check(not orbit.view.first_person and orbit.view.globe_shown,"you arrive in orbit (the globe view)")
	var heading_found=false
	for child in orbit.get_children():
		if child is Label and child.text.begins_with("赤砂星"): heading_found=true
	check(heading_found,"the heading names 赤砂星")
	check(orbit.view.terrain.profile.get("name")=="赤砂星","the view draws 赤砂星's ground")
	orbit._enter(); for i in range(4): await process_frame
	orbit._sync(); await process_frame
	check(orbit.view.first_person and orbit.view.ship_parked and orbit.view.ship_at.distance_to(Vector2(14,21))<0.5,"first person lands at the landing site, the ship beside it")
	check(orbit.view.walker.position.distance_to(Vector2(14,21))<40.0,"you start near the ship")
	game._close_all(); await process_frame
	game._show_starforge(); for i in range(3): await process_frame
	game.modal._tab("gear"); await process_frame
	check(button(game.modal,"停回船坞")!=null,"星锻岛's gear tab shows the commissioned ship")
	game._close_all(); await process_frame
	game._show_time_gate(); await process_frame
	check(button(game,"走过光桥")!=null,"on 赤砂星 the light bridge leads to the landing site, not to Earth's eras")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("STARSHIP UI OK (%d checks)" % checks); quit(0)
	else: print("STARSHIP UI FAILED: ",failures); quit(1)
