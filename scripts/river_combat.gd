extends RefCounted
## Encounter simulation uses real seconds, never accelerated ecological days.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_combat.json"))
var player_health=100.0
var attack_left=0.0
var hurt_flash=0.0
var records={}
var revision=0

func entities(v) -> Array:
	var out=[]; var t=v.construction.terrain
	for id in v.world.regions:
		var r=v.world.regions[id]; var c: Vector3=t.CENTERS[id]
		for a in r.animals:
			var fish=a.species=="marsh_fish"; var spread=1.0 if r.enclosed else 2.2
			var at=Vector2(c.x+a.x*spread,c.z+a.z*spread)
			if fish: at=Vector2(t.river_x(c.z+a.z*2.2)+a.x*0.4,c.z+a.z*2.2)
			out.append({"key":"animal:"+id+":"+str(int(a.id)),"type":"animal","region":id,"id":a.id,"row":a,"position":at,"origin":Vector2(c.x,c.z),"scale":spread,"fish":fish,"name":("湿地鱼" if fish else "草甸小鹿"),"height":0.35 if fish else 0.8})
	var observer=Vector2(v.actor.eye.x,v.actor.eye.z) if not v.actor.is_empty() else Vector2.ZERO
	for s in v.population.visible_sites(observer):
		for kind in ["animals","visitors"]:
			for a in s[kind]:
				var human=kind=="visitors"; var key=("visitor:" if human else "wild:")+str(s.id)+":"+str(int(a.id))
				out.append({"key":key,"type":"visitor" if human else "wild","row":a,"position":Vector2(s.x+a.x,s.z+a.z),"origin":Vector2(s.x,s.z),"scale":1.0,"fish":false,"name":a.name if human else ("林地野猪" if a.species=="woodland_boar" else "林间小鹿"),"height":1.55 if human else 0.8,"id":a.id,"site":s.id})
	for a in v.settlement.people:
		out.append({"key":"resident:"+str(int(a.id)),"type":"resident","row":a,"position":Vector2(a.x,a.z),"origin":Vector2.ZERO,"scale":1.0,"fish":false,"name":a.name,"height":1.65,"id":a.id})
	return out

func busy(key: String) -> bool:
	return records.get(key,{}).get("anger",0)>0

func reaction(entity: Dictionary) -> String:
	return "逃跑" if entity.fish or (entity.type in ["animal","wild"] and entity.row.get("species")!="woodland_boar") else "反击"

func strike(target: Dictionary,v) -> String:
	if player_health<=0: return "你需要回营地休息"
	if attack_left>0: return "稍等，手臂还在收回"
	if not target.has("entity") or target.distance>float(rules.reach): return "靠近目标后再挥击"
	var e: Dictionary=target.entity
	if e.row.get("health",1)<=0: return "目标已经离开"
	if not records.has(e.key) and records.size()>=int(rules.max_records): return "遭遇记录已满，等待已有怒气消退"
	v.ranch.attacked(e,int(v.world.elapsed))
	var r=records.get(e.key,{"anger":0.0,"wait":float(rules.enemy_cooldown),"home_x":e.position.x,"home_z":e.position.y,"mode":reaction(e)})
	r.anger=minf(100,r.anger+float(rules.anger_per_hit)); records[e.key]=r
	e.row.health=maxf(0,float(e.row.get("health",1))-float(rules.hit_damage)); attack_left=float(rules.hit_cooldown); revision+=1
	if e.row.health<=0:
		records.erase(e.key); _remove(e,v)
		return e.name+"倒下了。它不会因为重新进入区域而复活。"
	return "%s受到攻击 · 血量%.0f%% · %s" % [e.name,e.row.health*100,r.mode]

func _remove(e: Dictionary,v) -> void:
	if e.type=="animal": v.world.regions[e.region].animals.erase(e.row)
	elif e.type=="wild": v.population.sites[e.site].animals.erase(e.row)
	elif e.type=="visitor": v.population.sites[e.site].visitors.erase(e.row)
	else: v.settlement.people.erase(e.row)

func tick(dt: float,v) -> void:
	attack_left=maxf(0,attack_left-dt); hurt_flash=maxf(0,hurt_flash-dt)
	if v.actor.is_empty() or player_health<=0: return
	var c=v.construction; var t=c.terrain; var player=Vector2(v.actor.feet.x,v.actor.feet.z)
	var live={}
	for e in entities(v):
		live[e.key]=true
		if not records.has(e.key): continue
		var r=records[e.key]; r.anger=maxf(0,r.anger-float(rules.anger_decay)*dt); r.wait=maxf(0,r.wait-dt)
		if r.anger<=0 or e.row.get("health",1)<=0: records.erase(e.key); revision+=1; continue
		var leash=Vector2(r.home_x,r.home_z)
		if player.distance_to(leash)>float(rules.leash): r.anger=maxf(0,r.anger-dt*20); continue
		var toward=(player-e.position).normalized(); var fleeing=r.mode=="逃跑"; var direction=-toward if fleeing else toward
		if e.fish: continue
		var dist=e.position.distance_to(player)
		if (not fleeing and dist>float(rules.enemy_reach)*0.8) or (fleeing and dist<8):
			for dir in [direction,direction.rotated(0.8),direction.rotated(-0.8)]:
				var next=e.position+dir*float(rules.speed)*dt
				if next.distance_to(leash)>7.5: continue
				if t.blocked(next,c.obstacles) or c.overlaps(next,t.ground(next),e.height): continue
				if absf(t.ground(next)-t.ground(e.position))>0.42: continue
				var local=(next-e.origin)/float(e.scale)
				if e.type=="animal" and (absf(local.x)>3.5 or absf(local.y)>3.5): continue
				if e.type in ["wild","visitor"] and (absf(local.x)>9 or absf(local.y)>9): continue
				e.row.x=local.x; e.row.z=local.y; break
		if not fleeing and r.anger>=float(rules.attack_threshold) and dist<=float(rules.enemy_reach) and r.wait<=0:
			var origin=Vector3(e.position.x,t.ground(e.position)+e.height*0.65,e.position.y)
			var aim: Vector3=v.actor.feet+Vector3(0,0.65,0); var ray=(aim-origin).normalized(); var obstruction=c.trace(origin,ray)
			if absf(v.actor.feet.y-t.ground(e.position))>1.2: continue
			if obstruction.has("point") and origin.distance_to(obstruction.point)<origin.distance_to(aim)-0.1: continue
			player_health=maxf(0,player_health-float(rules.enemy_damage)); hurt_flash=0.35; r.wait=float(rules.enemy_cooldown); revision+=1
	for key in records.keys():
		if not live.has(key): records.erase(key)

func respawn() -> void:
	player_health=float(rules.player_health); attack_left=0; hurt_flash=0; records.clear(); revision+=1

func serialize() -> Dictionary:
	return {"version":1,"player_health":player_health,"records":records.duplicate(true)}

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not _num(data.get("player_health"),0,rules.player_health) or not data.get("records") is Dictionary or data.records.size()>int(rules.max_records): return false
	for key in data.records:
		var r=data.records[key]
		if not key is String or key.length()>100 or not r is Dictionary or r.get("mode") not in ["逃跑","反击"]: return false
		for k in ["anger","wait","home_x","home_z"]:
			if not _num(r.get(k),-512 if k.begins_with("home") else 0,512 if k.begins_with("home") else (100 if k=="anger" else rules.enemy_cooldown)): return false
	player_health=data.player_health; records=data.records.duplicate(true); revision+=1; return true

func _num(n,lo: float,hi: float) -> bool:
	return (n is float or n is int) and is_finite(n) and n>=lo and n<=hi
