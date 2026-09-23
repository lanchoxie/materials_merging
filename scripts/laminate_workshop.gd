extends RefCounted
## Paid finite industrial feed, manufacturing, and property-based contracts.
var model=preload("res://scripts/laminate_model.gd").new()
var feed={"Cu":0.0,"Al":0.0}
var purchased={"Cu":0,"Al":0}
var consumed={"Cu":0.0,"Al":0.0}
var made: Dictionary={}
var stock: Dictionary={}
var installed: Dictionary={}
var sold: Dictionary={}
var job: Dictionary={}
var serial=1
var cooldown=0.0
var deliveries=0
var premiums=0
func unlocked(state) -> bool: return model.rules.project in state.campus.unlocked_materials
func count(id: String) -> int: return int(stock.get(id,0))
func total() -> int:
	var result=0
	for n in stock.values(): result+=int(n)
	return result
func buy(state,element: String) -> String:
	if not unlocked(state): return "先在科研院所完成分层构件方法研发"
	if not feed.has(element): return "仅采购标准铜层或铝层供料"
	var r=model.rules.manufacturing; var reserved=float(job.get("feed_kg",{}).get(element,0))
	if feed[element]+reserved+float(r.pack_kg)>float(r.max_feed_kg)+1e-9: return "标准供料仓已满（含在制预留）"
	if state.coins<float(r.feed_price[element]): return "金币不足"
	state.coins-=float(r.feed_price[element]); feed[element]+=float(r.pack_kg); purchased[element]+=1
	return "购入%d g标准%s层料；不消耗原子展示库存" % [r.pack_kg*1000,element]
func start(state,proof: Dictionary) -> String:
	if not unlocked(state) or not model.valid(proof): return "需要已解锁的分层构件模型方案"
	if not job.is_empty(): return "层压台正在加工，请等待或取消"
	if total()>=int(model.rules.manufacturing.max_products): return "层芯成品仓已满"
	for key in feed:
		if feed[key]+1e-12<proof.feed_kg[key]: return "标准%s层料不足" % key
	if state.coins<float(model.rules.manufacturing.fee): return "金币不足，装配工费%d" % model.rules.manufacturing.fee
	for key in feed: feed[key]=maxf(0,feed[key]-float(proof.feed_kg[key]))
	state.coins-=float(model.rules.manufacturing.fee)
	job={"id":serial,"design_id":proof.id,"feed_kg":proof.feed_kg.duplicate(true),"duration":float(model.rules.manufacturing.seconds),"left":float(model.rules.manufacturing.seconds),"fee":int(model.rules.manufacturing.fee)}; serial+=1
	return "分层装配开始：本岛工程师到车间后推进，暂停不会丢失预留层料"
func cancel() -> String:
	if job.is_empty(): return "层压台空闲"
	for key in feed: feed[key]+=float(job.feed_kg[key])
	job.clear(); return "已退还预留铜铝层料；工费不退"
func tick(dt: float,effort: float) -> void:
	if not is_finite(dt) or dt<=0 or dt>60: return
	cooldown=maxf(0,cooldown-dt)
	if job.is_empty() or not is_finite(effort) or effort<=0: return
	job.left=maxf(0,float(job.left)-dt*clampf(effort,0,3))
	if job.left>0: return
	var id=str(job.design_id)
	for key in feed: consumed[key]+=float(job.feed_kg[key])
	made[id]=int(made.get(id,0))+1; stock[id]=count(id)+1; job.clear()
func take(id: String,destination: String) -> bool:
	if count(id)<1 or destination not in ["installed","sold"]: return false
	stock[id]=count(id)-1
	var ledger=installed if destination=="installed" else sold
	ledger[id]=int(ledger.get(id,0))+1; return true
func quote(proof: Dictionary,order_id: String,terms: Dictionary={}) -> Dictionary:
	var q={"ready":false,"premium":false,"payment":0,"reason":"需要已制成的模型构件","ratio":0.0}
	if not model.rules.orders.has(order_id) or not model.valid(proof): return q
	var r=model.rules.orders[order_id] if terms.is_empty() else terms; var design=proof.result
	q.ratio=minf(1,float(design.conductance_W_K)/float(r.target_G_W_K))
	if design.mass_kg>float(r.max_mass_kg)+1e-9 or design.area_m2>float(r.max_area_m2)+1e-12: q.reason="超过买家的重量或截面限制"; return q
	if q.ratio<float(r.minimum_ratio): q.reason="模型热导未达到最低用途要求"; return q
	q.premium=q.ratio>=float(r.premium_ratio); q.payment=int(floor(float(r.reward)*q.ratio))
	if cooldown>0: q.reason="买家采购冷却中"; return q
	if count(proof.id)<1: return q
	q.ready=true; q.reason="精品：模型符合合同" if q.premium else "可交付接近目标的构件"; return q
func deliver(state,proof: Dictionary,order_id: String,terms: Dictionary={}) -> String:
	var q=quote(proof,order_id,terms)
	var contract=model.rules.orders.get(order_id,{}) if terms.is_empty() else terms
	if not q.ready: return q.reason
	if not take(str(proof.id),"sold"): return "成品不足"
	state.coins+=q.payment; deliveries+=1; cooldown=float(model.rules.order_cooldown_seconds)
	if q.premium: state.upgrades+=int(contract.premium_upgrades); premiums+=1
	return "模型合同交付：%d金币%s" % [q.payment,("，额外%d枚升级晶石" % contract.premium_upgrades) if q.premium else ""]
func serialize() -> Dictionary:
	return {"version":1,"feed":feed.duplicate(),"purchased":purchased.duplicate(),"consumed":consumed.duplicate(),"made":made.duplicate(),"stock":stock.duplicate(),"installed":installed.duplicate(),"sold":sold.duplicate(),"job":job.duplicate(true),"serial":serial,"cooldown":cooldown,"deliveries":deliveries,"premiums":premiums}
func restore(data,designs: Dictionary) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	var num=preload("res://scripts/player_fixture.gd").new(); var count_ok=preload("res://scripts/island_storage.gd").count_ok
	for key in ["serial","deliveries","premiums"]:
		if not count_ok.call(data.get(key)): return false
	if data.serial<1 or data.premiums>data.deliveries or not num.number(data.get("cooldown"),0,model.rules.order_cooldown_seconds): return false
	for key in ["feed","purchased","consumed"]:
		if not data.get(key) is Dictionary or data[key].size()!=2: return false
	for key in ["made","stock","installed","sold"]:
		if not data.get(key) is Dictionary or data[key].size()>96: return false
		for id in data[key]:
			if not designs.has(id) or not model.valid(designs[id]) or not count_ok.call(data[key][id]): return false
	var sums={"Cu":0.0,"Al":0.0}; var products=0; var sales=0; var made_total=0
	for id in designs:
		var n=int(data.made.get(id,0)); products+=int(data.stock.get(id,0)); sales+=int(data.sold.get(id,0)); made_total+=n
		if n!=int(data.stock.get(id,0))+int(data.installed.get(id,0))+int(data.sold.get(id,0)): return false
		if n>0:
			for key in sums: sums[key]+=n*float(designs[id].feed_kg[key])
	if products>int(model.rules.manufacturing.max_products) or sales!=data.deliveries or made_total>=data.serial: return false
	if not data.get("job") is Dictionary: return false
	if not data.job.is_empty():
		var j=data.job
		if not count_ok.call(j.get("id")) or j.id<1 or j.id>=data.serial or not designs.has(j.get("design_id")) or not model.valid(designs[j.design_id]) or products>=int(model.rules.manufacturing.max_products): return false
		if not num.electrical._same(j.get("feed_kg"),designs[j.design_id].feed_kg) or not num.number(j.get("duration"),1,86400) or not num.number(j.get("left"),0.00000001,j.duration) or not count_ok.call(j.get("fee")): return false
	for key in sums:
		if not count_ok.call(data.purchased.get(key)) or not num.number(data.feed.get(key),0,model.rules.manufacturing.max_feed_kg) or not num.number(data.consumed.get(key),0,1e6): return false
		var reserved=float(data.job.get("feed_kg",{}).get(key,0))
		if absf(sums[key]-float(data.consumed[key]))>1e-8 or absf(float(data.purchased[key])*float(model.rules.manufacturing.pack_kg)-data.feed[key]-data.consumed[key]-reserved)>1e-8: return false
		if data.feed[key]+reserved>float(model.rules.manufacturing.max_feed_kg)+1e-9: return false
	for key in ["feed","purchased","consumed","made","stock","installed","sold","job"]: set(key,data[key].duplicate(true))
	serial=int(data.serial); cooldown=float(data.cooldown); deliveries=int(data.deliveries); premiums=int(data.premiums); return true
