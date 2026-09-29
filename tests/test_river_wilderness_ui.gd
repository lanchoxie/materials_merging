extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
var panel
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("wilderness UI timeout"); quit(2))
func key(code: int) -> void:
	var event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true; Input.parse_input_event(event)
	await process_frame
	event.pressed=false; Input.parse_input_event(event); await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	while not panel.view.stream.pending.is_empty(): await process_frame
	game.toast_panel.hide(); await create_timer(0.15).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._show_planet_v2(); await process_frame; await process_frame; panel=game.modal
	var v=game.state.planet.v2; v.world.paused=true
	panel._travel("camp"); await process_frame; await process_frame
	check(panel.view.first_person and panel._in_wilderness(),"route enters first person far outside original map")
	check(v.population.sites.has("1:1") and not panel.view.life_view.moving.is_empty(),"travellers and wild animals are rendered from persistent site")
	check(panel.world_title.text.contains("远郊") and not panel.right_panel.visible,"wilderness has clear destination and full viewport")
	var site=v.population.sites["1:1"]; site.flora=1; panel._sync()
	await capture("v021-wilderness-camp")
	await key(KEY_M)
	check(panel.section=="explore" and panel.right_panel.visible,"M opens journey and renewal controls")
	check(panel.widgets.explore.text.contains("可以采集") and panel.widgets.explore.text.contains("进营"),"nearby panel identifies ripe plants and traveller task")
	await capture("v021-wilderness-journey")
	panel._toggle_details(); panel.explore_input.grab_focus(); var food=v.world.food
	await key(KEY_E); await key(KEY_E)
	check(v.world.food==food+1 and site.flora==0.2,"E collects once and cannot duplicate forage")
	var persist=site.duplicate(true); panel._travel("ridge"); await process_frame; panel._travel("camp"); await process_frame
	check(site.flora==persist.flora and site.visitors==persist.visitors,"travel never resets harvested vegetation or people")
	var seeds=v.world.seeds; var stock=JSON.stringify(game.state.storage.batches)
	panel._act("v2_plant",{"crop":"grain"})
	check(v.world.seeds==seeds and panel.message.contains("起始河湾"),"far wilderness does not silently sow crops in old region")
	panel._tab("bag")
	check(JSON.stringify(game.state.storage.batches)==stock and panel.body.get_child_count()==1,"far bag directs to supported experiment instead of spending stock")
	panel._travel("home"); await process_frame; panel._tab("observe")
	check(not panel._in_wilderness() and panel.widgets.has("environment"),"home return restores detailed ecology and material controls")
	panel._travel("camp"); await process_frame
	var original_id=site.visitors[0].id
	v.advance(240); panel._sync()
	check(site.visitors.all(func(person): return person.id!=original_id),"traveller departure reaches the displayed world")
	var visible=panel.view.life_view.moving.keys()
	check(not visible.has("1:1/visitor/"+str(int(original_id))),"departed traveller node is removed")
	check(panel.view.walker.barriers.size()>0 and panel.view.terrain.blocked(Vector2(61,62),panel.view.walker.barriers),"camp shelter blocks the first-person walker")
	panel._travel("ridge"); await process_frame; await capture("v021-wilderness-ridge")
	panel.view.walker.position=Vector2(500,0); panel._sync(); await process_frame
	await capture("v021-wilderness-edge")
	check(panel.view.stream.chunks.size()<=49 and panel.view.life_view.moving.size()<48,"far edge retains bounded scenery and population rendering")
	panel._travel("camp"); await process_frame
	var timings=[]
	while not panel.view.stream.pending.is_empty(): await process_frame
	for i in range(120):
		var start=Time.get_ticks_usec(); await process_frame; timings.append((Time.get_ticks_usec()-start)/1000.0)
	timings.sort()
	var metrics={"chunks":panel.view.stream.chunks.size(),"nearby_people_and_animals":panel.view.life_view.moving.size(),"median_ms":timings[60],"p95_ms":timings[114],"note":"Native desktop stationary camp, not mobile/Web acceptance."}
	panel._open_journey(); await process_frame; await capture("v021-wilderness-final")
	game.queue_free(); await process_frame
	print("RIVER_WILDERNESS_UI: %d checks, %d failures" % [checks,failures.size()]); print(JSON.stringify(metrics))
	FileAccess.open("res://artifacts/v021-wilderness-ui-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	quit(0 if failures.is_empty() else 1)
