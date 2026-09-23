extends RefCounted
## Three connected nutrient-equivalent pools. No wallet, view or random input.
const Thermal=preload("res://scripts/planet_thermal.gd")
var thermal=Thermal.new()
var oxygen_rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_ecology.json")).device
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_watershed.json"))

func ids() -> Array:
	return ["headwater","marsh","estuary"]

func initial_total(era: String) -> float:
	var total=float(rules.eras[era].source)
	for info in rules.regions: total+=float(info.nutrient)+float(info.algae)+float(info.detritus)
	for n in rules.eras[era].initial_plants: total+=float(n)
	return total

func cohort_total() -> float:
	var total=float(rules.refuge_fish)
	for info in rules.regions: total+=float(info.fish)
	return total

func fresh(era: String="devonian",at: int=0,enabled: bool=false) -> Dictionary:
	var regions={}
	for i in range(rules.regions.size()):
		var info=rules.regions[i]
		var r={"nutrient":float(info.nutrient),"algae":float(info.algae),"detritus":float(info.detritus),"plants":float(rules.eras[era].initial_plants[i]),"fish":float(info.fish),"benthos":float(info.benthos),"oxygen":float(rules.biology.oxygen_equilibrium),"stress":0,
			"device":false,"enabled":true,"flow":1.0,"gas":0.0,"energy":0.0,"loaded":0.0,"used":0.0,
			"screen":false,"screen_enabled":true,"screen_loaded":false,"retained":0.0,"screen_energy":0.0,"screen_used":0.0,"screen_charges":0,"screen_discarded":0.0,"buffer":false,"flush":0,
			"harvest_target":"algae","harvest":{},"flags":[]}
		thermal.initialize_region(r); regions[info.id]=r
	var result={"model":rules.model,"era":era,"enabled":enabled,"elapsed":0,"regions":regions,"source":float(rules.eras[era].source),"source_open":true,"bypass":false,"migration_open":true,"refuge":float(rules.refuge_fish),"dead":0.0,"added":0.0,"exported":0.0,"waste":0.0,"history":[]}
	_record(result,at); return result

func nutrient_total(w: Dictionary) -> float:
	var total=float(w.source)+float(w.exported)+float(w.waste)
	for r in w.regions.values():
		for key in ["nutrient","algae","detritus","plants","retained"]: total+=float(r[key])
	return total

func can_deploy(w: Dictionary,site: String,recipe: String) -> bool:
	if not w.enabled or not w.regions.has(site): return false
	var r=w.regions[site]; var d=rules.devices
	if thermal.lab.is_component(recipe): return r.device and thermal.lab.fits(recipe,site) and r.component.get("recipe","")!=recipe
	match recipe:
		"standard_water_crate": return r.flush==0
		"oxygen_station": return not r.device
		"oxygen_cartridge": return r.device and r.gas==0
		"runoff_feed": return site=="headwater" and w.added+float(d.nutrient_pack)<=float(d.max_added_nutrient)
		"screen_station": return not r.screen
		"screen_cartridge": return r.screen and (not r.screen_loaded or r.screen_energy<=0 or r.retained>=float(d.screen_capacity)-0.000001)
		"buffer_raft": return not r.buffer and w.added+float(d.buffer_nutrient)<=float(d.max_added_nutrient)
		"harvest_box": return r.harvest.is_empty() and r[r.harvest_target]>1.0
	return false

func deploy(w: Dictionary,site: String,recipe: String,component: Dictionary={}) -> void:
	var r=w.regions[site]; var d=rules.devices
	if thermal.lab.is_component(recipe): r.component=component.duplicate(true); return
	match recipe:
		"standard_water_crate": r.flush=int(rules.flow.flush_seconds)
		"oxygen_station": r.device=true
		"oxygen_cartridge": r.gas=float(oxygen_rules.cartridge_units); r.energy=r.gas; r.loaded+=r.gas
		"runoff_feed": w.source+=float(d.nutrient_pack); w.added+=float(d.nutrient_pack)
		"screen_station": r.screen=true
		"screen_cartridge":
			w.waste+=r.retained; r.retained=0.0; r.screen_loaded=true; r.flags.erase("screen_spent")
			r.screen_discarded+=r.screen_energy; r.screen_energy=float(d.screen_energy); r.screen_charges+=1
		"buffer_raft": r.buffer=true; r.plants+=float(d.buffer_nutrient); w.added+=float(d.buffer_nutrient)
		"harvest_box": r.harvest={"target":r.harvest_target,"space":float(d.harvest_capacity),"left":int(d.harvest_seconds)}

func control(w: Dictionary,site: String,action: String) -> String:
	if not w.enabled: return "先选择时代并开启水域"
	match action:
		"source": w.source_open=not w.source_open; return "上游营养输入已"+("开放" if w.source_open else "关闭；水流仍然连通")
		"bypass": w.bypass=not w.bypass; return "上游改道直达河口，绕过湿地" if w.bypass else "上游重新流经湿地，再进入河口"
		"migration": w.migration_open=not w.migration_open; return "鱼群与外缘通道已"+("开放" if w.migration_open else "关闭")
	if not w.regions.has(site): return "请选择水域"
	var r=w.regions[site]
	match action:
		"power": r.enabled=not r.enabled; return "供氧开关已切换"
		"flow": r.flow={0.5:1.0,1.0:2.0,2.0:0.5}[float(r.flow)]; return "供氧流量已调整"
		"screen": r.screen_enabled=not r.screen_enabled; return "过滤泵已"+("开启" if r.screen_enabled else "暂停")
		"harvest_target": r.harvest_target="plants" if r.harvest_target=="algae" else "algae"; return "下一箱收割目标："+("植被" if r.harvest_target=="plants" else "藻类")
	return "未知水域操作"

func _once(r: Dictionary,id: String,message: String,events: Array) -> void:
	if id not in r.flags: r.flags.append(id); events.append(message)

func step(w: Dictionary,at: int) -> Array:
	if not w.enabled: return []
	var events=[]; var bio=rules.biology; var d=rules.devices; var era=rules.eras[w.era]
	w.elapsed+=1
	if w.source_open:
		var input=minf(w.source,float(era.runoff_rate)); w.source-=input; w.regions.headwater.nutrient+=input
	# Snapshot all three outgoing fluxes before applying any: no traversal-order teleportation.
	var flux=[]
	for id in ids():
		var r=w.regions[id]; var rate=float(rules.flow.flush) if r.flush>0 else float(rules.flow.normal)
		var outgoing={}
		for key in ["nutrient","algae","detritus"]: outgoing[key]=float(r[key])*rate*(float(rules.flow.algae_fraction) if key=="algae" else 1.0)
		flux.append(outgoing)
	for i in range(3):
		var r=w.regions[ids()[i]]
		var destination="estuary" if i==1 or (i==0 and w.bypass) else "marsh"
		for key in flux[i]:
			r[key]-=flux[i][key]
			if i==2: w.exported+=float(flux[i][key])
			else: w.regions[destination][key]+=float(flux[i][key])
	for i in range(3):
		var id=ids()[i]; var r=w.regions[id]; var name=str(rules.regions[i].name)
		r.flush=maxi(0,int(r.flush)-1)
		if r.screen and r.screen_loaded and r.screen_enabled and r.screen_energy>0 and r.retained<float(d.screen_capacity):
			var amount=minf(float(d.screen_rate),minf(float(d.screen_capacity)-r.retained,r.algae+r.detritus))
			var detritus=minf(amount,r.detritus); r.detritus-=detritus; r.algae=maxf(0,r.algae-(amount-detritus)); r.retained+=amount
			r.screen_energy-=1.0; r.screen_used+=1.0
			if r.retained>=float(d.screen_capacity)-0.000001 or r.screen_energy<=0: _once(r,"screen_spent",name+"：滤盒饱和或动力耗尽，过滤停止；溶解营养仍可通过。",events)
		if not r.harvest.is_empty():
			var h=r.harvest; var amount=minf(float(d.harvest_rate),minf(h.space,maxf(0,r[h.target]-1.0)))
			r[h.target]-=amount; h.space-=amount; w.waste+=amount; h.left-=1
			if h.left<=0 or h.space<=0:
				r.harvest={}; events.append(name+"：收割结束，收集物已封存于本世界。")
		var uptake=minf(r.nutrient,float(bio.algae_growth)*r.algae*r.nutrient/(float(bio.nutrient_half)+r.nutrient)*maxf(0,1-r.algae/float(bio.algae_capacity)))
		r.nutrient-=uptake; r.algae+=uptake
		var dying=r.algae*float(bio.algae_death); r.algae-=dying; r.detritus+=dying
		var cap=float(era.plant_capacities[i])+(float(d.buffer_capacity) if r.buffer else 0.0)
		var growth=minf(r.nutrient,float(bio.plant_growth)*r.plants*r.nutrient/(float(bio.nutrient_half)+r.nutrient)*maxf(0,1-r.plants/cap))
		r.nutrient-=growth; r.plants+=growth
		var litter=r.plants*float(bio.plant_death); r.plants-=litter; r.detritus+=litter
		var decay=r.detritus*float(bio.detritus_decay)*r.oxygen/(5.0+r.oxygen); r.detritus-=decay; r.nutrient+=decay
		var run=thermal.step(r); var dose=float(run.dose); r.gas-=dose; r.energy-=dose; r.used+=dose
		if run.stopped: events.append(name+"：供氧器热保护，冷却期间不耗补给。")
		var exchange=float(bio.reaeration)*(float(bio.oxygen_equilibrium)-r.oxygen)
		var demand=float(bio.background_oxygen_use)+r.algae*float(bio.algae_respiration)+r.plants*float(bio.plant_respiration)+decay*float(bio.decomposition_oxygen)
		r.oxygen=clampf(r.oxygen+exchange+uptake*float(bio.oxygen_release_per_growth)+dose*float(oxygen_rules.transfer_per_unit)-demand,0,100)
		if r.algae>15: _once(r,"bloom",name+"：藻类增多；死亡残体会继续分解耗氧。",events)
		if r.oxygen<30: _once(r,"hypoxia",name+"：出现低氧；水变绿和生物受损之间有延迟。",events)
		if w.migration_open and r.oxygen<float(bio.fish_leave_below):
			var moving=minf(float(bio.fish_migrate_rate),r.fish); r.fish-=moving; w.refuge+=moving
		elif w.migration_open and r.oxygen>float(bio.fish_return_above):
			var moving=minf(float(bio.fish_migrate_rate),minf(w.refuge,maxf(0,float(rules.regions[i].fish)-r.fish))); r.fish+=moving; w.refuge-=moving
		r.stress=mini(int(bio.stress_seconds),int(r.stress)+1) if r.oxygen<float(bio.benthos_death_below) else maxi(0,int(r.stress)-2)
		if r.stress>=int(bio.stress_seconds):
			r.benthos=maxf(0,r.benthos-float(bio.benthos_death_rate))
			if r.oxygen<float(bio.fish_death_below):
				var loss=minf(r.fish,float(bio.fish_death_rate)); r.fish-=loss; w.dead+=loss
		elif r.oxygen>55 and r.detritus<12 and r.benthos>0: r.benthos=minf(float(rules.regions[i].benthos),r.benthos+float(bio.benthos_recovery))
		if "hypoxia" in r.flags and r.oxygen>55: _once(r,"recovery",name+"：氧条件改善，幸存底栖群体恢复较慢；迁走的鱼可回游。",events)
	# Reconcile only rounding on the closed fish cohort; biological losses stay recorded.
	var living=0.0
	for r in w.regions.values(): living+=r.fish
	w.refuge=maxf(0,cohort_total()-w.dead-living)
	if at%int(rules.history.every_seconds)==0: _record(w,at)
	return events

func _record(w: Dictionary,at: int) -> void:
	var snapshot={}
	for key in w:
		if key!="history": snapshot[key]=w[key]
	w.history.append({"at":at,"state":snapshot.duplicate(true)})
	while w.history.size()>int(rules.history.limit): w.history.pop_front()

func _num(v,lo: float,hi: float,integer: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi and (not integer or floor(float(v))==float(v))

func valid(w,at: int,history: bool=true) -> bool:
	if not w is Dictionary or w.get("model")!=rules.model or not rules.eras.has(str(w.get("era",""))): return false
	if not w.get("regions") is Dictionary or w.regions.size()!=3: return false
	for key in ["enabled","source_open","bypass","migration_open"]:
		if not w.get(key) is bool: return false
	if not _num(w.get("elapsed"),0,at,true): return false
	for key in ["source","added","exported","waste"]:
		if not _num(w.get(key),0,12000): return false
	if w.added>float(rules.devices.max_added_nutrient): return false
	for key in ["refuge","dead"]:
		if not _num(w.get(key),0,cohort_total()): return false
	var fish=float(w.refuge)+float(w.dead); var d=rules.devices
	for i in range(3):
		var id=ids()[i]; var r=w.regions.get(id)
		if not r is Dictionary or not thermal.valid(r): return false
		if not r.component.is_empty() and not thermal.lab.fits(str(r.component.recipe),id): return false
		for key in ["enabled","screen","screen_enabled","screen_loaded","buffer"]:
			if not r.get(key) is bool: return false
		for key in ["nutrient","algae","detritus","plants"]:
			if not _num(r.get(key),0,12000): return false
		if not _num(r.get("oxygen"),0,100) or not _num(r.get("fish"),0,cohort_total()) or not _num(r.get("benthos"),0,float(rules.regions[i].benthos)): return false
		fish+=float(r.fish)
		if not _num(r.get("stress"),0,int(rules.biology.stress_seconds),true) or not _num(r.get("flush"),0,int(rules.flow.flush_seconds),true): return false
		if r.get("flow") not in [0.5,1.0,2.0]: return false
		for key in ["gas","energy"]:
			if not _num(r.get(key),0,float(oxygen_rules.cartridge_units)): return false
		for key in ["loaded","used"]:
			if not _num(r.get(key),0,1000000000): return false
		if r.gas!=r.energy or not is_equal_approx(r.loaded-r.used,r.gas) or (not r.device and r.loaded!=0): return false
		if not _num(r.get("retained"),0,float(d.screen_capacity)) or not _num(r.get("screen_energy"),0,float(d.screen_energy),true): return false
		if not _num(r.get("screen_used"),0,1000000000,true) or not _num(r.get("screen_charges"),0,10000000,true): return false
		if not _num(r.get("screen_discarded"),0,1000000000,true): return false
		if float(r.screen_charges)*float(d.screen_energy)-r.screen_used-r.screen_discarded!=r.screen_energy: return false
		if (not r.screen or not r.screen_loaded) and (r.retained!=0 or r.screen_charges!=0 or r.screen_energy!=0): return false
		if r.get("harvest_target") not in ["algae","plants"] or not r.get("harvest") is Dictionary: return false
		if not r.harvest.is_empty():
			if r.harvest.get("target") not in ["algae","plants"] or not _num(r.harvest.get("space"),0,float(d.harvest_capacity)): return false
			if not _num(r.harvest.get("left"),1,int(d.harvest_seconds),true): return false
		if not r.get("flags") is Array or r.flags.size()>4: return false
		var seen=[]
		for flag in r.flags:
			if flag not in ["bloom","hypoxia","recovery","screen_spent"] or flag in seen: return false
			seen.append(flag)
	if absf(fish-cohort_total())>0.00001 or absf(nutrient_total(w)-(initial_total(w.era)+w.added))>0.00001: return false
	if history:
		if not w.get("history") is Array or w.history.size()>int(rules.history.limit): return false
		var last=-1
		for entry in w.history:
			if not entry is Dictionary or not _num(entry.get("at"),last+1,at,true) or not valid(entry.get("state"),int(entry.at),false): return false
			last=int(entry.at)
	return true
