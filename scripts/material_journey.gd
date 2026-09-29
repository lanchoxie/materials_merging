extends RefCounted
## Guidance is derived from real progress; no second quest ledger or free rewards.
static func next(state) -> Dictionary:
	var p=state.planet; var f=p.laminates
	if not p.joined: return step(0,"开启材料制造","在工艺车间领取供料，再把浮岛样品用于研究、制造和星球探索。","factory","前往工艺车间")
	var record=""
	for id in p.materials.records:
		if not f.model.counts(p.materials.records[id].work).is_empty(): record=id; break
	if record.is_empty():
		for batch in state.storage.batches:
			if not f.model.counts(batch.work).is_empty(): return step(1,"为铜铝提案留样","仓库里已有铜铝样品，留存1份，保留原子位置与结构身份。","materials","留存已有样品")
		for reactor in state.reactors:
			if not f.model.counts(state.reactor_work(reactor)).is_empty(): return step(1,"收集反应炉样品","等待生产完成后收集。炉子里的待收集产物还不能用于订单或档案。","island","回岛收集")
		if state.element_inventory.get("Cu",0)>0 and state.element_inventory.get("Al",0)>0: return step(1,"搭建铜铝投料提案","在工作台加入铜与铝，保存并装炉；博士负责搬运，坐标由你决定。","sandbox","打开结构工坊")
		return step(1,"准备铜与铝","购买两种元素，再搭一个铜铝作品。可以先试2份铜、1份铝。","elements","前往元素商店")
	if not f.unlocked(state): return step(2,"学习热阻网络方法","教授1人指导博士2人，在连通的科研院所开展分层构件方法课题。这里只解锁有范围的计算方法。","research","查看科研团队")
	var design=""
	for id in p.materials.designs:
		if p.materials.designs[id].basis=="family_model": design=id; break
	if design.is_empty(): return step(3,"决定层片与用途","同样配比，顺着层片与横穿层片的热导不同。保存一个适合重量或尺寸约束的方案。","materials","设计铜铝层芯")
	if not f.job.is_empty(): return step(4,"工程师装配中","层料已经预留。工程师到工艺车间后加工；行路、休息和其他本岛订单会影响进度。","workshop","查看装配进度")
	if f.total()>0: return step(5,"让新构件派上用场","查看广场收购商的性质需求，把合适的构件交给来访客人。","mail","接待收购商")
	if f.deliveries>0 or not f.installed.is_empty(): return step(6,"完成一次材料循环","继续改变配比和层片方向，比较构件性质并满足新的订单。新方案仍需重新装配。","materials","继续设计与对照")
	return step(4,"把模型方案做成构件","采购标准铜铝层料，在连通的工艺车间安排工程师。原子库存、工业供料和成品分别记账。","workshop","采购层料并装配")
static func step(index: int,title: String,detail: String,route: String,action: String) -> Dictionary:
	return {"index":index,"title":title,"detail":detail,"route":route,"action":action}
