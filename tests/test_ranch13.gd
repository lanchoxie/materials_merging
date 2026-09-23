extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const V2=preload("res://scripts/planet_v2.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func place(v,kind: String,at: Vector2) -> String:
	var c=v.construction; var serial=str(c.sources.size()+1); var recipe="field_"+kind
	var b={"x":int(at.x),"y":c.base(Vector3i(int(at.x),0,int(at.y))),"z":int(at.y),"kind":kind,"source":serial}
	c.sources[serial]={"product":{"id":int(serial),"recipe":recipe,"recipe_version":1,"source_batch":"field:"+serial},"remaining":int(c.rules.recipes[recipe].units)-1}
	var key=c.key(c.cell(b)); c.blocks[key]=b; c.revision+=1; v.ranch.sync(v); return key
func look(v,p: Vector2,height: float=0.7) -> void:
	var target=Vector3(p.x,v.construction.terrain.ground(p)+height,p.y)
	v.actor={"eye":target+Vector3(0,0,2.5),"feet":target+Vector3(0,-1,2.5),"direction":Vector3.FORWARD}
func _initialize() -> void:
	var factory=State.new(); factory.coins=10000; factory.campus_build(3,"workshop"); factory.campus_road(3); factory.campus_assign_post(factory.campus.people[0].id,"workshop")
	factory.planet.command(factory,"join")
	factory.planet.v2.field.stock.stone=4; factory.planet.v2.field.stock.timber=3; factory.planet.v2.field.stock.fiber=2
	var wallet=factory.coins
	for recipe in ["field_trough","field_feeder"]:
		factory.planet.command(factory,"pack",{"recipe":recipe,"production_mode":"island"}); factory.planet.tick(60,1)
	check(factory.planet.products.size()==2,"real island workshop manufactures both new facility recipes")
	check(factory.planet.v2.field.stock.stone==0 and factory.planet.v2.field.stock.timber==0 and factory.planet.v2.field.stock.fiber==0 and factory.coins==wallet,"facility crafting consumes exact natural inputs without extra coins")
	var factory_items=factory.planet.v2.inventory.entries(factory)
	check(factory_items.get("recipe:field_trough",{}).get("quantity")==1 and factory_items.get("recipe:field_feeder",{}).get("quantity")==1,"manufactured facilities appear as one placeable piece each in shared backpack")
	var factory_copy=State.new(); check(factory_copy.planet.restore(JSON.parse_string(JSON.stringify(factory.planet.serialize())),factory_copy),"actual new workshop products and source reservations survive save validation")
	var s=State.new(); var v=s.planet.v2; var r=v.ranch; v.active=true
	v.field.stock.grain=8; v.field.stock.stone=8
	var seeds=v.world.seeds; var coins=s.coins
	s.planet.command(s,"v2_ranch_transfer",{"item":"seed","amount":5})
	check(v.world.seeds==seeds-5 and r.depot.seed==5 and s.coins==coins,"explicit deposit conserves seed stock without coins")
	s.planet.command(s,"v2_ranch_transfer",{"item":"seed","amount":-1})
	check(v.world.seeds==seeds-4 and r.depot.seed==4,"withdraw restores the exact seed")
	var old=r.depot.duplicate(); s.planet.command(s,"v2_ranch_transfer",{"item":"water","amount":5})
	check(r.depot==old,"water cannot be invented by a generic deposit")
	var water=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(water,3)
	var payload={"batch_id":water.id,"token":s.planet.shipment_serial}
	s.planet.command(s,"v2_ranch_water",payload); s.planet.command(s,"v2_ranch_water",payload)
	check(r.depot.water==1 and s.storage.batch(water.id).quantity==2,"water deposit consumes one real sample and rejects replay")
	var salt=s.product_snapshot(s._new_reactor(4,"oxygen",0)); s.storage.add_product(salt,1)
	s.planet.command(s,"v2_ranch_water",{"batch_id":salt.id,"token":s.planet.shipment_serial})
	check(r.depot.water==1 and s.storage.batch(salt.id).quantity==1,"non-water molecules are not accepted as drinking water")
	var trough=place(v,"trough",Vector2(12,12)); look(v,Vector2(12,12),0.3)
	s.planet.command(s,"v2_field_water",{"batch_id":water.id,"token":s.planet.shipment_serial})
	check(r.facilities[trough].stock==1 and s.storage.batch(water.id).quantity==1,"aimed trough accepts the same finite reactor sample")
	check(v.construction.occupied.has(trough),"stocked trough is protected against dismantling and miniature duplication")
	var e={}
	for candidate in v.combat.entities(v):
		if candidate.type=="animal" and not candidate.fish: e=candidate; break
	e.row.x=(12.0-10)/2.2; e.row.z=(13.4-10)/2.2; e.position=Vector2(12,13.4)
	var l=r.life(e.key); l.thirst=0.8; e.row.hunger=0.1
	r.tick(v)
	check(r.facilities[trough].stock==0 and l.thirst<0.4,"animal reaches real trough edge and consumes exactly one water portion")
	r.facilities[trough].stock=1; l.thirst=0.8
	var fence=place(v,"fence",Vector2(12,13)); e.row.z=(14.0-10)/2.2
	for i in range(2): r.tick(v)
	check(r.facilities[trough].stock==1,"wall between animal and water prevents remote drinking")
	v.construction.blocks.erase(fence); v.construction.sources.erase(str(v.construction.sources.size()))
	l.thirst=0.1; l.fatigue=0.9; r.tick(v)
	check(l.task=="休息" and l.fatigue<0.9,"tired animal actually rests")
	r.fed(e,0); var trust=l.trust; r.fed(e,1)
	check(trust>0 and l.trust==trust,"rapid feeding cannot farm trust")
	r.attacked(e,1); var hurt_trust=l.trust; r.fed(e,2)
	check(l.trust==hurt_trust and l.memory.size()<=3,"one meal does not erase violence and memory is bounded")
	# Complete a real job chain; actor is elsewhere, so citizens must walk themselves.
	var worker=V2.new(); var wr=worker.ranch; var garden=place(worker,"planter",Vector2(17,14))
	worker.settlement.era=1; worker.settlement.people=[{"id":1,"name":"禾苗","health":1.0,"hunger":0.0,"x":15.0,"z":14.0,"task":"安家"}]
	wr.depot.seed=1; wr.depot.water=3; wr.depot.fruit=5
	var player_stock=worker.field.stock.duplicate(); var player_seeds=worker.world.seeds
	for i in range(60): worker.advance(1)
	check(worker.field.gardens.has(garden),"farmer carries a public seed to an actual planter and plants it")
	check(worker.field.gardens.get(garden,{}).get("waterings",0)>0 and wr.depot.water<3,"farmer delivers finite water to the planted box")
	check(worker.field.stock==player_stock and worker.world.seeds==player_seeds,"automated farm never secretly debits or credits player backpack")
	worker.field.gardens[garden].growth=1
	for i in range(60): worker.advance(1)
	check(wr.depot.grain>=3 and worker.settlement.harvests==1,"mature crop is carried back as finite public grain and seed")
	check(V2.new().restore(JSON.parse_string(JSON.stringify(worker.serialize()))),"public depot, pending carry and gardens survive a JSON save")
	var bad=worker.serialize(); bad.ranch.depot.water=-1; check(not V2.new().restore(bad),"negative depot inventory is rejected")
	bad=worker.serialize(); bad.ranch.jobs={"1":{"action":"浇水","stage":"work","item":"water","target":garden,"cargo":{},"left":2}}
	check(not V2.new().restore(bad),"work without reserved cargo is rejected")
	var legacy=V2.new().serialize(); legacy.erase("ranch"); check(V2.new().restore(legacy),"sandbox12 saves migrate with empty public depot")
	var repair=place(worker,"trough",Vector2(17,16)); wr.facilities[repair].integrity=0.4; wr.depot.stone=1
	worker.settlement.people.append({"id":2,"name":"石川","health":1.0,"hunger":0.0,"x":15.0,"z":14.0,"task":"安家"})
	for i in range(60): worker.advance(1)
	check(wr.facilities[repair].integrity>0.65 and wr.depot.stone==0,"artisan walks with one stone and repairs real worn equipment")
	# A visitor has a finite offer per persistent visit; closing the panel is not a restock.
	var visitor=v.population.sites.meadow.visitors[0]; visitor.x=20.0-10; visitor.x=8.0; visitor.z=8.0
	look(v,Vector2(18,18),1.1)
	var pine=v.nature.seeds.pine; var grain=v.field.stock.grain
	for i in range(3): s.planet.command(s,"v2_ranch_trade")
	check(v.nature.seeds.pine==pine+2 and v.field.stock.grain==grain-4,"merchant sells only two carried seeds, using real backpack grain")
	var trader_key="visitor:meadow:"+str(int(visitor.id)); var pe={"key":trader_key}
	r.trades.erase(trader_key); r.attacked(pe,int(v.world.elapsed))
	s.planet.command(s,"v2_ranch_trade")
	check(v.nature.seeds.pine==pine+2,"hostile merchant refuses trade even with new stock")
	var cleanup=r.facilities[trough].stock; r.facilities[trough].integrity=0.8
	var stone=v.field.stock.stone; var stored_water=r.depot.water
	s.planet.command(s,"v2_ranch_empty",{"key":trough})
	check(r.facilities[trough].stock==0 and r.facilities[trough].integrity==1 and v.field.stock.stone==stone-1 and r.depot.water==stored_water+cleanup,"unloading moves remaining contents and spends finite repair material")
	check(not v.construction.occupied.has(trough),"empty repaired equipment can be dismantled or miniaturized")
	bad=worker.serialize(); bad.ranch.jobs={"1":{"action":"播种","stage":"work","item":"seed","target":repair,"cargo":{"seed":1},"left":2}}
	check(not V2.new().restore(bad),"save validator rejects planting inside a trough")
	var unattended=V2.new(); var ug=place(unattended,"planter",Vector2(17,14)); unattended.settlement.era=1
	unattended.settlement.people=[{"id":1,"name":"禾苗","health":1.0,"hunger":0.1,"x":15.0,"z":14.0,"task":"安家"}]
	for i in range(40): unattended.advance(1)
	check(not unattended.field.gardens.has(ug) and unattended.world.seeds==6,"empty public depot does not steal private seeds or create crops")
	var population=V2.new(); population.population.observe(Vector2(68,68)); var kinds={}
	for site in population.population.sites.values():
		for animal in site.animals: kinds[animal.species]=true
	check(kinds.has("meadow_herbivore") and kinds.has("woodland_boar"),"new wilderness contains two land species with different encounter behavior")
	check(population.combat.reaction({"fish":false,"type":"wild","row":{"species":"woodland_boar"}})=="反击" and population.combat.reaction({"fish":false,"type":"wild","row":{"species":"meadow_herbivore"}})=="逃跑","reaction follows species rather than an arbitrary numeric ID")
	# Close and reopen halfway through movement. Need thresholds must be stable across JSON floats.
	var a=V2.new(); a.advance(120); var b=V2.new(); check(b.restore(JSON.parse_string(JSON.stringify(a.serialize()))),"ecology snapshot reloads")
	var first=-1
	for i in range(60):
		a.advance(1); b.advance(1)
		if not Same.same(a.world,b.world) and first<0:
			first=i
	check(first<0,"animal paths and needs continue identically after reloading")
	FileAccess.open("res://artifacts/ranch13-model-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("RANCH13: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
