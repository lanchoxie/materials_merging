extends SceneTree
## v0.32 Earth: climate baseline, biomes, machines, atmosphere and warming, saves, wildlife.
const Planet=preload("res://scripts/planet_v2.gd")
const Climate=preload("res://scripts/planet_environment.gd")
const Population=preload("res://scripts/river_population.gd")
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func find_cell(env,want: Callable) -> Vector2i:
	for j in range(env.size):
		for i in range(env.size):
			var c=Vector2i(i,j)
			if env.cell_center(c).length()<7600 and want.call(env.values(c)): return c
	return Vector2i(-1,-1)

## A machine block at the cell centre, with a matching one-unit source pack.
func place(v,c: Vector2i,kind: String,recipe: String,id: int) -> String:
	var at=v.environment.cell_center(c); var x=roundi(at.x)+id%10*2; var z=roundi(at.y)
	var y=v.construction.base(Vector3i(x,0,z))
	var k=v.construction.key(Vector3i(x,y,z))
	v.construction.sources[str(id)]={"product":{"id":id,"recipe":recipe,"recipe_version":1,"source_batch":"test"},"remaining":0}
	v.construction.blocks[k]={"x":x,"y":y,"z":z,"kind":kind,"source":str(id)}
	v.construction.revision+=1
	return k

func run(v,seconds: int) -> void:
	v.active=true
	while seconds>0:
		var step=mini(seconds,480); v.advance(step); seconds-=step

func _initialize() -> void:
	var env=Climate.new()
	# --- Baseline: the start area is unchanged, the far world has every biome.
	check(env.biome_at(Vector2.ZERO)=="grassland" and env.biome_at(Vector2(200,-150))=="grassland","the start area stays grassland")
	var h=env.habitat(Vector2(64,64)); var old: Dictionary=Population.new().rules.wild_environment
	check(absf(h.water-float(old.water))<0.02 and absf(h.moisture-float(old.moisture))<0.02 and absf(h.temperature-float(old.temperature))<1.5,"near wild sites keep the old wild environment")
	check(Population.new()._suitable(h),"the start area is still habitable")
	var counts={}
	for j in range(env.size):
		for i in range(env.size):
			var c=Vector2i(i,j)
			if env.cell_center(c).length()<8192: counts[env.biome_of(env.values(c))]=int(counts.get(env.biome_of(env.values(c)),0))+1
	for b in ["grassland","forest","wetland","desert","tundra"]: check(int(counts.get(b,0))>=40,"the world has a real %s region (%d cells)" % [b,int(counts.get(b,0))])
	check(env.biome_at(Vector2(0,-6000))=="tundra" and env.biome_at(Vector2(1348,1348))=="forest","north is frozen and the 千米林海 is forest")
	check(env.base_water==Climate.new().base_water and env.base_heat==Climate.new().base_heat,"the baseline is deterministic")
	check(env.tint(env.blend(Vector2.ZERO),Color("749b64")).is_equal_approx(Color("749b64")),"start-area grass keeps its old colour")
	check(not env.tint(env.values(env.cell_of(Vector2(0,-6000))),Color("749b64")).is_equal_approx(Color("749b64")),"tundra ground is tinted")
	# --- A sprinkler greens a desert.
	var v=Planet.new()
	var dry=find_cell(v.environment,func(x): return x.x>0.08 and x.x<0.2 and x.y>8 and x.y<26)
	check(dry.x>=0,"a reclaimable desert cell exists")
	if dry.x<0: return _finish()
	check(v.environment.biome_of(v.environment.values(dry))=="desert","the chosen cell starts as desert")
	var version=v.environment.chunk_version(v.environment.cell_center(dry))
	var k1=place(v,dry,"sprinkler","earth_sprinkler",9001)
	var k2=place(v,dry,"sprinkler","earth_sprinkler",9002)
	run(v,2400)
	var wet: Vector4=v.environment.values(dry)
	check(wet.x>0.25+0.2 and v.environment.biome_of(wet)!="desert","two sprinklers turn the desert into %s (water %.2f)" % [v.environment.biome_of(wet),wet.x])
	check(v.environment.chunk_version(v.environment.cell_center(dry))!=version,"the cell's render version changed")
	var side=dry+Vector2i(1,0)
	check(v.environment.deltas.has(v.environment._key(side)) and float(v.environment.deltas[v.environment._key(side)][0])>0.05,"neighbour cells get a share")
	check(v.environment.machine_count("sprinkler")==2,"machines are counted from construction")
	# --- Save round trip, forged values, and old saves without the key.
	var saved=JSON.parse_string(JSON.stringify(v.serialize()))
	check(saved.has("environment"),"planet save carries the environment")
	var q=Planet.new()
	check(q.restore(saved),"environment round trip restores")
	check(q.environment.values(dry).is_equal_approx(v.environment.values(dry)) and q.environment.co2==v.environment.co2,"restored climate matches")
	var forged=saved.duplicate(true); forged.environment.cells["99:0"]=[0.1,0,0,0]
	check(not Planet.new().restore(forged),"cells outside the grid are rejected")
	forged=saved.duplicate(true); forged.environment.co2=1e6
	check(not Planet.new().restore(forged),"impossible CO2 is rejected")
	forged=saved.duplicate(true); forged.environment.cells[forged.environment.cells.keys()[0]]=[5.0,0,0,0]
	check(not Planet.new().restore(forged),"out-of-range deltas are rejected")
	var legacy=saved.duplicate(true); legacy.erase("environment")
	var older=Planet.new()
	check(older.restore(legacy) and older.environment.deltas.is_empty() and older.environment.co2==420.0,"saves from before Earth load with an untouched planet")
	# --- Removing machines lets the land recover.
	v.construction.blocks.erase(k1); v.construction.blocks.erase(k2); v.construction.revision+=1
	run(v,2400)
	check(v.environment.values(dry).x<wet.x-0.15,"after the sprinklers are removed the cell dries again")
	# --- CO2 towers warm the planet and speed crops; oxygen towers raise O2.
	var w=Planet.new(); var meadow=w.world.regions.meadow
	var spot=w.environment.cell_of(Vector2(400,400))
	place(w,spot,"co2_tower","earth_co2_tower",9101); place(w,spot+Vector2i(2,0),"co2_tower","earth_co2_tower",9102)
	place(w,spot+Vector2i(0,2),"oxygen_tower","earth_oxygen_tower",9103)
	var cold=find_cell(w.environment,func(x): return x.y>0.6 and x.y<1.9)
	run(w,3600)
	check(w.environment.co2>600 and w.environment.warming()>1.0,"two CO2 towers raise CO2 to %d ppm and warm %.1f°C" % [roundi(w.environment.co2),w.environment.warming()])
	check(w.environment.o2>21.0,"an oxygen tower raises O2")
	check(w.environment.co2_growth()>1.05,"higher CO2 speeds crops a little")
	var reference=Planet.new(); run(reference,3600)
	check(meadow.temperature>reference.world.regions.meadow.temperature+0.9,"home regions feel the warming")
	if cold.x>=0: check(w.environment.biome_of(w.environment.values(cold))!="tundra","warming thaws the edge of the tundra")
	# --- Wildlife follows the environment.
	var pop=w.population
	pop.observe(Vector2(1348,1348))
	var boars=0; var animals=0
	for key in pop.active_sites:
		for a in pop.sites[key].animals:
			animals+=1; boars+=int(a.species=="woodland_boar")
	check(animals>0 and boars==animals,"forest sites are boar country")
	var desert=find_cell(Climate.new(),func(x): return x.x<0.12 and x.y>8)
	if desert.x>=0: check(not pop._suitable(Climate.new().habitat(Climate.new().cell_center(desert))),"deep desert is not habitable")
	# --- Workshop: new samples qualify, old program saves gain the new kits.
	var s=State.new(); var pg=s.planet
	pg.command(s,"join")
	check(pg.command(s,"qualify",{"reference":"carbon_dioxide","batch_id":"none"}).contains("二氧化碳"),"CO2 samples are accepted as a qualification route")
	check(pg.command(s,"qualify",{"reference":"benzene"})=="暂无这个体系的工艺","unknown references stay closed")
	var program=JSON.parse_string(JSON.stringify(pg.serialize())); program.version=11
	for id in pg.EARTH_KITS: program.supplies.erase(id)
	var migrated=Program.new()
	check(migrated.restore(program,s) and migrated.supplies.has("earth_co2_tower_kit"),"v11 program saves migrate the Earth kits")
	check(pg.recipe("earth_sprinkler").get("reference")=="water" and pg.v2.construction.rules.kinds.sprinkler.get("machine",false),"the sprinkler is a workshop recipe and a construction machine")
	_finish()

func _finish() -> void:
	print("earth checks: %d, failures: %d" % [checks,failures.size()])
	for f in failures: print("  FAIL ",f)
	quit(1 if not failures.is_empty() else 0)
