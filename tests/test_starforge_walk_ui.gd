extends SceneTree
## v0.43 星锻岛漫步 (user request): walk island Ⅱ in first person — factories block and open their
## management with E (and the walk waits), decorations are placed from the toolbox with a tile
## ghost and stored back with E, 星锻公寓 can be entered, staff stand on the deck, and the deck map
## expands the island where you tap.
const Main=preload("res://scripts/main.gd")
const Industry=preload("res://scripts/industry.gd")
var checks:=0
var failures=[]
var game
func check(ok: bool,msg: String)->void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func button(node: Node,text: String):
	if node is Button and node.text.contains(text): return node
	for child in node.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
func _initialize()->void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(120).timeout.connect(func(): quit(2))

## Stand at `from` and look at `to` (ground points), slightly down so the deck is in reach.
func look(walk,from: Vector2,to: Vector3,pitch: float=-0.25) -> void:
	walk.walker.position=from; walk.walker.reset_height()
	walk.walker.yaw=atan2(-(to.x-from.x),-(to.z-from.y)); walk.walker.pitch=pitch; walk._camera()

func _run()->void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,800); s.coins=500000; ind.credits=900
	ind.build(s,0,"staff_housing"); ind.build(s,1,"metal_works"); ind.build(s,3,"staff_lounge")
	ind.staff.append({"id":1,"name":"林工","role":"engineer","specialty":"","home":0,"factory":1,"energy":100.0,"resting":false})
	ind.staff.append({"id":2,"name":"周博","role":"doctor","specialty":"","home":0,"factory":-1,"energy":30.0,"resting":true})
	ind.staff_serial=3
	s.storage.decorations["flower_bed"]=1; s.storage.decorations["bench"]=1
	game._show_starforge(); for i in range(3): await process_frame
	var panel=game.modal
	check(button(panel,"第一人称登岛")!=null and not button(panel,"第一人称登岛").disabled,"the starforge screen offers a first-person visit")
	# Deck map: tap a ＋ west of the deck.
	var plus=null
	for b in _buttons(panel,[]):
		if b.text=="＋" and b.tooltip_text=="在这里扩建": plus=b; break
	check(plus!=null,"the deck map shows cells to expand into")
	var plots=ind.plots
	if plus!=null: plus.pressed.emit(); await process_frame
	check(ind.plots==plots+1,"tapping ＋ builds the deck out there")
	button(panel,"第一人称登岛").pressed.emit(); for i in range(3): await process_frame
	var walk=game.modal
	check(walk!=null and walk.has_method("enter_apartment") and walk.walker!=null,"the walk opens")
	check(walk.terrain.inside(walk.walker.position) and not walk.terrain.blocked(walk.walker.position),"the visitor starts on free deck")
	check(walk.view.walk_mode and walk.view.figures.size()==2,"both staff stand on the deck")
	var lounge=ind.plot_center(3)
	check(walk.view.staff_spot(ind,ind.staff[1]).distance_to(lounge)<1.5,"the tired doctor is in the lounge")
	# Factories block walking.
	var factory=ind.plot_center(1)
	check(walk.terrain.blocked(Vector2(factory.x,factory.z)) and walk.terrain.blocked(Vector2(factory.x+1.0,factory.z)),"factories block the way")
	# E on the factory opens its management; closing it returns to the walk where it was.
	var stand=Vector2(factory.x,factory.z+1.45)
	look(walk,stand,factory+Vector3(0,0.6,0),0.0)
	var t=walk.aim()
	check(t.get("kind","")=="building" and int(t.get("index",-1))==1,"the crosshair finds the factory")
	walk._interact(); for i in range(3): await process_frame
	check(game.modal!=walk and game.modal.has_method("focus_plot") and game.modal.section=="factory","E opens the factory's management")
	check(game.modal.close_button.text.contains("星锻岛漫步"),"management says it returns to the walk")
	game.modal._close(); for i in range(3): await process_frame
	check(game.modal==walk and walk.walker.position.is_equal_approx(stand),"closing management resumes the walk in place")
	# Hold a flower bed and set it down on the empty plot 3 (index 2).
	var empty=ind.plot_center(2)
	walk._hold("flower_bed")
	check(walk.holding=="flower_bed","the toolbox bar puts a decoration in hand")
	look(walk,Vector2(empty.x-1.0,empty.z+0.2),empty,-0.5)
	t=walk.aim()
	check(t.get("kind","")=="ground","the crosshair finds open deck")
	walk._ghost()
	check(walk.ghost.visible and walk.ghost.material_override.albedo_color.g>0.9,"a green ghost shows where it goes")
	walk._interact(); await process_frame
	check(ind.decorations().size()==1 and int(s.storage.decorations.get("flower_bed",0))==0 and walk.holding=="","E places it from the toolbox")
	check(walk.view.decor_root.get_child_count()==1,"the decoration is drawn on the deck")
	look(walk,Vector2(empty.x-1.0,empty.z+0.2),empty,-0.5)
	t=walk.aim()
	check(t.get("kind","")=="decor","the crosshair finds the decoration")
	walk._interact(); await process_frame
	check(ind.decorations().is_empty() and int(s.storage.decorations.flower_bed)==1,"E stores it back in the toolbox")
	# A bench won't fit half off the plot: the ghost turns red and nothing is placed.
	walk._hold("bench"); walk.rot=0
	var spot=walk.placement(Vector2(empty.x+1.49,empty.z))
	check(spot.plot==2 and spot.error.is_empty(),"placement clamps the footprint inside the plot")
	# Into 星锻公寓 and back out.
	var flats=ind.plot_center(0)
	look(walk,Vector2(flats.x,flats.z+1.45),flats+Vector3(0,0.6,0),0.0)
	walk._hold("")
	walk._interact(); for i in range(2): await process_frame
	check(walk.interior_mode and walk.interior_layout.kind=="staff_housing","E walks into the staff apartments")
	check(walk.interior_layout.fixtures.filter(func(f): return f.type=="bed").size()==4,"four beds at level 1")
	walk._exit_apartment(); await process_frame
	check(not walk.interior_mode and walk.terrain==walk.deck_terrain,"leaving puts you back on the deck")
	# Leaving the walk returns to management.
	walk._close(); for i in range(3): await process_frame
	check(game.modal!=null and game.modal.has_method("focus_plot"),"leaving the walk returns to the starforge screen")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("STARFORGE WALK UI OK (%d checks)" % checks); quit(0)
	else: print("STARFORGE WALK UI FAILED: ",failures); quit(1)

func _buttons(node: Node,out: Array) -> Array:
	if node is Button: out.append(node)
	for child in node.get_children(): _buttons(child,out)
	return out
