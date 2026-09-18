extends RefCounted
## Match labelled graphs, then remap all geometry references to player indices.

static func edges(bonds: Array) -> Dictionary:
	var result := {}
	for b in bonds: result["%d:%d" % [mini(int(b[0]),int(b[1])),maxi(int(b[0]),int(b[1]))]] = int(b[2])
	return result

static func edge(graph: Dictionary, a: int, b: int) -> int:
	return int(graph.get("%d:%d" % [mini(a,b),maxi(a,b)],0))

static func match_graph(atoms: Array, bonds: Array, template: Dictionary) -> Array:
	if atoms.size() != template.atoms.size() or bonds.size() != template.bond_orders.size(): return []
	var graph := edges(bonds)
	var reference := edges(template.bond_orders)
	var mapping: Array = []
	var used := {}
	var budget := [4096]
	if _search(atoms,template.atoms,graph,reference,mapping,used,budget): return mapping
	return []

static func _search(atoms: Array, target: Array, graph: Dictionary, reference: Dictionary, mapping: Array, used: Dictionary, budget: Array) -> bool:
	if mapping.size() == atoms.size(): return true
	budget[0] -= 1
	if budget[0] < 0: return false
	var i := mapping.size()
	for j in range(target.size()):
		if used.has(j) or atoms[i] != target[j]: continue
		var okay := true
		for prev in range(i):
			if edge(graph,i,prev) != edge(reference,j,int(mapping[prev])): okay = false; break
		if not okay: continue
		mapping.append(j)
		used[j] = true
		if _search(atoms,target,graph,reference,mapping,used,budget): return true
		mapping.pop_back()
		used.erase(j)
	return false

static func describe(work: Dictionary, templates: Dictionary, elements: Dictionary) -> Dictionary:
	var atoms: Array = work.atoms
	# Arbitrary PBC and art are explicitly not isolated molecular references.
	if work.get("mode","science") != "art" and not bool(work.get("periodic",false)):
		for key in templates:
			var t: Dictionary = templates[key]
			if t.has("cell"): continue
			var mapping := match_graph(atoms,work.bonds,t)
			if mapping.is_empty(): continue
			var info := t.duplicate(true)
			var inverse := {}
			info.positions = []
			info.atom_contexts = []
			for i in range(mapping.size()):
				inverse[int(mapping[i])] = i
				info.positions.append(t.positions[int(mapping[i])].duplicate())
				info.atom_contexts.append(t.atom_contexts[int(mapping[i])].duplicate(true))
			for name in ["bonds","angles","bond_orders"]:
				info[name] = []
				for entry in t.get(name,[]):
					var value: Array = entry.duplicate()
					for n in range(3 if name == "angles" else 2): value[n] = inverse[int(value[n])]
					info[name].append(value)
			info.atoms = atoms.duplicate()
			info.known = true
			info.reference_id = key
			return info
	var contexts: Array = []
	var guides: Array = []
	for s in atoms: contexts.append({"radius":elements[s].radius,"radius_type":"默认展示半径，环境未知","source":elements[s].source,"oxidation_state":null,"coordination":null})
	for b in work.bonds: guides.append([b[0],b[1],float(elements[atoms[int(b[0])]].radius)+float(elements[atoms[int(b[1])]].radius)])
	return {"name":str(work.get("name","探索作品")),"formula":"探索组合","atoms":atoms.duplicate(),"positions":work.positions.duplicate(true),"bonds":guides,"bond_orders":work.bonds.duplicate(true),"angles":[],"atom_contexts":contexts,"known":false,"reference_id":"","chapter":"创意","color":"bbbcff","description":"自创结构；暂未匹配参考。可向创意访客出售展示样品，不代表稳定性或真实物性。","source":"玩家作品，无可靠体系参考"}
