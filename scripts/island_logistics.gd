extends RefCounted
## Assigns real trips; the facade alone commits completed collections/installations.
var rounds: Dictionary={}
var tasks: Dictionary={}

func prepare(people: Array, reactors: Array, reachable: Array, storage, config: Dictionary) -> Dictionary:
	var orders={}
	var reserved={}
	var next_tasks={}
	for p in people:
		if p.role!="doctor" or p.get("post","auto") not in ["auto","logistics"] or int(p.research_job)>=0: continue
		var id=str(int(p.id))
		var home=int(p.home_plot)
		var task={}
		# Element substitutions are installation jobs, not research projects.
		for i in range(reactors.size()):
			var r: Dictionary=reactors[i]
			if not r.get("installation",{}).is_empty() and int(r.plot) in reachable and not reserved.has(i):
				task={"activity":"install","target":int(r.plot),"reactor":i}; break
		if task.is_empty() and home in reachable:
			if int(rounds.get(id,0))>0:
				var best=-1
				for i in range(reactors.size()):
					if int(reactors[i].plot) not in reachable or reserved.has(i) or int(reactors[i].get("pending",0))<=0: continue
					if best<0 or int(reactors[i].pending)>int(reactors[best].pending): best=i
				if best>=0: task={"activity":"collect","target":int(reactors[best].plot),"reactor":best}
			elif storage.food_count(home)>0:
				task={"activity":"snack","target":home,"reactor":-1}
			else: task={"activity":"supply_wait","target":home,"reactor":-1}
		if task.is_empty(): continue
		var old: Dictionary=tasks.get(id,{})
		task.elapsed=float(old.get("elapsed",0)) if old.get("activity")==task.activity and int(old.get("reactor",-2))==int(task.reactor) else 0.0
		if int(task.reactor)>=0: reserved[int(task.reactor)]=true
		next_tasks[id]=task; orders[int(p.id)]=task
	tasks=next_tasks
	# Discharged residents do not leave unbounded records behind.
	var ids=[]
	for p in people: ids.append(str(int(p.id)))
	for id in rounds.keys():
		if id not in ids: rounds.erase(id)
	return orders

func arrivals(people: Array, dt: float, storage, rules: Dictionary) -> Array:
	var result=[]
	for p in people:
		var id=str(int(p.id))
		if not tasks.has(id): continue
		var task: Dictionary=tasks[id]
		if not p.arrived or p.activity!=task.activity or int(p.current_plot)!=int(task.target): continue
		if task.activity=="snack":
			var kind: String=storage.eat(int(p.home_plot))
			if kind.is_empty(): continue
			rounds[id]=int(rules.consumables[kind].rounds)
			p.hunger=maxf(0,float(p.hunger)-float(rules.consumables[kind].hunger_recovery))
		elif task.activity=="install": result.append({"kind":"install","reactor":int(task.reactor),"person":int(p.id)})
		elif task.activity=="collect":
			task.elapsed+=dt
			if task.elapsed>=float(rules.logistics.collection_seconds):
				result.append({"kind":"collect","reactor":int(task.reactor),"person":int(p.id)})
				task.elapsed=0.0
	return result
