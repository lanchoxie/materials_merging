extends RefCounted
## Pure unit tests can finish the installation transaction without exercising walking.
## test_island_loop separately exercises real travel, food and scheduling end to end.
static func install(state) -> void:
	var temporary=state.campus._new_person("doctor",-1,true)
	state.campus.people.append(temporary)
	for i in range(state.reactors.size()):
		for step in range(100):
			if state.reactors[i].get("installation",{}).is_empty(): break
			state._finish_logistics([{"kind":"install","reactor":i,"person":temporary.id}])
	state.campus.people.erase(temporary)

static func same(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))<1e-10
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not same(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	return a==b

static func offer(state, template: String="water", property: String="") -> void:
	var index=0
	for i in range(state.economy.rules.orders.buyers.size()):
		if state.economy.rules.orders.buyers[i].template==template: index=i; break
	var order=state.economy.make_order(index,state.templates)
	if not property.is_empty(): order["property"]=property
	state.order=order.duplicate(true)
	state.market.serial+=1
	state.market.visitors=[{"id":state.market.serial,"slot":0,"phase":"visiting","age":0.0,"order":order}]
	state.market.clock=float(state.island_rules.visitors.arrival_interval)
