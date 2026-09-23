extends RefCounted
## User-authorized transactions. Simulation never gets access to the player's stock.
static func command(state,action: String,p: Dictionary) -> String:
	var v=state.planet.v2; var r=v.ranch
	if not v.active: return "请先进入星球"
	if action=="v2_ranch_water": return water(state,p)
	if action=="v2_ranch_transfer":
		var item=str(p.get("item","")); var amount=p.get("amount",0)
		if item not in r.ITEMS or item=="water" or not amount is int or amount not in [-5,-1,1,5]: return "请选择1份或5份物资"
		var available=int(v.world.seeds) if item=="seed" else (int(v.world.food) if item=="ration" else int(v.field.stock.get(item,0)))
		if amount>0 and available<amount: return "背包数量不足，未转移物资"
		if amount<0 and r.depot[item]<-amount: return "公共仓库数量不足"
		if r.depot[item]+amount>r.rules.depot_capacity: return "公共仓库已满"
		if amount<0 and item not in ["seed","ration"] and available-amount>v.field.rules.max_stock: return "背包已满"
		r.depot[item]+=amount
		if item=="seed": v.world.seeds-=amount
		elif item=="ration": v.world.food-=amount
		else: v.field.stock[item]-=amount
		r.revision+=1; v.field.revision+=1
		return "已存入公共仓库" if amount>0 else "已取回自己的背包"
	if action=="v2_ranch_empty":
		var key=str(p.get("key","")); r.sync(v)
		if not r.facilities.has(key): return "这个设施已不存在"
		var f=r.facilities[key]; var spec=r.rules.facilities[f.kind]
		if r.depot[spec.item]+f.stock>r.rules.depot_capacity: return "先清出公共仓库空间"
		if f.integrity<0.999 and v.field.stock[spec.repair]<1: return "翻修后才能收回构件；背包需1份"+str(v.field.rules.resources[spec.repair].name)
		if f.integrity<0.999: v.field.stock[spec.repair]-=1
		r.depot[spec.item]+=f.stock; f.stock=0; f.integrity=1.0
		for j in r.jobs.values():
			if j.target==key: j.stage="return"; j.target=""
		r.sync(v); r.revision+=1; v.field.revision+=1
		return "储料已回公共仓库，设施已翻修；现在可以拆回或微缩"
	if action=="v2_ranch_trade":
		var target=v.Target.query(v)
		if not target.has("entity") or target.entity.type!="visitor": return "请走近并瞄准旅行商人"
		var e=target.entity; var l=r.life(e.key)
		if v.combat.busy(e.key) or l.get("trust",0)<0: return "这位旅人仍在警惕你，暂不交易"
		var used=int(r.trades.get(e.key,0)); var spec=r.rules.trade
		if used>=int(spec.stock_per_visit): return "这次带来的树种已经换完了"
		if v.field.stock.grain<int(spec.grain_cost): return "需要背包中的2份谷穗"
		if v.nature.seeds.pine+spec.pine_seeds>v.nature.rules.max_seed_stock: return "松树种子存放已满"
		v.field.stock.grain-=int(spec.grain_cost); v.nature.seeds.pine+=int(spec.pine_seeds)
		r.trades[e.key]=used+1; r.revision+=1; v.field.revision+=1
		r.remember(l,"你与我交换过谷穗和树种")
		return "交出2份谷穗，得到1颗松树种子；这位旅人本次余货%d" % (int(spec.stock_per_visit)-used-1)
	return "未知村庄操作"

static func water(state,p: Dictionary,key: String="") -> String:
	var program=state.planet; var v=program.v2; var r=v.ranch; r.sync(v)
	if not v.active: return "请先进入星球"
	if key.is_empty():
		if r.depot.water>=r.rules.depot_capacity: return "公共仓库饮水已满"
	else:
		if r.facilities.get(key,{}).get("kind")!="trough": return "请瞄准饮水槽"
		if r.facilities[key].stock>=r.rules.facilities.trough.capacity: return "饮水槽已经装满"
	var token=p.get("token")
	if not (token is int or token is float) or token!=program.shipment_serial: return "这份水已经处理"
	if p.has("batch_id"):
		var batch=state.storage.batch(str(p.batch_id))
		if batch.is_empty() or state.sandbox_reference(batch.work).get("reference_id")!="water": return "需要反应釜产出的已识别水样"
		if not state.storage.take_product(batch.id,1): return "这份水样已用完"
	else:
		var index=-1
		for i in range(program.products.size()):
			if program.products[i].id==p.get("product_id") and program.products[i].recipe=="standard_water_crate": index=i; break
		if index<0: return "请选择一份现有水样或工艺车间制作的标准水箱"
		program.products.remove_at(index)
	program.shipment_serial+=1; r.revision+=1
	if not key.is_empty(): return r.fill(key,"water",v)
	r.depot.water+=1
	return "已消耗1份水，存为公共饮水；农夫会拿去浇地或补充饮水槽"
