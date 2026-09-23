extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Ecology=preload("res://scripts/planet_ecology.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func sample(s,id: String) -> String:
	var batch=s.product_snapshot(s._new_reactor(3,id,0)); s.storage.add_product(batch,2); return batch.id
func act(s,action: String,data: Dictionary={}) -> String:
	return s.planet.command(s,action,data)
func deploy(s,recipe: String,site: String,token: int=-1) -> String:
	return act(s,"deploy",{"world_id":s.planet.worlds.active_id,"site_id":site,"recipe":recipe,"token":s.planet.shipment_serial if token<0 else token})
func make(s,id: String) -> void:
	var info=s.planet.recipe(id); act(s,"buy_feed",{"input":info.input}); act(s,"pack",{"recipe":id}); s.planet.tick(info.seconds)
func run_for(e,eco: Dictionary,seconds: int,start: int=0) -> void:
	for at in range(start+1,start+seconds+1): e.step(eco,at)
func supply(e,eco: Dictionary,id: String) -> void:
	e.deploy(eco,id,"oxygen_station"); e.deploy(eco,id,"oxygen_cartridge")
func _initialize() -> void:
	var e=Ecology.new(); var treated=e.fresh(); var control=e.fresh()
	check(e.valid(treated,0),"initial ecology validates")
	supply(e,treated,"microbe"); supply(e,treated,"fish")
	var earliest=treated.history[0].duplicate(true)
	run_for(e,treated,60); run_for(e,control,60)
	var m=treated.regions.microbe; var f=treated.regions.fish
	check(m.sensitive<control.regions.microbe.sensitive-35,"same oxygen intervention visibly harms sensitive mat")
	check(f.bay>control.regions.fish.bay+5,"same oxygen intervention enables existing fish to return")
	check(f.dead==0 and is_equal_approx(f.bay+f.outer,24),"open migration conserves fish without spawning")
	check(m.gas==0 and m.energy==0 and m.loaded==m.used,"supply and energy are finite and fully accounted")
	check(m.refuge>0 and m.sensitive<40,"isolated refuge retains survivors despite main mat decline")
	check(Same.same(earliest,treated.history[0]),"historical snapshot never aliases living state")
	var before_oxygen=m.oxygen; run_for(e,treated,20,60)
	check(m.oxygen<before_oxygen and m.gas==0,"empty equipment cannot produce free oxygen")
	var min_cover=m.sensitive; run_for(e,treated,240,80)
	check(e.valid(JSON.parse_string(JSON.stringify(treated)),320),"ecology and full history survive JSON roundtrip")
	check(m.sensitive==min_cover,"sealed refuge does not teleport colonies into empty main pool")
	e.control(treated,"microbe","refuge"); run_for(e,treated,100,320)
	check(m.sensitive>min_cover+10,"reopening surviving refuge after oxygen falls allows recolonization")
	var trapped=e.fresh(); trapped.regions.fish.gate_open=false
	run_for(e,trapped,60)
	check(trapped.regions.fish.dead>0 and trapped.regions.fish.outer==18,"closed channel makes sustained hypoxia harm trapped fish")
	check(is_equal_approx(trapped.regions.fish.bay+trapped.regions.fish.outer+trapped.regions.fish.dead,24),"mortality transfers cohorts to loss ledger")
	var dead=trapped.regions.fish.dead; supply(e,trapped,"fish"); run_for(e,trapped,60,60)
	check(trapped.regions.fish.dead>=dead and trapped.regions.fish.bay<=6-dead+0.00001,"oxygen cannot resurrect dead fish or pass closed gate")
	var no_refuge=e.fresh(); no_refuge.regions.microbe.sealed=false; supply(e,no_refuge,"microbe")
	for cycle in range(4):
		if cycle>0: e.deploy(no_refuge,"microbe","oxygen_cartridge")
		run_for(e,no_refuge,60,cycle*60)
	check(no_refuge.regions.microbe.sensitive==0 and no_refuge.regions.microbe.refuge==0,"long exposure can remove both sensitive populations")
	run_for(e,no_refuge,360,240)
	check(no_refuge.regions.microbe.sensitive==0,"extinct sensitive population does not spontaneously return")
	var switched=e.fresh(); supply(e,switched,"fish"); switched.regions.fish.enabled=false; run_for(e,switched,10)
	check(switched.regions.fish.gas==60 and switched.regions.fish.used==0,"power switch stops consumption")
	var slow=e.fresh(); supply(e,slow,"fish"); slow.regions.fish.flow=0.5; run_for(e,slow,60)
	check(slow.regions.fish.gas==30,"low flow prolongs finite supply")
	var fast=e.fresh(); supply(e,fast,"fish"); fast.regions.fish.flow=2.0; run_for(e,fast,30)
	check(fast.regions.fish.gas>0 and fast.regions.fish.trips>0 and fast.regions.fish.loaded==fast.regions.fish.used+fast.regions.fish.gas,"high flow now needs thermal management and preserves remaining supply")
	check(not e.can_deploy(slow,"fish","oxygen_station") and not e.can_deploy(slow,"fish","oxygen_cartridge"),"no duplicate device or unneeded refill")
	check(not e.can_deploy(e.fresh(),"fish","oxygen_cartridge"),"cartridge requires installed equipment")
	run_for(e,control,650,60)
	check(control.history.size()==120,"history has a fixed memory budget")
	var s=State.new(); s.coins=5000; var p=s.planet
	act(s,"join"); var water=sample(s,"water")
	act(s,"qualify",{"reference":"oxygen","batch_id":water})
	check(not p.qualified_for("oxygen") and s.storage.batch(water).quantity==2,"water's bound oxygen cannot qualify as O2")
	var oxygen=sample(s,"oxygen"); act(s,"qualify",{"reference":"oxygen","batch_id":oxygen})
	check(p.qualified_for("oxygen") and s.storage.batch(oxygen).is_empty() and not p.qualified,"O2 qualification is independent of water and consumes two samples")
	make(s,"oxygen_station"); make(s,"oxygen_cartridge")
	check(p.available_products()==0 and p.available_products("oxygen_station")==1 and p.products.size()==2,"industrial products preserve distinct identities")
	var stock=p.serialize(); var wallet=s.coins
	deploy(s,"oxygen_cartridge","fish"); deploy(s,"oxygen_station","deep")
	check(Same.same(stock,p.serialize()) and wallet==s.coins,"wrong-site and missing-equipment transactions are atomic")
	var token=p.shipment_serial; deploy(s,"oxygen_station","fish",token); deploy(s,"oxygen_station","microbe",token)
	check(p.available_products("oxygen_station")==0 and p.worlds.get_world().ecology.regions.fish.device and not p.worlds.get_world().ecology.regions.microbe.device,"replayed installation cannot create a second device")
	deploy(s,"oxygen_cartridge","fish"); p.observing=true; p.tick(13)
	check(p.worlds.get_world().ecology.regions.fish.gas==47,"career device consumes actual manufactured charge")
	var saved=JSON.parse_string(JSON.stringify(p.serialize())); var restored=Program.new()
	check(restored.restore(saved,s) and Same.same(restored.serialize(),saved),"working ecology, evidence and inventory restore exactly")
	restored.observing=true; restored.tick(10); p.tick(10)
	check(Same.same(restored.serialize(),p.serialize()),"restored experiment continues deterministically")
	act(s,"fork",{"dry":true}); deploy(s,"oxygen_station","microbe"); deploy(s,"oxygen_cartridge","microbe")
	act(s,"fork",{"dry":true}); deploy(s,"oxygen_station","fish"); deploy(s,"oxygen_cartridge","fish")
	for i in range(6): act(s,"step_pair")
	check(p.worlds.can_step_pair() and p.worlds.get_world("trial_a").seconds==60,"paired intervention worlds retain matched baseline and time")
	check(p.worlds.get_world("trial_a").ecology.regions.microbe.sensitive<p.worlds.get_world("trial_b").ecology.regions.microbe.sensitive,"placement creates causally distinct ecology branches")
	check(s.coins==wallet and p.products.is_empty(),"trial virtual inputs cannot alter career wallet or stock")
	var parent=p.worlds.get_world("home").duplicate(true); act(s,"reset_trial")
	check(Same.same(parent,p.worlds.get_world("home")) and p.worlds.get_world().eco_allowance.oxygen_station==2,"reset replaces trial supply only")
	act(s,"buy_feed",{"input":"oxygen_feed"}); act(s,"pack",{"recipe":"oxygen_cartridge"}); p.tick(7)
	var retuned=Program.new(); retuned.config.recipes.oxygen_cartridge.fee=15; retuned.config.recipes.oxygen_cartridge.seconds=30
	check(retuned.restore(JSON.parse_string(JSON.stringify(p.serialize())),s) and retuned.job.left==18 and retuned.job.fee==10,"new price and duration leave already-paid job intact")
	retuned.tick(18); check(retuned.available_products("oxygen_cartridge")==1,"reserved work completes at original promised time after balance update")
	var paid=s.coins; var left=p.input_count("oxygen_feed"); act(s,"cancel_pack"); act(s,"cancel_pack")
	check(p.input_count("oxygen_feed")==left+1 and paid==s.coins,"cancel returns correct reserved input once")
	var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planet_v011.json")); var migrated=Program.new()
	check(migrated.restore(legacy,s),"genuine v0.11 fixture migrates")
	check(migrated.products.size()==1 and migrated.job.left==18 and migrated.worlds.get_world("trial_b").zones[1].water==1,"migration preserves stock, work progress and old water worlds")
	check(migrated.worlds.can_step_pair() and not migrated.qualified_for("oxygen") and migrated.input_count("oxygen_feed")==0,"migration preserves matching baselines without granting industrial goods")
	migrated.tick(18); check(migrated.available_products()==2,"old reserved job completes once after migration")
	var valid=p.serialize()
	for key in ["gas","energy","oxygen","loaded","used"]:
		var bad=valid.duplicate(true); bad.worlds.worlds[0].ecology.regions.fish[key]=-1
		check(not Program.new().restore(bad,s),"reject invalid ecology ledger: "+key)
	var bad=valid.duplicate(true); bad.worlds.worlds[0].ecology.regions.fish.bay=24
	check(not Program.new().restore(bad,s),"reject population duplication")
	bad=valid.duplicate(true); bad.worlds.worlds[0].ecology.regions.fish.gas+=1
	check(not Program.new().restore(bad,s),"reject gas unbacked by loaded supply")
	bad=valid.duplicate(true); bad.extra_qualifications.oxygen.work=valid.qualification.get("work",{})
	check(not Program.new().restore(bad,s),"reject forged oxygen proof")
	bad=valid.duplicate(true); bad.worlds.worlds[1].base.ecology.regions.microbe.oxygen=77
	check(not Program.new().restore(bad,s),"ecology contributes to baseline identity")
	bad=valid.duplicate(true); bad.worlds.worlds[0].ecology.history[0].regions.fish.dead=999
	check(not Program.new().restore(bad,s),"replay snapshots are validated too")
	var path="res://saves/ecology-test.json"; s.save_game(path); var s2=State.new()
	check(s2.load_game(path) and Same.same(s2.planet.serialize(),s.planet.serialize()),"complete island save includes ecology and recipes")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	s.close_science(); s2.close_science()
	print("ECOLOGY: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
