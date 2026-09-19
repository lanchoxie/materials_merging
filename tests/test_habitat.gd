extends SceneTree
const Habitat=preload("res://scripts/planet_habitat.gd")
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func step(m,w,seconds: int) -> void:
	for i in range(seconds): m.step(w,int(w.elapsed)+1)
func act(s,a: String,d: Dictionary={}) -> String: return s.planet.command(s,a,d)
func ship(s,site: String,id: String) -> void:
	act(s,"deploy",{"world_id":s.planet.worlds.active_id,"site_id":site,"recipe":id,"token":s.planet.shipment_serial})
func _initialize() -> void:
	var m=Habitat.new(); var w=m.fresh(0,true)
	check(m.valid(w,0),"initial habitat has closed accounts and bounded representatives")
	var dormant=m.fresh(); var untouched=dormant.duplicate(true); step(m,dormant,300)
	check(Same.same(untouched,dormant) and not m.can_deploy(dormant,"habitat_fern","standard_water_crate"),"dormant chapter does not consume or age")
	check(m.route(w,"fern","ridge").is_empty() and not m.route(w,"fern","wood").is_empty(),"new refuge requires a real connection")
	check(not m.can_deploy(w,"crossing_fern_ridge","standard_water_crate") and not m.can_deploy(w,"habitat_fern","oxygen_cartridge"),"wrong destinations and products rejected")
	m.deploy(w,"crossing_fern_ridge","habitat_bridge")
	check(m.route(w,"fern","ridge")==["fern_ridge"] and not m.can_deploy(w,"crossing_fern_ridge","habitat_bridge"),"one bridge creates a reusable connection without duplicate spending")
	m.control(w,"fern_ridge"); check(m.route(w,"fern","ridge").is_empty(),"closed route is removed from pathfinding")
	m.control(w,"fern_ridge")
	var bridged=w.duplicate(true); var baseline=m.fresh(0,true)
	step(m,w,300); step(m,baseline,300)
	var visited=false
	for animal in w.animals: visited=visited or animal.at=="ridge" or animal.to=="ridge"
	check(w.regions.ridge.drunk>0 and baseline.regions.ridge.drunk==0,"bridge lets actual animals use previously unreachable refuge water")
	var crossing=m.fresh(0,true); m.deploy(crossing,"crossing_fern_ridge","habitat_bridge")
	var p=crossing.animals[0]; p.to="ridge"; p.edge="fern_ridge"; p.action="walk"; p.progress=0.50
	m.control(crossing,"fern_ridge"); step(m,crossing,10)
	check(p.at=="ridge" and p.to.is_empty() and m.route(crossing,"ridge","fern").is_empty(),"closing a bridge finishes the current crossing without teleportation")
	var shade=m.fresh(0,true); var bare=m.fresh(0,true); m.deploy(shade,"habitat_ridge","shade_canopy")
	step(m,shade,90); step(m,bare,90)
	check(shade.regions.ridge.evaporated<bare.regions.ridge.evaporated and shade.regions.ridge.grown<bare.regions.ridge.grown,"shade conserves water while reducing growth at the same unreachable test site")
	check(not m.can_deploy(shade,"habitat_ridge","shade_canopy"),"only one shade installation per region")
	var full=m.fresh(0,true)
	check(not m.can_deploy(full,"habitat_lagoon","standard_water_crate"),"full water point rejects whole crate without clipping its contents")
	m.deploy(full,"habitat_fern","standard_water_crate")
	check(full.regions.fern.water==60 and full.regions.fern.added==38,"external water enters the exact resource ledger")
	var hunter=m.fresh(0,true)
	for a in hunter.animals:
		a.at="wood"; a.hunger=70; a.thirst=0
	for id in ["lagoon_wood","fern_lagoon"]: hunter.edges[id].open=false
	step(m,hunter,160)
	check(hunter.kills>0 and hunter.regions.wood.remains>0 and hunter.regions.wood.scavenged>0,"encounters produce finite remains and actual predator food")
	check(m.valid(hunter,160),"predation and remains balances remain valid")
	var deaths=m.fresh(0,true)
	for id in deaths.regions:
		var r=deaths.regions[id]; r.evaporated=r.water; r.water=0; r.wilted=r.plants; r.plants=0
	for a in deaths.animals: a.thirst=100; a.hunger=100; a.health=0.1
	step(m,deaths,1); var dead=m.alive(deaths)
	m.deploy(deaths,"habitat_fern","standard_water_crate"); step(m,deaths,300)
	check(dead==0 and m.alive(deaths)==0 and m.valid(deaths,301),"water and rain cannot revive a lost individual")
	var resumed=JSON.parse_string(JSON.stringify(w)); var uninterrupted=w.duplicate(true)
	step(m,resumed,240); step(m,uninterrupted,240)
	check(Same.same(resumed,uninterrupted),"JSON save/load preserves deterministic trajectories and ledgers")
	step(m,w,1500)
	check(m.valid(w,1800) and w.history.size()==60,"thirty simulated minutes keep history bounded and resources valid")
	for kind in ["water","plants","remains","route","revive","history","species","count"]:
		var bad=w.duplicate(true)
		match kind:
			"water": bad.regions.fern.water+=3
			"plants": bad.regions.wood.grazed+=2
			"remains": bad.regions.ridge.remains+=5; bad.regions.ridge.carrion+=5
			"route": bad.animals[0].to="lagoon"; bad.animals[0].edge="invalid"
			"revive": bad.animals[0].alive=true; bad.animals[0].health=0
			"history": bad.history[-1].at=bad.history[0].at
			"species": bad.animals[0].species="tyrannosaurus"
			"count": bad.migrations+=1
		check(not m.valid(bad,1800),"reject tampering: "+kind)
	var s=State.new(); s.coins=9000; var program=s.planet; act(s,"join"); act(s,"activate_habitat")
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,2); act(s,"qualify",{"batch_id":sample.id})
	for id in ["habitat_bridge","shade_canopy"]:
		var recipe=program.recipe(id); act(s,"buy_feed",{"input":recipe.input}); act(s,"pack",{"recipe":id}); program.tick(recipe.seconds)
	check(program.products.size()==2,"two new products use existing qualified, paid, finite workshop jobs")
	var wallet=s.coins; var serial=program.shipment_serial
	ship(s,"habitat_fern","habitat_bridge")
	check(program.products.size()==2 and program.shipment_serial==serial and wallet==s.coins,"failed location spends nothing")
	ship(s,"crossing_fern_ridge","habitat_bridge"); ship(s,"habitat_fern","shade_canopy")
	check(program.products.is_empty() and program.worlds.get_world().habitat.edges.fern_ridge.built,"manufactured products deploy once into career habitat")
	var after=program.serialize(); act(s,"deploy",{"world_id":"home","site_id":"crossing_wood_ridge","recipe":"habitat_bridge","token":serial})
	check(Same.same(after,program.serialize()),"stale shipment cannot duplicate a bridge")
	act(s,"step_world"); act(s,"fork"); act(s,"select",{"world_id":"home"}); act(s,"fork")
	check(program.worlds.can_step_pair(),"two habitat forks share the exact baseline and time")
	var home=program.worlds.get_world("home").duplicate(true); var inventory=program.products.duplicate(true)
	ship(s,"crossing_wood_ridge","habitat_bridge"); act(s,"step_pair")
	check(Same.same(home,program.worlds.get_world("home")) and Same.same(inventory,program.products),"experimental bridge and time do not change career world or stock")
	check(program.worlds.get_world("trial_a").habitat.elapsed==40 and program.worlds.get_world("trial_b").habitat.elapsed==40,"paired experiment advances both ecological times")
	var saved=program.serialize(); var loaded=Program.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(saved)),s) and Same.same(saved,loaded.serialize()),"full program restores habitat snapshots, accounts and comparison keys")
	act(s,"reset_trial"); check(program.worlds.get_world().habitat.elapsed==30,"reset restores baseline instead of making an unrelated fresh habitat")
	for version in ["v011","v012","v0121","v013","v014"]:
		var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planet_"+version+".json")); var upgraded=Program.new()
		check(upgraded.restore(legacy,s),"actual "+version+" fixture migrates")
		check(not upgraded.worlds.get_world().habitat.enabled and upgraded.serialize().version==10,"migration adds dormant habitat: "+version)
	s.close_science()
	print("HABITAT PROBE baseline300=",m.alive(baseline)," linked540=",m.alive(resumed)," migration=",w.migrations," kills=",w.kills)
	print("HABITAT: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
