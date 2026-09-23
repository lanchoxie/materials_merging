extends SceneTree
const Campus=preload("res://scripts/campus_sim.gd")
const State=preload("res://scripts/lab_state.gd")
const Logistics=preload("res://scripts/island_logistics.gd")
var checks=0
var failures=[]
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func _initialize() -> void:
	var c=Campus.new(); c.rng.seed=1400; c.setup(3,2)
	var ctx={"plaza_plot":0,"coins":10000,"templates":{"hydrogen_sulfide":{}},"reactors":[{"plot":2,"build_left":50}],"reachable_plots":[0,1,2],"road_links":{0:[1],1:[0,2],2:[1]},"buildings":[{"plot":2,"kind":"workshop","capacity":1,"connected":true},{"plot":1,"kind":"institute","capacity":3,"connected":true}]}
	for i in range(2): c.assign_post(c.people[i].id,"workshop")
	c.tick(1,ctx)
	check(c.industrial_rate(ctx)==0 and c.people[0].moving,"workshop worker walks before contributing production")
	var progress=c.people[0].movement_progress; c.assign_post(c.people[0].id,"auto")
	check(c.people[0].movement_progress==progress and c.people[0].moving,"changing posts keeps the current road position")
	c.assign_post(c.people[0].id,"workshop")
	for i in range(10): c.tick(1,ctx)
	check(c.industrial_rate(ctx)>0 and c.people[0].arrived and c.people[1].activity=="idle","one-seat workshop admits exactly one arrived engineer")
	check(c.construction_factor(2)>0 and c.people[2].activity=="construct" and c.people[0].activity=="factory","distinct engineers supply distinct construction and industrial jobs")
	c.assign_post(c.people[2].id,"workshop")
	check(c.construction_factor(2)==0,"transferred construction engineer stops contributing immediately")
	ctx.buildings[0].connected=false
	check(c.industrial_rate(ctx)==0,"a disconnected workshop cannot contribute even before next resident tick")
	ctx.buildings[0].connected=true
	var rate=c.industrial_rate(ctx); c.work_factor=0.75
	check(is_equal_approx(c.industrial_rate(ctx),rate*0.75),"industrial effort observes payroll work factor")
	c.work_factor=1
	var doctor=c.people[3]; c.assign_post(doctor.id,"logistics"); c.assign_post(c.people[4].id,"research")
	var q=c.start_research("hydrogen_sulfide",ctx)
	check(q.ready and c.people[4].research_job>=0 and doctor.research_job==-1,"research selects a research doctor rather than a logistics doctor")
	c.assign_post(c.people[4].id,"logistics")
	check(c.people[4].post=="research","an active research team member cannot simultaneously transfer to collecting")
	var state=State.new(); var logi=Logistics.new()
	var orders=logi.prepare(c.people,[{"plot":2,"installation":{"left":1},"pending":0}],[0,1,2],state.storage,state.island_rules)
	check(orders.has(int(doctor.id)) and not orders.has(int(c.people[4].id)),"only eligible doctoral posts get logistics jobs")
	var saved=JSON.parse_string(JSON.stringify(c.serialize())); check(Campus.new().restore(saved),"posts and assigned research survive JSON save")
	var old=saved.duplicate(true); old.version=2
	for p in old.people: p.erase("post")
	var legacy=Campus.new(); check(legacy.restore(old) and legacy.people[0].post=="auto","previous campus saves default all residents to automatic posts")
	var bad=saved.duplicate(true); bad.people[0].post="research"; check(not Campus.new().restore(bad),"incompatible saved profession/post combination is rejected")
	var program=state.planet; state.coins=5000; program.command(state,"join")
	var sample=state.product_snapshot(state._new_reactor(3,"water",0)); state.storage.add_product(sample,2); program.command(state,"qualify",{"batch_id":sample.id})
	program.command(state,"pack"); program.command(state,"production_mode",{"mode":"island"})
	var left=program.job.left; program.tick(10,0)
	check(program.job.left==left,"island production waits indefinitely without arrived labor")
	program.tick(1,0.5); check(is_equal_approx(program.job.left,left-0.5),"actual labor rate scales only the production job")
	program.command(state,"production_mode",{"mode":"partner"}); program.tick(60,0)
	check(program.job.is_empty() and program.products.size()==1,"partner workshop completes reserved job without duplicate payment or product")
	state.campus_build(3,"workshop"); state.campus_road(3); state.campus_assign_post(state.campus.people[0].id,"workshop")
	program.command(state,"pack"); program.command(state,"production_mode",{"mode":"island"}); left=program.job.left
	state.tick(0.5); check(program.job.left==left,"actual game facade does not award work before engineer arrival")
	for i in range(15): state.tick(1)
	check(state.campus.industrial_rate(state.campus_context())>0 and program.job.left<left,"real island workshop, road and engineer advance the industrial job")
	var path="res://saves/workshop-posts-test.json"; state.save_game(path); var loaded=State.new()
	check(loaded.load_game(path) and loaded.planet.production_mode=="island" and loaded.campus.people[0].post=="workshop","outer game save restores workshop, post and in-flight order together")
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	loaded.close_science(); state.close_science(); print("WORKSHOP POSTS: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
