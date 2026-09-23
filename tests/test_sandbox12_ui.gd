extends "res://tests/test_river_field_ui.gd"

func look(panel,at: Vector2,point: Vector3) -> void:
	panel.view.travel(at)
	var d=point-panel.view.walker.eye()
	panel.view.walker.yaw=atan2(-d.x,-d.z); panel.view.walker.pitch=atan2(d.y,Vector2(d.x,d.z).length())
	panel.view._camera(0); panel._update_actor(); panel._aim()

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; s.coins=10000
	game._show_island_walk(); await process_frame; var island=game.modal
	check(island.world.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and island.hands.visible,"island shares real architecture through perspective view with visible hand")
	var old=island.walker.position; island.input.grab_focus(); await key(KEY_W); await process_frame
	check(island.walker.position!=old,"island keyboard movement changes terrain-bound position")
	check(island.terrain.blocked(Vector2(0,0)) and island.terrain.blocked(Vector2(1000,1000)),"island houses/reactors and void edges block walking")
	island.walker.position=Vector2(0,1.3); island.walker.reset_height(); island.walker.yaw=0; island.walker.pitch=-0.1; island._camera(); await key(KEY_E); await process_frame
	check(game.modal!=island and game.modal.get_script().resource_path.contains("atom_editor"),"first person reactor interaction opens actual molecular editor")
	game._show_planet_v2(); await process_frame; var panel=game.modal; var v=s.planet.v2; var c=v.construction; var t=c.terrain
	v.world.paused=true; panel._enter(); panel._equip_item("tool:axe")
	var tree=t.tree_records(Vector2i(-3,-3))[0]; var at=Vector2(tree.x,tree.z)
	look(panel,at+Vector2(0,2.3),Vector3(at.x,t.ground(at)+1.2,at.y)); await process_frame
	check(v.Target.query(v).get("tree_id")==tree.id,"equipped axe selects visible trunk in rendered first person")
	var timer=panel.view.hands.clock; await key(KEY_E)
	check(panel.view.hands.swing_left>0 and v.nature.trees.get(tree.id,{}).get("hits")==1,"real action input simultaneously animates hand and advances one chop")
	await capture("sandbox-axe")
	for i in range(3): await key(KEY_E)
	check(v.field.stock.timber==5 and v.nature.lookup(tree.id,t).cut,"input fells tree and inserts yield into shared inventory")
	panel._open_backpack(); await process_frame; await process_frame
	check(panel.backpack.items.has("tree:"+tree.species) and panel.backpack.items.has("raw:timber"),"harvested seed and timber appear in backpack categories")
	await capture("sandbox-backpack"); panel._close_backpack(); await process_frame
	panel._equip_item("tool:dig"); var dirt=Vector2(15,14)
	for offset in [Vector2(0,2),Vector2(2,0),Vector2(0,-2),Vector2(-2,0)]:
		if t.blocked(dirt+offset): continue
		look(panel,dirt+offset,Vector3(dirt.x,t.ground(dirt)-0.02,dirt.y))
		if v.Target.query(v).get("type")=="terrain": break
	await key(KEY_E)
	check(v.field.stock.soil==1,"first person shovel adds one soil from aimed terrain")
	await capture("sandbox-terrain")
	panel._equip_item("raw:soil"); look(panel,panel.view.walker.position,Vector3(dirt.x,t.ground(dirt)-0.02,dirt.y)); await key(KEY_E); check(v.field.stock.soil==0,"equipped soil restores ground through same input path")
	# Build a small connected sculpture from one real eight-piece construction source.
	s.planet.products.append({"id":91,"recipe":"field_wall","recipe_version":1,"source_batch":"ui-fixture"})
	for y in range(3): _place_above(v,s.planet,14,14,y,"block","field_wall")
	check(c.blocks.size()==3,"construction product creates connected sculpture")
	panel._equip_item("tool:mini_pack"); look(panel,Vector2(14,17),Vector3(14,1.4,14)); await key(KEY_E)
	check(c.blocks.is_empty() and c.miniatures.size()==1,"micro tool moves actual aimed sculpture into backpack")
	game._show_miniatures(); await process_frame; await process_frame
	check(button(game.modal,"摆放 / 收回")!=null,"island offers placement for packed works")
	# Select the default available plot and use the real exhibit button.
	var options=_options(game.modal); options.select(1); button(game.modal,"摆放 / 收回").pressed.emit(); await process_frame; await process_frame
	check(c.miniatures["1"].plot>=0 and game.miniature_view.get_child_count()>=2,"exhibit UI creates pedestal and actual model in island world")
	game._show_island_walk(); await process_frame; island=game.modal
	var parcel=s.plots[c.miniatures["1"].plot]; island.walker.position=Vector2(parcel.x*3+1.2,parcel.z*3+1.0); island.walker.reset_height()
	var target=Vector3(parcel.x*3+0.95,0.68,parcel.z*3-0.98); var d=target-island.walker.eye()
	island.walker.yaw=atan2(-d.x,-d.z); island.walker.pitch=atan2(d.y,Vector2(d.x,d.z).length()); island._camera()
	await capture("sandbox-miniature")
	game._show_planet_v2(); await process_frame; panel=game.modal; panel._enter(); panel._equip_item("tool:strike")
	var person={"id":1,"name":"禾苗","health":1.0,"hunger":0.1,"x":30.0,"z":30.0,"task":"安家"}; v.settlement.era=1; v.settlement.people=[person]
	look(panel,Vector2(30,32),Vector3(30,t.ground(Vector2(30,30))+1,30)); await key(KEY_E)
	check(person.health<1 and panel.encounter_hud.target.has("entity"),"rendered human receives strike and target health/anger HUD appears")
	var hp=v.combat.player_health; await create_timer(1.8).timeout
	check(v.combat.player_health==hp,"pause freezes retaliation")
	v.world.paused=false; await create_timer(2).timeout
	check(v.combat.player_health<hp,"unpaused human walks toward player and retaliates")
	await capture("sandbox-encounter")
	v.combat.player_health=0; await process_frame; await process_frame
	check(panel.faint_button.visible,"zero player health exposes camp recovery action")
	panel.faint_button.pressed.emit(); await process_frame; check(v.combat.player_health==100,"camp action restores health")
	game.queue_free(); await process_frame
	print("SANDBOX12 UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)

func _options(node):
	if node is OptionButton: return node
	for child in node.get_children():
		var found=_options(child)
		if found!=null: return found
	return null
