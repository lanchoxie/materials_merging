extends "res://tests/test_ranch13.gd"
const Journey=preload("res://scripts/river_journey.gd")

func place(v,kind: String,at: Vector2) -> String:
	var c=v.construction; var serial=str(c.sources.size()+1)
	var recipe={"block":"field_wall","solar":"modern_silicon"}.get(kind,"field_"+kind)
	var b={"x":int(at.x),"y":c.base(Vector3i(int(at.x),0,int(at.y))),"z":int(at.y),"kind":kind,"source":serial}
	c.sources[serial]={"product":{"id":int(serial),"recipe":recipe,"recipe_version":1,"source_batch":"field:"+serial},"remaining":int(c.rules.recipes[recipe].units)-1}
	var key=c.key(c.cell(b)); c.blocks[key]=b; c.revision+=1; v.ranch.sync(v); return key

func _initialize() -> void:
	var s=State.new(); var v=s.planet.v2; var t=v.construction.terrain; var c=v.construction
	check(t.rules.radius==8192 and t.inside(Vector2(6000,0)) and not t.inside(Vector2(8193,0)),"finite 16 km world has honest consistent bounds")
	var old=Vector2(15,14); var height=t.ground(old)
	check(is_equal_approx(height,preload("res://scripts/river_terrain.gd").new().ground(old)),"existing origin terrain remains deterministic")
	var p=Vector2(6000,2000); v.population.observe(p)
	check(not v.population.visible_sites(p).is_empty() and v.population.active_sites.size()<=9,"remote site still creates nearby wildlife and camps")
	var site=v.population.nearest(p); var id=site.id; site.flora=0.2
	for z in range(-13,14):
		for x in range(-13,14): v.population.observe(Vector2(x*192,z*192))
	check(v.population.sites.size()>300,"exploration continues after old 300 site cap")
	v.population.observe(Vector2(-6000,1200))
	check(not v.population.visible_sites(Vector2(-6000,1200)).is_empty(),"new locations still have animals after many explored sites")
	check(v.population.simulation_keys().size()<=13 and v.population.nearby_keys(Vector2(-6000,1200)).size()<=29,"simulation and visibility use local indices not all history")
	var seconds=v.population.sites[id].seconds; v.population.advance(v.world.regions)
	check(v.population.sites[id].seconds==seconds and v.population.sites[id].flora==0.2,"remote unobserved habitat retains state without restarting or simulating")
	v.population.observe(p); check(v.population.sites[id].flora==0.2,"returning does not regenerate consumed flora")
	# Find an unoccupied remote tile; use real terrain edits and tree operations.
	var clear=Vector2.ZERO
	for z in range(1990,2011):
		for x in range(5990,6011):
			var point=Vector2(x,z)
			if not t.blocked(point) and not t.on_path(point): clear=point; break
		if clear!=Vector2.ZERO: break
	check(clear!=Vector2.ZERO,"far wilderness has accessible land")
	var before=t.height_at(clear); v.nature.terraform(-1,Vector3(clear.x,before,clear.y),v)
	check(t.height_at(clear)==before-1 and v.field.stock.soil==1,"remote digging changes persistent terrain and yields finite soil")
	var tree=t.tree_records(t.chunk_at(p))[0]
	for i in range(int(v.nature.rules.chop_hits)): v.nature.chop(tree.id,v.field,t)
	check(v.nature.trees[tree.id].cut,"remote tree can be harvested beyond original 512 metre save bound")
	var planted=false
	for x in range(6040,6061):
		for z in range(2040,2061):
			if v.nature.plant(str(tree.species),Vector2(x,z),v).begins_with("种下"): planted=true; break
		if planted: break
	check(planted,"harvested remote tree seed can be planted in distant soil")
	var block=place(v,"block",clear+Vector2(2,0)); check(c.blocks.has(block),"remote building exists on enlarged terrain")
	var animal=v.population.visible_sites(p)[0].animals[0]; var key="wild:"+id+":"+str(int(animal.id))
	v.ranch.life(key); v.ranch.lives[key].trust=0.42
	v.combat.records[key]={"anger":20.0,"wait":0.0,"home_x":p.x,"home_z":p.y,"mode":"逃跑"}
	v.active=true; v.actor={"feet":Vector3(clear.x,t.ground(clear),clear.y),"eye":Vector3(clear.x,t.ground(clear)+1.62,clear.y),"direction":Vector3.FORWARD}
	s.planet.command(s,"v2_waypoint_add"); s.planet.command(s,"v2_waypoint_add")
	check(v.journey.points.size()==1,"waypoint stores actual position and duplicate nearby click does not add another")
	var saved=JSON.parse_string(JSON.stringify(v.serialize())); var loaded=V2.new()
	check(loaded.restore(saved),"far construction tree terrain combat and all encounter records survive JSON save")
	check(loaded.nature.trees[tree.id].cut and loaded.population.sites[id].flora==0.2 and loaded.journey.points.size()==1,"save preserves remote edits harvest and route, not only geometry")
	check(loaded.ranch.life_groups.has("wild:"+id) and loaded.ranch.lives[key].trust==0.42,"needs history group index rebuilds on load")
	loaded.ranch._prune(loaded); check(loaded.ranch.lives.has(key),"pruning local encounters never erases remote animal memory")
	var corrupt=saved.duplicate(true); corrupt.nature.trees[tree.id].x=9000
	check(not V2.new().restore(corrupt),"expanded bounds still reject invalid coordinates")
	corrupt=saved.duplicate(true); corrupt.journey.points["1"].z=NAN
	check(not V2.new().restore(corrupt),"waypoint NaN rejected")
	var legacy=saved.duplicate(true); legacy.erase("journey")
	check(V2.new().restore(legacy),"old saves without waypoints migrate")
	var placed=c.blocks.duplicate(true); s.planet.command(s,"v2_waypoint_remove",{"id":"1"})
	check(v.journey.points.is_empty() and c.blocks==placed,"removing waypoint never removes built objects")
	_era_tests()
	s.close_science(); print("FRONTIER17: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)

func _era_tests() -> void:
	var s=State.new(); var v=s.planet.v2; var c=v.construction; var e=v.settlement
	check(e.checklist(v.world,c).size()==5 and not e.ready(v.world,c),"fresh era lists five unmet or complete conditions")
	# Build six blocks as a real supported roof, preserving product unit totals.
	c.sources["1"]={"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"field:1"},"remaining":2}
	var y=c.base(Vector3i(15,0,14))
	for cell in [Vector3i(15,y,14),Vector3i(15,y+1,14),Vector3i(15,y+2,14),Vector3i(15,y+3,14),Vector3i(16,y+3,14),Vector3i(17,y+3,14)]:
		c.blocks[c.key(cell)]={"x":cell.x,"y":cell.y,"z":cell.z,"kind":"block","source":"1"}
	v.ranch.depot.grain=3; v.world.food=0; e.harvests=1; v.world.regions.meadow.water=0.4
	check(e.ready(v.world,c),"actual housing harvest and public grain count toward founding without world-food-only deadlock")
	var before=c.serialize(); e.advance_era(v.world,c)
	check(e.era==1 and e.people.size()==2 and c.serialize()==before,"promotion retains buildings and invites real residents")
	check(e.checklist(v.world,c).size()==8 and not e.ready(v.world,c),"modern stage exposes all eight requirements")
	place(v,"solar",Vector2(19,14)); e.harvests=3; e.meals=4; v.ranch.depot.water=1; e.energy=0
	check(not e.ready(v.world,c),"placing solar alone does not claim successful energy production")
	v.world.elapsed=30
	for i in range(18): e.tick(v.world,c)
	check(e.energy>=2 and e.ready(v.world,c),"actual daytime solar accumulation and supplies enable modern stage")
	var roofs=c.blocks.duplicate(true); c.blocks.clear()
	check(not e.ready(v.world,c),"demolishing living space invalidates modern readiness immediately")
	c.blocks=roofs; v.ranch.depot.water=0
	check(not e.ready(v.world,c) and e.requirements(v.world,c).contains("反应釜"),"missing real public water is blocked with reactor-source instructions")
	v.ranch.depot.water=1; v.ranch.depot.grain=0; v.world.food=100
	check(not e.ready(v.world,c),"unallocated backpack food cannot masquerade as resident supplies")
	v.ranch.depot.grain=3
	for p in e.people: p.health=0.1
	check(not e.ready(v.world,c),"critically unwell residents prevent upgrading an abandoned settlement")
	e.people[0].health=0.9; e.people[0].hunger=0.2
	check(e.ready(v.world,c) and e.checklist(v.world,c).all(func(row): return row.complete),"displayed checklist and actual readiness share one authority")
	e.advance_era(v.world,c); var population=e.people.duplicate(true); e.advance_era(v.world,c)
	check(e.era==2 and not e.ready(v.world,c) and e.people==population,"final implemented era cannot promote again or duplicate people")
	check(e.requirements(v.world,c).contains("没有下一时代"),"future unimplemented eras are clearly labelled")
	e.people.clear(); v.ranch.depot.grain=2; v.ranch.depot.water=1
	e.recruit(c)
	check(e.people.size()==1 and e.people[0].name=="新旅人 1" and v.ranch.depot.grain==0 and v.ranch.depot.water==0,"empty settlement can recruit a new person using finite public supplies")
	e.recruit(c); check(e.people.size()==1,"recruitment without supplies cannot duplicate residents")
	var copy=e.get_script().new(); check(copy.restore(JSON.parse_string(JSON.stringify(e.serialize()))),"replacement resident identity survives old-compatible save schema")
	s.close_science()
