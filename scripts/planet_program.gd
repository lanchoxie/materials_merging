extends RefCounted
## Coordinates atomic island transactions; simulation and views never debit inventory.
const Legacy=preload("res://scripts/retired_planet_data.gd")
const Count=preload("res://scripts/island_storage.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const WorkshopAccess=preload("res://scripts/workshop_access.gd")
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/factory_recipes.json"))
var retired_planet: Dictionary={}
var lab=preload("res://scripts/material_lab.gd").new()
var reports: Dictionary={}
var circuit_reports: Dictionary={}
var electrical=preload("res://scripts/electrical_lab.gd").new()
var laminates=preload("res://scripts/laminate_workshop.gd").new()
var materials=preload("res://scripts/player_materials.gd").new()
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
var _reference_cache: Dictionary={}
var notice=""
var v2=PlanetV2.new()

func _init() -> void:
	for id in config.supplies: supplies[id]=0

func recipe_ids() -> Array:
	return ["standard_water_crate"]+config.recipes.keys()+v2.field.rules.recipes.keys()

func recipe(id: String) -> Dictionary:
	if v2.field.rules.recipes.has(id): return v2.field.rules.recipes[id]
	if materials.designs.has(id):
		var d=materials.designs[id]; var name=str(materials.records[d.record_id].name)
		if d.basis=="family_model": return {"id":id,"version":1,"name":laminates.model.name(d),"domain":"modern","reference":"laminate","input":"","fee":int(laminates.model.rules.manufacturing.fee),"seconds":float(laminates.model.rules.manufacturing.seconds),"description":"标准铜铝层料的理想装配模型，非合金实测。"}
		return {"id":id,"version":1,"name":name+(" · 假设散热芯" if d.kind=="sink" else " · 假设导线"),"domain":"calculation","reference":"hypothesis","input":"","fee":0,"seconds":0,"description":"保留计算依据的假设方案，不进入真实成品仓。"}
	if id=="standard_water_crate":
		return {"id":id,"version":int(config.recipe.version),"name":str(config.recipe.name),"reference":"water","input":"feed","fee":int(config.workshop.packing_cost),"seconds":float(config.workshop.packing_seconds),"description":"把合作方标准供料装入回收水箱。"}
	return config.recipes.get(id,{})

func qualified_for(reference: String) -> bool:
	if reference.begins_with("circuit:"): return circuit_reports.has(reference.trim_prefix("circuit:"))
	if reference.begins_with("fixture:"): return reports.has(reference.trim_prefix("fixture:"))
	return qualified if reference=="water" else extra_qualifications.has(reference)

func evidence(reference: String) -> Dictionary:
	if reference.begins_with("circuit:"): return circuit_reports.get(reference.trim_prefix("circuit:"),{})
	if reference.begins_with("fixture:"): return reports.get(reference.trim_prefix("fixture:"),{})
	return qualification if reference=="water" else extra_qualifications.get(reference,{})

func input_count(id: String) -> int:
	return feed if id=="feed" else int(supplies.get(id,0))

func _input_add(id: String,amount: int) -> void:
	if id=="feed": feed+=amount
	else: supplies[id]=input_count(id)+amount

func available_products(recipe_id: String="standard_water_crate") -> int:
	if materials.designs.get(recipe_id,{}).get("basis")=="family_model": return laminates.count(recipe_id)
	var result=0
	for item in products:
		if item.recipe==recipe_id: result+=1
	return result

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
		"laminate_research":
			if not joined: return "先领取合作补给"
			return state.campus_start_research(laminates.model.rules.project)
		"propose_laminate":
			if not joined: return "先领取合作补给"
			return materials.propose_laminate(state,str(payload.get("record_id","")),str(payload.get("orientation","")),str(payload.get("mode","")))
		"laminate_buy": return laminates.buy(state,str(payload.get("element",""))) if joined else "先领取合作补给"
		"laminate_pack": return laminates.start(state,materials.designs.get(str(payload.get("design_id","")),{})) if joined else "先领取合作补给"
		"laminate_cancel": return laminates.cancel()
		"laminate_deliver": return state.fulfill_order(int(payload.get("visitor_id",-1)),str(payload.get("design_id",""))) if joined else "先领取合作补给"
		"archive_material":
			if not joined: return "先领取合作补给"
			return materials.archive(state,str(payload.get("batch_id","")))
		"propose_material":
			if not joined or not payload.get("properties") is Dictionary: return "请选择结构并填写用途所需的假设"
			return materials.propose(str(payload.get("record_id","")),str(payload.get("kind","")),str(payload.get("mode","")),payload.properties)
		"compare_circuits":
			if not joined: return "先领取合作补给"
			var mode=str(payload.get("mode","")); var report=electrical.proof(mode)
			if report.is_empty(): return "未知电学约束"
			circuit_reports[mode]=report; return "已记录20°C导线计算对照；对应标准导线开放制作。"
		"production_mode":
			var mode=str(payload.get("mode",""))
			if mode not in ["partner","island"]: return "未知工坊模式"
			if mode=="partner" and not job.is_empty() and recipe(str(job.recipe)).has("natural_inputs"): return "采集材料必须由本岛工程师加工，不能切换成合作代工"
			production_mode=mode
			return "已交给合作工坊" if mode=="partner" else "已交给本岛车间；工程师到岗后才开始加工"
		"join":
			if joined: return "合作补给已领取"
			joined=true; feed=int(config.workshop.starter_feed)
			return "已加入浮岛工坊合作，收到%d份标准供料" % feed
		"compare_materials":
			if not joined: return "先领取浮岛工坊合作"
			var mode=str(payload.get("mode","")); var proof=lab.proof(mode)
			if proof.is_empty(): return "未知对照条件"
			reports[mode]=proof
			return "已记录%s计算对照；对应导热芯可在工坊制作。" % ("同尺寸" if mode=="same_size" else "同重量")
		"qualify":
			if not joined: return "先在邮箱领取浮岛工坊合作"
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
			if info.has("natural_inputs"): return _pack_natural(state,info)
			var mode=str(payload.get("production_mode",production_mode))
			if mode not in ["partner","island"]: return "未知加工方式"
			if mode=="island":
				var access=WorkshopAccess.status(state)
				if not access.ready: return access.message
			if not qualified_for(str(info.reference)): return "先完成材料对照或提交对应结构样品解锁工艺"
			if not job.is_empty(): return "装罐台正在工作"
			if products.size()>=int(config.workshop.product_limit): return "成品仓已满，请先部署成品"
			if input_count(str(info.input))<1 or state.coins<float(info.fee): return "需要1份对应供料与%d金币工费" % int(info.fee)
			_input_add(str(info.input),-1); state.coins-=float(info.fee)
			production_mode=mode
			job={"id":serial,"recipe":str(info.id),"recipe_version":int(info.version),"left":float(info.seconds),"duration":float(info.seconds),"fee":int(info.fee),"source_batch":str(evidence(str(info.reference)).batch_id)}
			serial+=1
			return "%s制作中 · 标准工时%d秒，完工后自动入库" % [info.name,int(info.seconds)]
		"cancel_pack":
			if job.is_empty(): return "装罐台当前空闲"
			if recipe(str(job.recipe)).has("natural_inputs"):
				var reason=v2.field.cancel(int(job.id))
				if not reason.is_empty(): return reason
				job.clear(); return "采集材料已全部退回背包"
			# Supply is reserved until completion; service fee covers interrupted work.
			_input_add(str(recipe(str(job.recipe)).input),1); job.clear()
			return "已退回预留供料；本次装罐费不退还"
		"v2_enter":
			return v2.enter(str(payload.get("region_id","wetland")))
		"v2_chop", "v2_dig", "v2_fill", "v2_tree_plant", "v2_strike", "v2_mini_pack", "v2_mini_unfold":
			if not v2.active or v2.actor.is_empty(): return "进入星球第一人称后再操作"
			if v2.combat.player_health<=0: return "先回营地休息"
			var aim=v2.Target.query(v2)
			match action:
				"v2_chop": return v2.nature.chop(str(aim.get("tree_id","")),v2.field,v2.construction.terrain)
				"v2_dig", "v2_fill":
					if aim.get("type")!="terrain": return "请瞄准没有植物或构件遮挡的地面"
					return v2.nature.terraform(-1 if action=="v2_dig" else 1,aim.point,v2)
				"v2_tree_plant":
					if aim.get("type")!="terrain": return "请瞄准空地种树"
					return v2.nature.plant(str(payload.get("species","")),Vector2(aim.point.x,aim.point.z),v2)
				"v2_strike": return v2.combat.strike(aim,v2)
				"v2_mini_pack":
					v2.construction.occupied=v2.field.gardens
					return preload("res://scripts/river_miniatures.gd").pack(v2.construction,aim)
				"v2_mini_unfold": return preload("res://scripts/river_miniatures.gd").unfold(v2.construction,str(payload.get("id","")),v2.actor)
		"v2_mini_exhibit":
			return preload("res://scripts/river_miniatures.gd").exhibit(v2.construction,str(payload.get("id","")),int(payload.get("plot",-1)),state.plots)
		"v2_build", "v2_dismantle":
			if not v2.active: return "请先进入星球"
			v2.construction.occupied=v2.field.gardens
			return v2.construction.interact("place" if action=="v2_build" else "remove",str(payload.get("kind","block")),products,v2.actor,str(payload.get("recipe","")))
		"v2_field_collect", "v2_field_plant", "v2_field_feed", "v2_field_water":
			return _field_action(state,action,payload)
		"v2_field_pantry":
			var id=str(payload.get("resource",""))
			if id not in ["fruit","grain"] or int(v2.field.stock.get(id,0))<1: return "背包中没有这种收获"
			v2.field.stock[id]-=1; v2.world.food+=1; v2.field.revision+=1; return "取出1份收获送入星球粮仓"
		"v2_repack":
			return v2.construction.repack(str(payload.get("source_id","")),products,int(config.workshop.product_limit))
		"v2_next_era":
			var previous=v2.settlement.era
			var result=v2.settlement.advance_era(v2.world,v2.construction)
			if previous!=v2.settlement.era: v2._event(result)
			return result
		"v2_pause":
			return v2.set_paused(bool(payload.get("paused",not v2.world.paused)))
		"v2_speed":
			return v2.set_speed(int(payload.get("speed",1)))
		"v2_plant":
			return v2.plant(str(payload.get("crop","grain")))
		"v2_harvest":
			return v2.harvest()
		"v2_pen":
			return v2.toggle_pen()
		"v2_renewal":
			v2.population.enabled=bool(payload.get("enabled",not v2.population.enabled))
			return "自然补充已开启" if v2.population.enabled else "自然补充已暂停；原有生命仍继续活动"
		"v2_collect_wild":
			var x=payload.get("x",0); var z=payload.get("z",0)
			if not (x is float or x is int) or not (z is float or z is int) or not is_finite(float(x)) or not is_finite(float(z)): return "无效位置"
			return v2.collect_wild(Vector2(float(x),float(z)))
		"v2_deploy_sample":
			if not Count.count_ok(payload.get("token")) or int(payload.token)!=shipment_serial: return "这次投放已处理，请重新选择样品"
			var batch=state.storage.batch(str(payload.get("batch_id","")))
			if batch.is_empty(): return "工具箱里已经没有这个批次"
			var ref=str(state.sandbox_reference(batch.work).get("reference_id",""))
			if ref not in ["water","oxygen"]: return "当前仅开放已识别水样和氧气样品的环境用途"
			var use="sample_"+ref; var target=str(payload.get("region_id",""))
			var reason=v2.quote(target,use)
			if not reason.is_empty(): return reason
			var record={"kind":"sample","batch_id":batch.id,"work":batch.work.duplicate(true),"reference":ref}
			if not state.storage.take_product(batch.id,1): return "样品数量不足"
			shipment_serial+=1
			return v2.deploy(target,use,record)
		"v2_deploy_product":
			if not joined: return "先领取浮岛合作补给"
			if not Count.count_ok(payload.get("product_id")): return "请选择仓库中的成品"
			var product_id=int(payload.product_id); var target=str(payload.get("region_id",""))
			for i in range(products.size()):
				if int(products[i].id)!=product_id: continue
				var item=products[i].duplicate(true); var reason=v2.quote(target,str(item.recipe))
				if not reason.is_empty(): return reason
				products.remove_at(i)
				return v2.deploy(target,str(item.recipe),{"kind":"product","product":item})
			return "星球仓库找不到这件成品"
	return "未知的星球操作"

func _pack_natural(state,info: Dictionary) -> String:
	if not joined: return "先在工艺车间领取合作，登记原料加工"
	var access=WorkshopAccess.status(state)
	if not access.ready: return access.message
	if not job.is_empty(): return "车间正在加工，请等当前订单完成"
	if products.size()>=int(config.workshop.product_limit): return "成品仓已满"
	var reason=v2.field.reserve(str(info.id),serial)
	if not reason.is_empty(): return reason
	production_mode="island"
	job={"id":serial,"recipe":str(info.id),"recipe_version":int(info.version),"left":float(info.seconds),"duration":float(info.seconds),"fee":0,"source_batch":"river:"+str(serial)}
	serial+=1
	return "已预留采集材料，等待本岛工程师加工；无需另买原料"

func _field_action(state,action: String,payload: Dictionary) -> String:
	if not v2.active: return "请先进入星球"
	var target=v2.Target.query(v2)
	if target.is_empty(): return "瞄准5米内的采集点、种植箱或小兽"
	if action=="v2_field_collect":
		if target.type=="resource": return v2.field.collect(target.node,int(v2.world.elapsed))
		if target.type=="facility" and target.recipe=="frame_bundle":
			var r=v2.world.regions[target.region]; r.enclosed=not r.enclosed
			return "围栏已关闭，动物改从粮仓取食" if r.enclosed else "围栏已打开，动物恢复自然觅食"
		if target.type=="block" and target.kind=="planter":
			var was_ready=v2.field.gardens.get(target.key,{}).get("growth",0)>=1
			var result=v2.field.harvest(target.key,v2.world)
			if was_ready and not v2.field.gardens.has(target.key): v2.settlement.harvests+=1
			return result
		return v2.Target.prompt(v2,target)
	if action=="v2_field_plant":
		if target.type!="block" or target.kind!="planter": return "装备种子，瞄准一个空种植箱播种"
		return v2.field.plant(target.key,v2.world,v2.construction)
	if action=="v2_field_feed":
		var resource=str(payload.get("resource","fruit"))
		if resource not in ["fruit","grain"] or int(v2.field.stock.get(resource,0))<1: return "背包缺少野果或谷穗"
		if target.type!="animal": return "走近并瞄准一只草甸小兽"
		if target.get("fish",false): return "鱼类不使用这种食物，未消耗库存"
		for animal in v2.world.regions[target.region].animals:
			if animal.id!=target.id: continue
			if animal.hunger<float(v2.field.rules.feeding.minimum_hunger): return "它已经吃饱了，没有消耗食物"
			v2.field.stock[resource]-=1; v2.field.revision+=1; animal.hunger=maxf(0,animal.hunger-float(v2.field.rules.feeding.hunger_reduction))
			return "%s吃了一份%s，饥饿降到%.0f%%" % [target.name,v2.field.rules.resources[resource].name,animal.hunger*100]
	if action=="v2_field_water":
		var is_tree=target.type=="tree"
		if not is_tree and (target.type!="block" or target.kind!="planter"): return "瞄准幼树或已播种的种植箱浇水"
		var reason=v2.nature.water_error(target.tree_id,v2.construction.terrain) if is_tree else v2.field.water_error(target.key)
		if not reason.is_empty(): return reason
		if not Count.count_ok(payload.get("token")) or int(payload.token)!=shipment_serial: return "这次浇水已处理"
		if payload.has("batch_id"):
			var batch=state.storage.batch(str(payload.batch_id))
			if batch.is_empty() or state.sandbox_reference(batch.work).get("reference_id")!="water": return "请选择已识别的水样；其他结构不能代替"
			if not state.storage.take_product(batch.id,1): return "水样不足"
		else:
			var index=-1
			for i in range(products.size()):
				if products[i].id==payload.get("product_id") and products[i].recipe=="standard_water_crate": index=i; break
			if index<0: return "没有这件标准水箱"
			products.remove_at(index)
		shipment_serial+=1
		if is_tree:
			v2.nature.water(target.tree_id,v2.construction.terrain)
			return "消耗一份水，幼树土壤变湿，生长加快"
		v2.field.water(target.key)
		var source="水样批次 "+str(payload.batch_id).left(80) if payload.has("batch_id") else "标准水箱 #"+str(payload.product_id)
		v2._event("种植箱%s收到1份%s；湿润只作用于这一箱。" % [target.key,source])
		return "这一箱土壤变湿了；已消耗1份水，旁边种植箱不受影响"
	return "这个目标暂不能执行该操作"

func tick(dt: float,effort: float=0.0) -> void:
	if not is_finite(dt) or dt<=0 or dt>60: return
	var rate=1.0 if production_mode=="partner" else (clampf(effort,0,100) if is_finite(effort) else 0.0)
	laminates.tick(dt,effort if production_mode=="partner" or job.is_empty() else 0.0)
	if not job.is_empty():
		job.left=maxf(0,float(job.left)-dt*rate)
		if float(job.left)<=0:
			products.append({"id":int(job.id),"recipe":str(job.recipe),"recipe_version":int(job.recipe_version),"source_batch":str(job.source_batch)})
			if recipe(str(job.recipe)).has("natural_inputs"): v2.field.crafts[str(job.id)].complete=true; v2.field.revision+=1
			notice="%s制作完成，已收入工业成品仓" % recipe(str(job.recipe)).name; job.clear()
	v2.tick(dt)

func serialize() -> Dictionary:
	return {"version":11,"laminates":laminates.serialize(),"materials":materials.serialize(),"circuit_reports":circuit_reports.duplicate(true),"production_mode":production_mode,"reports":reports.duplicate(true),"joined":joined,"qualified":qualified,"qualification":qualification.duplicate(true),"extra_qualifications":extra_qualifications.duplicate(true),"supplies":supplies.duplicate(true),"feed":feed,"products":products.duplicate(true),"job":job.duplicate(true),"serial":serial,"shipment_serial":shipment_serial,"retired_planet":retired_planet.duplicate(true),"v2":v2.serialize()}

func restore(data,state) -> bool:
	if not data is Dictionary or not Count.count_ok(data.get("version")) or int(data.version) not in [1,2,3,4,5,6,7,8,9,10,11]: return false
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
	if data.version<6:
		if not data.get("supplies") is Dictionary or data.supplies.size()!=12: return false
		data.supplies.habitat_bridge_kit=0; data.supplies.shade_kit=0
	if data.version<7:
		if not data.get("supplies") is Dictionary or data.supplies.size()!=14: return false
		for id in ["generator_kit","gasoline_feed","recovery_kit","repair_kit","industrial_feed","copper_wire_kit","aluminum_wire_kit","copper_wire_mass_kit","aluminum_wire_mass_kit"]: data.supplies[id]=0
		data.circuit_reports={}
	if data.version<8:
		if not data.get("supplies") is Dictionary or data.supplies.size()!=23: return false
		for id in config.supplies:
			if not data.supplies.has(id): data.supplies[id]=0
	if not data.get("circuit_reports") is Dictionary or data.circuit_reports.size()>2: return false
	for mode in data.circuit_reports:
		if not electrical.valid_report(data.circuit_reports[mode],str(mode)) or data.get("joined")!=true: return false
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
		var stock=0 if info.has("natural_inputs") else (int(data.feed) if info.input=="feed" else int(data.supplies[info.input]))
		if stock>=int(config.workshop.inventory_limit): return false
		for key in ["left","duration"]:
			if not (data.job.get(key) is int or data.job.get(key) is float) or not is_finite(float(data.job[key])): return false
		# Work already paid for retains its quoted duration and fee after balance updates.
		if float(data.job.duration)<=0 or float(data.job.duration)>86400 or float(data.job.left)<=0 or float(data.job.left)>float(data.job.duration): return false
		if not Count.count_ok(data.job.get("fee")) or int(data.job.fee)>1000000: return false
	var archive=preload("res://scripts/player_materials.gd").new()
	if int(data.version)>=9 and not archive.restore(data.get("materials"),state): return false
	var factory=preload("res://scripts/laminate_workshop.gd").new()
	if int(data.version)>=10 and not factory.restore(data.get("laminates"),archive.designs): return false
	if not data.joined and (not archive.records.is_empty() or not archive.designs.is_empty()): return false
	var retired=Legacy.new()
	if not retired.restore(data.get("retired_planet",{}) if int(data.version)>=11 else data.get("worlds")): return false
	if not data.job.is_empty(): ids.append(int(data.job.id))
	for component in retired.components():
		if not _valid_product(component,data,ids): return false
		ids.append(int(component.id))
	if not data.joined and (int(data.feed)>0 or not data.products.is_empty() or not data.job.is_empty()): return false
	if not data.joined:
		for n in data.supplies.values():
			if int(n)>0: return false
	for id in archive.designs:
		if archive.designs[id].basis=="family_model" and int(factory.installed.get(id,0))!=int(retired.family_receipts().get(id,0)): return false
	for id in retired.family_receipts():
		if not archive.designs.has(id) or archive.designs[id].basis!="family_model" or int(factory.installed.get(id,0))!=int(retired.family_receipts()[id]): return false
	if not data.joined and (factory.purchased.Cu>0 or factory.purchased.Al>0 or not factory.job.is_empty()): return false
	var restored_v2=PlanetV2.new()
	if data.has("v2") and not restored_v2.restore(data.v2): return false
	for craft_id in restored_v2.field.crafts:
		if int(craft_id)>=int(data.serial): return false
		var craft=restored_v2.field.crafts[craft_id]
		if not craft.complete and (str(int(data.job.get("id",-1)))!=craft_id or data.job.get("recipe")!=craft.recipe or data.production_mode!="island"): return false
	for source in restored_v2.construction.sources.values():
		if not _valid_product(source.product,data,ids): return false
		ids.append(int(source.product.id))
	for receipt in restored_v2.world.receipts:
		if receipt.get("kind")=="product":
			if not _valid_product(receipt.get("product"),data,ids): return false
			if receipt.use!=receipt.product.recipe: return false
			ids.append(int(receipt.product.id))
		elif receipt.get("kind")=="sample":
			if not receipt.get("batch_id") is String or receipt.batch_id.is_empty() or receipt.batch_id.length()>120: return false
			if receipt.get("reference") not in ["water","oxygen"] or receipt.use!="sample_"+receipt.reference: return false
			if not receipt.get("work") is Dictionary or not state.sandbox_validate(receipt.work): return false
			if state.sandbox_reference(receipt.work).get("reference_id","")!=receipt.reference: return false
		else: return false
	laminates=factory; materials=archive; retired_planet=retired.data
	production_mode=data.production_mode
	reports=data.reports.duplicate(true)
	circuit_reports=data.circuit_reports.duplicate(true)
	joined=data.joined; qualified=data.qualified; qualification=data.qualification.duplicate(true)
	feed=int(data.feed); products=data.products.duplicate(true); job=data.job.duplicate(true)
	extra_qualifications=data.extra_qualifications.duplicate(true); supplies=data.supplies.duplicate(true)
	serial=int(data.serial); shipment_serial=int(data.shipment_serial); v2=restored_v2
	return true

func _valid_product(product,data,ids: Array) -> bool:
	if not product is Dictionary: return false
	if not Count.count_ok(product.get("id")) or int(product.id)<1 or int(product.id)>=int(data.serial) or int(product.id) in ids: return false
	var info=recipe(str(product.get("recipe","")))
	if info.is_empty(): return false
	if info.has("natural_inputs"):
		var world_data=data.get("v2",{})
		if not world_data is Dictionary or not world_data.get("field") is Dictionary or not world_data.field.get("crafts") is Dictionary or not data.get("job") is Dictionary: return false
		var record=world_data.field.crafts.get(str(int(product.id)),{})
		if not record is Dictionary or record.get("recipe")!=info.id: return false
		var in_progress=data.get("job",{}).get("id")==product.id
		if record.get("complete")!=not in_progress: return false
		return product.get("recipe_version")==int(info.version) and product.get("source_batch")=="river:"+str(int(product.id))
	var q=data.qualification if info.reference=="water" else data.extra_qualifications.get(info.reference,{})
	if str(info.reference).begins_with("fixture:"): q=data.reports.get(str(info.reference).trim_prefix("fixture:"),{})
	if str(info.reference).begins_with("circuit:"): q=data.circuit_reports.get(str(info.reference).trim_prefix("circuit:"),{})
	if q.is_empty() or (info.reference=="water" and not data.qualified): return false
	return product.get("recipe_version")==int(info.version) and product.get("source_batch")==str(q.batch_id)
