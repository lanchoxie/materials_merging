extends RefCounted
## A projection of existing reactor/element/logistics ledgers, never a product generator.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/organic_materials.json"))

func reference_ids() -> Array:
	return rules.references.keys()

func draft(state,reference: String) -> Dictionary:
	if not rules.references.has(reference): return {}
	return state.sandbox_from_baseline(reference)

func stock(state,reference: String) -> int:
	var total=0
	for batch in state.planet.sample_candidates(state,reference): total+=int(batch.quantity)
	return total

func installation_reference(state,r: Dictionary) -> String:
	var payload: Dictionary=r.get("installation",{}).get("payload",{})
	if payload.get("kind")=="template": return str(payload.get("template",""))
	if payload.get("kind")=="sandbox": return str(state.sandbox_reference(payload.work).get("reference_id",""))
	return ""

func logistics(state,index: int) -> String:
	var r=state.reactors[index]; var context=state.campus_context()
	if int(r.plot) not in context.reachable_plots: return "反应釜未连通：用小路连接迎客广场"
	var doctors=0; var available=0
	for person in state.campus.people:
		if person.role!="doctor": continue
		doctors+=1
		if person.get("post","auto") in ["auto","logistics"] and int(person.research_job)<0: available+=1
	if doctors==0: return "需要装炉博士：先建博士公寓与科研院所，再招募博士"
	if available==0: return "博士都在其他岗位：安排一位博士负责装炉与收集"
	for id in state.logistics.tasks:
		var task=state.logistics.tasks[id]
		if task.get("activity")=="install" and int(task.get("reactor",-1))==index:
			var person=state.campus.person(int(id))
			if person.get("arrived",false) and person.get("activity")=="install": return "博士已到炉旁，正在安装新分子"
			return "博士正在前往反应釜；走路时间不算装炉进度"
	return "等待博士完成当前行程，再到炉旁装入新分子"

func status(state,index: int,reference: String) -> Dictionary:
	var result={"valid":false,"phase":"choose","message":"请选择一台反应釜","reference":reference,"stock":stock(state,reference),"missing":{},"element_cost":0,"can_buy":false,"start_ready":false,"pending":0,"progress":0.0,"eta":0,"fee":0,"required":{},"quality":0.0}
	if not rules.references.has(reference) or index<0 or index>=state.reactors.size(): return result
	var r=state.reactors[index]; result.valid=true; result.fee=state.edit_cost(r)
	if float(r.build_left)>0:
		result.phase="building"; result.message="工程师正在建造反应釜，完成后再装入分子"; return result
	if not r.get("installation",{}).is_empty():
		result.phase="installing" if installation_reference(state,r)==reference else "busy"
		result.message=logistics(state,index) if result.phase=="installing" else "这台炉已有其他装炉任务；先完成或取消它"
		result.progress=1.0-float(r.installation.remaining)/float(state.island_rules.logistics.installation_seconds)
		return result
	if state.reference_id(r)==reference:
		result.phase="ready" if int(r.pending)>0 else "producing"; result.pending=int(r.pending); result.progress=float(r.progress); result.quality=state.quality(r)
		var speed=(0.35+result.quality*0.65)*(1.0+(int(r.level)-1)*float(state.island_rules.production.level_speed_bonus))/float(state.island_rules.production.seconds_per_unit)
		if "process_control" in state.campus.unlocked_materials: speed*=1.15
		result.eta=ceili((1.0-float(r.progress))/speed)
		result.message="成品已在反应釜中，收获后才会进入背包" if result.pending>0 else "反应釜正在合成；调整键长和角度可以提高产率"
		if int(r.pending)>=state.reactor_capacity(r): result.message="反应釜已满，暂停合成；先收获或安排博士收集"
		return result
	result.phase="prepare"
	var quote=state.sandbox_reactor_quote(index,draft(state,reference))
	result.required=quote.required; result.start_ready=quote.ready; result.message=quote.message
	var can_buy=true
	for symbol in quote.required:
		var count=maxi(0,int(quote.required[symbol])-int(state.element_inventory.get(symbol,0)))
		if count<=0: continue
		result.missing[symbol]=count
		var purchase=state.purchase_quote(symbol,count)
		result.element_cost+=int(purchase.total); can_buy=can_buy and purchase.ready
	result.can_buy=can_buy and not result.missing.is_empty() and state.coins>=result.element_cost
	return result

func buy_missing(state,index: int,reference: String) -> String:
	var q=status(state,index,reference)
	if q.phase!="prepare" or not q.can_buy: return "无需购入，或金币不足；请检查所选反应釜"
	# All prices/capacity checks precede any debit; buying only fills element stock.
	for symbol in q.missing: state.buy_elements(symbol,int(q.missing[symbol]))
	return "缺少元素已入库；还没有合成分子，请提交装炉"

func start(state,index: int,reference: String) -> String:
	var q=status(state,index,reference)
	if q.phase!="prepare": return "本炉已有该结构或正在装炉，不会重复扣费"
	if not q.start_ready: return q.message
	return state.apply_sandbox_to_reactor(index,draft(state,reference))

func harvest(state,index: int,reference: String) -> String:
	var q=status(state,index,reference)
	if q.phase not in ["producing","ready"]: return "这台炉还没有完成目标分子的装炉"
	return state.harvest(index)
