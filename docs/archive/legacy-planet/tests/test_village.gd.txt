extends SceneTree
const Village=preload("res://scripts/planet_village.gd")
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
func feed(m,w,rounds: int=1) -> void:
	for i in range(rounds):
		for id in ["frame_bundle","tool_chest","standard_water_crate","drinking_barrel"]:
			if m.can_deploy(w,"village_depot",id): m.deploy(w,id)
func act(s,a: String,d: Dictionary={}) -> String: return s.planet.command(s,a,d)
func make(s,id: String) -> void:
	var i=s.planet.recipe(id); act(s,"buy_feed",{"input":i.input}); act(s,"pack",{"recipe":id}); s.planet.tick(i.seconds)
func deploy(s,id: String) -> void:
	act(s,"deploy",{"world_id":s.planet.worlds.active_id,"site_id":"village_depot","recipe":id,"token":s.planet.shipment_serial})
func _initialize() -> void:
	var m=Village.new(); var w=m.fresh(0,true)
	check(m.valid(w,0),"fresh village has closed household accounts")
	w.enabled=false; check(not m.can_deploy(w,"village_depot","frame_bundle"),"dormant village rejects delivery"); w.enabled=true
	check(not m.can_deploy(w,"mill","frame_bundle"),"only the village depot accepts deliveries")
	var empty=w.duplicate(true); step(m,empty,500)
	check(empty.stock.water<2 and not empty.projects.road.complete and empty.used.water<=16,"unsupplied village exhausts farm water and cannot build from nothing")
	feed(m,w,4); m.control(w,"approve","mill"); m.control(w,"approve","market")
	var construction_waited=true; var saw_cargo=false; var saw_scaffold=false; var saw_mill=false
	for i in range(20):
		m.step(w,int(w.elapsed)+1)
		for p in w.people:
			if p.task=="build" and p.route.size()>1 and w.projects[p.project].progress>0: construction_waited=false
	check(construction_waited and w.projects.cistern.committed,"builder reserves once and walking contributes no construction")
	var active=str(w.active_project); var held=float(w.projects[active].progress)
	m.control(w,"pause",active); step(m,w,30)
	check(w.projects[active].progress==held and w.projects[active].committed and w.active_project==active,"pausing an unfinished project preserves commitment and progress")
	m.control(w,"pause",active)
	for i in range(1000):
		m.step(w,int(w.elapsed)+1)
		for p in w.people: saw_cargo=saw_cargo or not p.cargo.is_empty()
		saw_scaffold=saw_scaffold or (not w.active_project.is_empty() and w.projects[w.active_project].progress>0)
		saw_mill=saw_mill or w.mill_running
	check(saw_cargo and saw_scaffold and saw_mill,"real work produces carried goods, construction phases and turning-mill states")
	check(w.projects.road.complete and w.projects.cistern.complete and w.projects.mill.complete and w.projects.market.complete,"finite external supplies enable the complete village construction chain")
	check(w.trades>0 and w.exported.goods==2*w.trades,"local market exports goods exactly once per exchange")
	var construction_frames=0.0
	for id in w.projects: construction_frames+=float(m.rules.projects[id].inputs.frames)
	check(is_equal_approx(w.used.frames,construction_frames+w.started.craft),"pause and resume do not pay construction inputs twice")
	check(w.produced.food>empty.produced.food and empty.spring_taken>0,"supplies increase cumulative food output while unsupplied residents fetch finite spring water")
	check(m.valid(w,w.elapsed),"long run closes all job, resource and source-water ledgers")
	check(w.history.size()==60 and w.people.size()==6,"histories and visible population stay bounded")
	var resumed=JSON.parse_string(JSON.stringify(w)); check(m.valid(resumed,w.elapsed),"mid-task JSON restore accepts carried goods and commitments")
	step(m,w,90); step(m,resumed,90); check(Same.same(w,resumed),"resuming a saved village produces the identical deterministic future")
	var river=w.duplicate(true); var mill=w.duplicate(true)
	while river.diversion!=0: m.control(river,"diversion")
	while mill.diversion!=1: m.control(mill,"diversion")
	feed(m,river,3); feed(m,mill,3); step(m,river,200); step(m,mill,200)
	check(river.passage>mill.passage,"same starting village with less diversion preserves more river passage")
	check(m.valid(river,river.elapsed) and m.valid(mill,mill.elapsed),"both policy outcomes remain ledger-valid")
	var care=m.fresh(0,true); var workshop=care.duplicate(true); feed(m,care); feed(m,workshop); m.control(workshop,"policy","workshop")
	step(m,care,55); step(m,workshop,55)
	check(care.projects.cistern.committed and workshop.projects.road.committed,"community priorities produce different first construction decisions")
	for kind in ["stock","balanced_forgery","route","history","counter","impossible_pickup"]:
		var bad=w.duplicate(true)
		match kind:
			"stock": bad.stock.drink+=1
			"balanced_forgery": bad.stock.food+=1; bad.produced.food+=1
			"route": bad.people[0].route=["home","mill"]; bad.people[0].at="home"; bad.people[0].target="mill"
			"history": bad.history[-1].at=bad.history[0].at
			"counter": bad.completed.farm+=1
			"impossible_pickup": bad.people[0].task="rest"; bad.people[0].stage="pickup"
		check(not m.valid(bad,w.elapsed),"reject tampering: "+kind)
	var full=m.fresh(0,true)
	for i in range(83): m.deploy(full,"frame_bundle")
	check(not m.can_deploy(full,"village_depot","frame_bundle"),"full depot rejects another structure shipment")
	var s=State.new(); s.coins=9000; var p=s.planet
	act(s,"join"); act(s,"activate_village")
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,2); act(s,"qualify",{"batch_id":sample.id})
	for id in ["drinking_barrel","frame_bundle","tool_chest"]: make(s,id)
	check(p.products.size()==3 and p.worlds.get_world().village.enabled,"new products manufacture through existing paid workshop")
	var token=p.shipment_serial; deploy(s,"frame_bundle"); var after=p.serialize(); act(s,"deploy",{"world_id":p.worlds.active_id,"site_id":"village_depot","recipe":"frame_bundle","token":token})
	check(Same.same(after,p.serialize()),"repeated delivery token cannot duplicate a product")
	deploy(s,"drinking_barrel"); deploy(s,"tool_chest"); act(s,"step_world")
	var vw=p.worlds.get_world().village
	check(p.products.is_empty() and vw.elapsed==30 and vw.added.drink==24 and vw.added.frames==6,"actual products enter the village input ledger")
	check(Program.new().restore(JSON.parse_string(JSON.stringify(p.serialize())),s),"current program round trips with village history")
	act(s,"fork"); act(s,"select",{"world_id":"home"}); act(s,"fork")
	check(p.worlds.worlds.size()==3 and p.worlds.can_step_pair(),"two experiments cloned from the same live baseline can compare")
	var career=p.worlds.get_world("home").duplicate(true)
	act(s,"village",{"control":"policy","id":"river"}); act(s,"step_pair")
	check(Same.same(career,p.worlds.get_world("home")) and p.worlds.can_step_pair(),"paired experiments advance without changing career supplies or residents")
	act(s,"reset_trial"); check(p.worlds.get_world().village.elapsed==30,"reset restores the exact experiment baseline")
	for version in ["v0121","v013"]:
		var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/planet_"+version+".json")); var upgraded=Program.new()
		check(upgraded.restore(legacy,s),"actual "+version+" save migrates")
		check(not upgraded.worlds.get_world().village.enabled and upgraded.serialize().version==10,"legacy migration adds a dormant village without auto-spending")
	s.close_science(); print("VILLAGE: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
