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

func center() -> Vector2:
	return Vector2(rules.center[0],rules.center[1])

func title() -> String:
	return rules.eras[era].name

func requirements(world: Dictionary, construction) -> String:
	if era==0:
		var r: Dictionary=rules.agrarian
		return "草甸附近木构 %d/%d块\n屋顶下可住面积 %d/%d格\n收获 %d/%d · 粮仓 %d/%d · 水位 %.0f%%/%.0f%%" % [construction.count_kind("block",center(),rules.radius),r.blocks,construction.shelter_cells(center(),rules.radius),r.shelter_cells,harvests,r.harvests,world.food,r.food,world.regions.meadow.water*100,r.water*100]
	if era==1:
		var r: Dictionary=rules.modern
		return "草甸附近光伏 %d/%d · 收获 %d/%d · 供餐 %d/%d" % [construction.count_kind("solar",center(),rules.radius),r.solar,harvests,r.harvests,meals,r.meals]
	return "生态站已成立；照顾居民、保持水源，太阳能服务点会支持灌溉。"

func ready(world: Dictionary, construction) -> bool:
	if era==0:
		var r: Dictionary=rules.agrarian
		return construction.count_kind("block",center(),rules.radius)>=r.blocks and construction.shelter_cells(center(),rules.radius)>=r.shelter_cells and harvests>=r.harvests and world.food>=r.food and world.regions.meadow.water>=r.water
	if era==1:
		var r: Dictionary=rules.modern
		return construction.count_kind("solar",center(),rules.radius)>=r.solar and harvests>=r.harvests and meals>=r.meals and not people.is_empty()
	return false

func advance_era(world: Dictionary, construction) -> String:
	if not ready(world,construction): return "还需要完成："+requirements(world,construction)
	era+=1
	if era==1:
		for i in range(2): people.append({"id":i+1,"name":["禾苗","石川"][i],"health":0.9,"hunger":0.1,"x":13.0+i,"z":13.0,"task":"安家"})
	return "进入"+title()+"。动物、作物和自建建筑继续保留。"

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
		if int(world.elapsed)%int(rules.meal_interval)==0 and world.food>0 and person.hunger>0.12:
			world.food-=1; person.hunger=maxf(0,person.hunger-0.35); meals+=1
		var safe=housing and meadow.water>0.12 and person.hunger<0.65
		person.health=clampf(person.health+(0.0002 if safe else -0.0007),0,1)
		var night=posmod(int(world.elapsed),60)<12 or posmod(int(world.elapsed),60)>48
		person.task="缺少食物" if person.hunger>0.65 else ("休息" if night else ("设备巡检" if era>=2 else "田间观察"))
		if combat!=null and combat.busy("resident:"+str(int(person.id))): continue
		var target=center()+Vector2(3,3+int(person.id)*0.7) if night else center()+Vector2(2+sin(world.elapsed*0.03+person.id)*2,-2)
		var pos=Vector2(person.x,person.z).move_toward(target,0.09)
		if not construction.overlaps(pos,construction.terrain.ground(pos),1.5): person.x=pos.x; person.z=pos.y
	people=people.filter(func(p): return p.health>0)

func serialize() -> Dictionary:
	return {"version":1,"era":era,"harvests":harvests,"meals":meals,"energy":energy,"people":people.duplicate(true)}

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	for field in ["era","harvests","meals"]:
		if not _num(data.get(field),0,2 if field=="era" else 1e12,true): return false
	if not _num(data.get("energy"),0,rules.energy_capacity) or not data.get("people") is Array or data.people.size()>(0 if data.era==0 else 2): return false
	var ids=[]
	for p in data.people:
		if not p is Dictionary or not _num(p.get("id"),1,2,true) or p.id in ids: return false
		ids.append(p.id)
		if p.get("name")!=["禾苗","石川"][int(p.id)-1] or p.get("task") not in ["安家","缺少食物","休息","田间观察","设备巡检"]: return false
		for field in ["health","hunger"]:
			if not _num(p.get(field),0,1): return false
		for field in ["x","z"]:
			if not _num(p.get(field),-512,512): return false
	era=int(data.era); harvests=int(data.harvests); meals=int(data.meals); energy=float(data.energy); people=data.people.duplicate(true)
	return true

func _num(v,lo: float,hi: float,whole: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi and (not whole or v==floor(v))
