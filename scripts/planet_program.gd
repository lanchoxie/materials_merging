extends RefCounted
## Coordinates atomic island transactions; simulation and views never debit inventory.
const Worlds=preload("res://scripts/planet_worlds.gd")
const Count=preload("res://scripts/island_storage.gd")
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_balance.json"))
var worlds=Worlds.new(config)
var lab=preload("res://scripts/material_lab.gd").new()
var reports: Dictionary={}
var production_mode="partner"
var joined=false
var qualified=false
var qualification: Dictionary={}
var extra_qualifications: Dictionary={}
var supplies: Dictionary={}
var feed=0
var products: Array=[]
var job: Dictionary={}
var serial=1
var shipment_serial=1
var observing=false
var observer_id=0
var _reference_cache: Dictionary={}
var notice=""

func _init() -> void:
	for id in config.supplies: supplies[id]=0

func recipe_ids() -> Array:
	return ["standard_water_crate"]+config.recipes.keys()

func recipe(id: String) -> Dictionary:
	if id=="standard_water_crate":
		return {"id":id,"version":int(config.recipe.version),"name":str(config.recipe.name),"reference":"water","input":"feed","fee":int(config.workshop.packing_cost),"seconds":float(config.workshop.packing_seconds),"description":"把合作方标准供料装入回收水箱。"}
	return config.recipes.get(id,{})

func qualified_for(reference: String) -> bool:
	if reference.begins_with("fixture:"): return reports.has(reference.trim_prefix("fixture:"))
	return qualified if reference=="water" else extra_qualifications.has(reference)

func evidence(reference: String) -> Dictionary:
	if reference.begins_with("fixture:"): return reports.get(reference.trim_prefix("fixture:"),{})
	return qualification if reference=="water" else extra_qualifications.get(reference,{})

func input_count(id: String) -> int:
	return feed if id=="feed" else int(supplies.get(id,0))

func _input_add(id: String,amount: int) -> void:
	if id=="feed": feed+=amount
	else: supplies[id]=input_count(id)+amount

func available_products(recipe_id: String="standard_water_crate") -> int:
	var result=0
	for item in products:
		if item.recipe==recipe_id: result+=1
	return result

func available_in(world: Dictionary,recipe_id: String) -> int:
	if world.mode=="career": return available_products(recipe_id)
	return int(world.allowance) if recipe_id=="standard_water_crate" else int(world.eco_allowance.get(recipe_id,0))

func water_candidates(state) -> Array:
	return sample_candidates(state,"water")

func sample_candidates(state,reference: String) -> Array:
	var candidates=[]
	for batch in state.storage.batches:
		# Resolve the immutable structure, not its original template label.
		if not _reference_cache.has(batch.id):
			if _reference_cache.size()>=512: _reference_cache.clear()
			_reference_cache[batch.id]=str(state.sandbox_reference(batch.work).get("reference_id",""))
		if _reference_cache[batch.id]==reference: candidates.append(batch)
	return candidates

func command(state,action: String,payload: Dictionary={}) -> String:
	match action:
		"production_mode":
			var mode=str(payload.get("mode",""))
			if mode not in ["partner","island"]: return "未知工坊模式"
			production_mode=mode
			return "已交给合作工坊" if mode=="partner" else "已交给本岛车间；工程师到岗后才开始加工"
		"join":
			if joined: return "合作补给已领取"
			joined=true; feed=int(config.workshop.starter_feed)
			return "已加入试验湾合作，收到%d份标准供料" % feed
		"compare_materials":
			if not joined: return "先领取试验湾合作"
			var mode=str(payload.get("mode","")); var proof=lab.proof(mode)
			if proof.is_empty(): return "未知对照条件"
			reports[mode]=proof
			return "已记录%s计算对照；对应导热芯可在工坊制作。" % ("同尺寸" if mode=="same_size" else "同重量")
		"qualify":
			if not joined: return "先在邮箱领取试验湾合作"
			var ref=str(payload.get("reference","water"))
			if ref not in ["water","oxygen"]: return "暂无这个体系的工艺"
			if qualified_for(ref): return "工艺已经解锁，无需重复提交样品"
			var id=str(payload.get("batch_id","")); var accepted: Dictionary={}
			for candidate in sample_candidates(state,ref):
				if candidate.id==id: accepted=candidate
			if accepted.is_empty() or int(accepted.quantity)<int(config.workshop.samples_required): return "需要同一批次的%d份%s样品，其他结构不能代替" % [int(config.workshop.samples_required),"水" if ref=="water" else "氧气 O₂"]
			var proof={"batch_id":id,"work":accepted.work.duplicate(true),"reference":ref,"method":"reference_identity_v1"}
			state.storage.take_product(id,int(config.workshop.samples_required))
			if ref=="water": qualification=proof; qualified=true
			else: extra_qualifications[ref]=proof
			return "%s样品身份已验证，对应工艺开放；批量供料由合作方提供" % ("水" if ref=="water" else "氧气")
		"buy_feed":
			if not joined: return "先领取合作补给"
			var input_id=str(payload.get("input","feed"))
			if input_id!="feed" and not config.supplies.has(input_id): return "未知供料"
			var reserved=int(not job.is_empty() and recipe(str(job.recipe)).input==input_id)
			if input_count(input_id)+reserved>=int(config.workshop.inventory_limit): return "供料仓已满（含工坊预留供料）"
			var price=int(config.workshop.feed_cost) if input_id=="feed" else int(config.supplies[input_id].price)
			if state.coins<price: return "金币不足，供料%d金币一份" % price
			state.coins-=price; _input_add(input_id,1)
			return "购入1份%s" % ("标准水供料（含容器）" if input_id=="feed" else str(config.supplies[input_id].name))
		"pack":
			var info=recipe(str(payload.get("recipe","standard_water_crate")))
			if info.is_empty(): return "未知工艺"
			if not qualified_for(str(info.reference)): return "先完成材料对照或提交对应结构样品解锁工艺"
			if not job.is_empty(): return "装罐台正在工作"
			if products.size()>=int(config.workshop.product_limit): return "成品仓已满，请先部署成品"
			if input_count(str(info.input))<1 or state.coins<float(info.fee): return "需要1份对应供料与%d金币工费" % int(info.fee)
			_input_add(str(info.input),-1); state.coins-=float(info.fee)
			job={"id":serial,"recipe":str(info.id),"recipe_version":int(info.version),"left":float(info.seconds),"duration":float(info.seconds),"fee":int(info.fee),"source_batch":str(evidence(str(info.reference)).batch_id)}
			serial+=1
			return "%s制作中 · 标准工时%d秒，完工后自动入库" % [info.name,int(info.seconds)]
		"cancel_pack":
			if job.is_empty(): return "装罐台当前空闲"
			# Supply is reserved until completion; service fee covers interrupted work.
			_input_add(str(recipe(str(job.recipe)).input),1); job.clear()
			return "已退回预留供料；本次装罐费不退还"
		"deploy":
			var id=str(payload.get("world_id","")); var site=str(payload.get("site_id",""))
			var recipe_id=str(payload.get("recipe","standard_water_crate"))
			if recipe(recipe_id).is_empty(): return "未知成品"
			if not Count.count_ok(payload.get("token")) or int(payload.token)!=shipment_serial: return "这次投放已处理或已过期，请重新选择水箱"
			if not joined or not worlds.can_deploy(id,site,recipe_id): return "落点不适用：请检查支架的尺寸/重量限制、已有设备或剩余补给"
			var w=worlds.get_world(id); var component: Dictionary={}; var old: Dictionary={}
			if lab.is_component(recipe_id): old=worlds.component_region(w,site).component.duplicate(true)
			if w.mode=="career":
				if available_products(recipe_id)<=0: return "主仓库暂无这个成品，请先制作"
				for i in range(products.size()):
					if products[i].recipe==recipe_id:
						if lab.is_component(recipe_id): component=products[i].duplicate(true)
						products.remove_at(i); break
				if not old.is_empty(): products.append(old)
			else:
				if available_in(w,recipe_id)<=0: return "本次实验配给已用完，可以重置实验"
				if recipe_id=="standard_water_crate": w.allowance=int(w.allowance)-1
				else: w.eco_allowance[recipe_id]=int(w.eco_allowance[recipe_id])-1
				if lab.is_component(recipe_id):
					component={"id":0,"recipe":recipe_id,"recipe_version":1,"source_batch":lab.proof(str(lab.data.designs[recipe_id].mode)).batch_id}
					if not old.is_empty(): w.eco_allowance[old.recipe]=int(w.eco_allowance[old.recipe])+1
			worlds.deploy(id,site,shipment_serial,recipe_id,component); shipment_serial+=1
			return "%s已交付%s%s" % [recipe(recipe_id).name,w.name,"；开始观察后运行" if w.paused else ""]
		"select":
			var id=str(payload.get("world_id",""))
			if worlds.get_world(id).is_empty(): return "这个世界不存在"
			worlds.active_id=id; return "已切换到%s" % worlds.get_world().name
		"fork":
			if not joined: return "先领取试验湾合作"
			return worlds.fork(bool(payload.get("dry",false)),str(payload.get("era","")))
		"reset_trial": return worlds.reset_trial(bool(payload.get("fresh",false)),str(payload.get("era","")))
		"activate_village":
			if not joined: return "先领取合作补给"
			return worlds.activate_village()
		"village":
			if not joined: return "先领取合作补给"
			var w=worlds.get_world(); var before=worlds.ecology.canonical(w.village)
			var result=worlds.village.control(w.village,str(payload.get("control","")),str(payload.get("id","")))
			if before!=worlds.ecology.canonical(w.village): worlds._event(w,"village",result)
			return result
		"activate_watershed":
			if not joined: return "先领取合作补给"
			return worlds.activate_watershed(str(payload.get("era","devonian")))
		"watershed":
			if not joined: return "先领取合作补给"
			var w=worlds.get_world(); var before=worlds.ecology.canonical(w.watershed)
			var result=worlds.watershed.control(w.watershed,str(payload.get("site","")),str(payload.get("control","")))
			if before!=worlds.ecology.canonical(w.watershed): worlds._event(w,"watershed",result)
			return result
		"ecology":
			if not joined: return "先领取合作补给"
			var w=worlds.get_world(); var before=worlds.ecology.canonical(w.ecology)
			var result=worlds.ecology.control(w.ecology,str(payload.get("site","")),str(payload.get("control","")))
			if before!=worlds.ecology.canonical(w.ecology): worlds._event(w,"ecology",result)
			return result
		"pause":
			var w=worlds.get_world(); w.paused=not w.paused
			return "观察已暂停" if w.paused else "观察继续"
		"step_world":
			var w=worlds.get_world(); w.paused=true; worlds.tick_world(w,30.0)
			return "当前世界推进30秒，已暂停"
		"step_pair": return worlds.step_pair()
	return "未知的星球操作"

func tick(dt: float,effort: float=0.0) -> void:
	if not is_finite(dt) or dt<=0 or dt>60: return
	var rate=1.0 if production_mode=="partner" else (clampf(effort,0,100) if is_finite(effort) else 0.0)
	if not job.is_empty():
		job.left=maxf(0,float(job.left)-dt*rate)
		if float(job.left)<=0:
			products.append({"id":int(job.id),"recipe":str(job.recipe),"recipe_version":int(job.recipe_version),"source_batch":str(job.source_batch)})
			notice="%s制作完成，已收入工业成品仓" % recipe(str(job.recipe)).name; job.clear()
	if observing: worlds.tick(dt)

func serialize() -> Dictionary:
	return {"version":5,"production_mode":production_mode,"reports":reports.duplicate(true),"joined":joined,"qualified":qualified,"qualification":qualification.duplicate(true),"extra_qualifications":extra_qualifications.duplicate(true),"supplies":supplies.duplicate(true),"feed":feed,"products":products.duplicate(true),"job":job.duplicate(true),"serial":serial,"shipment_serial":shipment_serial,"worlds":worlds.serialize()}

func restore(data,state) -> bool:
	if not data is Dictionary or not Count.count_ok(data.get("version")) or int(data.version) not in [1,2,3,4,5]: return false
	data=data.duplicate(true)
	if data.version<5: data.production_mode="partner"
	if data.get("production_mode") not in ["partner","island"]: return false
	if data.version==1: data.extra_qualifications={}; data.supplies={"station_parts":0,"oxygen_feed":0}
	if data.version<3:
		if not data.get("supplies") is Dictionary or data.supplies.size()!=2: return false
		data.reports={}; data.supplies.copper_kit=0; data.supplies.aluminum_kit=0
	if data.version<4:
		if not data.get("supplies") is Dictionary or data.supplies.size()!=4: return false
		for id in ["nutrient_kit","screen_kit","screen_feed","buffer_kit","harvest_kit"]: data.supplies[id]=0
	if data.version<5:
		if not data.get("supplies") is Dictionary or data.supplies.size()!=9: return false
		for id in ["drinking_kit","frame_kit","tool_chest_kit"]: data.supplies[id]=0
	if not data.get("reports") is Dictionary or data.reports.size()>2: return false
	for mode in data.reports:
		if not lab.valid_report(data.reports[mode],str(mode)) or data.get("joined")!=true: return false
	if not data.get("joined") is bool or not data.get("qualified") is bool or (data.qualified and not data.joined): return false
	if not Count.count_ok(data.get("feed")) or int(data.feed)>int(config.workshop.inventory_limit): return false
	for key in ["serial","shipment_serial"]:
		if not Count.count_ok(data.get(key)) or int(data[key])<1: return false
	if not data.get("qualification") is Dictionary: return false
	if data.qualified:
		var q=data.qualification
		if not q.get("batch_id") is String or q.batch_id.is_empty() or q.batch_id.length()>96 or q.get("reference")!="water" or q.get("method")!="reference_identity_v1": return false
		if not q.get("work") is Dictionary or not state.sandbox_validate(q.work): return false
		if state.sandbox_reference(q.work).get("reference_id","")!="water": return false
	elif not data.qualification.is_empty(): return false
	if not data.get("supplies") is Dictionary or data.supplies.size()!=config.supplies.size(): return false
	for key in config.supplies:
		if not Count.count_ok(data.supplies.get(key)) or int(data.supplies[key])>int(config.workshop.inventory_limit): return false
	if not data.get("extra_qualifications") is Dictionary or data.extra_qualifications.size()>1: return false
	for ref in data.extra_qualifications:
		if ref!="oxygen" or not data.joined: return false
		var q=data.extra_qualifications[ref]
		if not q is Dictionary or not q.get("batch_id") is String or q.batch_id.is_empty() or q.batch_id.length()>96: return false
		if q.get("reference")!=ref or q.get("method")!="reference_identity_v1" or not q.get("work") is Dictionary: return false
		if not state.sandbox_validate(q.work) or state.sandbox_reference(q.work).get("reference_id","")!=ref: return false
	if not data.get("products") is Array or data.products.size()>int(config.workshop.product_limit): return false
	var ids=[]
	for product in data.products:
		if not _valid_product(product,data,ids): return false
		ids.append(int(product.id))
	if not data.get("job") is Dictionary: return false
	if not data.job.is_empty():
		if not _valid_product(data.job,data,ids) or data.products.size()>=int(config.workshop.product_limit): return false
		var info=recipe(str(data.job.recipe))
		var stock=int(data.feed) if info.input=="feed" else int(data.supplies[info.input])
		if stock>=int(config.workshop.inventory_limit): return false
		for key in ["left","duration"]:
			if not (data.job.get(key) is int or data.job.get(key) is float) or not is_finite(float(data.job[key])): return false
		# Work already paid for retains its quoted duration and fee after balance updates.
		if float(data.job.duration)<=0 or float(data.job.duration)>86400 or float(data.job.left)<=0 or float(data.job.left)>float(data.job.duration): return false
		if not Count.count_ok(data.job.get("fee")) or int(data.job.fee)>1000000: return false
	var restored=Worlds.new(config)
	if int(data.version)>=2 and (not data.get("worlds") is Dictionary or data.worlds.get("version")!=data.version): return false
	if not restored.restore(data.get("worlds")): return false
	if not data.job.is_empty(): ids.append(int(data.job.id))
	for r in restored.component_regions(restored.get_world("home")):
		if not r.component.is_empty():
			if not _valid_product(r.component,data,ids): return false
			ids.append(int(r.component.id))
	if not data.joined and (int(data.feed)>0 or not data.products.is_empty() or not data.job.is_empty() or restored.worlds.size()>1): return false
	if not data.joined:
		if restored.get_world("home").village.enabled: return false
		for n in data.supplies.values():
			if int(n)>0: return false
	production_mode=data.production_mode
	reports=data.reports.duplicate(true)
	joined=data.joined; qualified=data.qualified; qualification=data.qualification.duplicate(true)
	feed=int(data.feed); products=data.products.duplicate(true); job=data.job.duplicate(true)
	extra_qualifications=data.extra_qualifications.duplicate(true); supplies=data.supplies.duplicate(true)
	serial=int(data.serial); shipment_serial=int(data.shipment_serial); worlds=restored; observing=false
	return true

func _valid_product(product,data,ids: Array) -> bool:
	if not product is Dictionary: return false
	if not Count.count_ok(product.get("id")) or int(product.id)<1 or int(product.id)>=int(data.serial) or int(product.id) in ids: return false
	var info=recipe(str(product.get("recipe","")))
	if info.is_empty(): return false
	var q=data.qualification if info.reference=="water" else data.extra_qualifications.get(info.reference,{})
	if str(info.reference).begins_with("fixture:"): q=data.reports.get(str(info.reference).trim_prefix("fixture:"),{})
	if q.is_empty() or (info.reference=="water" and not data.qualified): return false
	return product.get("recipe_version")==int(info.version) and product.get("source_batch")==str(q.batch_id)
