extends RefCounted
## Coordinates atomic island transactions; simulation and views never debit inventory.
const Worlds=preload("res://scripts/planet_worlds.gd")
const Count=preload("res://scripts/island_storage.gd")
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_balance.json"))
var worlds=Worlds.new(config)
var joined=false
var qualified=false
var qualification: Dictionary={}
var feed=0
var products: Array=[]
var job: Dictionary={}
var serial=1
var shipment_serial=1
var observing=false
var observer_id=0
var _reference_cache: Dictionary={}
var notice=""

func available_products() -> int:
	return products.size()

func water_candidates(state) -> Array:
	var candidates=[]
	for batch in state.storage.batches:
		# Resolve the immutable structure, not its original template label.
		if not _reference_cache.has(batch.id):
			if _reference_cache.size()>=512: _reference_cache.clear()
			_reference_cache[batch.id]=str(state.sandbox_reference(batch.work).get("reference_id",""))
		if _reference_cache[batch.id]=="water": candidates.append(batch)
	return candidates

func command(state,action: String,payload: Dictionary={}) -> String:
	match action:
		"join":
			if joined: return "合作补给已领取"
			joined=true; feed=int(config.workshop.starter_feed)
			return "已加入试验湾合作，收到%d份标准供料" % feed
		"qualify":
			if not joined: return "先在邮箱领取试验湾合作"
			if qualified: return "装罐工艺已经解锁，无需重复提交样品"
			var id=str(payload.get("batch_id","")); var accepted: Dictionary={}
			for candidate in water_candidates(state):
				if candidate.id==id: accepted=candidate
			if accepted.is_empty() or int(accepted.quantity)<int(config.workshop.samples_required): return "需要同一批次的%d份已收集水样；其他含氢或含氧结构不能代替" % int(config.workshop.samples_required)
			qualification={"batch_id":id,"work":accepted.work.duplicate(true),"reference":"water","method":"reference_identity_v1"}
			state.storage.take_product(id,int(config.workshop.samples_required)); qualified=true
			return "水样身份已验证，独立装罐台开放；供料由合作方提供"
		"buy_feed":
			if not joined: return "先领取合作补给"
			if feed+int(not job.is_empty())>=int(config.workshop.inventory_limit): return "供料仓已满（含装罐台预留供料）"
			if state.coins<float(config.workshop.feed_cost): return "金币不足，供料%d金币一份" % int(config.workshop.feed_cost)
			state.coins-=float(config.workshop.feed_cost); feed+=1
			return "购入1份标准供料（含容器）"
		"pack":
			if not qualified: return "先提交水样解锁装罐工艺"
			if not job.is_empty(): return "装罐台正在工作"
			if products.size()>=int(config.workshop.product_limit): return "成品仓已满，请先部署水箱"
			if feed<1 or state.coins<float(config.workshop.packing_cost): return "需要1份供料与%d金币装罐费" % int(config.workshop.packing_cost)
			feed-=1; state.coins-=float(config.workshop.packing_cost)
			job={"id":serial,"recipe":str(config.recipe.id),"recipe_version":int(config.recipe.version),"left":float(config.workshop.packing_seconds),"duration":float(config.workshop.packing_seconds),"fee":int(config.workshop.packing_cost),"source_batch":str(qualification.batch_id)}
			serial+=1
			return "已开始装罐 · %d秒后水箱自动入库" % int(config.workshop.packing_seconds)
		"cancel_pack":
			if job.is_empty(): return "装罐台当前空闲"
			# Supply is reserved until completion; service fee covers interrupted work.
			feed+=1; job.clear()
			return "已退回预留供料；本次装罐费不退还"
		"deploy":
			var id=str(payload.get("world_id","")); var site=str(payload.get("site_id",""))
			if not Count.count_ok(payload.get("token")) or int(payload.token)!=shipment_serial: return "这次投放已处理或已过期，请重新选择水箱"
			if not joined or not worlds.can_deploy(id,site): return "请选择还有容量的盆地落点"
			var w=worlds.get_world(id)
			if w.mode=="career":
				if products.is_empty(): return "主仓库暂无水箱，请先装罐"
				products.pop_front()
			else:
				if int(w.allowance)<=0: return "本次实验配给已用完，可以重置实验"
				w.allowance=int(w.allowance)-1
			worlds.deploy(id,site,shipment_serial); shipment_serial+=1
			return "水箱已交付%s；%s" % [w.name,"开始观察后会流入盆地" if w.paused else "正在经管道注入盆地"]
		"select":
			var id=str(payload.get("world_id",""))
			if worlds.get_world(id).is_empty(): return "这个世界不存在"
			worlds.active_id=id; return "已切换到%s" % worlds.get_world().name
		"fork":
			if not joined: return "先领取试验湾合作"
			return worlds.fork(bool(payload.get("dry",false)))
		"reset_trial": return worlds.reset_trial()
		"pause":
			var w=worlds.get_world(); w.paused=not w.paused
			return "观察已暂停" if w.paused else "观察继续"
		"step_pair": return worlds.step_pair()
	return "未知的星球操作"

func tick(dt: float) -> void:
	if not is_finite(dt) or dt<=0 or dt>60: return
	if not job.is_empty():
		job.left=maxf(0,float(job.left)-dt)
		if float(job.left)<=0:
			products.append({"id":int(job.id),"recipe":str(job.recipe),"recipe_version":int(job.recipe_version),"source_batch":str(job.source_batch)})
			job.clear(); notice="标准水箱装罐完成，已收入工业成品仓"
	if observing: worlds.tick(dt)

func serialize() -> Dictionary:
	return {"version":1,"joined":joined,"qualified":qualified,"qualification":qualification.duplicate(true),"feed":feed,"products":products.duplicate(true),"job":job.duplicate(true),"serial":serial,"shipment_serial":shipment_serial,"worlds":worlds.serialize()}

func restore(data,state) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	if not data.get("joined") is bool or not data.get("qualified") is bool or (data.qualified and not data.joined): return false
	if not Count.count_ok(data.get("feed")) or int(data.feed)>int(config.workshop.inventory_limit): return false
	for key in ["serial","shipment_serial"]:
		if not Count.count_ok(data.get(key)) or int(data[key])<1: return false
	if not data.get("qualification") is Dictionary: return false
	if data.qualified:
		var q=data.qualification
		if not q.get("batch_id") is String or q.batch_id.length()>96 or q.get("reference")!="water" or q.get("method")!="reference_identity_v1": return false
		if not q.get("work") is Dictionary or not state.sandbox_validate(q.work): return false
		if state.sandbox_reference(q.work).get("reference_id","")!="water": return false
	elif not data.qualification.is_empty(): return false
	if not data.get("products") is Array or data.products.size()>int(config.workshop.product_limit): return false
	var ids=[]
	for product in data.products:
		if not _valid_product(product,data,ids): return false
		ids.append(int(product.id))
	if not data.get("job") is Dictionary: return false
	if not data.job.is_empty():
		if int(data.feed)>=int(config.workshop.inventory_limit): return false
		if not _valid_product(data.job,data,ids) or data.products.size()>=int(config.workshop.product_limit): return false
		for key in ["left","duration"]:
			if not (data.job.get(key) is int or data.job.get(key) is float) or not is_finite(float(data.job[key])): return false
		if float(data.job.duration)!=float(config.workshop.packing_seconds) or float(data.job.left)<=0 or float(data.job.left)>float(data.job.duration): return false
		if data.job.get("fee")!=int(config.workshop.packing_cost): return false
	var restored=Worlds.new(config)
	if not restored.restore(data.get("worlds")): return false
	if not data.joined and (int(data.feed)>0 or not data.products.is_empty() or not data.job.is_empty() or restored.worlds.size()>1): return false
	joined=data.joined; qualified=data.qualified; qualification=data.qualification.duplicate(true)
	feed=int(data.feed); products=data.products.duplicate(true); job=data.job.duplicate(true)
	serial=int(data.serial); shipment_serial=int(data.shipment_serial); worlds=restored; observing=false
	return true

func _valid_product(product,data,ids: Array) -> bool:
	if not data.qualified or not product is Dictionary: return false
	if not Count.count_ok(product.get("id")) or int(product.id)<1 or int(product.id)>=int(data.serial) or int(product.id) in ids: return false
	return product.get("recipe")==str(config.recipe.id) and product.get("recipe_version")==int(config.recipe.version) and product.get("source_batch")==str(data.qualification.get("batch_id",""))
