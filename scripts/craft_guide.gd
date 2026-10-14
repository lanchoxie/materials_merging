extends RefCounted
## v0.51 (user: 在一堆元素和工业品里找自己能做的东西会很无助 / 需要类似 LoL 的树杈状可合成面板;
## 对于元素的淬炼也要告诉玩家从哪些里面提取): the guide that answers "what can I make, what do I
## still need, and where does each element come from".
##
## It walks the real recipe data — `industry.json` (42 recipes with their building and evidence),
## `refinery.json` (18 processes and 5 extractors) and `minerals.json` (what each ore contains) — and
## turns it into a tree of nodes. Nothing here is hand-written content: if a recipe changes, the tree
## changes with it. Every node knows what you have, what it needs, and the shortest honest reason it
## can't be made yet.
const Geology=preload("res://scripts/planet_geology.gd")

## How deep a tree can get before it stops recursing (a chain of 6 recipes is already deep).
const MAX_DEPTH=6

var state
var _rules: Dictionary={}       # industry.json
var _refinery: Dictionary={}    # refinery.json
var _minerals: Dictionary={}    # minerals.json
var _uses: Dictionary={}        # element symbol -> [{kind:"recipe"|"process", name, ...}]

func setup(model) -> void:
	state=model
	_rules=state.industry.rules()
	_refinery=JSON.parse_string(FileAccess.get_file_as_string("res://data/refinery.json"))
	_minerals=JSON.parse_string(FileAccess.get_file_as_string("res://data/minerals.json"))

# --- Names -------------------------------------------------------------------------------------
func name_of(key: String) -> String:
	var kind=key.get_slice(":",0); var id=key.get_slice(":",1)
	match kind:
		"el": return "%s %s" % [id,str(state.elements.get(id,{}).get("name",id))]
		"item": return str(_rules.items.get(id,{}).get("name",id))
		"min": return str(Geology.info(id).get("name",id))
		"raw": return str(state.planet.v2.field.rules.resources.get(id,{}).get("name",id))
		"batch": return str(state.templates.get(id,{}).get("name",id)).get_slice(" ·",0)
	return key

func have(key: String) -> int:
	return int(state.industry.available(state,key))

# --- What makes a key ---------------------------------------------------------------------------
## Every recipe or process that produces `key`, as {kind, id, name, inputs, building, evidence}.
func makers(key: String) -> Array:
	var kind=key.get_slice(":",0); var id=key.get_slice(":",1)
	var out=[]
	if kind=="item":
		for rid in _rules.recipes:
			var r: Dictionary=_rules.recipes[rid]
			if r.outputs.has(id): out.append({"kind":"recipe","id":rid,"name":str(r.name),"inputs":r.inputs,"building":str(r.building),"evidence":r.get("evidence",[]),"seconds":float(r.get("seconds",0)),"outputs":r.outputs})
	elif kind=="el":
		for pid in _refinery.processes:
			var p: Dictionary=_refinery.processes[pid]
			if p.outputs.has(id): out.append({"kind":"process","id":pid,"name":str(p.name),"inputs":_mineral_inputs(p.inputs),"outputs":p.outputs,"seconds":float(p.get("seconds",0)),"equation":str(p.get("equation",""))})
	return out

## A refinery process takes minerals; express them as min: keys so the tree can continue.
func _mineral_inputs(inputs: Dictionary) -> Dictionary:
	var out={}
	for m in inputs: out["min:"+str(m)]=int(inputs[m])
	return out

func building_of(kind: String) -> Dictionary:
	return _rules.buildings.get(kind,{})

func built_building(kind: String) -> int:
	return int(state.industry.count(kind))

# --- The tree -----------------------------------------------------------------------------------
## A node: {key,name,have,need,status,detail,children,building,building_name,evidence,seconds}
## status: "have" | "make" | "building" | "locked" | "mine" | "none"
func node(key: String,need: int=1,depth: int=0,seen: Dictionary={}) -> Dictionary:
	var at=have(key)
	var base={"key":key,"name":name_of(key),"have":at,"need":need,"children":[]}
	if at>=need: base.status="have"; return base
	if depth>=MAX_DEPTH or seen.has(key):
		base.status="none"
		base.detail="链条太深，先看看它上一层"
		return base
	var seen2=seen.duplicate(); seen2[key]=true
	var options=makers(key)
	if options.is_empty():
		# A base material: say where it is mined or gathered.
		base.status="mine"
		base.detail=source_hint(key)
		return base
	# Pick the option that is closest to buildable: one whose building exists and whose inputs are
	# mostly held; that is the one worth showing first.
	options.sort_custom(func(a,b): return _score(a,seen2)>_score(b,seen2))
	base.children=options.map(func(o): return _option_node(o,need,depth,seen2))
	var best=base.children[0]
	base.status=best.status
	base.detail=best.detail
	base.building=best.get("building","")
	base.building_name=best.get("building_name","")
	base.evidence=best.get("evidence",[])
	base.seconds=best.get("seconds",0.0)
	return base

func _option_node(o: Dictionary,need: int,depth: int,seen: Dictionary) -> Dictionary:
	var kids=[]
	var ready=true; var missing=[]
	for k in o.inputs:
		# Ask for enough: one production run needs `amount` of each input, scaled by how many runs.
		var runs=maxi(1,ceili(float(need)/maxf(1.0,float(_output_qty(o,k)))))
		var child=node(k,int(o.inputs[k])*runs,depth+1,seen)
		kids.append(child)
		if child.status!="have":
			ready=false; missing.append(child)
	var status="make"; var detail=""; var have_b=-1
	if o.kind=="recipe":
		have_b=built_building(str(o.building))
		if have_b<=0:
			status="building"
			detail="需要先建%s" % building_label(str(o.building))
		else:
			var miss=[]
			for f in o.get("evidence",[]):
				if not state.industry.has_made(state,str(f)): miss.append(str(f))
			if not miss.is_empty():
				status="locked"
				detail="先在原子工坊做出 %s，配方才会解锁" % "、".join(miss)
			elif not ready: detail="还缺 %s" % _short_list(missing)
			else: detail="材料齐了 · 在%s投料 · %.0f 秒" % [str(_rules.buildings.get(o.building,{}).get("name",o.building)),float(o.get("seconds",0))]
	else:
		if not ready: detail="还缺 %s" % _short_list(missing)
		else: detail="材料齐了 · 精炼厂「%s」· %.0f 秒" % [o.name,float(o.get("seconds",0))]
	var node_out={"key":o.id,"name":o.name,"kind":o.kind,"status":status,"detail":detail,"children":kids,
		"building":str(o.get("building","")),"building_name":str(_rules.buildings.get(o.get("building",""),{}).get("name","")),
		"evidence":o.get("evidence",[]),"seconds":float(o.get("seconds",0)),"outputs":o.outputs}
	if status=="make" and not ready: node_out.status="missing"
	if o.kind=="recipe":
		node_out.building_cost=_rules.buildings.get(o.building,{}).get("cost",{})
		node_out.building_built=have_b
	return node_out

func _output_qty(o: Dictionary,k: String) -> float:
	# How many units one run makes, used to scale the ask for a multi-run need.
	var id=""
	if k.begins_with("item:"): id=k.get_slice(":",1)
	elif k.begins_with("el:"): id=k.get_slice(":",1)
	return maxf(1.0,float(o.outputs.get(id,1)))

func building_label(kind: String) -> String:
	var b: Dictionary=building_of(kind)
	var cost: Dictionary=b.get("cost",{})
	var parts=[]
	if int(cost.get("coins",0))>0: parts.append("%d 金币" % int(cost.coins))
	if int(cost.get("credits",0))>0: parts.append("%d 工业信用" % int(cost.credits))
	return "%s（%s）" % [str(b.get("name",kind)),"＋".join(parts) if not parts.is_empty() else "无需费用"]

func _short_list(nodes: Array) -> String:
	var names=[]
	for n in nodes.slice(0,3): names.append("%s %d/%d" % [n.name,maxi(0,n.have),n.need])
	if nodes.size()>3: names.append("等 %d 项" % nodes.size())
	return "、".join(names)

## Cheapest option first: built building, then unlocked, then the most inputs already held.
func _score(o: Dictionary,seen: Dictionary) -> int:
	var s=0
	if o.kind=="recipe":
		if built_building(str(o.building))>0: s+=100
		else: s-=10
		for f in o.get("evidence",[]):
			if state.industry.has_made(state,str(f)): s+=40
			else: s-=20
	var held=0; var total=0
	for k in o.inputs:
		total+=1
		if have(k)>=int(o.inputs[k]): held+=1
	if total>0: s+=int(60.0*float(held)/float(total))
	return s

# --- Where a base material comes from -----------------------------------------------------------
func source_hint(key: String) -> String:
	var kind=key.get_slice(":",0); var id=key.get_slice(":",1)
	if kind=="min":
		var spec: Dictionary=Geology.info(id)
		var band=str(_minerals.materials.get(id,{}).get("band",""))
		return "%s%s · 用采掘镐挖%s" % [str(spec.get("layer","地下")),("（"+band+"）" if band!="" else ""),"矿脉层"]
	if kind=="raw":
		return "星球上采集：砍树、采集或种植场收获"
	if kind=="el":
		return "暂无来源"
	if kind=="batch":
		return "原子工坊制造（收割后记入物质索引）"
	return "星球 / 精炼厂"

# --- Where an element comes from, and what needs it ---------------------------------------------
## Ordered, plain-language sources for one element: every ore that contains it (with its layer),
## every refinery process that yields it, and every extractor that produces it outright.
func element_sources(symbol: String) -> Array:
	var out=[]
	for id in _refinery.extractors:
		if _refinery.extractors[id].outputs.has(symbol):
			out.append({"kind":"extractor","name":str(_refinery.extractors[id].name),"ore":"","note":"精炼厂自动产出（不需要矿石）"})
	for id in _refinery.processes:
		var p: Dictionary=_refinery.processes[id]
		if not p.outputs.has(symbol): continue
		var ores=[]
		for m in p.inputs.keys(): ores.append(str(Geology.info(m).get("name",m)))
		out.append({"kind":"process","name":str(p.name),"ore":"＋".join(ores),"note":"每炉产 %d" % int(p.outputs[symbol]),"seconds":float(p.get("seconds",0))})
	for id in _minerals.materials:
		var spec: Dictionary=_minerals.materials[id]
		var el: Dictionary=spec.get("elements",{})
		if not el.has(symbol): continue
		out.append({"kind":"mineral","name":str(spec.name),"ore":str(spec.get("formula","")),"note":"%s%s · 每块含 %d 个%s" % [str(spec.get("layer","地下")),("（"+str(spec.band)+"）" if spec.get("band","")!="" else ""),int(el[symbol]),symbol]})
	return out

## Everything that consumes this element, so an element panel can answer "what is it for".
func element_uses(symbol: String) -> Array:
	if _uses.is_empty(): _build_uses()
	return _uses.get(symbol,[])

func _build_uses() -> void:
	for rid in _rules.recipes:
		var r: Dictionary=_rules.recipes[rid]
		for k in r.inputs:
			if not k.begins_with("el:"): continue
			var sym=k.get_slice(":",1)
			if not _uses.has(sym): _uses[sym]=[]
			_uses[sym].append({"kind":"recipe","name":str(r.name),"amount":int(r.inputs[k]),"building":str(_rules.buildings.get(r.building,{}).get("name",r.building)),"output":_output_name(r.outputs)})

func _output_name(outputs: Dictionary) -> String:
	var names=[]
	for id in outputs: names.append(str(_rules.items.get(id,{}).get("name",id)))
	return "＋".join(names)

# --- A whole-element summary for the refinery tab -----------------------------------------------
## "This element, in one sentence": the ore to dig and the process to run.
func element_guide(symbol: String) -> String:
	var sources=element_sources(symbol)
	if sources.is_empty(): return "暂无来源"
	var main=""
	for s in sources:
		if s.kind=="process":
			main="%s →「%s」" % [s.ore,s.name]; break
	if main=="": return "%s（%s）" % [sources[0].name,sources[0].note]
	var uses=[]
	for u in element_uses(symbol): uses.append(str(u.name))
	var tail=""
	if not uses.is_empty(): tail="  ·  用于："+"、".join(uses.slice(0,3))+" 等"
	return main+tail
