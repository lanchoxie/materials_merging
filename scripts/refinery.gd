extends RefCounted
## v0.28 refinery: planet minerals become element units, and island extractors trickle the common ones.
## Replaces the coin element shop. Chemistry and sources are in data/refinery.json; times, yields and caps are game values.
const Geology=preload("res://scripts/planet_geology.gd")
const MAX_STOCK=9999
static var _rules: Dictionary={}
var level=1
var jobs: Array=[]           # queue of {"process":id,"left":seconds}; only the first one runs
var progress: Dictionary={}  # extractor id -> accumulated seconds
var made: Dictionary={}      # element -> units produced here (stats and guidance)
var power_gain=0.0          # v0.30: extra speed from fabricator solar panels (set by LabState.sync_gear, not saved)

static func rules() -> Dictionary:
	if _rules.is_empty(): _rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/refinery.json"))
	return _rules

func process(id: String) -> Dictionary:
	return rules().processes.get(id,{})

func speed() -> float:
	return (1.0+float(rules().speed_per_level)*(level-1))*(1.0+power_gain)

func extractor_cap() -> int:
	return int(rules().extractor_cap)+int(rules().extractor_cap_per_level)*(level-1)

func queue_limit() -> int:
	return int(rules().queue_base)+level-1

func upgrade_cost() -> int:
	return int(rules().upgrade_costs[level-1]) if level<int(rules().max_level) else -1

func seconds(id: String) -> float:
	return float(process(id).get("seconds",0))/speed()

## Where each element can come from, for guidance text: extractors first, then minerals.
func sources_of(symbol: String) -> Array:
	var result=[]
	for id in rules().extractors:
		if rules().extractors[id].outputs.has(symbol): result.append({"kind":"extractor","id":id,"name":rules().extractors[id].name})
	for id in rules().processes:
		var p: Dictionary=rules().processes[id]
		if p.outputs.has(symbol): result.append({"kind":"process","id":id,"name":p.name,"minerals":p.inputs.keys()})
	return result

## One short Chinese line: how to get more of `symbol`.
func how_to_get(symbol: String) -> String:
	var parts=[]
	for s in sources_of(symbol):
		if s.kind=="extractor": parts.append("%s自动产出" % s.name)
		else:
			var names=[]
			for m in s.minerals: names.append(str(Geology.info(m).get("name",m)))
			parts.append("星球挖%s → 精炼厂「%s」" % ["＋".join(names),s.name])
	return "；".join(parts) if not parts.is_empty() else "暂无来源"

func mineral_stock(state) -> Dictionary:
	return state.planet.v2.nature.minerals

func quote(state,id: String) -> Dictionary:
	var p=process(id); var q={"ready":false,"message":"","missing":{}}
	if p.is_empty(): q.message="没有这种精炼工艺"; return q
	var stock=mineral_stock(state)
	for m in p.inputs:
		var lack=int(p.inputs[m])-int(stock.get(m,0))
		if lack>0: q.missing[m]=lack
	if not q.missing.is_empty():
		var m=str(q.missing.keys()[0]); var spec: Dictionary=Geology.info(m)
		q.message="缺少%s ×%d：去星球地下采掘（%s）" % [spec.get("name",m),q.missing[m],spec.get("layer","")]
		return q
	if jobs.size()>=queue_limit(): q.message="精炼队列已满（%d个），等当前批次完成" % queue_limit(); return q
	for symbol in p.outputs:
		if int(state.element_inventory.get(symbol,0))+int(p.outputs[symbol])>MAX_STOCK: q.message="%s库存已满" % symbol; return q
	q.ready=true; q.message="投入矿物，%d秒后得到 %s" % [ceili(seconds(id)),format(p.outputs)]
	return q

func start(state,id: String) -> String:
	var q=quote(state,id)
	if not q.ready: return q.message
	var p=process(id); var stock=mineral_stock(state)
	for m in p.inputs: stock[m]=int(stock[m])-int(p.inputs[m])
	jobs.append({"process":id,"left":float(p.seconds)})
	return "%s开始：%s" % [p.name,q.message]

## Advances the queue and extractors; returns finished-batch notices.
func tick(state,delta: float) -> Array:
	var notices=[]
	var work=delta*speed()
	while work>0.0 and not jobs.is_empty():
		var job: Dictionary=jobs[0]
		var used=minf(work,float(job.left)); job.left=float(job.left)-used; work-=used
		if float(job.left)>0.0: break
		var p=process(str(job.process))
		for symbol in p.outputs: _add(state,symbol,int(p.outputs[symbol]))
		notices.append("精炼完成：%s → %s" % [p.name,format(p.outputs)])
		jobs.pop_front()
	var cap=extractor_cap()
	for id in rules().extractors:
		var ex: Dictionary=rules().extractors[id]
		var every=float(ex.every)
		var full=true
		for symbol in ex.outputs:
			if int(state.element_inventory.get(symbol,0))<cap: full=false
		if full: progress[id]=0.0; continue
		progress[id]=float(progress.get(id,0.0))+delta*speed()
		while float(progress[id])>=every:
			progress[id]=float(progress[id])-every
			for symbol in ex.outputs:
				var room=cap-int(state.element_inventory.get(symbol,0))
				if room>0: _add(state,symbol,mini(room,int(ex.outputs[symbol])))
	return notices

func _add(state,symbol: String,count: int) -> void:
	state.element_inventory[symbol]=mini(MAX_STOCK,int(state.element_inventory.get(symbol,0))+count)
	made[symbol]=int(made.get(symbol,0))+count

func upgrade(state) -> String:
	var cost=upgrade_cost()
	if cost<0: return "精炼厂已是最高等级"
	if state.coins<cost: return "升级需要%d金币" % cost
	state.coins-=cost; level+=1
	return "精炼厂升到%d级：速度×%.2f，自动提取上限%d，队列%d" % [level,speed(),extractor_cap(),queue_limit()]

static func format(outputs: Dictionary) -> String:
	var parts=[]
	for symbol in outputs: parts.append("%s×%d" % [symbol,int(outputs[symbol])])
	return " ".join(parts)

func serialize() -> Dictionary:
	return {"version":1,"level":level,"jobs":jobs.duplicate(true),"progress":progress.duplicate(),"made":made.duplicate()}

func restore(data,elements: Dictionary) -> bool:
	if not data is Dictionary or int(data.get("version",0))!=1: return false
	var lv=data.get("level"); if not (lv is float or lv is int) or int(lv)<1 or int(lv)>int(rules().max_level): return false
	if not data.get("jobs") is Array or data.jobs.size()>int(rules().queue_base)+int(rules().max_level): return false
	for job in data.jobs:
		if not job is Dictionary or not rules().processes.has(str(job.get("process",""))): return false
		var left=job.get("left"); if not (left is float or left is int) or float(left)<0.0 or float(left)>float(process(str(job.process)).seconds): return false
	if not data.get("progress") is Dictionary or not data.get("made") is Dictionary: return false
	for id in data.progress:
		var v=data.progress[id]
		if not rules().extractors.has(id) or not (v is float or v is int) or float(v)<0.0 or float(v)>float(rules().extractors[id].every): return false
	for symbol in data.made:
		var v=data.made[symbol]
		if not elements.has(symbol) or not (v is float or v is int) or float(v)<0.0 or float(v)>1e9: return false
	level=int(lv); jobs=data.jobs.duplicate(true); progress=data.progress.duplicate(); made=data.made.duplicate()
	for job in jobs: job.left=float(job.left)
	return true
