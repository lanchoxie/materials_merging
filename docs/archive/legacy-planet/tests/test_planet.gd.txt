extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func action(s,kind: String,data: Dictionary={}) -> String:
	return s.planet.command(s,kind,data)

func sample(s,id: String="water",count: int=2) -> String:
	var r=s._new_reactor(3,id,0.0)
	var product=s.product_snapshot(r)
	s.storage.add_product(product,count)
	return product.id

func deploy(s,site: String="deep",world: String="",token: int=-1) -> String:
	return action(s,"deploy",{"world_id":s.planet.worlds.active_id if world.is_empty() else world,"site_id":site,"token":s.planet.shipment_serial if token<0 else token})

func _initialize() -> void:
	var s=State.new(); var p=s.planet
	check(not p.joined and not p.qualified and p.worlds.worlds.size()==1,"new island has a dormant world and no free products")
	var wallet=s.coins
	action(s,"pack"); deploy(s)
	check(s.coins==wallet and p.products.is_empty(),"locked commands do not debit resources")
	action(s,"join"); var feed=p.feed; action(s,"join")
	check(feed==2 and p.feed==feed,"cooperation grant is exactly once")
	for id in ["hydrogen_chloride","sodium_chloride","hydrogen","oxygen"]:
		var wrong=sample(s,id)
		action(s,"qualify",{"batch_id":wrong})
		check(not p.qualified and s.storage.batch(wrong).quantity==2,"wrong structure cannot qualify as water: "+id)
	var good=sample(s)
	var original=s.storage.batch(good).work.duplicate(true)
	action(s,"qualify",{"batch_id":good})
	check(p.qualified and s.storage.batch(good).is_empty(),"qualification consumes exactly two collected water samples")
	check(Same.same(original,p.qualification.work),"qualification keeps immutable structure evidence")
	action(s,"qualify",{"batch_id":good})
	check(p.feed==feed,"requalification cannot mint supply")
	action(s,"pack"); var paid=s.coins; var job_id=p.job.id
	action(s,"pack")
	check(p.feed==1 and s.coins==paid and p.job.id==job_id,"double start does not double-debit")
	p.tick(10)
	var snapshot=JSON.parse_string(JSON.stringify(p.serialize()))
	var restored=Program.new()
	check(restored.restore(snapshot,s),"mid-process state survives JSON roundtrip")
	restored.tick(15)
	check(restored.products.size()==1 and restored.job.is_empty(),"restored work completes once")
	restored.tick(30)
	check(restored.products.size()==1,"completed jobs do not produce again")
	p.tick(15)
	check(p.products.size()==1,"packing completes into product inventory")
	var before=p.serialize()
	deploy(s,"invalid")
	check(Same.same(before,p.serialize()),"invalid drop preserves all planet state")
	var token=p.shipment_serial
	deploy(s,"deep","home",token); deploy(s,"shelf","home",token)
	check(p.products.is_empty() and p.worlds.total(p.worlds.get_world())==1,"shipment token commits once")
	check(p.worlds.get_world().zones[0].water==0,"delivery grows water over time instead of immediate world recolor")
	p.tick(8)
	check(p.worlds.get_world().zones[0].water==0,"unobserved world is paused while workshop still advances")
	p.observing=true; p.tick(8)
	check(p.worlds.get_world().zones[0].water==1 and p.worlds.get_world().observation,"observed delivery forms visible water and observation")
	action(s,"fork",{"dry":true})
	check(p.worlds.active_id=="trial_a" and p.worlds.get_world().paused,"fork creates a paused independent experiment")
	var island_wallet=s.coins; var stock=p.products.size()
	deploy(s,"deep")
	check(s.coins==island_wallet and p.products.size()==stock and p.worlds.get_world().allowance==2,"trial deployment uses only trial allowance")
	action(s,"fork",{"dry":true})
	deploy(s,"shelf")
	check(p.worlds.can_step_pair(),"two dry forks retain common initial conditions")
	action(s,"step_pair")
	check(p.worlds.get_world("trial_a").zones[0].water==1 and p.worlds.get_world("trial_b").zones[1].water==1,"synchronized branches show different placements at equal time")
	check(p.worlds.get_world("home").zones[0].target==1,"fork mutation does not mutate source")
	check(p.worlds.worlds.size()==3,"three world slots")
	action(s,"fork"); check(p.worlds.worlds.size()==3,"world count bounded")
	var saved=p.serialize(); var loaded=Program.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(saved)),s),"fork base hashes survive JSON serialization")
	check(Same.same(saved,loaded.serialize()),"all world state survives roundtrip")
	action(s,"reset_trial"); check(p.worlds.total(p.worlds.get_world())==0 and p.worlds.get_world().allowance==3,"reset restores baseline and virtual supplies")
	check(not p.worlds.can_step_pair(),"different observation times cannot masquerade as matched comparison")
	action(s,"select",{"world_id":"trial_a"}); action(s,"reset_trial")
	check(p.worlds.can_step_pair(),"reset both returns matched experiment")
	for i in range(3): deploy(s)
	var full=p.serialize(); deploy(s,"shelf")
	check(Same.same(full,p.serialize()),"full basin cannot consume further supplies")
	action(s,"select",{"world_id":"home"}); var home=p.worlds.get_world().duplicate(true)
	action(s,"reset_trial"); check(Same.same(home,p.worlds.get_world()),"career world cannot use experiment reset")
	action(s,"pack"); var cancel_wallet=s.coins
	action(s,"cancel_pack"); action(s,"cancel_pack")
	check(p.feed==1 and s.coins==cancel_wallet,"cancel returns supply once, retaining disclosed service fee")
	var valid=p.serialize()
	for field in ["feed","serial","shipment_serial"]:
		var corrupt=valid.duplicate(true); corrupt[field]=-1
		check(not Program.new().restore(corrupt,s),"reject invalid counter "+field)
	var corrupt=valid.duplicate(true); corrupt.worlds.worlds[0].zones[0].water=99
	check(not Program.new().restore(corrupt,s),"reject water beyond delivered amount")
	corrupt=valid.duplicate(true); corrupt.qualification.work.atoms=["Na","Cl"]
	check(not Program.new().restore(corrupt,s),"forged qualified structure rejected")
	corrupt=valid.duplicate(true); corrupt.worlds.worlds[1].base_key="forged"
	check(not Program.new().restore(corrupt,s),"altered experiment baseline rejected")
	var path="res://saves/planet-test.json"
	s.save_game(path); var s2=State.new()
	check(s2.load_game(path) and Same.same(s.planet.serialize(),s2.planet.serialize()),"island save includes planet without changing state")
	var legacy=JSON.parse_string(FileAccess.get_file_as_string(path)); legacy.version=10; legacy.erase("planet")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(legacy))
	check(s2.load_game(path) and not s2.planet.joined and s2.planet.products.is_empty(),"v10 migration starts dormant world, preserves island")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	s.close_science(); s2.close_science()
	print("PLANET: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
