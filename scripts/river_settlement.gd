extends RefCounted
## A small persistent community, sharing the same ecology and material stock.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_settlement.json"))
var era=0
var harvests=0
var meals=0
var energy=0.0
var people: Array=[]
var irrigation=false
var combat
var world_radius=float(JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_exploration.json")).radius)
var ranch
var recruit_serial=1

func center() -> Vector2:
	return Vector2(rules.center[0],rules.center[1])

func title() -> String:
	return rules.eras[era].name

func checklist(world: Dictionary, construction) -> Array:
	var rows=[]; var shelter=construction.shelter_cells(center(),rules.radius)
	if era==0:
		var r: Dictionary=rules.agrarian
		rows.append(_condition("blocks","营地木构",construction.count_kind("block",center(),rules.radius),r.blocks,"采木料 → 工艺车间木墙包；放在草甸营地14米内"))
		rows.append(_condition("shelter","屋顶下可站立空地",shelter,r.shelter_cells,"立柱撑起屋顶；正下方留足1.75米，不能用实心堆块代替"))
		rows.append(_condition("harvests","实际作物收获",harvests,r.harvests,"种植箱或河湾田地成熟后收获；采野果不算作物收获"))
		rows.append(_condition("food","粮食储备",world.food+stored_food(),r.food,"田地收获入口粮；箱中谷穗可存公共仓库，也计入储备"))
		rows.append(_condition("water","草甸水位（%）",world.regions.meadow.water*100,r.water*100,"背包水样 → 起始草甸区域补水；给种植箱浇水不改变区域水位"))
	elif era==1:
		var r: Dictionary=rules.modern
		rows.append(_condition("shelter","仍可使用的住处",shelter,r.shelter_cells,"保留营地内的屋顶与净空；拆掉住处后不能晋级"))
		rows.append(_condition("solar","营地已安装光伏",construction.count_kind("solar",center(),rules.radius),r.solar,"工艺车间制造光伏 → 背包装备 → 营地14米内放置"))
		rows.append(_condition("harvests","累计作物收获",harvests,r.harvests,"持续种植并收获；已有收获保留"))
		rows.append(_condition("meals","居民实际用餐",meals,r.meals,"把口粮、谷穗或野果存公共仓库；居民走到仓库吃掉才计次"))
		var residents=0
		for p in people:
			if p.health>=r.health and p.hunger<=r.hunger_max: residents+=1
		rows.append(_condition("residents","安居居民",residents,r.residents,"至少一位健康≥50%、饥饿≤65%的居民；保留水源、住房和食物"))
		rows.append(_condition("food","公共仓库食物",stored_food(),r.depot_food,"村庄页存入口粮、谷穗或野果；背包里的食物尚未供给居民"))
		rows.append(_condition("water","公共仓库水样",ranch.depot.water if ranch!=null else 0,r.depot_water,"村庄页存入反应釜生产并收获的水样；区域水位不能替代仓库水"))
		rows.append(_condition("energy","已积蓄太阳能服务点",energy,r.energy,"白天实际发电积蓄到2点；暂停或夜间不发电"))
	return rows

func stored_food() -> int:
	return int(ranch.depot.ration+ranch.depot.grain+ranch.depot.fruit) if ranch!=null else 0

func _condition(id: String,label: String,value: float,required: float,hint: String) -> Dictionary:
	return {"id":id,"label":label,"value":value,"required":required,"complete":value+0.000001>=required,"hint":hint}

func requirements(world: Dictionary, construction) -> String:
	var lines=[]
	for row in checklist(world,construction):
		lines.append(("✓ " if row.complete else "○ ")+row.label+" · %.1f / %.1f" % [row.value,row.required]+("" if row.complete else "\n"+row.hint))
	return "\n\n".join(lines) if not lines.is_empty() else "生态站已成立；现阶段没有下一时代。工业文明、史前物种与未来科技尚未实装。"

func ready(world: Dictionary, construction) -> bool:
	var rows=checklist(world,construction)
	return not rows.is_empty() and rows.all(func(row): return row.complete)

func advance_era(world: Dictionary, construction) -> String:
	if not ready(world,construction): return "还需要完成："+requirements(world,construction)
	era+=1
	if era==1:
		for i in range(2): people.append({"id":i+1,"name":["禾苗","石川"][i],"health":0.9,"hunger":0.1,"x":13.0+i,"z":13.0,"task":"安家"})
	return "进入"+title()+"。动物、作物和自建建筑继续保留。"

func recruit_error(construction) -> String:
	if era==0: return "先建立农耕聚落"
	if people.size()>=2: return "两处居民岗位已有人居住"
	if construction.shelter_cells(center(),rules.radius)<int(rules.agrarian.shelter_cells): return "先修复营地住处，留下两格可站立空间"
	if ranch==null or stored_food()<int(rules.recruitment.food) or ranch.depot.water<int(rules.recruitment.water): return "邀请新旅人需要公共仓库2份食物、1份水样作为安家补给"
	return ""

func recruit(construction) -> String:
	var error=recruit_error(construction)
	if not error.is_empty(): return error
	var role=1
	for p in people:
		if int(p.id)==1: role=2
	var left=int(rules.recruitment.food)
	for food in ["ration","grain","fruit"]:
		var used=mini(left,int(ranch.depot[food])); ranch.depot[food]-=used; left-=used
	ranch.depot.water-=int(rules.recruitment.water); ranch.revision+=1
	var key="resident:"+str(role)
	ranch.lives.erase(key)
	if combat!=null: combat.records.erase(key)
	people.append({"id":role,"name":"新旅人 %d" % recruit_serial,"generation":recruit_serial,"health":0.9,"hunger":0.1,"x":12.0+role,"z":13.0,"task":"安家"})
	recruit_serial+=1
	return "新旅人带着安家补给入住空缺岗位；原来的居民不会复活，既有时代和记录保留"

func tick(world: Dictionary, construction) -> void:
	irrigation=false
	if era==0: return
	var meadow: Dictionary=world.regions.meadow
	var solar=construction.count_kind("solar",center(),rules.radius)
	var daylight=maxf(0,sin(float(world.elapsed)/60.0*TAU-PI/2))
	energy=minf(float(rules.energy_capacity),energy+solar*daylight*float(rules.solar_per_second))
	if era>=2 and energy>=float(rules.irrigation_energy) and meadow.water>0.12 and meadow.moisture<0.72:
		energy-=float(rules.irrigation_energy); meadow.water=maxf(0,meadow.water-0.0004); meadow.moisture=minf(1,meadow.moisture+0.0004); irrigation=true
	var housing=construction.shelter_cells(center(),rules.radius)>=int(rules.agrarian.shelter_cells)
	for person in people:
		person.hunger=minf(1,person.hunger+0.0015)
		if ranch==null and int(world.elapsed)%int(rules.meal_interval)==0 and world.food>0 and person.hunger>0.12:
			world.food-=1; person.hunger=maxf(0,person.hunger-0.35); meals+=1
		var safe=housing and meadow.water>0.12 and person.hunger<0.65
		person.health=clampf(person.health+(0.0002 if safe else -0.0007),0,1)
		var night=posmod(int(world.elapsed),60)<12 or posmod(int(world.elapsed),60)>48
		person.task="缺少食物" if person.hunger>0.65 else ("休息" if night else ("设备巡检" if era>=2 else "田间观察"))
		if ranch!=null: continue
		if combat!=null and combat.busy("resident:"+str(int(person.id))): continue
		var target=center()+Vector2(3,3+int(person.id)*0.7) if night else center()+Vector2(2+sin(world.elapsed*0.03+person.id)*2,-2)
		var pos=Vector2(person.x,person.z).move_toward(target,0.09)
		if not construction.overlaps(pos,construction.terrain.ground(pos),1.5): person.x=pos.x; person.z=pos.y
	people=people.filter(func(p): return p.health>0)

func serialize() -> Dictionary:
	return {"version":1,"era":era,"harvests":harvests,"meals":meals,"energy":energy,"people":people.duplicate(true),"recruit_serial":recruit_serial}

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	if not _num(data.get("recruit_serial",1),1,1e12,true): return false
	for field in ["era","harvests","meals"]:
		if not _num(data.get(field),0,2 if field=="era" else 1e12,true): return false
	if not _num(data.get("energy"),0,rules.energy_capacity) or not data.get("people") is Array or data.people.size()>(0 if data.era==0 else 2): return false
	var ids=[]
	for p in data.people:
		if not p is Dictionary or not _num(p.get("id"),1,2,true) or p.id in ids: return false
		ids.append(p.id)
		if not _num(p.get("generation",0),0,float(data.get("recruit_serial",1))-1,true): return false
		var name="新旅人 %d" % int(p.generation) if p.get("generation",0)>0 else ["禾苗","石川"][int(p.id)-1]
		if p.get("name")!=name or p.get("task") not in ["安家","缺少食物","休息","田间观察","设备巡检"]: return false
		for field in ["health","hunger"]:
			if not _num(p.get(field),0,1): return false
		for field in ["x","z"]:
			if not _num(p.get(field),-world_radius,world_radius): return false
	era=int(data.era); harvests=int(data.harvests); meals=int(data.meals); energy=float(data.energy); people=data.people.duplicate(true); recruit_serial=int(data.get("recruit_serial",1))
	return true

func _num(v,lo: float,hi: float,whole: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi and (not whole or v==floor(v))
