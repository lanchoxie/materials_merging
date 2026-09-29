extends RefCounted
## One-second deterministic teaching city. Power, storage, heat and materials balance separately.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_modern.json"))
var lab=preload("res://scripts/material_lab.gd").new()
var custom=preload("res://scripts/player_fixture.gd").new()
const ENERGY=["sun_J","pv_J","unconverted_J","charged_J","discharged_J","battery_loss_J","load_J","curtailed_J","compute_J","removed_heat_J"]
const ROLES=["operator","operator","recycler","resident","resident","resident"]
func fresh(at: int=0,enabled: bool=false) -> Dictionary:
	var w={"model":rules.model,"custom_sink":{},"custom_receipts":[],"family_receipts":{},"enabled":enabled,"elapsed":0,"policy":"residents","storage_mode":"auto","running":true,"recycling":true,"park_requested":false,"park":false,"park_progress":0.0,"park_spent":0.0,"panels":{},"installed":{"battery":false,"server":false,"fan":false,"recycler":false},"sink":"","received":{},"scrapped":{},"battery_J":0.0,"heat_J":0.0,"tripped":false,"trips":0,"flow":{},"solar_W":0.0,"irradiance":0.0,"charge_W":0.0,"discharge_W":0.0,"cooling_W":0.0,"service":70.0,"job_kind":"lighting","job":{"kind":"lighting","progress":0.0},"completed":{"lighting":0,"cooling":0},"boost_until":{"lighting":0,"cooling":0},"scrap":0.0,"scrap_added":0.0,"scrap_used":0.0,"parts":0.0,"recovered":0.0,"residue":0.0,"recycle_progress":0.0,"recycle_active":false,"cycles":0,"people":[],"flags":[],"history":[]}
	for id in rules.solar: w.panels[id]={"recipe":"","quality":1.0}
	for id in rules.trial_products: w.received[id]=0; w.scrapped[id]=0
	for id in rules.loads: w.flow[id]=0.0
	for i in range(ROLES.size()): w.people.append({"id":i,"role":ROLES[i],"at":"homes","route":[],"progress":0.0,"task":"waiting"})
	for key in ENERGY: w[key]=0.0
	_record(w,at); return w
func ids() -> Array:
	var list=[]
	for id in rules.nodes:
		if id not in ["junction","park","homes"]: list.append("modern_"+str(id))
	return list
func can_deploy(w: Dictionary,site: String,id: String) -> bool:
	if not w.enabled or not site.begins_with("modern_"): return false
	var node=site.trim_prefix("modern_")
	if rules.panels.has(id):
		return rules.solar.has(node) and (w.panels[node].recipe!=id or w.panels[node].quality<0.99) and rules.panels[id].mass_kg_m2*rules.solar[node].area_m2<=rules.solar[node].max_mass_kg and (w.panels[node].recipe.is_empty() or w.scrap+2<=rules.limits.stock)
	if rules.sinks.has(id): return node=="cooling" and (w.sink!=id or not w.get("custom_sink",{}).is_empty()) and (w.sink.is_empty() or w.scrap+1<=rules.limits.stock)
	if not rules.deliveries.has(id): return false
	var spec=rules.deliveries[id]
	if node!=spec.site: return false
	if spec.has("install"): return not w.installed[spec.install]
	return w.scrap+spec.scrap<=rules.limits.stock
func deploy(w: Dictionary,site: String,id: String) -> void:
	if not can_deploy(w,site,id): return
	var node=site.trim_prefix("modern_"); w.received[id]+=1
	if rules.panels.has(id):
		if not w.panels[node].recipe.is_empty():
			w.scrapped[w.panels[node].recipe]+=1; w.scrap+=2; w.scrap_added+=2
		w.panels[node]={"recipe":id,"quality":1.0}
	elif rules.sinks.has(id):
		w.custom_sink={}
		if not w.sink.is_empty(): w.scrapped[w.sink]+=1; w.scrap+=1; w.scrap_added+=1
		w.sink=id
	else:
		var spec=rules.deliveries[id]
		if spec.has("install"): w.installed[spec.install]=true
		else: w.scrap+=spec.scrap; w.scrap_added+=spec.scrap
func control(w: Dictionary,action: String,id: String="") -> String:
	if not w.enabled: return "先开启现代城市"
	match action:
		"policy":
			if not rules.policies.has(id): return "未知配电方向"
			w.policy=id; return "配电方向已更新；日照和有限储能决定总电量"
		"storage":
			if id not in ["auto","reserve","off"]: return "未知储能方式"
			w.storage_mode=id; return "储能策略已更新；保留模式只充不放，关闭模式不充不放"
		"compute": w.running=not w.running; return "计算任务继续" if w.running else "计算任务暂停，已完成工时保留"
		"job":
			if not rules.jobs.has(id): return "未知计算任务"
			w.job_kind=id; return "下一项计算任务已选择；当前任务保留"
		"recycle": w.recycling=not w.recycling; return "回收继续" if w.recycling else "回收暂停，预留投入保留"
		"park": w.park_requested=not w.park_requested; return "已安排公园施工，需4份再生件和现场工时" if w.park_requested else "公园施工暂停，投入与工时保留"
	return "未知城市操作"
func light(elapsed: int) -> float:
	var t=posmod(elapsed,int(rules.day.period))
	if t>=int(rules.day.daylight): return 0.0
	var cloud=rules.day.cloud_fraction if t>=rules.day.cloud_start and t<rules.day.cloud_end else 1.0
	return maxf(0,sin(PI*t/float(rules.day.daylight)))*float(rules.day.peak_W_m2)*float(cloud)
func _staff(w: Dictionary,role: String) -> int:
	var n=0
	for p in w.people:
		if p.role==role and p.task=="work": n+=1
	return n
func _people(w: Dictionary) -> void:
	for p in w.people:
		var target="compute" if p.role=="operator" else ("recycle" if p.role=="recycler" else ("park" if w.park and posmod(w.elapsed,120)<60 else "homes"))
		if p.role=="recycler" and w.park_requested and not w.park and (w.park_spent>0 or w.parts>=rules.recycling.park_parts): target="park"
		if not p.route.is_empty():
			p.progress+=1.0/float(rules.people.travel_seconds)
			if p.progress>=1-1e-9: p.at=p.route.pop_front(); p.progress=0.0
		if p.route.is_empty() and p.at!=target: p.route=[target] if p.at=="junction" or target=="junction" else ["junction",target]
		p.task="travel" if not p.route.is_empty() else ("work" if p.role!="resident" else "leisure" if p.at=="park" else "home")
func _job(w: Dictionary) -> void:
	var work=w.flow.compute/float(rules.loads.compute)*_staff(w,"operator")/2.0
	if work<=0: return
	w.job.progress+=work
	if w.job.progress>=float(rules.jobs[w.job.kind].work):
		w.completed[w.job.kind]+=1; w.boost_until[w.job.kind]=w.elapsed+int(rules.jobs[w.job.kind].duration)
		w.job={"kind":w.job_kind,"progress":0.0}
func _circular(w: Dictionary) -> void:
	var p=w.people[2]
	if p.task!="work": return
	if p.at=="park" and w.park_requested and not w.park:
		if w.park_spent==0 and w.parts>=rules.recycling.park_parts:
			w.parts-=float(rules.recycling.park_parts); w.park_spent=float(rules.recycling.park_parts)
		if w.park_spent>0: w.park_progress+=1
		if w.park_progress>=float(rules.recycling.park_work): w.park=true; w.park_progress=float(rules.recycling.park_work)
		return
	if p.at!="recycle" or not w.recycling or w.flow.recycle<=0: return
	if not w.recycle_active and w.scrap>=rules.recycling.input and w.parts+rules.recycling.recovered<=rules.limits.stock:
		w.scrap-=float(rules.recycling.input); w.scrap_used+=float(rules.recycling.input); w.recycle_active=true
	if not w.recycle_active: return
	w.recycle_progress+=w.flow.recycle/float(rules.loads.recycle)
	if w.recycle_progress>=float(rules.recycling.work):
		w.parts+=float(rules.recycling.recovered); w.recovered+=float(rules.recycling.recovered); w.residue+=float(rules.recycling.residue); w.cycles+=1; w.recycle_progress=0.0; w.recycle_active=false
func step(w: Dictionary,at: int) -> Array:
	if not w.enabled: return []
	w.elapsed+=1; _people(w); w.irradiance=light(w.elapsed); w.solar_W=0.0
	for id in w.panels:
		var panel=w.panels[id]
		if panel.recipe.is_empty(): continue
		var spec=rules.panels[panel.recipe]; var incoming=w.irradiance*float(rules.solar[id].area_m2)
		var power=incoming*float(spec.efficiency)*panel.quality
		w.sun_J+=incoming; w.pv_J+=power; w.unconverted_J+=incoming-power; w.solar_W+=power
		if incoming>0: panel.quality=maxf(0.2,panel.quality-float(spec.decay_s))
	var heat=rules.heat
	if w.tripped and w.heat_J/float(heat.capacity_J_K)<=float(heat.restart_K_above_ambient): w.tripped=false
	var demand=rules.loads.duplicate(true)
	for id in rules.jobs:
		if w.boost_until[id]>w.elapsed: demand["homes" if id=="lighting" else "fan"]*=float(rules.jobs[id].demand_factor)
	if not w.installed.fan or (w.sink.is_empty() and w.get("custom_sink",{}).is_empty()): demand.fan=0.0
	if not w.installed.server or not w.running or w.tripped or _staff(w,"operator")==0: demand.compute=0.0
	if not w.installed.recycler or not w.recycling or w.people[2].at!="recycle" or w.people[2].task!="work" or (not w.recycle_active and w.scrap<rules.recycling.input): demand.recycle=0.0
	var total=0.0
	for value in demand.values(): total+=float(value)
	w.charge_W=0.0; w.discharge_W=0.0
	var battery=rules.battery
	if w.installed.battery and w.storage_mode=="auto":
		w.discharge_W=minf(maxf(0,total-w.solar_W),minf(float(battery.discharge_W),w.battery_J*float(battery.discharge_efficiency)))
		var take=w.discharge_W/float(battery.discharge_efficiency); w.battery_J-=take; w.discharged_J+=w.discharge_W; w.battery_loss_J+=take-w.discharge_W
	var available=w.solar_W+w.discharge_W
	for id in rules.policies[w.policy]:
		w.flow[id]=minf(available,float(demand[id])); available-=w.flow[id]; w.load_J+=w.flow[id]
	if w.installed.battery and w.storage_mode!="off" and w.discharge_W==0:
		w.charge_W=minf(available,minf(float(battery.charge_W),(float(battery.capacity_J)-w.battery_J)/float(battery.charge_efficiency)))
		w.charge_W=maxf(0,w.charge_W); w.battery_J+=w.charge_W*float(battery.charge_efficiency); w.charged_J+=w.charge_W; w.battery_loss_J+=w.charge_W*(1-float(battery.charge_efficiency)); available-=w.charge_W
	w.curtailed_J+=maxf(0,available)
	w.heat_J+=w.flow.compute; w.compute_J+=w.flow.compute
	var conductance=float(heat.passive_W_K)
	if demand.fan>0:
		var design=w.custom_sink.result if not w.get("custom_sink",{}).is_empty() else lab.design(str(rules.sinks[w.sink].reference))
		conductance+=design.assembly_conductance_W_K*float(heat.sink_scale_W_K)*w.flow.fan/float(demand.fan)
	w.cooling_W=minf(w.heat_J,conductance*w.heat_J/float(heat.capacity_J_K)); w.heat_J-=w.cooling_W; w.removed_heat_J+=w.cooling_W
	if not w.tripped and w.heat_J/float(heat.capacity_J_K)>=float(heat.cutoff_K_above_ambient): w.tripped=true; w.trips+=1
	_job(w); _circular(w)
	w.service=clampf(w.service+(w.flow.homes/maxf(1,float(demand.homes))-.7)*.25+(0.035 if w.park else 0),0,100)
	var messages=[]
	for flag in ["compute","night","overheat","park"]:
		var ready=(w.completed.lighting+w.completed.cooling>0 if flag=="compute" else w.elapsed>=rules.day.daylight if flag=="night" else w.trips>0 if flag=="overheat" else w.park)
		if ready and flag not in w.flags:
			w.flags.append(flag); messages.append({"compute":"计算任务完成：限时调度生效，不能永久免费节能。","night":"夜晚到来，光伏停止；空电池无法继续供电。","overheat":"计算中心热积累触发停机；装好散热、降低任务负载或等待冷却。","park":"再生构件建成口袋公园，居民开始沿路前往休息。"}[flag])
	if int(w.elapsed)%10==0: _record(w,at)
	return messages
func _record(w: Dictionary,at: int) -> void:
	var snapshot={}
	for key in w:
		if key!="history": snapshot[key]=w[key]
	w.history.append({"at":at,"state":snapshot.duplicate(true)})
	while w.history.size()>int(rules.limits.history): w.history.pop_front()
func _num(v,lo: float=0,hi: float=1e12,integer: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi and (not integer or v==floor(float(v)))
func _close(a: float,b: float) -> bool: return absf(a-b)<=maxf(1e-6,maxf(absf(a),absf(b))*1e-9)
func _valid(w,at: int) -> bool:
	if not w is Dictionary or w.get("model")!=rules.model or not _num(w.get("elapsed"),0,at,true): return false
	for key in ["enabled","running","recycling","park_requested","park","tripped","recycle_active"]:
		if not w.get(key) is bool: return false
	if not w.enabled and w.elapsed!=0: return false
	if not w.get("family_receipts",{}) is Dictionary or w.get("family_receipts",{}).size()>96: return false
	for id in w.get("family_receipts",{}):
		if not id is String or not id.begins_with("custom:") or id.length()!=31 or not _num(w.family_receipts[id],1,1000000,true): return false
	if not custom.valid_receipts(w.get("custom_receipts",[])) or not w.get("custom_sink",{}) is Dictionary: return false
	if not w.get("custom_sink",{}).is_empty():
		var d=w.custom_sink
		if not w.enabled or not custom.valid(d) or d.kind!="sink" or not custom_fits(d): return false
		if d.basis=="family_model":
			if int(w.get("family_receipts",{}).get(d.id,0))<1: return false
		elif d.id not in w.get("custom_receipts",[]): return false
	if not rules.policies.has(w.get("policy")) or w.get("storage_mode") not in ["auto","reserve","off"] or not rules.jobs.has(w.get("job_kind")): return false
	for key in ENERGY+["battery_J","heat_J","scrap","scrap_added","scrap_used","parts","recovered","residue","park_spent"]:
		if not _num(w.get(key)): return false
	if not _close(w.sun_J,w.pv_J+w.unconverted_J) or not _close(w.pv_J+w.discharged_J,w.load_J+w.charged_J+w.curtailed_J): return false
	if not _close(w.charged_J,w.discharged_J+w.battery_J+w.battery_loss_J) or not _close(w.charged_J*rules.battery.charge_efficiency,w.battery_J+w.discharged_J/rules.battery.discharge_efficiency): return false
	if not _close(w.compute_J,w.heat_J+w.removed_heat_J) or w.compute_J>w.load_J+1e-6 or w.battery_J>rules.battery.capacity_J+1e-6: return false
	if not _close(w.scrap_added,w.scrap+w.scrap_used) or not _close(w.recovered,w.parts+w.park_spent): return false
	if not _num(w.get("cycles"),0,w.elapsed,true) or not _num(w.get("trips"),0,w.elapsed,true): return false
	if not _close(w.scrap_used,(w.cycles+int(w.recycle_active))*rules.recycling.input) or not _close(w.recovered,w.cycles*rules.recycling.recovered) or not _close(w.residue,w.cycles*rules.recycling.residue): return false
	if not _num(w.get("park_progress"),0,rules.recycling.park_work) or w.park!=(w.park_progress==rules.recycling.park_work) or w.park_spent not in [0.0,float(rules.recycling.park_parts)] or (w.park_progress>0 and w.park_spent==0): return false
	if not _num(w.get("recycle_progress"),0,float(rules.recycling.work)-1e-9) or (not w.recycle_active and w.recycle_progress!=0): return false
	if w.scrap>rules.limits.stock or w.parts>rules.limits.stock: return false
	if not _num(w.get("service"),0,100) or not _num(w.get("irradiance"),0,rules.day.peak_W_m2): return false
	for key in ["solar_W","charge_W","discharge_W","cooling_W"]:
		if not _num(w.get(key),0,100000): return false
	if not _close(w.irradiance,light(w.elapsed)) or w.charge_W>rules.battery.charge_W or w.discharge_W>rules.battery.discharge_W or (w.charge_W>0 and w.discharge_W>0): return false
	for key in ["installed","flow","panels","received","scrapped","completed","boost_until"]:
		if not w.get(key) is Dictionary: return false
	if w.installed.size()!=4 or w.flow.size()!=4 or w.panels.size()!=2 or w.received.size()!=rules.trial_products.size() or w.scrapped.size()!=rules.trial_products.size(): return false
	for id in ["battery","server","fan","recycler"]:
		if not w.installed.get(id) is bool: return false
	for id in rules.loads:
		if not _num(w.flow.get(id),0,rules.loads[id]): return false
	var installed={}; var generated_scrap=0.0
	for id in rules.trial_products: installed[id]=0
	for node in rules.solar:
		var panel=w.panels.get(node)
		if not panel is Dictionary or not panel.get("recipe") is String or not _num(panel.get("quality"),0.2,1): return false
		if not panel.recipe.is_empty():
			if not rules.panels.has(panel.recipe) or rules.panels[panel.recipe].mass_kg_m2*rules.solar[node].area_m2>rules.solar[node].max_mass_kg: return false
			installed[panel.recipe]+=1
	if not w.get("sink") is String or (not w.sink.is_empty() and not rules.sinks.has(w.sink)): return false
	if not w.sink.is_empty(): installed[w.sink]+=1
	for id in rules.deliveries:
		if rules.deliveries[id].has("install"): installed[id]+=int(w.installed[rules.deliveries[id].install])
	for id in rules.trial_products:
		if not _num(w.received.get(id),0,1e7,true) or not _num(w.scrapped.get(id),0,1e7,true): return false
		if id=="modern_scrap":
			if w.scrapped[id]!=0: return false
			generated_scrap+=w.received[id]*rules.deliveries[id].scrap
		else:
			if w.received[id]!=installed[id]+w.scrapped[id]: return false
			if rules.panels.has(id): generated_scrap+=w.scrapped[id]*2
			elif rules.sinks.has(id): generated_scrap+=w.scrapped[id]
			elif w.scrapped[id]!=0: return false
	if not _close(generated_scrap,w.scrap_added): return false
	if not w.get("job") is Dictionary or not rules.jobs.has(w.job.get("kind")) or not _num(w.job.get("progress"),0,float(rules.jobs[w.job.kind].work)-1e-9): return false
	if w.completed.size()!=2 or w.boost_until.size()!=2: return false
	var completed_work=0.0
	for id in rules.jobs:
		if not _num(w.completed.get(id),0,w.elapsed,true) or not _num(w.boost_until.get(id),0,w.elapsed+rules.jobs[id].duration,true) or (w.completed[id]==0 and w.boost_until[id]!=0): return false
		completed_work+=w.completed[id]*float(rules.jobs[id].work)
	if completed_work+w.job.progress>w.compute_J/float(rules.loads.compute)+1e-6: return false
	if not w.get("people") is Array or w.people.size()!=ROLES.size(): return false
	for i in range(w.people.size()):
		var p=w.people[i]
		if not p is Dictionary or p.get("id")!=i or p.get("role")!=ROLES[i] or not rules.nodes.has(p.get("at")) or not p.get("route") is Array or p.route.size()>2 or not _num(p.get("progress"),0,0.999999999): return false
		if p.get("task") not in ["waiting","home","work","leisure","travel"] or (p.task=="travel")!=not p.route.is_empty() or (p.route.is_empty() and p.progress!=0): return false
		var prev=str(p.at)
		for target in p.route:
			if not rules.nodes.has(target) or target==prev or (prev!="junction" and target!="junction"): return false
			prev=target
	if not w.get("flags") is Array or w.flags.size()>4: return false
	var seen=[]
	for flag in w.flags:
		if flag not in ["compute","night","overheat","park"] or flag in seen: return false
		seen.append(flag)
	return true
func valid(w,at: int) -> bool:
	if not _valid(w,at) or not w.get("history") is Array or w.history.is_empty() or w.history.size()>int(rules.limits.history): return false
	var last=-1; var elapsed=-1
	for item in w.history:
		if not item is Dictionary or not _num(item.get("at"),last+1,at,true) or not _valid(item.get("state"),int(item.at)) or item.state.has("history"): return false
		if item.state.elapsed<=elapsed or item.state.elapsed>w.elapsed: return false
		last=int(item.at); elapsed=int(item.state.elapsed)
	return true

func custom_fits(d: Dictionary) -> bool:
	return d.result.area_m2<=float(custom.rules.sink_mount.max_area_m2)+1e-12 and d.result.mass_kg<=float(custom.rules.sink_mount.max_mass_kg)+1e-9
func can_custom(w: Dictionary,site: String,d: Dictionary) -> bool:
	return w.enabled and site=="modern_cooling" and custom.valid(d) and d.kind=="sink" and (w.get("custom_receipts",[]).size()<int(custom.rules.trial_placements) if d.basis=="player_hypothesis" else int(w.get("family_receipts",{}).get(d.id,0))<1000000) and w.get("custom_sink",{}).get("id","")!=d.id and custom_fits(d)
func deploy_custom(w: Dictionary,site: String,d: Dictionary) -> void:
	if not can_custom(w,site,d): return
	w.custom_sink=d.duplicate(true)
	if d.basis=="family_model": w.family_receipts[d.id]=int(w.family_receipts.get(d.id,0))+1
	else: w.custom_receipts.append(d.id)
