extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Lab=preload("res://scripts/material_lab.gd")
const Ecology=preload("res://scripts/planet_ecology.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func act(s,action: String,data: Dictionary={}) -> String:
	return s.planet.command(s,action,data)
func deploy(s,id: String,site: String="fish",token: int=-1) -> void:
	act(s,"deploy",{"world_id":s.planet.worlds.active_id,"site_id":site,"recipe":id,"token":s.planet.shipment_serial if token<0 else token})
func make(s,id: String) -> void:
	var info=s.planet.recipe(id); act(s,"buy_feed",{"input":info.input}); act(s,"pack",{"recipe":id}); s.planet.tick(info.seconds)
func component(lab,id: String) -> Dictionary:
	return {"id":0,"recipe":id,"recipe_version":1,"source_batch":lab.proof(str(lab.data.designs[id].mode)).batch_id}
func run_fixture(e,id: String,seconds: int=30) -> Dictionary:
	var site="microbe" if id.ends_with("compact") else "fish"
	var eco=e.fresh(); e.deploy(eco,site,"oxygen_station"); e.deploy(eco,site,"oxygen_cartridge")
	if not id.is_empty(): e.deploy(eco,site,id,component(e.thermal.lab,id))
	eco.regions[site].flow=2.0
	for i in range(seconds): e.step(eco,i+1)
	return eco
func _initialize() -> void:
	var lab=Lab.new(); var cc=lab.design("copper_compact"); var ac=lab.design("aluminum_compact")
	var cl=lab.design("copper_light"); var al=lab.design("aluminum_light")
	check(is_equal_approx(cc.mass_kg,0.0896) and is_equal_approx(ac.mass_kg,0.027),"same geometry masses use SI density")
	check(is_equal_approx(cc.conductance_W_K,0.4) and is_equal_approx(ac.conductance_W_K,0.235),"one dimensional analytic conductance")
	check(is_equal_approx(cc.heat_flow_W,0.8) and is_equal_approx(ac.heat_flow_W,0.47),"heat flow uses explicit 2 K boundary")
	check(is_equal_approx(cl.mass_kg,0.054) and is_equal_approx(al.mass_kg,0.054),"equal mass comparison conserves specified mass")
	check(cc.conductance_W_K>ac.conductance_W_K and al.conductance_W_K>cl.conductance_W_K,"design constraint reverses material preference")
	check(is_equal_approx(cl.area_m2,0.054/896) and is_equal_approx(al.area_m2,0.0002),"equal mass changes cross section explicitly")
	check(is_equal_approx(cc.assembly_conductance_W_K,1.0/4.5),"contact and external resistances add in series")
	check(lab.calculate("unseen","same_size").is_empty() and lab.calculate("copper","hotter").is_empty(),"unsupported materials and conditions do not fabricate properties")
	check(lab.data.materials.copper.heat_capacity_J_kgK==null and lab.data.materials.aluminum.toxicity==null,"unknown properties remain null")
	check(lab.valid_report(JSON.parse_string(JSON.stringify(lab.proof("same_mass"))),"same_mass"),"report persists source and model with SI results")
	var bad=lab.proof("same_size"); bad.copper.conductance_W_K=99
	check(not lab.valid_report(bad,"same_size"),"reject forged calculation evidence")
	check(lab.fits("copper_compact","microbe") and not lab.fits("copper_compact","fish"),"mass limit excludes heavy compact copper from fish bay")
	check(lab.fits("aluminum_light","fish") and not lab.fits("aluminum_light","microbe"),"slot limit excludes wide aluminum from narrow microbe mount")
	var e=Ecology.new(); var bare=run_fixture(e,""); var copper=run_fixture(e,"copper_compact"); var aluminum=run_fixture(e,"aluminum_compact")
	check(bare.regions.fish.trips>0 and bare.regions.fish.gas>0,"unassisted high flow triggers finite cooling stop")
	check(copper.regions.microbe.trips==0 and copper.regions.microbe.gas==0,"compact copper supports complete high flow cycle")
	check(aluminum.regions.microbe.trips>0 and aluminum.regions.microbe.used<copper.regions.microbe.used,"compact aluminum choice has observable interruption")
	var copper_light=run_fixture(e,"copper_light"); var aluminum_light=run_fixture(e,"aluminum_light")
	check(copper_light.regions.fish.trips>0 and aluminum_light.regions.fish.trips==0,"equal weight reverses device outcome too")
	check(e.valid(copper,30) and e.valid(aluminum,30),"module heat and every replay snapshot validate")
	var r=aluminum.regions.microbe; var gas=r.gas; var heat=r.heat
	e.step(aluminum,31)
	check(r.gas==gas and r.energy==gas and r.heat<heat,"cooling consumes neither gas nor electrical charge")
	for i in range(32,60): e.step(aluminum,i)
	check(r.gas==0 and r.loaded==r.used,"hysteresis resumes and finishes finite cartridge")
	var s=State.new(); s.coins=9000; var p=s.planet; var before=p.serialize()
	act(s,"compare_materials",{"mode":"same_size"})
	check(Same.same(before,p.serialize()),"cooperation required before record")
	act(s,"join"); var money=s.coins
	act(s,"compare_materials",{"mode":"same_size"}); act(s,"compare_materials",{"mode":"same_mass"})
	check(p.reports.size()==2 and s.coins==money and not p.qualified and not p.qualified_for("oxygen"),"supplier reference does not grant molecular discovery or consume money")
	var source=s.product_snapshot(s._new_reactor(3,"oxygen",0)); s.storage.add_product(source,2); act(s,"qualify",{"reference":"oxygen","batch_id":source.id})
	for id in ["oxygen_station","copper_light","aluminum_light"]: make(s,id)
	check(p.products.size()==3 and p.available_products("copper_light")==1,"reference-qualified kit follows normal paid manufacturing")
	before=p.serialize(); deploy(s,"copper_light")
	check(Same.same(before,p.serialize()),"missing device rejects component without stock loss")
	deploy(s,"oxygen_station"); deploy(s,"copper_light")
	var old=p.worlds.get_world().ecology.regions.fish.component.duplicate(true); var token=p.shipment_serial
	deploy(s,"aluminum_light","fish",token); deploy(s,"aluminum_light","fish",token)
	check(p.available_products("copper_light")==1 and p.available_products("aluminum_light")==0,"replacement returns old component exactly once")
	check(Same.same(old,p.products[0]),"returned component preserves serial and reference provenance")
	before=p.serialize(); deploy(s,"aluminum_light")
	check(Same.same(before,p.serialize()),"same component cannot be redundantly installed")
	var restored=Program.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(before)),s) and Same.same(restored.serialize(),before),"installed and stored components restore atomically")
	var invalid=before.duplicate(true); invalid.products.append(invalid.worlds.worlds[0].ecology.regions.fish.component.duplicate(true))
	check(not Program.new().restore(invalid,s),"career component cannot exist both on device and in stock")
	var wallet=s.coins; var stock=p.products.duplicate(true)
	act(s,"fork"); deploy(s,"aluminum_compact")
	check(p.worlds.get_world().eco_allowance.aluminum_light==3,"trial returns copied baseline component to virtual stock")
	check(s.coins==wallet and Same.same(stock,p.products),"trial component swaps cannot import or export career stock")
	check(Program.new().restore(JSON.parse_string(JSON.stringify(p.serialize())),s),"virtual inventory includes baseline components in conservation")
	invalid=p.serialize(); invalid.worlds.worlds[1].eco_allowance.aluminum_light+=1
	check(not Program.new().restore(invalid,s),"reject duplicated virtual modules")
	act(s,"reset_trial")
	check(p.worlds.get_world().ecology.regions.fish.component.recipe=="aluminum_light" and p.worlds.get_world().eco_allowance.aluminum_light==2,"reset restores baseline component and fresh isolated budget")
	var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planet_v012.json")); var upgraded=Program.new()
	check(upgraded.restore(legacy,s),"actual v0.12 fixture migrates")
	check(upgraded.products.size()==1 and upgraded.job.left==18 and upgraded.worlds.get_world("home").ecology.regions.fish.gas==47,"migration preserves items, reserved work, oxygen and charge")
	check(upgraded.worlds.can_step_pair() and upgraded.reports.is_empty() and upgraded.supplies.copper_kit==0,"migration preserves matched baselines without inventing material purchases")
	check(upgraded.worlds.get_world("home").ecology.history.size()==3 and upgraded.worlds.get_world("home").ecology.history[2].regions.fish.heat==0,"migration supplies neutral thermal fields throughout history")
	invalid=legacy.duplicate(true); invalid.worlds.worlds[1].base.ecology.regions.fish.gas-=1
	check(not Program.new().restore(invalid,s),"old corrupted baseline is rejected before migration")
	invalid=p.serialize(); invalid.worlds.worlds[0].ecology.regions.fish.heat=-1
	check(not Program.new().restore(invalid,s),"reject negative thermal load")
	invalid=p.serialize(); invalid.reports.same_size.source="made_up"
	check(not Program.new().restore(invalid,s),"reject source substitution")
	invalid=p.serialize(); invalid.worlds.worlds[0].ecology.regions.fish.erase("device")
	check(not Program.new().restore(invalid,s),"missing device field is rejected without validation exception")
	s.close_science(); print("MATERIAL LAB: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
