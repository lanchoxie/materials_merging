extends "res://tests/test_ranch13_ui.gd"
## v0.32 Earth through the real UI: the CO₂ workshop gate, building a sprinkler in a desert from
## the backpack, its effect on the land, the environment map, and screenshots of each biome.
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(200).timeout.connect(func(): quit(2))

func settle(panel) -> void:
	panel._sync(); await process_frame
	while not panel.view.stream.pending.is_empty(): await process_frame
	await process_frame

func find_cell(env,want: Callable) -> Vector2i:
	for j in range(env.size):
		for i in range(env.size):
			var c=Vector2i(i,j)
			var at=env.cell_center(c)
			if at.length()<7400 and at.length()>1500 and preload("res://scripts/planet_shape.gd").continent(at.x,at.y)>0.2 and preload("res://scripts/planet_shape.gd").mountains(at.x,at.y,1.0)==0.0 and want.call(env.values(c)): return c
	return Vector2i(-1,-1)

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; var pg=s.planet; var v=pg.v2; var env=v.environment
	pg.command(s,"join")
	# --- Workshop: the CO2 tower asks for a CO2 sample and accepts a real CO2 batch.
	var gas=s.product_snapshot(s._new_reactor(3,"carbon_dioxide",0)); s.storage.add_product(gas,8)
	game._show_factory("earth_co2_tower"); await process_frame; await process_frame
	var factory=game.modal
	check(factory.selected_recipe=="earth_co2_tower" and button(factory,"提交二氧化碳 CO₂ 样品")!=null,"the CO2 tower asks for a CO2 sample")
	button(factory,"提交二氧化碳 CO₂ 样品").pressed.emit(); await process_frame; await process_frame
	check(pg.qualified_for("carbon_dioxide") and s.storage.batch(gas.id).quantity<8,"submitting the sample unlocks the line and spends samples")
	check(button(factory,"补充1份供料")!=null,"after qualification the supply and build steps appear")
	await capture("earth-workshop")
	game._close_modal(); await process_frame
	# --- A sprinkler made for the planet, placed in a desert from the backpack.
	pg.products.append({"id":pg.serial,"recipe":"earth_sprinkler","recipe_version":1,"source_batch":"ui-earth"}); pg.serial+=1
	var dry=find_cell(env,func(x): return x.x>0.08 and x.x<0.2 and x.y>8 and x.y<26)
	check(dry.x>=0,"a desert cell exists within reach")
	if dry.x<0: _done(); return
	game._show_planet_v2(); await process_frame; await process_frame
	var panel=game.modal; v.world.paused=true
	var at=env.cell_center(dry)
	panel._enter(); panel._equip_item("recipe:earth_sprinkler")
	var ground=v.construction.terrain.ground(at+Vector2(0,-3))
	look(panel,at,Vector3(at.x,ground+0.2,at.y-3)); await process_frame
	check(env.biome_at(panel.view.walker.position)=="desert","the walk starts in a desert")
	await settle(panel); await capture("earth-desert-before")
	await key(KEY_E); await process_frame
	check(v.construction.count_kind("sprinkler")==1,"E places the sprinkler from the backpack")
	panel._sync(); await process_frame
	check(panel.view.construction_view.effects.size()==1,"the sprinkler sprays (an effect node is live)")
	var before=env.values(dry).x
	for i in range(4): v.active=true; v.advance(400)
	check(env.values(dry).x>before+0.15 and env.biome_at(at)!="desert","the desert greens around the sprinkler")
	look(panel,at+Vector2(4,6),Vector3(at.x,ground+1.2,at.y-3)); await settle(panel)
	check(panel.view.stream.chunks.values().all(func(n): return n.get_meta("env",-1)==panel.view.stream._env_version(panel.view.stream.chunks.find_key(n))),"every chunk is rebuilt for the new climate")
	await capture("earth-desert-green")
	# --- The environment map.
	panel.toggle_earth_map(); await process_frame; await process_frame
	var map=panel.earth_map
	check(map!=null and map.visible and map.name=="EarthMap","the map toggles open")
	check(map.stats.text.contains("喷淋塔 ×1") and map.stats.text.contains("CO₂"),"the map lists machines and the atmosphere")
	check(map.here.text.contains("你在："),"the map tells you where you stand")
	await capture("earth-map")
	button(map,"温度").pressed.emit(); await process_frame; await process_frame
	check(map.channel=="temperature","the map switches channel")
	await capture("earth-map-temperature")
	panel.toggle_earth_map(); await process_frame
	check(not map.visible,"the map toggles closed")
	# --- Biomes on foot.
	for spot in [["tundra"],["wetland"],["forest"]]:
		var c=find_cell(env,func(x): return env.biome_of(x)==spot[0])
		if c.x<0: check(false,"a %s cell exists" % spot[0]); continue
		var p=env.cell_center(c)
		for tries in range(8):
			if panel.view.travel(p) and env.biome_at(panel.view.walker.position)==spot[0]: break
			p+=Vector2(37,23)
		look(panel,p,Vector3(p.x+6,v.construction.terrain.ground(p+Vector2(6,-8))+1.0,p.y-8)); await settle(panel)
		check(env.biome_at(panel.view.walker.position)==spot[0],"walked into %s" % spot[0])
		await capture("earth-"+spot[0])
	panel.view.travel(Vector2(12,12)); await settle(panel)
	panel.show_details=true; panel._exploration_layout(); panel._tab("observe"); await process_frame; await process_frame
	panel._live()
	check(panel.widgets.has("environment") and panel.widgets.environment.text.contains("地球："),"the life tab names the biome and atmosphere")
	_done()

func _done() -> void:
	game.queue_free(); await process_frame
	print("EARTH UI: %d checks, %d failures" % [checks,failures.size()])
	for f in failures: print("  FAIL ",f)
	quit(0 if failures.is_empty() else 1)
