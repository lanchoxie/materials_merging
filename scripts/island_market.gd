extends RefCounted
## Bounded visitor roster; stock and money are committed atomically by LabState.
var visitors: Array=[]
var clock: float=0
var serial: int=0
var quote_rules: Dictionary={}

func spawn(economy, templates: Dictionary, rules: Dictionary, special_requests: Array=[]) -> void:
	if visitors.size()>=int(rules.max_active) or serial>=1000000: return
	var request: Dictionary=economy.make_order(serial,templates)
	var cadence=maxi(1,int(rules.get("material_every",3)))
	if not special_requests.is_empty() and serial%cadence==int(rules.get("material_slot",1)):
		request=special_requests[(serial/cadence)%special_requests.size()].duplicate(true)
	elif serial%4==1:
		request["property"]="oxygen_molecule"
		request.name="清泉材料工作室"
		request.story="收集含氧的分子样品。按已知参考与几何匹配度验收，尚不评定净水效果。"
		request.target_quality=float(rules.get("property_target_quality",0.95))
	elif serial%4==3:
		request["property"]="exhibition"
		request.name="浮岛创意展"
		request.story="收集自由搭建的展示样品；不要求真实材料性质。"
	serial+=1
	var occupied=[]
	for visitor in visitors: occupied.append(int(visitor.slot))
	var slot=0
	while slot in occupied: slot+=1
	visitors.append({"id":serial,"slot":slot,"phase":"arriving","age":0.0,"fulfilled":false,"order":request})
	clock=float(rules.arrival_interval)

func tick(dt: float, economy, templates: Dictionary, rules: Dictionary, special_requests: Array=[]) -> void:
	for v in visitors:
		v.age=float(v.age)+dt
		if v.phase=="arriving" and v.age>=float(rules.arrival_seconds): v.phase="visiting"; v.age=0.0
		elif v.phase=="visiting" and v.age>=float(rules.stay_seconds): leave(int(v.id))
	visitors=visitors.filter(func(v): return v.phase!="leaving" or float(v.age)<float(rules.departure_seconds))
	clock=maxf(0,clock-dt)
	if clock<=0 and visitors.size()<int(rules.max_active): spawn(economy,templates,rules,special_requests)

func visitor(id: int) -> Dictionary:
	for v in visitors:
		if int(v.id)==id: return v
	return {}

func leave(id: int,fulfilled: bool=false) -> void:
	var v=visitor(id)
	if not v.is_empty() and v.phase!="leaving": v.phase="leaving"; v.age=0.0; v.fulfilled=fulfilled

func quote(v: Dictionary, batch: Dictionary, economy) -> Dictionary:
	var order: Dictionary=v.order
	var q: Dictionary=economy.quote(str(batch.reference),float(batch.quality),int(batch.quantity),false,order)
	q["batch_id"]=str(batch.id)
	q["known"]=not str(batch.reference).is_empty()
	q["name"]=str(batch.name)
	q["quantity"]=int(batch.quantity)
	q["quality"]=float(batch.quality)
	var requirement=str(order.get("property",""))
	if requirement=="oxygen_molecule":
		q.matching=q.known and "O" in batch.work.atoms and not batch.work.get("periodic",false)
		q.ready=int(batch.quantity)>=int(order.quantity) and q.known
		q.difference=absf(float(batch.quality)-float(order.target_quality))
		q.premium=q.matching and q.difference<=float(order.tolerance)
		var rewards: Dictionary=quote_rules.get("property_rewards",{"premium":90,"matching":60,"substitute":20})
		q.payment=int(rewards.premium) if q.premium else (int(rewards.matching) if q.matching else int(rewards.substitute))
	elif requirement=="exhibition":
		q.ready=int(batch.quantity)>=int(order.quantity)
		q.matching=true; q.premium=false; q.payment=int(quote_rules.get("exhibition_reward",18))
	else:
		q.ready=bool(q.ready) and q.known
		if not q.known: q.payment=0; q.premium=false
	q.catalysts=1 if q.premium else 0
	q.ready=bool(q.ready) and v.phase=="visiting"
	q["score"]=economy.ranking_score(q)
	q["reason"]=economy.ranking_reason(q)
	return q

func candidates(id: int, batches: Array, economy) -> Array:
	var v=visitor(id)
	if v.is_empty(): return []
	var rows=[]
	for batch in batches: rows.append(quote(v,batch,economy))
	rows.sort_custom(func(a,b): return float(a.score)>float(b.score) if a.score!=b.score else str(a.batch_id)<str(b.batch_id))
	return rows

func request_text(v: Dictionary, templates: Dictionary) -> String:
	var order: Dictionary=v.order
	if order.get("kind","")!="" and order.get("kind")!="specimen": return str(order.get("short_text","性质构件"))+" ×1"
	match str(order.get("property","")):
		"oxygen_molecule": return "含氧分子 ×%d" % int(order.quantity)
		"exhibition": return "展示样品 ×%d" % int(order.quantity)
	return "%s ×%d" % [templates.get(order.get("template",""),{}).get("formula","参考样品"),int(order.quantity)]

func serialize() -> Dictionary:
	return {"version":2,"visitors":visitors.duplicate(true),"clock":clock,"serial":serial}

func restore(data, rules: Dictionary, templates: Dictionary, special_validator: Callable=Callable()) -> bool:
	if not data is Dictionary or not data.get("visitors") is Array or data.visitors.size()>int(rules.max_active): return false
	if data.get("version",1)!=1 and data.get("version",1)!=2: return false
	if not _number(data.get("serial"),0,1000000) or not _number(data.get("clock"),0,float(rules.arrival_interval)): return false
	if floor(float(data.serial))!=float(data.serial): return false
	var ids=[]; var slots=[]
	for v in data.visitors:
		if not v is Dictionary or not _number(v.get("id"),1,float(data.serial)) or v.id in ids: return false
		if not _number(v.get("slot"),0,int(rules.max_active)-1) or v.slot in slots: return false
		if float(v.id)!=floor(float(v.id)) or float(v.slot)!=floor(float(v.slot)): return false
		if v.get("phase") not in ["arriving","visiting","leaving"] or not _number(v.get("age"),0,10000): return false
		if not v.get("fulfilled",false) is bool or (v.get("fulfilled",false) and v.phase!="leaving"): return false
		if not v.get("order") is Dictionary: return false
		var o: Dictionary=v.order
		if o.get("kind","specimen")!="specimen":
			if data.get("version",1)<2 or not special_validator.is_valid() or not special_validator.call(o): return false
			ids.append(v.id); slots.append(v.slot); continue
		if not templates.has(o.get("template","")) or not o.get("name") is String or not o.get("story") is String: return false
		for key in ["target_quality","tolerance"]:
			if not _number(o.get(key),0,1): return false
		if not _number(o.get("quantity"),1,100) or not _number(o.get("reward"),0,100000): return false
		if float(o.quantity)!=floor(float(o.quantity)) or float(o.reward)!=floor(float(o.reward)): return false
		if str(o.get("property","")) not in ["","oxygen_molecule","exhibition"]: return false
		ids.append(v.id); slots.append(v.slot)
	visitors=data.visitors.duplicate(true); clock=float(data.clock); serial=int(data.serial)
	for v in visitors:
		v.id=int(v.id); v.slot=int(v.slot); v.fulfilled=bool(v.get("fulfilled",false)); v.order.quantity=int(v.order.quantity)
		if v.order.has("reward"): v.order.reward=int(v.order.reward)
	return true

func _number(value, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value>=low and value<=high
