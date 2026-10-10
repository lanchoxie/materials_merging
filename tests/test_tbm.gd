extends SceneTree
## v0.45 盾构机 (user: 金属制品太耗元素……可以考虑加入盾构机吗): a 3×3 tunnel boring machine made at
## the vehicle assembly plant, deployed to the planet, boring one metre at a time (level, dive,
## climb), collecting every cut cell as ore in bulk; batch refinery processes turn it into metal.
const State=preload("res://scripts/lab_state.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const Tbm=preload("res://scripts/planet_tbm.gd")
const Industry=preload("res://scripts/industry.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func total(d: Dictionary) -> int:
	var n=0
	for k in d: n+=int(d[k])
	return n

func _initialize() -> void:
	var R=Industry.rules()
	# --- Data: the machine, its recipe and rules; batch refinery processes.
	check(R.items.tbm.get("tbm",false) and not R.items.tbm.get("vehicle",false),"the 盾构机 is its own kind of machine (not a rover)")
	check(R.recipes.tbm.building=="vehicle_assembly" and R.recipes.tbm.inputs.has("item:steel_ingot") and R.recipes.tbm.inputs.has("item:motor"),"built at the vehicle assembly plant from steel and motors")
	var refinery: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/refinery.json"))
	var bulk: Dictionary=refinery.processes.hematite_bulk
	check(int(bulk.inputs.hematite)==4 and int(bulk.inputs.coal)==1 and int(bulk.outputs.Fe)==16,"整炉炼铁: 4 hematite + 1 coal → 16 Fe (one coke per four ores)")
	check(refinery.processes.has("malachite_bulk") and refinery.processes.has("gibbsite_bulk"),"copper and aluminium have batch processes too")
	# --- Industry slot: deploy, charge, recharge, save.
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,100)
	check(ind.deploy_tbm("tbm").contains("没有"),"no machine, nothing to deploy")
	ind.items["tbm"]=1; ind._reconcile("tbm")
	check(ind.deploy_tbm("tbm").contains("派往地球") and ind.tbm=="tbm" and is_equal_approx(float(ind.tbm_state.cap),float(R.tbm.cap_wh)),"deployed with a %d Wh battery" % int(R.tbm.cap_wh))
	check(ind.reserved("tbm")==1,"a deployed machine can't be sold")
	ind.recharge_tbm(float(R.tbm.recharge_seconds)*0.5)
	check(absf(float(ind.tbm_state.charge)-float(R.tbm.cap_wh)*0.5)<0.01,"half the recharge time, half a battery")
	var copy=Industry.new(); check(copy.restore(JSON.parse_string(JSON.stringify(ind.serialize()))) and copy.tbm=="tbm" and is_equal_approx(float(copy.tbm_state.charge),float(ind.tbm_state.charge)),"the deployment and charge are saved")
	var bad=JSON.parse_string(JSON.stringify(ind.serialize())); bad.tbm="rover"
	check(not Industry.new().restore(bad),"a non-machine in the 盾构机 slot is rejected")
	# --- Boring: dive from the surface to hematite depth, collecting everything.
	var v=PlanetV2.new(); var t=v.construction.terrain
	var m=Tbm.new(R.tbm); m.state={"charge":float(R.tbm.cap_wh),"cap":float(R.tbm.cap_wh)}
	var start=Vector2i(60,-40); var g=floori(t.ground(Vector2(start)))
	m.place(Vector3i(start.x,g,start.y),0); m.grade=-1
	var before=total(v.nature.minerals); var stone=int(v.field.stock.stone); var soil=int(v.field.stock.soil)
	for i in range(20):
		var said=m.advance(v); m.busy=0.0
		if not said.begins_with("掘进") and not said.begins_with("前进"): check(false,"dive step %d: %s" % [i,said]); break
	check(m.cell.y==g-20 and m.cell.z==start.y-20,"twenty metres of diving: 20 down and 20 forward (y %d)" % m.cell.y)
	var cut=total(m.haul)-int(m.haul.get("stone",0))+m.overflow
	check(cut>=150 and total(v.nature.minerals)-before+int(v.field.stock.soil)-soil+m.overflow==cut,"every cut cell went into a store (%d cells)" % cut)
	check(int(v.field.stock.stone)-stone==int(m.haul.get("stone",0)) and int(m.haul.get("stone",0))>0,"quarried rock also left building stone")
	check(absf(float(m.state.charge)-(float(R.tbm.cap_wh)-float(cut)*float(R.tbm.wh_per_cell)))<0.01,"the battery paid %.1f Wh per cell" % float(R.tbm.wh_per_cell))
	check(v.nature.voxels.size()>=cut,"the tunnel is real terrain edits")
	# Level run in the hematite layer.
	m.grade=0; var hem=int(v.nature.minerals.get("hematite",0))
	for i in range(60):
		var said=m.advance(v); m.busy=0.0
		if not said.begins_with("掘进") and not said.begins_with("前进"): break
	check(int(v.nature.minerals.get("granite",0))>50,"the deep run cut granite in bulk (%d)" % int(v.nature.minerals.get("granite",0)))
	check(int(v.nature.minerals.get("hematite",0))>=hem,"hematite comes out with it (%d)" % int(v.nature.minerals.get("hematite",0)))
	# The tunnel is walkable: the floor is the machine's floor cell.
	var mid=m.cell-m.dir()*3
	check(absf(v.construction.floor_at(Vector2(mid.x,mid.z),mid.y+1.2)-float(mid.y))<0.01 and not v.construction.terrain.overlaps(Vector2(mid.x,mid.z),float(mid.y),1.75),"you can stand in the tunnel")
	# --- Controls: turn by quarter turns (once per press), back up only through open tunnel.
	m.busy=0.0; m.movement=Vector2(1,0); m.step(0.1,v); m.step(0.1,v)
	check(m.facing==1,"A/D turns a quarter turn per press")
	m.movement=Vector2.ZERO; m.step(0.1,v)
	check(m.reverse(v).contains("不是空隧道"),"backing into rock is refused")
	m.movement=Vector2(-1,0); m.step(0.1,v); m.movement=Vector2.ZERO; m.step(0.1,v)
	var cell=m.cell
	check(m.facing==0 and m.reverse(v).begins_with("后退") and m.cell==cell+Vector3i(0,0,1),"backing up the bored tunnel works")
	m.busy=0.0
	# --- Refusals: bedrock, buildings, flat battery, the edit limit, full stores.
	var deep=Tbm.new(R.tbm); deep.state={"charge":99999.0,"cap":99999.0}
	deep.place(Vector3i(start.x+40,-29,start.y),0); deep.grade=-1
	var why=""
	for i in range(6):
		why=deep.advance(v); deep.busy=0.0
		if why.contains("基岩"): break
	check(why.contains("基岩"),"bedrock stops the dive (%s)" % why)
	var flat=Tbm.new(R.tbm); flat.state={"charge":0.5,"cap":1200.0}; flat.place(Vector3i(start.x+80,g-6,start.y),2)
	check(flat.advance(v).contains("电量不足"),"a flat battery stops the cutter")
	var c=v.construction
	var guard=Tbm.new(R.tbm); guard.state={"charge":999.0,"cap":1200.0}
	var gx=start.x-60; var gz=start.y; var gb=c.base(Vector3i(gx,0,gz-1))
	c.sources["1"]={"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"river:1"},"remaining":7}
	c.blocks[c.key(Vector3i(gx,gb,gz-1))]={"x":gx,"y":gb,"z":gz-1,"kind":"block","source":"1"}; c.revision+=1
	guard.place(Vector3i(gx,gb,gz),0)
	check(guard.advance(v).contains("建筑"),"it won't bore through a building")
	var cap=int(v.nature.rules.max_voxels); v.nature.rules.max_voxels=v.nature.voxels.size()
	var fresh=Tbm.new(R.tbm); fresh.state={"charge":999.0,"cap":1200.0}; fresh.place(Vector3i(start.x+120,g-6,start.y),2)
	check(fresh.advance(v).contains("改造记录已满"),"the terrain-edit limit stops it")
	v.nature.rules.max_voxels=cap
	v.nature.minerals["granite"]=int(v.nature.rules.max_mineral_stock); var lost=m.overflow
	for i in range(3): m.advance(v); m.busy=0.0
	check(m.overflow>lost and int(v.nature.minerals.granite)==int(v.nature.rules.max_mineral_stock),"a full store drops the overflow but keeps boring (%d lost)" % (m.overflow-lost))
	check(m.haul_text().contains("仓满丢弃"),"and says so")
	# --- Planet save: the machine's place; a far-north rover no longer breaks loading.
	v.tbm_at={"x":m.cell.x,"y":m.cell.y,"z":m.cell.z,"facing":m.facing,"grade":m.grade}
	v.rover_at={"x":100.0,"z":-7000.0,"heading":0.0}
	var data=JSON.parse_string(JSON.stringify(v.serialize()))
	var back=PlanetV2.new()
	check(back.restore(data) and int(back.tbm_at.y)==m.cell.y and int(back.tbm_at.facing)==m.facing,"the machine's place is saved")
	check(float(back.rover_at.z)==-7000.0,"a rover parked far north loads (fixed v0.42 disc check)")
	data.tbm.facing=5
	check(not PlanetV2.new().restore(data),"a bad facing is rejected")
	# --- Bulk ore through the refinery.
	var ref=s.refinery
	s.planet.v2.nature.minerals["hematite"]=8; s.planet.v2.nature.minerals["coal"]=2
	var fe=int(s.element_inventory.get("Fe",0))
	var started=ref.start(s,"hematite_bulk") if ref.has_method("start") else ""
	for i in range(20): ref.tick(s,10.0)
	check(int(s.element_inventory.get("Fe",0))>=fe+16,"整炉 turns 4 hematite + 1 coal into 16 Fe (%s)" % str(started))
	if failures.is_empty(): print("TBM OK (%d checks)" % checks); quit(0)
	else: print("TBM FAILED: ",failures); quit(1)
