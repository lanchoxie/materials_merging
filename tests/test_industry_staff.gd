extends SceneTree
## v0.35 星锻岛 staff and market: service years, seeded 延毕, the player's approval, island Ⅱ
## housing, staffed factories (speed / yield), wages and arrears, furniture (studio, apartments,
## island Ⅰ toolbox), contracts with the export airship, and the v1 → v2 save upgrade.
const State=preload("res://scripts/lab_state.gd")
const Industry=preload("res://scripts/industry.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func made(s,formula: String) -> void:
	s.index_found[Industry._keys_for(formula)[0]]=true

func _initialize() -> void:
	var R=Industry.rules()
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,800); s.coins=200000
	# --- Service years and legacy credit.
	var eng: Dictionary={}
	for p in s.campus.people:
		if p.role=="engineer": eng=p; break
	check(not eng.is_empty(),"the starting island has an engineer")
	ind.serve(s,1.0)
	var c=ind.candidates(s).filter(func(x): return x.id==int(eng.id))[0]
	check(is_equal_approx(c.years,float(R.staff.legacy_years)+1.0/ind.year_seconds()),"existing residents start with legacy service years")
	check(not c.ready and ind.promote(s,int(eng.id)).begins_with("还没到年限"),"not ready before the required years")
	# --- 延毕 is seeded and visible: find an id that rolls a delay and one that does not.
	var delayed=-1; var clean=-1
	for id in range(1,400):
		if Industry._roll(id,0.25): delayed=id if delayed<0 else delayed
		else: clean=id if clean<0 else clean
	check(delayed>0 and clean>0 and Industry._roll(delayed,0.25)==Industry._roll(delayed,0.25),"the 延毕 roll is stable per person")
	ind.service[str(int(eng.id))]=float(R.staff.roles.engineer.years)*ind.year_seconds()-1.0
	var notes=ind.serve(s,2.0)
	var key=str(int(eng.id))
	check(not notes.is_empty(),"crossing the service line produces a note (graduate or 延毕)")
	if ind.delays.has(key):
		c=ind.candidates(s).filter(func(x): return x.id==int(eng.id))[0]
		check(c.delayed and not c.ready and c.reason!="" and is_equal_approx(c.need,float(R.staff.roles.engineer.years)+1.0),"延毕 adds a year and shows its reason")
		ind.service[key]=c.need*ind.year_seconds()
	# --- Approval needs housing on island Ⅱ.
	check(ind.promote(s,int(eng.id)).contains("没有空床位"),"promotion waits for a bed in 星锻公寓")
	check(ind.build(s,0,"staff_housing").contains("建成") and ind.beds()==int(R.buildings.staff_housing.capacity),"星锻公寓 gives beds")
	var people=s.campus.people.size(); var engineers=s.engineers
	check(ind.promote(s,int(eng.id)).begins_with("已批准"),"the player approves the promotion")
	check(s.campus.people.size()==people-1 and s.engineers==engineers-1 and s.campus.person(int(eng.id)).is_empty(),"the engineer leaves island Ⅰ (a vacancy)")
	check(ind.staff.size()==1 and ind.staff[0].role=="engineer" and int(ind.staff[0].home)==0,"they move into the apartment as 高级工程师")
	# --- Staffed factory runs faster; a 研发博士 adds yield.
	ind.build(s,1,"metal_works"); made(s,"Fe3C")
	var base=ind.speed(ind.buildings["1"],1)
	check(ind.assign(int(ind.staff[0].id),1).contains("派到") and ind.speed(ind.buildings["1"],1)>base*1.29,"a senior engineer speeds the factory up by 30%")
	ind.staff.append({"id":ind.staff_serial,"name":"测试博士","role":"doctor","specialty":"","home":0,"factory":1}); ind.staff_serial+=1
	s.element_inventory["Fe"]=60; s.element_inventory["C"]=10
	for i in range(4):
		ind.start(s,1,"carbon_steel"); ind.tick(s,40.0)
	check(int(ind.items.get("steel_ingot",0))==9,"four jobs with a 研发博士 give one extra batch (8 + 1)")
	check(ind.assign(int(ind.staff[0].id),0).begins_with("只能"),"staff only work in factories")
	# --- Wages, arrears and their effect.
	s.coins=0.0
	ind._pay(s,float(R.staff.settle_seconds))
	check(ind.arrears>0.0 and ind.staff_bonus(1,"speed")==0.0,"unpaid wages pause the staff bonus")
	s.coins=10000.0; ind.pay_arrears(s)
	check(ind.arrears==0.0 and ind.staff_bonus(1,"speed")>0.0,"paying the arrears restores it")
	# --- Furniture: studio recipe, apartment comfort, island Ⅰ toolbox.
	ind.build(s,2,"home_studio"); made(s,"C2H4")
	ind.items["pe"]=10; ind.items["steel_ingot"]=5
	check(ind.start(s,2,"chair_nova").begins_with("已投料"),"the studio makes a 星环椅")
	ind.tick(s,60.0)
	check(int(ind.items.get("chair_nova",0))==1,"the chair comes out")
	var before=ind.comfort(0)
	check(ind.furnish(0,"chair_nova").contains("舒适度") and ind.comfort(0)>before,"furniture raises apartment comfort")
	ind.items["chair_nova"]=1
	check(ind.ship_home(s,"chair_nova").contains("工具箱") and int(s.storage.decorations.get("sf_chair",0))==1,"furniture can go to island Ⅰ's toolbox")
	s.planet.v2.field.stock["timber"]=6; ind.items["uf_resin"]=2
	check(ind.start(s,2,"particleboard").begins_with("已投料") and int(s.planet.v2.field.stock.timber)==3,"particleboard takes planet timber")
	# --- Contracts and the airship.
	ind.build(s,3,"trade_hub"); ind.tick(s,0.1)
	check(ind.contracts.size()==int(R.contracts.board),"the trade hub posts a contract board")
	var con: Dictionary=ind.contracts[0]
	for item in con.lines: ind.items[item]=int(ind.items.get(item,0))+int(con.lines[item])
	var coins=s.coins; var credit=ind.credits
	check(ind.deliver(int(con.id)).contains("飞艇") and not ind.airship.is_empty(),"delivering loads the airship")
	check(ind.deliver_error(int(ind.contracts[0].id)).contains("在途"),"one trip at a time")
	ind.tick(s,float(R.contracts.trip)+1.0)
	check(ind.airship.is_empty() and s.coins>=coins+float(con.coins)-0.01 and ind.credits==credit+int(con.credits),"the airship returns with coins and credits")
	check(ind.reroll(s).contains("刷新"),"the board can be rerolled for credits")
	# --- Save: v2 round trip, v1 upgrade, rejection.
	var data=JSON.parse_string(JSON.stringify(ind.serialize())); var again=Industry.new()
	check(again.restore(data) and again.staff.size()==2 and again.contracts.size()==ind.contracts.size() and again.furnished.get("0",0)==1,"v2 survives a JSON round trip")
	var old=data.duplicate(true); old.version=1
	for k in ["service","delays","service_init","staff","staff_serial","wages","wage_clock","arrears","furnished","contracts","contract_serial","board_left","airship"]: old.erase(k)
	for b in old.buildings.values(): b.erase("yield_acc")
	var up=Industry.new()
	check(up.restore(old) and up.staff.is_empty() and up.service_init==false,"a v0.34 island save loads and starts the pipeline fresh")
	var bad=data.duplicate(true); bad.staff[0].home=1
	check(not Industry.new().restore(bad),"staff must live in an apartment")
	bad=data.duplicate(true); bad.contracts[0].lines={"moon_rock":1}
	check(not Industry.new().restore(bad),"contracts only ask for real items")
	if failures.is_empty(): print("STAFF OK (%d checks)" % checks); quit(0)
	else: print("STAFF FAILED: ",failures); quit(1)
