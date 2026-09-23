extends RefCounted
## Persistent encounters, separate from render chunks and the player's inventory.
const Terrain=preload("res://scripts/river_terrain.gd")
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_population.json"))
var terrain=Terrain.new()
var sites={}
var active_sites=[]
var enabled=true
var combat

func _init() -> void:
	for id in Terrain.CENTERS:
		var c: Vector3=Terrain.CENTERS[id]
		sites[id]=_site(id,Vector2(c.x,c.z),id=="meadow",true)

func _site(id: String,p: Vector2,camp: bool,home: bool=false) -> Dictionary:
	var site={"id":id,"x":p.x,"z":p.y,"camp":camp,"home":home,"seconds":0,"flora":0.6,"animal_clock":0,"visitor_clock":0,"serial":1,"animals":[],"visitors":[],"arrivals":0}
	if not home:
		for i in range(2): site.animals.append(_animal(site))
	if camp: site.visitors.append(_visitor(site))
	return site

func _animal(site: Dictionary) -> Dictionary:
	var id=int(site.serial); site.serial+=1
	return {"id":id,"species":"meadow_herbivore","health":0.9,"age":0.5,"x":sin(id*9.1)*2,"z":cos(id*4.7)*2}

func _visitor(site: Dictionary) -> Dictionary:
	var id=int(site.serial); site.serial+=1
	return {"id":id,"name":["林禾","阿舟","小岚","山青"][id%4],"born":int(site.seconds),"state":"进营","x":-7.0,"z":2.0}

func observe(at: Vector2) -> void:
	active_sites=[]
	var spacing=float(terrain.rules.site_spacing); var center=(at/spacing).round()
	for z in range(-1,2):
		for x in range(-1,2):
			var grid=center+Vector2(x,z); var p=grid*spacing
			if p.length()<40 or not terrain.inside(p,10) or at.distance_to(p)>float(rules.active_radius): continue
			var key="%d:%d" % [int(grid.x),int(grid.y)]
			if not sites.has(key) and sites.size()<int(rules.max_sites):
				var camp=(posmod(int(grid.x)*7+int(grid.y)*3,5)==0)
				sites[key]=_site(key,p,camp)
			if sites.has(key): active_sites.append(key)

func _suitable(env: Dictionary) -> bool:
	return float(env.moisture)>0.3 and float(env.water)>0.15 and float(env.temperature)>5 and float(env.temperature)<34 and float(env.pollution)<0.4

func advance(regions: Dictionary) -> Array:
	var arrivals=[]
	for key in sites:
		var s: Dictionary=sites[key]
		if not s.home and key not in active_sites: continue
		var env=regions[key] if s.home else rules.wild_environment
		s.seconds+=1
		var good=_suitable(env)
		if enabled and good: s.flora=minf(1,float(s.flora)+1.0/float(rules.plant_regrow_seconds))
		elif not good: s.flora=maxf(0,float(s.flora)-0.001)
		s.animal_clock=mini(int(rules.animal_interval),int(s.animal_clock)+1)
		var animals: Array=env.animals if s.home else s.animals
		if enabled and good and s.flora>0.35 and not env.enclosed and s.animal_clock>=int(rules.animal_interval) and animals.size()<int(rules.animal_target):
			var aquatic=key in ["wetland","riverbank"]
			if not aquatic or float(env.oxygen)>0.4:
				s.animal_clock=0; s.arrivals+=1
				if s.home: arrivals.append(key)
				else: s.animals.append(_animal(s))
		if not s.home:
			for a in s.animals:
				a.age+=1.0/60; a.health=clampf(a.health+(0.0002 if s.flora>0.15 else -0.002),0,1)
				if combat!=null and combat.busy("wild:"+str(s.id)+":"+str(int(a.id))): continue
				var target=Vector2(sin(float(s.seconds)*0.03+a.id)*3,cos(float(s.seconds)*0.023+a.id*7)*3)
				var moved=Vector2(a.x,a.z).move_toward(target,0.10); a.x=moved.x; a.z=moved.y
				if int(s.seconds)%30==0: s.flora=maxf(0,s.flora-0.01)
			s.animals=s.animals.filter(func(a): return a.health>0)
		if not s.camp: continue
		var staying=[]
		for v in s.visitors:
			if combat!=null and combat.busy("visitor:"+str(s.id)+":"+str(int(v.id))): staying.append(v); continue
			var age=int(s.seconds)-int(v.born); var stay=int(rules.visitor_stay_seconds)
			if age>=stay: continue
			v.state="离营" if age>stay-20 else ("进营" if age<25 else ("采集" if age%70<30 else "休息"))
			var target=Vector2(-8,2) if v.state=="离营" else (Vector2(4,-2) if v.state=="采集" else Vector2(2,1+int(v.id)%2))
			var moved=Vector2(v.x,v.z).move_toward(target,0.18); v.x=moved.x; v.z=moved.y; staying.append(v)
		s.visitors=staying; s.visitor_clock=mini(int(rules.visitor_interval),int(s.visitor_clock)+1)
		if enabled and good and s.flora>=0.5 and s.visitors.size()<int(rules.visitor_capacity) and s.visitor_clock>=int(rules.visitor_interval):
			s.flora-=float(rules.visitor_food_cost); s.visitor_clock=0; s.visitors.append(_visitor(s)); s.arrivals+=1
	return arrivals

func nearest(at: Vector2) -> Dictionary:
	var best={}; var distance=INF
	for s in visible_sites(at):
		var d=at.distance_squared_to(Vector2(s.x,s.z))
		if d<distance: best=s; distance=d
	return best

func visible_sites(at: Vector2) -> Array:
	var result=[]
	for key in sites:
		var s=sites[key]
		if Vector2(s.x,s.z).distance_squared_to(at)<pow(float(rules.visible_radius),2): result.append(s)
	return result

func harvest(at: Vector2) -> bool:
	var s=nearest(at)
	if s.is_empty() or at.distance_to(Vector2(s.x,s.z))>float(rules.harvest_radius) or s.flora<float(rules.harvest_maturity): return false
	s.flora=float(rules.harvest_remaining); return true

func serialize() -> Dictionary:
	return {"version":1,"enabled":enabled,"sites":sites.duplicate(true)}

func _num(v,lo: float,hi: float,integer: bool=false) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi and (not integer or floor(float(v))==float(v))

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("enabled") is bool or not data.get("sites") is Dictionary: return false
	if data.sites.size()<4 or data.sites.size()>int(rules.max_sites): return false
	for id in Terrain.CENTERS:
		if not data.sites.has(id): return false
	for key in data.sites:
		var s=data.sites[key]
		if not s is Dictionary or s.get("id")!=key or not s.get("home") is bool or not s.get("camp") is bool: return false
		var radius=float(terrain.rules.radius)
		if not _num(s.get("x"),-radius,radius) or not _num(s.get("z"),-radius,radius) or not _num(s.get("flora"),0,1): return false
		var p=Vector2(s.x,s.z)
		if Terrain.CENTERS.has(key):
			var c: Vector3=Terrain.CENTERS[key]
			if not s.home or p!=Vector2(c.x,c.z) or s.camp!=(key=="meadow"): return false
		else:
			var grid=p/float(terrain.rules.site_spacing)
			if s.home or p.length()<40 or not terrain.inside(p,10) or grid!=grid.round(): return false
			if key!="%d:%d" % [int(grid.x),int(grid.y)] or s.camp!=(posmod(int(grid.x)*7+int(grid.y)*3,5)==0): return false
		for field in ["seconds","serial","arrivals"]:
			if not _num(s.get(field),1 if field=="serial" else 0,1e12,true): return false
		if not _num(s.get("animal_clock"),0,rules.animal_interval,true) or not _num(s.get("visitor_clock"),0,rules.visitor_interval,true): return false
		if not s.get("animals") is Array or s.animals.size()>(0 if s.home else int(rules.animal_target)) or not s.get("visitors") is Array or s.visitors.size()>(int(rules.visitor_capacity) if s.camp else 0): return false
		var ids=[]
		for a in s.animals+s.visitors:
			if not a is Dictionary or not _num(a.get("id"),1,s.serial-1,true) or int(a.id) in ids or not _num(a.get("x"),-9,9) or not _num(a.get("z"),-9,9): return false
			ids.append(int(a.id))
		for a in s.animals:
			if a.get("species")!="meadow_herbivore" or not _num(a.get("health"),0,1) or not _num(a.get("age"),0,1e12): return false
		for v in s.visitors:
			if v.has("health") and not _num(v.health,0,1): return false
			if not _num(v.get("born"),0,s.seconds,true) or not v.get("name") is String or v.name.length()>24 or v.get("state") not in ["进营","离营","采集","休息"]: return false
	enabled=data.enabled; sites=data.sites.duplicate(true); active_sites=[]; return true
