extends RefCounted
## Isolated specimens share the sandbox graph resolver; template labels are not chemistry.
const Reference = preload("res://scripts/sandbox_reference.gd")

static func reference_id(base_id: String, atoms: Array, templates: Dictionary) -> String:
	if not templates.has(base_id): return ""
	var base: Dictionary = templates[base_id]
	if atoms.size() != base.atoms.size(): return ""
	for key in templates:
		var candidate: Dictionary = templates[key]
		if base.has("cell"):
			if candidate.get("family",key) == base.get("family",base_id) and atoms == candidate.atoms: return key
		elif not candidate.has("cell") and not Reference.match_graph(atoms,base.get("bond_orders",[]),candidate).is_empty():
			return key
	return ""

static func describe(base_id: String, atoms: Array, templates: Dictionary, elements: Dictionary) -> Dictionary:
	var base: Dictionary = templates[base_id]
	if not base.has("cell"):
		return Reference.describe({"atoms":atoms,"positions":base.positions,"bonds":base.get("bond_orders",[]),"mode":"science","periodic":false},templates,elements)
	var reference: String = reference_id(base_id,atoms,templates)
	var info: Dictionary = templates[reference if not reference.is_empty() else base_id].duplicate(true)
	info["known"] = not reference.is_empty()
	info["reference_id"] = reference
	if info.known:
		if atoms != info.atoms and atoms.size() == 2:
			info.atom_contexts.reverse()
			info.positions.reverse()
	else:
		info.name = "等待研究的探索样品"
		info.formula = "探索组合"
		info.description = "组成已改变，当前数据库没有适用参考。只给少量探索收益，不评价真实稳定性，也不能交付科研订单。"
		info.source = "尚无适用参考；连线沿用原模板，仅帮助编辑。"
		info.atom_contexts = []
		for symbol in atoms:
			info.atom_contexts.append({"radius":elements[symbol].radius,"radius_type":"展示尺寸；价态与配位环境待研究","oxidation_state":null,"coordination":null,"source":"暂无体系参考"})
	info.atoms = atoms.duplicate()
	return info
