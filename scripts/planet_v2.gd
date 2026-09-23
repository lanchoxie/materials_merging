extends RefCounted
## Deterministic, bounded game simulation. Inventory transactions live in PlanetProgram.
const Population=preload("res://scripts/river_population.gd")
var population=Population.new()
const Construction=preload("res://scripts/river_construction.gd")
const Settlement=preload("res://scripts/river_settlement.gd")
var construction=Construction.new()
var settlement=Settlement.new()
const Inventory=preload("res://scripts/river_inventory.gd")
var inventory=Inventory.new()
const Field=preload("res://scripts/river_field.gd")
const Target=preload("res://scripts/river_target.gd")
var field=Field.new()
const Nature=preload("res://scripts/river_nature.gd")
const Combat=preload("res://scripts/river_combat.gd")
var nature=Nature.new()
var combat=Combat.new()
const Ranch=preload("res://scripts/river_ranch.gd")
var ranch=Ranch.new()
const Organics=preload("res://scripts/river_organics.gd")
var organics=Organics.new()
var actor: Dictionary={}
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_v2.json"))
var world: Dictionary={}
var active=false
var observer_id=0

func _init() -> void:
	world=fresh()
	_link_geometry()

func _link_geometry() -> void:
	construction.terrain.nature=nature
	field.terrain=construction.terrain; population.terrain=construction.terrain
	population.combat=combat; settlement.combat=combat
	population.ranch=ranch; settlement.ranch=ranch

func fresh() -> Dictionary:
	var w={"version":1,"elapsed":0,"remainder":0.0,"paused":false,"speed":1,"current_region":"wetland","next_animal":1,"seeds":int(rules.ecology.initial_seeds),"food":0,"events":[],"receipts":[],"regions":{}}
	for spec in rules.regions:
		var r=spec.duplicate(true)
		r.crops=[]; r.animals=[]; r.buildings={}; r.oxygen_fuel=0.0; r.filter_fuel=0.0; r.enclosed=false
		if spec.id in ["wetland","riverbank","meadow"]:
			var kind="marsh_fish" if spec.id!="meadow" else "meadow_herbivore"
			for i in range(4):
				r.animals.append(_animal(kind,int(w.next_animal),0,0.5+i*0.4)); w.next_animal+=1
		w.regions[spec.id]=r
	w.regions.wetland.crops.append({"crop":"reed","growth":0.25,"ready":false})
	w.regions.meadow.crops.append({"crop":"grain","growth":0.1,"ready":false})
	w.events.append({"time":0,"text":"河湾已苏醒。选择区域，把浮岛样品或成品带到这里。"})
	return w

func _animal(kind: String,id: int,generation: int,age: float=0.0) -> Dictionary:
	return {"id":id,"species":kind,"age":age,"health":0.9,"hunger":0.15,"generation":generation,"tolerance":0.30+_noise(id)*0.05,"state":"觅食","x":_noise(id)*0.7,"z":_noise(id*3)*0.7,"target_x":0.0,"target_z":0.0,"task_left":0.0}

func _noise(id: int) -> float:
	var n=(id*48271+271828)%2147483647
	n=(n*48271)%2147483647
	return float(n)/2147483647.0*2.0-1.0

func species(id: String) -> Dictionary:
	for s in rules.species:
		if s.id==id: return s
	return {}

func crop(id: String) -> Dictionary:
	for c in rules.crops:
		if c.id==id: return c
	return {}

func region() -> Dictionary:
	return world.regions[world.current_region]

func day() -> int:
	return int(float(world.elapsed)/float(rules.clock.day_seconds))

func season() -> int:
	return (day()/int(rules.clock.season_days))%4

func time_label() -> String:
	return "第 %d 天 · %s · %02d:00" % [day()+1,rules.clock.seasons[season()],int(fmod(float(world.elapsed)/float(rules.clock.day_seconds),1.0)*24)]

func _event(message: String) -> void:
	world.events.push_front({"time":int(world.elapsed),"text":message})
	if world.events.size()>32: world.events.pop_back()

func enter(id: String) -> String:
	if not world.regions.has(id): return "这个区域不存在"
	world.current_region=id
	return "正在观察"+str(region().name)

func set_paused(value: bool) -> String:
	world.paused=value
	return "时间已暂停" if value else "时间继续流动"

func set_speed(value: int) -> String:
	if value not in [1,4,8]: return "请选择1、4或8倍速度"
	world.speed=value
	return "时间倍率 %dx" % value

func tick(dt: float) -> void:
	if not active or world.paused or not is_finite(dt) or dt<=0 or dt>60: return
	advance(dt*float(world.speed))

func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds<=0 or seconds>480: return
	world.remainder+=seconds
	while float(world.remainder)>=1:
		world.remainder-=1.0; world.elapsed+=1
		_step()

func _step() -> void:
	nature.tick(construction.terrain)
	field.tick(world,construction,organics)
	organics.tick(field,construction)
	settlement.tick(world,construction)
	var ds=float(rules.clock.day_seconds)
	var changed_season=int(world.elapsed)%(int(ds)*int(rules.clock.season_days))==0
	if changed_season: _event("%s季来了：水位、光照与食物会随季节改变。" % rules.clock.seasons[season()])
	# JSON orders object keys differently; stable rule order keeps newborn IDs reproducible.
	for spec in rules.regions:
		var id=str(spec.id)
		var r: Dictionary=world.regions[id]
		var base: Dictionary=spec
		var rain=float(rules.ecology.rain[season()])*(1.0 if id in ["wetland","riverbank"] else 0.5)
		var shade=r.buildings.has("shade_canopy")
		var evaporation=float(rules.ecology.evaporation[season()])*(0.55 if shade else 1.0)
		r.water=clampf(r.water+(rain-evaporation)/ds,0,1)
		r.moisture=clampf(r.moisture+(r.water-r.moisture)*0.06/ds,0,1)
		r.temperature=float(base.temperature)+float(rules.ecology.temperature[season()])+sin(float(world.elapsed)/ds*TAU)*2
		r.oxygen=clampf(r.oxygen+(0.52-r.oxygen)*0.16/ds-r.pollution*0.06/ds,0,1)
		if r.oxygen_fuel>0:
			r.oxygen_fuel=maxf(0,r.oxygen_fuel-1); r.oxygen=clampf(r.oxygen+0.004,0,1)
		if r.filter_fuel>0:
			r.filter_fuel=maxf(0,r.filter_fuel-1); r.pollution=maxf(0,r.pollution-0.002)
		for plot in r.crops:
			if plot.ready: continue
			var c=crop(plot.crop)
			var water_ok=r.moisture>=c.moisture_min and r.moisture<=c.moisture_max
			var warm=r.temperature>=c.temperature_min and r.temperature<=c.temperature_max
			if water_ok and warm and r.nutrients>0.08:
				plot.growth=minf(1,plot.growth+(0.8 if shade else 1.0)/(float(c.days)*ds))
				r.nutrients=maxf(0,r.nutrients-float(c.nutrient_use)/(float(c.days)*ds))
			if plot.growth>=1:
				plot.ready=true; _event("%s的%s成熟了，可以收获留种。" % [r.name,c.name])
		var survivors=[]
		for a in r.animals:
			a.age+=1.0/ds
			var fish=a.species=="marsh_fish"
			if not fish:
				if a.health>0: survivors.append(a)
				continue
			var food_ok=r.water>0.15
			if r.enclosed and not fish and world.food>0 and int(world.elapsed)%int(ds)==0 and a.hunger>0.3:
				world.food-=1; a.hunger=maxf(0,a.hunger-0.6)
			a.hunger=clampf(a.hunger+(-0.12 if food_ok else 0.15)/ds,0,1)
			var stress=maxf(0,a.hunger-0.65)*0.25
			if fish: stress+=maxf(0,a.tolerance-r.oxygen)*0.7+maxf(0,0.15-r.water)*0.8
			else: stress+=maxf(0,0.1-r.water)*0.5
			a.health=clampf(a.health+(0.018-stress)/ds,0,1)
			a.state="缺氧" if fish and r.oxygen<a.tolerance else ("饥饿" if a.hunger>0.65 else ("圈养" if r.enclosed and not fish else "觅食"))
			if combat.busy("animal:"+id+":"+str(int(a.id))) and a.health>0:
				survivors.append(a); continue
			a.task_left=maxf(0,float(a.task_left)-1)
			if a.task_left<=0:
				var key=int(a.id)*97+int(world.elapsed)*31
				a.target_x=_noise(key)*(0.65 if r.enclosed else 1.4); a.target_z=_noise(key*3)*(0.65 if r.enclosed else 1.4)
				if a.hunger>0.65 and r.enclosed: a.target_x=0.0; a.target_z=0.85
				a.task_left=10+int(absf(_noise(key*7))*10)
			var position=Vector2(a.x,a.z).move_toward(Vector2(a.target_x,a.target_z),0.11 if a.health>0.5 else 0.04)
			var center: Vector3=construction.terrain.CENTERS[id]
			var spread=1.0 if r.enclosed else 2.2
			var next_at=Vector2(center.x,center.z)+position*spread
			if fish or not construction.overlaps(next_at,construction.terrain.ground(next_at),0.8): a.x=position.x; a.z=position.y
			if a.health<=0:
				_event("%s的%s #%d 死亡，死因与食物、水位和溶氧有关。" % [r.name,species(a.species).name,a.id])
			else: survivors.append(a)
		r.animals=survivors
		if int(world.elapsed)%int(ds)==0: _breed(r)
	var arrivals=population.advance(world.regions)
	for spec in rules.regions:
		var id=str(spec.id)
		if id not in arrivals: continue
		var r: Dictionary=world.regions[id]
		var kind="marsh_fish" if id in ["wetland","riverbank"] else "meadow_herbivore"
		var a=_animal(kind,int(world.next_animal),0,1.0); a.origin="迁入"
		world.next_animal+=1; r.animals.append(a)
		_event("%s栖地恢复，一只新的%s #%d 从外界迁入。" % [r.name,species(kind).name,a.id])

	ranch.tick(self)

func collect_wild(at: Vector2) -> String:
	if not population.harvest(at): return "走近成熟野生植被再采集；采集后需要等待再生"
	world.food+=1; _event("采集了一份野生植物，已放入星球粮仓；原处开始缓慢再生。")
	return "获得1份饲料，野生植被减少"

func _breed(r: Dictionary) -> void:
	for spec in rules.species:
		var parents=[]; var total=0
		for a in r.animals:
			if a.species!=spec.id: continue
			total+=1
			if a.age>=spec.mature_days and a.health>0.7 and a.hunger<0.45: parents.append(a)
		if parents.size()<2 or total>=int(spec.max_population) or day()%int(rules.ecology.birth_interval_days)!=0: continue
		parents.sort_custom(func(a,b): return a.generation>b.generation if a.generation!=b.generation else a.health>b.health)
		var a=parents[0]; var b=parents[1]
		var child=_animal(spec.id,int(world.next_animal),maxi(a.generation,b.generation)+1)
		child.tolerance=clampf((a.tolerance+b.tolerance)*0.5+_noise(int(world.next_animal)*97)*float(rules.ecology.mutation_range),0.1,0.65)
		world.next_animal+=1; r.animals.append(child)
		_event("%s诞生%s #%d · 谱系第%d代，继承双亲的耐缺氧性状。" % [r.name,spec.name,child.id,child.generation+1])

func plant(kind: String) -> String:
	if crop(kind).is_empty(): return "未知种子"
	if world.seeds<1: return "种子不足；收获成熟作物可留种"
	if region().crops.size()>=int(rules.ecology.max_plots): return "这里的种植位已用完"
	world.seeds-=1; region().crops.append({"crop":kind,"growth":0.0,"ready":false})
	_event("在%s播下%s。" % [region().name,crop(kind).name])
	return "已播种，湿度和温度合适时生长"

func harvest() -> String:
	var ready=0; var remaining=[]
	for plot in region().crops:
		if plot.ready: ready+=1
		else: remaining.append(plot)
	if ready==0: return "作物尚未成熟"
	var seeds=ready*int(rules.ecology.harvest_seeds); var food=ready*int(rules.ecology.harvest_food)
	region().crops=remaining; world.seeds+=seeds; world.food+=food
	settlement.harvests+=ready
	_event("%s收获%d块作物，获得%d份饲料与%d份种子。" % [region().name,ready,food,seeds])
	return "收获已进入星球粮仓"

func toggle_pen() -> String:
	if not region().buildings.has("frame_bundle"): return "先从浮岛带来结构构件包，建造围栏"
	region().enclosed=not region().enclosed
	return "围栏关闭，小兽会消耗粮仓饲料" if region().enclosed else "围栏打开，小兽恢复自然觅食"

func quote(region_id: String,recipe_id: String) -> String:
	if not world.regions.has(region_id): return "这个区域不存在"
	if not rules.products.has(recipe_id): return "尚未定义这种材料的环境用途"
	if world.receipts.size()>=256: return "本片试验区已达到256次投放上限"
	var r: Dictionary=world.regions[region_id]; var p: Dictionary=rules.products[recipe_id]
	if p.get("aquatic",false) and region_id not in ["wetland","riverbank"]: return "请投到湿地或河岸水域"
	if p.get("land",false) and region_id not in ["meadow","highland"]: return "请投到草甸或高地"
	if p.get("requires","")!="" and not r.buildings.has(p.requires): return "先安装"+str(rules.products[p.requires].name)
	if p.effect=="building" and r.buildings.has(recipe_id): return "这里已经安装了这个设施"
	if p.effect=="water" and r.water>0.94: return "水位已高，暂时不需要补水"
	if p.effect=="oxygen" and r.oxygen>0.94: return "溶氧已高，暂时不需要补充"
	if p.effect=="oxygen_fuel" and r.oxygen_fuel>0: return "供氧器仍有补给，请用完再添加"
	if p.effect=="filter_fuel" and r.filter_fuel>0: return "滤盒仍在使用，请用完再更换"
	if p.effect=="nutrient" and r.nutrients>0.94: return "营养已足，暂时不需要添加"
	return ""

func deploy(region_id: String,recipe_id: String,receipt: Dictionary) -> String:
	var error=quote(region_id,recipe_id)
	if not error.is_empty(): return error
	var r: Dictionary=world.regions[region_id]; var p: Dictionary=rules.products[recipe_id]
	match p.effect:
		"water": r.water=minf(1,r.water+p.amount); r.moisture=minf(1,r.moisture+p.amount*0.4)
		"oxygen": r.oxygen=minf(1,r.oxygen+p.amount)
		"building": r.buildings[recipe_id]=true
		"oxygen_fuel": r.oxygen_fuel=float(p.amount)
		"filter_fuel": r.filter_fuel=float(p.amount)
		"nutrient": r.nutrients=minf(1,r.nutrients+p.amount); r.pollution=minf(1,r.pollution+p.amount*0.25)
	var record=receipt.duplicate(true); record.region=region_id; record.use=recipe_id; record.time=int(world.elapsed)
	world.receipts.append(record)
	_event("%s收到%s：%s" % [r.name,p.name,p.description])
	return "已消耗1份库存，将%s送达%s" % [p.name,r.name]

func serialize() -> Dictionary:
	organics.prune_empty(construction)
	return {"version":1,"world":world.duplicate(true),"population":population.serialize(),"construction":construction.serialize(),"settlement":settlement.serialize(),"inventory":inventory.serialize(),"field":field.serialize(),"nature":nature.serialize(),"combat":combat.serialize(),"ranch":ranch.serialize(),"organics":organics.serialize()}

func _number(v,lo: float,hi: float,whole: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi and (not whole or float(v)==floor(float(v)))

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("world") is Dictionary: return false
	var w: Dictionary=data.world
	if w.get("version")!=1 or not w.get("paused") is bool or not _number(w.get("speed"),1,8,true): return false
	if int(w.speed) not in [1,4,8]: return false
	if not _number(w.get("elapsed"),0,1e12,true) or not _number(w.get("remainder"),0,0.999999999): return false
	for key in ["seeds","food"]:
		if not _number(w.get(key),0,1e12,true): return false
	if not _number(w.get("next_animal"),1,1e12,true): return false
	if not w.get("regions") is Dictionary or w.regions.size()!=rules.regions.size() or not w.regions.has(w.get("current_region")): return false
	var ids=[]
	for spec in rules.regions:
		var r=w.regions.get(spec.id)
		if not r is Dictionary or r.get("id")!=spec.id or r.get("name")!=spec.name or r.get("terrain")!=spec.terrain or absf(float(r.get("elevation",-99))-float(spec.elevation))>0.00001: return false
		for key in ["water","moisture","oxygen","nutrients","pollution"]:
			if not _number(r.get(key),0,1): return false
		if not _number(r.get("temperature"),-100,100): return false
		for key in ["oxygen_fuel","filter_fuel"]:
			if not _number(r.get(key),0,80): return false
		if not r.get("enclosed") is bool or not r.get("buildings") is Dictionary or r.buildings.size()>4: return false
		for key in r.buildings:
			if rules.products.get(key,{}).get("effect")!="building" or r.buildings[key]!=true: return false
		if r.enclosed and not r.buildings.has("frame_bundle"): return false
		if not r.get("crops") is Array or r.crops.size()>4 or not r.get("animals") is Array or r.animals.size()>40: return false
		for c in r.crops:
			if not c is Dictionary or crop(str(c.get("crop",""))).is_empty() or not _number(c.get("growth"),0,1) or not c.get("ready") is bool: return false
			if c.ready!=(c.growth==1): return false
		var counts={}
		for a in r.animals:
			if not a is Dictionary or not _number(a.get("id"),1,float(w.next_animal)-1,true) or int(a.id) in ids: return false
			ids.append(int(a.id)); var s=species(str(a.get("species","")))
			if s.is_empty() or not _number(a.get("age"),0,1e12) or not _number(a.get("generation"),0,1e12,true): return false
			for key in ["health","hunger","tolerance"]:
				if not _number(a.get(key),0,1): return false
			for key in ["x","z","target_x","target_z"]:
				if not _number(a.get(key),-3.5 if key in ["x","z"] else -1.5,3.5 if key in ["x","z"] else 1.5): return false
			if not _number(a.get("task_left"),0,20): return false
			if a.get("state") not in ["觅食","圈养","饥饿","缺氧"]: return false
			counts[a.species]=int(counts.get(a.species,0))+1
			if counts[a.species]>s.max_population: return false
	if not w.get("events") is Array or w.events.size()>32 or not w.get("receipts") is Array or w.receipts.size()>256: return false
	for e in w.events:
		if not e is Dictionary or not _number(e.get("time"),0,w.elapsed,true) or not e.get("text") is String or e.text.length()>240: return false
	for r in w.receipts:
		if not r is Dictionary or not w.regions.has(r.get("region")) or not rules.products.has(r.get("use")) or not _number(r.get("time"),0,w.elapsed,true): return false
		var rule: Dictionary=rules.products[r.use]
		if rule.get("aquatic",false) and r.region not in ["wetland","riverbank"]: return false
		if rule.get("land",false) and r.region not in ["meadow","highland"]: return false
	for id in w.regions:
		var installed={}
		for receipt in w.receipts:
			if receipt.region!=id: continue
			var rule: Dictionary=rules.products[receipt.use]
			if rule.get("requires","")!="" and not installed.has(rule.requires): return false
			if rule.effect=="building":
				if installed.has(receipt.use): return false
				installed[receipt.use]=true
		if installed!=w.regions[id].buildings: return false
		if w.regions[id].oxygen_fuel>0 and not installed.has("oxygen_station"): return false
		if w.regions[id].filter_fuel>0 and not installed.has("screen_station"): return false
	var restored_population=Population.new()
	if data.has("population") and not restored_population.restore(data.population): return false
	var restored_nature=Nature.new()
	var restored_construction=Construction.new()
	if data.has("nature") and not restored_nature.restore(data.nature,restored_construction.terrain): return false
	restored_construction.terrain.nature=restored_nature
	var restored_combat=Combat.new()
	if data.has("combat") and not restored_combat.restore(data.combat): return false
	if data.has("construction") and not restored_construction.restore(data.construction): return false
	var restored_settlement=Settlement.new()
	if data.has("settlement") and not restored_settlement.restore(data.settlement): return false
	var restored_inventory=Inventory.new()
	if data.has("inventory") and not restored_inventory.restore(data.inventory): return false
	var restored_field=Field.new()
	restored_field.terrain=restored_construction.terrain
	if data.has("field") and not restored_field.restore(data.field,restored_construction,int(w.elapsed)): return false
	var restored_ranch=Ranch.new()
	if data.has("ranch") and not restored_ranch.restore(data.ranch,restored_construction,int(w.elapsed),restored_settlement.people): return false
	var restored_organics=Organics.new()
	if data.has("organics") and not restored_organics.restore(data.organics,restored_construction): return false
	organics=restored_organics
	ranch=restored_ranch
	field=restored_field; restored_construction.occupied=field.gardens
	inventory=restored_inventory
	world=w.duplicate(true); population=restored_population; construction=restored_construction; settlement=restored_settlement; nature=restored_nature; combat=restored_combat; actor={}; active=false
	_link_geometry()
	ranch.sync(self)
	return true
