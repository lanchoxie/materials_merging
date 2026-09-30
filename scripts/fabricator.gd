extends RefCounted
## v0.30 制造台: stored compounds that the chemistry index recognises become gear.
## - Pick heads: Vickers hardness estimated from Materials Project elastic moduli (Chen et al. 2011),
##   compared with rock hardness on the same scale (Mohs minerals measured by Broz et al. 2006).
## - Solar panels: efficiency limit from the band gap (Shockley–Queisser detailed balance); they speed up the refinery.
## Rules, sources and the efficiency table are in data/fabricator.json (built by dev/fabricator/build_rules.py).
## Missing data means the compound can't fill the role; nothing is guessed.
const ChemIndex=preload("res://scripts/chem_index.gd")
const Geology=preload("res://scripts/planet_geology.gd")
const KINDS={"pick":"镐头","panel":"太阳能板"}
static var _rules: Dictionary={}
var items: Array=[]      # {id, kind, key, formula, name, stat...}; see craft()
var pick: String=""      # equipped pick id; "" = the starter pick
var panels: Array=[]     # installed panel ids, at most rules().panel.slots
var serial: int=0

static func rules() -> Dictionary:
	if _rules.is_empty(): _rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/fabricator.json"))
	return _rules

## Mohs number → Vickers hardness (GPa), log-linear between the Broz et al. reference minerals.
static func mohs_to_hv(mohs: float) -> float:
	var table: Array=rules().mohs_reference
	if mohs<=float(table[0][0]): return float(table[0][2])
	for i in range(1,table.size()):
		if mohs<=float(table[i][0]):
			var a: Array=table[i-1]; var b: Array=table[i]
			var t=(mohs-float(a[0]))/(float(b[0])-float(a[0]))
			return exp(lerpf(log(float(a[2])),log(float(b[2])),t))
	return float(table[-1][2])

## Vickers (GPa) → Mohs-equivalent number for display; above corundum it just reads "> 9".
static func hv_to_mohs(hv: float) -> float:
	var table: Array=rules().mohs_reference
	if hv<=float(table[0][2]): return float(table[0][0])
	for i in range(1,table.size()):
		if hv<=float(table[i][2]):
			var a: Array=table[i-1]; var b: Array=table[i]
			return lerpf(float(a[0]),float(b[0]),(log(hv)-log(float(a[2])))/(log(float(b[2]))-log(float(a[2]))))
	return 9.5

static func mohs_text(hv: float) -> String:
	return "莫氏 >9" if hv>float(rules().mohs_reference[-1][2]) else "≈莫氏 %.1f" % hv_to_mohs(hv)

## A rock's Mohs number: mixtures from their main minerals, minerals from minerals.json ("6–7" → 6.5).
## Returns -1 for loose material (soil, sand, clay), which a shovel moves whatever its hardness.
static func rock_mohs(id: String) -> float:
	if id in rules().loose or id=="bedrock": return -1.0
	if rules().rock_mohs.has(id): return float(rules().rock_mohs[id].mohs)
	var text=str(Geology.info(id).get("mohs",""))
	var numbers=[]
	var rx=RegEx.create_from_string("\\d+(?:\\.\\d+)?")
	for m in rx.search_all(text.split("（")[0]): numbers.append(float(m.get_string()))
	if numbers.is_empty(): return -1.0
	return (float(numbers[0])+float(numbers[-1]))/2.0

static func rock_hv(id: String) -> float:
	var m=rock_mohs(id)
	return -1.0 if m<0.0 else mohs_to_hv(m)

## Hits needed with a pick of hardness `hv`: a pick softer than the rock slows down in proportion, up to a cap.
static func dig_hits(id: String, base: int, hv: float) -> int:
	var rock=rock_hv(id)
	if rock<=0.0 or hv>=rock or base<=0: return base
	return ceili(float(base)*minf(float(rules().pick.max_slowdown),rock/maxf(hv,0.01)))

## Elastic data an estimate may use: both moduli, and a Poisson ratio in the physical range for an isotropic solid.
static func elastic(entry: Dictionary) -> Dictionary:
	var b=float(entry.get("bulk_gpa",0.0)); var g=float(entry.get("shear_gpa",0.0))
	if b<=0.0 or g<=0.0: return {"ok":false,"reason":"没有弹性模量数据（未测）"}
	var nu=(3.0*b-2.0*g)/(2.0*(3.0*b+g))
	if nu<0.0 or nu>0.5: return {"ok":false,"reason":"弹性数据不自洽（泊松比 %.2f 超出 0–0.5），不采用" % nu}
	return {"ok":true,"bulk":b,"shear":g,"k":g/b,"nu":nu}

## Pick head stats for an index entry: {ok, hv, tough, reason}.
static func pick_stats(entry: Dictionary) -> Dictionary:
	if entry.is_empty() or entry.has("cid"): return {"ok":false,"reason":"镐头要用晶体材料，分子做不了"}
	var rule: Dictionary=rules().pick
	var elements: Array=str(entry.get("chemsys","")).split("-")
	for symbol in rule.no_alkali:
		if symbol in elements: return {"ok":false,"reason":"含碱金属 %s：遇水或空气反应，做不了工具" % symbol}
	for symbol in rule.no_anions:
		if symbol in elements: return {"ok":false,"reason":"卤化物和氢化物太软或遇水分解，做不了工具"}
	var e=elastic(entry)
	if not e.ok: return {"ok":false,"reason":e.reason}
	if float(e.k)<float(rule.min_pugh_k): return {"ok":false,"reason":"韧性很强（Pugh 比 G/B=%.2f）：硬度取决于冷锻、淬火等加工，模量推不出来" % float(e.k)}
	var hv=maxf(0.0,2.0*pow(float(e.k)*float(e.k)*float(e.shear),0.585)-3.0)
	return {"ok":true,"hv":hv,"tough":1.0/float(e.k)>1.75,"k":e.k,"bulk":e.bulk,"shear":e.shear}

## Solar panel stats: {ok, gap, efficiency, reason}; efficiency is the detailed-balance limit at the MP band gap.
static func panel_stats(entry: Dictionary) -> Dictionary:
	if entry.is_empty() or entry.has("cid"): return {"ok":false,"reason":"太阳能板要用晶体半导体，分子做不了"}
	if bool(entry.get("metal",false)): return {"ok":false,"reason":"金属没有带隙，光生电子立刻复合，发不了电"}
	var gap=float(entry.get("band_gap",0.0))
	if gap<=0.0: return {"ok":false,"reason":"没有带隙数据（未测）"}
	return {"ok":true,"gap":gap,"efficiency":sq_efficiency(gap)}

static func sq_efficiency(gap: float) -> float:
	var table: Array=rules().sq_table
	if gap<=float(table[0][0]): return float(table[0][1])*gap/float(table[0][0])
	for i in range(1,table.size()):
		if gap<=float(table[i][0]):
			var a: Array=table[i-1]; var b: Array=table[i]
			return lerpf(float(a[1]),float(b[1]),(gap-float(a[0]))/(float(b[0])-float(a[0])))
	return float(table[-1][1])

static func stats(kind: String, entry: Dictionary) -> Dictionary:
	return pick_stats(entry) if kind=="pick" else panel_stats(entry)

## One short line for a stat card.
static func stat_text(kind: String, s: Dictionary) -> String:
	if not s.ok: return str(s.reason)
	if kind=="pick": return "估算硬度 %.1f GPa（%s）· %s" % [float(s.hv),mohs_text(float(s.hv)),"偏韧" if s.tough else "偏脆"]
	return "带隙 %.2f eV → 效率上限 %.1f%%" % [float(s.gap),100.0*float(s.efficiency)]

func item(id: String) -> Dictionary:
	for it in items:
		if str(it.id)==id: return it
	return {}

func pick_hv() -> float:
	var it=item(pick)
	return float(it.hv) if not it.is_empty() else float(rules().starter_pick.hv)

func pick_name() -> String:
	var it=item(pick)
	return "%s镐" % str(it.formula) if not it.is_empty() else str(rules().starter_pick.name)

## Sum of the installed panels' efficiencies.
func power() -> float:
	var total=0.0
	for id in panels: total+=float(item(str(id)).get("efficiency",0.0))
	return total

## Extra refinery speed from the panels: speed × (1 + gain).
func refinery_gain() -> float:
	return float(rules().panel.speed_gain)*power()

## What a stored batch can become. `found` is the batch's index identification (LabState.batch_index).
func quote(state, batch_id: String, kind: String) -> Dictionary:
	var q={"ready":false,"message":"","stats":{}}
	if not KINDS.has(kind): q.message="没有这种装备"; return q
	var batch: Dictionary=state.storage.batch(batch_id)
	if batch.is_empty(): q.message="仓库里没有这批产物"; return q
	var found: Dictionary=state.batch_index(batch)
	if not ChemIndex.is_find(found): q.message="化学索引里没有这种物质：没有真实性质，做不了装备"; return q
	var s=stats(kind,found.entry); q.stats=s; q["found"]=found
	if not s.ok: q.message=str(s.reason); return q
	var rule: Dictionary=rules()[kind]
	if int(batch.quantity)<int(rule.units): q.message="需要 %d 份，这批只有 %d 份" % [int(rule.units),int(batch.quantity)]; return q
	if state.coins<float(rule.coins): q.message="加工费 %d 金币，还差 %d" % [int(rule.coins),ceili(float(rule.coins)-state.coins)]; return q
	if items.size()>=int(rules().max_items): q.message="装备架已满（%d 件），先拆掉一件" % int(rules().max_items); return q
	q.ready=true; q.message="用 %d 份 + %d 金币做一件%s：%s" % [int(rule.units),int(rule.coins),KINDS[kind],stat_text(kind,s)]
	return q

func craft(state, batch_id: String, kind: String) -> String:
	var q=quote(state,batch_id,kind)
	if not q.ready: return q.message
	var rule: Dictionary=rules()[kind]
	if not state.storage.take_product(batch_id,int(rule.units)): return "取出产物失败"
	state.coins-=float(rule.coins)
	serial+=1
	var entry: Dictionary=q.found.entry
	var it={"id":"g%d" % serial,"kind":kind,"key":str(q.found.key),"formula":ChemIndex.formula(entry),"name":str(entry.get("spacegroup","")),"experimental":bool(entry.get("experimental",false))}
	if kind=="pick": it.hv=float(q.stats.hv); it.tough=bool(q.stats.tough)
	else: it.gap=float(q.stats.gap); it.efficiency=float(q.stats.efficiency)
	items.append(it)
	var extra=""
	if kind=="pick" and float(it.hv)>pick_hv(): pick=str(it.id); extra="，已换上"
	if kind=="panel" and panels.size()<int(rules().panel.slots): panels.append(str(it.id)); extra="，已装到精炼厂屋顶"
	state.sync_gear()
	return "制造台做好 %s%s：%s%s" % [it.formula,KINDS[kind],stat_text(kind,q.stats),extra]

func equip(state, id: String) -> String:
	var it=item(id)
	if id!="" and (it.is_empty() or it.kind!="pick"): return "没有这把镐"
	pick=id; state.sync_gear()
	return "换上%s：%.1f GPa（%s）" % [pick_name(),pick_hv(),mohs_text(pick_hv())]

func toggle_panel(state, id: String) -> String:
	var it=item(id)
	if it.is_empty() or it.kind!="panel": return "没有这块太阳能板"
	if id in panels: panels.erase(id)
	elif panels.size()>=int(rules().panel.slots): return "屋顶只有 %d 个板位，先拆下一块" % int(rules().panel.slots)
	else: panels.append(id)
	state.sync_gear()
	return "精炼厂供电：%d 块板，速度 +%d%%" % [panels.size(),roundi(100.0*refinery_gain())]

## Take an item apart (frees a rack slot; the material is not returned).
func scrap(state, id: String) -> String:
	var it=item(id)
	if it.is_empty(): return "没有这件装备"
	items.erase(it); panels.erase(id)
	if pick==id: pick=""
	state.sync_gear()
	return "拆掉了 %s%s" % [str(it.formula),KINDS.get(str(it.kind),"")]

func serialize() -> Dictionary:
	return {"version":1,"items":items.duplicate(true),"pick":pick,"panels":panels.duplicate(),"serial":serial}

## Validates and restores; returns false for malformed data (load then keeps defaults).
func restore(data) -> bool:
	if not data is Dictionary or int(data.get("version",0))!=1: return false
	var list=data.get("items"); var slots=data.get("panels")
	if not list is Array or list.size()>int(rules().max_items) or not slots is Array or slots.size()>int(rules().panel.slots): return false
	var ids={}
	for it in list:
		if not it is Dictionary or not KINDS.has(str(it.get("kind",""))) or not it.get("id") is String or str(it.id).length()>12 or ids.has(it.id): return false
		if not it.get("key") is String or str(it.key).length()>40 or not it.get("formula") is String or str(it.formula).length()>40: return false
		var stat="hv" if it.kind=="pick" else "efficiency"
		if not (it.get(stat) is float or it.get(stat) is int) or float(it[stat])<0.0 or float(it[stat])>200.0: return false
		ids[it.id]=it.kind
	if not data.get("pick") is String or (data.pick!="" and ids.get(data.pick,"")!="pick"): return false
	for id in slots:
		if ids.get(id,"")!="panel" or slots.count(id)>1: return false
	if not (data.get("serial") is float or data.get("serial") is int) or int(data.serial)<0: return false
	items=list.duplicate(true); pick=str(data.pick); panels=slots.duplicate(); serial=int(data.serial)
	return true
