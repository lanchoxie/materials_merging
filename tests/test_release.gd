extends SceneTree
const Fixtures=preload("res://tests/fixtures_v09.gd")
const State = preload("res://scripts/lab_state.gd")
var checks=0
var failures: Array=[]
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var s=State.new()
	s.coins=10000
	s.upgrades=20
	s.engineers=3
	s.campus.setup(3,3)
	s._sync_campus_counts()
	var work=s.sandbox_from_baseline("water")
	# Recognition follows topology, not an untrusted baseline label or atom order.
	work.atoms=["H","O","H"]
	work.positions=[work.positions[1],work.positions[0],work.positions[2]]
	work.bonds=[[0,1,1],[1,2,1]]
	var info=s.sandbox_reference(work)
	check(info.known and info.reference_id=="water","permuted topology recognized")
	work.bonds=[]
	check(not s.sandbox_reference(work).known,"disconnected composition is not water")
	work=s.sandbox_from_baseline("water")
	work.mode="art"
	check(not s.sandbox_reference(work).known,"art cannot claim reference")
	work.mode="science"
	work.periodic=true
	check(not s.sandbox_reference(work).known,"arbitrary periodic geometry cannot claim molecular reference")
	work=s.sandbox_from_baseline("methane")
	s.element_inventory.C=0
	var before=s.coins
	var old=s.reactors[0].duplicate(true)
	var inventory=s.element_inventory.duplicate(true)
	s.apply_sandbox_to_reactor(0,work)
	check(s.coins==before and s.reactors[0]==old and s.element_inventory==inventory,"insufficient atoms transaction atomic")
	s.element_inventory.C=2
	s.element_inventory.H=20
	var q=s.sandbox_reactor_quote(0,work)
	check(q.required=={"C":1,"H":2},"reuse original atoms by species count only")
	s.apply_sandbox_to_reactor(0,work)
	check(s.coins==before-s.edit_cost(old),"one fixed edit charge")
	check(s.element_inventory.C==1 and s.element_inventory.H==18,"new atoms consumed exactly once")
	Fixtures.install(s)
	check(s.reference_id(s.reactors[0])=="methane","custom methane produces known stock")
	before=s.coins
	s.apply_sandbox_to_reactor(0,work)
	check(s.coins==before,"identical apply is free")
	work.bonds=[]
	work.name="我的像素样品"
	s.apply_sandbox_to_reactor(0,work)
	Fixtures.install(s)
	for n in range(240): s.tick(1)
	s.harvest(0)
	Fixtures.offer(s)
	check(s.storage.batch(s.signature(s.reactors[0])).quantity>=3,"unknown custom structure produces display samples")
	check(not s.delivery_quote(0).ready and s.delivery_quote(0).payment==0,"unknown refused for science order")
	Fixtures.offer(s,"water","exhibition")
	check(s.market.visitors[0].order.get("property","")=="exhibition","creative curator offers exhibition order")
	q=s.delivery_quote(0)
	check(q.ready and q.payment==18 and not q.premium,"curator buys custom sample with no premium")
	var catalysts=s.upgrades
	s.deliver(0)
	check(s.upgrades==catalysts and not s.visitor_available(),"no catalyst exploit; visitor departs")
	before=s.coins
	s.deliver(0)
	check(s.coins==before,"cooldown blocks repeated sale")
	var original_id=s.reactors[0].id
	var original_stock=s.reactors[0].stock
	s.move_building(4,3)
	check(s.plots[4].kind=="empty" and s.plots[3].rid==0 and s.reactors[0].plot==3,"building and plot pointers moved together")
	check(s.reactors[0].id==original_id and s.reactors[0].stock==original_stock,"move retains identity and stock")
	s.place_decoration(4,"sculpture")
	check(s.plots[4].kind=="empty","sculpture requires quest")
	s.deliveries=3
	s.place_decoration(4,"sculpture")
	check(s.plots[4].kind=="sculpture","quest unlocks sculpture")
	s.save_game("res://saves/release-test-save.json")
	var loaded=State.new()
	check(loaded.load_game("res://saves/release-test-save.json"),"custom reactor and decorations reload")
	check(loaded.reactors[0].atoms==s.reactors[0].atoms and loaded.reactors[0].bonds==[],"save preserves arbitrary topology")
	check(Fixtures.same(loaded.market.serialize(),s.market.serialize()),"visit timing survives reload")
	# Actual asynchronous computation must not change sample or charge coins.
	s.change_template(0,"water")
	Fixtures.install(s)
	s.unlock_science_method("empirical_ho")
	old=s.reactors[0].duplicate(true)
	before=s.coins
	s.run_science_task("empirical_ho",0)
	check(not s.science_pending.is_empty(),"task enters pending state")
	for n in range(1000):
		s.poll_science()
		if s.science_pending.is_empty(): break
		await create_timer(0.01).timeout
	check(s.science_runs.size()==1 and s.science_runs[0].result.success,"real threaded optimization completes")
	check(s.coins==before and s.reactors[0]==old,"calculation does not mutate reactor")
	check(s.run_science_task("empirical_ho",0).contains("缓存"),"same method and input reuse cache")
	s.reactors[0].positions[1][0]+=0.15
	check(s.apply_science_result(0).contains("过期"),"stale optimization cannot overwrite edited structure")
	s.save_game("res://saves/research-test-save.json")
	check(loaded.load_game("res://saves/research-test-save.json") and loaded.science_runs.size()==1,"computed result schema survives save")
	s.run_science_task("empirical_ho",0)
	s.cancel_science()
	for n in range(1000):
		s.poll_science()
		if s.science_pending.is_empty(): break
		await create_timer(0.01).timeout
	check(s.science_runs.size()==1 and s.science_pending.is_empty(),"cancelled worker safely discards result")
	s.close_science()
	print("RELEASE CHECKS: %d passed / %d total" % [checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)
