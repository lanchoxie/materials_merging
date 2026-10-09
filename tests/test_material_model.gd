extends SceneTree
## v0.37 material property model v1: the laws are continuous with the right shapes (steel quench and
## temper sweet spot, bronze δ-phase embrittlement, duralumin peak ageing, Al-Li density), lots carry
## knobs and scatter, the test bench measures, prices follow quality, the bit uses its best lot, saves.
const State=preload("res://scripts/lab_state.gd")
const Industry=preload("res://scripts/industry.gd")
const Model=preload("res://scripts/material_model.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	# --- Laws: shapes, not tiers.
	var hv=func(id,k): return float(Model.props(id,k).hv)
	check(hv.call("carbon_steel",{"C":0.2})<hv.call("carbon_steel",{"C":0.45}) and hv.call("carbon_steel",{"C":0.45})<hv.call("carbon_steel",{"C":0.77}),"pearlite: normalised steel hardens smoothly with carbon")
	check(Model.props("carbon_steel",{"C":1.2}).tough<Model.props("carbon_steel",{"C":0.2}).tough,"more carbon, less toughness")
	var q150=Model.props("steel_tool",{"C":0.6,"T":150}); var q600=Model.props("steel_tool",{"C":0.6,"T":600})
	check(float(q150.hv)>700 and float(q600.hv)<400 and float(q600.tough)>float(q150.tough),"tempering trades hardness for toughness (HV %d → %d)" % [int(q150.hv),int(q600.hv)])
	check(absf(float(Model.props("steel_tool",{"C":0.8,"T":150}).hv)-float(Model.props("steel_tool",{"C":1.2,"T":150}).hv))<40,"martensite hardness flattens above ~0.8 % C (Krauss)")
	var best=[0.0,0.0,0.0]
	for c in [0.2,0.4,0.6,0.8,1.0,1.2]:
		for t in [150,200,250,300,400,500,650]:
			var e=float(Model.props("steel_tool",{"C":c,"T":t}).edge)
			if e>best[0]: best=[e,c,t]
	check(best[1]>0.3 and best[1]<1.1 and best[2]<=300,"the bit has an interior sweet spot, not 'max everything' (%.2f GPa at C %.1f, %d °C)" % best)
	check(float(Model.props("steel_tool",{"C":1.2,"T":150}).edge)<float(Model.props("steel_tool",{"C":1.2,"T":150}).gpa),"a brittle edge chips: edge hardness below hardness")
	var tme=Model.props("steel_tool",{"C":0.6,"T":300}); var near=Model.props("steel_tool",{"C":0.6,"T":400})
	check(float(tme.tough)<float(near.tough),"tempered-martensite embrittlement near 300 °C")
	check(hv.call("tin_bronze",{"Sn":12})>hv.call("tin_bronze",{"Sn":6}) and Model.props("tin_bronze",{"Sn":20}).tough<0.3,"bronze: solid-solution hardening, δ phase embrittles above ~13.5 % Sn")
	var under=hv.call("duralumin",{"t":0.5}); var peak=hv.call("duralumin",{"t":10}); var over=hv.call("duralumin",{"t":200})
	check(peak>under and peak>over and over>float(Model.family("duralumin").ss_hv),"duralumin ageing curve rises, peaks, then overages (%d/%d/%d)" % [int(under),int(peak),int(over)])
	var li1=Model.props("al_li",{"Li":1.0}); var li2=Model.props("al_li",{"Li":2.6})
	check(float(li2.rho)<float(li1.rho) and float(li2.specific)>float(li1.specific) and float(li2.tough)<float(li1.tough),"Al-Li: lighter and stiffer per Li, tougher below 1.8 %")
	check(absf(float(Model.props("al_li",{"Li":1.0}).rho)/2.78-0.97)<0.001,"−3 % density per wt% Li (Rioja & Liu)")
	check(is_equal_approx(float(Model.knobs("steel_tool",{"T":9999}).T),650.0),"knobs clamp to their range")
	check(Model.quality(1)!=Model.quality(2) and absf(Model.quality(7)-1.0)<=float(Model.rules().scatter)+0.0001,"lots scatter within ±3 %")
	check(Model.describe("steel_tool",{"C":0.6,"T":200},1.0,false).contains("±") and not Model.describe("steel_tool",{"C":0.6,"T":200},1.02,true).contains("±"),"predictions show a band, measurements do not")
	# --- Factory flow: knobs → lots.
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,300); s.coins=100000
	ind.build(s,0,"metal_works"); ind.build(s,1,"trade_hub")
	ind.lots={}; ind.items={}
	for f in ["Fe3C","Cu3Sn"]: s.index_found[Industry._keys_for(f)[0]]=true
	s.element_inventory["Fe"]=60; s.element_inventory["C"]=10; s.element_inventory["Cu"]=30; s.element_inventory["Sn"]=10
	ind.set_knob("carbon_steel","C",0.65)
	check(ind.start(s,0,"carbon_steel").contains("碳含量 0.65"),"the job remembers its carbon")
	ind.set_knob("bronze","Sn",22)
	check(int(ind.inputs("bronze")["el:Sn"])==2,"more tin in the melt needs more tin atoms")
	ind.tick(s,60.0)
	check(int(ind.items.get("steel_ingot",0))==2 and ind.lots_of("steel_ingot").size()==1 and is_equal_approx(float(ind.lots.steel_ingot[0].k.C),0.65),"finished ingots form a lot with the knob")
	ind.set_knob("steel_bit","T",200)
	ind.items.steel_ingot=3; ind._reconcile("steel_ingot")
	check(ind.lots_of("steel_ingot").size()==2,"an old unit without a lot becomes a default lot")
	check(ind.start(s,0,"steel_bit").begins_with("已投料"),"the bit is forged from the ingots")
	var job=ind.buildings["0"].jobs[-1]
	check(float(job.k.C)>0.45 and float(job.k.C)<0.65,"the bit inherits the mean carbon of the ingots it consumed (%.2f)" % float(job.k.C))
	ind.tick(s,200.0)
	check(int(ind.items.get("steel_bit",0))==1,"the bit comes out")
	check(ind.equip("steel_bit").contains("刃口硬度"),"equipping reports the edge hardness")
	s.sync_gear()
	check(absf(float(s.planet.v2.nature.pick_hv)-ind.gear_hv("steel_bit"))<0.0001 and ind.gear_hv("steel_bit")>5.43,"the planet digs with the bit's modelled edge (%.2f GPa)" % ind.gear_hv("steel_bit"))
	# --- Market and test bench.
	ind.items.duralumin=4; ind.lots.duralumin=[{"n":2,"k":{"t":10.0},"q":1.0,"m":false},{"n":2,"k":{"t":200.0},"q":1.0,"m":false}]
	check(ind.lot_price("duralumin",0)>ind.lot_price("duralumin",1),"peak-aged duralumin sells for more than over-aged")
	check(ind.measure(s,"duralumin",0).contains("先建"),"measuring needs the test bench")
	s.coins=100000; ind.plots=maxi(ind.plots,3)
	check(ind.build(s,2,"test_bench").contains("建成"),"the test bench is built")
	var before=ind.lot_price("duralumin",0)
	check(ind.measure(s,"duralumin",0).begins_with("测试台报告"),"a lot is measured")
	var measured=-1
	for i in range(ind.lots.duralumin.size()):
		if bool(ind.lots.duralumin[i].m): measured=i
	check(measured>=0 and ind.lot_price("duralumin",measured)>before,"a test report raises the price")
	check(ind.sell(s,"duralumin",2,measured).contains("+") and int(ind.items.duralumin)==2 and ind.lots_of("duralumin").size()==1,"selling one lot keeps the other")
	check(ind.sell(s,"steel_bit",1).contains("不能卖"),"the equipped bit still cannot be sold")
	# --- Save round trip and validation.
	var data=ind.serialize()
	var again=Industry.new()
	check(again.restore(JSON.parse_string(JSON.stringify(data))) and again.lots_of("duralumin").size()==1 and absf(again.gear_hv("steel_bit")-ind.gear_hv("steel_bit"))<0.001 and is_equal_approx(float(again.recipe_knobs("carbon_steel").C),0.65),"lots and knob settings survive a JSON round trip")
	var bad=JSON.parse_string(JSON.stringify(data)); bad.lots.duralumin[0].n=99
	check(not Industry.new().restore(bad),"lots that do not sum to the count are rejected")
	bad=JSON.parse_string(JSON.stringify(data)); bad.lots["pe"]=[{"n":1,"k":{},"q":1.0,"m":false}]
	check(not Industry.new().restore(bad),"lots on an unmodelled item are rejected")
	var old=JSON.parse_string(JSON.stringify(data)); old.version=2; old.erase("lots"); old.erase("settings"); old.erase("lot_serial")
	var legacy=Industry.new()
	check(legacy.restore(old) and legacy.lots_of("duralumin").size()==1 and int(legacy.lots_of("duralumin")[0].n)==2,"a v0.36 save gets default lots")
	if failures.is_empty(): print("MATERIAL MODEL OK (%d checks)" % checks); quit(0)
	else: print("MATERIAL MODEL FAILED: ",failures); quit(1)
