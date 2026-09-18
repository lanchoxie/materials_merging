extends RefCounted
## World state has no access to the island wallet, sample bag or product stock.
const Rules=preload("res://scripts/island_storage.gd")
var config: Dictionary
var worlds: Array=[]
var active_id="home"

func _init(rules: Dictionary={}) -> void:
	config=rules
	if config.is_empty(): config=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_balance.json"))
	worlds=[_new_world("home","试验湾 · 主世界","career")]

func _new_world(id: String,title: String,mode: String) -> Dictionary:
	var zones=[]
	for site in config.sites: zones.append({"id":site.id,"target":0,"water":0.0})
	return {"id":id,"name":title,"mode":mode,"seed":int(config.world.seed),"seconds":0,"fraction":0.0,
		"paused":mode=="experiment","zones":zones,"events":[],"event_serial":0,"allowance":int(config.world.trial_allowance) if mode=="experiment" else 0,
		"base":{},"base_key":"","observation":false}

func get_world(id: String="") -> Dictionary:
	for item in worlds:
		if item.id==(active_id if id.is_empty() else id): return item
	return {}

func total(world: Dictionary, field: String="target") -> float:
	var result=0.0
	for zone in world.zones: result+=float(zone[field])
	return result

func can_deploy(id: String, site_id: String) -> bool:
	var w=get_world(id)
	if w.is_empty() or total(w)>=int(config.world.capacity): return false
	for zone in w.zones:
		if zone.id==site_id: return int(zone.target)<int(config.world.capacity)
	return false

func deploy(id: String,site_id: String,shipment: int) -> void:
	var w=get_world(id)
	for zone in w.zones:
		if zone.id==site_id:
			zone.target=int(zone.target)+1
			_event(w,"shipment","水箱抵达%s" % ("深槽" if site_id=="deep" else "浅台"),shipment)
			return

func _event(w: Dictionary,kind: String,message: String,shipment: int=0) -> void:
	w.event_serial=int(w.event_serial)+1
	w.events.append({"id":w.event_serial,"at":int(w.seconds),"kind":kind,"message":message,"shipment":shipment})
	while w.events.size()>int(config.world.max_events): w.events.pop_front()

func tick_world(w: Dictionary,dt: float) -> void:
	if not is_finite(dt) or dt<=0 or dt>60: return
	w.fraction=float(w.fraction)+dt
	while float(w.fraction)>=1.0:
		w.fraction=float(w.fraction)-1.0
		w.seconds=mini(int(config.world.max_seconds),int(w.seconds)+1)
		for zone in w.zones:
			zone.water=minf(float(zone.target),float(zone.water)+1.0/float(config.world.delivery_seconds))
		if not w.observation and total(w,"water")>=1.0:
			w.observation=true
			_event(w,"observation","第一片水面：水箱经管道进入已冷却的封闭盆地。")

func tick(dt: float) -> void:
	var w=get_world()
	if not w.paused: tick_world(w,dt)

func base_snapshot(w: Dictionary) -> Dictionary:
	return {"seed":int(w.seed),"seconds":int(w.seconds),"fraction":float(w.fraction),"zones":w.zones.duplicate(true),"observation":w.observation}

func _base_key(base: Dictionary) -> String:
	# JSON parses integer fields as floats. Hash semantic values, not their storage types.
	var parts=["%d:%d:%.6f:%d" % [int(base.seed),int(base.seconds),float(base.fraction),int(base.observation)]]
	for zone in base.zones: parts.append("%s:%d:%.6f" % [str(zone.id),int(zone.target),float(zone.water)])
	return "|".join(parts).sha256_text()

func fork(dry: bool=false) -> String:
	if worlds.size()>=3: return "两个实验位已使用，可重置已有实验继续比较"
	var source=_new_world("source","","career") if dry else get_world()
	var base=base_snapshot(source)
	var id="trial_a" if get_world("trial_a").is_empty() else "trial_b"
	var w=_new_world(id,"实验 A" if id=="trial_a" else "实验 B","experiment")
	w.base=base.duplicate(true)
	w.base_key=_base_key(base)
	_reset_from_base(w)
	worlds.append(w)
	active_id=id
	return "%s已创建 · 独立试验配给，不扣主仓库" % w.name

func _reset_from_base(w: Dictionary) -> void:
	for key in ["seed","seconds","fraction","observation"]: w[key]=w.base[key]
	w.zones=w.base.zones.duplicate(true)
	w.paused=true; w.allowance=int(config.world.trial_allowance)
	w.events=[]; w.event_serial=0
	_event(w,"fork","同起点试验已就绪 · 先放置水箱，再开始观察")

func reset_trial() -> String:
	var w=get_world()
	if w.mode!="experiment": return "主世界不会重置；请在实验副本中试验"
	_reset_from_base(w)
	return "已回到这个实验的起点，独立配给已重置"

func can_step_pair() -> bool:
	var a=get_world("trial_a"); var b=get_world("trial_b")
	return not a.is_empty() and not b.is_empty() and a.base_key==b.base_key and int(a.seconds)==int(b.seconds) and is_equal_approx(float(a.fraction),float(b.fraction))

func step_pair() -> String:
	if not can_step_pair(): return "同步比较需要两个实验拥有相同起点与时刻；可先分别重置实验"
	for id in ["trial_a","trial_b"]:
		var w=get_world(id); w.paused=true; tick_world(w,10.0)
	return "两个实验共同推进了10秒，现已暂停，方便比较"

func serialize() -> Dictionary:
	return {"active_id":active_id,"worlds":worlds.duplicate(true)}

func _number(value,lo: float,hi: float,integer: bool=false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=lo and value<=hi and (not integer or float(value)==floor(float(value)))

func _valid_base(w) -> bool:
	if not w is Dictionary: return false
	if not _number(w.get("seed"),0,2147483647,true) or not _number(w.get("seconds"),0,float(config.world.max_seconds),true): return false
	if not _number(w.get("fraction"),0,0.999999999) or not w.get("observation") is bool: return false
	if not w.get("zones") is Array or w.zones.size()!=config.sites.size(): return false
	for i in range(config.sites.size()):
		var zone=w.zones[i]
		if not zone is Dictionary or zone.get("id")!=config.sites[i].id: return false
		if not _number(zone.get("target"),0,float(config.world.capacity),true): return false
		if not _number(zone.get("water"),0,float(zone.target)): return false
	return total(w)<=int(config.world.capacity)

func restore(data) -> bool:
	if not data is Dictionary or not data.get("worlds") is Array or not data.get("active_id") is String: return false
	if data.worlds.size()<1 or data.worlds.size()>3: return false
	var ids=[]
	for w in data.worlds:
		if not _valid_base(w): return false
		if w.get("id") not in ["home","trial_a","trial_b"] or w.id in ids: return false
		ids.append(w.id)
		if not w.get("name") is String or w.name.length()>32 or not w.get("paused") is bool: return false
		if w.get("mode")!=("career" if w.id=="home" else "experiment"): return false
		if not _number(w.get("allowance"),0,float(config.world.trial_allowance),true): return false
		if w.id=="home" and int(w.allowance)!=0: return false
		if not w.get("base") is Dictionary or not w.get("base_key") is String: return false
		if w.mode=="experiment":
			if not _valid_base(w.base) or w.base_key!=_base_key(w.base): return false
		elif not w.base.is_empty() or not w.base_key.is_empty(): return false
		if not _number(w.get("event_serial"),0,10000000,true): return false
		if not w.get("events") is Array or w.events.size()>int(config.world.max_events): return false
		var last=0
		for event in w.events:
			if not event is Dictionary or not _number(event.get("id"),last+1,int(w.event_serial),true): return false
			last=int(event.id)
			if not _number(event.get("at"),0,int(w.seconds),true) or not _number(event.get("shipment"),0,10000000,true): return false
			if event.get("kind") not in ["shipment","observation","fork"] or not event.get("message") is String or event.message.length()>160: return false
	if "home" not in ids or data.active_id not in ids: return false
	worlds=data.worlds.duplicate(true); active_id=data.active_id
	return true
