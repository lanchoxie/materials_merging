extends SceneTree
## v0.31 Builder through the real UI: spill placement in build mode, the HUD undo/eraser/path
## recycle, the sidebar recycle (two taps) and undo, Ctrl+Z, and the doctor/element gates in the
## template dialog, atom editor and sandbox editor.
const Main=preload("res://scripts/main.gd")
const Town=preload("res://scripts/island_town.gd")
const Fixtures=preload("res://tests/fixtures_v09.gd")
var game
var checks=0
var failures=[]
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	_run.call_deferred()
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/builder-"+label+".png")
func find_button(node: Node, text: String, enabled: bool=true) -> Button:
	if node is Button and node.text.contains(text) and (node.disabled!=enabled): return node
	for child in node.get_children():
		var found=find_button(child,text,enabled)
		if found!=null: return found
	return null
func find_named(node: Node, wanted: String) -> Node:
	if node.name==wanted: return node
	for child in node.get_children():
		var found=find_named(child,wanted)
		if found!=null: return found
	return null
func tile_screen(plot: int, tile: Vector2i) -> Vector2:
	var p: Dictionary=game.state.plots[plot]
	var point=Vector3(float(p.x)*3,0.08,float(p.z)*3)+Town.center(tile,Vector2i.ONE)+Vector3(0,0.08,0)
	var local=game.world.camera.unproject_position(point)
	return game.world_box.global_position+local*game.world_box.size/Vector2(game.world_viewport.size)
func tap(pos: Vector2) -> void:
	await game._test_touch(pos,true)
	await game._test_touch(pos,false)
	await process_frame
func neighbour(plot: int, dx: int) -> int:
	var p: Dictionary=game.state.plots[plot]
	for i in range(game.state.plots.size()):
		var q: Dictionary=game.state.plots[i]
		if int(q.x)==int(p.x)+dx and int(q.z)==int(p.z): return i
	return -1
func paths(plot: int) -> int:
	return game.state.plots[plot].items.filter(func(item): return item.kind=="stone_path").size()

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	s.coins=60000; s.materials=[10000,10000,10000]; s.deliveries=3
	for i in range(s.plots.size()):
		if s.can_expand(i) and not s.plots[i].unlocked: s.buy_plot(i)
	var home=-1
	for i in range(s.plots.size()):
		var east=neighbour(i,1)
		if s.plots[i].unlocked and s.plots[i].kind=="empty" and east>=0 and s.plots[east].unlocked and s.plots[east].kind=="empty": home=i; break
	check(home>=0,"an empty plot with an empty unlocked east neighbour exists")
	if home<0: return _finish()
	var east=neighbour(home,1)
	s.town_place(home,"engineer_house",3,3)
	s.town_journal.clear()
	game._sync_world(); game._select_plot(home); game.world.focus_plot(home)
	await create_timer(0.8).timeout
	# --- Build mode: tapping the east plot's first column centres a 2×2 path on the seam; its anchor
	# (column 11) is on the selected plot, so it belongs there and spills one column east.
	game.town_build.start_place("stone_path")
	await process_frame
	check(game.town_build.active and is_instance_valid(game.town_build.undo_button) and game.town_build.undo_button.disabled,"build mode shows a disabled undo button before anything is placed")
	await tap(tile_screen(east,Vector2i(0,6)))
	check(paths(home)==1 and paths(east)==0,"the path belongs to the plot holding its anchor")
	var hit: Dictionary=s.town_at(Vector2i(int(s.plots[home].x)*12+12,int(s.plots[home].z)*12+6))
	check(int(hit.get("plot",-1))==home and hit.get("id","")!="","the path's second column covers the neighbouring plot's first tile")
	check(not game.town_build.undo_button.disabled and game.town_build.undo_button.tooltip_text.contains("石板路"),"the HUD undo button names what it will undo")
	await capture("spill")
	game.town_build.undo_button.pressed.emit(); await process_frame
	check(paths(home)==0 and game.town_build.active,"HUD undo removes the path and keeps build mode open")
	await tap(tile_screen(east,Vector2i(0,6)))
	await tap(tile_screen(home,Vector2i(6,9)))
	check(paths(home)==2,"two paths placed again")
	# Island-wide path recycle needs two taps.
	var before=int(s.storage.decorations.get("stone_path",0))
	var recycle=game.town_build.paths_button
	recycle.pressed.emit(); await process_frame
	check(paths(home)==2 and recycle.text.contains("再点一次"),"first tap on island path recycle only arms it")
	recycle.pressed.emit(); await process_frame
	check(paths(home)==0 and int(s.storage.decorations.get("stone_path",0))==before+2,"second tap stores every path in the toolbox")
	game.town_build.undo_button.pressed.emit(); await process_frame
	check(paths(home)==2 and int(s.storage.decorations.get("stone_path",0))==before,"undo puts the recycled paths back")
	# Eraser stores what it is dragged over.
	find_button(game.town_build.hud,"擦除").pressed.emit(); await process_frame
	check(game.town_build.erasing and find_button(game.town_build.hud,"改为摆放")!=null,"the HUD eraser switches the mode")
	await tap(tile_screen(home,Vector2i(6,9)))
	check(paths(home)==1 and int(s.storage.decorations.get("stone_path",0))==before+1,"tapping with the eraser stores that path")
	await capture("erase")
	game.town_build.finish(); await process_frame
	check(not game.town_build.active,"done closes build mode")
	# --- Sidebar: recycle this plot (two taps), undo, Ctrl+Z.
	s.town_place(home,"bench",8,1); game._select_plot(home); await process_frame
	var tools=find_button(game.side,"回收本地块")
	check(tools!=null and tools.text.contains("2"),"sidebar offers recycling the plot's path and bench")
	tools.pressed.emit(); await process_frame
	var confirm=find_button(game.side,"再点一次确认回收")
	check(confirm!=null and paths(home)==1,"first sidebar tap asks for confirmation")
	await capture("sidebar-recycle")
	confirm.pressed.emit(); await process_frame
	var left=s.plots[home].items.filter(func(item): return not Town.is_building(str(item.kind)))
	check(left.is_empty() and s.plots[home].items.is_empty() and s.plots[home].kind=="engineer_house","confirmed recycle stores the path and bench but keeps the house")
	var undo=find_button(game.side,"↶ 撤销")
	check(undo!=null and undo.tooltip_text.contains("回收"),"the sidebar shows an undo button for the recycle")
	undo.pressed.emit(); await process_frame
	check(paths(home)==1 and s.plots[home].items.size()==2,"sidebar undo restores the recycled items")
	s.town_place(home,"bench",1,9)
	var key=InputEventKey.new(); key.keycode=KEY_Z; key.pressed=true; key.ctrl_pressed=true
	game._unhandled_key_input(key); await process_frame
	check(s.plots[home].items.size()==2,"Ctrl+Z undoes the last placement")
	check(find_button(game.side,"擦除小路/装饰")!=null,"the sidebar keeps an eraser shortcut")
	# --- Gates: no doctor → templates disabled with a banner.
	check(not s.install_status().ok,"the test island has no doctor yet")
	game._select_plot(east); await process_frame
	game._show_templates(true); await process_frame
	check(find_named(game.modal,"DoctorBanner")!=null,"the template dialog explains that a doctor is needed")
	check(find_button(game.modal,"建造此反应炉")==null and find_button(game.modal,"建造此反应炉",false)!=null,"every build button is disabled without a doctor")
	await capture("templates-no-doctor")
	game._close_modal(); await process_frame
	game._select_plot(int(s.reactors[0].plot)); await process_frame
	game._open_editor(); await process_frame
	var editor=game.modal
	if editor!=null and editor.get("swap_button")!=null:
		check(editor.swap_button.disabled and editor.swap_button.text.contains("博士") and editor.doctor_banner!=null,"atom editor locks element swaps without a doctor")
	elif editor!=null:
		check(editor.composition_locked and find_named(editor,"DoctorBanner")!=null,"sandbox editor locks composition without a doctor")
	else: check(false,"the reactor editor opens")
	await capture("editor-no-doctor")
	game._close_modal(); await process_frame
	# With a doctor, a template still needs its elements.
	Fixtures.doctor(s)
	for symbol in s.element_inventory.keys(): s.element_inventory[symbol]=0
	game._select_plot(east); await process_frame
	game._show_templates(true); await process_frame
	check(find_named(game.modal,"DoctorBanner")==null and find_button(game.modal,"建造此反应炉")==null,"with a doctor but no elements nothing can be built")
	check(find_button(game.modal,"建造此反应炉",false)!=null,"disabled buttons are still listed")
	s.element_inventory["H"]=2; s.element_inventory["O"]=1
	game._close_modal(); game._show_templates(true); await process_frame
	var water=find_button(game.modal,"建造此反应炉")
	check(water!=null,"stocking H2 + O enables at least the water reactor")
	await capture("templates-ready")
	if water!=null:
		var coins=s.coins
		water.pressed.emit(); await process_frame
		check(s.coins==coins-100 and int(s.element_inventory.H)==0 and int(s.element_inventory.O)==0,"building charges 100 coins and the recipe's elements")
	game._close_modal(); await process_frame
	_finish()

func _finish() -> void:
	print("builder ui checks: %d, failures: %d" % [checks,failures.size()])
	for failure in failures: print("  FAIL ", failure)
	if game!=null: game.state.close_science()
	quit(1 if not failures.is_empty() else 0)
