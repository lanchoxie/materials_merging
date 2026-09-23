extends RefCounted
## Fixed-step teaching ecology. No rendering, global wallet or unseeded randomness.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_habitat.json"))
const ACCOUNTS=["added","rain","drunk","evaporated","growth_water","overflow","grown","grazed","wilted","remains","scavenged","decayed"]
const ACTIONS=["rest","walk","drink","graze","scavenge","hunt","lost"]
const CAUSES=["","thirst","hunger","predation"]

func fresh(at: int=0,enabled: bool=false) -> Dictionary:
	var w={"model":rules.model,"era":rules.era,"enabled":enabled,"elapsed":0,"regions":{},"edges":{},"animals":[],"migrations":0,"kills":0,"flags":[],"history":[]}
	for id in rules.regions:
		var spec=rules.regions[id]; var r={"water":float(spec.water),"plants":float(spec.plants),"carrion":0.0,"shade":false}
		for key in ACCOUNTS: r[key]=0.0
		w.regions[id]=r
	for id in rules.edges: w.edges[id]={"built":bool(rules.edges[id].built),"open":bool(rules.edges[id].built)}
	for i in range(rules.animals.size()):
		var spec=rules.animals[i]
		w.animals.append({"id":i,"species":spec[0],"at":spec[1],"to":"","edge":"","progress":0.0,"alive":true,"health":100.0,"thirst":float(12+i),"hunger":float(16+i),"action":"rest","cause":"","cooldown":0,"journeys":0})
	_record(w,at); return w

func ids() -> Array:
	var result=[]
	for id in rules.regions: result.append("habitat_"+str(id))
	for id in rules.edges: result.append("crossing_"+str(id))
	return result

func can_deploy(w: Dictionary,site: String,recipe: String) -> bool:
	if not w.enabled: return false
	if site.begins_with("crossing_"):
		var edge=site.trim_prefix("crossing_")
		return w.edges.has(edge) and recipe=="habitat_bridge" and not w.edges[edge].built
	var id=site.trim_prefix("habitat_")
	if not site.begins_with("habitat_") or not w.regions.has(id): return false
	var r=w.regions[id]
	if recipe=="standard_water_crate": return r.water+rules.products.water_crate<=rules.limits.water and r.added+rules.products.water_crate<=rules.limits.ledger
	return recipe=="shade_canopy" and not r.shade

func deploy(w: Dictionary,site: String,recipe: String) -> void:
	if not can_deploy(w,site,recipe): return
	if recipe=="habitat_bridge": w.edges[site.trim_prefix("crossing_")]={"built":true,"open":true}; return
	var r=w.regions[site.trim_prefix("habitat_")]
	if recipe=="shade_canopy": r.shade=true
	else: r.water+=float(rules.products.water_crate); r.added+=float(rules.products.water_crate)

func control(w: Dictionary,id: String) -> String:
	if not w.enabled or not w.edges.has(id) or not w.edges[id].built: return "先投放连接桥，才能开放这条通道"
	w.edges[id].open=not w.edges[id].open
	return str(rules.edges[id].name)+("已开放，捕食者也能通过" if w.edges[id].open else "已关闭；在途动物完成当前一段后停下")

func wet(w: Dictionary) -> bool: return int(w.elapsed)%int(rules.climate.cycle)>=int(rules.climate.dry_seconds)

func occupants(w: Dictionary,id: String,predators: bool=false) -> int:
	var n=0
	for p in w.animals:
		if p.alive and p.to.is_empty() and p.at==id and (rules.species[p.species].diet=="carrion")==predators: n+=1
	return n

func route(w: Dictionary,from: String,to: String) -> Array:
	if from==to: return []
	var queue=[from]; var seen={from:[]}
	while not queue.is_empty():
		var node=queue.pop_front()
		for id in rules.edges:
			if not w.edges[id].open: continue
			var e=rules.edges[id]; var next=str(e.b) if e.a==node else (str(e.a) if e.b==node else "")
			if next.is_empty() or seen.has(next): continue
			seen[next]=seen[node]+[id]
			if next==to: return seen[next]
			queue.append(next)
	return []

func _score(w: Dictionary,p: Dictionary,id: String) -> float:
	var r=w.regions[id]; var predator=rules.species[p.species].diet=="carrion"
	var food=float(r.carrion)+occupants(w,id)*12.0 if predator else float(r.plants)
	var score=minf(1,r.water/12.0)*p.thirst+minf(1,food/18.0)*p.hunger
	if not predator: score-=occupants(w,id,true)*float(rules.movement.fear)
	score-=occupants(w,id,predator)*float(rules.movement.crowding)
	return score

func _choose(w: Dictionary,p: Dictionary) -> void:
	var best=""; var score=_score(w,p,p.at)+float(rules.movement.improvement)
	for id in rules.regions:
		var path=route(w,p.at,id)
		if path.is_empty(): continue
		var value=_score(w,p,id)-path.size()*float(rules.movement.distance_cost)
		if value>score: score=value; best=str(path[0])
	if best.is_empty(): return
	var e=rules.edges[best]; p.edge=best; p.to=str(e.b) if p.at==e.a else str(e.a); p.progress=0.0; p.action="walk"

func _die(w: Dictionary,p: Dictionary,cause: String) -> void:
	if not p.alive: return
	p.alive=false; p.health=0.0; p.cause=cause; p.action="lost"
	# Loss during a crossing is assigned to its origin for the region ledger.
	var r=w.regions[p.at]; var amount=float(rules.species[p.species].body)
	r.remains+=amount; r.carrion+=amount
	p.to=""; p.edge=""; p.progress=0.0
	if cause=="predation": w.kills+=1

func _act(w: Dictionary,p: Dictionary) -> void:
	p.thirst=minf(100,p.thirst+float(rules.needs.thirst)); p.hunger=minf(100,p.hunger+float(rules.needs.hunger))
	p.cooldown=maxi(0,int(p.cooldown)-1)
	if not p.to.is_empty():
		p.action="walk"; p.progress+=float(rules.species[p.species].speed)/float(rules.edges[p.edge].seconds)
		if p.progress>=1:
			p.at=p.to; p.to=""; p.edge=""; p.progress=0.0; p.journeys+=1; w.migrations+=1; p.action="rest"
	else:
		p.action="rest"
		var r=w.regions[p.at]
		if p.thirst>5 and r.water>0:
			var amount=minf(r.water,float(rules.needs.drink)); r.water-=amount; r.drunk+=amount
			p.thirst=maxf(0,p.thirst-amount*float(rules.needs.drink_relief)); p.action="drink"
		if p.hunger>5:
			var herbivore=rules.species[p.species].diet=="plants"
			var food="plants" if herbivore else "carrion"; var book="grazed" if herbivore else "scavenged"
			var amount=minf(r[food],float(rules.needs.eat))
			if amount>0:
				r[food]-=amount; r[book]+=amount; p.hunger=maxf(0,p.hunger-amount*float(rules.needs.eat_relief)); p.action="graze" if herbivore else "scavenge"
			elif not herbivore and p.hunger>float(rules.predation.hunger) and p.cooldown==0:
				for prey in w.animals:
					if prey.alive and prey.at==p.at and prey.to.is_empty() and rules.species[prey.species].diet=="plants":
						prey.health=maxf(0,prey.health-float(rules.predation.damage)); p.cooldown=int(rules.predation.cooldown); p.action="hunt"
						if prey.health<=0: _die(w,prey,"predation")
						break
		if (int(w.elapsed)+int(p.id))%int(rules.movement.interval)==0: _choose(w,p)
	var thirsty=p.thirst>float(rules.needs.stress); var hungry=p.hunger>float(rules.needs.stress)
	if thirsty or hungry:
		p.health=maxf(0,p.health-float(rules.needs.damage)*(int(thirsty)+int(hungry)))
		if p.health<=0: _die(w,p,"thirst" if thirsty else "hunger")
	elif p.thirst<40 and p.hunger<40: p.health=minf(100,p.health+float(rules.needs.recovery))

func step(w: Dictionary,at: int) -> Array:
	if not w.enabled: return []
	w.elapsed+=1
	for id in rules.regions:
		var r=w.regions[id]; var spec=rules.regions[id]
		var rain=float(spec.rain) if wet(w) else 0.0; r.water+=rain; r.rain+=rain
		var overflow=maxf(0,r.water-float(rules.limits.water)); r.water-=overflow; r.overflow+=overflow
		var evaporation=minf(r.water,float(rules.climate.wet_evaporation if wet(w) else rules.climate.evaporation)*(float(rules.products.shade_evaporation) if r.shade else 1.0))
		r.water-=evaporation; r.evaporated+=evaporation
		var growth=minf(float(rules.limits.plants)-r.plants,float(spec.growth)*minf(1,r.water/12.0)*(float(rules.products.shade_growth) if r.shade else 1.0))
		growth=minf(growth,r.water/float(rules.plants.water_per_growth))
		r.plants+=growth; r.grown+=growth; r.water-=growth*float(rules.plants.water_per_growth); r.growth_water+=growth*float(rules.plants.water_per_growth)
		var wilt=minf(r.plants,float(rules.plants.dry_wilt)) if r.water<1 else 0.0; r.plants-=wilt; r.wilted+=wilt
		var decay=minf(r.carrion,float(rules.plants.carrion_decay)); r.carrion-=decay; r.decayed+=decay
	# Rotating the update order avoids permanently favoring the first individual.
	for n in range(w.animals.size()):
		var p=w.animals[(int(w.elapsed)+n)%w.animals.size()]
		if p.alive: _act(w,p)
	var messages=[]
	if w.migrations>0 and "migration" not in w.flags: w.flags.append("migration"); messages.append("恐龙开始迁徙：路线由可达的水、食物和捕食压力决定。")
	if alive(w)<w.animals.size() and "loss" not in w.flags: w.flags.append("loss"); messages.append("出现个体损失；补给只能帮助存活动物，不能让死亡倒转。")
	if wet(w) and "rain" not in w.flags: w.flags.append("rain"); messages.append("雨期到来，水点开始恢复；损失仍保留在账本中。")
	if int(w.elapsed)%10==0: _record(w,at)
	return messages

func alive(w: Dictionary,species: String="") -> int:
	var n=0
	for p in w.animals:
		if p.alive and (species.is_empty() or p.species==species): n+=1
	return n

func _record(w: Dictionary,at: int) -> void:
	var state={}
	for key in w:
		if key!="history": state[key]=w[key]
	w.history.append({"at":at,"state":state.duplicate(true)})
	while w.history.size()>int(rules.limits.history): w.history.pop_front()

func _num(v,lo: float=0,hi: float=10000000,integer: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi and (not integer or float(v)==floor(float(v)))

func _valid_state(w,at: int) -> bool:
	if not w is Dictionary or w.get("model")!=rules.model or w.get("era")!=rules.era or not w.get("enabled") is bool: return false
	if not _num(w.get("elapsed"),0,at,true) or (not w.enabled and w.elapsed!=0): return false
	if not w.get("regions") is Dictionary or w.regions.size()!=rules.regions.size() or not w.get("edges") is Dictionary or w.edges.size()!=rules.edges.size(): return false
	for id in rules.regions:
		var r=w.regions.get(id); var spec=rules.regions[id]
		if not r is Dictionary or not r.get("shade") is bool: return false
		for key in ACCOUNTS+["water","plants","carrion"]:
			if not _num(r.get(key),0,float(rules.limits.ledger)): return false
		if r.water>rules.limits.water+0.00001 or r.plants>rules.limits.plants+0.00001: return false
		if absf(spec.water+r.added+r.rain-r.drunk-r.evaporated-r.growth_water-r.overflow-r.water)>0.0001: return false
		if absf(spec.plants+r.grown-r.grazed-r.wilted-r.plants)>0.0001: return false
		if absf(r.remains-r.scavenged-r.decayed-r.carrion)>0.0001: return false
		if absf(r.grown*float(rules.plants.water_per_growth)-r.growth_water)>0.0001: return false
	for id in rules.edges:
		var e=w.edges.get(id)
		if not e is Dictionary or not e.get("built") is bool or not e.get("open") is bool or (e.open and not e.built) or (rules.edges[id].built and not e.built): return false
	if not w.get("animals") is Array or w.animals.size()!=rules.animals.size(): return false
	var journeys=0; var kills=0; var remains={}
	for id in rules.regions: remains[id]=0.0
	for i in range(w.animals.size()):
		var p=w.animals[i]
		if not p is Dictionary or p.get("id")!=i or p.get("species")!=rules.animals[i][0] or not rules.regions.has(p.get("at")) or not p.get("alive") is bool: return false
		for key in ["health","thirst","hunger"]:
			if not _num(p.get(key),0,100): return false
		if not _num(p.get("progress"),0,0.999999999) or not _num(p.get("cooldown"),0,rules.predation.cooldown,true) or not _num(p.get("journeys"),0,w.elapsed,true): return false
		if p.get("action") not in ACTIONS or p.get("cause") not in CAUSES or not p.get("to") is String or not p.get("edge") is String: return false
		if p.alive!=(p.health>0) or (p.alive and (p.cause!="" or p.action=="lost")): return false
		if not p.alive:
			if p.cause=="" or p.action!="lost" or not p.to.is_empty(): return false
			remains[p.at]+=float(rules.species[p.species].body); kills+=int(p.cause=="predation")
		if p.to.is_empty():
			if not p.edge.is_empty() or p.progress!=0 or p.action=="walk": return false
		else:
			if not rules.edges.has(p.edge) or not w.edges[p.edge].built or not p.alive or p.action!="walk": return false
			var e=rules.edges[p.edge]
			if not ((e.a==p.at and e.b==p.to) or (e.b==p.at and e.a==p.to)): return false
		journeys+=int(p.journeys)
	for id in remains:
		if absf(remains[id]-w.regions[id].remains)>0.0001: return false
	if w.get("migrations")!=journeys or w.get("kills")!=kills: return false
	if not w.get("flags") is Array or w.flags.size()>3: return false
	var flags=[]
	for flag in w.flags:
		if flag not in ["migration","loss","rain"] or flag in flags: return false
		flags.append(flag)
	return true

func valid(w,at: int) -> bool:
	if not _valid_state(w,at) or not w.get("history") is Array or w.history.is_empty() or w.history.size()>int(rules.limits.history): return false
	var last=-1; var elapsed=-1
	for record in w.history:
		if not record is Dictionary or not _num(record.get("at"),last+1,at,true) or not _valid_state(record.get("state"),int(record.at)): return false
		if record.state.has("history") or record.state.elapsed<=elapsed or record.state.elapsed>w.elapsed: return false
		last=int(record.at); elapsed=int(record.state.elapsed)
	return true
