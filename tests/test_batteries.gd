extends SceneTree
## v0.40 "Batteries & Power": Faraday capacity, the electrode-thickness trade-off (energy vs rate), the
## battery works chain (lead-acid, LFP cells, packs), the motor, the cordless drill on the planet
## (fewer hits, real Wh, recharge on the island), grid storage, saves.
const State=preload("res://scripts/lab_state.gd")
const Industry=preload("res://scripts/industry.gd")
const Model=preload("res://scripts/material_model.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	# --- Laws.
	var thin=Model.props("lfp_cell",{"t":40}); var thick=Model.props("lfp_cell",{"t":200})
	check(absf(float(thin.capacity)-169.9)<0.2,"Faraday: LiFePO₄ holds 170 mAh/g")
	check(float(thick.wh_kg)>float(thin.wh_kg) and float(thick.c_rate)<float(thin.c_rate),"thicker coatings store more but deliver less current")
	check(float(thin.wh_kg)>80 and float(thick.wh_kg)<180,"cell specific energy stays in the real LFP range (%.0f–%.0f Wh/kg)" % [float(thin.wh_kg),float(thick.wh_kg)])
	var best=[0.0,0.0]
	for t in range(40,205,5):
		var e=float(Model.props("lfp_cell",{"t":t}).tool_energy)
		if e>best[0]: best=[e,t]
	check(best[1]>60 and best[1]<140,"the power-tool optimum is an interior thickness (%d µm)" % int(best[1]))
	var drill=Model.props("power_drill",{"t":90})
	check(float(drill.pack_wh)>60 and float(drill.pack_wh)<120 and int(drill.blocks)>=20,"a drill pack holds about a cordless-tool battery (%.0f Wh, %d blocks)" % [float(drill.pack_wh),int(drill.blocks)])
	check(float(Model.props("power_drill",{"t":200}).drill_factor)>float(drill.drill_factor),"a thick, low-rate pack drills weaker")
	# --- Factory chain.
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,900); ind.gain(Industry.step(14)); s.coins=900000; ind.plots=10; ind.solar=[0.3,0.3,0.3,0.3,0.3,0.3,0.3,0.3]
	for k in ["battery_works","metal_works","packaging_plant","polymer_works","trade_hub"]: check(ind.build(s,ind.buildings.size(),k).contains("建成"),k+" is built")
	preload("res://scripts/test_mode.gd").battery_kit(s)
	ind.set_knob("lfp_cell","t",90)
	check(ind.start(s,0,"lfp_cell").contains("涂层厚度 90"),"LFP cells remember their coating")
	check(ind.start(s,0,"lead_acid").begins_with("已投料"),"lead-acid starts")
	ind.tick(s,200.0)
	ind.start(s,0,"lfp_cell"); ind.tick(s,200.0)
	check(int(ind.items.get("lfp_cell",0))==8 and int(ind.items.get("lead_acid",0))==1,"8 cells and a lead-acid battery come out")
	check(ind.start(s,0,"battery_pack").begins_with("已投料") and ind.start(s,1,"motor").begins_with("已投料"),"pack and motor start")
	ind.tick(s,200.0)
	check(absf(float(ind.lots_of("battery_pack")[0].k.t)-90.0)<0.01,"the pack inherits the cells' coating")
	check(ind.start(s,2,"power_drill").begins_with("已投料"),"the drill is assembled")
	ind.tick(s,200.0)
	check(int(ind.items.get("power_drill",0))==1,"a drill comes out")
	# --- Drill on the planet.
	check(ind.equip_drill("power_drill").contains("Wh"),"the drill is equipped")
	s.sync_gear()
	var v=s.planet.v2; var n=v.nature
	check(n.drill==ind.drill_state and float(ind.drill_state.cap)>60,"the planet shares the drill's state")
	ind.drill_state.charge=ind.drill_state.cap
	var t=v.construction.terrain; var p=Vector2(30,30); var ground=t.ground(p)
	var cell=Vector3i(30,int(floor(ground))-1,30)
	var aim={"type":"terrain","target":cell,"voxel":cell,"point":Vector3(30,ground,30)}
	v.actor={"eye":Vector3(30,ground+1.6,31.5),"feet":Vector3(30,ground,31.5),"direction":(Vector3(30,ground-0.5,30)-Vector3(30,ground+1.6,31.5)).normalized()}
	var hits=0; var before=float(ind.drill_state.charge); var last=""
	for i in range(12):
		last=n.dig(aim,v); hits+=1
		if not last.contains("采掘"): break
	check(not last.contains("采掘"),"the cell is dug out: "+last)
	check(float(ind.drill_state.charge)<before,"digging used drill charge (%.0f → %.0f Wh)" % [before,float(ind.drill_state.charge)])
	ind.drill_state.charge=0.0; v.active=false
	s.tick(30.0)
	check(float(ind.drill_state.charge)>0.0,"back on the island the drill recharges")
	# --- Grid storage.
	var cap=ind.power_cap()
	check(ind.install_storage("lead_acid").contains("接入") and ind.power_cap()==cap+1,"lead-acid adds 1 to the grid")
	check(ind.install_storage("lead_acid").contains("没有"),"only stock that exists can be installed")
	check(ind.sell(s,"power_drill",1).contains("不能卖"),"the equipped drill cannot be sold")
	# --- Save.
	var data=JSON.parse_string(JSON.stringify(ind.serialize()))
	var again=Industry.new()
	check(again.restore(data) and again.drill=="power_drill" and again.storage==[1],"drill, charge and storage survive a save")
	var bad=JSON.parse_string(JSON.stringify(ind.serialize())); bad.storage=[5]
	check(not Industry.new().restore(bad),"an impossible storage unit is rejected")
	bad=JSON.parse_string(JSON.stringify(ind.serialize())); bad.drill="pe"
	check(not Industry.new().restore(bad),"a non-drill cannot be equipped as a drill")
	if failures.is_empty(): print("BATTERIES OK (%d checks)" % checks); quit(0)
	else: print("BATTERIES FAILED: ",failures); quit(1)
