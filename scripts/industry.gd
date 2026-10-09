extends RefCounted
## v0.34 星锻岛 (Starforge Isle): 岛主等级 XP, 工业信用, the second island's plots and factories,
## industry items and the trade hub. Rules live in data/industry.json; everything here is pure
## state plus transactions, like the refinery (inputs are reserved when a job is queued).
const ChemIndex=preload("res://scripts/chem_index.gd")
const Model=preload("res://scripts/material_model.gd")
const Geology=preload("res://scripts/planet_geology.gd")
static var _rules: Dictionary={}
static var _formula_keys: Dictionary={}
const FACTORIES=["metal_works","polymer_works","home_studio","inorganic_works","silicon_works"]

var unlocked=false
var xp=0
## Legacy score already turned into XP; growth of the old progress keeps paying XP after unlock.
var legacy_seen=-1
var credits=0
var plots=0
var buildings: Dictionary={}   # "plot index" -> {kind, level, jobs: [{recipe, left}]}
var items: Dictionary={}       # item id -> count
var saturation: Dictionary={}  # item id -> 0..1 market saturation
var bit=""                     # equipped industry drill bit item id ("" = none)
var earned=0                   # coins earned at the trade hub
var crafted=0
## v0.35 promotion pipeline: service seconds and 延毕 per island Ⅰ person id (as strings).
var service: Dictionary={}
var delays: Dictionary={}      # id -> reason index (one 延毕 at most)
var service_init=false
## Senior staff on island Ⅱ: [{id, name, role, specialty, home, factory}]
var staff: Array=[]
var staff_serial=1
var wages=0.0                  # accrued, settled every staff.settle_seconds
var wage_clock=0.0
var arrears=0.0
var furnished: Dictionary={}   # housing plot -> furniture pieces placed there
## Trade-hub contracts and the export airship.
var contracts: Array=[]
var contract_serial=1
var board_left=0.0
var airship: Dictionary={}     # {} or {"contract": {...}, "left": seconds}
## Not saved: XP gained since the HUD last looked, for "+XP" pops.
var pending_xp=0
# v0.37 material model: lots of modelled items ({n, k: knobs, q: scatter, m: measured}; the counts in
# `items` stay authoritative and the lots always sum to them) and the knob settings per recipe.
var lots: Dictionary={}
var settings: Dictionary={}
var lot_serial=1
var solar: Array=[]            # efficiencies of panels installed on the island grid

static func rules() -> Dictionary:
	if _rules.is_empty(): _rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/industry.json"))
	return _rules

# --- 岛主等级 ------------------------------------------------------------------------------
## XP to go from rank n to n+1.
static func step(n: int) -> int:
	var r: Dictionary=rules().rank
	return int(round(float(r.base)*pow(float(n),float(r.power))))

static func rank_of(total: int) -> Dictionary:
	var n=1; var left=total
	while n<int(rules().rank.max) and left>=step(n):
		left-=step(n); n+=1
	return {"rank":n,"into":left,"need":step(n)}

func rank() -> int:
	return int(rank_of(xp).rank)

## The old progress as XP: milestones, codex stars, index finds, reactor levels, plots, refinery, gear.
static func legacy_score(state) -> int:
	var w: Dictionary=rules().rank.legacy
	var levels=0
	for r in state.reactors: levels+=int(r.get("level",0))
	return int(state.milestones_claimed.size())*int(w.milestone)+int(state.star_rewards)*int(w.codex_star)\
		+int(state.index_found.size())*int(w.index_find)+levels*int(w.reactor_level)\
		+int(state.unlocked_plot_count())*int(w.plot)+int(state.refinery.level)*int(w.refinery_level)\
		+int(state.fabricator.serial)*int(w.fabricated)\
		+int(state.planet.v2.specimens.count())*int(w.get("specimen",0))+int(state.planet.v2.specimens.biomes())*int(w.get("specimen_biome",0))\
		+int(state.planet.v2.incidents.weathered)*int(w.get("weathered",0))

## Called on tick: the first call converts old saves once; later growth of old progress adds XP.
func sync_legacy(state) -> int:
	var score=legacy_score(state)
	if legacy_seen<0: legacy_seen=score; xp+=score; return 0
	if score<=legacy_seen: return 0
	var gained=score-legacy_seen; legacy_seen=score
	return gain(gained)

func gain(amount: int) -> int:
	if amount<=0: return 0
	xp=mini(xp+amount,1000000000); pending_xp+=amount
	return amount

# --- Unlock -----------------------------------------------------------------------------------
func unlock_rows(state) -> Array:
	var u: Dictionary=rules().unlock
	return [
		_row("岛主等级",rank(),int(u.rank),"制作、研究、领取里程碑、发现新物质都会加经验"),
		_row("金币",int(state.coins),int(u.coins),"反应釜生产、交付订单"),
		_row("合金片",int(state.materials[2]),int(u.alloy),"收获产物时随机获得"),
		_row("浮岛 Ⅰ 已开拓地块",int(state.unlocked_plot_count()),int(u.home_plots),"用星砂、晶露、合金片开拓"),
		_row("精炼厂等级",int(state.refinery.level),int(u.refinery_level),"精炼厂页面升级"),
		_row("制造台作品",int(state.fabricator.serial),int(u.fabricated),"制造台：用晶体做镐头或光伏板")]

func _row(label: String,value: int,need: int,hint: String) -> Dictionary:
	return {"label":label,"value":value,"need":need,"ok":value>=need,"hint":hint}

func unlock(state) -> String:
	if unlocked: return "星锻岛已经开放"
	for row in unlock_rows(state):
		if not row.ok: return "还差：%s %d/%d" % [row.label,row.value,row.need]
	var u: Dictionary=rules().unlock
	state.coins-=float(u.coins); state.materials[2]=int(state.materials[2])-int(u.alloy)
	unlocked=true; plots=int(rules().plots.start); gain(100)
	return "星锻岛开放！光桥已连通，%d块甲板地块可以建厂" % plots

# --- 工业信用 -----------------------------------------------------------------------------------
func fuse(state,times: int=1) -> String:
	if not unlocked: return "星锻岛开放后才能兑换工业信用"
	var f: Dictionary=rules().credits.fuse; var need: Array=f.materials
	var can=times
	for i in range(3):
		if int(need[i])>0: can=mini(can,int(state.materials[i])/int(need[i]))
	if can<=0: return "需要星砂、晶露、合金片各%d份" % int(need[0])
	for i in range(3): state.materials[i]=int(state.materials[i])-int(need[i])*can
	credits=mini(credits+int(f.credits)*can,int(rules().credits.max))
	return "熔合了%d份旧建材 → 工业信用 +%d" % [can,int(f.credits)*can]

# --- Plots and buildings ----------------------------------------------------------------------
func plot_cost() -> Dictionary:
	var p: Dictionary=rules().plots; var n=plots-int(p.start)
	return {"coins":int(round(float(p.coins)*pow(float(p.growth),n))),"credits":int(round(float(p.credits)*pow(float(p.growth),n)))}

func buy_plot(state) -> String:
	if not unlocked: return "星锻岛尚未开放"
	if plots>=int(rules().plots.max): return "本版星锻岛最多%d块地" % int(rules().plots.max)
	var c=plot_cost()
	if state.coins<c.coins or credits<c.credits: return "扩建甲板需要%d金币和%d工业信用" % [c.coins,c.credits]
	state.coins-=float(c.coins); credits-=int(c.credits); plots+=1; gain(10)
	return "甲板扩建 · 现在%d块地" % plots

func power_use() -> int:
	var total=0
	for b in buildings.values(): total+=int(rules().buildings[b.kind].power)
	return total

func power_cap() -> int:
	var p: Dictionary=rules().power
	return mini(int(p.max),int(p.starter)+int(p.get("per_rank",0))*maxi(0,rank()-int(rules().unlock.rank)))+solar_power()

## v0.37: installed solar panels add (Σ efficiency / 20 %) units to the grid.
func solar_power() -> int:
	var total=0.0
	for e in solar: total+=float(e)
	return int(floor(total/float(rules().solar.power_per_eff)+0.0001))

func install_solar() -> String:
	if int(items.get("solar_panel",0))<1: return "没有太阳能板"
	if solar.size()>=int(rules().solar.max): return "岛心最多装%d块太阳能板" % int(rules().solar.max)
	var best=best_lot("solar_panel"); var lot: Dictionary=lots_of("solar_panel")[best]
	var eff=float(lot_props("solar_panel",lot).eff)
	lots.solar_panel[best].n=int(lot.n)-1
	lots.solar_panel=lots.solar_panel.filter(func(l): return int(l.n)>0)
	items.solar_panel=int(items.solar_panel)-1
	if int(items.solar_panel)<=0: items.erase("solar_panel"); lots.erase("solar_panel")
	solar.append(snappedf(eff,0.0001)); gain(10)
	return "装上一块效率 %.1f%% 的太阳能板 · 电网上限 %d" % [eff*100,power_cap()]

func licences(kind: String) -> int:
	var l: Dictionary=rules().licences
	return int(l.base)+maxi(0,(rank()-int(rules().unlock.rank))/int(l.per_ranks))

func count(kind: String) -> int:
	var n=0
	for b in buildings.values(): n+=1 if b.kind==kind else 0
	return n

func build_error(state,plot: int,kind: String) -> String:
	if not unlocked: return "星锻岛尚未开放"
	if not rules().buildings.has(kind): return "未知建筑"
	if plot<0 or plot>=plots: return "这块甲板还没扩建"
	if buildings.has(str(plot)): return "这块地上已经有工厂"
	var spec: Dictionary=rules().buildings[kind]
	if not spec.get("no_licence",false) and count(kind)>=licences(kind): return "%s的许可证已用完（每%d级岛主等级多一张）" % [spec.name,int(rules().licences.per_ranks)]
	if power_use()+int(spec.power)>power_cap(): return "岛心电网不够：需要%d，剩余%d" % [int(spec.power),power_cap()-power_use()]
	if state.coins<float(spec.cost.coins) or credits<int(spec.cost.credits): return "需要%d金币和%d工业信用" % [int(spec.cost.coins),int(spec.cost.credits)]
	return ""

func build(state,plot: int,kind: String) -> String:
	var error=build_error(state,plot,kind)
	if not error.is_empty(): return error
	var spec: Dictionary=rules().buildings[kind]
	state.coins-=float(spec.cost.coins); credits-=int(spec.cost.credits)
	buildings[str(plot)]={"kind":kind,"level":1,"jobs":[]}
	gain(int(spec.xp))
	return "%s建成！" % spec.name

func upgrade(state,plot: int) -> String:
	var b: Dictionary=buildings.get(str(plot),{})
	if b.is_empty(): return "这里没有工厂"
	var spec: Dictionary=rules().buildings[b.kind]
	if int(b.level)>=int(spec.max_level): return "%s已是最高等级" % spec.name
	var cost=int(spec.upgrade_costs[int(b.level)-1])
	if state.coins<cost: return "升级需要%d金币" % cost
	state.coins-=float(cost); b.level=int(b.level)+1; gain(20)
	return "%s升到%d级：速度+%d%%，队列%d" % [spec.name,int(b.level),int(float(spec.speed_per_level)*100*(int(b.level)-1)),queue_limit(b)]

func queue_limit(b: Dictionary) -> int:
	return int(rules().buildings[b.kind].queue_base)+int(b.level)-1

func speed(b: Dictionary,plot: int=-1) -> float:
	var base=1.0+float(rules().buildings[b.kind].speed_per_level)*(int(b.level)-1)
	return base*(1.0+staff_bonus(plot,"speed"))

# --- Evidence: the player must have made the real compound ---------------------------------
static func _keys_for(formula: String) -> Array:
	if _formula_keys.is_empty():
		for e in ChemIndex.crystals()+ChemIndex.molecules():
			var f=str(e.get("formula",""))
			if not _formula_keys.has(f): _formula_keys[f]=[]
			_formula_keys[f].append(str(e.key))
	return _formula_keys.get(formula,[])

static func has_made(state,formula: String) -> bool:
	for key in _keys_for(formula):
		if state.index_found.has(key): return true
	return false

# --- Inputs (namespaced like backpack keys) --------------------------------------------------
func available(state,key: String) -> int:
	var kind=key.get_slice(":",0); var id=key.get_slice(":",1)
	match kind:
		"el": return int(state.element_inventory.get(id,0))
		"item": return int(items.get(id,0))-(1 if id==bit else 0)
		"raw": return int(state.planet.v2.field.stock.get(id,0))
		"min": return int(state.planet.v2.nature.minerals.get(id,0))
		"batch":
			var n=0
			for b in state.storage.batches:
				if str(b.get("reference",""))==id: n+=int(b.quantity)
			return n
	return 0

func _take(state,key: String,amount: int) -> void:
	var kind=key.get_slice(":",0); var id=key.get_slice(":",1)
	match kind:
		"el": state.element_inventory[id]=int(state.element_inventory.get(id,0))-amount
		"raw": state.planet.v2.field.stock[id]=int(state.planet.v2.field.stock.get(id,0))-amount; state.planet.v2.field.revision+=1
		"min":
			var m: Dictionary=state.planet.v2.nature.minerals
			m[id]=int(m.get(id,0))-amount
			if int(m[id])<=0: m.erase(id)
		"item": take_item(id,amount)
		"batch":
			var left=amount
			for b in state.storage.batches.duplicate():
				if left<=0: break
				if str(b.get("reference",""))!=id: continue
				var use=mini(left,int(b.quantity)); state.storage.take_product(str(b.id),use); left-=use

static func input_name(state,key: String) -> String:
	var kind=key.get_slice(":",0); var id=key.get_slice(":",1)
	match kind:
		"el": return id
		"item": return str(rules().items.get(id,{}).get("name",id))
		"min": return str(Geology.info(id).get("name",id))
		"raw": return str(state.planet.v2.field.rules.resources.get(id,{}).get("name",id))
		"batch": return str(state.templates.get(id,{}).get("name",id)).get_slice(" ·",0)
	return key

func quote(state,plot: int,recipe_id: String) -> Dictionary:
	var b: Dictionary=buildings.get(str(plot),{}); var r: Dictionary=rules().recipes.get(recipe_id,{})
	if b.is_empty() or r.is_empty() or r.building!=b.kind: return {"ready":false,"message":"这座工厂不做这个"}
	for f in r.evidence:
		if not has_made(state,str(f)): return {"ready":false,"message":"先在原子工坊做出 %s（收获后记入物质索引），才知道配方" % f,"locked":true}
	if b.jobs.size()>=queue_limit(b): return {"ready":false,"message":"队列已满（%d）" % queue_limit(b)}
	var missing=[]; var ins=inputs(recipe_id)
	for key in ins:
		if available(state,key)<int(ins[key]): missing.append("%s %d/%d" % [input_name(state,key),available(state,key),int(ins[key])])
	if not missing.is_empty(): return {"ready":false,"message":"缺少："+"，".join(missing)}
	return {"ready":true,"message":"%s · %d秒" % [r.name,int(ceil(job_seconds({"recipe":recipe_id,"k":recipe_knobs(recipe_id)})/speed(b,plot)))]}

func start(state,plot: int,recipe_id: String) -> String:
	var q=quote(state,plot,recipe_id)
	if not q.ready: return q.message
	var r: Dictionary=rules().recipes[recipe_id]; var ins=inputs(recipe_id)
	var job={"recipe":recipe_id,"left":float(r.seconds)}
	var fam=str(r.get("model",""))
	if fam!="":
		var k=recipe_knobs(recipe_id)
		# Inherited knobs (the bit's carbon) come from the lots actually consumed.
		var inherit: Dictionary=Model.family(fam).get("inherit",{})
		for key in ins:
			var used=_take_lots(key,int(ins[key]),true)
			for knob in inherit:
				if key=="item:"+str(inherit[knob]) and not used.is_empty(): k[knob]=float(used.get(knob,k.get(knob,0.0)))
		job["k"]=Model.knobs(fam,k)
		job.left=job_seconds(job)
	for key in ins: _take(state,key,int(ins[key]))
	buildings[str(plot)].jobs.append(job)
	return "已投料：%s%s" % [r.name,"（%s）" % Model.knob_text(fam,job.k) if job.has("k") else ""]

## A job's length: the recipe time scaled by its knobs (glass with more soda melts faster).
func job_seconds(job: Dictionary) -> float:
	var r: Dictionary=rules().recipes[job.recipe]
	if not job.has("k") or str(r.get("model",""))=="": return float(r.seconds)
	return float(r.seconds)*Model.seconds_factor(str(r.model),job.k)

## v0.37.1: queue up to n jobs at once; stops at the queue limit or the first missing input.
func start_many(state,plot: int,recipe_id: String,n: int) -> String:
	var started=0; var last=""
	for i in range(maxi(1,n)):
		last=start(state,plot,recipe_id)
		if not last.begins_with("已投料"): break
		started+=1
	if started==0: return last
	var r: Dictionary=rules().recipes[recipe_id]
	return "已投料：%s ×%d%s" % [r.name,started,"" if started>=n else "（%s）" % quote(state,plot,recipe_id).message]

func queue_room(plot: int) -> int:
	var b: Dictionary=buildings.get(str(plot),{})
	return 0 if b.is_empty() else maxi(0,queue_limit(b)-b.jobs.size())

## Per-building loop: the recipe is re-queued whenever its inputs are there (also offline).
func set_repeat(plot: int,recipe_id: String) -> String:
	var b: Dictionary=buildings.get(str(plot),{})
	if b.is_empty(): return "这里没有工厂"
	if recipe_id!="" and rules().recipes.get(recipe_id,{}).get("building","")!=b.kind: return "这座工厂不做这个"
	if recipe_id=="": b.erase("repeat"); return "已停止循环生产"
	b["repeat"]=recipe_id
	return "循环生产：%s（原料够就自动投料，离线也继续）" % rules().recipes[recipe_id].name

func _refill(state,plot: String) -> void:
	var b: Dictionary=buildings[plot]; var rid=str(b.get("repeat",""))
	if rid=="": return
	while b.jobs.size()<queue_limit(b) and quote(state,int(plot),rid).ready: start(state,int(plot),rid)

## Recipe inputs, with knob-scaled amounts (more tin needs more tin).
func inputs(recipe_id: String) -> Dictionary:
	var r: Dictionary=rules().recipes[recipe_id]; var out: Dictionary=r.inputs.duplicate()
	var fam=str(r.get("model",""))
	if fam=="": return out
	var k=recipe_knobs(recipe_id)
	var scaled: Dictionary=Model.family(fam).get("inputs_by_knob",{})
	for key in scaled:
		var s: Dictionary=scaled[key]
		out[key]=maxi(int(s.min),int(round(float(k.get(s.knob,0.0))/float(s.per))))
	return out

func recipe_knobs(recipe_id: String) -> Dictionary:
	var fam=str(rules().recipes.get(recipe_id,{}).get("model",""))
	return Model.knobs(fam,settings.get(recipe_id,{})) if fam!="" else {}

func set_knob(recipe_id: String,knob: String,value: float) -> void:
	var fam=str(rules().recipes.get(recipe_id,{}).get("model",""))
	if fam=="" or not Model.family(fam).get("knobs",{}).has(knob): return
	var spec: Dictionary=Model.family(fam).knobs[knob]
	var k: Dictionary=settings.get(recipe_id,{}).duplicate(); k[knob]=clampf(value,float(spec.min),float(spec.max))
	settings[recipe_id]=k

# --- v0.37 Lots -------------------------------------------------------------------------------
static func modelled(id: String) -> String:
	return str(rules().items.get(id,{}).get("model",""))

func lot_score(id: String,lot: Dictionary) -> float:
	return Model.score(modelled(id),lot.k,float(lot.q))

func lot_props(id: String,lot: Dictionary) -> Dictionary:
	return Model.props(modelled(id),lot.k,float(lot.q))

func lots_of(id: String) -> Array:
	_reconcile(id)
	return lots.get(id,[])

## Adds n units with knobs k at scatter q; stacks merge when knobs and quality match to 1 %.
func _add_lot(id: String,n: int,k: Dictionary,q: float,measured: bool=false) -> void:
	if modelled(id)=="" or n<=0: return
	var list: Array=lots.get(id,[]); var qq=snappedf(q,0.01); var kk=Model.knobs(modelled(id),k)
	for knob in kk: kk[knob]=snappedf(float(kk[knob]),0.01)
	for lot in list:
		if bool(lot.m)==measured and is_equal_approx(float(lot.q),qq) and lot.k==kk: lot.n=int(lot.n)+n; lots[id]=list; return
	if list.size()>=int(Model.rules().max_lots):
		# Full: the new units join the lot closest in score.
		var best=list[0]; var s=Model.score(modelled(id),kk,qq)
		for lot in list:
			if absf(lot_score(id,lot)-s)<absf(lot_score(id,best)-s): best=lot
		best.n=int(best.n)+n; lots[id]=list; return
	list.append({"n":n,"k":kk,"q":qq,"m":measured}); lots[id]=list

## Removes n units, worst lots first (so the best bit stays equipped); returns the mean knobs used.
## `dry` only reports what would be taken.
func _take_lots(key: String,n: int,dry: bool=false,sync: bool=true) -> Dictionary:
	if not key.begins_with("item:"): return {}
	var id=key.get_slice(":",1)
	if modelled(id)=="": return {}
	if sync: _reconcile(id)
	var list: Array=lots.get(id,[]).duplicate()
	list.sort_custom(func(a,b): return lot_score(id,a)<lot_score(id,b))
	var sums={}; var taken=0; var left=n
	for lot in list:
		if left<=0: break
		var use=mini(left,int(lot.n)); left-=use; taken+=use
		if not dry: lot.n=int(lot.n)-use
		for knob in lot.k: sums[knob]=float(sums.get(knob,0.0))+float(lot.k[knob])*use
	if not dry:
		lots[id]=lots.get(id,[]).filter(func(l): return int(l.n)>0)
		if lots[id].is_empty(): lots.erase(id)
	var mean={}
	for knob in sums: mean[knob]=float(sums[knob])/maxf(1.0,float(taken))
	return mean

## Every count change for an item goes through here so lots and counts never drift apart.
func take_item(id: String,amount: int) -> void:
	_take_lots("item:"+id,amount)
	items[id]=int(items.get(id,0))-amount
	if int(items[id])<=0: items.erase(id)

## Lots always sum to the item count: missing units become a default lot, extra lot units go.
func _reconcile(id: String) -> void:
	if modelled(id)=="": return
	var have=0
	for lot in lots.get(id,[]): have+=int(lot.n)
	var want=int(items.get(id,0))
	if have<want: _add_lot(id,want-have,{},1.0)
	elif have>want: _take_lots("item:"+id,have-want,false,false)
	if want<=0: lots.erase(id)

## 材料测试台: one lot's predicted band becomes its measured value.
func measure_error(state,id: String,index: int) -> String:
	if count("test_bench")<1: return "先建一座材料测试台"
	var list=lots_of(id)
	if index<0 or index>=list.size(): return "没有这个批次"
	if bool(list[index].m): return "这个批次已经检测过"
	if state.coins<float(Model.rules().measure.coins): return "送检需要%d金币" % int(Model.rules().measure.coins)
	return ""

func measure(state,id: String,index: int) -> String:
	var error=measure_error(state,id,index)
	if not error.is_empty(): return error
	var lot: Dictionary=lots[id][index]
	state.coins-=float(Model.rules().measure.coins); gain(int(Model.rules().measure.xp))
	lots[id].remove_at(index)
	_add_lot(id,int(lot.n),lot.k,float(lot.q),true)
	return "测试台报告：%s × %d · %s" % [rules().items[id].name,int(lot.n),Model.describe(modelled(id),lot.k,float(lot.q),true)]

# --- Time ---------------------------------------------------------------------------------------
func tick(state,delta: float) -> Array:
	var notes=[]
	if not unlocked: return notes
	for key in buildings:
		_refill(state,key)
		var b: Dictionary=buildings[key]; var work=delta*speed(b,int(key))
		while work>0.0 and not b.jobs.is_empty():
			var job: Dictionary=b.jobs[0]; var used=minf(work,float(job.left))
			job.left=float(job.left)-used; work-=used
			if float(job.left)<=0.0001:
				b.jobs.pop_front(); var r: Dictionary=rules().recipes[job.recipe]
				# 研发博士: a fraction of an extra batch accumulates per finished job.
				b.yield_acc=float(b.get("yield_acc",0.0))+staff_bonus(int(key),"yield")
				var extra=0
				if float(b.yield_acc)>=1.0: extra=1; b.yield_acc=float(b.yield_acc)-1.0
				var first=true
				for id in r.outputs:
					var n=int(r.outputs[id])+(extra if first else 0); first=false
					n=mini(n,9999-int(items.get(id,0)))
					items[id]=int(items.get(id,0))+n
					if modelled(id)!="":
						_add_lot(id,n,job.get("k",{}),Model.quality(lot_serial)); lot_serial+=1
					gain(int(rules().items[id].xp)*n)
				crafted+=1; notes.append("%s出炉%s" % [r.name,"（研发博士多出一份）" if extra>0 else ""])
				_refill(state,key)
	var m: Dictionary=rules().market
	var decay=pow(0.5,delta/float(m.half_life))
	for id in saturation.keys():
		saturation[id]=float(saturation[id])*decay
		if float(saturation[id])<0.001: saturation.erase(id)
	notes.append_array(_contracts_tick(state,delta))
	return notes

# --- v0.35 Promotion pipeline (island Ⅰ → island Ⅱ) ---------------------------------------------
func _role(role: String) -> Dictionary:
	return rules().staff.roles.get(role,{})

func year_seconds() -> float:
	return float(rules().staff.year_seconds)

func need_seconds(person: Dictionary) -> float:
	var r=_role(str(person.role)); var key=str(int(person.id))
	return (float(r.get("years",0))+(1.0 if delays.has(key) else 0.0))*year_seconds()

## Live campus time only (like campus wages): every engineer and 博士生 accrues service. The first
## call after an upgrade credits existing residents with legacy years. Returns notes (延毕 news).
func serve(state,dt: float) -> Array:
	var notes=[]; var alive={}
	for p in state.campus.people:
		var r=_role(str(p.role))
		if r.is_empty(): continue
		var key=str(int(p.id)); alive[key]=true
		if not service.has(key): service[key]=float(rules().staff.legacy_years)*year_seconds() if not service_init else 0.0
		var before=float(service[key]); service[key]=minf(before+dt,100.0*year_seconds())
		var first=float(r.years)*year_seconds()
		if before<first and float(service[key])>=first and not delays.has(key) and _roll(int(p.id),float(r.delay)):
			var reasons: Array=rules().staff.delay_reasons[str(p.role)]
			delays[key]=int(posmod(int(p.id)*31+7,reasons.size()))
			notes.append("%s 延毕一年：%s" % [p.name,reasons[int(delays[key])]])
		elif before<need_seconds(p) and float(service[key])>=need_seconds(p):
			notes.append("%s 可以%s了，等你审批晋升" % [p.name,"毕业" if p.role=="doctor" else "晋升"])
	service_init=true
	for key in service.keys():
		if not alive.has(key): service.erase(key); delays.erase(key)
	_pay(state,dt)
	return notes

## A seeded, stable roll per person: the same save always gives the same 延毕.
static func _roll(id: int,chance: float) -> bool:
	var h: int=(id*2654435761)^0x5bd1e995
	h=(h^(h>>15))*2246822519
	return float(posmod(h^(h>>13),10007))/10007.0<chance

func candidates(state) -> Array:
	var result=[]
	for p in state.campus.people:
		var r=_role(str(p.role))
		if r.is_empty(): continue
		var key=str(int(p.id)); var have=float(service.get(key,0.0)); var need=need_seconds(p)
		var reason=""
		if delays.has(key): reason=str(rules().staff.delay_reasons[str(p.role)][int(delays[key])])
		result.append({"id":int(p.id),"name":str(p.name),"role":str(p.role),"from":str(r.from),"to":str(r.name),"years":have/year_seconds(),
			"need":need/year_seconds(),"ready":have>=need,"delayed":delays.has(key),"reason":reason,"progress":clampf(have/need,0,1)})
	return result

func beds() -> int:
	var total=0
	for key in buildings:
		var b: Dictionary=buildings[key]
		if b.kind=="staff_housing": total+=housing_capacity(b)
	return total

func housing_capacity(b: Dictionary) -> int:
	var spec: Dictionary=rules().buildings[b.kind]
	return int(spec.get("capacity",0))+int(spec.get("capacity_per_level",0))*(int(b.level)-1)

func _free_home() -> int:
	for key in buildings:
		var b: Dictionary=buildings[key]
		if b.kind!="staff_housing": continue
		var used=0
		for s in staff: used+=1 if int(s.home)==int(key) else 0
		if used<housing_capacity(b): return int(key)
	return -1

func promote_error(state,person_id: int) -> String:
	if not unlocked: return "星锻岛开放后才能晋升"
	var c=candidates(state).filter(func(x): return int(x.id)==person_id)
	if c.is_empty(): return "只有工程师和博士生可以晋升"
	if not c[0].ready: return "还没到年限：%.1f / %.1f 学年" % [c[0].years,c[0].need]
	if _free_home()<0: return "星锻岛没有空床位：先建或升级星锻公寓"
	return ""

## The player's approval: the person leaves island Ⅰ (a vacancy there) and moves to island Ⅱ.
func promote(state,person_id: int) -> String:
	var error=promote_error(state,person_id)
	if not error.is_empty(): return error
	var p: Dictionary=state.campus.person(person_id); var r=_role(str(p.role))
	var home=_free_home()
	staff.append({"id":staff_serial,"name":str(p.name),"role":str(p.role),"specialty":str(p.get("specialty","")),"home":home,"factory":-1})
	staff_serial+=1
	service.erase(str(person_id)); delays.erase(str(person_id))
	state.campus_dismiss(person_id)
	gain(40)
	return "已批准：%s 晋升为%s，搬进星锻公寓 · 浮岛 Ⅰ 空出一个%s岗位" % [p.name,r.name,r.from]

func assign(staff_id: int,plot: int) -> String:
	var s=_staff(staff_id)
	if s.is_empty(): return "找不到这位员工"
	if plot<0: s.factory=-1; return "%s 暂时休息" % s.name
	var b: Dictionary=buildings.get(str(plot),{})
	if b.is_empty() or b.kind not in FACTORIES: return "只能派到工厂"
	var here=staff.filter(func(x): return int(x.factory)==plot and int(x.id)!=staff_id).size()
	if here>=int(rules().staff.per_factory): return "每座工厂最多%d位高级员工" % int(rules().staff.per_factory)
	s.factory=plot
	return "%s 派到%d号地的%s" % [s.name,plot+1,rules().buildings[b.kind].name]

func _staff(staff_id: int) -> Dictionary:
	for s in staff:
		if int(s.id)==staff_id: return s
	return {}

## Speed or yield bonus of the senior staff at a factory; nothing while wages are owed.
func staff_bonus(plot: int,effect: String) -> float:
	if plot<0 or arrears>0.0: return 0.0
	var total=0.0
	for s in staff:
		if int(s.factory)!=plot: continue
		var r=_role(str(s.role))
		if str(r.effect)==effect: total+=float(r.amount)*comfort(int(s.home))
	return total

func comfort(home: int) -> float:
	var b: Dictionary=buildings.get(str(home),{})
	if b.is_empty(): return 1.0
	return 1.0+float(rules().staff.comfort_bonus)*minf(1.0,float(furnished.get(str(home),0))/float(housing_capacity(b)))

func daily_wages() -> int:
	var total=0
	for s in staff: total+=int(_role(str(s.role)).daily_pay)
	return total

func _pay(state,dt: float) -> void:
	if staff.is_empty(): return
	wages+=float(daily_wages())*dt/float(rules().staff.settle_seconds)
	wage_clock+=dt
	if wage_clock<float(rules().staff.settle_seconds): return
	wage_clock=0.0; arrears+=wages; wages=0.0
	pay_arrears(state)

func pay_arrears(state) -> String:
	if arrears<=0.0: return "没有欠薪"
	var paid=minf(arrears,maxf(0.0,state.coins)); state.coins-=paid; arrears-=paid
	if arrears<0.01: arrears=0.0
	return "已发星锻岛薪酬 %.0f 金币%s" % [paid,"；仍欠 %.0f，员工加成暂停" % arrears if arrears>0 else ""]

# --- v0.35 Furniture ----------------------------------------------------------------------------
func furnish(plot: int,id: String) -> String:
	var b: Dictionary=buildings.get(str(plot),{})
	if b.is_empty() or b.kind!="staff_housing": return "只能布置星锻公寓"
	if not rules().items.get(id,{}).has("furniture") or int(items.get(id,0))<1: return "没有这件家具"
	var n=int(furnished.get(str(plot),0))
	if n>=housing_capacity(b): return "这栋公寓已经布置满了"
	take_item(id,1)
	furnished[str(plot)]=n+1; gain(5)
	return "公寓布置了%s · 住户舒适度 %d%%" % [rules().items[id].name,int(100*(comfort(plot)-1.0)/float(rules().staff.comfort_bonus))]

## Sends a furniture piece to island Ⅰ's toolbox, where the town places it like any decoration.
func ship_home(state,id: String) -> String:
	var f: Dictionary=rules().items.get(id,{}).get("furniture",{})
	if f.is_empty() or int(items.get(id,0))<1: return "没有这件家具"
	take_item(id,1)
	state.storage.decorations[str(f.town)]=int(state.storage.decorations.get(str(f.town),0))+1
	return "%s已送回浮岛 Ⅰ 的工具箱：在建造菜单里摆到庭院" % rules().items[id].name

# --- v0.35 Contracts and the export airship ----------------------------------------------------
func makeable(state) -> Array:
	var result=[]
	for id in rules().recipes:
		var r: Dictionary=rules().recipes[id]
		if count(str(r.building))<1: continue
		if r.evidence.any(func(f): return not has_made(state,str(f))): continue
		for out in r.outputs:
			if out not in result: result.append(out)
	return result

func _contract(state) -> Dictionary:
	var C: Dictionary=rules().contracts; var pool=makeable(state)
	if pool.is_empty(): pool=["steel_ingot","pe"]
	var rng=RandomNumberGenerator.new(); rng.seed=contract_serial*7919+13
	# Buyers ask for what their story says (wants), among what the player can make today.
	var order=range(C.buyers.size()); var start=rng.randi_range(0,C.buyers.size()-1); var buyer: Dictionary=C.buyers[start]
	for i in order:
		var b: Dictionary=C.buyers[(start+i)%C.buyers.size()]
		if pool.any(func(x): return x in b.get("wants",[])): buyer=b; break
	var wanted=pool.filter(func(x): return x in buyer.get("wants",[]))
	if not wanted.is_empty(): pool=wanted
	var lines={}; var value=0
	for i in range(rng.randi_range(int(C.lines[0]),mini(int(C.lines[1]),pool.size()))):
		var id=str(pool[rng.randi_range(0,pool.size()-1)])
		if lines.has(id): continue
		var n=rng.randi_range(int(C.qty[0]),int(C.qty[1])); lines[id]=n; value+=int(rules().items[id].sell)*n
	var c={"id":contract_serial,"buyer":str(buyer.name),"story":str(buyer.story),"lines":lines,
		"coins":int(round(value*float(C.bonus))),"credits":rng.randi_range(int(C.credits[0]),int(C.credits[1])),"xp":int(value/5)}
	contract_serial+=1
	return c

func refresh_board(state) -> void:
	contracts=[]
	for i in range(int(rules().contracts.board)): contracts.append(_contract(state))
	board_left=float(rules().contracts.refresh)

func reroll(state) -> String:
	if count("trade_hub")<1: return "先建一座星港交易所"
	var cost=int(rules().contracts.reroll_credits)
	if credits<cost: return "换一批合同需要%d工业信用" % cost
	credits-=cost; refresh_board(state)
	return "合同板已刷新"

func deliver_error(id: int) -> String:
	if count("trade_hub")<1: return "先建一座星港交易所"
	if not airship.is_empty(): return "货运飞艇在途，%d秒后返航" % int(ceil(float(airship.left)))
	var c=_find_contract(id)
	if c.is_empty(): return "这份合同已经结束"
	for item in c.lines:
		var spare=int(items.get(item,0))-(1 if bit==item else 0)
		if spare<int(c.lines[item]): return "还缺%s %d/%d" % [rules().items[item].name,spare,int(c.lines[item])]
	return ""

func deliver(id: int) -> String:
	var error=deliver_error(id)
	if not error.is_empty(): return error
	var c=_find_contract(id)
	for item in c.lines: take_item(item,int(c.lines[item]))
	contracts.erase(c)
	airship={"contract":c,"left":float(rules().contracts.trip)}
	return "货已装上飞艇，飞往%s · %d秒后结算" % [c.buyer,int(rules().contracts.trip)]

func _find_contract(id: int) -> Dictionary:
	for c in contracts:
		if int(c.id)==id: return c
	return {}

func _contracts_tick(state,delta: float) -> Array:
	var notes=[]
	if count("trade_hub")<1: return notes
	if contracts.is_empty() and board_left<=0.0: refresh_board(state)
	board_left=maxf(0.0,board_left-delta)
	if board_left<=0.0: refresh_board(state); notes.append("交易所合同板刷新了")
	if not airship.is_empty():
		airship.left=float(airship.left)-delta
		if float(airship.left)<=0.0:
			var c: Dictionary=airship.contract; airship={}
			state.coins=minf(100000000.0,state.coins+float(c.coins)); credits=mini(credits+int(c.credits),int(rules().credits.max)); earned+=int(c.coins)
			gain(int(c.xp))
			notes.append("飞艇返航：%s付清合同 +%d金币 +%d信用" % [c.buyer,int(c.coins),int(c.credits)])
	return notes

# --- Trade hub ----------------------------------------------------------------------------------
func price(id: String) -> int:
	var m: Dictionary=rules().market
	var demand=maxf(float(m.floor),1.0-float(saturation.get(id,0.0)))
	return maxi(1,int(round(float(rules().items[id].sell)*demand)))

## v0.37: a modelled lot sells at its quality (better properties and a test report pay more).
func lot_price(id: String,index: int) -> int:
	var list=lots_of(id)
	if index<0 or index>=list.size(): return price(id)
	var lot: Dictionary=list[index]
	return maxi(1,int(round(float(price(id))*Model.price_factor(modelled(id),lot.k,float(lot.q),bool(lot.m)))))

func lot_spare(id: String,index: int) -> int:
	var list=lots_of(id)
	if index<0 or index>=list.size(): return 0
	return int(list[index].n)-(1 if bit==id and index==best_lot(id) else 0)

func best_lot(id: String) -> int:
	var list=lots_of(id); var best=-1
	for i in range(list.size()):
		if best<0 or float(lot_props(id,list[i]).get("edge",lot_score(id,list[i])))>float(lot_props(id,list[best]).get("edge",lot_score(id,list[best])))+0.000001: best=i
	return best

func sell(state,id: String,amount: int=1,index: int=-1) -> String:
	if count("trade_hub")<1: return "先建一座星港交易所"
	if not rules().items.has(id) or amount<1: return "没有这种工业品"
	var spare=int(items.get(id,0))-(1 if bit==id else 0)
	if index>=0: spare=lot_spare(id,index)
	if spare<amount: return "库存不足（装备中的钻头不能卖）"
	var total=0
	for i in range(amount):
		total+=lot_price(id,index) if index>=0 else price(id); saturation[id]=minf(1.0,float(saturation.get(id,0.0))+float(rules().market.per_unit))
	if index>=0:
		lots[id][index].n=int(lots[id][index].n)-amount
		lots[id]=lots[id].filter(func(l): return int(l.n)>0)
		items[id]=int(items[id])-amount
		if int(items[id])<=0: items.erase(id); lots.erase(id)
	else: take_item(id,amount)
	state.coins=minf(100000000.0,state.coins+total); earned+=total
	gain(total/int(rules().market.xp_per_coins))
	return "卖出%d件%s · +%d金币" % [amount,rules().items[id].name,total]

# --- Gear ---------------------------------------------------------------------------------------
func equip(id: String) -> String:
	if id=="": bit=""; return "已卸下工业钻头"
	if not rules().items.get(id,{}).has("gear") or int(items.get(id,0))<1: return "没有这件装备"
	bit=id; return "已装备%s：星球采掘使用刃口硬度 %.2f GPa 的钻头（最好的一批）" % [rules().items[id].name,gear_hv(id)]

## v0.37: a modelled bit cuts with its best lot's edge hardness; others keep their fixed value.
func gear_hv(id: String) -> float:
	if int(items.get(id,0))<1: return 0.0
	if modelled(id)!="":
		var best=best_lot(id)
		if best>=0: return float(lot_props(id,lots[id][best]).get("edge",0.0))
	return float(rules().items[id].gear.hv)

func bit_hv() -> float:
	if bit=="" or int(items.get(bit,0))<1: return 0.0
	return gear_hv(bit)

# --- Save ---------------------------------------------------------------------------------------
func serialize() -> Dictionary:
	for id in items.keys(): _reconcile(id)
	return {"version":3,"lots":lots.duplicate(true),"settings":settings.duplicate(true),"lot_serial":lot_serial,"solar":solar.duplicate(),"unlocked":unlocked,"xp":xp,"legacy_seen":legacy_seen,"credits":credits,"plots":plots,
		"buildings":buildings.duplicate(true),"items":items.duplicate(),"saturation":saturation.duplicate(),"bit":bit,"earned":earned,"crafted":crafted,
		"service":service.duplicate(),"delays":delays.duplicate(),"service_init":service_init,"staff":staff.duplicate(true),"staff_serial":staff_serial,
		"wages":wages,"wage_clock":wage_clock,"arrears":arrears,"furnished":furnished.duplicate(),
		"contracts":contracts.duplicate(true),"contract_serial":contract_serial,"board_left":board_left,"airship":airship.duplicate(true)}

static func _num(v,lo: float,hi: float,whole: bool=true) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi and (not whole or float(v)==floor(float(v)))

func restore(data) -> bool:
	if not data is Dictionary or not _num(data.get("version"),1,3) or not data.get("unlocked") is bool: return false
	var R=rules()
	if not _num(data.get("xp"),0,1000000000) or not _num(data.get("legacy_seen"),-1,1000000000) or not _num(data.get("credits"),0,float(R.credits.max)): return false
	if not _num(data.get("plots"),0,float(R.plots.max)) or (data.unlocked and int(data.plots)<int(R.plots.start)): return false
	if not _num(data.get("earned"),0,1e12) or not _num(data.get("crafted"),0,1e12): return false
	if not data.get("buildings") is Dictionary or not data.get("items") is Dictionary or not data.get("saturation") is Dictionary or not data.get("bit") is String: return false
	for key in data.buildings:
		var b=data.buildings[key]
		if not str(key).is_valid_int() or int(key)<0 or int(key)>=int(data.plots) or str(int(key))!=key: return false
		if not b is Dictionary or not R.buildings.has(b.get("kind")) or not b.get("jobs") is Array: return false
		if b.has("repeat") and (not b.repeat is String or R.recipes.get(b.repeat,{}).get("building","")!=b.kind): return false
		var spec: Dictionary=R.buildings[b.kind]
		if not _num(b.get("level"),1,float(spec.max_level)) or b.jobs.size()>int(spec.queue_base)+int(spec.max_level)-1: return false
		for job in b.jobs:
			if not job is Dictionary or not R.recipes.has(job.get("recipe")) or R.recipes[job.recipe].building!=b.kind: return false
			if not _num(job.get("left"),0,2.0*float(R.recipes[job.recipe].seconds),false): return false
			if job.has("k") and not _knobs_ok(job.k,str(R.recipes[job.recipe].get("model",""))): return false
	if not data.unlocked and not data.buildings.is_empty(): return false
	for id in data.items:
		if not R.items.has(id) or not _num(data.items[id],1,9999): return false
	for id in data.saturation:
		if not R.items.has(id) or not _num(data.saturation[id],0,1,false): return false
	if data.bit!="" and not R.items.get(data.bit,{}).has("gear"): return false
	var v2=int(data.version)>=2
	if v2 and not _restore_v2_ok(data,R): return false
	if int(data.version)>=3 and not _restore_v3_ok(data,R): return false
	unlocked=data.unlocked; xp=int(data.xp); legacy_seen=int(data.legacy_seen); credits=int(data.credits); plots=int(data.plots)
	buildings={}
	for key in data.buildings:
		var b=data.buildings[key]; var jobs=[]
		for job in b.jobs:
			var j={"recipe":str(job.recipe),"left":float(job.left)}
			if job.has("k"): j["k"]=Model.knobs(str(R.recipes[job.recipe].model),job.k)
			jobs.append(j)
		buildings[str(key)]={"kind":str(b.kind),"level":int(b.level),"jobs":jobs,"yield_acc":float(b.get("yield_acc",0.0))}
		if b.has("repeat"): buildings[str(key)]["repeat"]=str(b.repeat)
	items={}
	for id in data.items: items[id]=int(data.items[id])
	saturation={}
	for id in data.saturation: saturation[id]=float(data.saturation[id])
	bit=data.bit; earned=int(data.earned); crafted=int(data.crafted); pending_xp=0
	service={}; delays={}; service_init=false; staff=[]; staff_serial=1; wages=0.0; wage_clock=0.0; arrears=0.0
	furnished={}; contracts=[]; contract_serial=1; board_left=0.0; airship={}
	if v2:
		for k in data.service: service[str(k)]=float(data.service[k])
		for k in data.delays: delays[str(k)]=int(data.delays[k])
		service_init=data.service_init; staff=[]
		for s2 in data.staff: staff.append({"id":int(s2.id),"name":str(s2.name),"role":str(s2.role),"specialty":str(s2.specialty),"home":int(s2.home),"factory":int(s2.factory)})
		staff_serial=int(data.staff_serial); wages=float(data.wages); wage_clock=float(data.wage_clock); arrears=float(data.arrears)
		for k in data.furnished: furnished[str(k)]=int(data.furnished[k])
		contracts=data.contracts.duplicate(true); contract_serial=int(data.contract_serial); board_left=float(data.board_left); airship=data.airship.duplicate(true)
		for c in contracts+([airship.contract] if not airship.is_empty() else []): _normalise_contract(c)
	lots={}; settings={}; lot_serial=1; solar=[]
	if int(data.version)>=3:
		lot_serial=int(data.lot_serial)
		for e in data.get("solar",[]): solar.append(float(e))
		for id in data.lots:
			for lot in data.lots[id]: _add_lot(str(id),int(lot.n),lot.k,float(lot.q),bool(lot.m))
		for rid in data.settings:
			for knob in data.settings[rid]: set_knob(str(rid),str(knob),float(data.settings[rid][knob]))
	# Saves before v0.37 (and any drift): units without a lot become default lots.
	for id in items.keys(): _reconcile(id)
	return true

static func _knobs_ok(k,fam: String) -> bool:
	if not k is Dictionary or fam=="" or k.size()>4: return false
	var f=Model.family(fam)
	for knob in k:
		if not f.get("knobs",{}).has(knob) and not f.get("inherit",{}).has(knob): return false
		if not _num(k[knob],-1000,1000,false): return false
	return true

func _restore_v3_ok(data: Dictionary,R: Dictionary) -> bool:
	if not data.get("lots") is Dictionary or not data.get("settings") is Dictionary or not _num(data.get("lot_serial"),1,1e12): return false
	for id in data.lots:
		var fam=str(R.items.get(id,{}).get("model",""))
		if fam=="" or not data.lots[id] is Array or data.lots[id].size()>int(Model.rules().max_lots): return false
		var total=0
		for lot in data.lots[id]:
			if not lot is Dictionary or not _num(lot.get("n"),1,9999) or not lot.get("m") is bool: return false
			if not _num(lot.get("q"),0.8,1.2,false) or not _knobs_ok(lot.get("k"),fam): return false
			total+=int(lot.n)
		if total!=int(data.items.get(id,0)): return false
	for rid in data.settings:
		if not R.recipes.has(rid) or not _knobs_ok(data.settings[rid],str(R.recipes[rid].get("model",""))): return false
	if not data.get("solar",[]) is Array or data.get("solar",[]).size()>int(R.solar.max): return false
	for e in data.get("solar",[]):
		if not _num(e,0,0.5,false): return false
	return true

func _normalise_contract(c: Dictionary) -> void:
	for k in ["id","coins","credits","xp"]: c[k]=int(c[k])
	for item in c.lines.keys(): c.lines[item]=int(c.lines[item])

static func _contract_ok(c,R: Dictionary,serial: int) -> bool:
	if not c is Dictionary or not _num(c.get("id"),1,serial-1) or not c.get("buyer") is String or not c.get("story") is String or c.buyer.length()>40 or c.story.length()>200: return false
	if not c.get("lines") is Dictionary or c.lines.is_empty() or c.lines.size()>4: return false
	for item in c.lines:
		if not R.items.has(item) or not _num(c.lines[item],1,99): return false
	return _num(c.get("coins"),0,1e7) and _num(c.get("credits"),0,1000) and _num(c.get("xp"),0,1e6)

func _restore_v2_ok(data: Dictionary,R: Dictionary) -> bool:
	if not data.get("service") is Dictionary or not data.get("delays") is Dictionary or not data.get("service_init") is bool: return false
	if data.service.size()>200 or data.delays.size()>200: return false
	for k in data.service:
		if not str(k).is_valid_int() or not _num(data.service[k],0,100.0*float(R.staff.year_seconds),false): return false
	for k in data.delays:
		if not data.service.has(k) or not _num(data.delays[k],0,9): return false
	if not data.get("staff") is Array or data.staff.size()>64 or not _num(data.get("staff_serial"),1,1e9): return false
	var ids={}
	for s2 in data.staff:
		if not s2 is Dictionary or not _num(s2.get("id"),1,float(data.staff_serial)-1) or ids.has(int(s2.id)): return false
		ids[int(s2.id)]=true
		if not R.staff.roles.has(s2.get("role")) or not s2.get("name") is String or s2.name.length()>40 or not s2.get("specialty") is String or s2.specialty.length()>40: return false
		if not _num(s2.get("home"),0,999) or data.buildings.get(str(int(s2.home)),{}).get("kind")!="staff_housing": return false
		if not _num(s2.get("factory"),-1,999): return false
		if int(s2.factory)>=0 and data.buildings.get(str(int(s2.factory)),{}).get("kind") not in FACTORIES: return false
	for k in ["wages","wage_clock","arrears","board_left"]:
		if not _num(data.get(k),0,1e9,false): return false
	if not data.get("furnished") is Dictionary: return false
	for k in data.furnished:
		if data.buildings.get(str(k),{}).get("kind")!="staff_housing" or not _num(data.furnished[k],0,99): return false
	if not data.get("contracts") is Array or data.contracts.size()>int(R.contracts.board) or not _num(data.get("contract_serial"),1,1e9): return false
	for c in data.contracts:
		if not _contract_ok(c,R,int(data.contract_serial)): return false
	if not data.get("airship") is Dictionary: return false
	if not data.airship.is_empty():
		if not _contract_ok(data.airship.get("contract"),R,int(data.contract_serial)) or not _num(data.airship.get("left"),-1,float(R.contracts.trip),false): return false
	for key in data.buildings:
		if not _num(data.buildings[key].get("yield_acc",0.0),0,1,false): return false
	return true
