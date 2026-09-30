extends SceneTree
## v0.27 Hometown through the real UI: shop, build mode taps and drags, item selection, pedestal
## exhibits, tier looks and the pop/upgrade effects in the island view.
const Main=preload("res://scripts/main.gd")
const Town=preload("res://scripts/island_town.gd")
const Surface=preload("res://scripts/island_walk_surface.gd")
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
	root.get_texture().get_image().save_png("res://artifacts/hometown-"+label+".png")
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text.contains(text) and not node.disabled: return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null: return found
	return null
func find_label(node: Node, text: String) -> Label:
	if node is Label and node.text==text: return node
	for child in node.get_children():
		var found=find_label(child,text)
		if found!=null: return found
	return null
## Global screen position of a tile's centre on a plot.
func tile_screen(plot: int, tile: Vector2i) -> Vector2:
	var p: Dictionary=game.state.plots[plot]
	var point=Vector3(float(p.x)*3,0.08,float(p.z)*3)+Town.center(tile,Vector2i.ONE)+Vector3(0,0.08,0)
	var local=game.world.camera.unproject_position(point)
	return game.world_box.global_position+local*game.world_box.size/Vector2(game.world_viewport.size)
func tap(pos: Vector2) -> void:
	await game._test_touch(pos,true)
	await game._test_touch(pos,false)
	await process_frame
func drag(from: Vector2, to: Vector2) -> void:
	await game._test_touch(from,true)
	for i in range(1,7):
		var event=InputEventScreenDrag.new(); event.index=0; event.position=from.lerp(to,i/6.0)
		preload("res://scripts/core/test_input.gd").send(event)
		await process_frame
	await game._test_touch(to,false)
	await process_frame
func uids(plot: int, kind: String) -> Array:
	return game.state.plots[plot].items.filter(func(item): return item.kind==kind).map(func(item): return int(item.uid))

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	s.coins=60000; s.materials=[10000,10000,10000]; s.deliveries=3
	for i in [0,1,2,6,7,8]:
		if not s.plots[i].unlocked: s.buy_plot(i)
	var home=3
	s.town_place(home,"engineer_house",0,0); s.campus_road(home)
	s.campus_build(5,"institute"); s.campus_road(5)
	for i in range(4): s.campus_upgrade(5)
	s.town_place(7,"doctor_dorm",3,3); s.campus_upgrade(7); s.campus_upgrade(7)
	s.campus.elapsed=90; s.campus.day_time=90
	game._sync_world(); game._select_plot(home)
	game.world.focus_plot(home)
	await create_timer(1.0).timeout
	# Shop → build mode → tap a free tile.
	game._show_town_shop()
	await process_frame
	check(game.modal!=null and find_button(game.modal,"摆放")!=null,"shop lists placeable buildings")
	await capture("shop")
	var effects=game.campus_view.effects_played
	var card=find_label(game.modal,s.town_name("canteen")).get_parent()
	find_button(card,"摆放").pressed.emit()
	await process_frame
	var kind: String=game.town_build.kind
	check(kind=="canteen","the card's button starts placing that building")
	check(game.town_build.active and game.modal==null and is_instance_valid(game.town_build.hud),"placing closes the shop and opens build mode with a HUD")
	var footprint=Town.size(kind)
	var target=Vector2i(6,0)+footprint/2
	var screen=tile_screen(home,target)
	game.town_build.hover(screen-game.world_box.global_position)
	await process_frame
	check(game.town_build.plot==home and game.town_build.at==Vector2i(6,0) and game.town_build.error.is_empty(),"ghost snaps to the tile under the pointer: %s %s" % [game.town_build.at,game.town_build.error])
	await capture("ghost")
	await tap(screen)
	await process_frame
	check(uids(home,kind).size()==1,"a tap in build mode places the building")
	check(not game.town_build.active,"placing a building ends build mode")
	check(game.campus_view.effects_played>effects,"new building pops in with an effect")
	# Red footprint on an occupied spot.
	game.town_build.start_place("bench")
	game.town_build.hover(tile_screen(home,Vector2i(2,2))-game.world_box.global_position)
	check(game.town_build.error=="这里已经被占用了" and game.town_build.marker.material_override.albedo_color.r>0.8,"occupied tiles turn the footprint red")
	var coins=s.coins
	await tap(tile_screen(home,Vector2i(2,2)))
	check(s.coins==coins,"tapping a red spot changes nothing")
	game.town_build.finish()
	# Drag-paint a stone path along row 6.
	game.town_build.start_place("stone_path")
	await drag(tile_screen(home,Vector2i(1,6)),tile_screen(home,Vector2i(9,6)))
	var paths=uids(home,"stone_path").size()
	check(paths>=3,"dragging paints a row of path tiles: %d" % paths)
	check(game.town_build.active,"paint items stay in build mode for more strokes")
	game.town_build.finish()
	# Fences join, flowers and a lamp by the API, then a pedestal with a real specimen.
	for x in range(0,6): s.town_place(home,"picket_fence",x,10)
	s.town_place(home,"flower_bed",0,8); s.town_place(home,"street_lamp",6,10); s.town_place(home,"young_tree",8,9)
	s.town_place(home,"stone_pedestal",6,8)
	var pedestal=uids(home,"stone_pedestal")[0]
	s.planet.v2.nature.minerals["limestone"]=2
	game._select_plot(home,pedestal)
	check(find_button(game.side,"选择展品")!=null,"an empty pedestal offers exhibits")
	find_button(game.side,"选择展品").pressed.emit()
	await process_frame
	check(find_button(game.modal,"石灰岩")!=null,"exhibit picker lists mined minerals")
	find_button(game.modal,"石灰岩").pressed.emit()
	await process_frame
	check(s.town_item(home,pedestal).show.get("id")=="limestone" and int(s.planet.v2.nature.minerals.limestone)==1,"pedestal shows the specimen from the backpack")
	var caption: Label3D=game.campus_view.scenery.get_node_or_null("Plot_%d/Item_%d/Caption" % [home,pedestal])
	check(caption!=null and caption.text.contains("CaCO₃"),"specimen card names the mineral and its formula")
	# Selecting an item by tapping it in the world.
	game._select_plot(4)
	await tap(tile_screen(home,Vector2i(1,8)))
	var bed=uids(home,"flower_bed")[0]
	check(game.selected_plot==home and game.selected_item==bed and find_button(game.side,"收起")!=null,"tapping an item selects it with move/store/sell actions")
	await capture("item-selected")
	find_button(game.side,"收起").pressed.emit()
	await process_frame
	check(uids(home,"flower_bed").is_empty() and int(s.storage.decorations.flower_bed)==1 and game.selected_item==-1,"store action returns the flower bed to the toolbox")
	# Move the main building through build mode.
	game._select_plot(home,0)
	find_button(game.side,"挪动位置").pressed.emit()
	await process_frame
	check(game.town_build.active and game.town_build.uid==0,"main building enters move mode")
	game.town_build.finish()
	# Upgrade effect on an extra building.
	var extra=uids(home,kind)
	if not extra.is_empty():
		effects=game.campus_view.effects_played
		game._select_plot(home,extra[0])
		find_button(game.side,"升级").pressed.emit()
		await process_frame
		check(int(s.town_item(home,extra[0]).level)==2 and game.campus_view.effects_played>effects,"upgrade plays the squash, scaffold and star effect")
	# Walk collisions follow real footprints.
	var surface=Surface.new(); surface.setup(s,game.light_bridge)
	var lamp=s.town_item(home,uids(home,"street_lamp")[0])
	var lamp_rect=Surface.tile_rect(Vector2(s.plots[home].x*3,s.plots[home].z*3),Town.item_rect(lamp))
	check(surface.obstacles.has(lamp_rect),"walkers bump into courtyard items")
	check(not surface.obstacles.any(func(r): return r.has_point(Vector2(s.plots[home].x*3,s.plots[home].z*3)+Vector2(-1.5,-1.5)+Vector2(2.5,6.5)*Town.tile())),"paths stay walkable")
	await create_timer(1.2).timeout
	game.world.zoom_view(8.0/game.world.camera.size)
	game.world.focus_plot(home)
	await create_timer(0.6).timeout
	await capture("courtyard")
	game.world.focus_plot(5)
	await create_timer(0.6).timeout
	await capture("tiers")
	s.close_science()
	print("PASS: ",checks," hometown UI checks" if failures.is_empty() else " FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
