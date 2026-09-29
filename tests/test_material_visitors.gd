extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const Fixtures=preload("res://tests/laminate_fixture.gd")
const Market=preload("res://scripts/island_market.gd")
const Journey=preload("res://scripts/material_journey.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func json_copy(value): return JSON.parse_string(JSON.stringify(value,"",true,true))
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): push_error("Material visitor timeout"); quit(2))
	var s=State.new(); var p=s.planet; var c=s.contracts; var f=p.laminates
	check(Journey.next(s).index==0 and c.offers(s).is_empty(),"new player begins at cooperation and does not receive inaccessible material orders")
	Fixtures.act(s,"join"); check(Journey.next(s).route=="elements","research path points to missing elements")
	s.buy_elements("Cu",2); s.buy_elements("Al",1); check(Journey.next(s).route=="sandbox","owning both elements points to actual structure creation")
	var rid=Fixtures.specimen(s); check(Journey.next(s).route=="research","archived molar proposal points to real researcher requirements")
	Fixtures.campus(s); check(Fixtures.research(s),"actual campus completes method project for visitor tests")
	check(Journey.next(s).index==3,"completed method requires a saved design rather than silently granting a product")
	s.market.visitors.clear(); check(c.offers(s).size()==2,"two sourced material contracts become eligible")
	var standard=s.market.serialize(); var scheduling=s.island_rules.visitors.duplicate(true)
	s.market.serial=1; s.market.spawn(s.economy,s.templates,scheduling,c.offers(s))
	var v=s.market.visitors[-1]; check(c.is_material(v) and v.phase=="arriving" and v.order.contract_id=="compact","scheduled property visitor enters through normal arrival phase")
	check(c.offers(s).is_empty(),"at most one material buyer shares the plaza with other specimen buyers")
	s.market.spawn(s.economy,s.templates,scheduling,c.offers(s)); s.market.spawn(s.economy,s.templates,scheduling,c.offers(s)); s.market.spawn(s.economy,s.templates,scheduling,c.offers(s))
	check(s.market.visitors.size()==3,"all visitor types share the configured plaza capacity")
	check(s.market.request_text(v,s.templates)=="窄槽换热芯 ×1","property bubble describes an application rather than a molecule name")
	var id=Fixtures.design(s,rid); var alternative=Fixtures.design(s,rid,"series"); check(Journey.next(s).index==4,"saved design proceeds to paid production")
	Fixtures.make(s,id); Fixtures.make(s,alternative)
	check(Journey.next(s).index==5,"actual stock progresses to visitor delivery")
	var coins=s.coins; var goods=f.serialize(); s.fulfill_order(int(v.id),id)
	check(s.coins==coins and f.serialize()==goods,"arriving buyer cannot spend stock or pay remotely")
	s.market.tick(6,s.economy,s.templates,scheduling)
	var rows=s.visitor_candidates(int(v.id))
	check(rows.size()==2 and rows[0].batch_id==id and rows[0].premium and rows[0].ready,"available premium geometry ranks ahead of a merely acceptable layer")
	check(s.delivery_quote(0).has("payment"),"legacy specimen quote adapter stays valid when a property buyer is present")
	var old_reward=float(f.model.rules.orders.compact.reward); f.model.rules.orders.compact.reward=1
	check(s.visitor_candidates(int(v.id))[0].payment==85,"active buyer keeps its arrival quote across later balance changes")
	f.model.rules.orders.compact.reward=old_reward
	var snapshots=s.market.serialize(); check(Market.new().restore(json_copy(snapshots),scheduling,s.templates,c.valid_order),"mixed specimen and property arrivals serialize together")
	var tampered=json_copy(snapshots); tampered.visitors[0].order.terms.reward=900
	check(not Market.new().restore(tampered,scheduling,s.templates,c.valid_order),"changed quote terms require their original fingerprint")
	tampered=json_copy(snapshots); tampered.visitors[0].order.contract_id="unknown"
	check(not Market.new().restore(tampered,scheduling,s.templates,c.valid_order),"unknown product contracts are rejected")
	tampered=json_copy(snapshots); tampered.visitors[0].fulfilled=true
	check(not Market.new().restore(tampered,scheduling,s.templates,c.valid_order),"arriving or waiting visitor cannot claim goods already loaded")
	var sales=s.deliveries; var catalysts=s.upgrades; coins=s.coins
	Fixtures.act(s,"laminate_deliver",{"design_id":id,"order_id":"compact"})
	check(f.count(id)==1 and s.coins==coins,"old factory command no longer bypasses visit lifecycle")
	s.fulfill_order(int(v.id),id)
	check(v.phase=="leaving" and v.fulfilled and f.count(id)==0,"sale transitions buyer to departure with exactly one loaded component")
	check(s.coins==coins+85 and s.upgrades==catalysts+1 and s.deliveries==sales+1 and f.deliveries==1,"shared mailbox commits payment, crystal and both delivery totals once")
	coins=s.coins; s.fulfill_order(int(v.id),alternative)
	check(s.coins==coins and f.count(alternative)==1,"repeated click during departure cannot sell another component")
	check(c.offers(s).is_empty() and f.cooldown>0,"sale cooldown prevents immediate procurement respawn")
	var departure=s.market.serialize(); check(Market.new().restore(json_copy(departure),scheduling,s.templates,c.valid_order),"loaded departure survives reload without a second reward")
	s.market.tick(5,s.economy,s.templates,scheduling); check(s.market.visitor(int(v.id)).is_empty(),"completed vehicle departure removes the visitor")
	for i in range(4): p.tick(60,0)
	s.market.visitors.clear(); check(c.offers(s).size()==2,"procurement becomes eligible after actual cooldown")
	s.market.serial=4; s.market.spawn(s.economy,s.templates,scheduling,c.offers(s)); v=s.market.visitors[-1]
	check(v.order.contract_id=="light" and v.order.vehicle=="bicycle","later material slot alternates buyer demand and transport")
	s.market.tick(6,s.economy,s.templates,scheduling); rows=s.visitor_candidates(int(v.id))
	check(not rows[0].ready and not rows[0].matching,"unsuitable mass or size stays grey even with physical stock")
	coins=s.coins; s.fulfill_order(int(v.id),alternative); check(s.coins==coins and v.phase=="visiting","wrong-use delivery has no economic side effects")
	s.dismiss_market_visitor(int(v.id)); check(not v.fulfilled and v.phase=="leaving","dismissed vehicle leaves with no fabricated cargo")
	s.market.visitors.clear(); v=Fixtures.visitor(s,"compact",false); s.market.tick(6,s.economy,s.templates,scheduling)
	s.market.tick(240,s.economy,s.templates,scheduling); coins=s.coins; s.fulfill_order(int(v.id),alternative)
	check(v.phase=="leaving" and not v.fulfilled and s.coins==coins,"expired offer cannot pay after leaving its service window")
	s.market.visitors.clear(); v=Fixtures.visitor(s,"compact")
	var path="res://saves/material-visitors-v020.json"; s.save_game(path); var loaded=State.new()
	check(loaded.load_game(path) and loaded.contracts.is_material(loaded.market.visitor(int(v.id))),"full game restores live product contract, stock and research together")
	var bad=json_copy(JSON.parse_string(FileAccess.get_file_as_string(path))); bad.campus.unlocked_materials.erase("laminate_design")
	check(not loaded._validate_save(bad),"outer consistency requires research before material visitors")
	bad=JSON.parse_string(FileAccess.get_file_as_string(path)); bad.version=9
	check(not loaded._validate_save(bad),"legacy outer schema cannot smuggle new product visitor contracts")
	var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/game_v019.json"))
	check(loaded._validate_save(old),"real 0.19 full-game fixture remains loadable")
	var legacy=s.market.serialize(); legacy.erase("version"); legacy.visitors=[]
	check(Market.new().restore(legacy,scheduling,s.templates),"older empty market without a version migrates")
	var initial=State.new(); legacy=initial.market.serialize(); legacy.erase("version"); legacy.visitors[0].erase("fulfilled")
	check(Market.new().restore(json_copy(legacy),scheduling,s.templates),"older specimen visitor gains an unfulfilled default")
	initial.close_science(); loaded.close_science(); s.close_science()
	print("MATERIAL VISITORS: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
