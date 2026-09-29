extends "res://tests/test_ranch13_ui.gd"
const Fixture=preload("res://tests/test_frontier17.gd")

func capture_frontier(name: String,river) -> void:
	while not river.view.stream.pending.is_empty(): await process_frame
	await capture(name)

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	game._show_planet_v2(); await process_frame; await process_frame; var river=game.modal; var v=game.state.planet.v2
	v.world.paused=true; river._travel("far_river"); await process_frame; await process_frame
	check(river.view.walker.position.length()>6000 and river.view.first_person,"new distant landmark enters six km first-person terrain")
	check(not v.population.visible_sites(river.view.walker.position).is_empty(),"far first-person view contains actual local encounter state")
	await capture_frontier("frontier17-river",river)
	check(river.view.stream.chunks.size()<=49 and not river.view.stream.chunks.is_empty(),"six km location still renders at most 49 terrain chunks")
	var p=river.view.walker.position; var feet=river.view.walker.feet_y; river.explore_input.grab_focus(); await key(KEY_SPACE)
	for i in range(90): river.view.walker.step(1.0/60)
	check(river.view.walker.grounded and absf(river.view.walker.feet_y-feet)<0.02,"remote jump falls back onto the same terrain")
	river._open_journey(); await process_frame; await process_frame
	check(button(river,"记住当前位置")!=null,"journey displays persistent navigation controls")
	button(river,"记住当前位置").pressed.emit(); await process_frame; await process_frame
	check(v.journey.points.size()==1 and button(river,"我的路标 1")!=null,"waypoint added through actual menu, not a debug fixture")
	river._travel("home"); await process_frame; river._open_journey(); await process_frame
	button(river,"我的路标 1").pressed.emit(); await process_frame
	check(river.view.walker.position.distance_to(p)<1,"saved remote waypoint returns to the same place")
	var count=v.journey.points.size(); river._open_journey(); await process_frame; button(river,"记住当前位置").pressed.emit(); await process_frame
	check(v.journey.points.size()==count,"repeat button does not duplicate nearby waypoint")
	river._travel("home"); river._tab("era"); await process_frame; await process_frame
	check(river.widgets.era.text.contains("实际作物收获") and river.widgets.era_advance.disabled,"fresh era panel explains progress and disables premature promotion")
	var helper=Fixture.new(); var c=v.construction; var y=c.base(Vector3i(15,0,14))
	c.sources["1"]={"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"field:1"},"remaining":2}
	for cell in [Vector3i(15,y,14),Vector3i(15,y+1,14),Vector3i(15,y+2,14),Vector3i(15,y+3,14),Vector3i(16,y+3,14),Vector3i(17,y+3,14)]:
		c.blocks[c.key(cell)]={"x":cell.x,"y":cell.y,"z":cell.z,"kind":"block","source":"1"}
	c.revision+=1; v.settlement.harvests=1; v.ranch.depot.grain=3; v.world.regions.meadow.water=0.4
	river._live(); check(not river.widgets.era_advance.disabled,"actual updated conditions enable promotion without reopening panel")
	river.widgets.era_advance.pressed.emit(); await process_frame; await process_frame
	check(v.settlement.era==1 and river.widgets.era.text.contains("公共仓库水样") and river.widgets.era_advance.disabled,"modern checklist exposes missing storage and energy rather than silently refusing")
	river.show_details=true; river._exploration_layout(); await capture_frontier("frontier17-era",river)
	helper.place(v,"solar",Vector2(19,14)); v.settlement.harvests=3; v.settlement.meals=4; v.ranch.depot.water=2; v.settlement.energy=2
	river._live(); check(not river.widgets.era_advance.disabled,"complete modern checklist becomes actionable")
	river.widgets.era_advance.pressed.emit(); await process_frame; await process_frame; river._sync()
	check(v.settlement.era==2 and not river.widgets.has("era_advance") and river.widgets.era.text.contains("没有下一时代"),"last implemented chapter clearly stops with no fictional unlock")
	var view=river.view.settlement_view; view.sync(v.settlement,Vector2(13,13))
	check(view.members[1].get_child(0).mesh==view._mesh(2,1),"already visible resident gets modern outfit immediately")
	v.settlement.people.clear(); river._tab("era"); await process_frame; await process_frame
	check(river.widgets.has("era_recruit") and not river.widgets.era_recruit.disabled,"lost residents have an explicit resettlement route")
	river.widgets.era_recruit.pressed.emit(); await process_frame
	check(v.settlement.people.size()==1 and v.ranch.depot.grain==1,"inviting a new resident consumes finite supplies through UI")
	var timings=[]; river._travel("frontier")
	while not river.view.stream.pending.is_empty(): await process_frame
	for i in range(120):
		var now=Time.get_ticks_usec(); await process_frame; timings.append((Time.get_ticks_usec()-now)/1000.0)
	timings.sort()
	var metrics={"chunks":river.view.stream.chunks.size(),"active_sites":v.population.active_sites.size(),"median_ms":timings[60],"p95_ms":timings[114],"note":"Desktop stationary remote scene, not Android performance acceptance"}
	FileAccess.open("res://artifacts/frontier17-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics))
	helper.free(); game.queue_free(); await process_frame
	print("FRONTIER17 UI: %d checks, %d failures" % [checks,failures.size()]); print(JSON.stringify(metrics)); quit(0 if failures.is_empty() else 1)
