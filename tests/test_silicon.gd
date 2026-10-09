extends SceneTree
## v0.37 Si/Ca/P: elements and ores, refinery routes, the inorganic works (glass, cement, tile,
## superphosphate) fed by planet minerals, the silicon foundry (Siemens polysilicon, P-doped wafers,
## solar panels), the doping and soda laws, solar power on the island grid, fertiliser on Earth.
const State=preload("res://scripts/lab_state.gd")
const Industry=preload("res://scripts/industry.gd")
const Model=preload("res://scripts/material_model.gd")
const ChemIndex=preload("res://scripts/chem_index.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	var s=State.new(); var ind=s.industry
	# --- Elements, ore and refinery.
	for el in ["Si","P","Ca"]:
		check(s.elements.has(el) and not s.refinery.sources_of(el).is_empty(),"%s exists and has a refinery source" % el)
	check(s.refinery.process("apatite_phosphorus").inputs.has("apatite") and s.refinery.process("quartz_silicon").outputs.has("Si"),"phosphorus from apatite, silicon from quartz sand")
	check(not ChemIndex.crystals().filter(func(e): return e.formula=="Si").is_empty() and not ChemIndex.molecules().filter(func(e): return e.formula=="Cl3HSi").is_empty(),"the index has crystalline Si and the trichlorosilane molecule")
	check(ChemIndex.crystals().size()>=2500,"the rebuilt crystal index covers the new elements (%d)" % ChemIndex.crystals().size())
	# --- Laws.
	var g12=Model.props("soda_lime_glass",{"Na2O":12}); var g18=Model.props("soda_lime_glass",{"Na2O":18})
	check(float(g12.durab)>float(g18.durab) and Model.seconds_factor("soda_lime_glass",{"Na2O":12})>Model.seconds_factor("soda_lime_glass",{"Na2O":18}),"soda: faster melting, worse weathering")
	check(absf(float(Model.props("soda_lime_glass",{"Na2O":15}).n)-1.52)<0.01,"Appen gives soda-lime glass n ≈ 1.52")
	var lo=Model.props("n_wafer",{"N":14}); var mid=Model.props("n_wafer",{"N":15.7}); var hi=Model.props("n_wafer",{"N":19})
	check(float(lo.mu)>1300 and float(hi.mu)<200,"electron mobility falls with doping (Masetti)")
	check(float(lo.rho_ohm)>float(mid.rho_ohm) and float(mid.rho_ohm)>float(hi.rho_ohm),"resistivity falls with doping")
	check(absf(float(Model.props("n_wafer",{"N":15.7}).rho_ohm)-1.0)<0.3,"N≈5×10¹⁵ is about 1 Ω·cm")
	check(float(mid.eff)>float(lo.eff) and float(mid.eff)>float(hi.eff),"cell efficiency has a doping sweet spot")
	check(absf(float(Model.props("solar_panel",{"N":15.7}).eff)-0.26*0.92)<0.001 and absf(float(Model.props("solar_panel",{"N":15.7}).watt)-0.26*0.92*1600)<1,"module = cell × 0.92 and watts at 1000 W/m²")
	# --- Factories.
	preload("res://scripts/test_mode.gd").open_starforge(s,500); s.coins=200000; ind.gain(Industry.step(8))
	ind.plots=8
	check(ind.build(s,0,"inorganic_works").contains("建成") and ind.build(s,1,"silicon_works").contains("建成"),"the inorganic works and the silicon foundry are built")
	var m: Dictionary=s.planet.v2.nature.minerals
	m["sand"]=10; m["limestone"]=10; m["clay"]=10; m["apatite"]=4
	s.element_inventory["Na"]=20
	ind.set_knob("soda_lime_glass","Na2O",18)
	check(int(ind.inputs("soda_lime_glass")["el:Na"])==3,"more soda needs more sodium")
	var q=ind.quote(s,0,"soda_lime_glass")
	check(q.ready,"glass is made from mined sand and limestone: "+str(q.message))
	ind.start(s,0,"soda_lime_glass")
	check(int(m.sand)==7 and int(m.limestone)==9 and int(s.element_inventory.Na)==17,"planet minerals are consumed")
	check(absf(float(ind.buildings["0"].jobs[0].left)-40.0*0.75)<0.01,"high-soda glass melts faster")
	check(ind.quote(s,0,"cement").get("locked",false),"cement waits for CaO")
	s.index_found[Industry._keys_for("CaO")[0]]=true
	check(ind.quote(s,0,"cement").ready,"making CaO (NaCl template with Ca and O) unlocks cement")
	check(ind.quote(s,0,"superphosphate").get("locked",false),"fertiliser waits for H₃PO₄")
	check(ind.quote(s,1,"polysilicon").get("locked",false),"polysilicon waits for SiHCl₃")
	for f in ["Cl3HSi","Si","H3O4P"]: s.index_found[Industry._keys_for(f)[0]]=true
	s.element_inventory["Si"]=8; s.element_inventory["H"]=20; s.element_inventory["Cl"]=10; s.element_inventory["P"]=4; s.element_inventory["S"]=4; s.element_inventory["O"]=10
	check(ind.start(s,1,"polysilicon").begins_with("已投料") and ind.start(s,0,"superphosphate").begins_with("已投料"),"polysilicon and superphosphate start")
	ind.tick(s,200.0)
	check(int(ind.items.get("glass",0))==2 and int(ind.items.get("polysilicon",0))==2 and int(ind.items.get("fertilizer",0))==3,"glass, polysilicon and fertiliser come out")
	ind.set_knob("n_wafer","N",15.7)
	check(ind.start(s,1,"n_wafer").contains("磷掺杂"),"the wafer remembers its doping")
	ind.tick(s,100.0)
	check(int(ind.items.get("wafer",0))==3 and ind.lots_of("wafer").size()==1,"wafers form one lot")
	ind.items["duralumin"]=1; ind._reconcile("duralumin")
	check(ind.start(s,1,"solar_panel").begins_with("已投料"),"a panel is laminated from wafers, glass and duralumin")
	var job=ind.buildings["1"].jobs[-1]
	check(absf(float(job.k.N)-15.7)<0.01,"the panel inherits the wafer doping")
	ind.tick(s,100.0)
	var cap=ind.power_cap()
	check(int(ind.items.get("solar_panel",0))==1,"the panel comes out")
	var msg=ind.install_solar()
	check(msg.contains("太阳能板") and ind.solar.size()==1 and not ind.items.has("solar_panel"),"the panel is installed on the island grid")
	ind.solar=[0.24,0.24]
	check(ind.solar_power()==2 and ind.power_cap()==cap+2,"two 24 % panels add two grid units (Σ efficiency / 20 %)")
	# --- Earth.
	var v=s.planet.v2; var region_id=v.world.regions.keys()[0]; var r=v.world.regions[region_id]
	r.crops=[{"crop":"wheat","growth":0.2,"ready":false}]; r.nutrients=0.3
	check(s.fertilize().contains("养分") and absf(float(r.nutrients)-0.42)<0.001 and int(ind.items.get("fertilizer",0))==2,"fertiliser raises nutrients where crops grow")
	for id in v.world.regions: v.world.regions[id].crops=[]
	check(s.fertilize().contains("暂时不用") and int(ind.items.get("fertilizer",0))==2,"no crops, no fertiliser spent")
	# --- Save.
	var again=Industry.new()
	check(again.restore(JSON.parse_string(JSON.stringify(ind.serialize()))) and again.solar.size()==2 and again.lots_of("glass").size()==1,"solar and new lots survive a round trip")
	var bad=JSON.parse_string(JSON.stringify(ind.serialize())); bad.solar=[0.9]
	check(not Industry.new().restore(bad),"an impossible panel efficiency is rejected")
	if failures.is_empty(): print("SILICON OK (%d checks)" % checks); quit(0)
	else: print("SILICON FAILED: ",failures); quit(1)
