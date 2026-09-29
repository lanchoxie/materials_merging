extends SceneTree
const Model=preload("res://scripts/planet_modern.gd")
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func same(a,b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))<=maxf(1e-9,maxf(absf(float(a)),absf(float(b)))*1e-12)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not same(a[i],b[i]): return false
		return true
	return a==b
func step(m,w,n: int) -> void:
	for i in range(n): m.step(w,int(w.elapsed)+1)
func equipped(m,sink="modern_aluminum_sink") -> Dictionary:
	var w=m.fresh(0,true)
	for item in [["field","modern_silicon"],["roof","modern_perovskite"],["battery","modern_battery"],["compute","modern_server"],["cooling","modern_fan"],["cooling",sink],["recycle","modern_recycler"],["recycle","modern_scrap"]]: m.deploy(w,"modern_"+item[0],item[1])
	return w
func act(s,a: String,d: Dictionary={}) -> String: return s.planet.command(s,a,d)
func ship(s,site: String,id: String) -> void:
	act(s,"deploy",{"world_id":s.planet.worlds.active_id,"site_id":site,"recipe":id,"token":s.planet.shipment_serial})
func _initialize() -> void:
	var m=Model.new(); var w=m.fresh(0,true)
	check(m.valid(w,0),"fresh city has empty storage and closed accounts")
	var dormant=m.fresh(); var initial=dormant.duplicate(true); step(m,dormant,300)
	check(Same.same(initial,dormant),"dormant chapter does not consume, age or evolve")
	check(m.light(150)==0 and m.light(239)==0 and m.light(0)==0 and m.light(60)>m.light(80),"bounded deterministic day, cloud and night forcing")
	var stable=m.fresh(0,true); var thin=m.fresh(0,true); m.deploy(stable,"modern_field","modern_silicon"); m.deploy(thin,"modern_field","modern_perovskite")
	step(m,stable,60); step(m,thin,60)
	check(thin.solar_W>stable.solar_W,"thin-film teaching device offers more initial output on identical ground area")
	step(m,stable,4000); step(m,thin,4000)
	check(thin.panels.field.quality<stable.panels.field.quality and thin.panels.field.quality*.24<stable.panels.field.quality*.20,"accelerated teaching aging creates a later durability tradeoff, not permanent material superiority")
	check(not m.can_deploy(w,"modern_roof","modern_silicon") and m.can_deploy(w,"modern_field","modern_silicon") and m.can_deploy(w,"modern_roof","modern_perovskite"),"roof load rejects heavy standard device and accepts thin-film scenario")
	m.deploy(w,"modern_battery","modern_battery"); step(m,w,200)
	check(w.battery_J==0 and w.pv_J==0 and w.discharged_J==0 and w.load_J==0,"new battery creates no energy without solar input")
	w=equipped(m); check(not m.can_deploy(w,"modern_roof","modern_perovskite"),"new panel cannot be replaced by identical unused device")
	step(m,w,70)
	check(w.pv_J>0 and w.charged_J>0 and w.battery_J>0 and m.valid(w,70),"sun feeds actual loads and charges only remaining surplus")
	check(w.job.progress>0 and w.people[0].at=="compute","real staff arrive before computation progresses")
	var charge=w.charged_J; step(m,w,105)
	check(w.solar_W==0 and w.discharged_J>0 and w.flow.homes>0 and w.charged_J>=charge,"night uses finite earlier stored energy")
	check(w.battery_loss_J>0 and m._close(w.charged_J*.9,w.battery_J+w.discharged_J/.9),"90 percent charge and discharge efficiencies give lossy round-trip")
	check(m._close(w.compute_J,w.heat_J+w.removed_heat_J),"all compute electricity enters finite thermal balance")
	var before=w.panels.roof.quality; step(m,w,30)
	check(w.panels.roof.quality==before,"night does not apply light-exposure aging")
	m.control(w,"storage","reserve"); var energy=w.battery_J; step(m,w,10)
	check(w.discharge_W==0 and w.battery_J==energy and w.flow.homes==0,"reserve mode keeps battery untouched through darkness")
	m.control(w,"storage","off"); step(m,w,120)
	check(w.charge_W==0 and w.discharge_W==0 and w.battery_J==energy,"disabled storage neither charges nor discharges")
	var hot=m.fresh(0,true); m.deploy(hot,"modern_field","modern_silicon"); m.deploy(hot,"modern_roof","modern_perovskite"); m.deploy(hot,"modern_compute","modern_server")
	step(m,hot,145)
	check(hot.trips>0,"server without adequate cooling eventually trips")
	var prior=hot.heat_J; m.control(hot,"compute"); step(m,hot,30)
	check(hot.flow.compute==0 and hot.heat_J<prior,"paused computation preserves task but removes heat through passive exchange")
	var cu=equipped(m,"modern_copper_sink"); var al=equipped(m); step(m,cu,65); step(m,al,65)
	check(al.removed_heat_J>cu.removed_heat_J and al.heat_J<cu.heat_J,"same-mass aluminum reference improves the explicit teaching cooling mapping")
	var jobs=equipped(m); m.control(jobs,"job","cooling"); step(m,jobs,500)
	check(jobs.completed.lighting==1 and jobs.completed.cooling>0,"next task choice retains first committed lighting task")
	check(jobs.boost_until.cooling>0 and jobs.completed.lighting+jobs.completed.cooling<10,"useful task completions require finite real compute work")
	m.control(jobs,"compute"); step(m,jobs,240)
	check(jobs.boost_until.cooling<jobs.elapsed,"optimization benefit expires instead of becoming a permanent free multiplier")
	var city=equipped(m); m.control(city,"policy","circular"); m.control(city,"park"); step(m,city,700)
	check(city.park and city.park_spent==4 and city.residue>0 and city.recovered<city.scrap_used,"lossy recycling reserves actual parts for constructed park")
	var visitors=0
	for record in city.history:
		for person in record.state.people: visitors+=int(person.role=="resident" and (person.at=="park" or "park" in person.route))
	check(visitors>0,"residents physically use the completed park")
	check(m.valid(city,700),"construction, regeneration and waste all retain valid material ledgers")
	var paused=equipped(m); m.control(paused,"policy","circular"); m.control(paused,"park")
	for i in range(300):
		step(m,paused,1)
		if paused.park_progress>0: break
	m.control(paused,"park"); var progress=paused.park_progress; var reserved=paused.park_spent; step(m,paused,30)
	check(paused.park_progress==progress and paused.park_spent==reserved and reserved==4,"pausing on-site park construction preserves its one-time material reservation")
	m.control(paused,"park"); step(m,paused,70)
	check(paused.park and paused.park_spent==4,"resumed worker finishes park without charging materials again")
	var cycles=city.cycles; step(m,city,300)
	check(city.cycles==cycles and city.recovered==city.cycles*1.4,"empty waste supply cannot be recycled repeatedly")
	m.deploy(city,"modern_field","modern_perovskite")
	check(city.scrapped.modern_silicon==1 and city.scrap_added==10 and m.valid(city,1000),"replaced panel adds finite traceable waste without product duplication")
	m.deploy(city,"modern_cooling","modern_copper_sink")
	check(city.scrapped.modern_aluminum_sink==1 and city.scrap_added==11,"sink replacement also preserves old material as waste")
	var resumed=JSON.parse_string(JSON.stringify(city)); var continuous=city.duplicate(true); step(m,resumed,800); step(m,continuous,800)
	check(same(resumed,continuous) and m.valid(resumed,1800) and resumed.history.size()==60,"save/load preserves trajectories and bounded history for thirty simulated minutes")
	for field in ["battery","solar","heat","scrap","parts","panel","route","progress","jobs","history"]:
		var bad=continuous.duplicate(true)
		match field:
			"battery": bad.battery_J+=100
			"solar": bad.pv_J+=100
			"heat": bad.heat_J+=100
			"scrap": bad.scrap+=2
			"parts": bad.parts+=2
			"panel": bad.panels.roof.recipe="modern_silicon"
			"route": bad.people[0].route=["homes","compute"]; bad.people[0].task="travel"
			"progress": bad.park_spent=0
			"jobs": bad.completed.cooling+=100
			"history": bad.history[-1].at=bad.history[0].at
		check(not m.valid(bad,1800),"reject forged "+field)
	var s=State.new(); s.coins=9000; var p=s.planet; act(s,"join"); act(s,"activate_modern")
	check(p.worlds.get_world().modern.enabled and p.worlds.get_world().paused,"career chapter starts paused")
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,2); act(s,"qualify",{"batch_id":sample.id})
	act(s,"compare_materials",{"mode":"same_mass"})
	for id in ["modern_silicon","modern_battery","modern_aluminum_sink"]:
		var r=p.recipe(id); act(s,"buy_feed",{"input":r.input}); act(s,"pack",{"recipe":id}); p.tick(r.seconds)
	check(p.products.size()==3,"modern products share qualified paid finite production")
	var serial=p.shipment_serial; ship(s,"modern_roof","modern_silicon")
	check(p.products.size()==3 and serial==p.shipment_serial,"overweight roof delivery spends no inventory or transaction")
	ship(s,"modern_field","modern_silicon"); ship(s,"modern_battery","modern_battery"); ship(s,"modern_cooling","modern_aluminum_sink")
	check(p.products.is_empty() and p.worlds.get_world().modern.installed.battery,"three actual manufactured items install once")
	act(s,"step_world"); act(s,"fork"); act(s,"select",{"world_id":"home"}); act(s,"fork")
	check(p.worlds.can_step_pair(),"two copies preserve exact city baseline")
	var home=p.worlds.get_world("home").duplicate(true); ship(s,"modern_roof","modern_perovskite"); act(s,"step_pair")
	check(Same.same(home,p.worlds.get_world("home")) and p.products.is_empty(),"trial solar allocation and time do not alter career world")
	check(p.worlds.get_world("trial_a").modern.elapsed==40 and p.worlds.get_world("trial_b").modern.elapsed==40,"paired city clocks advance together")
	var loaded=Program.new(); var data=p.serialize()
	check(loaded.restore(JSON.parse_string(JSON.stringify(data)),s) and same(data,loaded.serialize()),"complete city program saves and restores with all earlier chapters")
	act(s,"reset_trial"); check(p.worlds.get_world().modern.elapsed==30,"reset returns chosen experiment to exact baseline")
	act(s,"reset_trial",{"fresh":true,"era":"modern"})
	check(p.worlds.get_world().modern.enabled and p.worlds.get_world().modern.elapsed==0 and not p.worlds.can_step_pair(),"new city starting point is not mistaken for an existing same-condition comparison")
	for version in ["v011","v012","v0121","v013","v014","v015","v016"]:
		var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planet_"+version+".json")); var upgraded=Program.new()
		check(upgraded.restore(legacy,s),"real "+version+" fixture migrates")
		check(not upgraded.worlds.get_world().modern.enabled and upgraded.serialize().version==10,"migration leaves modern chapter dormant: "+version)
	s.close_science(); print("MODERN: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
