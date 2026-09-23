extends RefCounted
## Fixed-step world utility and logistics simulation. Rendering and global inventory are separate.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_industry.json"))
var electrical=preload("res://scripts/electrical_lab.gd").new()
var custom=preload("res://scripts/player_fixture.gd").new()
const ENERGY=["chemical_J","electric_J","heat_J","engine_loss_J","wire_loss_J","load_J","unused_J","recovered_J","useful_heat_J","rejected_heat_J","transport_J","transport_loss_J"]
const ROLES=["repair","factory","factory","clinic","signal","homes"]

func fresh(era: String="ww1",at: int=0,enabled: bool=false) -> Dictionary:
	var zero={}; var cables={}; var flow={}; var integrity={}; var people=[]; var installed={}
	for id in rules.initial: zero[id]=0.0
	for id in rules.loads: cables[id]=""; flow[id]=0.0
	for id in rules.nodes: integrity[id]=1.0
	for id in electrical.data.designs: installed[id]=0
	for i in range(ROLES.size()): people.append({"id":i,"role":ROLES[i],"at":"depot","route":[],"progress":0.0,"task":"waiting"})
	var w={"model":rules.model,"custom_cables":{},"custom_receipts":[],"era":era,"enabled":enabled,"elapsed":0,"policy":"care","engine":false,"running":true,"recovery":false,"blackout":false,"repairs":true,
		"stock":rules.initial.duplicate(true),"added":zero.duplicate(),"used":zero.duplicate(),"produced":zero.duplicate(),"shipped":zero.duplicate(),"cables":cables,"cables_received":installed.duplicate(),"cables_scrapped":installed.duplicate(),
		"integrity":integrity,"flow":flow,"engine_fuel_kg":0.0,"transport_fuel_kg":0.0,"generated_W":0.0,"wire_loss_W":0.0,"warmth":70.0,"care":70.0,"heat_service":0.0,"signal_service":0.0,"event_done":false,"alert":false,
		"factory_kind":"civil","factory":{"active":false,"kind":"civil","progress":0.0},"started":0,"completed":0,"repair":{"target":"","progress":0.0},"repairs_started":0,"repairs_completed":0,
		"truck":{"stage":"idle","kind":"civil","amount":0.0,"progress":0.0},"people":people,"flags":[],"history":[]}
	for key in ENERGY: w[key]=0.0
	_record(w,at); return w

func ids() -> Array:
	var result=[]
	for id in rules.nodes:
		if id!="junction": result.append("industry_"+str(id))
	return result

func can_deploy(w: Dictionary,site: String,recipe: String) -> bool:
	if not w.enabled or not site.begins_with("industry_"): return false
	var id=site.trim_prefix("industry_")
	if electrical.data.designs.has(recipe):
		return rules.loads.has(id) and (w.cables[id]!=recipe or w.get("custom_cables",{}).has(id)) and electrical.design(recipe).area_m2<=float(rules.loads[id].max_area_m2)+1e-12
	if not rules.deliveries.has(recipe): return false
	var spec=rules.deliveries[recipe]
	if spec.has("install"): return id=="power" and not w[spec.install]
	if id!="depot": return false
	for key in spec:
		var limit=float(rules.limits.fuel_kg) if key=="fuel_kg" else float(rules.limits.stock)
		if w.stock[key]+spec[key]>limit+1e-9 or w.added[key]+spec[key]>float(rules.limits.ledger): return false
	return true

func deploy(w: Dictionary,site: String,recipe: String) -> void:
	if not can_deploy(w,site,recipe): return
	var id=site.trim_prefix("industry_")
	if electrical.data.designs.has(recipe):
		w.custom_cables.erase(id)
		if not w.cables[id].is_empty(): w.cables_scrapped[w.cables[id]]+=1
		w.cables[id]=recipe; w.cables_received[recipe]+=1; return
	var spec=rules.deliveries[recipe]
	if spec.has("install"): w[spec.install]=true; return
	for key in spec: w.stock[key]+=float(spec[key]); w.added[key]+=float(spec[key])

func control(w: Dictionary,action: String,id: String="") -> String:
	if not w.enabled: return "先开启工业港"
	match action:
		"policy":
			if not rules.policies.has(id): return "未知供电方向"
			w.policy=id; return "供电优先方向已更新；线损与功率不足仍会限制设备"
		"output":
			if id not in ["civil","military"]: return "未知物资类型"
			w.factory_kind=id; return "下一批改为"+("民用修复物资" if id=="civil" else "军需维修物资")+"；在制批次保留原用途"
		"engine": w.running=not w.running; return "动力站已开机" if w.running else "动力站已关机，不再消耗燃料"
		"blackout": w.blackout=not w.blackout; return "住宅灯火管制开启，照明暂停，余热供暖仍可用" if w.blackout else "住宅照明恢复"
		"repairs": w.repairs=not w.repairs; return "工程师继续检修" if w.repairs else "检修暂停，已预留维修件与进度保留"
	return "未知工业港操作"

func _travel(p: Dictionary,target: String) -> void:
	if not p.route.is_empty() or p.at==target: return
	p.route=[target] if p.at=="junction" or target=="junction" else ["junction",target]
	p.progress=0.0

func _move(p: Dictionary) -> void:
	if p.route.is_empty(): return
	p.progress+=1.0/float(rules.people.travel_seconds)
	if p.progress>=1.0-1e-9:
		p.at=p.route.pop_front(); p.progress=0.0

func _staff(w: Dictionary,target: String) -> int:
	var n=0
	for p in w.people:
		if p.at==target and p.route.is_empty() and p.task=="work": n+=1
	return n

func _people(w: Dictionary) -> void:
	if w.repairs and w.repair.target.is_empty() and w.stock.spares>=float(rules.people.repair_cost):
		for id in ["power","signal"]:
			if w.integrity[id]<1:
				w.stock.spares-=float(rules.people.repair_cost); w.used.spares+=float(rules.people.repair_cost); w.repairs_started+=1; w.repair={"target":id,"progress":0.0}; break
	for p in w.people:
		var target="depot" if p.role=="repair" else str(p.role)
		if p.role=="repair" and not w.repair.target.is_empty() and w.repairs: target=w.repair.target
		if w.alert and w.era=="ww2": target="depot"
		_move(p)
		if p.route.is_empty(): _travel(p,target)
		p.task="travel" if not p.route.is_empty() else ("shelter" if w.alert and w.era=="ww2" else ("work" if p.at==target and target!="depot" else "waiting"))
	if not w.repair.target.is_empty() and w.repairs and _staff(w,w.repair.target)>0:
		var p=w.people[0]
		if p.at==w.repair.target and p.task=="work":
			w.repair.progress+=1.0
			if w.repair.progress>=float(rules.people.repair_work):
				w.integrity[w.repair.target]=1.0; w.repairs_completed+=1; w.repair={"target":"","progress":0.0}

func _power(w: Dictionary) -> void:
	var fuel=0.0
	if w.engine and w.running: fuel=minf(w.stock.fuel_kg,float(rules.engine.burn_kg_s)*float(w.integrity.power))
	w.stock.fuel_kg-=fuel; w.used.fuel_kg+=fuel; w.engine_fuel_kg+=fuel
	var chemical=fuel*float(electrical.data.fuel.gasoline_lhv_J_kg)
	var electricity=chemical*float(rules.engine.electric_efficiency); var heat=chemical*float(rules.engine.heat_fraction)
	w.chemical_J+=chemical; w.electric_J+=electricity; w.heat_J+=heat; w.engine_loss_J+=chemical-electricity-heat
	w.generated_W=electricity; w.wire_loss_W=0.0
	var budget=electricity
	for id in rules.loads: w.flow[id]=0.0
	for id in rules.policies[w.policy]:
		if (w.cables[id].is_empty() and not w.get("custom_cables",{}).has(id)) or w.integrity[id]<=0 or (id=="homes" and w.blackout): continue
		var design=w.custom_cables[id].result if w.get("custom_cables",{}).has(id) else electrical.design(w.cables[id]); var spec=rules.loads[id]
		var flow=electrical.circuit(design.resistance_ohm*float(spec.loop_multiplier),float(spec.rated_W),float(electrical.data.fixture.voltage_V),maxf(0,budget))
		budget=maxf(0,budget-flow.source_W); w.flow[id]=flow.load_W; w.load_J+=flow.load_W; w.wire_loss_J+=flow.wire_loss_W; w.wire_loss_W+=flow.wire_loss_W
	w.unused_J+=budget
	var recovered=heat*float(rules.engine.heat_recovery_fraction) if w.recovery else 0.0
	var useful=minf(recovered,float(rules.engine.heat_demand_W))
	w.recovered_J+=recovered; w.useful_heat_J+=useful; w.rejected_heat_J+=heat-useful
	w.heat_service=useful/float(rules.engine.heat_demand_W)
	w.signal_service=w.flow.signal/float(rules.loads.signal.rated_W) if _staff(w,"signal")>0 else 0.0
	var light=w.flow.homes/float(rules.loads.homes.rated_W)
	w.warmth=clampf(w.warmth+float(rules.people.warmth_recovery)*(w.heat_service+light)-float(rules.people.warmth_decay)*(1-w.heat_service),0,100)
	var medical=w.flow.clinic/float(rules.loads.clinic.rated_W) if _staff(w,"clinic")>0 else 0.0
	w.care=clampf(w.care+float(rules.people.care_recovery)*medical-float(rules.people.care_decay)*(1-medical),0,100)

func _factory(w: Dictionary) -> void:
	if _staff(w,"factory")==0 or w.alert and w.era=="ww2": return
	var ratio=w.flow.factory/float(rules.loads.factory.rated_W)
	if ratio<float(rules.factory.min_power_ratio): return
	if not w.factory.active and w.stock.stock>=float(rules.factory.input) and w.stock.civil+w.stock.military<float(rules.limits.stock):
		w.stock.stock-=float(rules.factory.input); w.used.stock+=float(rules.factory.input); w.started+=1
		w.factory={"active":true,"kind":w.factory_kind,"progress":0.0}
	if not w.factory.active: return
	w.factory.progress+=ratio*_staff(w,"factory")*float(rules.people.work_rate)
	if w.factory.progress>=float(rules.factory.work):
		var kind=str(w.factory.kind); w.stock[kind]+=1.0; w.produced[kind]+=1.0; w.completed+=1; w.factory.active=false; w.factory.progress=0.0

func _shipping(w: Dictionary) -> void:
	var t=w.truck
	if t.stage=="idle":
		if w.alert and w.era=="ww2": return
		for kind in ["civil","military"]:
			if w.stock[kind]>=1:
				t.kind=kind; t.amount=minf(w.stock[kind],float(rules.shipping.capacity)); w.stock[kind]-=t.amount; t.stage="outbound"; t.progress=0.0; break
	else:
		var fuel=minf(w.stock.fuel_kg,float(rules.shipping.burn_kg_s))
		w.stock.fuel_kg-=fuel; w.used.fuel_kg+=fuel; w.transport_fuel_kg+=fuel
		var energy=fuel*float(electrical.data.fuel.gasoline_lhv_J_kg); var mechanical=energy*float(rules.shipping.mechanical_efficiency)
		w.chemical_J+=energy; w.transport_J+=mechanical; w.transport_loss_J+=energy-mechanical
		var speed=(1.0+(float(rules.shipping.signal_multiplier)-1.0)*w.signal_service)*fuel/float(rules.shipping.burn_kg_s)
		t.progress+=speed/float(rules.shipping.travel_seconds)
		if t.progress>=1-1e-9:
			t.progress=0.0
			if t.stage=="outbound":
				w.shipped[t.kind]+=t.amount; t.amount=0.0; t.stage="return"
			else: t.stage="idle"

func step(w: Dictionary,at: int) -> Array:
	if not w.enabled: return []
	w.elapsed+=1; var scenario=rules.eras[w.era]; var messages=[]
	w.alert=w.elapsed>=int(scenario.event_at)-10 and w.elapsed<int(scenario.event_end)
	if not w.event_done and w.elapsed>=int(scenario.event_at):
		w.event_done=true; w.integrity[scenario.damage_target]=float(scenario.damage_to); messages.append(str(scenario.event_name)+"；维修需要工程师到场和有限备件。")
	_people(w); _power(w); _factory(w); _shipping(w)
	if w.completed>0 and "production" not in w.flags: w.flags.append("production"); messages.append("第一批物资完成，运抵仓库才计入交付；供电优先方向影响车间产出。")
	if w.repairs_completed>0 and "repair" not in w.flags: w.flags.append("repair"); messages.append("工程师已完成修复；备件只在开工预留一次。")
	if w.engine and w.stock.fuel_kg<=0 and w.used.fuel_kg>0 and "fuel" not in w.flags: w.flags.append("fuel"); messages.append("动力站燃料耗尽；没有燃料就没有电力或余热。")
	if int(w.elapsed)%10==0: _record(w,at)
	return messages

func _record(w: Dictionary,at: int) -> void:
	var state={}
	for key in w:
		if key!="history": state[key]=w[key]
	w.history.append({"at":at,"state":state.duplicate(true)})
	while w.history.size()>int(rules.limits.history): w.history.pop_front()

func _num(v,lo: float=0,hi: float=1000000000000,integer: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi and (not integer or float(v)==floor(float(v)))
func _close(a: float,b: float) -> bool: return absf(a-b)<=maxf(0.000001,maxf(absf(a),absf(b))*1e-8)

func _valid_state(w,at: int) -> bool:
	if not w is Dictionary or w.get("model")!=rules.model or not rules.eras.has(w.get("era")): return false
	for key in ["enabled","engine","running","recovery","blackout","repairs","event_done","alert"]:
		if not w.get(key) is bool: return false
	if not _num(w.get("elapsed"),0,at,true) or (not w.enabled and w.elapsed!=0) or not rules.policies.has(w.get("policy")) or w.get("factory_kind") not in ["civil","military"]: return false
	var scenario=rules.eras[w.era]
	if w.event_done!=(w.elapsed>=int(scenario.event_at)) or w.alert!=(w.elapsed>=int(scenario.event_at)-10 and w.elapsed<int(scenario.event_end)): return false
	for group in ["stock","added","used","produced","shipped"]:
		if not w.get(group) is Dictionary or w[group].size()!=rules.initial.size(): return false
		for key in rules.initial:
			if not _num(w[group].get(key),0,float(rules.limits.ledger),key!="fuel_kg"): return false
	# v0.16 histories can round a nearly completed trip to exactly 1 in JSON.
	# Accept that arrival boundary; the next simulation step settles it once.
	if not w.get("truck") is Dictionary or w.truck.get("stage") not in ["idle","outbound","return"] or w.truck.get("kind") not in ["civil","military"] or not _num(w.truck.get("amount"),0,rules.shipping.capacity,true) or not _num(w.truck.get("progress"),0,1): return false
	if (w.truck.stage=="outbound")!=(w.truck.amount>=1) or (w.truck.stage=="idle" and w.truck.progress!=0): return false
	for key in rules.initial:
		var cargo=float(w.truck.amount) if key==w.truck.kind else 0.0
		if not _close(rules.initial[key]+w.added[key]+w.produced[key],w.stock[key]+w.used[key]+w.shipped[key]+cargo): return false
		if key not in ["civil","military"] and (w.produced[key]!=0 or w.shipped[key]!=0): return false
		if key in ["civil","military"] and (w.used[key]!=0 or w.added[key]!=0): return false
		if w.stock[key]>(rules.limits.fuel_kg if key=="fuel_kg" else rules.limits.stock)+1e-8: return false
	for key in ENERGY+["engine_fuel_kg","transport_fuel_kg"]:
		if not _num(w.get(key)): return false
	if not _close(w.used.fuel_kg,w.engine_fuel_kg+w.transport_fuel_kg): return false
	if not _close(w.transport_J,w.transport_fuel_kg*float(electrical.data.fuel.gasoline_lhv_J_kg)*float(rules.shipping.mechanical_efficiency)): return false
	if not _close(w.transport_J+w.transport_loss_J,w.transport_fuel_kg*float(electrical.data.fuel.gasoline_lhv_J_kg)): return false
	if not _close(w.chemical_J,w.used.fuel_kg*float(electrical.data.fuel.gasoline_lhv_J_kg)) or not _close(w.chemical_J,w.electric_J+w.heat_J+w.engine_loss_J+w.transport_J+w.transport_loss_J): return false
	if not _close(w.electric_J,w.load_J+w.wire_loss_J+w.unused_J) or not _close(w.heat_J,w.useful_heat_J+w.rejected_heat_J): return false
	if not _close(w.electric_J,w.engine_fuel_kg*float(electrical.data.fuel.gasoline_lhv_J_kg)*float(rules.engine.electric_efficiency)) or not _close(w.heat_J,w.engine_fuel_kg*float(electrical.data.fuel.gasoline_lhv_J_kg)*float(rules.engine.heat_fraction)): return false
	if w.recovered_J>w.heat_J+1e-6 or w.useful_heat_J>w.recovered_J+1e-6: return false
	for key in ["warmth","care"]:
		if not _num(w.get(key),0,100): return false
	for key in ["heat_service","signal_service"]:
		if not _num(w.get(key),0,1): return false
	for key in ["generated_W","wire_loss_W"]:
		if not _num(w.get(key),0,rules.engine.burn_kg_s*electrical.data.fuel.gasoline_lhv_J_kg): return false
	for key in ["cables","flow"]:
		if not w.get(key) is Dictionary or w[key].size()!=rules.loads.size(): return false
	if not custom.valid_receipts(w.get("custom_receipts",[])) or not w.get("custom_cables",{}) is Dictionary or w.get("custom_cables",{}).size()>rules.loads.size(): return false
	var active_ids=[]
	for node in w.get("custom_cables",{}):
		var d=w.custom_cables[node]
		if not w.enabled or not rules.loads.has(node) or not custom.valid(d) or d.kind!="wire" or not custom_fits(node,d): return false
		active_ids.append(d.id)
		if active_ids.count(d.id)>w.get("custom_receipts",[]).count(d.id): return false
	var load=0.0
	for id in rules.loads:
		if not w.cables.get(id) is String or not _num(w.flow.get(id),0,rules.loads[id].rated_W): return false
		if not w.cables[id].is_empty():
			var design=electrical.design(w.cables[id])
			if design.is_empty() or design.area_m2>float(rules.loads[id].max_area_m2)+1e-12: return false
		elif w.flow[id]!=0 and not w.get("custom_cables",{}).has(id): return false
		load+=float(w.flow[id])
	if load+w.wire_loss_W>w.generated_W+1e-6: return false
	for group in ["cables_received","cables_scrapped"]:
		if not w.get(group) is Dictionary or w[group].size()!=electrical.data.designs.size(): return false
		for id in electrical.data.designs:
			if not _num(w[group].get(id),0,10000000,true): return false
	for id in electrical.data.designs:
		if w.cables_received[id]!=w.cables_scrapped[id]+w.cables.values().count(id): return false
	if not w.get("integrity") is Dictionary or w.integrity.size()!=rules.nodes.size(): return false
	for id in rules.nodes:
		if not _num(w.integrity.get(id),0,1): return false
	for key in ["started","completed","repairs_started","repairs_completed"]:
		if not _num(w.get(key),0,w.elapsed,true): return false
	if not w.get("factory") is Dictionary or not w.factory.get("active") is bool or w.factory.get("kind") not in ["civil","military"] or not _num(w.factory.get("progress"),0,float(rules.factory.work)-1e-8): return false
	if not w.factory.active and w.factory.progress!=0: return false
	if w.started!=w.completed+int(w.factory.active) or not _close(w.used.stock,w.started*float(rules.factory.input)) or not _close(w.produced.civil+w.produced.military,w.completed): return false
	if not w.get("repair") is Dictionary or not w.repair.get("target") is String or w.repair.target not in ["","power","signal"] or not _num(w.repair.get("progress"),0,float(rules.people.repair_work)-1e-8): return false
	if w.repair.target.is_empty() and w.repair.progress!=0: return false
	if w.repairs_started!=w.repairs_completed+int(not w.repair.target.is_empty()) or not _close(w.used.spares,w.repairs_started*float(rules.people.repair_cost)): return false
	if not w.get("people") is Array or w.people.size()!=ROLES.size(): return false
	for i in range(w.people.size()):
		var p=w.people[i]
		if not p is Dictionary or p.get("id")!=i or p.get("role")!=ROLES[i] or not rules.nodes.has(p.get("at")) or not p.get("route") is Array or p.route.size()>2 or not _num(p.get("progress"),0,0.999999999): return false
		if p.get("task") not in ["waiting","travel","shelter","work"] or (p.route.is_empty() and p.progress!=0): return false
		if (p.task=="travel")!=not p.route.is_empty(): return false
		var prev=str(p.at)
		for target in p.route:
			if not rules.nodes.has(target) or target==prev or (prev!="junction" and target!="junction"): return false
			prev=target
	if not w.get("flags") is Array or w.flags.size()>3: return false
	var seen=[]
	for flag in w.flags:
		if flag not in ["production","repair","fuel"] or flag in seen: return false
		seen.append(flag)
	return true

func valid(w,at: int) -> bool:
	if not _valid_state(w,at) or not w.get("history") is Array or w.history.is_empty() or w.history.size()>int(rules.limits.history): return false
	var last=-1; var elapsed=-1
	for item in w.history:
		if not item is Dictionary or not _num(item.get("at"),last+1,at,true) or not _valid_state(item.get("state"),int(item.at)): return false
		if item.state.has("history") or item.state.era!=w.era or item.state.elapsed<=elapsed or item.state.elapsed>w.elapsed: return false
		last=int(item.at); elapsed=int(item.state.elapsed)
	return true

func custom_fits(node: String,d: Dictionary) -> bool:
	return rules.loads.has(node) and d.result.area_m2<=float(rules.loads[node].max_area_m2)+1e-12
func can_custom(w: Dictionary,site: String,d: Dictionary) -> bool:
	var node=site.trim_prefix("industry_")
	return w.enabled and site.begins_with("industry_") and custom.valid(d) and d.kind=="wire" and w.get("custom_receipts",[]).size()<int(custom.rules.trial_placements) and w.get("custom_cables",{}).get(node,{}).get("id","")!=d.id and custom_fits(node,d)
func deploy_custom(w: Dictionary,site: String,d: Dictionary) -> void:
	if not can_custom(w,site,d): return
	w.custom_cables[site.trim_prefix("industry_")]=d.duplicate(true); w.custom_receipts.append(d.id)
