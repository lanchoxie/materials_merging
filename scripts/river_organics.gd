extends RefCounted
## Finite teaching-dose ledger. UI and scenes never consume inventory.
## Soil mass is tracked as fertilizer-equivalent, not unchanged urea molecules.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/organic_materials.json"))
var tanks={}
var bottles={}
var soils={}
var inputs={}
var serial=1
var spent_g=0.0
var applied_water_l=0.0
var waste_g=0.0
var waste_l=0.0
var waste_by_reference={}
var revision=0

func substance(row: Dictionary) -> String:
	return str(row.get("reference","urea"))

func sample_mass(reference: String) -> float:
	return float(rules.references[reference].gameplay.sample_g)

func substance_name(reference: String) -> String:
	return str(rules.references.get(reference,{}).get("name",reference))

func is_liquid(row: Dictionary) -> bool:
	return rules.references.get(substance(row),{}).get("gameplay",{}).get("phase")=="liquid"

func tank(key: String,c) -> Dictionary:
	if c.blocks.get(key,{}).get("kind")!="mixing_tank": return {}
	if not tanks.has(key):
		if tanks.size()>=int(rules.game.max_tanks): return {}
		tanks[key]={"water_l":0.0,"solid_g":0.0,"dissolved_g":0.0,"temperature_c":float(rules.game.temperature_c)}
	return tanks[key]

func concentration(row: Dictionary) -> float:
	return float(row.get("dissolved_g",0))/float(row.water_l) if float(row.get("water_l",0))>0 else 0.0

func protected_keys() -> Dictionary:
	var result={}
	for key in tanks:
		var t=tanks[key]
		if t.water_l+t.solid_g+t.dissolved_g>0.000001: result[key]=true
	for key in soils:
		if soils[key].mass_g>0.000001 or soils[key].injury>0: result[key]=true
	return result

func input_error(key: String,reference: String,batch_id: String,c) -> String:
	if reference!="water" and not rules.references.has(reference): return "这里只接收目录内已识别的有机物或水样"
	if not inputs.has(batch_id) and inputs.size()>=int(rules.game.max_inputs): return "配料来源记录已满"
	if c.blocks.get(key,{}).get("kind")!="mixing_tank": return "走近你放置的配料罐再操作"
	if not tanks.has(key) and tanks.size()>=int(rules.game.max_tanks): return "最多同时使用32只配料罐"
	var t=tanks.get(key,{"water_l":0.0,"solid_g":0.0,"dissolved_g":0.0})
	if reference=="water" and t.water_l+float(rules.game.sample_water_l)>float(rules.game.tank_capacity_l)+0.000001: return "配料罐已满；先分装，不会消耗水样"
	if reference!="water":
		if t.solid_g+t.dissolved_g>0.000001 and substance(t)!=reference: return "每罐只做一种有机物的配水实验；先封存余料或换一只罐"
		if t.solid_g+t.dissolved_g+sample_mass(reference)>float(rules.game.tank_solid_limit_g)+0.000001: return "已达到本罐的配料量上限；这不是溶解度上限"
	return ""

func add_input(key: String,reference: String,batch: Dictionary) -> void:
	# Called only after the coordinator has atomically debited the real sample.
	var t=tanks[key]
	if reference=="water": t.water_l+=float(rules.game.sample_water_l)
	else: t.reference=reference; t.solid_g+=sample_mass(reference)
	if not inputs.has(str(batch.id)): inputs[str(batch.id)]={"reference":reference,"count":0,"work":batch.work.duplicate(true)}
	inputs[str(batch.id)].count+=1; revision+=1

func bottle_error(key: String) -> String:
	var t=tanks.get(key,{})
	if t.is_empty() or t.get("water_l",0)<float(rules.game.bottle_l)-0.000001: return "罐内水量不足一瓶"
	if t.get("dissolved_g",0)<=0.000001: return "先加入有机物和水，等待混合完成"
	if bottles.size()>=int(rules.game.max_bottles): return "溶液瓶已装满背包，先使用已有的瓶子"
	return ""

func bottle(key: String) -> String:
	var error=bottle_error(key)
	if not error.is_empty(): return error
	var t=tanks[key]; var water=float(rules.game.bottle_l)
	var mass=minf(t.dissolved_g,concentration(t)*water)
	bottles[str(serial)]={"water_l":water,"mass_g":mass,"tank":key,"reference":substance(t)}
	serial+=1; t.water_l=maxf(0,t.water_l-water); t.dissolved_g=maxf(0,t.dissolved_g-mass); revision+=1
	return "已分装250教学mL · "+substance_name(substance(t))+"；用途和浓度保存在背包标签中"

func drain(key: String) -> String:
	if not tanks.has(key): return "没有配料罐"
	var t=tanks[key]
	waste_g+=t.solid_g+t.dissolved_g; waste_l+=t.water_l
	waste_by_reference[substance(t)]=float(waste_by_reference.get(substance(t),0))+t.solid_g+t.dissolved_g
	t.solid_g=0.0; t.dissolved_g=0.0; t.water_l=0.0; revision+=1
	return "余料已封存为废液；不返还样品、不倒入河流。空罐可以拆回"

func apply_error(id: String,key: String,field) -> String:
	if not bottles.has(id): return "这瓶已用完，回配料罐分装"
	if substance(bottles[id])!="urea": return "这瓶是"+substance_name(substance(bottles[id]))+"配水实验样品；瞄准同种配料罐可倒回，未开放作物用途"
	if not field.gardens.has(key): return "瞄准已播种的种植箱；这瓶不作饮水或动物饲料"
	if field.gardens[key].growth>=1: return "作物已经成熟，先收获；没有消耗溶液"
	if not soils.has(key) and soils.size()>=int(rules.game.max_plots): return "已达到施肥地块记录上限"
	if float(soils.get(key,{}).get("mass_g",0))+bottles[id].mass_g>float(rules.game.soil_limit_g): return "这箱已积累太多肥料，请等它恢复"
	return ""

func apply(id: String,key: String,field) -> String:
	var error=apply_error(id,key,field)
	if not error.is_empty(): return error
	var b=bottles[id]
	if not soils.has(key): soils[key]={"mass_g":0.0,"injury":0.0,"doses":0,"last_concentration":0.0}
	var soil=soils[key]; soil.mass_g+=b.mass_g; soil.doses+=1; soil.last_concentration=b.mass_g/b.water_l
	var excess=soil.last_concentration>float(rules.game.gentle_concentration_g_l) or soil.mass_g>float(rules.game.gentle_soil_g)
	if excess: soil.injury=minf(1,soil.injury+float(rules.game.injury_per_overdose))
	field.gardens[key].moisture=minf(1,field.gardens[key].moisture+b.water_l*float(rules.game.water_moisture_per_l))
	applied_water_l+=b.water_l; bottles.erase(id); revision+=1; field.revision+=1
	return "这箱施用过浓或累积过量，叶尖开始受损。停止追加，让作物缓慢恢复" if excess else "这箱获得温和补肥；土壤湿润时长得更快，旁边的对照箱保持原样"

func growth_factor(key: String) -> float:
	var s=soils.get(key,{})
	if s.is_empty(): return 1.0
	return (1.0+float(rules.game.growth_bonus) if s.mass_g>0 else 1.0)*(1.0-float(s.injury)*0.9)

func injury(key: String) -> float:
	return float(soils.get(key,{}).get("injury",0))

func describe_soil(key: String) -> String:
	if not soils.has(key): return "未施肥 · 可保留作对照"
	var s=soils[key]
	return "肥料余量 %.2f g当量 · 叶片受损 %.0f%% · 生长 ×%.2f" % [s.mass_g,s.injury*100,growth_factor(key)]

func tick(field,c) -> void:
	for key in tanks.keys():
		if not c.blocks.has(key): tanks.erase(key); continue # only empty tanks may be dismantled
		var t=tanks[key]
		if t.water_l<=0 or t.temperature_c!=float(rules.game.temperature_c): continue
		var delta=minf(t.solid_g,float(rules.references[substance(t)].gameplay.mixing_g_per_second))
		if delta>0: t.solid_g-=delta; t.dissolved_g+=delta; revision+=1
	for key in soils.keys():
		var s=soils[key]
		if field.gardens.has(key):
			s.injury=maxf(0,s.injury-float(rules.game.injury_recovery_per_second))
			if field.gardens[key].moisture>=float(field.rules.garden.minimum_moisture) and field.gardens[key].growth<1:
				var delta=minf(s.mass_g,float(rules.game.uptake_g_per_second)); s.mass_g-=delta; spent_g+=delta
		if s.mass_g<=0.000001 and s.injury<=0: spent_g+=s.mass_g; soils.erase(key); revision+=1

func balance() -> Dictionary:
	var input_g=0.0; var input_l=0.0; var held_g=spent_g+waste_g; var held_l=applied_water_l+waste_l
	for row in inputs.values():
		if row.reference=="water": input_l+=row.count*float(rules.game.sample_water_l)
		else: input_g+=row.count*sample_mass(row.reference)
	for row in tanks.values(): held_g+=row.solid_g+row.dissolved_g; held_l+=row.water_l
	for row in bottles.values(): held_g+=row.mass_g; held_l+=row.water_l
	for row in soils.values(): held_g+=row.mass_g
	return {"input_g":input_g,"input_l":input_l,"held_g":held_g,"held_l":held_l}

func serialize() -> Dictionary:
	return {"version":2,"waste_by_reference":waste_by_reference.duplicate(),"tanks":tanks.duplicate(true),"bottles":bottles.duplicate(true),"soils":soils.duplicate(true),"inputs":inputs.duplicate(true),"serial":serial,"spent_g":spent_g,"applied_water_l":applied_water_l,"waste_g":waste_g,"waste_l":waste_l}

func prune_empty(c) -> void:
	for key in tanks.keys():
		var t=tanks[key]
		if not c.blocks.has(key) and t.water_l+t.solid_g+t.dissolved_g<0.000001: tanks.erase(key); revision+=1

func restore(data,c) -> bool:
	if not data is Dictionary or (data.get("version")!=1 and data.get("version")!=2): return false
	for pair in [["tanks","max_tanks"],["bottles","max_bottles"],["soils","max_plots"],["inputs","max_inputs"]]:
		if not data.get(pair[0]) is Dictionary or data[pair[0]].size()>int(rules.game[pair[1]]): return false
	if not _num(data.get("serial"),1,1e12,true): return false
	for key in ["spent_g","applied_water_l","waste_g","waste_l"]:
		if not _num(data.get(key),0,1e12): return false
	for key in data.tanks:
		var row=data.tanks[key]
		if c.blocks.get(key,{}).get("kind")!="mixing_tank" or not row is Dictionary: return false
		if not _num(row.get("water_l"),0,rules.game.tank_capacity_l): return false
		for prop in ["solid_g","dissolved_g"]:
			if not _num(row.get(prop),0,rules.game.tank_solid_limit_g): return false
		if row.solid_g+row.dissolved_g>float(rules.game.tank_solid_limit_g)+0.000001 or row.get("temperature_c")!=rules.game.temperature_c: return false
		if row.water_l==0 and row.dissolved_g>0.000001: return false
		if not rules.references.has(substance(row)): return false
	for id in data.bottles:
		var row=data.bottles[id]
		if not str(id).is_valid_int() or int(id)<1 or int(id)>=int(data.serial) or not row is Dictionary: return false
		if row.get("water_l")!=rules.game.bottle_l or not _num(row.get("mass_g"),0.000000001,rules.game.tank_solid_limit_g): return false
		if not row.get("tank") is String or row.tank.length()>80: return false
		if not rules.references.has(substance(row)): return false
	for key in data.soils:
		var row=data.soils[key]
		if c.blocks.get(key,{}).get("kind")!="planter" or not row is Dictionary: return false
		if not _num(row.get("mass_g"),0,rules.game.soil_limit_g) or not _num(row.get("injury"),0,1) or not _num(row.get("doses"),1,1e12,true) or not _num(row.get("last_concentration"),0,1000): return false
	for id in data.inputs:
		var row=data.inputs[id]
		if not id is String or id.is_empty() or id.length()>160 or not row is Dictionary: return false
		if (row.get("reference")!="water" and not rules.references.has(str(row.get("reference")))) or not _num(row.get("count"),1,1e9,true) or not row.get("work") is Dictionary: return false
	var discarded=data.get("waste_by_reference",{"urea":data.waste_g} if data.version==1 else null)
	if not discarded is Dictionary or discarded.size()>rules.references.size(): return false
	var waste_total=0.0
	for ref in discarded:
		if not rules.references.has(ref) or not _num(discarded[ref],0,1e12): return false
		waste_total+=discarded[ref]
	if absf(waste_total-float(data.waste_g))>0.00001: return false
	# Check on an isolated candidate, so corrupt ledgers cannot partially replace state.
	var candidate=get_script().new()
	candidate.tanks=data.tanks.duplicate(true); candidate.bottles=data.bottles.duplicate(true); candidate.soils=data.soils.duplicate(true); candidate.inputs=data.inputs.duplicate(true)
	candidate.spent_g=float(data.spent_g); candidate.applied_water_l=float(data.applied_water_l); candidate.waste_g=float(data.waste_g); candidate.waste_l=float(data.waste_l)
	candidate.waste_by_reference=discarded.duplicate()
	for total in candidate.species_balance().values():
		if absf(total.input-total.held)>0.00001: return false
	var totals=candidate.balance()
	if absf(totals.input_g-totals.held_g)>0.00001 or absf(totals.input_l-totals.held_l)>0.00001: return false
	waste_by_reference=candidate.waste_by_reference
	tanks=candidate.tanks; bottles=candidate.bottles; soils=candidate.soils; inputs=candidate.inputs
	spent_g=candidate.spent_g; applied_water_l=candidate.applied_water_l; waste_g=candidate.waste_g; waste_l=candidate.waste_l; serial=int(data.serial); revision+=1
	return true

func _num(value,lo: float,hi: float,whole: bool=false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=lo and value<=hi and (not whole or value==floor(value))

func species_balance() -> Dictionary:
	var result={}
	for ref in rules.references: result[ref]={"input":0.0,"held":float(waste_by_reference.get(ref,0))}
	result.urea.held+=spent_g
	for row in inputs.values():
		if row.reference!="water": result[row.reference].input+=row.count*sample_mass(row.reference)
	for row in tanks.values(): result[substance(row)].held+=row.solid_g+row.dissolved_g
	for row in bottles.values(): result[substance(row)].held+=row.mass_g
	for row in soils.values(): result.urea.held+=row.mass_g
	return result

func return_error(id: String,key: String,c) -> String:
	if not bottles.has(id): return "这瓶已经用完"
	if c.blocks.get(key,{}).get("kind")!="mixing_tank": return "瞄准配料罐倒回"
	if not tanks.has(key) and tanks.size()>=int(rules.game.max_tanks): return "配料罐数量已达上限"
	var b=bottles[id]; var t=tanks.get(key,{"water_l":0.0,"solid_g":0.0,"dissolved_g":0.0})
	if t.solid_g+t.dissolved_g>0.000001 and substance(t)!=substance(b): return "不同有机物不能倒进同一罐；换空罐或同种罐"
	if t.water_l+b.water_l>float(rules.game.tank_capacity_l)+0.000001 or t.solid_g+t.dissolved_g+b.mass_g>float(rules.game.tank_solid_limit_g)+0.000001: return "这只罐空间不足，溶液仍保留在背包"
	return ""

func return_bottle(id: String,key: String,c) -> String:
	var error=return_error(id,key,c)
	if not error.is_empty(): return error
	var b=bottles[id]; var t=tank(key,c); t.reference=substance(b)
	t.water_l+=b.water_l; t.dissolved_g+=b.mass_g; bottles.erase(id); revision+=1
	return "溶液已倒回，可继续稀释或分装；原来的瓶子已用完"
