extends SceneTree
const Model=preload("res://scripts/planet_industry.gd")
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func equivalent(a,b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))<=maxf(1e-9,maxf(absf(float(a)),absf(float(b)))*1e-12)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b
func step(m,w,n: int) -> void:
	for i in range(n): m.step(w,int(w.elapsed)+1)
func equipped(m,era="ww1") -> Dictionary:
	var w=m.fresh(era,0,true)
	m.deploy(w,"industry_power","generator_set"); m.deploy(w,"industry_power","heat_recovery")
	for i in range(4): m.deploy(w,"industry_depot","fuel_can")
	m.deploy(w,"industry_depot","industry_stock")
	for id in m.rules.loads: m.deploy(w,"industry_"+str(id),"copper_wire")
	return w
func act(s,a: String,d: Dictionary={}) -> String: return s.planet.command(s,a,d)
func ship(s,site: String,id: String) -> void:
	act(s,"deploy",{"world_id":s.planet.worlds.active_id,"site_id":site,"recipe":id,"token":s.planet.shipment_serial})
func _initialize() -> void:
	var m=Model.new(); var e=m.electrical
	var cu=e.calculate("copper","same_size"); var al=e.calculate("aluminum","same_size"); var light=e.calculate("aluminum","same_mass")
	check(is_equal_approx(cu.resistance_ohm,0.275856) and is_equal_approx(al.resistance_ohm,0.452224),"SI copper/aluminum resistance matches independent rho L/A calculation")
	check(cu.load_W>al.load_W and cu.wire_loss_W<al.wire_loss_W,"equal-area copper delivers more load power with less cable loss")
	check(is_equal_approx(light.mass_kg,cu.mass_kg) and light.area_m2>8.2e-6 and light.resistance_ohm<cu.resistance_ohm,"equal-mass aluminum is larger and lower resistance")
	var budget=e.circuit(1,400,24,50)
	check(is_equal_approx(budget.source_W,50) and is_equal_approx(budget.load_W+budget.wire_loss_W,50),"limited source closes its circuit power budget")
	check(e.circuit(1,400,24,0).load_W==0 and e.circuit(-1,400,24,40).is_empty() and e.circuit(1,400,24,NAN).is_empty(),"zero supply and invalid calculation inputs handled")
	check(e.calculate("unknown","same_mass").is_empty() and e.design("unknown").is_empty(),"unknown material never acquires invented properties")
	var report=e.proof("same_mass"); check(e.valid_report(report,"same_mass"),"reference report validates")
	check(e.valid_report(JSON.parse_string(JSON.stringify(report)),"same_mass"),"reference evidence survives JSON precision across SI magnitudes")
	var bad_area=report.duplicate(true); bad_area.aluminum.area_m2*=1.001
	check(not e.valid_report(bad_area,"same_mass"),"small absolute area edits remain detectable")
	report.aluminum.resistance_ohm*=0.5; check(not e.valid_report(report,"same_mass"),"modified reference evidence rejected")
	var w=m.fresh("ww1",0,true); check(m.valid(w,0),"fresh industry has valid ledgers")
	var dormant=m.fresh(); var before=dormant.duplicate(true); step(m,dormant,300)
	check(Same.same(before,dormant) and not m.can_deploy(dormant,"industry_power","generator_set"),"dormant industry neither ages nor consumes")
	check(not m.can_deploy(w,"industry_clinic","aluminum_wire_mass") and m.can_deploy(w,"industry_factory","aluminum_wire_mass"),"equal-mass aluminum is rejected only by narrow installation slots")
	m.deploy(w,"industry_factory","copper_wire"); m.deploy(w,"industry_factory","aluminum_wire_mass")
	check(w.cables_scrapped.copper_wire==1 and w.cables_received.aluminum_wire_mass==1 and not m.can_deploy(w,"industry_factory","aluminum_wire_mass"),"replaced cable is scrapped once with no duplicate same-design installation")
	m.deploy(w,"industry_power","generator_set"); step(m,w,10)
	check(w.generated_W==0 and w.chemical_J==0 and w.completed==0,"installed engine without fuel cannot generate power or products")
	var fueled=equipped(m); step(m,fueled,30)
	check(fueled.generated_W==1100 and fueled.useful_heat_J>0 and fueled.stock.fuel_kg<0.2,"engine spends finite fuel and recovers real heat")
	check(m.valid(fueled,30),"electrical and thermal ledgers close with populated loads")
	var care=equipped(m); var production=equipped(m); m.control(production,"policy","production")
	step(m,care,90); step(m,production,90)
	check(production.flow.factory>care.flow.factory and care.flow.homes>production.flow.homes,"priority policy redistributes a fixed source budget")
	check(production.produced.civil>care.produced.civil,"staffed factory gets greater output with production priority")
	check(production.shipped.civil>0 and production.transport_fuel_kg>0 and m.valid(production,90),"actual fuel-consuming route delivers completed cargo and keeps accounts valid")
	var order=equipped(m); m.control(order,"policy","production"); step(m,order,25)
	check(order.factory.active and order.factory.kind=="civil","factory starts after people arrive, reserving one input")
	m.control(order,"output","military"); step(m,order,100)
	check(order.produced.civil==1 and order.produced.military>0 and m.valid(order,125),"changing output preserves quoted batch and changes subsequent production")
	var dark=equipped(m); m.control(dark,"blackout"); step(m,dark,30)
	check(dark.flow.homes==0 and dark.heat_service>0 and dark.flow.clinic>0,"blackout removes home lighting while retaining heat and other circuits")
	m.control(dark,"engine"); var used=dark.engine_fuel_kg; step(m,dark,1)
	check(dark.generated_W==0 and dark.engine_fuel_kg==used,"switching off stops engine fuel and generation immediately")
	var damage=equipped(m); step(m,damage,110)
	check(damage.event_done and damage.integrity.signal==0 and damage.repairs_started==1 and damage.repair.progress==0,"line outage reserves one spare but requires on-site work")
	m.control(damage,"repairs"); var reserve=damage.used.spares; step(m,damage,30)
	check(damage.repair.progress==0 and damage.used.spares==reserve and damage.integrity.signal==0,"paused repairs preserve commitment without remote progress or repeated charges")
	m.control(damage,"repairs"); step(m,damage,70)
	check(damage.integrity.signal==1 and damage.repairs_completed==1 and damage.used.spares==1 and m.valid(damage,210),"engineer walks to fault and completes one repair")
	var raid=equipped(m,"ww2"); m.control(raid,"policy","production"); step(m,raid,150)
	var shelters=0
	for person in raid.people: shelters+=int(person.task=="shelter")
	check(raid.alert and raid.integrity.power==0.35 and shelters==6 and raid.repair.progress==0,"air-raid event damages station and workers actually reach shelter")
	step(m,raid,70)
	check(not raid.alert and raid.integrity.power==1 and raid.repairs_completed==1 and m.valid(raid,220),"after alarm engineer returns and repairs power")
	var exhausted=equipped(m); m.control(exhausted,"policy","production"); step(m,exhausted,2300)
	check(exhausted.stock.fuel_kg==0 and exhausted.generated_W==0 and m.valid(exhausted,2300),"long simulation cannot manufacture energy after fuel exhaustion")
	var cargo=exhausted.truck.duplicate(true); step(m,exhausted,40)
	check(Same.same(cargo,exhausted.truck),"fuel-starved vehicle cannot move or deliver cargo for free")
	check(exhausted.history.size()==60,"long observation bounds history storage")
	var arrival=equipped(m); m.control(arrival,"policy","production")
	# A legacy trip can reach an exact JSON 1 before its old next-tick settlement.
	for i in range(100):
		step(m,arrival,1)
		if arrival.truck.stage=="outbound": break
	arrival.truck.progress=1.0; var shipped=arrival.shipped.civil; var amount=arrival.truck.amount
	check(m.valid(JSON.parse_string(JSON.stringify(arrival)),arrival.elapsed),"legacy exact-arrival boundary remains loadable")
	step(m,arrival,1)
	check(arrival.truck.stage=="return" and arrival.shipped.civil==shipped+amount and m.valid(arrival,arrival.elapsed),"loaded arrival settles cargo once instead of duplicating or rejecting it")
	var saved=JSON.parse_string(JSON.stringify(raid)); var continuous=raid.duplicate(true); step(m,saved,240); step(m,continuous,240)
	check(equivalent(saved,continuous) and m.valid(saved,460),"JSON round-trip preserves deterministic people, energy and logistics")
	for field in ["energy","fuel","cable","route","event","clock","batch","fractional","cargo","history"]:
		var bad=continuous.duplicate(true)
		match field:
			"energy": bad.load_J+=100
			"fuel": bad.stock.fuel_kg+=0.01
			"cable": bad.cables.clinic="aluminum_wire_mass"
			"route": bad.people[0].route=["homes","factory"]; bad.people[0].task="travel"
			"event": bad.event_done=false
			"clock": bad.alert=true
			"batch": bad.started+=1
			"fractional": bad.stock.spares+=0.5; bad.added.spares+=0.5
			"cargo": bad.truck.amount+=1
			"history": bad.history[-1].at=bad.history[0].at
		check(not m.valid(bad,460),"reject tampered "+field)
	var s=State.new(); s.coins=9000; var p=s.planet; act(s,"join"); act(s,"activate_industry",{"era":"ww1"})
	check(p.worlds.get_world().paused and p.worlds.get_world().industry.enabled,"career industry activates paused")
	var snap=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(snap,2); act(s,"qualify",{"batch_id":snap.id})
	var wallet=s.coins; act(s,"pack",{"recipe":"copper_wire"})
	check(p.job.is_empty() and wallet==s.coins,"unrecorded electrical evidence cannot create a cable")
	act(s,"compare_circuits",{"mode":"same_size"})
	for id in ["generator_set","fuel_can","heat_recovery","copper_wire"]:
		var r=p.recipe(id); act(s,"buy_feed",{"input":r.input}); act(s,"pack",{"recipe":id}); p.tick(r.seconds)
	check(p.products.size()==4,"paid production completes distinct equipment, fuel, recovery and cable")
	var serial=p.shipment_serial; ship(s,"industry_clinic","fuel_can")
	check(p.products.size()==4 and p.shipment_serial==serial,"wrong deployment spends no product or shipment token")
	ship(s,"industry_power","generator_set"); ship(s,"industry_power","heat_recovery"); ship(s,"industry_depot","fuel_can"); ship(s,"industry_clinic","copper_wire")
	check(p.products.is_empty() and p.worlds.get_world().industry.stock.fuel_kg==0.05,"actual produced items deploy exactly once")
	act(s,"step_world"); var pre=p.serialize(); act(s,"deploy",{"world_id":"home","site_id":"industry_homes","recipe":"copper_wire","token":serial})
	check(Same.same(pre,p.serialize()),"stale shipment is side-effect free")
	act(s,"fork"); act(s,"select",{"world_id":"home"}); act(s,"fork")
	check(p.worlds.can_step_pair(),"two same-start industry forks can be compared")
	var home=p.worlds.get_world("home").duplicate(true); ship(s,"industry_factory","aluminum_wire_mass"); act(s,"step_pair")
	check(Same.same(home,p.worlds.get_world("home")) and p.products.is_empty(),"trial allowance and paired ticks do not alter career world or inventory")
	check(p.worlds.get_world("trial_a").industry.elapsed==40 and p.worlds.get_world("trial_b").industry.elapsed==40,"paired industrial times advance together")
	var loaded=Program.new(); var data=p.serialize()
	check(loaded.restore(JSON.parse_string(JSON.stringify(data)),s) and equivalent(data,loaded.serialize()),"full chapter evidence, worlds, histories and ledgers round-trip")
	act(s,"reset_trial"); check(p.worlds.get_world().industry.elapsed==30,"reset returns to matching saved baseline")
	act(s,"reset_trial",{"fresh":true,"era":"ww2"}); check(p.worlds.get_world().industry.era=="ww2" and not p.worlds.can_step_pair(),"different eras remain valid independent experiments, not same-condition comparisons")
	for version in ["v011","v012","v0121","v013","v014","v015"]:
		var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planet_"+version+".json")); var upgraded=Program.new()
		check(upgraded.restore(legacy,s),"real "+version+" fixture migrates")
		check(not upgraded.worlds.get_world().industry.enabled and upgraded.serialize().version==10,"old saves add dormant industry without consuming supplies: "+version)
	s.close_science()
	print("INDUSTRY: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
