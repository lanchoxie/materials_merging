extends SceneTree
const Planet=preload("res://scripts/planet_v2.gd")
const Population=preload("res://scripts/river_population.gd")
const Terrain=preload("res://scripts/river_terrain.gd")
const Stream=preload("res://scripts/river_chunk_stream.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var p=Planet.new(); var pop=p.population; var camp=Vector2(64,64)
	pop.observe(camp); var s=pop.sites["1:1"]
	check(s.camp and s.animals.size()==2 and s.visitors.size()==1,"discovered camp starts with bounded persistent residents")
	var initial=s.duplicate(true)
	pop.observe(Vector2(350,0)); pop.observe(camp)
	check(Same.same(s,initial),"leaving and revisiting does not reset or duplicate site")
	s.flora=1; var food=p.world.food
	p.collect_wild(camp); p.collect_wild(camp)
	check(p.world.food==food+1 and s.flora==0.2,"mature wild harvest yields once and depletes vegetation")
	pop.observe(Vector2(350,0)); p.advance(180)
	check(s.flora==0.2 and s.seconds==0,"distant sites do not accrue unseen renewal")
	pop.observe(camp); p.active=true; p.world.paused=true; var saved=p.serialize(); p.tick(20)
	check(Same.same(saved,p.serialize()),"pause freezes renewal and travellers")
	p.world.paused=false; p.advance(180)
	check(s.flora>0.8 and s.flora<=1,"healthy vegetation slowly regrows despite grazing")
	var old_visitor=int(initial.visitors[0].id); p.advance(60)
	check(s.visitors.all(func(v): return v.id!=old_visitor) and not s.visitors.is_empty(),"departed traveller is replaced by a new identity")
	check(s.animals.size()<=int(pop.rules.animal_target) and s.visitors.size()<=int(pop.rules.visitor_capacity),"animal and human renewal obey capacities")
	var old_serial=int(s.serial); s.animals=[]; s.animal_clock=0
	p.advance(239); check(s.animals.is_empty(),"empty site does not instantly spawn animals")
	p.advance(1); check(s.animals.size()==1 and s.animals[0].id>=old_serial,"migration waits full interval and creates a new identity")
	s.animals=[]; s.visitors=[]; pop.enabled=false; s.flora=0.3
	p.advance(300)
	check(s.animals.is_empty() and s.visitors.is_empty() and s.flora==0.3,"renewal switch stops migration and regrowth")
	pop.enabled=true; s.flora=0.1; s.visitor_clock=150; pop.advance(p.world.regions)
	check(s.visitors.is_empty(),"food shortage prevents new travellers")
	s.flora=1; pop.advance(p.world.regions)
	check(s.visitors.size()==1 and s.flora<1,"travellers use finite site food when admitted")
	var json=JSON.parse_string(JSON.stringify(p.serialize())); var restored=Planet.new()
	check(restored.restore(json),"world including discoveries and renewal counters roundtrips")
	check(Same.same(restored.population.serialize(),pop.serialize()),"roundtrip preserves identities vegetation and counters")
	pop.observe(camp); restored.population.observe(camp); p.advance(30); restored.advance(30)
	check(Same.same(p.serialize(),restored.serialize()),"reload follows same observed-site trajectory")
	var legacy=p.serialize(); legacy.erase("population")
	check(Planet.new().restore(legacy),"older river saves initialize renewal safely")
	for mutation in ["id","flora","coordinate","clock"]:
		var corrupt=pop.serialize(); var item=corrupt.sites["1:1"]
		match mutation:
			"id": item.visitors[0].id=-1
			"flora": item.flora=1.5
			"coordinate": item.x=9999
			"clock": item.animal_clock=-1
		check(not Population.new().restore(corrupt),"reject corrupt population "+mutation)
	var closed=Planet.new(); var r=closed.world.regions.meadow
	r.animals=[]; r.enclosed=true; r.moisture=0.6; r.water=0.6
	closed.population.sites.meadow.animal_clock=240
	check(not closed.population.advance(closed.world.regions).has("meadow"),"closed pen rejects external migration")
	r.enclosed=false; r.pollution=0.8
	check(not closed.population.advance(closed.world.regions).has("meadow"),"polluted habitat does not attract migration")
	r.pollution=0; r.water=0
	check(not closed.population.advance(closed.world.regions).has("meadow"),"dry habitat does not attract migration")
	r.water=0.6
	check(closed.population.advance(closed.world.regions).has("meadow"),"healthy empty open habitat admits migration")
	r=closed.world.regions.wetland; r.animals=[]; r.water=0.6; r.moisture=0.6; r.temperature=20; r.oxygen=0
	closed.population.sites.wetland.animal_clock=240
	check(not closed.population.advance(closed.world.regions).has("wetland"),"hypoxic water does not repopulate fish")
	var t=Terrain.new(); var second=Terrain.new()
	check(t.rules.radius==512 and t.inside(Vector2(500,0)) and not t.inside(Vector2(520,0)),"bounded world has roughly one kilometre diameter")
	var reference=t.chunk_trees(Vector2i(12,-12)).duplicate()
	for z in range(-20,21):
		for x in range(-20,21): t.chunk_trees(Vector2i(x,z))
	check(t.tree_cache.size()<=96,"tree query cache stays bounded on long journeys")
	check(reference==t.chunk_trees(Vector2i(12,-12)) and reference==second.chunk_trees(Vector2i(12,-12)),"evicted chunks regenerate identical trees")
	check(t.ground(Vector2(195,-185))==second.ground(Vector2(195,-185)),"world ground is deterministic at distant coordinates")
	var stream=Stream.new(); stream.terrain=t; stream.material=StandardMaterial3D.new(); root.add_child(stream)
	stream.set_process(false); stream.schedule(Vector2.ZERO,0); stream.drain(100)
	check(stream.chunks.size()==49,"rendering keeps seven by seven chunks")
	var max_build=0; var start=Time.get_ticks_msec()
	for at in [Vector2(64,64),Vector2(200,-200),Vector2(-320,0),Vector2(500,0),Vector2.ZERO]:
		stream.schedule(at,1); stream.drain(4); max_build=maxi(max_build,stream.last_build_us)
		check(stream.chunks.size()<=49 and stream.pending.size()<=49,"travel keeps resident and pending chunk counts bounded")
		await process_frame
	stream.schedule(Vector2(16,0),2); stream.drain(4)
	stream.schedule(Vector2(32,0),2); stream.drain(100)
	check(stream.chunks.values().all(func(n): return n.get_meta("season")==2),"moving during season recolour leaves no stale chunks")
	check(stream.get_child_count()<=98,"deferred unloads do not accumulate across frames")
	await process_frame
	check(stream.get_child_count()==stream.chunks.size(),"unloaded render nodes actually leave scene")
	for z in range(-8,9):
		for x in range(-8,9): pop.observe(Vector2(x,z)*64)
	check(pop.sites.size()<=int(pop.rules.max_sites),"discovered site persistence is bounded")
	check(Population.new().restore(JSON.parse_string(JSON.stringify(pop.serialize()))),"fully explored world population remains loadable")
	var metrics={"sites":pop.sites.size(),"population_save_bytes":JSON.stringify(pop.serialize()).length(),"tree_cache":t.tree_cache.size(),"chunks":stream.chunks.size(),"sample_chunk_build_ms":max_build/1000.0,"travel_test_ms":Time.get_ticks_msec()-start}
	stream.queue_free(); await process_frame
	print("RIVER_POPULATION: %d checks, %d failures" % [checks,failures.size()]); print(JSON.stringify(metrics))
	FileAccess.open("res://artifacts/v021-population-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	quit(0 if failures.is_empty() else 1)
