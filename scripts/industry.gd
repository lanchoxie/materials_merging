extends RefCounted
## v0.34 星锻岛 (Starforge Isle): 岛主等级 XP, 工业信用, the second island's plots and factories,
## industry items and the trade hub. Rules live in data/industry.json; everything here is pure
## state plus transactions, like the refinery (inputs are reserved when a job is queued).
const ChemIndex=preload("res://scripts/chem_index.gd")
static var _rules: Dictionary={}
static var _formula_keys: Dictionary={}
const FACTORIES=["metal_works","polymer_works","home_studio"]

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
	return mini(int(p.max),int(p.starter)+int(p.get("per_rank",0))*maxi(0,rank()-int(rules().unlock.rank)))

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
		"raw": return str(state.planet.v2.field.rules.resources.get(id,{}).get("name",id))
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
	return {"ready":true,"message":"%s · %d秒" % [r.name,int(ceil(float(r.seconds)/speed(b,plot)))]}

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
					items[id]=mini(int(items.get(id,0))+n,9999)
					gain(int(rules().items[id].xp)*n)
				crafted+=1; notes.append("%s出炉%s" % [r.name,"（研发博士多出一份）" if extra>0 else ""])
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
	items[id]=int(items[id])-1
	if int(items[id])<=0: items.erase(id)
	furnished[str(plot)]=n+1; gain(5)
	return "公寓布置了%s · 住户舒适度 %d%%" % [rules().items[id].name,int(100*(comfort(plot)-1.0)/float(rules().staff.comfort_bonus))]

## Sends a furniture piece to island Ⅰ's toolbox, where the town places it like any decoration.
func ship_home(state,id: String) -> String:
	var f: Dictionary=rules().items.get(id,{}).get("furniture",{})
	if f.is_empty() or int(items.get(id,0))<1: return "没有这件家具"
	items[id]=int(items[id])-1
	if int(items[id])<=0: items.erase(id)
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
	for item in c.lines:
		items[item]=int(items[item])-int(c.lines[item])
		if int(items[item])<=0: items.erase(item)
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
	return {"version":2,"unlocked":unlocked,"xp":xp,"legacy_seen":legacy_seen,"credits":credits,"plots":plots,
		"buildings":buildings.duplicate(true),"items":items.duplicate(),"saturation":saturation.duplicate(),"bit":bit,"earned":earned,"crafted":crafted,
		"service":service.duplicate(),"delays":delays.duplicate(),"service_init":service_init,"staff":staff.duplicate(true),"staff_serial":staff_serial,
		"wages":wages,"wage_clock":wage_clock,"arrears":arrears,"furnished":furnished.duplicate(),
		"contracts":contracts.duplicate(true),"contract_serial":contract_serial,"board_left":board_left,"airship":airship.duplicate(true)}

static func _num(v,lo: float,hi: float,whole: bool=true) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi and (not whole or float(v)==floor(float(v)))

func restore(data) -> bool:
	if not data is Dictionary or not _num(data.get("version"),1,2) or not data.get("unlocked") is bool: return false
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
	var v2=int(data.version)>=2
	if v2 and not _restore_v2_ok(data,R): return false
	unlocked=data.unlocked; xp=int(data.xp); legacy_seen=int(data.legacy_seen); credits=int(data.credits); plots=int(data.plots)
	buildings={}
	for key in data.buildings:
		var b=data.buildings[key]; var jobs=[]
		for job in b.jobs: jobs.append({"recipe":str(job.recipe),"left":float(job.left)})
		buildings[str(key)]={"kind":str(b.kind),"level":int(b.level),"jobs":jobs,"yield_acc":float(b.get("yield_acc",0.0))}
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
