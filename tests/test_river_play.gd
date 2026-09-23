extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const C=preload("res://scripts/river_construction.gd")
const Walker=preload("res://scripts/river_walker.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

class Flat extends RefCounted:
	var rules={"eye_height":1.62,"body_height":1.75,"walk_speed":3.2,"run_speed":5.2,"wading_multiplier":0.55,"step_height":0.62,"gravity":18.0,"jump_speed":7.0,"player_radius":0.24}
	func ground(_p): return 0.0
	func height_at(_p): return 0.3
	func bridge(_p): return false
	func spawn(_region): return Vector2.ZERO
	func blocked(p,barriers=[]):
		for r in barriers:
			if r.grow(0.24).has_point(p): return true
		return false

func manufacture(s,recipe: String) -> void:
	var pg=s.planet
	pg.command(s,"buy_feed",{"input":pg.recipe(recipe).input})
	pg.command(s,"pack",{"recipe":recipe}); pg.tick(60)

func actor_above(c,at: Vector2,height: float=4.0) -> Dictionary:
	var eye=Vector3(at.x,c.terrain.ground(at)+height,at.y)
	return {"eye":eye,"feet":eye-Vector3(0,1.62,0),"direction":Vector3.DOWN}

func _initialize() -> void:
	_jump_tests()
	var s=State.new(); s.coins=10000
	var pg=s.planet; var v=pg.v2; var c=v.construction
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,5)
	pg.command(s,"join"); pg.command(s,"qualify",{"batch_id":sample.id})
	manufacture(s,"frame_bundle"); check(pg.products.size()==1,"real factory makes building supply")
	var original=pg.products[0].duplicate(true); var wallet=s.coins
	v.active=true; v.actor=actor_above(c,Vector2(15,14))
	pg.command(s,"v2_build",{"kind":"block"})
	check(c.blocks.size()==1 and pg.products.is_empty() and c.available("block",pg.products)==7,"placement transfers one source package and consumes one of eight units")
	check(s.coins==wallet,"planet construction never buys with coins")
	var initial=c.serialize(); v.actor={}
	pg.command(s,"v2_build",{"kind":"block"}); check(Same.same(initial,c.serialize()),"no observer cannot construct")
	v.actor=actor_above(c,Vector2(15,14),10)
	pg.command(s,"v2_build",{"kind":"block"}); check(Same.same(initial,c.serialize()),"out of reach rejects atomically")
	v.actor=actor_above(c,Vector2(15,14)); pg.command(s,"v2_repack",{"source_id":str(original.id)})
	check(pg.products.is_empty(),"partly used package cannot duplicate full product")
	pg.command(s,"v2_dismantle")
	check(c.blocks.is_empty() and c.available("block",pg.products)==8,"dismantle returns exact material quantity")
	pg.command(s,"v2_dismantle"); check(c.available("block",pg.products)==8,"repeated dismantling cannot duplicate")
	pg.command(s,"v2_repack",{"source_id":str(original.id)})
	check(c.sources.is_empty() and pg.products==[original],"all pieces repack into original ID and provenance")
	pg.command(s,"v2_repack",{"source_id":str(original.id)}); check(pg.products==[original],"repack replay is harmless")
	for y in range(4):
		var eye=Vector3(15,y+4,14)
		v.actor={"eye":eye,"feet":eye-Vector3(0,1.62,0),"direction":Vector3.DOWN}; pg.command(s,"v2_build",{"kind":"block"})
	for x in [16,17]:
		var eye=Vector3(x+1.8,3.5,14)
		v.actor={"eye":eye,"feet":eye-Vector3(0,1.62,0),"direction":Vector3.LEFT}; pg.command(s,"v2_build",{"kind":"block"})
	check(c.blocks.size()==6,"six constructions form a small site")
	check(c.shelter_cells(Vector2(10,10),14)>=2,"raised roof with headroom supplies real shelter cells")
	check(not v.settlement.ready(v.world,c),"structures alone cannot skip agriculture")
	v.world.current_region="meadow"; v.world.regions.meadow.crops=[{"crop":"grain","growth":1.0,"ready":true}]
	v.harvest(); v.world.regions.meadow.water=0.4
	var ids=v.world.regions.meadow.animals.duplicate(true); var buildings=c.serialize()
	pg.command(s,"v2_next_era")
	check(v.settlement.era==1 and v.settlement.people.size()==2,"food, harvest, water and housing allow two settlers")
	check(v.world.regions.meadow.animals==ids and c.serialize()==buildings,"era transition preserves living animals and player architecture")
	pg.command(s,"v2_next_era"); check(v.settlement.era==1,"next era still requires light technology and sustained meals")
	v.world.food=20; var food=v.world.food
	for i in range(4): pg.command(s,"v2_ranch_transfer",{"item":"ration","amount":5})
	var supplied=v.ranch.depot.ration
	for i in range(3): v.advance(240)
	check(v.settlement.meals>=4 and v.world.food<food and v.ranch.depot.ration<supplied and v.settlement.people.size()==2,"settlers walk to eat finite explicitly supplied public food and persist as people")
	manufacture(s,"modern_silicon")
	v.actor=actor_above(c,Vector2(19,14)); pg.command(s,"v2_build",{"kind":"solar"})
	check(c.count_kind("solar")==1 and pg.products.is_empty(),"actual factory photovoltaic product is installed once")
	v.world.regions.meadow.crops=[{"crop":"grain","growth":1.0,"ready":true},{"crop":"grain","growth":1.0,"ready":true}]; v.harvest()
	pg.command(s,"v2_ranch_water",{"batch_id":sample.id,"token":pg.shipment_serial})
	v.advance(60)
	pg.command(s,"v2_next_era"); check(v.settlement.era==2,"modern chapter requires actual solar plus agriculture and meals")
	var original_time=v.world.elapsed
	v.world.regions.meadow.water=0.5; v.world.regions.meadow.moisture=0.5; v.world.elapsed=30
	v.settlement.energy=10; var water=v.world.regions.meadow.water; var moisture=v.world.regions.meadow.moisture
	v.settlement.tick(v.world,c)
	check(v.settlement.irrigation and v.world.regions.meadow.water<water and v.world.regions.meadow.moisture>moisture,"powered irrigation transfers finite water to soil")
	v.world.elapsed=0; v.settlement.energy=0; v.settlement.tick(v.world,c)
	check(not v.settlement.irrigation and v.settlement.energy==0,"empty energy at night cannot irrigate")
	v.world.elapsed=original_time
	var serialized=pg.serialize(); var other=State.new()
	check(other.planet.restore(serialized,other),"full program validates constructed product sources and community")
	check(Same.same(other.planet.v2.serialize(),v.serialize()),"construction, residual stock and era survive round trip")
	var bad=serialized.duplicate(true); var source=c.sources.keys()[0]
	bad.v2.construction.sources[source].remaining+=1
	check(not other.planet.restore(bad,other),"save cannot create extra loose blocks")
	bad=serialized.duplicate(true); bad.products.append(c.sources[source].product.duplicate(true))
	check(not other.planet.restore(bad,other),"same product cannot exist in both world and backpack")
	bad=serialized.duplicate(true); bad.v2.construction.blocks.values()[0].x=NAN
	check(not other.planet.restore(bad,other),"nonfinite block coordinates rejected")
	var old=serialized.duplicate(true); old.v2.erase("construction"); old.v2.erase("settlement")
	check(other.planet.restore(old,other) and other.planet.v2.construction.blocks.is_empty(),"pre-building saves migrate without a free stock grant")
	var tree=c.terrain.trees[0]; var origin=Vector3(tree.x,c.terrain.ground(tree)+1.6,tree.y+2)
	check(c.trace(origin,Vector3.FORWARD).get("blocked",false),"trees occlude building ray")
	var independent=C.new(); independent.sources={"1":{"product":{"id":1,"recipe":"frame_bundle"},"remaining":5}}
	var base=independent.base(Vector3i(15,0,14))
	for cell in [Vector3i(15,base,14),Vector3i(15,base+1,14),Vector3i(16,base+1,14)]: independent.blocks[independent.key(cell)]={"x":cell.x,"y":cell.y,"z":cell.z,"kind":"block","source":"1"}
	var detached=independent.blocks.duplicate(); detached.erase(independent.key(Vector3i(15,base,14)))
	check(independent.connected(independent.blocks) and not independent.connected(detached),"support connectivity detects a detached bridge")
	s.close_science(); other.close_science()
	print("RIVER PLAY: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func _jump_tests() -> void:
	var flat=Flat.new(); var w=Walker.new(flat); w.enter("test")
	check(w.jump() and not w.jump(),"jump starts only once while grounded")
	var peak=0.0
	for i in range(180): w.step(1.0/120); peak=maxf(peak,w.feet_y)
	check(peak>1.25 and peak<1.4 and w.grounded and is_zero_approx(w.feet_y),"gravity gives a useful bounded jump and lands exactly")
	var c=C.new(); c.blocks={"0:0:0":{"x":0,"y":0,"z":0,"kind":"block","source":"1"}}
	c.terrain=flat; w.construction=c; w.position=Vector2(0,1.2); w.reset_height(); w.yaw=0; w.movement=Vector2(0,-1)
	for i in range(30): w.step(1.0/120)
	check(w.position.y>0.7,"solid block cannot be walked through")
	w.jump()
	for i in range(55): w.step(1.0/120)
	w.stop()
	for i in range(120): w.step(1.0/120)
	check(w.grounded and is_equal_approx(w.feet_y,1.0),"jump lands on player-built platform")
	w.movement=Vector2(1,0)
	for i in range(180): w.step(1.0/120)
	check(w.grounded and is_zero_approx(w.feet_y),"walking off a platform falls back to terrain")
	c.blocks={"0:3:0":{"x":0,"y":3,"z":0,"kind":"block","source":"1"}}
	w.position=Vector2.ZERO; w.construction=null; w.reset_height(); w.construction=c; w.stop(); w.jump(); peak=0
	for i in range(180): w.step(1.0/120); peak=maxf(peak,w.feet_y)
	check(peak<=1.251 and w.grounded,"jump hits roof without passing through it")
