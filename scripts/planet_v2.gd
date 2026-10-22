extends RefCounted
const Shape=preload("res://scripts/planet_shape.gd")
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
const Journey=preload("res://scripts/river_journey.gd")
var journey=Journey.new()
## v0.32 Earth: climate field, atmosphere and machines.
const Climate=preload("res://scripts/planet_environment.gd")
var environment=Climate.new()
## v0.36: weather incidents (storm / flood / drought) and the 标本图鉴.
const Incidents=preload("res://scripts/planet_incidents.gd")
var incidents=Incidents.new()
const Specimens=preload("res://scripts/planet_specimens.gd")
var specimens=Specimens.new()
var actor: Dictionary={}
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_v2.json"))
var world: Dictionary={}
var active=false
var observer_id=0
## v0.39 timeline: "present" or "ice" (see rules.epochs). The time gate swaps whole PlanetV2 saves.
var epoch="present"
## v0.41: where this era's rover is parked ({} = not here yet), and whether the player is driving.
var rover_at: Dictionary={}
var driving=false
## v0.45 盾构机: where it stands ({x, y, z} floor cell, facing 0–3, grade −1/0/1) and whether the
## player is in its seat.
var tbm_at: Dictionary={}
var boring=false
## v0.68: additional TBM units deployed alongside the primary one (up to 2 extra).
var tbm_fleet: Array=[]  # [{x,y,z,facing,grade}, ...]
## v0.48: which planet this world is (data/planets.json), and the 星际飞船 parked here ({} = not
## here). The ship travels with the player between planets.
var planet="earth"
var ship_at: Dictionary={}
## v0.49: the native tribe (present-day Earth only).
const Natives=preload("res://scripts/river_natives.gd")
var natives=Natives.new()
## v0.50: where the player last stood, so first person resumes there instead of the spawn point.
var walk_at: Dictionary={}
## v0.47 小飞机: where it is parked ({x, z, heading}) and whether the player is flying it.
var plane_at: Dictionary={}
var flying=false
## v0.68: wearable equipment currently active (headlamp, insulated_suit → key present = equipped).
var equipped: Dictionary={}
## v0.68: player-placed map waypoints [{x, z, label}] — shown on globe, navigated in first person.
var waypoints: Array=[]
## v0.68: mods installed on each vehicle {"rover":["solar_panel","battery_pack",...], ...}
var vehicle_mods: Dictionary={"rover":[],"plane":[],"tbm":[],"ship":[]}

func _init() -> void:
	world=fresh()
	_link_geometry()
	natives.enabled=true

func _link_geometry() -> void:
	construction.terrain.nature=nature
	construction.terrain.environment=environment; population.environment=environment; nature.climate=environment
	field.terrain=construction.terrain; population.terrain=construction.terrain
	population.combat=combat; settlement.combat=combat
	population.ranch=ranch; settlement.ranch=ranch

func set_epoch(id: String) -> void:
	epoch=id if rules.epochs.has(id) else "present"
	var e: Dictionary=epoch_info()
	environment.epoch_offset=float(e.get("temperature",0.0)); environment._shift=environment.warming()+environment.epoch_offset
	population.cold_min=float(e.get("cold_min",5.0)); population.wild_species=e.get("wild",[])

func epoch_info() -> Dictionary:
	return rules.epochs.get(epoch,{})

## A brand-new world in another timeline (the first trip through the time gate).
## v0.48: generate this world as `id` (Earth's profile is {} so Earth stays byte-identical).
func set_planet(id: String) -> void:
	planet=id if Shape.planets().planets.has(id) else "earth"
	natives.enabled=planet=="earth" and epoch=="present"
	var p: Dictionary={} if planet=="earth" else Shape.profile_of(planet)
	construction.terrain.set_profile(p); environment.set_profile(p)

func planet_info() -> Dictionary:
	return Shape.profile_of(planet)

## Earth's timelines keep their old keys ("present", "ice"); other planets are "<planet>:<epoch>".
func world_key() -> String:
	return epoch if planet=="earth" else "%s:%s" % [planet,epoch]

func begin_planet(id: String) -> void:
	set_planet(id); begin_epoch("present")
	if planet!="earth": world.events=[{"time":0,"text":"飞船降落在%s：%s" % [str(planet_info().name),str(planet_info().description)]}]

func begin_epoch(id: String) -> void:
	set_epoch(id); world=fresh()
	natives=Natives.new(); natives.enabled=planet=="earth" and epoch=="present"
	if not bool(epoch_info().get("crops",true)):
		for r in world.regions.values(): r.crops=[]
	world.events=[{"time":0,"text":str(epoch_info().get("story","河湾已苏醒。"))}]
	# v0.69: non-Earth planets start barren — no animals, crops, or buildings.
	if planet!="earth":
		for r in world.regions.values():
			r.animals=[]; r.crops=[]; r.buildings={}; r.enclosed=false
		settlement=Settlement.new()
		# Spawn planet-specific creatures across all regions.
		var planet_species=rules.species.filter(func(s): return str(s.get("planet",""))==planet)
		if not planet_species.is_empty():
			var regions=world.regions.values()
			var nid=int(world.next_animal)
			for spec in planet_species:
				var count=mini(int(spec.get("max_population",4)),3)  # 3 per species per region start
				for reg in regions:
					for i in range(count):
						reg.animals.append(_animal(str(spec.id),nid,0,randf()*0.8)); nid+=1
			world.next_animal=nid

## Weather for this timeline: the 冰河期 has its own list and odds, all year round.
func incident_kinds() -> Array:
	return epoch_info().get("incidents",settlement.incident_kinds())

func incident_chance() -> float:
	return float(epoch_info().get("chance",settlement.incident_chance()))

func incidents_all_seasons() -> bool:
	return bool(epoch_info().get("all_seasons",false))

## v0.39 cold: air temperature where the player stands (climate field + season + day + weather).
func air_temperature(p: Vector2) -> float:
	var ds=float(rules.clock.day_seconds)
	return environment.values(environment.cell_of(p)).y+float(rules.ecology.temperature[season()])+sin(float(world.elapsed)/ds*TAU)*2-float(incidents.region_mods("").get("chill",0.0))

## Felt temperature: air plus a campfire within reach, a roof overhead and the 保温服.
func felt_temperature(feet: Vector3) -> float:
	var c: Dictionary=rules.cold; var p=Vector2(feet.x,feet.z)
	var t=air_temperature(p)+combat.suit_warmth+(combat.food_warmth if combat.food_left>0.0 else 0.0)
	if construction.near_kind("campfire",feet,float(c.fire_radius)): t+=float(c.fire_warmth)
	if construction.roof_over(feet): t+=float(c.roof_warmth)
	return t

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
	var prefix="%s · " % str(epoch_info().name) if epoch!="present" else ""
	return prefix+"第 %d 天 · %s · %02d:00" % [day()+1,rules.clock.seasons[season()],int(fmod(float(world.elapsed)/float(rules.clock.day_seconds),1.0)*24)]

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
	environment.tick(construction)
	nature.tick(construction.terrain)
	field.tick(world,construction,organics)
	organics.tick(field,construction)
	settlement.tick(world,construction)
	incidents.step(self)
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
		var weather: Dictionary=incidents.region_mods(id)
		rain=0.0 if float(weather.rain)<0 else rain+float(weather.rain)*(1.0 if id in ["wetland","riverbank"] else 0.6)
		evaporation*=float(weather.evaporation)
		r.water=clampf(r.water+(rain-evaporation)/ds,0,1)
		if weather.flood: r.water=minf(1.0,r.water+0.5/ds)
		r.moisture=clampf(r.moisture+(r.water-r.moisture)*0.06/ds,0,1)
		var at: Vector3=construction.terrain.CENTERS[id]
		r.temperature=float(base.temperature)+float(rules.ecology.temperature[season()])+sin(float(world.elapsed)/ds*TAU)*2+environment.warming()+environment.epoch_offset+environment.local_heat(Vector2(at.x,at.z))-float(weather.get("chill",0.0))
		r.oxygen=clampf(r.oxygen+(0.52*(environment.o2/20.9)-r.oxygen)*0.16/ds-r.pollution*0.06/ds,0,1)
		if r.oxygen_fuel>0:
			r.oxygen_fuel=maxf(0,r.oxygen_fuel-1); r.oxygen=clampf(r.oxygen+0.004,0,1)
		if r.filter_fuel>0:
			r.filter_fuel=maxf(0,r.filter_fuel-1); r.pollution=maxf(0,r.pollution-0.002)
		for plot in r.crops:
			if plot.ready: continue
			var c=crop(plot.crop)
			var water_ok=r.moisture>=c.moisture_min and r.moisture<=c.moisture_max
			var warm=r.temperature>=c.temperature_min and r.temperature<=c.temperature_max
			# Flattened by a storm or standing in flood water: an unprotected crop stops growing.
			if water_ok and warm and r.nutrients>0.08 and float(weather.crop_loss)<=0.0:
				plot.growth=minf(1,plot.growth+(0.8 if shade else 1.0)*environment.co2_growth()/(float(c.days)*ds))
				r.nutrients=maxf(0,r.nutrients-float(c.nutrient_use)/(float(c.days)*ds))
			if float(weather.crop_loss)>0.0:
				var lost=minf(float(plot.growth),float(weather.crop_loss)/ds)
				plot.growth=float(plot.growth)-lost; incidents.record_crop_loss(lost)
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
	field.robot_tick(self)
	natives.tick(self)

func collect_wild(at: Vector2) -> String:
	if not population.harvest(at): return "走近成熟野生植被再采集；采集后需要等待再生"
	world.food+=1; _event("采集了一份野生植物，做成1份口粮放进背包；原处开始缓慢再生。")
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
	var seeds=0; var food=ready*int(rules.ecology.harvest_food)
	for i in range(ready):
		seeds+=1+(1 if Field.roll(str(world.current_region),int(world.elapsed)*13+i)<float(rules.ecology.get("harvest_seed_chance",0.5)) else 0)
	region().crops=remaining; world.seeds+=seeds; world.food+=food
	settlement.harvests+=ready
	_event("%s收获%d块作物，获得%d份饲料与%d份种子。" % [region().name,ready,food,seeds])
	return "收获做成了口粮，放进背包"

func toggle_pen() -> String:
	if not region().buildings.has("frame_bundle"): return "先从浮岛带来结构构件包，建造围栏"
	region().enclosed=not region().enclosed
	return "围栏关闭，小兽会吃背包里的口粮" if region().enclosed else "围栏打开，小兽恢复自然觅食"

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
	return {"version":1,"epoch":epoch,"world":world.duplicate(true),"population":population.serialize(),"construction":construction.serialize(),"settlement":settlement.serialize(),"inventory":inventory.serialize(),"field":field.serialize(),"nature":nature.serialize(),"combat":combat.serialize(),"ranch":ranch.serialize(),"organics":organics.serialize(),"journey":journey.serialize(),"environment":environment.serialize(),"terrain":construction.terrain.pads_serialize(),"incidents":incidents.serialize(),"specimens":specimens.serialize(),"rover":rover_at.duplicate(),"tbm":tbm_at.duplicate(),"tbm_fleet":tbm_fleet.duplicate(true),"plane":plane_at.duplicate(),"planet":planet,"ship":ship_at.duplicate(),"natives":natives.serialize(),"walk":walk_at.duplicate(),"driving":false,"flying":false,"boring":false,"equipped":equipped.duplicate(),"waypoints":waypoints.duplicate(true),"vehicle_mods":vehicle_mods.duplicate(true)}

## Every x/z an old save placed something at: built blocks and edited voxels.
func _legacy_points(data: Dictionary) -> Array:
	var points=[]
	var blocks=data.get("construction",{}).get("blocks",{}) if data.get("construction") is Dictionary else {}
	if blocks is Dictionary:
		for b in blocks.values():
			if b is Dictionary and (b.get("x") is float or b.get("x") is int) and (b.get("z") is float or b.get("z") is int): points.append(Vector2(b.x,b.z))
	var n=data.get("nature",{})
	if n is Dictionary:
		for k in (n.get("voxels",{}) if n.get("voxels") is Dictionary else {}):
			var parts=str(k).split(":")
			if parts.size()==3 and parts[0].is_valid_int() and parts[2].is_valid_int(): points.append(Vector2(int(parts[0]),int(parts[2])))
		for k in (n.get("edits",{}) if n.get("edits") is Dictionary else {}):
			var parts=str(k).split(":")
			if parts.size()==2 and parts[0].is_valid_int() and parts[1].is_valid_int(): points.append(Vector2(int(parts[0]),int(parts[1])))
	return points

func _number(v,lo: float,hi: float,whole: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi and (not whole or float(v)==floor(float(v)))

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("world") is Dictionary: return false
	if not data.get("epoch","present") is String or not rules.epochs.has(str(data.get("epoch","present"))): return false
	var parked=data.get("rover",{})
	if not parked is Dictionary: return false
	if not parked.is_empty():
		for k in ["x","z","heading"]:
			if not _number(parked.get(k),-9000,9000): return false
		# v0.42 planet: anywhere on the surface (the old 8 km disc check rejected far-north parking).
		if absf(float(parked.x))>8192.0 or absf(float(parked.z))>7600.0: return false
	if not data.get("planet","earth") is String or not Shape.planets().planets.has(str(data.get("planet","earth"))): return false
	var ship=data.get("ship",{})
	if not ship is Dictionary: return false
	if not ship.is_empty():
		if not _number(ship.get("x"),-8192,8192) or not _number(ship.get("z"),-7600,7600) or not _number(ship.get("heading"),-9000,9000): return false
	var stood=data.get("walk",{})
	if not stood is Dictionary: return false
	if not stood.is_empty():
		for k in ["x","z"]:
			if not _number(stood.get(k),-8192,8192): return false
		if not _number(stood.get("yaw"),-9000,9000) or not _number(stood.get("pitch"),-1.6,1.6): return false
	var aircraft=data.get("plane",{})
	if not aircraft is Dictionary: return false
	if not aircraft.is_empty():
		if not _number(aircraft.get("x"),-8192,8192) or not _number(aircraft.get("z"),-7600,7600) or not _number(aircraft.get("heading"),-9000,9000): return false
	var machine=data.get("tbm",{})
	if not machine is Dictionary: return false
	if not machine.is_empty():
		for k in ["x","z"]:
			if not _number(machine.get(k),-8192,8192,true): return false
		if not _number(machine.get("y"),-31,120,true) or not _number(machine.get("facing"),0,3,true) or not _number(machine.get("grade"),-2,2,true): return false
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
	# v0.48: the planet's generator first — everything below reads its terrain.
	var world_planet=str(data.get("planet","earth"))
	var world_profile: Dictionary={} if world_planet=="earth" else Shape.profile_of(world_planet)
	restored_construction.terrain.set_profile(world_profile)
	# v0.33.2: saves made before relief existed keep their old ground where they built or dug.
	if data.has("terrain"):
		if not restored_construction.terrain.pads_restore(data.terrain): return false
	else: restored_construction.terrain.set_pads(restored_construction.terrain.legacy_pads(_legacy_points(data)))
	if data.has("nature") and not restored_nature.restore(data.nature,restored_construction.terrain): return false
	restored_construction.terrain.nature=restored_nature
	var restored_combat=Combat.new()
	if data.has("combat") and not restored_combat.restore(data.combat): return false
	if data.has("construction") and not restored_construction.restore(data.construction): return false
	# v0.49: the tribe (older saves have none yet: a fresh tribe settles on present-day Earth).
	var restored_natives=Natives.new()
	if data.has("natives"):
		if not restored_natives.restore(data.natives,restored_construction): return false
	else:
		for b in restored_construction.blocks.values():
			if Natives.is_native(b): return false
		restored_natives.enabled=world_planet=="earth" and str(data.get("epoch","present"))=="present"
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
	var restored_environment=Climate.new()
	restored_environment.set_profile(world_profile)
	if data.has("environment") and not restored_environment.restore(data.environment): return false
	var restored_incidents=Incidents.new()
	if data.has("incidents") and not restored_incidents.restore(data.incidents,int(w.elapsed)): return false
	var restored_specimens=Specimens.new()
	if data.has("specimens") and not restored_specimens.restore(data.specimens): return false
	var restored_journey=Journey.new()
	if data.has("journey") and not restored_journey.restore(data.journey,restored_construction.terrain): return false
	journey=restored_journey
	incidents=restored_incidents; specimens=restored_specimens
	environment=restored_environment
	organics=restored_organics
	ranch=restored_ranch
	field=restored_field; restored_construction.occupied=field.gardens
	inventory=restored_inventory
	world=w.duplicate(true); population=restored_population; construction=restored_construction; settlement=restored_settlement; nature=restored_nature; combat=restored_combat; actor={}; active=false
	natives=restored_natives
	_link_geometry()
	planet=world_planet
	set_epoch(str(data.get("epoch","present")))
	ship_at={}
	if not ship.is_empty(): ship_at={"x":float(ship.x),"z":float(ship.z),"heading":float(ship.heading)}
	rover_at={}; driving=bool(data.get("driving",false))
	if not parked.is_empty(): rover_at={"x":float(parked.x),"z":float(parked.z),"heading":float(parked.heading)}
	walk_at={}
	if not stood.is_empty(): walk_at={"x":float(stood.x),"z":float(stood.z),"yaw":float(stood.yaw),"pitch":float(stood.pitch)}
	plane_at={}; flying=bool(data.get("flying",false))
	if not aircraft.is_empty(): plane_at={"x":float(aircraft.x),"z":float(aircraft.z),"heading":float(aircraft.heading)}
	tbm_at={}; boring=bool(data.get("boring",false))
	if not machine.is_empty(): tbm_at={"x":int(machine.x),"y":int(machine.y),"z":int(machine.z),"facing":int(machine.facing),"grade":int(machine.grade)}
	# v0.68: restore fleet units (ignore malformed entries silently).
	tbm_fleet=[]
	for m in data.get("tbm_fleet",[]):
		if m is Dictionary and _number(m.get("x"),-8192,8192,true) and _number(m.get("y"),-31,120,true) and _number(m.get("z"),-7600,7600,true) and _number(m.get("facing"),0,3,true) and _number(m.get("grade"),-2,2,true):
			tbm_fleet.append({"x":int(m.x),"y":int(m.y),"z":int(m.z),"facing":int(m.facing),"grade":int(m.grade)})
	# v0.68: restore equipped wearables (headlamp, insulated_suit etc.)
	equipped={}
	var eq=data.get("equipped",{})
	if eq is Dictionary:
		for k in eq:
			if k is String and k.length()<64: equipped[k]=true
	# v0.68: restore map waypoints [{x,z,label}].
	waypoints=[]
	for wp in data.get("waypoints",[]):
		if wp is Dictionary and _number(wp.get("x"),-8192,8192) and _number(wp.get("z"),-7600,7600) and wp.get("label") is String:
			waypoints.append({"x":float(wp.x),"z":float(wp.z),"label":str(wp.label).left(32)})
	# v0.68: restore vehicle mods.
	vehicle_mods={"rover":[],"plane":[],"tbm":[],"ship":[]}
	var vm=data.get("vehicle_mods",{})
	if vm is Dictionary:
		for vid in vehicle_mods:
			var arr=vm.get(vid,[])
			if arr is Array:
				for mid in arr:
					if mid is String and mid.length()<64: vehicle_mods[vid].append(mid)
	ranch.sync(self)
	return true
