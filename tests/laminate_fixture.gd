extends RefCounted
static func act(s,action: String,data: Dictionary={}) -> String: return s.planet.command(s,action,data)
static func specimen(s,cu: int=2,al: int=1) -> String:
	var work=s.new_sandbox_structure("铜铝投料 %d:%d" % [cu,al])
	for i in range(cu+al): s.sandbox_add_atom(work,"Cu" if i<cu else "Al",[float(i)*1.6,0.0,0.0])
	var id="laminate-test-%d-%d" % [cu,al]
	s.storage.add_product({"id":id,"name":work.name,"formula":s.sandbox_formula(work),"reference":"","quality":0.0,"work":work},2)
	act(s,"archive_material",{"batch_id":id}); return s.planet.materials.identity(work)
static func campus(s) -> void:
	s.coins=20000; s.materials=[10000,10000,10000]; s.campus.rng.seed=194
	for entry in [[3,"workshop"],[5,"institute"],[7,"doctor_dorm"],[0,"professor_apartment"]]:
		if not s.plots[entry[0]].unlocked: s.buy_plot(entry[0])
		s.campus_build(entry[0],entry[1]); s.campus_road(entry[0])
	s.campus_hire("doctor"); s.campus_hire("doctor"); s.campus_hire("professor")
	s.campus_assign_post(s.campus.people[0].id,"workshop"); s.campus.elapsed=100
static func research(s) -> bool:
	act(s,"laminate_research")
	for i in range(1800):
		if s.planet.laminates.unlocked(s): return true
		s.tick(1)
	return false
static func design(s,rid: String,orientation: String="parallel",mode: String="same_size") -> String:
	act(s,"propose_laminate",{"record_id":rid,"orientation":orientation,"mode":mode})
	var d=s.planet.laminates.model.build(rid,s.planet.laminates.model.counts(s.planet.materials.records[rid].work),orientation,mode)
	return d.id
static func buy(s) -> void:
	act(s,"laminate_buy",{"element":"Cu"}); act(s,"laminate_buy",{"element":"Al"})
static func make(s,id: String) -> void:
	buy(s); act(s,"laminate_pack",{"design_id":id}); s.planet.tick(48,1)
static func visitor(s,order_id: String="compact",arrive: bool=true) -> Dictionary:
	s.market.visitors.clear()
	var rules=s.island_rules.visitors.duplicate(true); rules.material_every=1; rules.material_slot=0
	s.market.spawn(s.economy,s.templates,rules,[s.contracts.request(order_id)])
	var v=s.market.visitors[-1]
	if arrive: s.market.tick(float(rules.arrival_seconds),s.economy,s.templates,rules)
	return v
static func sell(s,id: String,order_id: String) -> String:
	var v=visitor(s,order_id)
	return act(s,"laminate_deliver",{"design_id":id,"visitor_id":v.id})
