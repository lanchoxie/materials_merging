extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Fixture=preload("res://scripts/player_fixture.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func props(k: float=235,density: float=2700,resistivity=2.8264e-8) -> Dictionary:
	return {"density_kg_m3":density,"conductivity_W_mK":k,"resistivity_ohm_m":resistivity}
func act(s,action: String,data: Dictionary={}) -> String: return s.planet.command(s,action,data)
func ship(s,id: String,site: String) -> String:
	return act(s,"deploy",{"world_id":s.planet.worlds.active_id,"site_id":site,"recipe":id,"token":s.planet.shipment_serial})
func roundtrip(p,state) -> bool:
	return Program.new().restore(JSON.parse_string(JSON.stringify(p.serialize())),state)
func _initialize() -> void:
	var s=State.new(); var p=s.planet; var f=Fixture.new()
	check(f.calculate("sink","same_mass",f.unknown()).is_empty(),"unknown properties block purpose calculation rather than becoming zero")
	for value in [0,-1,NAN,INF,"2700",true]:
		var v=props(); v.density_kg_m3=value
		check(f.calculate("sink","same_mass",v).is_empty(),"invalid density rejected: "+str(value))
	var sample=s.product_snapshot(s._new_reactor(8,"water",0)); s.storage.add_product(sample,4)
	act(s,"archive_material",{"batch_id":sample.id})
	check(p.materials.records.is_empty() and s.storage.batch(sample.id).quantity==4,"archive requires joining before spending a sample")
	act(s,"join"); var coins=s.coins; act(s,"archive_material",{"batch_id":sample.id})
	var rid=str(p.materials.records.keys()[0]); var record=p.materials.records[rid]
	check(s.storage.batch(sample.id).quantity==3 and s.coins==coins,"archive consumes exactly one specimen without charging coins")
	check(record.reference=="water" and record.work==sample.work,"immutable record preserves actual structure and re-resolves reference")
	act(s,"archive_material",{"batch_id":sample.id})
	check(s.storage.batch(sample.id).quantity==3 and p.materials.records.size()==1,"duplicate collection identity does not double-debit")
	var renamed=sample.work.duplicate(true); renamed.name="同结构的新名字"
	check(p.materials.identity(renamed)==rid,"renaming a specimen does not counterfeit another structure")
	var changed=sample.work.duplicate(true); changed.positions[0][0]+=.1
	check(p.materials.identity(changed)!=rid,"changing a coordinate creates a distinct immutable structure")
	var origin=record.work.duplicate(true); sample.work.positions[0][0]+=1
	check(record.work==origin,"future source mutations cannot rewrite the archived specimen")
	var pv=props(); pv.resistivity_ohm_m=null
	act(s,"propose_material",{"record_id":rid,"kind":"sink","mode":"same_mass","properties":pv})
	var sink=str(p.materials.designs.keys()[0]); var proof=p.materials.designs[sink]
	check(proof.properties.resistivity_ohm_m==null and proof.basis=="player_hypothesis","irrelevant unknown property is retained and assumptions remain labeled")
	check(f.electrical._same(proof.result.assembly_conductance_W_K,p.lab.calculate("aluminum","same_mass").assembly_conductance_W_K),"same explicit inputs recover the existing SI reference calculation")
	var original=proof.duplicate(true); pv.conductivity_W_mK=.05
	check(p.materials.designs[sink]==original,"editing a draft does not retroactively change a saved design")
	act(s,"propose_material",{"record_id":rid,"kind":"sink","mode":"same_mass","properties":pv})
	var weak=str(p.materials.designs.keys()[-1]); check(weak!=sink,"new assumption produces a separate reproducible design ID")
	act(s,"propose_material",{"record_id":rid,"kind":"wire","mode":"same_size","properties":pv})
	check(p.materials.designs.size()==2,"wire with unknown resistivity cannot be built")
	act(s,"propose_material",{"record_id":rid,"kind":"wire","mode":"same_mass","properties":props()})
	var wire=str(p.materials.designs.keys()[-1])
	check(f.valid(JSON.parse_string(JSON.stringify(p.materials.designs[wire]))),"SI proof survives JSON tiny resistivity rounding")
	act(s,"activate_modern"); var home=p.worlds.get_world()
	check(not p.worlds.can_deploy(home.id,"modern_cooling",sink) and p.available_in(home,sink)==0,"hypothetical materials are excluded from career stock and deployment")
	var stock=s.storage.serialize(); ship(s,sink,"modern_cooling")
	check(home.modern.custom_sink.is_empty() and stock==s.storage.serialize(),"blocked career deployment has no inventory side effect")
	for item in [["modern_field","modern_silicon"],["modern_roof","modern_perovskite"],["modern_compute","modern_server"],["modern_cooling","modern_fan"]]: p.worlds.modern.deploy(home.modern,item[0],item[1])
	act(s,"fork"); var a=p.worlds.get_world(); var allowance=a.eco_allowance.duplicate(); var token=p.shipment_serial
	ship(s,sink,"modern_roof")
	check(a.modern.custom_receipts.is_empty() and token==p.shipment_serial,"wrong target does not spend trial budget or shipment token")
	ship(s,sink,"modern_cooling")
	check(a.modern.custom_sink.id==sink and a.modern.custom_receipts.size()==1 and a.eco_allowance==allowance,"valid hypothetical sink spends a separate finite placement, no standard goods")
	act(s,"deploy",{"world_id":a.id,"site_id":"modern_cooling","recipe":weak,"token":token})
	check(a.modern.custom_sink.id==sink and a.modern.custom_receipts.size()==1,"duplicate delivery token is rejected atomically")
	act(s,"select",{"world_id":"home"}); act(s,"fork"); var b=p.worlds.get_world(); ship(s,weak,"modern_cooling")
	check(p.worlds.can_step_pair(),"different material interventions retain equal experimental starting conditions")
	for i in range(7): act(s,"step_pair")
	check(a.modern.heat_J<b.modern.heat_J and a.modern.removed_heat_J>b.modern.removed_heat_J,"player thermal assumptions change actual city heat and cooling")
	check(p.worlds.modern.valid(a.modern,a.seconds) and p.worlds.modern.valid(b.modern,b.seconds),"custom devices retain closed city energy and reference material accounts")
	check(roundtrip(p,s),"archive, design receipts, two worlds and history round-trip")
	var before=p.materials.serialize(); act(s,"reset_trial")
	check(b.modern.custom_sink.is_empty() and b.modern.custom_receipts.is_empty() and before==p.materials.serialize(),"reset restores experimental baseline without deleting evidence or duplicating inventory")
	for i in range(6): ship(s,sink if i%2==0 else weak,"modern_cooling")
	check(b.modern.custom_receipts.size()==6 and p.available_in(b,sink)==0,"six placements cap repeated hypothetical replacements")
	ship(s,sink,"modern_cooling"); check(b.modern.custom_receipts.size()==6,"seventh placement is refused")
	act(s,"reset_trial",{"era":"ww1"}); var w=b.industry
	ship(s,wire,"industry_clinic")
	check(w.custom_cables.is_empty(),"low-density equal-mass conductor cannot fit a narrow clinic slot")
	ship(s,wire,"industry_factory"); check(w.custom_cables.has("factory"),"same conductor fits a larger factory conduit")
	ship(s,"generator_set","industry_power"); ship(s,"fuel_can","industry_depot"); ship(s,"industrial_feed","industry_depot")
	act(s,"step_world")
	check(w.flow.factory>0 and w.wire_loss_J>0 and p.worlds.industry.valid(w,b.seconds),"custom wire powers actual loads and dissipates losses with closed fuel accounts")
	check(roundtrip(p,s),"custom electrical installation and receipts restore")
	var bad=p.serialize(); bad.materials.designs[wire].properties.resistivity_ohm_m*=2
	check(not Program.new().restore(bad,s),"edited properties cannot retain an old design calculation or identity")
	bad=p.serialize(); bad.materials.records.erase(rid)
	check(not Program.new().restore(bad,s),"orphan design loses its structural provenance and is refused")
	bad=p.serialize(); bad.worlds.worlds[2].industry.custom_cables.factory.result.resistance_ohm*=.5
	check(not Program.new().restore(bad,s),"installed component cannot counterfeit its design resistance")
	bad=p.serialize(); bad.worlds.worlds[2].industry.custom_receipts=[]
	check(not Program.new().restore(bad,s),"installed component requires matching finite delivery receipts")
	bad=p.serialize(); bad.worlds.worlds[0].modern.custom_receipts=[sink]
	check(not Program.new().restore(bad,s),"save validation rejects hypothetical career activity")
	bad=p.serialize(); bad.worlds.worlds[2].industry.erase("custom_cables")
	check(not Program.new().restore(bad,s),"current-version save cannot omit the new account fields")
	for version in ["v011","v012","v0121","v013","v014","v015","v016","v017"]:
		var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planet_"+version+".json")); var migrated=Program.new()
		check(migrated.restore(legacy,s),"historical fixture upgrades: "+version)
		check(migrated.materials.records.is_empty() and roundtrip(migrated,s),"migration introduces no invented samples and restores again: "+version)
	check(s.storage.batch(sample.id).quantity==3 and s.coins==coins,"all virtual tests leave the island economy unchanged after initial specimen cost")
	var precise=props(); precise.resistivity_ohm_m=1.23456789123456e-9
	var tiny=f.build(rid,"wire","same_size",precise)
	check(f.valid(JSON.parse_string(JSON.stringify(tiny,"",true,true))),"full-precision save codec retains small SI inputs")
	var mixed={"z":1.0}; mixed.a=2; mixed["b"]=3
	check(f.canonical(mixed)==f.canonical(JSON.parse_string(JSON.stringify(mixed))),"StringName and String keys use the same sorted identity")
	check(f.canonical({"residue":6.6613381478e-16},true)==f.canonical({"residue":6.6e-16},true),"world comparison ignores sub-micro simulation residue")
	var before_failure=p.serialize(); bad=p.serialize(); bad.materials.designs[wire].basis="measured"
	check(not p.restore(bad,s) and f.electrical._same(p.materials.serialize(),before_failure.materials),"failed restore cannot relabel a hypothesis as measurement or mutate existing archive")
	var saved_path="res://saves/test_player_materials_v018.json"
	check(s.save_game(saved_path).begins_with("已保存"),"full outer save writes real provenance and all three worlds")
	var loaded=State.new()
	check(loaded.load_game(saved_path) and loaded.planet.materials.records.size()==1 and loaded.planet.materials.designs.size()==3,"outer version19 loads actual file with complete archive")
	check(loaded.planet.worlds.get_world().industry.custom_cables.has("factory") and loaded.planet.shipment_serial==p.shipment_serial,"outer load preserves installations and one-time delivery token")
	loaded.close_science()
	s.close_science(); print("PLAYER MATERIALS: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)

