extends "res://tests/test_sandbox12_ui.gd"
func put(v,kind: String,p: Vector2) -> String:
	var c=v.construction; var id=str(c.sources.size()+1); var recipe="field_"+kind
	var b={"x":int(p.x),"y":c.base(Vector3i(int(p.x),0,int(p.y))),"z":int(p.y),"kind":kind,"source":id}
	c.sources[id]={"product":{"id":int(id),"recipe":recipe,"recipe_version":1,"source_batch":"ui-ranch"},"remaining":int(c.rules.recipes[recipe].units)-1}
	var k=c.key(c.cell(b)); c.blocks[k]=b; c.revision+=1; return k
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; var v=s.planet.v2; var r=v.ranch; var t=v.construction.terrain
	var water=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(water,8)
	v.field.stock={"timber":16,"stone":16,"fiber":8,"fruit":12,"grain":12,"soil":0}
	game._show_planet_v2(); await process_frame; var panel=game.modal; v.world.paused=true
	panel._tab("ranch"); await process_frame; await process_frame
	check(button(panel,"存1份水样")!=null,"village page exposes existing reactor water rather than selling it")
	button(panel,"存1份水样").pressed.emit(); await process_frame; await process_frame
	check(r.depot.water==1 and s.storage.batch(water.id).quantity==7,"actual UI deposits water with one inventory debit")
	button(panel,"存5").pressed.emit(); await process_frame; await process_frame
	check(r.depot.seed==5 and v.world.seeds==1,"seed deposit button moves five real seeds")
	for id in panel.tabs:
		check(panel.tabs[id].get_global_rect().end.x<panel.right_panel.get_global_rect().end.x,"tab fits panel: "+id)
	var trough=put(v,"trough",Vector2(12,12)); var feeder=put(v,"feeder",Vector2(12,10))
	var garden=put(v,"planter",Vector2(17,14)); put(v,"planter",Vector2(17,16))
	v.ranch.sync(v); r.facilities[trough].stock=4; r.facilities[feeder].stock=4; r.depot.grain=6; r.depot.fruit=8; r.depot.water=8; r.depot.stone=3
	v.settlement.era=1; v.settlement.people=[{"id":1,"name":"禾苗","health":1.0,"hunger":0.1,"x":15.0,"z":14.0,"task":"安家"},{"id":2,"name":"石川","health":1.0,"hunger":0.1,"x":15.0,"z":15.0,"task":"安家"}]
	panel._select_region("meadow"); panel._enter(); panel._equip_item("tool:collect")
	look(panel,Vector2(16,19),Vector3(13,1,12)); panel._sync(); await process_frame
	check(panel.view.settlement_view.members.size()==2,"farmer and artisan are real rendered villagers")
	check(panel.view.settlement_view.depot_node!=null,"finite public depot has a physical scene object")
	check(panel.view.settlement_view.facility_node.visible,"loaded water and feed render inside actual facilities")
	await capture("ranch13-village")
	var before=v.world.seeds
	for i in range(60): v.advance(1)
	panel._sync(); await process_frame
	check(v.field.gardens.has(garden) and v.world.seeds==before,"rendered village simulation plants from public seed stock")
	panel.show_details=true; panel._exploration_layout(); panel._tab("ranch"); await process_frame; await process_frame
	check(panel.widgets.has("worker:1") and panel.widgets["worker:1"].text.contains("农夫"),"village page reports actual role and current job")
	var old=panel.view.walker.position; panel.scroll.scroll_vertical=300; await process_frame
	button(panel,"存1份水样").pressed.emit(); await process_frame; await process_frame; await process_frame
	check(panel.view.walker.position==old,"supply action does not reset first-person position")
	check(panel.scroll.scroll_vertical>100,"supply action preserves useful scroll position")
	await capture("ranch13-supplies")
	panel.show_details=false; panel._exploration_layout()
	var person=v.settlement.people[1]; look(panel,Vector2(person.x,person.z+2.4),Vector3(person.x,t.ground(Vector2(person.x,person.z))+1.2,person.z)); panel._sync(); await process_frame
	await key(KEY_E); await process_frame
	check(panel.section=="ranch" and panel.show_details,"gloved interaction opens citizen information")
	await capture("ranch13-citizen")
	game.queue_free(); await process_frame
	print("RANCH13 UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
