extends RefCounted
## World state has no access to the island wallet, sample bag or product stock.
const Rules=preload("res://scripts/island_storage.gd")
const Ecology=preload("res://scripts/planet_ecology.gd")
var ecology=Ecology.new()
var watershed=preload("res://scripts/planet_watershed.gd").new()
var village=preload("res://scripts/planet_village.gd").new()
var habitat=preload("res://scripts/planet_habitat.gd").new()
var modern=preload("res://scripts/planet_modern.gd").new()
var industry=preload("res://scripts/planet_industry.gd").new()
var config: Dictionary
var custom_designs: Dictionary={}
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
		"base":{},"base_key":"","observation":false,"modern":modern.fresh(),"industry":industry.fresh(),"habitat":habitat.fresh(),"watershed":watershed.fresh(),"village":village.fresh(),"ecology":ecology.fresh(),"eco_allowance":config.trial_products.duplicate(true)}

func get_world(id: String="") -> Dictionary:
	for item in worlds:
		if item.id==(active_id if id.is_empty() else id): return item
	return {}

func total(world: Dictionary, field: String="target") -> float:
	var result=0.0
	for zone in world.zones: result+=float(zone[field])
	return result

func can_deploy(id: String, site_id: String,recipe: String="standard_water_crate") -> bool:
	var w=get_world(id)
	if w.is_empty(): return false
	if recipe.begins_with("custom:"):
		if not custom_designs.has(recipe): return false
		var d=custom_designs[recipe]
		if w.mode!="experiment" and d.basis!="family_model": return false
		if d.basis=="family_model" and w.mode=="experiment" and family_remaining(w)<=0: return false
		return modern.can_custom(w.modern,site_id,d) if d.kind=="sink" else industry.can_custom(w.industry,site_id,d)
	if site_id in modern.ids(): return modern.can_deploy(w.modern,site_id,recipe)
	if site_id in industry.ids(): return industry.can_deploy(w.industry,site_id,recipe)
	if site_id in habitat.ids(): return habitat.can_deploy(w.habitat,site_id,recipe)
	if site_id in watershed.ids(): return watershed.can_deploy(w.watershed,site_id,recipe)
	if site_id=="village_depot": return village.can_deploy(w.village,site_id,recipe)
	if recipe!="standard_water_crate": return ecology.can_deploy(w.ecology,site_id,recipe)
	if w.is_empty() or total(w)>=int(config.world.capacity): return false
	for zone in w.zones:
		if zone.id==site_id: return int(zone.target)<int(config.world.capacity)
	return false

func deploy(id: String,site_id: String,shipment: int,recipe: String="standard_water_crate",component: Dictionary={}) -> void:
	var w=get_world(id)
	if recipe.begins_with("custom:"):
		if not can_deploy(id,site_id,recipe): return
		var d=custom_designs[recipe]
		if d.kind=="sink": modern.deploy_custom(w.modern,site_id,d)
		else: industry.deploy_custom(w.industry,site_id,d)
		_event(w,"modern" if d.kind=="sink" else "industry","标准铜铝层芯已安装；性能采用295 K分层模型。" if d.basis=="family_model" else "玩家假设构件已安装；仅改变本实验，未认证实际材料性质。",shipment)
		return
	if site_id in modern.ids():
		modern.deploy(w.modern,site_id,recipe); _event(w,"modern","%s已交付现代城市" % str(config.recipes[recipe].name),shipment); return
	if site_id in industry.ids():
		industry.deploy(w.industry,site_id,recipe)
		_event(w,"industry","%s已交付到工业港" % str(config.recipes[recipe].name),shipment)
		return
	if site_id in habitat.ids():
		habitat.deploy(w.habitat,site_id,recipe)
		_event(w,"habitat","%s已交付到蕨林河谷" % str(config.recipe.name if recipe=="standard_water_crate" else config.recipes[recipe].name),shipment)
		return
	if site_id in watershed.ids():
		watershed.deploy(w.watershed,site_id,recipe,component)
		_event(w,"watershed","%s已部署到%s" % ["标准水箱" if recipe=="standard_water_crate" else config.recipes[recipe].name,watershed.rules.regions[watershed.ids().find(site_id)].name],shipment)
		return
	if site_id=="village_depot":
		village.deploy(w.village,recipe)
		_event(w,"village","%s已交付到河湾聚落" % str(config.recipes.get(recipe,{}).get("name",recipe)),shipment)
		return
	if recipe!="standard_water_crate":
		ecology.deploy(w.ecology,site_id,recipe,component)
		if ecology.thermal.lab.is_component(recipe):
			_event(w,"ecology","%s：装入%s，旧构件退回本世界库存。" % [ecology.rules[site_id].name,config.recipes[recipe].name],shipment)
			return
		_event(w,"ecology","%s：%s" % [str(ecology.rules[site_id].name),"供氧器就位，等待氧气与动力补给。" if recipe=="oxygen_station" else "已更换氧气与动力补给盒。"],shipment)
		return
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
		if int(w.seconds)>=int(config.world.max_seconds): w.fraction=0.0; break
		w.fraction=float(w.fraction)-1.0
		w.seconds=mini(int(config.world.max_seconds),int(w.seconds)+1)
		for message in watershed.step(w.watershed,int(w.seconds)): _event(w,"watershed",message)
		for message in village.step(w.village,int(w.seconds)): _event(w,"village",message)
		for message in habitat.step(w.habitat,int(w.seconds)): _event(w,"habitat",message)
		for message in modern.step(w.modern,int(w.seconds)): _event(w,"modern",message)
		for message in industry.step(w.industry,int(w.seconds)): _event(w,"industry",message)
		for message in ecology.step(w.ecology,int(w.seconds)): _event(w,"ecology",message)
		for zone in w.zones:
			zone.water=minf(float(zone.target),float(zone.water)+1.0/float(config.world.delivery_seconds))
		if not w.observation and total(w,"water")>=1.0:
			w.observation=true
			_event(w,"observation","第一片水面：水箱经管道进入已冷却的封闭盆地。")

func tick(dt: float) -> void:
	var w=get_world()
	if not w.paused: tick_world(w,dt)

func base_snapshot(w: Dictionary) -> Dictionary:
	return {"seed":int(w.seed),"seconds":int(w.seconds),"fraction":float(w.fraction),"zones":w.zones.duplicate(true),"observation":w.observation,"watershed":w.watershed.duplicate(true),"village":w.village.duplicate(true),"habitat":w.habitat.duplicate(true),"modern":w.modern.duplicate(true),"industry":w.industry.duplicate(true),"ecology":w.ecology.duplicate(true)}

func _base_key(base: Dictionary,legacy_hash: bool=false) -> String:
	if not legacy_hash: return preload("res://scripts/stable_identity.gd").canonical(base,true).sha256_text()
	# JSON parses integer fields as floats. Hash semantic values, not their storage types.
	var parts=["%d:%d:%.6f:%d" % [int(base.seed),int(base.seconds),float(base.fraction),int(base.observation)]]
	for zone in base.zones: parts.append("%s:%d:%.6f" % [str(zone.id),int(zone.target),float(zone.water)])
	if base.has("ecology"): parts.append(ecology.canonical(base.ecology))
	if base.has("watershed"): parts.append(ecology.canonical(base.watershed))
	if base.has("village"): parts.append(ecology.canonical(base.village))
	if base.has("habitat"): parts.append(ecology.canonical(base.habitat))
	if base.has("modern"): parts.append(ecology.canonical(base.modern))
	if base.has("industry"): parts.append(ecology.canonical(base.industry))
	return "|".join(parts).sha256_text()

func fork(dry: bool=false,era: String="") -> String:
	if worlds.size()>=3: return "两个实验位已使用，可重置已有实验继续比较"
	if not era.is_empty() and not watershed.rules.eras.has(era) and not industry.rules.eras.has(era) and era!="modern": return "未知时代起点"
	var source=_new_world("source","","career") if dry or not era.is_empty() else get_world()
	if era=="modern": source.modern=modern.fresh(0,true)
	elif industry.rules.eras.has(era): source.industry=industry.fresh(era,0,true)
	elif not era.is_empty(): source.watershed=watershed.fresh(era,0,true)
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
	w.ecology=w.base.ecology.duplicate(true)
	w.watershed=w.base.watershed.duplicate(true)
	w.village=w.base.village.duplicate(true)
	w.habitat=w.base.habitat.duplicate(true)
	w.industry=w.base.industry.duplicate(true)
	w.modern=w.base.modern.duplicate(true)
	w.eco_allowance=config.trial_products.duplicate(true)
	w.paused=true; w.allowance=int(config.world.trial_allowance)
	w.events=[]; w.event_serial=0
	_event(w,"fork","同起点试验已就绪 · 先选择干预，再开始观察")

func reset_trial(fresh_start: bool=false,era: String="") -> String:
	var w=get_world()
	if w.mode!="experiment": return "主世界不会重置；请在实验副本中试验"
	if not era.is_empty() and not watershed.rules.eras.has(era) and not industry.rules.eras.has(era) and era!="modern": return "未知时代起点"
	if fresh_start or not era.is_empty():
		var source=_new_world("source","","career")
		if era=="modern" or (w.modern.enabled and era.is_empty()): source.modern=modern.fresh(0,true)
		if w.habitat.enabled and era.is_empty(): source.habitat=habitat.fresh(0,true)
		if industry.rules.eras.has(era) or (w.industry.enabled and era.is_empty()): source.industry=industry.fresh(str(w.industry.era) if era.is_empty() else era,0,true)
		if watershed.rules.eras.has(era) or (w.watershed.enabled and era.is_empty()): source.watershed=watershed.fresh(str(w.watershed.era) if era.is_empty() else era,0,true)
		w.base=base_snapshot(source); w.base_key=_base_key(w.base)
	_reset_from_base(w)
	return "已回到这个实验的起点，独立配给已重置"

func can_step_pair() -> bool:
	var a=get_world("trial_a"); var b=get_world("trial_b")
	return not a.is_empty() and not b.is_empty() and a.base_key==b.base_key and a.watershed.enabled==b.watershed.enabled and a.watershed.elapsed==b.watershed.elapsed and a.village.enabled==b.village.enabled and a.village.elapsed==b.village.elapsed and a.habitat.enabled==b.habitat.enabled and a.habitat.elapsed==b.habitat.elapsed and a.modern.enabled==b.modern.enabled and a.modern.elapsed==b.modern.elapsed and a.industry.enabled==b.industry.enabled and a.industry.elapsed==b.industry.elapsed and int(a.seconds)==int(b.seconds) and is_equal_approx(float(a.fraction),float(b.fraction))

func step_pair() -> String:
	if not can_step_pair(): return "同步比较需要两个实验拥有相同起点与时刻；可先分别重置实验"
	for id in ["trial_a","trial_b"]:
		var w=get_world(id); w.paused=true; tick_world(w,10.0)
	return "两个实验共同推进了10秒，现已暂停，方便比较"

func serialize() -> Dictionary:
	return {"version":10,"active_id":active_id,"worlds":worlds.duplicate(true)}

func _number(value,lo: float,hi: float,integer: bool=false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=lo and value<=hi and (not integer or float(value)==floor(float(value)))

func _valid_base(w,legacy_eco: bool=false) -> bool:
	if not w is Dictionary: return false
	if not _number(w.get("seed"),0,2147483647,true) or not _number(w.get("seconds"),0,float(config.world.max_seconds),true): return false
	if not _number(w.get("fraction"),0,0.999999999) or not w.get("observation") is bool: return false
	if not w.get("zones") is Array or w.zones.size()!=config.sites.size(): return false
	for i in range(config.sites.size()):
		var zone=w.zones[i]
		if not zone is Dictionary or zone.get("id")!=config.sites[i].id: return false
		if not _number(zone.get("target"),0,float(config.world.capacity),true): return false
		if not _number(zone.get("water"),0,float(zone.target)): return false
	if w.has("watershed") and not watershed.valid(w.watershed,int(w.seconds)): return false
	if w.has("village") and not village.valid(w.village,int(w.seconds)): return false
	if w.has("habitat") and not habitat.valid(w.habitat,int(w.seconds)): return false
	if w.has("modern") and not modern.valid(w.modern,int(w.seconds)): return false
	if w.has("industry") and not industry.valid(w.industry,int(w.seconds)): return false
	return total(w)<=int(config.world.capacity) and (not w.has("ecology") or ecology.valid(w.ecology,int(w.seconds),legacy_eco))

func restore(data) -> bool:
	if not data is Dictionary or not data.get("worlds") is Array or not data.get("active_id") is String: return false
	if not _number(data.get("version",1),1,10,true): return false
	var legacy=data.get("version",1)==1
	var legacy_eco=data.get("version",1)<3
	if data.worlds.size()<1 or data.worlds.size()>3: return false
	var ids=[]
	for w in data.worlds:
		if not _valid_base(w,legacy_eco): return false
		if data.get("version",1)>=9 and not _custom_fields(w): return false
		if data.get("version",1)>=10 and not _family_fields(w): return false
		if data.get("version",1)>=4 and not w.has("watershed"): return false
		if data.get("version",1)>=5 and not w.has("village"): return false
		if data.get("version",1)>=6 and not w.has("habitat"): return false
		if data.get("version",1)>=7 and not w.has("industry"): return false
		if data.get("version",1)>=8 and not w.has("modern"): return false
		if not legacy and (not w.has("ecology") or not w.get("eco_allowance") is Dictionary): return false
		if not legacy:
			var limits=config.trial_products.duplicate(true)
			if data.get("version",1)<4:
				for key in watershed.rules.trial_products: limits.erase(key)
			if data.get("version",1)<5:
				for key in village.rules.trial_products: limits.erase(key)
			if data.get("version",1)<6:
				for key in habitat.rules.trial_products: limits.erase(key)
			if data.get("version",1)<7:
				for key in industry.rules.trial_products: limits.erase(key)
			if data.get("version",1)<8:
				for key in modern.rules.trial_products: limits.erase(key)
			if legacy_eco: limits={"oxygen_station":2,"oxygen_cartridge":4}
			if w.eco_allowance.size()!=limits.size(): return false
			for key in limits:
				if not _number(w.eco_allowance.get(key),0,int(limits[key])+(5 if ecology.thermal.lab.is_component(key) else 0),true): return false
		if w.get("id") not in ["home","trial_a","trial_b"] or w.id in ids: return false
		ids.append(w.id)
		if not w.get("name") is String or w.name.length()>32 or not w.get("paused") is bool: return false
		if w.get("mode")!=("career" if w.id=="home" else "experiment"): return false
		if not _number(w.get("allowance"),0,float(config.world.trial_allowance),true): return false
		if w.id=="home" and int(w.allowance)!=0: return false
		if not w.get("base") is Dictionary or not w.get("base_key") is String: return false
		if w.mode=="experiment":
			if not _valid_base(w.base,legacy_eco) or w.base_key!=_base_key(w.base,data.get("version",1)<9): return false
			if data.get("version",1)>=9 and not _custom_fields(w.base): return false
			if data.get("version",1)>=10 and (not _family_fields(w.base) or family_remaining(w)<0 or not _family_monotonic(w.base.modern,w.modern)): return false
			if not legacy and not w.base.has("ecology"): return false
			if data.get("version",1)>=4 and not w.base.has("watershed"): return false
			if data.get("version",1)>=5 and not w.base.has("village"): return false
			if data.get("version",1)>=6 and not w.base.has("habitat"): return false
			if data.get("version",1)>=7 and not w.base.has("industry"): return false
			if data.get("version",1)>=8 and not w.base.has("modern"): return false
		elif not w.base.is_empty() or not w.base_key.is_empty(): return false
		if not legacy_eco and w.mode=="experiment":
			for key in ecology.thermal.lab.data.designs:
				var onboard=0; var baseline=0
				for r in component_regions(w): onboard+=int(r.component.get("recipe","")==key)
				for r in component_regions(w.base): baseline+=int(r.component.get("recipe","")==key)
				if int(w.eco_allowance[key])+onboard!=int(config.trial_products[key])+baseline: return false
		if not _number(w.get("event_serial"),0,10000000,true): return false
		if not w.get("events") is Array or w.events.size()>int(config.world.max_events): return false
		var last=0
		for event in w.events:
			if not event is Dictionary or not _number(event.get("id"),last+1,int(w.event_serial),true): return false
			last=int(event.id)
			if not _number(event.get("at"),0,int(w.seconds),true) or not _number(event.get("shipment"),0,10000000,true): return false
			if event.get("kind") not in ["shipment","observation","fork","ecology","watershed","village","habitat","industry","modern"] or not event.get("message") is String or event.message.length()>160: return false
	if "home" not in ids or data.active_id not in ids: return false
	worlds=data.worlds.duplicate(true); active_id=data.active_id
	if legacy:
		for w in worlds:
			w.ecology=ecology.fresh(int(w.seconds)); w.eco_allowance=config.trial_products.duplicate(true)
			if w.mode=="experiment":
				w.base.ecology=ecology.fresh(int(w.base.seconds)); w.base_key=_base_key(w.base)
	elif legacy_eco:
		for w in worlds:
			ecology.migrate_thermal(w.ecology)
			for key in ecology.thermal.lab.data.designs: w.eco_allowance[key]=int(config.trial_products[key])
			if w.mode=="experiment":
				ecology.migrate_thermal(w.base.ecology); w.base_key=_base_key(w.base)
	if data.get("version",1)<4:
		for w in worlds:
			w.watershed=watershed.fresh("devonian",int(w.seconds))
			for key in watershed.rules.trial_products: w.eco_allowance[key]=int(config.trial_products[key])
			if w.mode=="experiment":
				w.base.watershed=watershed.fresh("devonian",int(w.base.seconds)); w.base_key=_base_key(w.base)
	if data.get("version",1)<5:
		for w in worlds:
			w.village=village.fresh(int(w.seconds))
			for key in village.rules.trial_products: w.eco_allowance[key]=int(config.trial_products[key])
			if w.mode=="experiment":
				w.base.village=village.fresh(int(w.base.seconds)); w.base_key=_base_key(w.base)
	if data.get("version",1)<6:
		for w in worlds:
			w.habitat=habitat.fresh(int(w.seconds))
			for key in habitat.rules.trial_products: w.eco_allowance[key]=int(config.trial_products[key])
			if w.mode=="experiment":
				w.base.habitat=habitat.fresh(int(w.base.seconds)); w.base_key=_base_key(w.base)
	if data.get("version",1)<7:
		for w in worlds:
			w.industry=industry.fresh("ww1",int(w.seconds))
			for key in industry.rules.trial_products: w.eco_allowance[key]=int(config.trial_products[key])
			if w.mode=="experiment":
				w.base.industry=industry.fresh("ww1",int(w.base.seconds)); w.base_key=_base_key(w.base)
	if data.get("version",1)<8:
		for w in worlds:
			w.modern=modern.fresh(int(w.seconds))
			for key in modern.rules.trial_products: w.eco_allowance[key]=int(config.trial_products[key])
			if w.mode=="experiment":
				w.base.modern=modern.fresh(int(w.base.seconds)); w.base_key=_base_key(w.base)
	if data.get("version",1)<9:
		for w in worlds:
			_migrate_custom(w)
			if w.mode=="experiment": _migrate_custom(w.base); w.base_key=_base_key(w.base)

	if data.get("version",1)<10:
		for w in worlds:
			_migrate_family(w)
			if w.mode=="experiment": _migrate_family(w.base); w.base_key=_base_key(w.base)

	return true

func component_regions(w: Dictionary) -> Array:
	var result=w.ecology.regions.values()
	if w.has("watershed"): result+=w.watershed.regions.values()
	return result

func component_region(w: Dictionary,site: String) -> Dictionary:
	return w.watershed.regions[site] if site in watershed.ids() else w.ecology.regions[site]

func activate_watershed(era: String) -> String:
	var w=get_world()
	if not watershed.rules.eras.has(era): return "未知时代"
	if w.watershed.enabled: return "水域已经开启；可创建另一时代的实验副本"
	w.watershed=watershed.fresh(era,int(w.seconds),true); w.paused=true
	if w.mode=="experiment":
		w.base.watershed=watershed.fresh(era,int(w.base.seconds),true); w.base_key=_base_key(w.base)
	_event(w,"watershed","已开启"+str(watershed.rules.eras[era].name)+"，先布置，再继续观察。")
	return "水域已开启并暂停，营养输入与设备现在可调节"

func activate_village() -> String:
	var w=get_world()
	if w.village.enabled: return "河湾聚落已经开启"
	w.village=village.fresh(int(w.seconds),true); w.paused=true
	if w.mode=="experiment":
		w.base.village=village.fresh(int(w.base.seconds),true); w.base_key=_base_key(w.base)
	_event(w,"village","河湾聚落已开启并暂停；先交付饮水、构件或工具，再安排项目。")
	return "河湾聚落已开启并暂停"

func activate_habitat() -> String:
	var w=get_world()
	if w.habitat.enabled: return "蕨林河谷已经开启"
	w.habitat=habitat.fresh(int(w.seconds),true); w.paused=true
	if w.mode=="experiment":
		w.base.habitat=habitat.fresh(int(w.base.seconds),true); w.base_key=_base_key(w.base)
	_event(w,"habitat","蕨林河谷已开启并暂停；旱季将至，可补水、遮荫或接通远岸。")
	return "蕨林河谷已开启并暂停"

func activate_industry(era: String) -> String:
	var w=get_world()
	if not industry.rules.eras.has(era): return "未知工业时代"
	if w.industry.enabled: return "工业港已开启；其他起点请在实验副本试验"
	w.industry=industry.fresh(era,int(w.seconds),true); w.paused=true
	if w.mode=="experiment":
		w.base.industry=industry.fresh(era,int(w.base.seconds),true); w.base_key=_base_key(w.base)
	_event(w,"industry","工业港已开启并暂停；先投放动力设备、燃料和导线。")
	return "工业港已开启并暂停"

func activate_modern() -> String:
	var w=get_world()
	if w.modern.enabled: return "现代城市已开启"
	w.modern=modern.fresh(int(w.seconds),true); w.paused=true
	if w.mode=="experiment": w.base.modern=modern.fresh(int(w.base.seconds),true); w.base_key=_base_key(w.base)
	_event(w,"modern","现代城市已开启并暂停；先安装光伏，储能模块出厂为空。")
	return "现代城市已开启并暂停"

func _custom_fields(w: Dictionary) -> bool:
	for kind in ["modern","industry"]:
		var values=[w[kind]]
		for item in w[kind].history: values.append(item.state)
		for value in values:
			if not value.has("custom_receipts") or not value.has("custom_sink" if kind=="modern" else "custom_cables"): return false
	return true
func _migrate_custom(w: Dictionary) -> void:
	for kind in ["modern","industry"]:
		var values=[w[kind]]
		for item in w[kind].history: values.append(item.state)
		for value in values:
			value.custom_receipts=[]; value["custom_sink" if kind=="modern" else "custom_cables"]={}

func family_remaining(w: Dictionary) -> int:
	var count=0
	for n in w.modern.get("family_receipts",{}).values(): count+=int(n)
	var baseline=0
	if w.mode=="experiment":
		for n in w.base.modern.get("family_receipts",{}).values(): baseline+=int(n)
	return 6-count+baseline
func _family_fields(w: Dictionary) -> bool:
	if not w.modern.has("family_receipts"): return false
	for h in w.modern.history:
		if not h.state.has("family_receipts") or not _family_monotonic(h.state,w.modern): return false
	return true
func _family_monotonic(before: Dictionary,after: Dictionary) -> bool:
	for id in before.get("family_receipts",{}):
		if int(after.get("family_receipts",{}).get(id,0))<int(before.family_receipts[id]): return false
	return true
func _migrate_family(w: Dictionary) -> void:
	w.modern.family_receipts={}
	for h in w.modern.history: h.state.family_receipts={}
