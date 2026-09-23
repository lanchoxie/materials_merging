extends RefCounted

# This model knows no UI, wallet or scene nodes. Callers pay a returned cost only
# after ready=true; all operation validation happens before any mutation.
var config: Dictionary = {}
var people: Array = []
var research_jobs: Array = []
var unlocked_materials: Array = []
var pending_requests: Array = []
var day_time: float = 0.0
var elapsed: float = 0.0
var rng = RandomNumberGenerator.new()
var _accumulator: float = 0.0
var _event_clock: float = 0.0
var _daily_requests: int = 0
var _request_day: int = 0
var _serial: int = 1
var _job_serial: int = 1
var _request_serial: int = 1
var _notifications: Array = []
var work_factor: float=1.0

const ACTIVITY_NAMES = {"factory":"车间加工","install":"装载新样品", "collect":"收集待领取产物", "snack":"回公寓吃补给", "supply_wait":"等公寓补给", "construct":"正在施工", "maintain":"维护反应炉", "deliver_meal":"给院士送餐", "research":"在科研院所工作", "eat":"食堂用餐", "home":"回家休息", "park":"在公园休息", "stroll":"散步整理思路", "idle":"在广场待命"}

func _init():
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_people.json"))
	if parsed is Dictionary: config = parsed
	rng.randomize()

func setup(legacy_engineers: int = 1, legacy_scientists: int = 0):
	people.clear(); research_jobs.clear(); unlocked_materials.clear(); pending_requests.clear()
	elapsed = 0; day_time = 0; _accumulator = 0; _event_clock = 0; _daily_requests = 0; _request_day = 0
	_serial = 1; _job_serial = 1; _request_serial = 1
	for i in range(clampi(legacy_engineers, 0, 80)):
		people.append(_new_person("engineer", -1, true))
	for i in range(clampi(legacy_scientists, 0, 16)):
		people.append(_new_person("doctor", -1, true))

func _new_person(role: String, home: int, legacy: bool = false) -> Dictionary:
	var names = ["小林", "小余", "小陈", "小苏", "小周", "小温", "小许", "小叶"]
	var specs: Array = config.roles[role].specialties
	var p = {"post":"auto","id":_serial, "name":str(names[(_serial - 1) % names.size()]) + str(_serial), "role":role,
		"traits":{"diligence":rng.randf_range(0.45,0.95),"leisure":rng.randf_range(0.15,0.85),"sociability":rng.randf_range(0.15,0.95)},
		"specialty":specs[rng.randi_range(0,specs.size()-1)],"hunger":10.0,"morale":75.0,
		"home_plot":home,"work_plot":-1,"activity":"idle","activity_label":ACTIVITY_NAMES.idle,"target_plot":home,
		"legacy_home":legacy,"research_job":-1,"last_request":-float(config.events.person_cooldown_seconds),
		"next_rethink":0.0,"room_comfort":0,"family_visits":0,"meal_recipient":-1,"delivery_left":0.0,"meal_stage":"none","supervisor_id":-1,
		"current_plot":home,"next_plot":home,"movement_progress":0.0,"moving":false,"arrived":false,"travel_target":-1,"travel_route":[],"travel_index":0}
	_serial += 1
	return p

func role_count(role: String) -> int:
	var n = 0
	for p in people:
		if p.role == role: n += 1
	return n

func role_data(role: String) -> Dictionary:
	return config.roles.get(role, {}).duplicate(true)

func posts_for(role: String) -> Array:
	return ["auto","workshop"] if role=="engineer" else (["auto","logistics","research"] if role=="doctor" else ["auto","research"])

func assign_post(id: int,post: String) -> String:
	var p=person(id)
	if p.is_empty() or post not in posts_for(str(p.role)): return "这个岗位不适合该居民"
	if int(p.research_job)>=0 and post not in ["auto","research"]: return "正在参加课题，完成后才能调往其他岗位"
	if p.post==post: return "已经安排这个岗位"
	p.post=post; p.next_rethink=0.0; p.meal_recipient=-1; p.meal_stage="none"; p.delivery_left=0.0
	# Keep the current road segment; the travel solver reroutes at the next node.
	_set_activity(p,"idle",int(p.current_plot)); p.arrived=false
	return p.name+"已改为"+str(config.posts[post])+"，下一次安排生效"

func _factory_workplaces(context: Dictionary) -> Dictionary:
	var remaining={}; var result={}
	for b in _buildings(context,["workshop"]): remaining[int(b.plot)]=int(b.capacity)
	for p in people:
		if p.role!="engineer" or p.get("post","auto")!="workshop": continue
		for plot in remaining:
			if int(remaining[plot])>0: result[int(p.id)]=plot; remaining[plot]-=1; break
	return result

func industrial_rate(context: Dictionary={}) -> float:
	var total=0.0
	var seats=_factory_workplaces(context) if not context.is_empty() else {}
	for p in people:
		if not context.is_empty() and int(seats.get(int(p.id),-1))!=int(p.current_plot): continue
		if p.role=="engineer" and p.get("post","auto")=="workshop" and p.activity=="factory" and p.arrived: total+=_efficiency(p)
	return minf(float(config.production.maximum_rate),total)

func _buildings(context: Dictionary, kinds: Array, connected_only: bool = true) -> Array:
	var result: Array = []
	for b in context.get("buildings", []):
		if str(b.get("kind","")) in kinds and (not connected_only or bool(b.get("connected",false))): result.append(b)
	return result

func _residents(plot: int, ignore_id: int = -1) -> int:
	var n = 0
	for p in people:
		if int(p.id) != ignore_id and int(p.home_plot) == plot: n += 1
	return n

func _free_home(role: String, context: Dictionary, excluded_plot: int = -999) -> int:
	for b in _buildings(context, config.roles[role].housing):
		if int(b.plot) != excluded_plot and _residents(int(b.plot)) < int(b.get("capacity",0)): return int(b.plot)
	return -1

func _wallet_allows(context: Dictionary, cost: int) -> bool:
	return float(context.get("coins",1.0e12)) >= cost

func quote_hire(role: String, context: Dictionary) -> Dictionary:
	var q = {"ready":false,"cost":0,"message":"未知职业","home_plot":-1}
	if not config.roles.has(role): return q
	q.cost = int(config.roles[role].cost)
	if people.size() >= int(config.max_people): q.message = "居民人数已达上限"; return q
	q.home_plot = _free_home(role, context)
	if int(q.home_plot) < 0: q.message = "需要有空床位、已连路的" + _housing_name(role); return q
	if bool(config.roles[role].needs_institute) and _buildings(context,["institute"]).is_empty():
		q.message = "请先建造并连通科研院所"; return q
	if bool(config.roles[role].needs_institute):
		var laboratory_capacity = 0
		for building in _buildings(context,["institute"]): laboratory_capacity += int(building.get("capacity",0))
		var laboratory_residents = role_count("doctor") + role_count("professor") + role_count("academician")
		if laboratory_residents >= laboratory_capacity: q.message = "科研院所工位已满，请升级或增建院所"; return q
	if not _wallet_allows(context,q.cost): q.message = "金币不足"; return q
	q.ready = true; q.message = "招募" + str(config.roles[role].name) + " · " + str(q.cost) + "金币"
	return q

func _housing_name(role: String) -> String:
	return {"engineer":"工程师小屋","doctor":"博士公寓","professor":"教授公寓","academician":"院士别墅"}.get(role,"住宅")

func hire(role: String, context: Dictionary) -> Dictionary:
	var q = quote_hire(role,context)
	if not q.ready: return q
	var p = _new_person(role,int(q.home_plot))
	people.append(p); q.person_id = p.id; q.message = p.name + "已经入住，准备开始工作"
	return q

func dismiss(id: int) -> String:
	for i in range(people.size()):
		if int(people[i].id) == id:
			var pname = str(people[i].name)
			people.remove_at(i)
			for remaining in people:
				if int(remaining.supervisor_id) == id: remaining.supervisor_id = -1
				if int(remaining.meal_recipient) == id: remaining.meal_recipient = -1; remaining.delivery_left = 0; remaining.meal_stage = "none"
			for job in research_jobs:
				if job.status != "complete" and id in job.team: job.team.erase(id); job.status = "waiting_team"
			pending_requests = pending_requests.filter(func(r): return int(r.person_id) != id)
			return pname + "已离开；研发岗位会等待补员"
	return "没有找到这位居民"

func person(id: int) -> Dictionary:
	for p in people:
		if int(p.id) == id: return p
	return {}

func _set_activity(p: Dictionary, activity: String, target: int):
	p.activity = activity; p.activity_label = ACTIVITY_NAMES.get(activity,activity); p.target_plot = target

func _first_plot(context: Dictionary, kinds: Array, fallback: int) -> int:
	var available = _buildings(context,kinds)
	return int(available[0].plot) if not available.is_empty() else fallback

func tick(delta: float, context: Dictionary) -> Dictionary:
	_notifications.clear()
	if not is_finite(delta) or delta <= 0: return {"changed":false,"notifications":[]}
	_accumulator = minf(60.0,_accumulator + delta)
	var steps = 0
	var step = clampf(float(config.get("step_seconds",1.0)),0.5,5.0)
	while _accumulator >= step and steps < 60:
		_accumulator -= step; steps += 1
		_step(step,context)
	return {"changed":steps > 0,"notifications":_notifications.duplicate(),"people":people.size()}

func _step(dt: float, context: Dictionary):
	elapsed += dt; day_time = fmod(elapsed,float(config.day_seconds))
	var day = int(elapsed / float(config.day_seconds))
	if day != _request_day: _daily_requests = 0; _request_day = day
	var plaza = int(context.get("plaza_plot",-1))
	_house_temporary_residents(context)
	var workplaces = _assign_workplaces(context)
	var factories = _factory_workplaces(context)
	var canteen = _first_plot(context,["canteen"],-1)
	var park = _first_plot(context,["park","garden"],-1)
	var unfinished: Array = []
	var finished: Array = []
	for r in context.get("reactors",[]):
		if not _plot_reachable(int(r.plot),context): continue
		if float(r.get("build_left",0)) > 0: unfinished.append(int(r.plot))
		else: finished.append(int(r.plot))
	var meal_targets: Array = []
	for p in people:
		if p.role == "academician" and float(p.hunger) >= 65.0 and canteen >= 0 and _plot_reachable(int(p.current_plot),context): meal_targets.append(p)
	var eng_index = 0
	var fraction = day_time / float(config.day_seconds)
	var on_duty = fraction >= 0.15 and fraction < 0.78
	for p in people:
		var institute = int(workplaces.get(int(p.id),-1))
		if int(p.current_plot) < 0:
			p.current_plot = plaza; p.next_plot = plaza
		p.hunger = minf(100.0,float(p.hunger) + dt * float(config.hunger_per_second))
		var home = int(p.home_plot) if int(p.home_plot) >= 0 else plaza
		if p.role == "engineer":
			if p.get("post","auto")=="workshop":
				var factory=int(factories.get(int(p.id),-1)); p.work_plot=factory
				if (float(p.hunger)>=70 or (p.activity=="eat" and float(p.hunger)>20)) and canteen>=0: _set_activity(p,"eat",canteen)
				else: _set_activity(p,"factory" if factory>=0 else "idle",factory if factory>=0 else plaza)
			elif int(p.meal_recipient) >= 0 and not person(int(p.meal_recipient)).is_empty():
				_choose_meal_destination(p,canteen)
			elif not meal_targets.is_empty() and eng_index == 0:
				p.meal_recipient = int(meal_targets[0].id); p.meal_stage = "pickup"; p.delivery_left = float(config.meal_pickup_seconds)
				_choose_meal_destination(p,canteen)
			elif (float(p.hunger) >= 70 or (p.activity == "eat" and float(p.hunger) > 20)) and canteen >= 0: _set_activity(p,"eat",canteen)
			elif not unfinished.is_empty():
				_set_activity(p,"construct",int(unfinished[eng_index % unfinished.size()])); p.work_plot = p.target_plot
			elif not finished.is_empty():
				_set_activity(p,"maintain",int(finished[eng_index % finished.size()])); p.work_plot = p.target_plot
			else: _set_activity(p,"idle",plaza)
			if p.get("post","auto")!="workshop": eng_index += 1
		elif not on_duty: _set_activity(p,"home",home)
		elif context.get("logistics",{}).has(int(p.id)):
			var task: Dictionary=context.logistics[int(p.id)]
			_set_activity(p,str(task.activity),int(task.target))
		elif (float(p.hunger) >= 65 or (p.activity == "eat" and float(p.hunger) > 20)) and p.role != "academician" and canteen >= 0: _set_activity(p,"eat",canteen)
		elif p.role == "doctor" and elapsed < float(p.next_rethink) and p.activity in ["park","stroll"]: pass
		elif p.role == "doctor" and elapsed >= float(p.next_rethink):
			p.next_rethink = elapsed + float(config.activity_rethink_seconds)
			var break_chance = float(p.traits.leisure) * (1.0 - float(p.traits.diligence)) * 0.35
			if rng.randf() < break_chance: _set_activity(p,"park" if park >= 0 else "stroll",park if park >= 0 else plaza)
			else: _set_activity(p,"research" if institute >= 0 else "idle",institute if institute >= 0 else plaza)
		else: _set_activity(p,"research" if institute >= 0 else "idle",institute if institute >= 0 else plaza)
		if p.role != "engineer": p.work_plot = institute
		_advance_travel(p,dt,context)
		if p.activity == "deliver_meal": _complete_meal_step(p,dt,context)
		if p.activity == "eat" and bool(p.arrived): p.hunger = maxf(0,float(p.hunger) - dt * float(config.meal_recovery_per_second))
		if p.activity == "park" and bool(p.arrived): p.morale = minf(100,float(p.morale) + 0.08 * dt)
		if float(p.hunger) >= 95: p.morale = maxf(20,float(p.morale) - 0.012 * dt)
	_progress_research(dt,context)
	_event_clock += dt
	if _event_clock >= float(config.events.check_seconds):
		_event_clock = 0; _request_tick(context)

func _house_temporary_residents(context: Dictionary):
	var occupancy: Dictionary = {}
	var housing: Dictionary = {}
	for p in people: occupancy[int(p.home_plot)] = int(occupancy.get(int(p.home_plot),0))+1
	for role in config.roles: housing[role] = _buildings(context,config.roles[role].housing)
	for p in people:
		if not bool(p.legacy_home): continue
		for building in housing[p.role]:
			var home = int(building.plot)
			if int(occupancy.get(home,0)) >= int(building.get("capacity",0)): continue
			p.home_plot = home; p.legacy_home = false; occupancy[home] = int(occupancy.get(home,0))+1
			_notifications.append(p.name + "已从临时住处搬进新住宅"); break

func _assign_workplaces(context: Dictionary) -> Dictionary:
	# Retain valid seats first; distribute additional staff across actual capacity.
	var remaining: Dictionary={}
	for building in _buildings(context,["institute"]): remaining[int(building.plot)]=int(building.capacity)
	var assigned: Dictionary={}
	for resident in people:
		if resident.role=="engineer": continue
		var previous=int(resident.work_plot)
		if int(remaining.get(previous,0))>0:
			assigned[int(resident.id)]=previous; remaining[previous]-=1
	for resident in people:
		if resident.role=="engineer" or assigned.has(int(resident.id)): continue
		for plot in remaining:
			if int(remaining[plot])>0:
				assigned[int(resident.id)]=plot; remaining[plot]-=1; break
	return assigned

func _plot_reachable(plot: int, context: Dictionary) -> bool:
	if plot < 0: return false
	if context.has("reachable_plots"): return plot in context.reachable_plots
	if context.has("road_links"):
		return not _route_between(int(context.get("plaza_plot",-1)),plot,context.road_links).is_empty()
	return true

func _neighbors(graph: Dictionary, plot: int) -> Array:
	return graph.get(plot,graph.get(str(plot),[]))

func _route_between(origin: int, target: int, graph: Dictionary) -> Array:
	if origin < 0 or target < 0 or (not graph.has(origin) and not graph.has(str(origin))) or (not graph.has(target) and not graph.has(str(target))): return []
	var queue: Array = [origin]
	var previous: Dictionary = {origin:-1}
	var cursor = 0
	while cursor < queue.size():
		var current = int(queue[cursor]); cursor += 1
		if current == target: break
		for neighbor in _neighbors(graph,current):
			if not previous.has(int(neighbor)): previous[int(neighbor)] = current; queue.append(int(neighbor))
	if not previous.has(target): return []
	var route: Array = []
	var step = target
	while step >= 0:
		route.push_front(step); step = int(previous[step])
	return route

func _advance_travel(p: Dictionary, dt: float, context: Dictionary):
	var target = int(p.target_plot)
	p.arrived = false
	if not context.has("road_links"):
		# Compatibility for pure simulation callers without a spatial world.
		p.current_plot = target; p.next_plot = target; p.moving = false; p.movement_progress = 0.0; p.arrived = target >= 0; return
	var graph: Dictionary = context.road_links
	var route: Array = p.travel_route
	var invalid_edge = bool(p.moving) and not int(p.next_plot) in _neighbors(graph,int(p.current_plot))
	var seconds_per_edge = maxf(0.5,float(config.travel_seconds_per_edge))
	var budget = dt
	# A changed schedule does not snap a walker back to the start of an edge.
	# Finish the current reachable segment, then reroute from that real node.
	if int(p.travel_target) != target and bool(p.moving) and not invalid_edge:
		var finish_seconds = (1.0-float(p.movement_progress))*seconds_per_edge
		if budget < finish_seconds:
			p.movement_progress = float(p.movement_progress)+budget/seconds_per_edge; return
		budget -= finish_seconds; p.current_plot = int(p.next_plot); p.movement_progress = 0.0; p.moving = false
	if int(p.travel_target) != target or invalid_edge or route.is_empty():
		route = _route_between(int(p.current_plot),target,graph)
		p.travel_route = route; p.travel_index = 0; p.travel_target = target
		p.movement_progress = 0.0; p.moving = false; p.next_plot = int(p.current_plot)
	if route.is_empty(): return
	var index = int(p.travel_index)
	if index >= route.size()-1:
		p.arrived = int(p.current_plot) == target; p.moving = false; p.next_plot = p.current_plot; p.movement_progress = 0.0; return
	# Road removals are checked at every edge, not only when the goal changes.
	while budget > 0 and index < route.size()-1:
		var next = int(route[index+1])
		if not next in _neighbors(graph,int(p.current_plot)):
			p.travel_route = []; p.moving = false; p.next_plot = p.current_plot; p.movement_progress = 0.0; return
		p.next_plot = next; p.moving = true
		var needed = (1.0-float(p.movement_progress))*seconds_per_edge
		if budget < needed:
			p.movement_progress = float(p.movement_progress)+budget/seconds_per_edge; budget = 0
		else:
			budget -= needed; p.current_plot = next; p.movement_progress = 0.0; index += 1; p.travel_index = index
	if index == route.size()-1:
		p.arrived = int(p.current_plot) == target; p.moving = false; p.next_plot = p.current_plot
	else: p.next_plot = int(route[index+1])

func _choose_meal_destination(p: Dictionary, canteen: int):
	var resident = person(int(p.meal_recipient))
	if resident.is_empty() or canteen < 0:
		p.meal_recipient = -1; p.delivery_left = 0; p.meal_stage = "none"; _set_activity(p,"idle",int(p.current_plot)); return
	var target = canteen if p.meal_stage == "pickup" else int(resident.target_plot)
	_set_activity(p,"deliver_meal",target)

func _complete_meal_step(p: Dictionary, dt: float, context: Dictionary):
	if not bool(p.arrived): return
	var resident = person(int(p.meal_recipient))
	if resident.is_empty(): return
	if p.meal_stage == "dropoff" and (bool(resident.moving) or int(p.current_plot) != int(resident.current_plot)): return
	p.delivery_left = maxf(0,float(p.delivery_left)-dt)
	if float(p.delivery_left) > 0: return
	if p.meal_stage == "pickup":
		p.meal_stage = "dropoff"; p.delivery_left = float(config.meal_handover_seconds)
		# Legacy no-topology callers retain the original 12-second delivery budget.
		if not context.has("road_links"): p.delivery_left = 10.0
	else:
		resident.hunger = maxf(0,float(resident.hunger)-65)
		p.meal_recipient = -1; p.meal_stage = "none"

func construction_factor(plot: int) -> float:
	var effort = 0.0
	for p in people:
		if p.role == "engineer" and p.activity == "construct" and int(p.target_plot) == plot and bool(p.arrived):
			effort += _efficiency(p)
	return 0.35 + 0.9 * sqrt(effort) if effort > 0 else 0.0

func worker_factor(plot: int = -1) -> float:
	if plot >= 0: return construction_factor(plot)
	var effort = 0.0
	for p in people:
		if p.role == "engineer" and p.activity in ["construct","maintain"] and bool(p.arrived): effort += _efficiency(p)
	return effort

func housing_usage(context: Dictionary) -> Array:
	var result: Array = []
	for role in config.roles:
		for building in _buildings(context,config.roles[role].housing,false):
			result.append({"plot":int(building.plot),"role":role,"used":_residents(int(building.plot)),"capacity":int(building.get("capacity",0)),"connected":bool(building.get("connected",false))})
	return result

func person_efficiency(id: int) -> float:
	var p = person(id)
	return 0.0 if p.is_empty() else _efficiency(p)

func _efficiency(p: Dictionary) -> float:
	var hunger_factor = 1.0 - maxf(0,float(p.hunger) - 60.0) / 100.0
	return (0.5 + float(p.traits.diligence) * 0.7) * (0.65 + float(p.morale) / 100.0 * 0.35) * hunger_factor * work_factor

func research_capacity() -> Dictionary:
	var active=0
	for job in research_jobs:
		if job.status!="complete" and int(config.projects[job.template_id].requires.get("academician",0))>0: active+=1
	return {"active":active,"capacity":role_count("academician")}

func quote_research(template_id: String, context: Dictionary) -> Dictionary:
	var q = {"ready":false,"cost":0,"message":"没有这个研发项目","team":[]}
	if not config.projects.has(template_id): return q
	var rule: Dictionary = config.projects[template_id]
	q.cost = int(rule.cost); q.name = rule.name; q.requires = rule.requires.duplicate(); q.seconds = rule.seconds; q.note = rule.note
	if template_id in unlocked_materials: q.message = "该配方已经完成研发"; return q
	for job in research_jobs:
		if job.template_id == template_id and job.status != "complete": q.message = "该配方正在研发"; return q
	if _buildings(context,["institute"]).is_empty(): q.message = "需要连通道路的科研院所"; return q
	var team = _pick_team(rule,[])
	if not _team_complete(team,rule):
		var requirement_text: Array[String] = []
		for role in rule.requires: requirement_text.append(str(config.roles[role].name) + " " + str(int(rule.requires[role])) + " 人")
		q.message = "需要空闲的" + "、".join(requirement_text); return q
	if not _wallet_allows(context,q.cost): q.message = "金币不足"; return q
	q.ready = true; q.team = team; q.message = "研究团队已就位；完成后解锁工艺能力，键长仍由你调整"
	return q

func _pick_team(rule: Dictionary, existing: Array) -> Array:
	var team = existing.duplicate()
	var slots: Dictionary=rule.requires.duplicate()
	for role in rule.get("optional",{}): slots[role]=int(slots.get(role,0))+int(rule.optional[role])
	for role in slots:
		var have = 0
		for id in team:
			if person(int(id)).get("role","") == role: have += 1
		var candidates: Array = []
		for p in people:
			if p.role == role and p.get("post","auto") in ["auto","research"] and int(p.research_job) < 0 and not int(p.id) in team: candidates.append(p)
		candidates.sort_custom(func(a,b): return _research_efficiency(a,rule) > _research_efficiency(b,rule))
		for p in candidates:
			if have >= int(slots[role]): break
			team.append(int(p.id)); have += 1
	return team

func _team_complete(team: Array, rule: Dictionary) -> bool:
	for role in rule.requires:
		var n = 0
		for id in team:
			if person(int(id)).get("role","") == role: n += 1
		if n < int(rule.requires[role]): return false
	return true

func _research_efficiency(p: Dictionary, rule: Dictionary) -> float:
	return _efficiency(p) * (1.25 if p.specialty == rule.specialty else 1.0)

func start_research(template_id: String, context: Dictionary) -> Dictionary:
	var q = quote_research(template_id,context)
	if not q.ready: return q
	var job = {"id":_job_serial,"template_id":template_id,"team":q.team.duplicate(),"progress":0.0,"required":float(config.projects[template_id].seconds),"status":"working"}
	_job_serial += 1; research_jobs.append(job)
	for id in job.team: person(int(id)).research_job = int(job.id)
	_assign_supervisor(job)
	q.job_id = job.id
	return q

func _assign_supervisor(job: Dictionary):
	var professor_id = -1
	for id in job.team:
		if person(int(id)).role == "professor": professor_id = int(id)
	for id in job.team:
		if person(int(id)).role == "doctor": person(int(id)).supervisor_id = professor_id

func _progress_research(dt: float, context: Dictionary):
	var institute_available = not _buildings(context,["institute"]).is_empty()
	for job in research_jobs:
		if job.status == "complete": continue
		var rule: Dictionary = config.projects[job.template_id]
		job.team = _pick_team(rule,job.team)
		for id in job.team: person(int(id)).research_job = int(job.id)
		_assign_supervisor(job)
		if not _team_complete(job.team,rule): job.status = "waiting_team"; continue
		if not institute_available: job.status = "waiting_institute"; continue
		var effort = research_rate(job)
		job.status = "working" if effort > 0 else "resting"
		job.progress = minf(float(job.required),float(job.progress) + dt * effort)
		if float(job.progress) >= float(job.required):
			job.status = "complete"
			if not job.template_id in unlocked_materials: unlocked_materials.append(job.template_id)
			for id in job.team: person(int(id)).research_job = -1
			for id in job.team: person(int(id)).supervisor_id = -1
			job.team.clear()
			_notifications.append("研发完成：" + str(rule.name) + "。新能力已解锁，原子坐标仍由你调整。")

func research_rate(job: Dictionary) -> float:
	var rule: Dictionary=config.projects[job.template_id]
	if not _team_complete(job.team,rule): return 0.0
	var leaders=0
	var mentors=0
	for id in job.team:
		var resident=person(int(id))
		if resident.get("activity","")!="research" or not resident.get("arrived",false): continue
		if resident.role=="academician": leaders+=1
		if resident.role=="professor": mentors+=1
	if leaders<int(rule.requires.get("academician",0)): return 0.0
	if mentors<int(rule.requires.get("professor",0)): return 0.0
	var effort=0.0
	var mentored=0
	for id in job.team:
		var resident=person(int(id))
		if resident.get("role","")!="doctor" or resident.activity!="research" or not resident.arrived: continue
		var bonus=1.0
		if mentored<mentors*int(config.research.professor_mentees):
			bonus+=float(config.research.professor_doctor_bonus); mentored+=1
		effort+=_research_efficiency(resident,rule)*bonus
	return effort/maxf(1,float(rule.requires.get("doctor",1)))

func _request_tick(_context: Dictionary):
	# Expiry is gentle: no morale penalty or burst of catch-up requests.
	pending_requests = pending_requests.filter(func(r): return elapsed - float(r.created_at) < float(config.events.request_lifetime_seconds))
	if elapsed < float(config.events.first_after_seconds) or _daily_requests >= int(config.events.daily_cap) or pending_requests.size() >= int(config.events.max_pending): return
	if rng.randf() >= float(config.events.chance): return
	var eligible: Array = []
	for p in people:
		if elapsed - float(p.last_request) < float(config.events.person_cooldown_seconds): continue
		var already = false
		for r in pending_requests:
			if int(r.person_id) == int(p.id): already = true
		if not already: eligible.append(p)
	if eligible.is_empty(): return
	var p: Dictionary = eligible[rng.randi_range(0,eligible.size()-1)]
	var weighted = []
	var total = 0.0
	for kind in config.events.types:
		var weight = float(config.events.types[kind].weight)
		if kind == "family_visit": weight *= 0.5 + float(p.traits.sociability)
		if kind == "housing_upgrade": weight *= 0.5 + float(p.traits.diligence)
		total += weight; weighted.append([kind,total])
	var draw = rng.randf() * total
	var selected = str(weighted[-1][0])
	for option in weighted:
		if draw <= float(option[1]): selected = str(option[0]); break
	var data: Dictionary = config.events.types[selected]
	pending_requests.append({"id":_request_serial,"person_id":int(p.id),"kind":selected,"title":p.name + " · " + str(data.title),"detail":str(data.detail),"created_at":elapsed})
	_request_serial += 1; _daily_requests += 1; p.last_request = elapsed
	_notifications.append(p.name + "提出了一个生活请求")

func resolve_request(id: int, choice: String, context: Dictionary) -> Dictionary:
	var q = {"ready":false,"cost":0,"reward":0,"message":"这条请求已不存在"}
	for i in range(pending_requests.size()):
		var r: Dictionary = pending_requests[i]
		if int(r.id) != id: continue
		var p = person(int(r.person_id))
		if p.is_empty(): return q
		if choice in ["decline","later"]:
			pending_requests.remove_at(i); q.ready = true; q.message = "已沟通暂缓安排，不扣金币与心情"; return q
		if choice != "accept": q.message = "请选择安排或暂缓"; return q
		var rule: Dictionary = config.events.types[r.kind]
		q.cost = int(rule.cost); q.reward = int(rule.morale)
		var new_home = -1
		if r.kind == "move_request":
			new_home = _free_home(p.role,context,int(p.home_plot))
			if new_home < 0: q.message = "另一栋同类住宅还没有连路的空床位"; return q
		if not _wallet_allows(context,q.cost): q.message = "金币不足"; return q
		if r.kind == "move_request": p.home_plot = new_home; p.legacy_home = false
		elif r.kind == "housing_upgrade": p.room_comfort = int(p.room_comfort) + 1
		elif r.kind == "family_visit": p.family_visits = int(p.family_visits) + 1
		p.morale = minf(100,float(p.morale) + q.reward)
		pending_requests.remove_at(i); q.ready = true; q.message = "已满足" + p.name + "的请求，心情提升"; return q
	return q

func serialize() -> Dictionary:
	return {"version":3,"people":people.duplicate(true),"research_jobs":research_jobs.duplicate(true),"unlocked_materials":unlocked_materials.duplicate(),"pending_requests":pending_requests.duplicate(true),"day_time":day_time,"elapsed":elapsed,"accumulator":_accumulator,"event_clock":_event_clock,"daily_requests":_daily_requests,"request_day":_request_day,"serial":_serial,"job_serial":_job_serial,"request_serial":_request_serial}

func _number(value, lo: float, hi: float, integer: bool = false) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= lo and float(value) <= hi and (not integer or float(value) == floor(float(value)))

func restore(data: Dictionary) -> bool:
	# Validate the complete snapshot first. A malformed file cannot partially
	# replace the population, unlock a material, or create duplicate job workers.
	if not _number(data.get("version"),1,3,true): return false
	data = data.duplicate(true)
	for key in ["people","research_jobs","unlocked_materials","pending_requests"]:
		if not data.get(key) is Array: return false
	if data.people.size() > int(config.max_people) or data.research_jobs.size() > config.projects.size() or data.pending_requests.size() > int(config.events.max_pending): return false
	for key in ["elapsed","day_time","accumulator","event_clock"]:
		if not _number(data.get(key),0,1.0e10): return false
	if float(data.day_time) >= float(config.day_seconds) or absf(fmod(float(data.elapsed),float(config.day_seconds)) - float(data.day_time)) > 0.01: return false
	for key in ["serial","job_serial","request_serial"]:
		if not _number(data.get(key),1,1.0e9,true): return false
	if not _number(data.get("daily_requests"),0,int(config.events.daily_cap),true) or not _number(data.get("request_day"),0,1.0e9,true): return false
	if int(data.request_day) != int(float(data.elapsed) / float(config.day_seconds)): return false
	var ids: Dictionary = {}
	for p in data.people:
		if not p is Dictionary or not config.roles.has(p.get("role","")) or not p.get("name") is String or str(p.name).length() > 80: return false
		if int(data.version)<3: p.post="auto"
		if p.get("post") not in posts_for(str(p.role)): return false
		if p.post not in ["auto","research"] and int(p.get("research_job",-1))>=0: return false
		if not _number(p.get("id"),1,float(data.serial)-1,true) or ids.has(int(p.id)): return false
		ids[int(p.id)] = p
		if not p.get("traits") is Dictionary: return false
		for trait_name in ["diligence","leisure","sociability"]:
			if not _number(p.traits.get(trait_name),0,1): return false
		if not p.get("specialty") in config.roles[p.role].specialties: return false
		for key in ["hunger","morale"]:
			if not _number(p.get(key),0,100): return false
		for key in ["home_plot","work_plot","target_plot","research_job","meal_recipient","supervisor_id"]:
			if not _number(p.get(key),-1,1000000,true): return false
		if int(data.version) == 1:
			p.current_plot = int(p.home_plot); p.next_plot = int(p.home_plot); p.movement_progress = 0.0
			p.moving = false; p.arrived = false; p.travel_target = -1; p.travel_route = []; p.travel_index = 0
			p.meal_stage = "pickup" if int(p.meal_recipient) >= 0 else "none"
			if int(p.meal_recipient) >= 0: p.delivery_left = float(config.meal_pickup_seconds)
		if not _number(p.get("delivery_left"),0,maxf(10.0,maxf(float(config.meal_pickup_seconds),float(config.meal_handover_seconds)))): return false
		if p.get("meal_stage") not in ["none","pickup","dropoff"]: return false
		for key in ["current_plot","next_plot","travel_target"]:
			if not _number(p.get(key),-1,1000000,true): return false
		if not _number(p.get("movement_progress"),0,0.99999999) or not p.get("moving") is bool or not p.get("arrived") is bool: return false
		if not p.get("travel_route") is Array or p.travel_route.size() > 1024 or not _number(p.get("travel_index"),0,maxi(0,p.travel_route.size()-1),true): return false
		var travel_seen: Dictionary = {}
		for plot in p.travel_route:
			if not _number(plot,0,1000000,true) or travel_seen.has(int(plot)): return false
			travel_seen[int(plot)] = true
		if bool(p.arrived) and (bool(p.moving) or int(p.current_plot) != int(p.target_plot)): return false
		if not p.travel_route.is_empty():
			if int(p.travel_route[int(p.travel_index)]) != int(p.current_plot) or int(p.travel_route[-1]) != int(p.travel_target): return false
		if bool(p.moving):
			if p.travel_route.is_empty() or int(p.travel_index) >= p.travel_route.size()-1 or int(p.next_plot) != int(p.travel_route[int(p.travel_index)+1]): return false
		if not p.get("legacy_home") is bool or not ACTIVITY_NAMES.has(p.get("activity","")): return false
		if not _number(p.get("last_request"),-float(config.events.person_cooldown_seconds),float(data.elapsed)) or not _number(p.get("next_rethink"),0,float(data.elapsed)+60): return false
		for key in ["room_comfort","family_visits"]:
			if not _number(p.get(key),0,1.0e8,true): return false
	var job_ids: Dictionary = {}
	var assigned: Dictionary = {}
	var completed: Array = []
	var projects_seen: Array = []
	for job in data.research_jobs:
		if not job is Dictionary or not config.projects.has(job.get("template_id","")) or job.template_id in projects_seen: return false
		projects_seen.append(job.template_id)
		if not _number(job.get("id"),1,float(data.job_serial)-1,true) or job_ids.has(int(job.id)): return false
		job_ids[int(job.id)] = job
		if not job.get("team") is Array or job.team.size() > data.people.size() or job.get("status") not in ["working","resting","waiting_team","waiting_institute","complete"]: return false
		var rule: Dictionary = config.projects[job.template_id]
		if not _number(job.get("required"),float(rule.seconds),float(rule.seconds)) or not _number(job.get("progress"),0,float(job.required)): return false
		var members: Array = []
		var roles: Dictionary = {}
		for id in job.team:
			if not _number(id,1,float(data.serial)-1,true) or not ids.has(int(id)) or int(id) in members: return false
			members.append(int(id))
			var role: String = ids[int(id)].role
			if not rule.requires.has(role) and not rule.get("optional",{}).has(role): return false
			roles[role] = int(roles.get(role,0)) + 1
			if int(roles[role]) > int(rule.requires.get(role,0))+int(rule.get("optional",{}).get(role,0)): return false
			if job.status != "complete":
				if assigned.has(int(id)) or int(ids[int(id)].research_job) != int(job.id): return false
				assigned[int(id)] = int(job.id)
		if job.status == "complete":
			if float(job.progress) != float(job.required): return false
			completed.append(job.template_id)
	for p in data.people:
		if int(p.research_job) >= 0 and assigned.get(int(p.id),-1) != int(p.research_job): return false
	var seen_unlocked: Array = []
	for id in data.unlocked_materials:
		if not id is String or not id in completed or id in seen_unlocked: return false
		seen_unlocked.append(id)
	if seen_unlocked.size() != completed.size(): return false
	var request_ids: Array = []
	var requesting_people: Array = []
	for r in data.pending_requests:
		if not r is Dictionary or not _number(r.get("id"),1,float(data.request_serial)-1,true) or int(r.id) in request_ids: return false
		request_ids.append(int(r.id))
		if not _number(r.get("person_id"),1,float(data.serial)-1,true) or not ids.has(int(r.person_id)) or int(r.person_id) in requesting_people: return false
		requesting_people.append(int(r.person_id))
		if not config.events.types.has(r.get("kind","")) or not r.get("title") is String or not r.get("detail") is String or str(r.title).length() > 200 or str(r.detail).length() > 500: return false
		if not _number(r.get("created_at"),0,float(data.elapsed)): return false
	people = data.people.duplicate(true); research_jobs = data.research_jobs.duplicate(true); unlocked_materials = data.unlocked_materials.duplicate(); pending_requests = data.pending_requests.duplicate(true)
	for p in people:
		for key in ["id","home_plot","work_plot","target_plot","research_job","meal_recipient","supervisor_id","room_comfort","family_visits","current_plot","next_plot","travel_target","travel_index"]: p[key] = int(p[key])
		for i in range(p.travel_route.size()): p.travel_route[i] = int(p.travel_route[i])
		p.activity_label = ACTIVITY_NAMES[p.activity]
	for job in research_jobs:
		job.id = int(job.id)
		for i in range(job.team.size()): job.team[i] = int(job.team[i])
	for request in pending_requests:
		request.id = int(request.id); request.person_id = int(request.person_id)
	elapsed = float(data.elapsed); day_time = float(data.day_time); _accumulator = minf(60,float(data.accumulator)); _event_clock = minf(float(config.events.check_seconds),float(data.event_clock))
	_daily_requests = int(data.daily_requests); _request_day = int(data.request_day); _serial = int(data.serial); _job_serial = int(data.job_serial); _request_serial = int(data.request_serial)
	return true
