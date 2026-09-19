extends RefCounted
## Resource and household simulation; no wallet, render nodes or random call order.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_village.json"))
const TASKS=["rest","drink","eat","fetch","farm","mill","craft","build"]

func fresh(at: int=0,enabled: bool=false) -> Dictionary:
	var zero={}; var projects={}; var people=[]
	for id in rules.initial: zero[id]=0.0
	for id in rules.projects: projects[id]={"approved":not rules.projects[id].approval,"paused":false,"committed":false,"progress":0.0,"complete":false}
	for i in range(rules.people.size()):
		people.append({"id":i,"at":"home","route":[],"fraction":0.0,"task":"","stage":"idle","target":"home","work":0.0,"thirst":float(i*3),"hunger":float(i*2),"cargo":{},"load":{},"project":""})
	var w={"model":rules.model,"era":rules.era,"enabled":enabled,"elapsed":0,"policy":"care","diversion":0.5,"passage":100.0,"mill_running":false,
		"started":{"drink":0,"eat":0,"farm":0,"mill":0,"craft":0},"completed":{"drink":0,"eat":0,"farm":0,"mill":0,"craft":0},"stock":rules.initial.duplicate(true),"added":zero.duplicate(),"produced":zero.duplicate(),"used":zero.duplicate(),"exported":zero.duplicate(),
		"spring":float(rules.spring.initial),"spring_taken":0.0,"spring_overflow":0.0,"projects":projects,"active_project":"","people":people,"trades":0,"trade_clock":0,"flags":[],"history":[]}
	_record(w,at); return w

func resources() -> Array: return rules.initial.keys()

func carried(w: Dictionary,id: String) -> float:
	var n=0.0
	for p in w.people: n+=float(p.cargo.get(id,0))
	return n

func can_deploy(w: Dictionary,site: String,recipe: String) -> bool:
	if not w.enabled or site!="village_depot" or not rules.deliveries.has(recipe): return false
	for key in rules.deliveries[recipe]:
		var n=float(rules.deliveries[recipe][key])
		if w.stock[key]+carried(w,key)+n>float(rules.stock_limit) or w.added[key]+n>float(rules.input_limit): return false
	return true

func deploy(w: Dictionary,recipe: String) -> void:
	for key in rules.deliveries[recipe]:
		w.stock[key]+=float(rules.deliveries[recipe][key]); w.added[key]+=float(rules.deliveries[recipe][key])

func control(w: Dictionary,action: String,id: String="") -> String:
	if not w.enabled: return "先开启河湾聚落"
	if action=="policy" and rules.policy_scores.has(id): w.policy=id; return "聚落优先方向已调整；已承诺项目继续执行"
	if action=="diversion":
		w.diversion={0.0:0.5,0.5:1.0,1.0:0.0}[float(w.diversion)]
		return "水磨引水比例：%d%%；未建成水磨时不引水" % roundi(w.diversion*100)
	if not rules.projects.has(id): return "未知聚落操作"
	var p=w.projects[id]
	if p.complete: return "这个项目已经完成"
	if action=="approve": p.approved=true; return "居民可以安排"+str(rules.projects[id].name)
	if action=="pause": p.paused=not p.paused; return "项目已暂停，投料和进度保留" if p.paused else "项目已恢复"
	return "未知聚落操作"

func _enough(w: Dictionary,cost: Dictionary) -> bool:
	for key in cost:
		if float(w.stock[key])+0.0000001<float(cost[key]): return false
	return true

func candidates(w: Dictionary) -> Array:
	var result=[]
	for id in rules.projects:
		var q=w.projects[id]; var spec=rules.projects[id]
		if q.complete: continue
		var reason="可以开工"
		if not q.approved: reason="等待你批准"
		elif q.paused: reason="项目暂停"
		else:
			for prior in spec.requires:
				if not w.projects[prior].complete: reason="先完成"+str(rules.projects[prior].name)
			if reason=="可以开工" and not q.committed and not _enough(w,spec.inputs): reason="缺少构件或工具"
		var score=float(rules.policy_scores[w.policy][id])
		if id=="cistern" and w.stock.drink<8: score+=25
		if id=="mill" and w.stock.food<5: score+=20
		result.append({"id":id,"score":score,"reason":reason,"ready":reason=="可以开工"})
	result.sort_custom(func(a,b): return a.score>b.score)
	return result

func _route(start: String,finish: String) -> Array:
	if start==finish: return []
	var queue=[[start]]; var seen=[start]
	while not queue.is_empty():
		var path: Array=queue.pop_front(); var last=path[-1]
		for edge in rules.edges:
			var next=str(edge[1]) if edge[0]==last else (str(edge[0]) if edge[1]==last else "")
			if next.is_empty() or next in seen: continue
			var branch=path.duplicate(); branch.append(next)
			if next==finish: return branch
			seen.append(next); queue.append(branch)
	return []

func _go(p: Dictionary,node: String) -> void:
	p.target=node; p.route=_route(str(p.at),node); p.fraction=0.0

func _idle(p: Dictionary) -> void:
	p.task=""; p.stage="idle"; p.project=""; p.load={}; p.work=0.0; p.route=[]; p.fraction=0.0; p.target=p.at

func _begin(w: Dictionary,p: Dictionary,task: String,project: String="") -> void:
	p.task=task; p.project=project; p.work=0.0; p.load={}
	p.stage="pickup" if task in ["drink","eat","farm","mill","craft","build"] else "work"
	_go(p,"depot" if p.stage=="pickup" else ("well" if task=="fetch" else "home"))

func _choose(w: Dictionary,p: Dictionary) -> void:
	var n=rules.needs
	if p.thirst>=float(n.threshold) and w.stock.drink>=float(n.drink_cost): _begin(w,p,"drink"); return
	if p.hunger>=float(n.threshold) and w.stock.food>=float(n.food_cost): _begin(w,p,"eat"); return
	var preferred=str(rules.people[int(p.id)].work)
	if (preferred=="fetch" or p.thirst>=float(n.critical)) and w.stock.drink<14 and w.spring>=1: _begin(w,p,"fetch"); return
	if preferred=="build":
		if not w.active_project.is_empty():
			var q=w.projects[w.active_project]
			if not q.paused: _begin(w,p,"build",w.active_project); return
		else:
			for q in candidates(w):
				if q.ready: _begin(w,p,"build",q.id); return
	if preferred=="craft":
		# A community reserve prevents incidental crafts from eating an approved build's last beam.
		var reserve=0.0
		if w.policy!="workshop":
			for q in candidates(w):
				if w.projects[q.id].approved and not w.projects[q.id].committed: reserve=float(rules.projects[q.id].inputs.frames); break
		if w.stock.frames<reserve+1: _begin(w,p,"rest"); return
	if preferred in ["build","fetch"]: preferred="farm"
	var recipe=rules.jobs.get(preferred,{})
	if not recipe.is_empty() and _enough(w,recipe.inputs):
		var room=true
		for key in recipe.outputs:
			if w.stock[key]+carried(w,key)+float(recipe.outputs[key])>float(rules.stock_limit): room=false
		if room: _begin(w,p,preferred); return
	_begin(w,p,"rest")

func _pickup(w: Dictionary,p: Dictionary) -> void:
	var cost={}; var target="depot"
	if p.task=="drink": cost={"drink":float(rules.needs.drink_cost)}
	elif p.task=="eat": cost={"food":float(rules.needs.food_cost)}
	elif p.task=="build":
		var q=w.projects[p.project]
		if q.paused or q.complete or (not w.active_project.is_empty() and w.active_project!=p.project): _idle(p); return
		if not q.committed: cost=rules.projects[p.project].inputs
		target=str(rules.projects[p.project].node)
	else:
		cost=rules.jobs[p.task].inputs; target={"farm":"field","mill":"mill","craft":"market"}[p.task]
	if not _enough(w,cost): _idle(p); return
	for key in cost: w.stock[key]=maxf(0,float(w.stock[key])-float(cost[key])); w.used[key]+=float(cost[key])
	p.load=cost.duplicate(true)
	if w.started.has(p.task): w.started[p.task]+=1
	if p.task=="build": w.projects[p.project].committed=true; w.active_project=p.project
	p.stage="work"; _go(p,target)

func _store(w: Dictionary,p: Dictionary) -> void:
	for key in p.cargo.keys():
		var n=minf(float(p.cargo[key]),float(rules.stock_limit)-float(w.stock[key]))
		w.stock[key]+=n; p.cargo[key]-=n
		if p.cargo[key]<0.0000001: p.cargo.erase(key)
	if p.cargo.is_empty(): _idle(p)

func step(w: Dictionary,at: int) -> Array:
	if not w.enabled: return []
	w.elapsed+=1; var events=[]; var inflow=float(rules.spring.inflow)
	w.spring+=inflow
	if w.spring>float(rules.spring.capacity): w.spring_overflow+=w.spring-float(rules.spring.capacity); w.spring=float(rules.spring.capacity)
	w.mill_running=false
	for p in w.people:
		p.thirst=minf(100,p.thirst+float(rules.needs.thirst_rate)); p.hunger=minf(100,p.hunger+float(rules.needs.hunger_rate))
		if p.stage=="idle": _choose(w,p); continue
		if p.route.size()>1:
			var speed=float(rules.travel_seconds)*(float(rules.road_factor) if w.projects.road.complete else 1.0)
			p.fraction+=1.0/speed
			if p.fraction>=1:
				p.at=p.route[1]; p.route.pop_front(); p.fraction-=1.0
				if p.route.size()==1: p.route=[]; p.fraction=0.0
			continue
		if p.stage=="pickup": _pickup(w,p); continue
		if p.stage=="return": _store(w,p); continue
		if p.task=="build" and w.projects[p.project].paused: _idle(p); continue
		var rate=0.4 if maxf(p.thirst,p.hunger)>=float(rules.needs.critical) else 1.0
		if p.task=="mill" and w.projects.mill.complete and w.diversion>0:
			w.mill_running=true; rate*=1.0+float(rules.river.mill_speed_bonus)*w.diversion
		p.work+=rate
		if p.task=="build":
			var q=w.projects[p.project]; var spec=rules.projects[p.project]
			q.progress=minf(float(spec.work),q.progress+rate)
			if q.progress>=float(spec.work):
				q.complete=true; w.active_project=""; events.append(str(spec.name)+"完工；居民会使用新的设施。"); _idle(p)
			continue
		var duration=6.0 if p.task=="rest" else float(rules.work_seconds[p.task])
		if p.work<duration: continue
		if w.completed.has(p.task): w.completed[p.task]+=1
		if p.task=="drink": p.thirst=maxf(0,p.thirst-float(rules.needs.drink_recovery))
		elif p.task=="eat": p.hunger=maxf(0,p.hunger-float(rules.needs.food_recovery))
		elif p.task=="fetch":
			var n=minf(w.spring,minf(maxf(0,float(rules.stock_limit)-w.stock.drink-carried(w,"drink")),float(rules.spring.fetch)*(1.5 if w.projects.cistern.complete else 1.0)))
			w.spring-=n; w.spring_taken+=n; p.cargo={"drink":n}; w.produced.drink+=n
		elif rules.jobs.has(p.task):
			p.cargo=rules.jobs[p.task].outputs.duplicate(true)
			for key in p.cargo: w.produced[key]+=float(p.cargo[key])
		if not p.cargo.is_empty(): p.load={}; p.stage="return"; _go(p,"depot")
		else: _idle(p)
	var diversion=w.diversion if w.projects.mill.complete else 0.0
	w.passage=clampf(w.passage+float(rules.river.passage_recovery)*(1.0-diversion)-float(rules.river.diversion_penalty)*diversion,0,100)
	if w.projects.market.complete:
		w.trade_clock=mini(int(rules.market.seconds),int(w.trade_clock)+1)
		var trade=rules.market
		if w.trade_clock>=int(trade.seconds) and w.stock.goods>=float(trade.goods) and w.stock.drink+float(trade.drink)<=float(rules.stock_limit) and w.stock.food+float(trade.food)<=float(rules.stock_limit):
			w.trade_clock=0; w.trades+=1; w.stock.goods-=float(trade.goods); w.exported.goods+=float(trade.goods)
			for key in ["drink","food"]: w.stock[key]+=float(trade[key]); w.produced[key]+=float(trade[key])
	if w.passage<35 and "river" not in w.flags: w.flags.append("river"); events.append("引水设施让原河道通行变差；降低引水比例可逐渐恢复。")
	if w.stock.water<2 and "water" not in w.flags: w.flags.append("water"); events.append("农作用水不足，农户正在等供给；生活饮水不能替代这份生产预算。")
	if at%int(rules.history.every_seconds)==0: _record(w,at)
	return events

func _record(w: Dictionary,at: int) -> void:
	var state={}
	for key in w:
		if key!="history": state[key]=w[key]
	w.history.append({"at":at,"state":state.duplicate(true)})
	while w.history.size()>int(rules.history.limit): w.history.pop_front()

func _num(v,lo: float,hi: float,integer: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi and (not integer or floor(float(v))==float(v))

func _amounts(d,complete: bool=false) -> bool:
	if not d is Dictionary or (complete and d.size()!=rules.initial.size()): return false
	for key in d:
		if not rules.initial.has(key) or not _num(d[key],0,100000000): return false
	return true

func _same_amounts(a: Dictionary,b: Dictionary) -> bool:
	if a.size()!=b.size(): return false
	for key in a:
		if not b.has(key) or absf(float(a[key])-float(b[key]))>0.0000001: return false
	return true

func valid(w,at: int,history: bool=true) -> bool:
	if not w is Dictionary or w.get("model")!=rules.model or w.get("era")!=rules.era: return false
	if not w.get("enabled") is bool or not _num(w.get("elapsed"),0,at,true) or not rules.policy_scores.has(str(w.get("policy",""))): return false
	if w.get("diversion") not in [0.0,0.5,1.0] or not _num(w.get("passage"),0,100) or not w.get("mill_running") is bool: return false
	for key in ["stock","added","produced","used","exported"]:
		if not _amounts(w.get(key),true): return false
	for key in resources():
		if w.stock[key]>float(rules.stock_limit) or w.added[key]>float(rules.input_limit): return false
	for key in ["spring","spring_taken","spring_overflow"]:
		if not _num(w.get(key),0,100000000): return false
	if w.spring>float(rules.spring.capacity) or absf(w.spring+w.spring_taken+w.spring_overflow-float(rules.spring.initial)-float(rules.spring.inflow)*w.elapsed)>0.0001: return false
	if not w.get("projects") is Dictionary or w.projects.size()!=rules.projects.size(): return false
	var active=[]
	for id in rules.projects:
		var q=w.projects.get(id)
		if not q is Dictionary: return false
		for key in ["approved","paused","committed","complete"]:
			if not q.get(key) is bool: return false
		if not _num(q.get("progress"),0,float(rules.projects[id].work)): return false
		if q.complete!=(q.progress==float(rules.projects[id].work)) or (q.progress>0 and not q.committed): return false
		if q.committed:
			if not q.approved: return false
			for required in rules.projects[id].requires:
				if not w.projects.get(required,{}).get("complete",false): return false
			if not q.complete: active.append(id)
	if active.size()>1 or w.get("active_project")!=("" if active.is_empty() else active[0]): return false
	if not w.get("people") is Array or w.people.size()!=rules.people.size(): return false
	for i in range(w.people.size()):
		var p=w.people[i]
		if not p is Dictionary or p.get("id")!=i or not rules.nodes.has(str(p.get("at",""))) or not rules.nodes.has(str(p.get("target",""))): return false
		if p.get("task") not in TASKS+[""] or p.get("stage") not in ["idle","pickup","work","return"]: return false
		if (p.stage=="idle")!=(p.task==""): return false
		if not _num(p.get("work"),0,1000000) or not _num(p.get("fraction"),0,0.99999999): return false
		for need in ["thirst","hunger"]:
			if not _num(p.get(need),0,100): return false
		if not _amounts(p.get("cargo")) or not _amounts(p.get("load")): return false
		if not p.get("route") is Array or p.route.size()>rules.nodes.size(): return false
		if not p.route.is_empty():
			if p.route.size()<2 or p.route[0]!=p.at or p.route[-1]!=p.target: return false
			var seen=[]
			for j in range(p.route.size()):
				var node=p.route[j]
				if not rules.nodes.has(str(node)) or node in seen: return false
				seen.append(node)
				if j>0 and [p.route[j-1],node] not in rules.edges and [node,p.route[j-1]] not in rules.edges: return false
		elif p.fraction!=0: return false
		if p.task=="build":
			if not rules.projects.has(str(p.get("project",""))): return false
		elif p.get("project")!="": return false
		if not p.cargo.is_empty() and p.stage!="return": return false
		if p.stage=="idle":
			if not p.load.is_empty() or not p.route.is_empty() or p.at!=p.target or p.work!=0: return false
		elif p.stage=="pickup":
			if p.task not in ["drink","eat","farm","mill","craft","build"] or p.target!="depot" or not p.load.is_empty() or p.work!=0: return false
		elif p.stage=="return":
			if p.task not in ["fetch","farm","mill","craft"] or p.target!="depot" or not p.load.is_empty(): return false
			var outputs={"drink":float(rules.spring.fetch)*1.5} if p.task=="fetch" else rules.jobs[p.task].outputs
			for key in p.cargo:
				if not outputs.has(key) or float(p.cargo[key])>float(outputs[key]): return false
		elif p.stage=="work":
			var target={"drink":"depot","eat":"depot","fetch":"well","farm":"field","mill":"mill","craft":"market","rest":"home"}.get(p.task,"")
			if p.task=="build":
				if not w.projects[p.project].committed or w.projects[p.project].complete: return false
				target=rules.projects[p.project].node
				if not p.load.is_empty() and not _same_amounts(p.load,rules.projects[p.project].inputs): return false
			elif p.task in ["rest","fetch"]:
				if not p.load.is_empty(): return false
			else:
				var inputs={"drink":float(rules.needs.drink_cost)} if p.task=="drink" else ({"food":float(rules.needs.food_cost)} if p.task=="eat" else rules.jobs[p.task].inputs)
				if not _same_amounts(p.load,inputs): return false
			if p.target!=target: return false
		if p.route.is_empty() and p.at!=p.target: return false
	for key in resources():
		if absf(w.stock[key]+carried(w,key)+w.used[key]+w.exported[key]-float(rules.initial[key])-w.added[key]-w.produced[key])>0.0001: return false
	if not _num(w.get("trades"),0,10000000,true) or not _num(w.get("trade_clock"),0,float(rules.market.seconds),true): return false
	var expected_used={}; var expected_produced={}; var expected_exports={}
	for key in resources(): expected_used[key]=0.0; expected_produced[key]=0.0; expected_exports[key]=0.0
	for table in ["started","completed"]:
		if not w.get(table) is Dictionary or w[table].size()!=5: return false
		for key in ["drink","eat","farm","mill","craft"]:
			if not _num(w[table].get(key),0,100000000,true): return false
	for task in w.started:
		if w.completed[task]>w.started[task]: return false
		var active_count=0
		for p in w.people:
			if p.task==task and p.stage=="work": active_count+=1
		if w.started[task]-w.completed[task]!=active_count: return false
		var cost={"drink":float(rules.needs.drink_cost)} if task=="drink" else ({"food":float(rules.needs.food_cost)} if task=="eat" else rules.jobs[task].inputs)
		for key in cost: expected_used[key]+=float(cost[key])*w.started[task]
		if rules.jobs.has(task):
			for key in rules.jobs[task].outputs: expected_produced[key]+=float(rules.jobs[task].outputs[key])*w.completed[task]
	for id in w.projects:
		if w.projects[id].committed:
			for key in rules.projects[id].inputs: expected_used[key]+=float(rules.projects[id].inputs[key])
	expected_produced.drink+=w.spring_taken+float(rules.market.drink)*w.trades
	expected_produced.food+=float(rules.market.food)*w.trades
	expected_exports.goods=float(rules.market.goods)*w.trades
	for key in resources():
		if absf(w.used[key]-expected_used[key])>0.0001 or absf(w.produced[key]-expected_produced[key])>0.0001 or absf(w.exported[key]-expected_exports[key])>0.0001: return false
	if not w.get("flags") is Array or w.flags.size()>2: return false
	for flag in w.flags:
		if flag not in ["river","water"]: return false
	if history:
		if not w.get("history") is Array or w.history.size()>int(rules.history.limit): return false
		var last=-1
		for entry in w.history:
			if not entry is Dictionary or not _num(entry.get("at"),last+1,at,true) or not valid(entry.get("state"),int(entry.at),false): return false
			last=int(entry.at)
	return true
