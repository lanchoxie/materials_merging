extends SceneTree
const Fixtures=preload("res://tests/fixtures_v09.gd")
const State=preload("res://scripts/lab_state.gd")
var checks=0
var failures=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func advance(s, seconds: int) -> void:
	for i in range(seconds): s.tick(1)
func doctor(s) -> Dictionary:
	s.coins=10000
	s.campus_build(5,"institute"); s.campus_road(5)
	s.campus_build(7,"doctor_dorm"); s.campus_road(7)
	s.campus_hire("doctor"); s.campus.elapsed=(int(s.campus.elapsed/480)+1)*480+100
	return s.campus.people[-1]
func _initialize() -> void:
	var s=State.new()
	var r: Dictionary=s.reactors[0]
	s.apply_edit(0,s.templates.water.positions.duplicate(true))
	advance(s,23)
	check(r.pending==0,"first unit takes the configured production time")
	advance(s,1)
	check(r.pending==1,"completed output waits in the reactor")
	advance(s,200)
	check(r.pending==5 and s.storage.batches.is_empty(),"finite capacity with no automatic bag collection")
	var money=r.stored_coins
	advance(s,60)
	check(r.pending==5 and is_equal_approx(r.stored_coins,money) and s.total_income()==0,"full reactor stops both coins and production")
	var wallet=s.coins
	s.harvest(0)
	check(r.pending==0 and r.stock==0 and s.storage.batches[0].quantity==5,"collection transfers completed units into immutable bag batch")
	check(is_equal_approx(s.coins,wallet+money),"collection pays exactly accumulated coins")
	wallet=s.coins; var drops=s.materials.duplicate(); s.harvest(0)
	check(s.coins==wallet and s.materials==drops and s.storage.batches[0].quantity==5,"repeated collection does not duplicate coins loot or products")
	advance(s,24)
	check(r.pending==1,"emptying the buffer resumes production")
	var before=s.storage.batches[0].duplicate(true)
	var p=doctor(s)
	var coordinates=r.positions.duplicate(true)
	wallet=s.coins
	s.apply_structure_edit(0,coordinates,["S","H","H"])
	check(s.reference_id(r)=="water" and r.has("installation"),"substitution queues without changing reactor immediately")
	check(s.coins==wallet-12 and s.element_inventory.S==0,"installation reserves exact fee and element once")
	var remaining=r.installation.remaining
	s.tick(1)
	check(not p.arrived and r.installation.remaining==remaining,"walking time cannot count as installation work")
	wallet=s.coins; s.apply_structure_edit(0,coordinates,["S","H","H"])
	check(s.coins==wallet,"second submission cannot double charge pending installation")
	advance(s,50)
	check(s.reference_id(r)=="hydrogen_sulfide" and not r.has("installation"),"doctoral student reaches reactor and installs new composition")
	check(s.storage.batches[0].reference==before.reference and s.storage.batches[0].quality==before.quality and s.storage.batches[0].quantity>=before.quantity,"old products retain composition and quality after install")
	check(r.positions==coordinates,"installation never optimizes player bond lengths")
	advance(s,120)
	check(r.pending>0 and not logistics_has_rounds(s),"no dorm food means no automated collection")
	s.buy_consumable("noodles",1)
	check(s.storage.consumables.noodles==1,"shop puts food into toolbox first")
	s.supply_dorm(7,"noodles",1)
	check(s.storage.consumables.noodles==0 and s.storage.food_count(7)==1,"dorm stocking moves food without duplication")
	s.campus.elapsed=(int(s.campus.elapsed/480)+1)*480+100
	var units=s.total_harvests
	advance(s,20)
	check(s.storage.food_count(7)==0 and int(s.logistics.rounds.get(str(p.id),0))==3,"doctor eats one pack and spends one round on completed pickup")
	check(s.total_harvests>units and s.storage.batches.size()>=2,"real arrival harvests product into inventory")
	# Stop extra production and use up the three remaining rounds one delivery at a time.
	for round_index in range(3):
		r.pending=1; r.stock=1; r.progress=0
		advance(s,5)
	check(int(s.logistics.rounds.get(str(p.id),0))==0,"each successful round consumes one charge")
	r.pending=5; r.stock=5
	units=s.total_harvests; advance(s,15)
	check(s.total_harvests==units and r.pending==5,"exhausted dorm halts collection instead of silently working")
	s.harvest(0)
	check(r.pending==0 and s.total_harvests==units+5,"manual collection stays available with empty supplies")
	# Cancelling before completion restores reservations exactly once.
	s.buy_elements("O",1); wallet=s.coins; var atoms=s.element_inventory.O
	s.apply_structure_edit(0,r.positions,["O","H","H"])
	s.cancel_installation(0)
	check(s.coins==wallet and s.element_inventory.O==atoms and s.reference_id(r)=="hydrogen_sulfide","cancel restores fee and elements without changing active product")
	s.cancel_installation(0)
	check(s.coins==wallet and s.element_inventory.O==atoms,"cancel cannot refund twice")
	# Road removal interrupts actual work, restoring it resumes the queued job.
	s.apply_structure_edit(0,r.positions,["O","H","H"])
	s.store_road(4); remaining=r.installation.remaining; advance(s,15)
	check(r.installation.remaining==remaining,"disconnected reactor cannot receive installations")
	wallet=s.coins; s.campus_road(4)
	check(s.coins==wallet and s.storage.decorations.road==0,"stored roads can be reused without paying")
	advance(s,60)
	check(s.reference_id(r)=="water","reconnected road resumes installation")
	# Picking up an exploration reward and moving decorations keeps item identity.
	s.collect_find(3); s.collect_find(3)
	check(s.storage.decorations.crystal_fox==1 and "crystal_fox" in s.storage.unlocked,"3D discovery unlocks once, repeat click is harmless")
	wallet=s.coins; s.campus_prop(3,0,"crystal_fox")
	check(s.storage.decorations.crystal_fox==0 and s.coins==wallet,"discovered item places from inventory")
	s.campus_remove_prop(3,0)
	check(s.storage.decorations.crystal_fox==1 and s.coins==wallet,"storage returns object, not a coin refund")
	_test_market()
	_test_save(s)
	_test_balance()
	s.close_science()
	print("ISLAND LOOP: %d / %d passed" % [checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)
func logistics_has_rounds(s) -> bool:
	for n in s.logistics.rounds.values():
		if int(n)>0: return true
	return false
func _test_market() -> void:
	var s=State.new()
	advance(s,140)
	check(s.market.visitors.size()==3,"three independent visitors may coexist")
	var first: Dictionary=s.market.visitors[0]
	var second: Dictionary=s.market.visitors[1]
	var second_snapshot=second.duplicate(true)
	s.reactors[0].positions=s.templates.water.positions.duplicate(true)
	s.reactors[0].stock=5; s.reactors[0].pending=5; s.harvest(0)
	var rows=s.visitor_candidates(int(first.id))
	check(rows[0].ready and rows[0].premium,"mailbox ranks a ready premium batch first")
	var wallet=s.coins; var id=str(rows[0].batch_id)
	s.fulfill_order(int(first.id),id)
	check(s.coins==wallet+rows[0].payment and s.upgrades==1 and s.storage.batch(id).quantity==2,"order consumes only quoted quantity and awards one catalyst")
	check(first.phase=="leaving" and second==second_snapshot,"one sale affects only its own visitor")
	wallet=s.coins; s.fulfill_order(int(first.id),id)
	check(s.coins==wallet and s.upgrades==1,"departing visitor cannot pay twice")
	rows=s.visitor_candidates(int(second.id))
	check(not rows[0].ready and rows[0].matching,"property requirement recognizes known oxygen molecule but rejects insufficient stock")
	s.reactors[0].pending=1; s.reactors[0].stock=1; s.harvest(0)
	check(s.visitor_candidates(int(second.id))[0].ready,"collected extra unit updates property order availability")
	advance(s,360)
	check(s.market.visitors.size()<=3 and s.market.visitor(int(first.id)).is_empty(),"departure and timeout keep visitor roster bounded")
	s.close_science()
func _test_save(s) -> void:
	var path="res://saves/island-loop-test.json"
	s.buy_consumable("cola",3); s.supply_dorm(7,"cola",2)
	s.apply_structure_edit(0,s.reactors[0].positions,["S","H","H"]) # May fail if no S; make a known queued template below.
	if s.reactors[0].get("installation",{}).is_empty(): s.change_template(0,"methane")
	s.save_game(path)
	var other=State.new()
	check(other.load_game(path),"v9 save loads with island logistics and market")
	check(Fixtures.same(other.storage.serialize(),s.storage.serialize()),"products food finds and stored objects persist")
	check(Fixtures.same(other.market.serialize(),s.market.serialize()) and other.logistics.rounds==s.logistics.rounds,"visitors and unused collection rounds survive reload")
	check(Fixtures.same(other.reactors[0].installation,s.reactors[0].installation),"paid installation payload and progress persist")
	var raw=JSON.parse_string(FileAccess.get_file_as_string(path))
	var invalid=raw.duplicate(true); invalid.storage.batches[0].quantity=-1
	check(not other._validate_save(invalid),"negative product count rejected")
	invalid=raw.duplicate(true); invalid.reactors[0].installation.payload={"kind":"bad"}
	check(not other._validate_save(invalid),"invalid pending installation rejected")
	invalid=raw.duplicate(true); invalid.storage.cupboards["99999"]={"cola":2}
	check(not other._validate_save(invalid),"out-of-map cupboard rejected")
	var legacy=State.new(); legacy.reactors[0].stock=12; legacy.reactors[0].pending=4; legacy.reactors[0].stored_coins=31
	legacy.save_game(path); raw=JSON.parse_string(FileAccess.get_file_as_string(path)); raw.version=8
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
	check(other.load_game(path),"v8 migrates to new storage model")
	check(other.reactors[0].pending==4 and other.reactors[0].stored_coins==31 and other.storage.batches[0].quantity==8,"migration preserves collected stock plus pending output and coins separately")
	other.harvest(0)
	check(other.storage.batches[0].quantity==12,"migration does not duplicate already collected products")
	other.save_game(path); var count=other.storage.batches[0].quantity; other.load_game(path)
	check(other.storage.batches[0].quantity==count,"migration is not reapplied to v9 saves")
	for suffix in ["",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	other.close_science(); legacy.close_science()
func _test_balance() -> void:
	var s=State.new(); s.rng.seed=123
	var r: Dictionary=s.reactors[0]; r.positions=s.templates.water.positions.duplicate(true)
	var count=s.materials[0]+s.materials[1]+s.materials[2]
	for i in range(8):
		r.pending=1; r.stock=1; s.harvest(0)
	check(s.materials[0]+s.materials[1]+s.materials[2]>count,"eight known harvests guarantee at least one material")
	var cap=s.reactor_capacity(r)
	s.campus.unlocked_materials.append("buffer_storage")
	check(s.reactor_capacity(r)==cap+3,"buffer research grants a concrete reactor capacity improvement")
	check(s.campus.config.projects.process_control.requires.get("professor",0)==1,"professor leads a process development project")
	check(s.campus.config.projects.parallel_screening.requires.get("academician",0)==1,"academician hosts advanced screening research")
	r.pending=0; r.stock=0; r.stored_coins=0.4
	var wallet=s.coins; var next=r.positions.duplicate(true); next[1][0]+=0.02
	s.apply_edit(0,next)
	check(is_equal_approx(s.coins,wallet-12+0.4),"editing preserves even fractional accumulated coins")
	s.close_science()
