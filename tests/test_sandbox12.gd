extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const V2=preload("res://scripts/planet_v2.gd")
const Mini=preload("res://scripts/river_miniatures.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func above(v,p: Vector2) -> void:
	var ground=v.construction.terrain.ground(p)
	v.actor={"eye":Vector3(p.x,ground+3,p.y),"feet":Vector3(p.x,ground+1.38,p.y),"direction":Vector3.DOWN}
func facing(v,p: Vector2,height: float=1.0) -> void:
	var target=Vector3(p.x,v.construction.terrain.ground(p)+height,p.y)
	var eye=target+Vector3(0,0,2.1)
	v.actor={"eye":eye,"feet":eye-Vector3(0,1.62,0),"direction":Vector3.FORWARD}
func _initialize() -> void:
	var s=State.new(); var v=s.planet.v2; var c=v.construction; var t=c.terrain; var n=v.nature; var f=v.field; v.active=true
	var trees=[]; var species={}
	for z in range(-3,3):
		for x in range(-3,3):
			for tree in t.tree_records(Vector2i(x,z)): trees.append(tree); species[tree.species]=true
	check(species.size()==3,"natural world has three deterministic tree species")
	var tree=trees[0]; var p=Vector2(tree.x,tree.z); facing(v,p)
	check(v.Target.query(v).get("tree_id")==tree.id,"visible trunk is picked by the same ray as tool use")
	for i in range(4): s.planet.command(s,"v2_chop")
	check(n.lookup(tree.id,t).cut and f.stock.timber==5 and n.seeds[tree.species]==1,"four axe hits yield one finite timber and seed harvest")
	s.planet.command(s,"v2_chop"); check(f.stock.timber==5,"stump cannot be harvested twice")
	check(p not in t.chunk_trees(t.chunk_at(p)),"felled tree stops blocking locomotion")
	var saved=v.serialize(); var restored=V2.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))) and restored.nature.lookup(tree.id,restored.construction.terrain).cut,"felled tree and seed inventory survive reload")
	var free=Vector2(24,18); var found=false
	for x in range(20,39):
		for z in range(15,35):
			if found: break
			var candidate=Vector2(x,z); n.plant(tree.species,candidate,v)
			if n.seeds[tree.species]==0: free=candidate; found=true
	check(found,"real tree seed can be planted on available dry soil")
	var planted="p:"+n.cell_key(free); var old=n.serialize(); n.plant(tree.species,free,v)
	check(Same.same(old,n.serialize()),"repeated planting cannot duplicate a consumed seed")
	check(n.water_error(planted,t).is_empty(),"seedling accepts irrigation")
	above(v,free); var water=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(water,2)
	var payload={"batch_id":water.id,"token":s.planet.shipment_serial}
	s.planet.command(s,"v2_field_water",payload)
	check(n.trees[planted].water==1 and s.storage.batch(water.id).quantity==1,"water from reactor inventory irrigates aimed tree and is consumed once")
	s.planet.command(s,"v2_field_water",payload); check(s.storage.batch(water.id).quantity==1,"replayed irrigation cannot consume twice")
	for i in range(600): n.tick(t)
	check(n.trees[planted].growth==1 and free in t.chunk_trees(t.chunk_at(free)),"seedling matures into solid matching-species tree")
	var dirt=Vector2(15,14); var before=t.ground(dirt); above(v,dirt)
	s.planet.command(s,"v2_dig")
	check(f.stock.soil==1 and is_equal_approx(t.ground(dirt),before-1),"digging changes shared terrain and grants exactly one soil")
	var walker=preload("res://scripts/river_walker.gd").new(t); walker.position=dirt; walker.reset_height()
	check(is_equal_approx(walker.feet_y,t.ground(dirt)),"walking reads modified terrain height")
	v.actor.feet.y=t.ground(dirt); var edits=n.edits.duplicate(); s.planet.command(s,"v2_fill")
	check(n.edits==edits and f.stock.soil==1,"cannot entomb player with soil placement")
	above(v,dirt); s.planet.command(s,"v2_fill")
	check(f.stock.soil==0 and is_equal_approx(t.ground(dirt),before),"soil placement returns original ground and spends inventory")
	above(v,dirt); s.planet.command(s,"v2_fill"); check(is_equal_approx(t.ground(dirt),before),"no soil means no free terrain creation")
	above(v,dirt); s.planet.command(s,"v2_dig")
	saved=v.serialize(); restored=V2.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))) and is_equal_approx(restored.construction.terrain.ground(dirt),t.ground(dirt)),"terrain edit and harvested inventory persist together")
	var node=f.node("home:0"); var anchor=Vector2(node.x,node.z); f.changed[node.id]={"hits":1,"ready_at":0}
	n.seeds.oak=1; n.plant("oak",anchor,v)
	var stable=f.node(node.id)
	check(stable.x==node.x and stable.z==node.z and V2.new().restore(v.serialize()),"planting near a harvested resource preserves its identity and loadable save")
	var legacy=V2.new().serialize(); legacy.erase("nature"); legacy.erase("combat"); legacy.field.stock.erase("soil"); legacy.construction.erase("miniatures"); legacy.construction.erase("miniature_serial")
	check(V2.new().restore(legacy),"previous homestead save migrates without new fields")
	var bad=v.serialize(); bad.nature.edits["24:24"]=7
	check(not V2.new().restore(bad),"invalid terrain height is rejected")
	# Tiny real construction ledger, with two pieces reserved from an eight-piece package.
	var b1={"x":19,"y":c.base(Vector3i(19,0,14)),"z":14,"kind":"block","source":"1"}; var b2=b1.duplicate(); b2.y+=1
	c.sources={"1":{"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"field:1"},"remaining":6}}
	c.blocks={c.key(c.cell(b1)):b1,c.key(c.cell(b2)):b2}
	c.occupied[c.key(c.cell(b1))]={}; var original=c.serialize()
	Mini.pack(c,{"type":"block","key":c.key(c.cell(b1))})
	check(Same.same(original,c.serialize()),"occupied planter/plot cannot be packed around growing plants")
	c.occupied.clear(); Mini.pack(c,{"type":"block","key":c.key(c.cell(b1))})
	check(c.blocks.is_empty() and c.miniatures.size()==1 and c.sources["1"].remaining==6,"packing moves pieces into one model without refunding or copying material")
	check(preload("res://scripts/river_construction.gd").new().restore(c.serialize()),"packed model preserves validated source conservation")
	Mini.exhibit(c,"1",4,s.plots); above(v,Vector2(15,14)); Mini.unfold(c,"1",v.actor)
	check(c.blocks.is_empty() and c.miniatures.size()==1,"exhibited model cannot also be unpacked in world")
	Mini.exhibit(c,"1",-1,s.plots); above(v,Vector2(15,17)); v.actor.direction=(Vector3(15,t.ground(Vector2(15,14))+0.02,14)-v.actor.eye).normalized(); var result=Mini.unfold(c,"1",v.actor)
	check(c.blocks.size()==2 and c.miniatures.is_empty(),"packed model can be returned to world: "+result)
	Mini.unfold(c,"1",v.actor); check(c.blocks.size()==2 and c.sources["1"].remaining==6,"replayed unpack cannot duplicate pieces")
	# Human retaliation, grounded and unobstructed; ecology speed is irrelevant.
	var person={"id":1,"name":"禾苗","health":1.0,"hunger":0.1,"x":30.0,"z":30.0,"task":"安家"}
	v.settlement.era=1; v.settlement.people=[person]; facing(v,Vector2(30,30),0.8)
	var target=v.Target.query(v); check(target.get("entity",{}).get("type")=="resident","humans participate in same target query as animals")
	s.planet.command(s,"v2_strike"); check(person.health<1 and v.combat.records.get("resident:1",{}).get("anger",0)>0,"strike changes persistent health and anger")
	var health=person.health; s.planet.command(s,"v2_strike"); check(person.health==health,"strike cooldown prevents click-rate damage exploit")
	for i in range(100): v.combat.tick(0.02,v)
	check(v.combat.player_health<100,"angry resident closes distance and retaliates")
	var combat_saved=v.combat.serialize(); var combat_copy=preload("res://scripts/river_combat.gd").new()
	check(combat_copy.restore(combat_saved) and combat_copy.player_health==v.combat.player_health,"encounter health and anger survive reload")
	v.actor.feet=Vector3(70,1,70)
	for i in range(160): v.combat.tick(0.02,v)
	check(v.combat.records.is_empty(),"escaping beyond leash lets anger subside")
	v.combat.player_health=0; health=person.health; s.planet.command(s,"v2_strike")
	check(person.health==health,"defeated player cannot keep striking")
	v.combat.respawn(); check(v.combat.player_health==100 and v.combat.records.is_empty(),"camp recovery resets player health and pursuit")
	# Exercise save validation with factory-issued identities, not a synthetic ledger.
	var real=State.new(); real.coins=10000; var rv=real.planet.v2; rv.active=true
	real.planet.command(real,"join"); real.campus_build(3,"workshop"); real.campus_road(3); real.campus_assign_post(real.campus.people[0].id,"workshop")
	rv.field.stock.timber=4; real.planet.command(real,"pack",{"recipe":"field_wall","production_mode":"island"}); real.planet.tick(60,1)
	above(rv,Vector2(15,14)); real.planet.command(real,"v2_build",{"kind":"block","recipe":"field_wall"})
	var rc=rv.construction
	check(rc.blocks.size()==1,"factory-issued material can be placed before packing")
	real.planet.command(real,"v2_mini_pack"); real.planet.command(real,"v2_mini_exhibit",{"id":"1","plot":4})
	var reload=State.new()
	check(reload.planet.restore(JSON.parse_string(JSON.stringify(real.planet.serialize())),reload) and reload.planet.v2.construction.miniatures.size()==1,"full production ledger with exhibited model round-trips through planet save validation")
	var before_chunks=rc.terrain.chunk_at(Vector2(15,14)); var rev=rv.nature.chunk_versions.duplicate()
	rv.nature.touch(Vector2(15,14),rc.terrain)
	check(rv.nature.chunk_versions.size()<=9,"one terrain/tree edit invalidates bounded neighboring chunks")
	real.close_science(); reload.close_science()
	print("SANDBOX12: %d checks, %d failures" % [checks,failures.size()]); s.close_science(); quit(0 if failures.is_empty() else 1)

