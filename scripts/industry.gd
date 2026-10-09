extends RefCounted
## v0.34 星锻岛 (Starforge Isle): 岛主等级 XP, 工业信用, the second island's plots and factories,
## industry items and the trade hub. Rules live in data/industry.json; everything here is pure
## state plus transactions, like the refinery (inputs are reserved when a job is queued).
const ChemIndex=preload("res://scripts/chem_index.gd")
static var _rules: Dictionary={}
static var _formula_keys: Dictionary={}
const BUILDING_KINDS=["metal_works","polymer_works","trade_hub"]

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
## Not saved: XP gained since the HUD last looked, for "+XP" pops.
var pending_xp=0

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
		+int(state.fabricator.serial)*int(w.fabricated)

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
	return int(rules().power.starter)

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
	if count(kind)>=licences(kind): return "%s的许可证已用完（每%d级岛主等级多一张）" % [spec.name,int(rules().licences.per_ranks)]
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

func speed(b: Dictionary) -> float:
	return 1.0+float(rules().buildings[b.kind].speed_per_level)*(int(b.level)-1)

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
		"item": return int(items.get(id,0))
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
		"item":
			items[id]=int(items.get(id,0))-amount
			if int(items[id])<=0: items.erase(id)
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
		"batch": return str(state.templates.get(id,{}).get("name",id)).get_slice(" ·",0)
	return key

func quote(state,plot: int,recipe_id: String) -> Dictionary:
	var b: Dictionary=buildings.get(str(plot),{}); var r: Dictionary=rules().recipes.get(recipe_id,{})
	if b.is_empty() or r.is_empty() or r.building!=b.kind: return {"ready":false,"message":"这座工厂不做这个"}
	for f in r.evidence:
		if not has_made(state,str(f)): return {"ready":false,"message":"先在原子工坊做出 %s（收获后记入物质索引），才知道配方" % f,"locked":true}
	if b.jobs.size()>=queue_limit(b): return {"ready":false,"message":"队列已满（%d）" % queue_limit(b)}
	var missing=[]
	for key in r.inputs:
		if available(state,key)<int(r.inputs[key]): missing.append("%s %d/%d" % [input_name(state,key),available(state,key),int(r.inputs[key])])
	if not missing.is_empty(): return {"ready":false,"message":"缺少："+"，".join(missing)}
	return {"ready":true,"message":"%s · %d秒" % [r.name,int(ceil(float(r.seconds)/speed(b)))]}

func start(state,plot: int,recipe_id: String) -> String:
	var q=quote(state,plot,recipe_id)
	if not q.ready: return q.message
	var r: Dictionary=rules().recipes[recipe_id]
	for key in r.inputs: _take(state,key,int(r.inputs[key]))
	buildings[str(plot)].jobs.append({"recipe":recipe_id,"left":float(r.seconds)})
	return "已投料：%s" % r.name

# --- Time ---------------------------------------------------------------------------------------
func tick(state,delta: float) -> Array:
	var notes=[]
	if not unlocked: return notes
	for key in buildings:
		var b: Dictionary=buildings[key]; var work=delta*speed(b)
		while work>0.0 and not b.jobs.is_empty():
			var job: Dictionary=b.jobs[0]; var used=minf(work,float(job.left))
			job.left=float(job.left)-used; work-=used
			if float(job.left)<=0.0001:
				b.jobs.pop_front(); var r: Dictionary=rules().recipes[job.recipe]
				for id in r.outputs:
					items[id]=mini(int(items.get(id,0))+int(r.outputs[id]),9999)
					gain(int(rules().items[id].xp)*int(r.outputs[id]))
				crafted+=1; notes.append("%s出炉" % r.name)
	var m: Dictionary=rules().market
	var decay=pow(0.5,delta/float(m.half_life))
	for id in saturation.keys():
		saturation[id]=float(saturation[id])*decay
		if float(saturation[id])<0.001: saturation.erase(id)
	return notes

# --- Trade hub ----------------------------------------------------------------------------------
func price(id: String) -> int:
	var m: Dictionary=rules().market
	var demand=maxf(float(m.floor),1.0-float(saturation.get(id,0.0)))
	return maxi(1,int(round(float(rules().items[id].sell)*demand)))

func sell(state,id: String,amount: int=1) -> String:
	if count("trade_hub")<1: return "先建一座星港交易所"
	if not rules().items.has(id) or amount<1: return "没有这种工业品"
	var spare=int(items.get(id,0))-(1 if bit==id else 0)
	if spare<amount: return "库存不足（装备中的钻头不能卖）"
	var total=0
	for i in range(amount):
		total+=price(id); saturation[id]=minf(1.0,float(saturation.get(id,0.0))+float(rules().market.per_unit))
	items[id]=int(items[id])-amount
	if int(items[id])<=0: items.erase(id)
	state.coins=minf(100000000.0,state.coins+total); earned+=total
	gain(total/int(rules().market.xp_per_coins))
	return "卖出%d件%s · +%d金币" % [amount,rules().items[id].name,total]

# --- Gear ---------------------------------------------------------------------------------------
func equip(id: String) -> String:
	if id=="": bit=""; return "已卸下工业钻头"
	if not rules().items.get(id,{}).has("gear") or int(items.get(id,0))<1: return "没有这件装备"
	bit=id; return "已装备%s：星球采掘使用 %.1f GPa 的钻头" % [rules().items[id].name,float(rules().items[id].gear.hv)]

func bit_hv() -> float:
	if bit=="" or int(items.get(bit,0))<1: return 0.0
	return float(rules().items[bit].gear.hv)

# --- Save ---------------------------------------------------------------------------------------
func serialize() -> Dictionary:
	return {"version":1,"unlocked":unlocked,"xp":xp,"legacy_seen":legacy_seen,"credits":credits,"plots":plots,
		"buildings":buildings.duplicate(true),"items":items.duplicate(),"saturation":saturation.duplicate(),"bit":bit,"earned":earned,"crafted":crafted}

static func _num(v,lo: float,hi: float,whole: bool=true) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi and (not whole or float(v)==floor(float(v)))

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("unlocked") is bool: return false
	var R=rules()
	if not _num(data.get("xp"),0,1000000000) or not _num(data.get("legacy_seen"),-1,1000000000) or not _num(data.get("credits"),0,float(R.credits.max)): return false
	if not _num(data.get("plots"),0,float(R.plots.max)) or (data.unlocked and int(data.plots)<int(R.plots.start)): return false
	if not _num(data.get("earned"),0,1e12) or not _num(data.get("crafted"),0,1e12): return false
	if not data.get("buildings") is Dictionary or not data.get("items") is Dictionary or not data.get("saturation") is Dictionary or not data.get("bit") is String: return false
	for key in data.buildings:
		var b=data.buildings[key]
		if not str(key).is_valid_int() or int(key)<0 or int(key)>=int(data.plots) or str(int(key))!=key: return false
		if not b is Dictionary or not R.buildings.has(b.get("kind")) or not b.get("jobs") is Array: return false
		var spec: Dictionary=R.buildings[b.kind]
		if not _num(b.get("level"),1,float(spec.max_level)) or b.jobs.size()>int(spec.queue_base)+int(spec.max_level)-1: return false
		for job in b.jobs:
			if not job is Dictionary or not R.recipes.has(job.get("recipe")) or R.recipes[job.recipe].building!=b.kind: return false
			if not _num(job.get("left"),0,float(R.recipes[job.recipe].seconds),false): return false
	if not data.unlocked and not data.buildings.is_empty(): return false
	for id in data.items:
		if not R.items.has(id) or not _num(data.items[id],1,9999): return false
	for id in data.saturation:
		if not R.items.has(id) or not _num(data.saturation[id],0,1,false): return false
	if data.bit!="" and not R.items.get(data.bit,{}).has("gear"): return false
	unlocked=data.unlocked; xp=int(data.xp); legacy_seen=int(data.legacy_seen); credits=int(data.credits); plots=int(data.plots)
	buildings={}
	for key in data.buildings:
		var b=data.buildings[key]; var jobs=[]
		for job in b.jobs: jobs.append({"recipe":str(job.recipe),"left":float(job.left)})
		buildings[str(key)]={"kind":str(b.kind),"level":int(b.level),"jobs":jobs}
	items={}
	for id in data.items: items[id]=int(data.items[id])
	saturation={}
	for id in data.saturation: saturation[id]=float(data.saturation[id])
	bit=data.bit; earned=int(data.earned); crafted=int(data.crafted); pending_xp=0
	return true
