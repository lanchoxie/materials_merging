extends RefCounted
## v0.28 reactor looks: level tiers (flask → jacketed kettle → autoclave → plasma chamber)
## and the room-temperature phase of each compound (sourced in data/phases.json).
const TIERS: Array = [
	{"from": 1, "name": "玻璃反应瓶", "accent": "9dddd0", "blurb": "敞口玻璃腔，看得清每个原子"},
	{"from": 5, "name": "夹套反应釜", "accent": "e0a05a", "blurb": "铜夹套控温，侧边多了加料管"},
	{"from": 10, "name": "高压反应釜", "accent": "8fb3c9", "blurb": "钢肋加固，前面装了压力表"},
	{"from": 15, "name": "等离子反应腔", "accent": "c79bff", "blurb": "悬浮磁环约束发光等离子体"},
]
const PHASE_NAMES: Dictionary = {"solid": "固态", "liquid": "液态", "gas": "气态"}
const PHASE_COLORS: Dictionary = {"solid": "f2d9a6", "liquid": "7fc8f8", "gas": "c9f2e4"}
static var _phases: Dictionary = {}

static func tier(level: int) -> int:
	var result: int = 0
	for index in range(TIERS.size()):
		if level >= int(TIERS[index].from): result = index
	return result

static func tier_info(level: int) -> Dictionary:
	return TIERS[tier(level)]

## Level inside the current tier (1-based), shown as gold pips on the reactor.
static func tier_step(level: int) -> int:
	return level - int(TIERS[tier(level)].from) + 1

## Level at which the next look unlocks, or 0 at the top tier.
static func next_tier_level(level: int) -> int:
	var index: int = tier(level) + 1
	return int(TIERS[index].from) if index < TIERS.size() else 0

static func phases() -> Dictionary:
	if _phases.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/phases.json"))
		_phases = data.phases if data is Dictionary else {}
	return _phases

## Room-temperature phase record for a known compound, or {} for an unidentified structure.
static func phase(template_id: String) -> Dictionary:
	return phases().get(template_id, {})

static func phase_name(template_id: String) -> String:
	return PHASE_NAMES.get(str(phase(template_id).get("phase", "")), "未鉴定")

static func phase_text(template_id: String) -> String:
	var p: Dictionary = phase(template_id)
	if p.is_empty(): return "物态未鉴定 · 结构未收录"
	var parts: Array = []
	if p.get("sublimes", false): parts.append("%.1f °C 升华" % float(p.bp))
	else:
		if p.get("mp") != null: parts.append("熔点%s %s °C" % ["约" if p.get("approximate", false) else "", _num(p.mp)])
		if p.get("bp") != null: parts.append("沸点 %s °C" % _num(p.bp))
		elif p.get("decomposes", false): parts.append("熔化即分解")
	return "%s · %s（25 °C）" % [PHASE_NAMES[p.phase], " / ".join(parts)]

## v0.52 (user: 有些气液固还是没展示出来): a phase for structures the sourced table does not cover.
## The 17 entries in phases.json are real data; anything else used to show 未鉴定 and fill nothing, so
## a player-built crystal or molecule looked like an empty chamber. This is a clearly-labelled
## **estimate** from the geometry the player authored — never presented as measured data.
const METALS: Array = ["Li","Na","Cs","Ca","Mg","Al","Fe","Cu","Pb","Sn","Si","Zn","Ag","Au"]

static func estimate(work: Dictionary, reference_id: String="") -> Dictionary:
	if not reference_id.is_empty():
		var p: Dictionary=phase(reference_id)
		if not p.is_empty(): return {"phase":str(p.phase),"text":phase_text(reference_id),"exact":true}
	var atoms: Array=work.get("atoms",[])
	if atoms.is_empty() and work.get("struct",{}).is_empty(): return {}
	var periodic: bool=bool(work.get("periodic",false)) or not work.get("occupancies",[]).is_empty() or str(work.get("chapter",""))=="晶体"
	if periodic:
		return {"phase":"solid","text":"固态 · 晶格（按你的晶胞推测，非实测）","exact":false}
	var metals: int=0
	for symbol in atoms:
		if METALS.has(str(symbol)): metals+=1
	if atoms.is_empty(): return {}
	if metals>0:
		return {"phase":"solid","text":"固态 · 含金属（推测：金属与盐在室温下通常为固体）","exact":false}
	var n: int=atoms.size()
	if n<=6: return {"phase":"gas","text":"气态（推测：%d 个小分子，室温下多为气体）" % n,"exact":false}
	if n<=12: return {"phase":"liquid","text":"液态（推测：%d 个原子，介于气体与固体之间）" % n,"exact":false}
	return {"phase":"solid","text":"固态（推测：%d 个原子的较大分子）" % n,"exact":false}

static func _num(value) -> String:
	var v: float = float(value)
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
