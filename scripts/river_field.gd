extends RefCounted
## Deterministic gather sites, shared raw stock, and local planter simulation.
## No scene nodes or UI callbacks; the program owns transactional calls.
const Terrain=preload("res://scripts/river_terrain.gd")
var terrain=Terrain.new()
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_field.json"))
var stock={}
var changed={}
var crafts={}
var gardens={}
var revision=0

func _init() -> void:
	for id in rules.resources: stock[id]=0

func nodes(at: Vector2,radius: float=36) -> Array:
	var result=[]
	var home=[Vector2(17,18),Vector2(20,15),Vector2(18,11),Vector2(22,19),Vector2(24,14),Vector2(26,18),Vector2(21,24),Vector2(25,23)]
	var kinds=["timber","stone","fiber","fruit"]
	for i in range(home.size()):
		if at.distance_to(home[i])<=radius: result.append(_node("home:"+str(i),kinds[i%4],home[i]))
	for z in range(floori((at.y-radius)/16),ceili((at.y+radius)/16)+1):
		for x in range(floori((at.x-radius)/16),ceili((at.x+radius)/16)+1):
			var p=Vector2(x*16+5+sin(x*7+z*13)*2,z*16+5+cos(z*11+x*3)*2)
			if p.length()<30 or p.distance_to(at)>radius or not terrain.inside(p,4) or terrain.height_at(p)<0.2 or terrain.blocked(p): continue
			result.append(_node("site:%d:%d" % [x,z],kinds[posmod(x*7+z*11,4)],p))
	return result

func _node(id: String,kind: String,at: Vector2) -> Dictionary:
	# Keep authored starter sites off tree trunks, using the same stable offset for
	# rendering, aiming, and save identity.
	for offset in [Vector2.ZERO,Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
		if not terrain.blocked(at+offset): at+=offset; break
	return {"id":id,"kind":kind,"x":at.x,"z":at.y,"y":terrain.ground(at)}

func node(id: String) -> Dictionary:
	if id.begins_with("home:"):
		for n in nodes(Vector2(18,16),12):
			if n.id==id: return n
	elif id.begins_with("site:"):
		var parts=id.split(":")
		if parts.size()!=3 or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return {}
		var center=Vector2(int(parts[1])*16+5,int(parts[2])*16+5)
		if not terrain.inside(center,-5): return {}
		for n in nodes(center,4):
			if n.id==id: return n
	return {}

func remaining(id: String,now: int) -> int:
	return maxi(0,int(changed.get(id,{}).get("ready_at",0))-now)

func collect(n: Dictionary,now: int) -> String:
	if n.is_empty(): return "瞄准附近的采集点"
	var spec: Dictionary=rules.resources[n.kind]
	if remaining(n.id,now)>0: return "%s恢复中 · 还需%d秒星球时间" % [spec.node,remaining(n.id,now)]
	if not can_add(n.kind,int(spec.yield)): return "这种材料已装满，先到车间加工"
	if not changed.has(n.id) and changed.size()>=int(rules.max_changed_nodes): return "采集记录已满，等待已有采集点恢复"
	var progress=int(changed.get(n.id,{}).get("hits",0))+1
	if progress<int(spec.hits):
		changed[n.id]={"hits":progress,"ready_at":0}; revision+=1
		return "%s · 采集 %d/%d" % [spec.node,progress,spec.hits]
	stock[n.kind]+=int(spec.yield); changed[n.id]={"hits":0,"ready_at":now+int(spec.renew_seconds)}; revision+=1
	return "收入背包：%s ×%d" % [spec.name,spec.yield]

func can_add(id: String,amount: int) -> bool:
	return stock.has(id) and amount>=0 and int(stock[id])+amount<=int(rules.max_stock)

func crafting_error(recipe: String) -> String:
	if not rules.recipes.has(recipe): return "未知采集工艺"
	if crafts.size()>=int(rules.max_craft_records): return "加工来源记录已满"
	for id in rules.recipes[recipe].natural_inputs:
		if int(stock[id])<int(rules.recipes[recipe].natural_inputs[id]): return "缺少"+str(rules.resources[id].name)+"，先到星球采集"
	return ""

func reserve(recipe: String,serial: int) -> String:
	var error=crafting_error(recipe)
	if not error.is_empty(): return error
	var inputs: Dictionary=rules.recipes[recipe].natural_inputs
	for id in inputs: stock[id]-=int(inputs[id])
	crafts[str(serial)]={"recipe":recipe,"inputs":inputs.duplicate(),"complete":false}; revision+=1
	return ""

func cancel(serial: int) -> String:
	var record: Dictionary=crafts.get(str(serial),{})
	if record.is_empty() or record.complete: return "找不到预留材料"
	for id in record.inputs:
		if not can_add(id,int(record.inputs[id])): return "材料格已满，先消耗一些材料再取消"
	for id in record.inputs: stock[id]+=int(record.inputs[id])
	crafts.erase(str(serial)); revision+=1
	return ""

func plant(key: String,world: Dictionary,c) -> String:
	if c.blocks.get(key,{}).get("kind")!="planter": return "请瞄准你放置的种植箱"
	if gardens.has(key): return "这箱已有作物，成熟后先收获"
	if world.seeds<1: return "种子不足"
	world.seeds-=1
	gardens[key]={"growth":0.0,"moisture":float(rules.garden.initial_moisture),"waterings":0}
	revision+=1; return "播下一份谷物种子；土壤偏干，请给这箱浇水"

func water_error(key: String) -> String:
	if not gardens.has(key): return "先在种植箱播种"
	if gardens[key].moisture>0.75: return "这箱土壤已经湿润，无需重复浇水"
	return ""

func water(key: String) -> void:
	gardens[key].moisture=minf(1,gardens[key].moisture+float(rules.garden.water_add)); gardens[key].waterings+=1; revision+=1

func harvest(key: String,world: Dictionary) -> String:
	if not gardens.has(key): return "箱里还没有作物；从背包装备种子"
	if gardens[key].growth<1: return "作物尚未成熟"
	var amount=int(rules.garden.harvest_grain)
	if not can_add("grain",amount): return "谷穗格已满，先取用收获"
	stock.grain+=amount; world.seeds+=int(rules.garden.harvest_seeds); gardens.erase(key); revision+=1
	return "收入背包：谷穗 ×%d，留种 ×%d；回浮岛仍可取用" % [amount,rules.garden.harvest_seeds]

func covered(b: Dictionary,c) -> bool:
	# A vertical column lookup stays bounded even with hundreds of planted boxes.
	for y in range(int(b.y)+2,c.base(c.cell(b))+int(c.rules.height_limit)+1):
		var roof: Dictionary=c.blocks.get(c.key(Vector3i(int(b.x),y,int(b.z))),{})
		if not roof.is_empty() and c.rules.kinds[roof.kind].get("roof",false): return true
	return false

func tick(world: Dictionary,c) -> void:
	for id in changed.keys():
		if changed[id].ready_at>0 and changed[id].ready_at<=world.elapsed: changed.erase(id); revision+=1
	for key in gardens:
		var plot: Dictionary=gardens[key]; var b: Dictionary=c.blocks[key]
		var roof=covered(b,c)
		var rain=float(rules.garden.rain_per_second) if int(world.elapsed)%int(rules.garden.rain_period_seconds)<int(rules.garden.rain_duration_seconds) and not roof else 0.0
		plot.moisture=clampf(plot.moisture-float(rules.garden.evaporation)*(float(rules.garden.roof_evaporation_multiplier) if roof else 1.0)+rain,0,1)
		if plot.moisture>=float(rules.garden.minimum_moisture): plot.growth=minf(1,plot.growth+(float(rules.garden.roof_growth_multiplier) if roof else 1.0)/float(rules.garden.growth_seconds))

func serialize() -> Dictionary:
	return {"version":1,"stock":stock.duplicate(),"changed":changed.duplicate(true),"crafts":crafts.duplicate(true),"gardens":gardens.duplicate(true)}

func restore(data,c,now: int) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	for field in ["stock","changed","crafts","gardens"]:
		if not data.get(field) is Dictionary: return false
	if data.stock.size()!=rules.resources.size() or data.changed.size()>int(rules.max_changed_nodes) or data.crafts.size()>int(rules.max_craft_records) or data.gardens.size()>c.blocks.size(): return false
	for id in rules.resources:
		if not _num(data.stock.get(id),0,rules.max_stock,true): return false
	for id in data.changed:
		var n=node(str(id)); var row=data.changed[id]
		if n.is_empty() or not row is Dictionary: return false
		var spec=rules.resources[n.kind]
		if not _num(row.get("hits"),0,int(spec.hits)-1,true) or not _num(row.get("ready_at"),0,now+int(spec.renew_seconds),true): return false
		if row.ready_at>0 and row.hits!=0: return false
	for id in data.crafts:
		var row=data.crafts[id]
		if not str(id).is_valid_int() or int(id)<1 or not row is Dictionary or not rules.recipes.has(row.get("recipe")) or not row.get("complete") is bool: return false
		if row.get("inputs")!=rules.recipes[row.recipe].natural_inputs: return false
	for key in data.gardens:
		var row=data.gardens[key]
		if c.blocks.get(key,{}).get("kind")!="planter" or not row is Dictionary: return false
		if not _num(row.get("growth"),0,1) or not _num(row.get("moisture"),0,1) or not _num(row.get("waterings"),0,1000000,true): return false
	stock=data.stock.duplicate(); changed=data.changed.duplicate(true); crafts=data.crafts.duplicate(true); gardens=data.gardens.duplicate(true); revision+=1
	return true

func _num(v,lo: float,hi: float,whole: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi and (not whole or v==floor(v))
