extends RefCounted
## Adapts researched products to the shared visitor lifecycle. Owns no stock or money.
const Identity=preload("res://scripts/stable_identity.gd")
var numeric=preload("res://scripts/player_fixture.gd").new()
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/laminates.json"))
func request(id: String) -> Dictionary:
	if not rules.orders.has(id): return {}
	var terms=rules.orders[id].duplicate(true)
	return {"kind":"material","contract_id":id,"quantity":1,"name":terms.name,"story":terms.story,"short_text":terms.short_text,"vehicle":terms.vehicle,"terms":terms,"terms_hash":Identity.canonical(terms).sha256_text()}
func offers(state) -> Array:
	if not state.planet.joined or not state.planet.laminates.unlocked(state) or state.planet.laminates.cooldown>0: return []
	for v in state.market.visitors:
		if is_material(v): return []
	var result=[]
	for id in rules.orders: result.append(request(id))
	return result
func is_material(v: Dictionary) -> bool: return v.get("order",{}).get("kind","")=="material"
func valid_order(o: Dictionary) -> bool:
	if o.get("kind")!="material" or not rules.orders.has(o.get("contract_id")) or o.get("quantity")!=1: return false
	for key in ["name","story","short_text","vehicle","terms_hash"]:
		if not o.get(key) is String or o[key].is_empty() or o[key].length()>512: return false
	if o.vehicle not in ["car","bicycle","minibus"] or not o.get("terms") is Dictionary: return false
	var t=o.terms; var num=numeric
	if t.size()!=rules.orders[o.contract_id].size() or Identity.canonical(t).sha256_text()!=o.terms_hash: return false
	for key in ["name","story","short_text","vehicle"]:
		if t.get(key)!=o[key]: return false
	for key in ["target_G_W_K","max_mass_kg","max_area_m2"]:
		if not num.number(t.get(key),1e-9,1e4): return false
	if not num.number(t.get("minimum_ratio"),.01,1) or not num.number(t.get("premium_ratio"),t.minimum_ratio,1): return false
	for key in ["reward","premium_upgrades"]:
		if not preload("res://scripts/island_storage.gd").count_ok(t.get(key)) or t[key]>100000: return false
	return true
func candidates(state,v: Dictionary) -> Array:
	if not is_material(v) or not valid_order(v.order): return []
	var rows=[]; var p=state.planet
	for id in p.materials.designs:
		var d=p.materials.designs[id]
		if d.basis!="family_model": continue
		var q=p.laminates.quote(d,v.order.contract_id,v.order.terms)
		q.batch_id=id; q.name=p.laminates.model.name(d); q.quantity=p.laminates.count(id); q.known=true
		q.matching=q.payment>0; q.quality=q.ratio; q.catalysts=int(v.order.terms.premium_upgrades) if q.premium else 0
		if v.phase!="visiting": q.ready=false; q.reason="收购商正在入场" if v.phase=="arriving" else "收购商已结束采购"
		q.score=1000*int(q.ready)+100*int(q.matching)+10*int(q.premium)+q.ratio
		rows.append(q)
	rows.sort_custom(func(a,b): return a.score>b.score if a.score!=b.score else str(a.batch_id)<str(b.batch_id))
	return rows
func deliver(state,v: Dictionary,design_id: String) -> String:
	if not is_material(v) or v.phase!="visiting" or not valid_order(v.order): return "请等收购商到场后，在邮箱或气泡交付"
	var p=state.planet; var d=p.materials.designs.get(design_id,{})
	var q=p.laminates.quote(d,v.order.contract_id,v.order.terms)
	if not q.ready: return q.reason
	var result=p.laminates.deliver(state,d,v.order.contract_id,v.order.terms)
	state.deliveries+=1; state.visitor_visits+=1; state.market.leave(int(v.id),true)
	return result+"；收购商带着层芯离岛了"
