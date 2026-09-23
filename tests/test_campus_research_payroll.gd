extends SceneTree
const Campus=preload("res://scripts/campus_sim.gd")
const Payroll=preload("res://scripts/campus_payroll.gd")
const State=preload("res://scripts/lab_state.gd")
var checks=0
var failures=[]
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error(message)
func _initialize() -> void:
	var sim=Campus.new(); sim.setup(0,0)
	var context={"coins":10000,"plaza_plot":0,"templates":{"hydrogen_sulfide":{},"hydrogen_chloride":{},"perovskite_chloride":{}},"buildings":[{"plot":1,"kind":"institute","connected":true,"capacity":20},{"plot":2,"kind":"doctor_dorm","connected":true,"capacity":12},{"plot":3,"kind":"academician_villa","connected":true,"capacity":2},{"plot":4,"kind":"professor_apartment","connected":true,"capacity":2}]}
	check(sim.hire("doctor",context).cost==45,"doctor is a low-cost paid role")
	check(sim.start_research("hydrogen_sulfide",context).ready,"one doctor can start introductory research")
	for n in range(4): sim.hire("doctor",context)
	sim.hire("academician",context)
	check(sim.start_research("perovskite_chloride",context).ready,"advanced research does not require professor")
	check(not sim.start_research("hydrogen_chloride",context).ready,"one academician cannot lead two simultaneous projects")
	sim.hire("academician",context)
	check(sim.start_research("hydrogen_chloride",context).ready,"second academician enables a parallel advanced project")
	var capacity=sim.research_capacity()
	check(capacity.active==2 and capacity.capacity==2,"parallel project slots reflect assigned academician leads")
	var assigned=[]
	var unique=true
	for job in sim.research_jobs:
		for id in job.team:
			if id in assigned: unique=false
			assigned.append(id)
	check(unique,"researchers cannot contribute to multiple projects")
	var job=sim.research_jobs[1]
	for id in job.team:
		var p=sim.person(id); p.activity="research"; p.arrived=true
	var base_rate=sim.research_rate(job)
	var professor_id=sim.hire("professor",context).person_id
	job.team=sim._pick_team(sim.config.projects[job.template_id],job.team)
	sim.person(professor_id).research_job=job.id
	sim._assign_supervisor(job)
	var professor=sim.person(professor_id); professor.activity="research"; professor.arrived=false
	check(is_equal_approx(sim.research_rate(job),base_rate),"professor bonus waits for arrival")
	professor.arrived=true
	check(is_equal_approx(sim.research_rate(job),base_rate*1.5),"present optional professor improves doctoral research by 50 percent")
	var lead=-1
	for id in job.team:
		if sim.person(id).role=="academician": lead=id
	sim.person(lead).arrived=false
	check(sim.research_rate(job)==0,"advanced project needs its lead on site")
	sim.dismiss(lead)
	check(sim.research_jobs[1].status=="waiting_team","departing lead pauses the project without losing progress")
	var pay=Payroll.new()
	var residents=[{"role":"doctor"},{"role":"engineer"}]
	var cfg=sim.config
	check(pay.daily_cost(residents,cfg.roles)==12,"daily budget includes each role's stipend or salary")
	var result=pay.tick(240,residents,cfg,100)
	check(not result.settled and is_equal_approx(pay.accrued,6),"wages accrue for actual elapsed employment")
	residents.pop_back()
	result=pay.tick(240,residents,cfg,100)
	check(result.settled and is_equal_approx(result.paid,8) and pay.arrears==0,"dismissal stops future accrual without erasing earned wages")
	check(pay.tick(0,residents,cfg,100).paid==0,"idle polling cannot double-pay")
	result=pay.tick(480,residents,cfg,1)
	check(result.paid==1 and is_equal_approx(pay.arrears,3),"insufficient funds never create a negative wallet")
	check(pay.work_factor(cfg)==0.75,"unpaid wages apply configured temporary work factor")
	var restored=Payroll.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(pay.serialize()))) and restored.arrears==3,"earned wages and arrears survive save")
	var paid=restored.pay_arrears(10)
	check(paid==3 and restored.work_factor(cfg)==1 and restored.pay_arrears(10)==0,"repayment restores work and cannot double debit")
	check(not restored.restore({"clock":0,"accrued":NAN,"arrears":0,"total_paid":0}),"nonfinite payroll snapshots rejected")
	var state=State.new(); state.coins=1
	for n in range(480): state.tick(1)
	check(state.coins==0 and state.payroll.arrears>6.99,"game state debits daily salary exactly once")
	state.click_energy(); state.click_energy(); state.click_energy(); state.click_energy()
	state.campus_pay_arrears()
	check(state.coins>0.99 and state.payroll.arrears==0 and state.campus.work_factor==1,"player can recover payroll with normal gameplay")
	state.close_science()
	print("Payroll and research: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
