extends RefCounted
## Bounded needs, finite public supplies and jobs. No player inventory access during tick.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_ranch.json"))
var depot={"seed":0,"water":0,"timber":0,"stone":0,"fruit":0,"grain":0,"ration":0}
var lives={}
var life_groups={}
var facilities={}
var jobs={}
var trades={}
var revision=0
var garden_rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_field.json")).garden
const ITEMS=["seed","water","timber","stone","fruit","grain","ration"]
const TASKS=["闲逛","找草","吃草","找水","饮水","休息","受惊","被困","吃饲料"]

func depot_at(v) -> Vector2:
	return v.settlement.center()+Vector2(rules.depot_offset[0],rules.depot_offset[1])

func life(key: String) -> Dictionary:
	if not lives.has(key):
		if lives.size()>=int(rules.max_lives): return {}
		var group=_life_group(key)
		if not life_groups.has(group): life_groups[group]={}
		life_groups[group][key]=true
		lives[key]={"thirst":0.18,"fatigue":0.08,"fear":0.0,"trust":0.0,"task":"闲逛","fed_at":-1000,"hurt_at":-1000,"memory":[]}
	return lives[key]

func remember(row: Dictionary,text: String) -> void:
	if text in row.memory: row.memory.erase(text)
	row.memory.push_front(text)
	while row.memory.size()>int(rules.max_memories): row.memory.pop_back()
	revision+=1

func attacked(e: Dictionary,time: int) -> void:
	var row=life(e.key)
	if row.is_empty(): return
	row.fear=minf(1,row.fear+0.6); row.trust=maxf(-1,row.trust-0.5); row.hurt_at=time
	remember(row,"你曾伤害过我；我会保持警惕")

func fed(e: Dictionary,time: int) -> void:
	var row=life(e.key)
	if row.is_empty(): return
	# Food always nourishes; repeated clicks and feeding immediately after violence do not buy trust.
	if time-row.fed_at>=int(rules.needs.feed_cooldown) and time-row.hurt_at>=120:
		row.trust=minf(1,row.trust+float(rules.needs.trust_per_feed)); row.fed_at=time
		remember(row,"你给过我食物")

func facility(key: String,kind: String) -> Dictionary:
	if not rules.facilities.has(kind): return {}
	if not facilities.has(key): facilities[key]={"kind":kind,"stock":0,"integrity":1.0}
	return facilities[key]

func sync(v) -> void:
	for key in facilities.keys():
		if not v.construction.blocks.has(key): facilities.erase(key)
	for key in v.construction.blocks:
		var b=v.construction.blocks[key]
		if rules.facilities.has(b.kind): facility(key,b.kind)
	v.construction.occupied=v.field.gardens.duplicate()
	v.construction.occupied.merge(v.organics.protected_keys())
	for key in facilities:
		if facilities[key].stock>0 or facilities[key].integrity<0.999: v.construction.occupied[key]=true
	for job in jobs.values():
		if not str(job.get("target","")).is_empty(): v.construction.occupied[job.target]=true

func fill(key: String,item: String,v) -> String:
	sync(v)
	if not facilities.has(key): return "请瞄准饮水槽或饲草架"
	var f=facilities[key]; var spec=rules.facilities[f.kind]
	if item!=spec.item: return "这个设施需要"+("水" if spec.item=="water" else "谷穗")
	if f.stock>=spec.capacity: return "设施已经装满"
	f.stock+=1; revision+=1; sync(v)
	return "已补充1份"+("饮水" if item=="water" else "谷穗")

func _move(e: Dictionary,target: Vector2,v,speed: float) -> bool:
	if e.position.distance_to(target)<0.8: return true
	var c=v.construction; var t=c.terrain; var delta=(target-e.position).normalized()
	for angle in [0.0,0.7,-0.7,1.3,-1.3]:
		var p=e.position+delta.rotated(angle)*minf(speed,e.position.distance_to(target))
		var local=(p-e.origin)/float(e.scale)
		var bound=3.5 if e.type=="animal" else 9.0
		if e.type in ["animal","wild"] and (absf(local.x)>bound or absf(local.y)>bound): continue
		if t.blocked(p,c.obstacles) or c.overlaps(p,t.ground(p),e.height) or absf(t.ground(p)-t.ground(e.position))>0.42: continue
		e.row.x=local.x; e.row.z=local.y; return false
	if e.has("key") and lives.has(e.key): lives[e.key].task="被困"
	return false

func _near_facility(e: Dictionary,kind: String,v) -> String:
	var best=""; var distance=INF
	var keys=facilities.keys(); keys.sort()
	for key in keys:
		var f=facilities[key]
		if f.kind!=kind or f.stock<=0 or f.integrity<=0.05: continue
		var b=v.construction.blocks[key]; var p=Vector2(b.x,b.z)
		var local=(p-e.origin)/float(e.scale)
		var bound=3.2 if e.type=="animal" else 8.7
		if absf(local.x)>bound or absf(local.y)>bound: continue
		var d=p.distance_squared_to(e.position)
		if d<distance: distance=d; best=key
	return best

func _use_facility(e: Dictionary,key: String,v) -> bool:
	var b=v.construction.blocks[key]; var p=Vector2(b.x,b.z)
	# Access an actual edge of the trough; animals cannot consume through a wall.
	var approach=p+(e.position-p).normalized()*1.05
	if not _move(e,approach,v,float(rules.needs.speed)): return false
	if e.position.distance_to(p)>1.9 or absf(v.construction.terrain.ground(e.position)-float(b.y))>0.6: return false
	var origin=Vector3(e.position.x,v.construction.terrain.ground(e.position)+0.65,e.position.y)
	var end=Vector3(b.x,b.y+0.65,b.z); var hit=v.construction.trace(origin,(end-origin).normalized())
	if hit.get("hit","")!=key: return false
	var f=facilities[key]; f.stock-=1; f.integrity=maxf(0,f.integrity-float(rules.facilities[f.kind].wear)); revision+=1
	return true

func tick(v) -> void:
	sync(v)
	if int(v.world.elapsed)%30==0: _prune(v)
	var n=rules.needs
	for e in v.combat.entities(v):
		if e.fish: continue
		var row=life(e.key)
		if row.is_empty(): continue
		row.fear=snappedf(maxf(0,row.fear-float(n.fear_decay)),0.000001)
		if e.type not in ["animal","wild"]: continue
		row.thirst=snappedf(minf(1,row.thirst+float(n.thirst_per_second)),0.000001); row.fatigue=snappedf(minf(1,row.fatigue+float(n.fatigue_per_second)),0.000001)
		e.row.hunger=snappedf(minf(1,float(e.row.get("hunger",0.15))+float(n.hunger_per_second)),0.000001)
		if v.combat.busy(e.key): row.task="受惊"; continue
		var site=v.population.sites[e.get("region",e.get("site",""))]
		var env=v.world.regions[e.region] if e.has("region") else v.population.rules.wild_environment
		var target=e.origin+Vector2(sin(float(v.world.elapsed)/30+e.id),cos(float(v.world.elapsed)/30+e.id))*2.5
		var was_resting=row.task=="休息"
		row.task="闲逛"
		if row.fear>0.3 and not v.actor.is_empty():
			var player=Vector2(v.actor.feet.x,v.actor.feet.z)
			if player.distance_to(e.position)<3:
				row.task="受惊"; _move(e,e.position+(e.position-player).normalized()*3,v,float(n.speed)); continue
		if row.fatigue>0.75 or (was_resting and row.fatigue>0.15):
			row.task="休息"; row.fatigue=maxf(0,row.fatigue-float(n.rest_per_second))
		elif row.thirst>0.35:
			row.task="找水"
			var key=_near_facility(e,"trough",v)
			if not key.is_empty():
				if _use_facility(e,key,v): row.thirst=maxf(0,row.thirst-float(n.drink_reduction)); row.task="饮水"
			else:
				target=e.origin+Vector2(-4,3)
				if _move(e,target,v,float(n.speed)) and env.water>0.15:
					row.thirst=maxf(0,row.thirst-float(n.drink_reduction)); row.task="饮水"
					e.row.health=maxf(0,e.row.health-float(env.pollution)*0.025)
		elif e.row.hunger>0.25:
			row.task="找草"; var key=_near_facility(e,"feeder",v)
			if not key.is_empty():
				if _use_facility(e,key,v): e.row.hunger=maxf(0,e.row.hunger-float(n.food_reduction)); row.task="吃饲料"
			elif not env.get("enclosed",false) and site.flora>0.15 and env.moisture>0.25:
				target=e.origin+Vector2(3.4+float(int(e.id)%3)*0.45,-2+float(int(e.id)%2)*0.65)
				if _move(e,target,v,float(n.speed)):
					e.row.hunger=maxf(0,e.row.hunger-float(n.graze_per_second)); site.flora=maxf(0,site.flora-0.002); row.task="吃草"
		else:
			if row.trust>0.25 and not v.actor.is_empty():
				var player=Vector2(v.actor.feet.x,v.actor.feet.z)
				if player.distance_to(e.position)<4: target=player+(e.position-player).normalized()*1.5
			_move(e,target,v,float(n.speed)*0.5)
		var stress=maxf(0,e.row.hunger-0.75)+maxf(0,row.thirst-0.75)
		e.row.health=clampf(e.row.health+(0.0002 if stress==0 else -0.003*stress),0,1)
	_tick_workers(v)
	sync(v)

func _life_group(key: String) -> String:
	return key.left(key.rfind(":"))

func _prune(v) -> void:
	# Only active locations can lose an animal/visitor; remote encounters are paused.
	var alive={}; var groups=[]
	for id in v.world.regions:
		groups.append("animal:"+str(id))
		for a in v.world.regions[id].animals: alive["animal:"+str(id)+":"+str(int(a.id))]=true
	for id in v.population.simulation_keys():
		groups.append("wild:"+str(id)); groups.append("visitor:"+str(id))
		for a in v.population.sites[id].animals: alive["wild:"+str(id)+":"+str(int(a.id))]=true
		for a in v.population.sites[id].visitors: alive["visitor:"+str(id)+":"+str(int(a.id))]=true
	groups.append("resident")
	for person in v.settlement.people: alive["resident:"+str(int(person.id))]=true
	for group in groups:
		for key in life_groups.get(group,{}).keys():
			if not alive.has(key): lives.erase(key); life_groups[group].erase(key)
		if life_groups.get(group,{}).is_empty(): life_groups.erase(group)
	for key in trades.keys():
		if _life_group(key) in groups and not alive.has(key): trades.erase(key)

func role(id: int) -> String:
	return "农夫 · 细心、亲近动物" if id==1 else "工匠 · 沉稳、爱惜材料"

func job_label(id: int) -> String:
	var j=jobs.get(str(id),{})
	if j.is_empty(): return "等候工作或物资"
	if j.get("blocked",0)>=12: return "路线受阻 · 需要留通道"
	return {"supply":"去仓库取料","work":"正在"+str(j.action),"return":"搬运收成回仓"}.get(j.stage,"工作中")

func _choose_job(id: int,v) -> Dictionary:
	var radius=float(rules.jobs.radius)
	var reserved={}
	for j in jobs.values(): reserved[j.target]=true
	var keys=v.construction.blocks.keys(); keys.sort()
	for key in keys:
		if reserved.has(key): continue
		var b=v.construction.blocks[key]
		if Vector2(b.x,b.z).distance_to(depot_at(v))>radius: continue
		var action=""; var item=""
		if id==1 and b.kind=="planter":
			var g=v.field.gardens.get(key,{})
			if g.is_empty() and depot.seed>0: action="播种"; item="seed"
			elif g.get("growth",0)>=1 and depot.grain<=int(rules.depot_capacity)-int(garden_rules.harvest_grain) and depot.seed<=int(rules.depot_capacity)-int(garden_rules.harvest_seeds): action="收获"
			elif not g.is_empty() and g.moisture<0.35 and depot.water>0: action="浇水"; item="water"
		if facilities.has(key):
			var f=facilities[key]; var spec=rules.facilities[f.kind]
			if id==2 and f.integrity<float(rules.jobs.repair_threshold) and depot[spec.repair]>0: action="修缮"; item=spec.repair
			elif id==1 and f.stock<2 and depot[spec.item]>0: action="补给"; item=spec.item
		if not action.is_empty(): return {"action":action,"item":item,"target":key,"stage":"supply" if not item.is_empty() else "work","cargo":{},"left":float(rules.jobs.work_seconds)}
	return {}

func _return_cargo(job: Dictionary) -> bool:
	for item in job.cargo:
		var qty=mini(int(job.cargo[item]),int(rules.depot_capacity)-int(depot[item]))
		depot[item]+=qty; job.cargo[item]-=qty
	for qty in job.cargo.values():
		if qty>0: return false
	return true

func _tick_workers(v) -> void:
	var present=[]
	for person in v.settlement.people: present.append(str(int(person.id)))
	for id in jobs.keys():
		if id not in present and _return_cargo(jobs[id]): jobs.erase(id)
	for person in v.settlement.people:
		var id=str(int(person.id)); var at=Vector2(person.x,person.z)
		var e={"row":person,"type":"resident","origin":Vector2.ZERO,"scale":1.0,"position":at,"height":1.65}
		if v.combat.busy("resident:"+id): continue
		# Residents eat only at the physical public store. Never debit the player's bag.
		if person.hunger>0.5:
			if _move(e,depot_at(v),v,float(rules.jobs.speed)):
				var food="ration" if depot.ration>0 else ("fruit" if depot.fruit>0 else "grain")
				if depot[food]>0: depot[food]-=1; person.hunger=maxf(0,person.hunger-0.4); v.settlement.meals+=1
			continue
		if not jobs.has(id):
			var next=_choose_job(int(person.id),v)
			if next.is_empty(): continue
			jobs[id]=next
		var j=jobs[id]
		if not v.construction.blocks.has(j.target): j.stage="return"
		if j.stage in ["supply","return"]:
			if not _move(e,depot_at(v),v,float(rules.jobs.speed)):
				j.blocked=int(j.get("blocked",0))+1 if Vector2(person.x,person.z)==at else 0
				continue
			j.blocked=0
			if j.stage=="return":
				if _return_cargo(j): jobs.erase(id); revision+=1
			elif depot.get(j.item,0)>0:
				depot[j.item]-=1; j.cargo[j.item]=1; j.stage="work"; revision+=1
			else: jobs.erase(id)
			continue
		var b=v.construction.blocks[j.target]; var p=Vector2(b.x,b.z)
		var approach=p+(at-p).normalized()*1.2
		if not _move(e,approach,v,float(rules.jobs.speed)):
			j.blocked=int(j.get("blocked",0))+1 if Vector2(person.x,person.z)==at else 0
			continue
		if at.distance_to(p)>2.0 or absf(v.construction.terrain.ground(at)-float(b.y))>0.6: continue
		var from=Vector3(at.x,v.construction.terrain.ground(at)+0.8,at.y); var to=Vector3(b.x,b.y+0.8,b.z)
		if v.construction.trace(from,(to-from).normalized()).get("hit","")!=j.target: continue
		j.blocked=0; j.left=maxf(0,j.left-1)
		if j.left>0: continue
		var success=false
		match j.action:
			"播种":
				if not v.field.gardens.has(j.target): v.field.gardens[j.target]={"growth":0.0,"moisture":v.field.rules.garden.initial_moisture,"waterings":0}; success=true
			"浇水":
				if v.field.water_error(j.target).is_empty(): v.field.water(j.target); success=true
			"收获":
				if v.field.gardens.get(j.target,{}).get("growth",0)>=1:
					v.field.gardens.erase(j.target); j.cargo={"grain":int(garden_rules.harvest_grain),"seed":int(garden_rules.harvest_seeds)}; v.settlement.harvests+=1; success=true
			"修缮":
				if facilities.has(j.target): facilities[j.target].integrity=minf(1,facilities[j.target].integrity+float(rules.jobs.repair_add)); success=true
			"补给":
				if facilities.has(j.target) and facilities[j.target].stock<rules.facilities[facilities[j.target].kind].capacity:
					facilities[j.target].stock+=1; success=true
		if success and j.action!="收获": j.cargo.clear()
		j.stage="return"; v.field.revision+=1; revision+=1

func serialize() -> Dictionary:
	return {"version":1,"depot":depot.duplicate(true),"lives":lives.duplicate(true),"facilities":facilities.duplicate(true),"jobs":jobs.duplicate(true),"trades":trades.duplicate(true)}

func _num(n,lo: float,hi: float,whole: bool=false) -> bool:
	return (n is int or n is float) and is_finite(float(n)) and n>=lo and n<=hi and (not whole or n==floor(n))

func restore(data,c,elapsed: int,people: Array) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	for key in ["depot","lives","facilities","jobs","trades"]:
		if not data.get(key) is Dictionary: return false
	if data.depot.size()!=ITEMS.size() or data.lives.size()>rules.max_lives or data.facilities.size()>c.rules.max_blocks or data.jobs.size()>2 or data.trades.size()>rules.max_lives: return false
	for item in ITEMS:
		if not _num(data.depot.get(item),0,rules.depot_capacity,true): return false
	for key in data.lives:
		var row=data.lives[key]
		if not key is String or key.length()>100 or not row is Dictionary: return false
		for k in ["thirst","fatigue","fear","trust"]:
			if not _num(row.get(k),-1 if k=="trust" else 0,1): return false
		for k in ["fed_at","hurt_at"]:
			if not _num(row.get(k),-1000,elapsed,true): return false
		if row.get("task") not in TASKS or not row.get("memory") is Array or row.memory.size()>rules.max_memories: return false
		for m in row.memory:
			if not m is String or m.length()>80: return false
	for key in data.facilities:
		var f=data.facilities[key]
		if not f is Dictionary or not rules.facilities.has(f.get("kind")) or c.blocks.get(key,{}).get("kind")!=f.kind: return false
		if not _num(f.get("stock"),0,rules.facilities[f.kind].capacity,true) or not _num(f.get("integrity"),0,1): return false
	var ids=[]
	for person in people: ids.append(str(int(person.id)))
	for id in data.jobs:
		var j=data.jobs[id]
		if id not in ["1","2"] or not j is Dictionary or j.get("stage") not in ["supply","work","return"] or j.get("action") not in ["播种","浇水","收获","补给","修缮"]: return false
		if not j.get("target") is String or j.target.length()>60 or j.get("item") not in ITEMS+[""] or not _num(j.get("left"),0,rules.jobs.work_seconds) or not j.get("cargo") is Dictionary or j.cargo.size()>2: return false
		if not _num(j.get("blocked",0),0,1e12,true): return false
		if j.stage!="return":
			var kind=c.blocks.get(j.target,{}).get("kind","")
			if j.action in ["播种","浇水","收获"]:
				if kind!="planter" or id!="1" or j.item!={"播种":"seed","浇水":"water","收获":""}[j.action]: return false
			else:
				if not rules.facilities.has(kind): return false
				if j.item!=rules.facilities[kind]["repair" if j.action=="修缮" else "item"]: return false
				if id!=("2" if j.action=="修缮" else "1"): return false
		for item in j.cargo:
			var maximum=int(garden_rules.harvest_grain) if item=="grain" else (int(garden_rules.harvest_seeds) if item=="seed" else 1)
			if item not in ITEMS or not _num(j.cargo[item],0,maximum,true): return false
			if j.action=="收获" and item not in ["grain","seed"]: return false
			if j.action!="收获" and (item!=j.item or j.cargo[item]>1): return false
		if j.stage=="supply" and not j.cargo.is_empty(): return false
		if j.stage=="work" and j.action=="收获" and not j.cargo.is_empty(): return false
		if j.stage=="work" and j.action!="收获" and j.cargo!={j.item:1}: return false
	for key in data.trades:
		if not key is String or key.length()>100 or not _num(data.trades[key],0,rules.trade.stock_per_visit,true): return false
	depot=data.depot.duplicate(true); lives=data.lives.duplicate(true); life_groups.clear()
	for key in lives:
		var group=_life_group(key)
		if not life_groups.has(group): life_groups[group]={}
		life_groups[group][key]=true
	facilities=data.facilities.duplicate(true); jobs=data.jobs.duplicate(true); trades=data.trades.duplicate(true)
	return true
