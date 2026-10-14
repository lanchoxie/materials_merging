extends SceneTree
## v0.51 (user: 在一堆元素和工业品里找自己能做的东西会很无助 / 需要类似 LoL 的树杈状可合成面板 /
## 对于元素的淬炼也要告诉玩家从哪些里面提取): the guide walks the real recipe data to answer what
## you can make, what you still need, which building is missing, and where each element comes from.
const State=preload("res://scripts/lab_state.gd")
const Guide=preload("res://scripts/craft_guide.gd")
const Geology=preload("res://scripts/planet_geology.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func all_nodes(n: Dictionary,out: Array=[]) -> Array:
	out.append(n)
	for c in n.get("children",[]): all_nodes(c,out)
	return out

func _initialize() -> void:
	var s=State.new(); s.coins=1000000
	var g=Guide.new(); g.setup(s)
	# --- A deep chain: glass needs a building the player has not built, and the tree says so.
	var glass=g.node("item:glass")
	check(glass.name=="钠钙玻璃板" and glass.status=="building","glass is blocked on a building (%s)" % glass.status)
	check(glass.detail.contains("无机材料厂") and glass.detail.contains("金币"),"the reason names the building and its cost: "+str(glass.detail))
	var leaves=all_nodes(glass).filter(func(n): return n.status=="mine")
	check(not leaves.is_empty() and all_nodes(glass).size()>=5,"the tree walks down to the ore (%d leaves, %d nodes)" % [leaves.size(),all_nodes(glass).size()])
	var sand=leaves.filter(func(n): return n.key=="min:sand")
	check(not sand.is_empty() and sand[0].detail.contains("采掘镐"),"an ore leaf says how to dig it: "+str(sand[0].detail if not sand.is_empty() else ""))
	# --- Once the building exists and the ore is in the bag, the same tree flips to "can make".
	var v=s.planet.v2
	v.nature.minerals["sand"]=99; v.nature.minerals["limestone"]=99; v.nature.minerals["halite"]=99
	s.refinery.tick(s,60)   # extractors top up Na and Cl
	s.element_inventory["Na"]=99; s.element_inventory["Cl"]=99
	# Stand the plant up directly: `build()` also checks licences, power and deck furniture.
	s.industry.buildings["0"]={"kind":"inorganic_works","level":1,"jobs":[]}
	var again=Guide.new(); again.setup(s)
	var ready_glass=again.node("item:glass")
	check(ready_glass.status=="missing" or ready_glass.status=="make","with the plant and the ore, glass is no longer blocked on a building (%s: %s)" % [ready_glass.status,ready_glass.detail])
	# --- Locked recipes say which experiment unlocks them, not just "locked".
	s.industry.buildings["1"]={"kind":"chip_fab","level":1,"jobs":[]}
	var chip=again.node("item:led_chip")
	var found_lock=all_nodes(chip).filter(func(n): return n.status=="locked")
	check(not found_lock.is_empty() and str(found_lock[0].detail).contains("原子工坊"),"a locked recipe names the experiment to run: "+str(found_lock[0].detail if not found_lock.is_empty() else ""))
	# --- Element sourcing: Cs is the hard one, and it must say exactly where to dig.
	var sources=again.element_sources("Cs")
	check(sources.size()>=2,"caesium lists both its ore and its process (%d)" % sources.size())
	var ore=sources.filter(func(x): return x.kind=="mineral")
	check(not ore.is_empty() and str(ore[0].name).contains("铯榴石") and str(ore[0].note).contains("花岗岩"),"it names 铯榴石 and the layer: "+str(ore[0].note if not ore.is_empty() else ""))
	check(again.element_guide("Cs").contains("铯榴石") and again.element_guide("Cs").contains("用于"),"the one-line guide says the ore and a use: "+again.element_guide("Cs"))
	var uses=again.element_uses("Cs")
	check(uses.size()>=1 and str(uses[0].name).contains("LED"),"Cs's only consumer is named: "+str(uses[0] if not uses.is_empty() else {}))
	check(again.element_uses("Fe").size()>=1 and again.element_guide("Fe").contains("赤铁矿"),"iron reads the same way: "+again.element_guide("Fe"))
	check(again.element_guide("H").contains("自动产出"),"an element from an extractor says so: "+again.element_guide("H"))
	# --- Every element in the game has an answer (no dead ends for the player).
	var missing=[]
	for symbol in s.elements:
		if again.element_guide(symbol)=="暂无来源": missing.append(symbol)
	check(missing.is_empty(),"every element has a source (%s)" % str(missing))
	for symbol in s.elements:
		check(not again.element_sources(symbol).is_empty(),"%s has at least one source" % symbol)
	# --- The v0.51 caesium fix: pollucite is reachable where the player digs, and there is a bulk run.
	var band={}
	for y in range(-24,-8):
		var hits=0
		for x in range(0,40):
			for z in range(0,40):
				if Geology.natural(Vector3i(x,y,z),1.0,false)=="pollucite": hits+=1
		band[y]=hits
	var shallow=0
	for y in range(-13,-9): shallow+=int(band.get(y,0))
	check(shallow>0,"pollucite is now reachable from −12 m, not only below −17 m (%s)" % str(band))
	var deep=0
	for y in band: deep+=int(band[y])
	check(deep>0,"and it still exists (%d cells in a 40×40 column test)" % deep)
	var bulk=s.refinery.rules().processes.get("pollucite_bulk",{})
	check(not bulk.is_empty() and int(bulk.outputs.get("Cs",0))==16 and int(bulk.inputs.get("pollucite",0))==4,"a bulk caesium run exists (4 ore → 16 Cs)")
	check(s.refinery.rules().processes.has("pollucite_bulk") and s.refinery.quote(s,"pollucite_bulk").has("ready"),"and the refinery offers it")
	if failures.is_empty(): print("CRAFT GUIDE OK (%d checks)" % checks); quit(0)
	else: print("CRAFT GUIDE FAILED: ",failures); quit(1)
