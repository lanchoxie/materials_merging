extends SceneTree
## v0.34 星锻岛 logic: 岛主 XP and the legacy conversion, unlock gates, 工业信用 fusing, plots,
## licences and power, evidence-gated recipes with reserved inputs, the market, the drill bit, saves.
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
	# --- Rank curve and legacy conversion.
	check(Industry.rank_of(0).rank==1 and Industry.rank_of(Industry.step(1)).rank==2,"rank 2 after the first step")
	var s=State.new(); var ind=s.industry
	s.milestones_claimed=["a","b"]; s.refinery.level=2
	var expect=Industry.legacy_score(s)
	ind.sync_legacy(s)
	check(ind.xp==expect and ind.pending_xp==0,"old progress converts once into XP without a pop (%d)" % expect)
	s.milestones_claimed.append("c"); ind.sync_legacy(s)
	check(ind.xp==expect+int(R.rank.legacy.milestone) and ind.pending_xp==int(R.rank.legacy.milestone),"new milestones keep paying XP")
	# --- Unlock gates.
	check(not ind.unlock(s).begins_with("星锻岛开放"),"unlock refuses while conditions are missing")
	var u: Dictionary=R.unlock
	ind.xp=0
	for n in range(1,int(u.rank)): ind.xp+=Industry.step(n)
	preload("res://scripts/test_mode.gd").unlock_plots(s,int(u.home_plots))
	s.coins=float(u.coins)+50000; s.materials=[50,50,int(u.alloy)+10]
	s.refinery.level=int(u.refinery_level); s.fabricator.serial=int(u.fabricated)
	check(ind.unlock_rows(s).all(func(r): return r.ok),"all unlock rows are met")
	var coins=s.coins
	check(ind.unlock(s).begins_with("星锻岛开放") and ind.unlocked and ind.plots==int(R.plots.start),"island Ⅱ unlocks with its starting plots")
	check(is_equal_approx(s.coins,coins-float(u.coins)) and s.materials[2]==10,"unlock costs coins and 合金片")
	# --- 工业信用.
	var before=ind.credits
	check(ind.fuse(s,10).contains("+50") and ind.credits==before+50 and s.materials==[40,40,0],"fusing turns 1+1+1 pieces into 5 credits")
	check(not ind.fuse(s,1).contains("+"),"fusing stops when a piece runs out")
	ind.credits=500
	# --- Buildings, licences, power.
	check(ind.build(s,0,"metal_works").contains("建成") and ind.build(s,1,"trade_hub").contains("建成"),"metal works and trade hub are built")
	check(not ind.build_error(s,2,"metal_works").is_empty(),"one licence per kind at the start")
	check(ind.build(s,2,"polymer_works").contains("建成") and ind.power_use()==7,"polymer works fits the starter grid")
	check(ind.build_error(s,9,"polymer_works")!="","plots beyond the deck are refused")
	var plots=ind.plots; ind.buy_plot(s)
	check(ind.plots==plots+1,"a plot can be bought with coins and credits")
	# --- Evidence-gated recipe, reserved inputs, production, XP.
	s.element_inventory["Fe"]=12; s.element_inventory["C"]=3
	check(ind.quote(s,0,"carbon_steel").get("locked",false),"steel is locked until Fe₃C has been made")
	made(s,"Fe3C")
	check(ind.quote(s,0,"carbon_steel").ready,"making Fe₃C unlocks carbon steel")
	check(ind.start(s,0,"carbon_steel").begins_with("已投料") and int(s.element_inventory.Fe)==6 and int(s.element_inventory.C)==2,"inputs are reserved when the job is queued")
	ind.pending_xp=0
	ind.tick(s,50.0)
	check(int(ind.items.get("steel_ingot",0))==2 and ind.pending_xp>0,"the job finishes and pays XP")
	check(not ind.quote(s,0,"polyethylene").ready,"a recipe of another factory is refused")
	# Batch inputs come from the island's harvested molecules.
	made(s,"C2H4")
	s.storage.batches.append({"id":"eth1","name":"乙醇","formula":"C2H6O","reference":"ethanol","quality":1.0,"work":{},"quantity":3})
	check(ind.start(s,2,"polyethylene").begins_with("已投料") and int(s.storage.batch("eth1").quantity)==1,"polyethylene takes two ethanol units")
	ind.tick(s,40.0)
	check(int(ind.items.get("pe",0))==3,"polyethylene pellets come out")
	# --- Market saturation.
	var p0=ind.price("pe")
	check(ind.sell(s,"pe",3).contains("+") and ind.price("pe")<p0,"selling saturates the price")
	ind.tick(s,float(R.market.half_life)*6)
	check(ind.price("pe")==p0,"the market recovers over time")
	# --- Drill bit becomes the planet pick when harder.
	ind.items["steel_ingot"]=3
	ind.start(s,0,"steel_bit"); ind.tick(s,60.0)
	check(ind.equip("steel_bit").contains("已装备"),"the steel bit can be equipped")
	s.sync_gear()
	check(is_equal_approx(s.planet.v2.nature.pick_hv,ind.gear_hv("steel_bit")) and s.planet.v2.nature.pick_hv>5.43 and s.planet.v2.nature.pick_name=="碳钢钻头","the bit sets the planet dig hardness")
	check(ind.sell(s,"steel_bit",1).contains("不能卖"),"the equipped bit cannot be sold")
	# --- Save round trip and validation.
	var data=ind.serialize(); var again=Industry.new()
	check(again.restore(JSON.parse_string(JSON.stringify(data))) and again.xp==ind.xp and again.buildings.size()==3 and again.bit=="steel_bit","industry survives a JSON round trip")
	var bad=data.duplicate(true); bad.buildings["0"].kind="moon_base"
	check(not Industry.new().restore(bad),"unknown buildings are rejected")
	bad=data.duplicate(true); bad.unlocked=false
	check(not Industry.new().restore(bad),"a locked island cannot have buildings")
	s.storage.take_product("eth1",int(s.storage.batch("eth1").get("quantity",0)))  # the fake batch has no real work
	var path="res://saves/industry-check.json"
	s.save_game(path)
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.industry.unlocked and loaded.industry.credits==ind.credits,"the whole game save keeps island Ⅱ")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	if failures.is_empty(): print("INDUSTRY OK (%d checks)" % checks); quit(0)
	else: print("INDUSTRY FAILED: ",failures); quit(1)
