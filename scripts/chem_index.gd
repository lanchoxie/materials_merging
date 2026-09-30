extends RefCounted
## v0.29 chemistry index: real crystals (Materials Project) and molecules (PubChem), built offline by
## dev/chem_index/*.py and bundled; no key and no network at runtime. Matching is honest and narrow:
## - molecule "graph": the player's bond graph (elements, bonds, bond orders) equals a PubChem graph;
## - crystal "prototype": the reduced composition equals an MP entry whose space group is the ideal
##   one of the template family (rock salt Fm-3m, cubic perovskite Pm-3m);
## - crystal "composition": the reduced composition equals an MP entry; the most stable polymorph is
##   shown and the geometry is not claimed to match;
## - "isomer": same atoms as a known molecule, different connectivity (a hint, not a find).
## Everything else stays "未收录 · 假说" with no invented properties.
## State keeps only `index_found` (entry keys → true); everything else is derived.

const Reference = preload("res://scripts/sandbox_reference.gd")
const StructureSandbox = preload("res://scripts/structure_sandbox.gd")
const CRYSTALS_PATH = "res://data/chem_index/crystals.json"
const MOLECULES_PATH = "res://data/chem_index/molecules.json"
const SOURCES_PATH = "res://data/chem_index/sources.json"
## Template families whose ideal cell is a known prototype (space group number).
const PROTOTYPES = {"perovskite_abx3": 221, "baseline_sodium_chloride": 225, "baseline_lithium_fluoride": 225}
const LATTICE_CHAPTERS = ["晶体", "离子晶格"]
const FINDS = ["graph", "prototype", "composition"]
const CRYSTAL_SYSTEMS = {"Cubic": "立方", "Tetragonal": "四方", "Orthorhombic": "正交", "Hexagonal": "六方", "Trigonal": "三方", "Monoclinic": "单斜", "Triclinic": "三斜"}
const MATCH_NAMES = {"graph": "成键图完全一致", "prototype": "组成与晶型一致", "composition": "组成一致 · 晶型未比对", "isomer": "同组成的已知分子 · 连接方式不同"}
## First-find rewards (coins). Unknown structures that match the index earn this multiple of the
## exploration stipend: a real compound is worth more than a hypothesis, less than a tuned template.
const REWARD_MOLECULE = 30
const REWARD_CRYSTAL = 45
const REWARD_EXPERIMENTAL = 15
const INDEX_RATE_FACTOR = 2.0

static var _crystals: Array = []
static var _molecules: Array = []
static var _crystal_keys: Dictionary = {}
static var _molecule_keys: Dictionary = {}
static var _sources: Array = []
static var _meta: Dictionary = {}

static func _ensure() -> void:
	if not _meta.is_empty(): return
	var crystals = JSON.parse_string(FileAccess.get_file_as_string(CRYSTALS_PATH))
	var molecules = JSON.parse_string(FileAccess.get_file_as_string(MOLECULES_PATH))
	var sources = JSON.parse_string(FileAccess.get_file_as_string(SOURCES_PATH))
	_crystals = crystals.get("entries", []) if crystals is Dictionary else []
	_molecules = molecules.get("entries", []) if molecules is Dictionary else []
	_sources = sources.get("sources", []) if sources is Dictionary else []
	_meta = {"db_version": str(crystals.get("db_version", "")) if crystals is Dictionary else "", "loaded": true}
	for i in range(_crystals.size()):
		var symbols: Array = []
		for site in _crystals[i].sites: symbols.append(str(site[0]))
		var key := composition_key(symbols, [], true)
		_crystals[i]["key"] = str(_crystals[i].id)
		if not _crystal_keys.has(key): _crystal_keys[key] = []
		_crystal_keys[key].append(i)
	for i in range(_molecules.size()):
		_molecules[i]["key"] = "cid:%d" % int(_molecules[i].cid)
		var key := composition_key(_molecules[i].atoms, [], false)
		if not _molecule_keys.has(key): _molecule_keys[key] = []
		_molecule_keys[key].append(i)

static func crystals() -> Array:
	_ensure(); return _crystals

static func molecules() -> Array:
	_ensure(); return _molecules

static func sources() -> Array:
	_ensure(); return _sources

static func db_version() -> String:
	_ensure(); return str(_meta.db_version)

static func size() -> int:
	_ensure(); return _crystals.size() + _molecules.size()

## "Cl1Na1"-style key. `weights` are site occupancies (corner 1/8, face 1/2); `reduce` divides by the
## common factor, as crystal formulas are per formula unit.
static func composition_key(atoms: Array, weights: Array = [], reduce: bool = false) -> String:
	var counts := {}
	for i in range(atoms.size()):
		counts[str(atoms[i])] = float(counts.get(str(atoms[i]), 0.0)) + (float(weights[i]) if i < weights.size() else 1.0)
	if counts.is_empty(): return ""
	var scale := 1
	for m in range(1, 25):
		var whole := true
		for symbol in counts:
			if absf(float(counts[symbol]) * m - roundf(float(counts[symbol]) * m)) > 0.01: whole = false; break
		if whole: scale = m; break
	var ints := {}
	for symbol in counts: ints[symbol] = maxi(1, roundi(float(counts[symbol]) * scale))
	if reduce:
		var g := 0
		for symbol in ints: g = _gcd(g, int(ints[symbol]))
		for symbol in ints: ints[symbol] = int(ints[symbol]) / maxi(g, 1)
	var keys := ints.keys(); keys.sort()
	var out := ""
	for symbol in keys: out += "%s%d" % [symbol, int(ints[symbol])]
	return out

static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b; b = a % b; a = t
	return a

## Identify a build. `work`: atoms, bonds ([a, b, order]), and optionally periodic, occupancies,
## family and chapter (reactor templates). Returns {} when nothing in the index applies.
static func identify(work: Dictionary) -> Dictionary:
	_ensure()
	var atoms: Array = work.get("atoms", [])
	if atoms.is_empty() or str(work.get("mode", "science")) == "art": return {}
	var family := str(work.get("family", ""))
	var lattice: bool = bool(work.get("periodic", false)) or not work.get("occupancies", []).is_empty() or PROTOTYPES.has(family) or str(work.get("chapter", "")) in LATTICE_CHAPTERS
	if lattice:
		var candidates: Array = _crystal_keys.get(composition_key(atoms, work.get("occupancies", []), true), [])
		if candidates.is_empty(): return {}
		var pick := int(candidates[0])
		var how := "composition"
		for i in candidates:
			if PROTOTYPES.has(family) and int(_crystals[i].get("sg_number", 0)) == int(PROTOTYPES[family]): pick = int(i); how = "prototype"; break
		return {"kind": "crystal", "match": how, "entry": _crystals[pick], "key": str(_crystals[pick].key), "polymorphs": candidates.size()}
	var same: Array = _molecule_keys.get(composition_key(atoms), [])
	for i in same:
		var m: Dictionary = _molecules[i]
		if not Reference.match_graph(atoms, work.get("bonds", []), {"atoms": m.atoms, "bond_orders": m.bonds}).is_empty():
			return {"kind": "molecule", "match": "graph", "entry": m, "key": str(m.key), "polymorphs": 0}
	if not same.is_empty():
		return {"kind": "molecule", "match": "isomer", "entry": _molecules[int(same[0])], "key": "", "polymorphs": 0}
	return {}

static func is_find(found: Dictionary) -> bool:
	return not found.is_empty() and str(found.get("match", "")) in FINDS

static func entry_by_key(key: String) -> Dictionary:
	_ensure()
	for list in [_molecules, _crystals]:
		for e in list:
			if str(e.key) == key: return e
	return {}

## Display formula: the workshop's own spelling for molecules, MP's with subscripts for crystals.
static func formula(entry: Dictionary) -> String:
	if entry.has("cid"): return StructureSandbox.formula({"atoms": entry.atoms})
	var out := ""
	for ch in str(entry.get("formula", "")):
		out += StructureSandbox._subscript(int(ch)) if ch >= "0" and ch <= "9" else ch
	return out

static func title(entry: Dictionary) -> String:
	return "%s  %s" % [formula(entry), str(entry.name)] if entry.has("cid") else "%s  %s" % [formula(entry), str(entry.get("spacegroup", ""))]

static func stability(entry: Dictionary) -> Dictionary:
	var h := float(entry.get("e_hull", 0.0))
	if h <= 0.0005: return {"name": "热力学稳定", "color": "7de2b0"}
	if h <= 0.025: return {"name": "近稳定", "color": "c9e27d"}
	return {"name": "亚稳", "color": "f2c46d"}

static func reward(found: Dictionary) -> int:
	if found.get("kind", "") == "molecule": return REWARD_MOLECULE
	return REWARD_CRYSTAL + (REWARD_EXPERIMENTAL if bool(found.entry.get("experimental", false)) else 0)

## One line for sidebars and the workshop.
static func summary(found: Dictionary) -> String:
	if found.is_empty(): return "化学索引：未收录 · 假说（没有真实性质可引用）"
	var e: Dictionary = found.entry
	if found.match == "isomer": return "化学索引：与「%s」组成相同，但连接方式不同 · 未收录" % str(e.name)
	if found.kind == "molecule": return "化学索引：%s %s · PubChem CID %d · %s" % [formula(e), str(e.name), int(e.cid), MATCH_NAMES.graph]
	return "化学索引：%s %s · %s · %s%s" % [formula(e), str(e.spacegroup), str(e.id), MATCH_NAMES[found.match], " · %d 种已知晶型" % int(found.polymorphs) if int(found.polymorphs) > 1 else ""]

## Record a find on `state.index_found`; returns the gift text ("" when nothing new). `pay` false
## settles old saves without a windfall.
static func record(state, found: Dictionary, pay: bool = true) -> String:
	if not is_find(found) or state.index_found.has(str(found.key)): return ""
	if state.index_found.size() >= 4096: return ""
	state.index_found[str(found.key)] = true
	if not pay: return ""
	var coins := reward(found)
	state.coins = minf(100000000.0, float(state.coins) + coins)
	return "化学索引新收录 %s +%d 金币" % [formula(found.entry), coins]

## Property rows [label, value] for an entry; missing values are "未测", never guessed.
static func properties(entry: Dictionary) -> Array:
	if entry.has("cid"):
		var rows := [["分子式", formula(entry)], ["分子量", "%.3f g/mol" % float(entry.weight)], ["IUPAC 名称", str(entry.get("iupac", "")) if not str(entry.get("iupac", "")).is_empty() else "未收录"], ["原子数", "%d（含氢）" % entry.atoms.size()], ["油水分配 XLogP", "%.1f" % float(entry.xlogp) if entry.has("xlogp") else "未测"], ["几何来源", "PubChem 三维构象" if str(entry.get("geometry", "")) == "3d" else "PubChem 二维结构（坐标仅示意）"]]
		if "formal_charges" in entry.get("notes", []): rows.append(["备注", "PubChem 以形式电荷表示；游戏不模拟形式电荷"])
		if "radical" in entry.get("notes", []): rows.append(["备注", "自由基（含未成对电子）"])
		return rows
	var gap := "金属（无带隙）" if bool(entry.get("metal", false)) or float(entry.get("band_gap", 0.0)) <= 0.0 else "%.2f eV · %s带隙（DFT 常低估）" % [float(entry.band_gap), "直接" if bool(entry.get("direct_gap", false)) else "间接"]
	return [
		["空间群", "%s（%d 号）" % [str(entry.spacegroup), int(entry.sg_number)]],
		["晶系", str(CRYSTAL_SYSTEMS.get(str(entry.crystal_system), entry.crystal_system))],
		["晶胞", "%d 个原子 · %.1f Å³" % [int(entry.nsites), float(entry.volume)]],
		["密度", "%.2f g/cm³" % float(entry.density)],
		["带隙", gap],
		["形成能", "%.3f eV/原子" % float(entry.e_form) if entry.get("e_form") != null else "未测"],
		["距凸包能", "%.3f eV/原子 · %s" % [float(entry.e_hull), stability(entry).name]],
		["磁性", "有磁性" if bool(entry.get("magnetic", false)) else "无磁性"],
		["体模量", "%.1f GPa" % float(entry.bulk_gpa) if entry.has("bulk_gpa") else "未测"],
		["剪切模量", "%.1f GPa" % float(entry.shear_gpa) if entry.has("shear_gpa") else "未测"],
		["实验观测", "是 · ICSD 收录 %d 条" % int(entry.icsd) if bool(entry.get("experimental", false)) else "否 · 仅计算预测"]]

static func source_line(entry: Dictionary) -> String:
	if entry.has("cid"): return "来源：PubChem CID %d（NCBI）· pubchem.ncbi.nlm.nih.gov/compound/%d" % [int(entry.cid), int(entry.cid)]
	return "来源：Materials Project %s（数据库 %s，CC BY 4.0）· DFT 计算值" % [str(entry.id), db_version()]

## How the player could make it (real routes in this game only).
static func how_to_build(entry: Dictionary) -> String:
	if entry.has("cid"): return "在「结构工坊」按 PubChem 的连接画出全部 %d 个原子（包括氢）和键级，应用到反应炉即可识别。" % entry.atoms.size()
	return "在「结构工坊」打开周期模式，按这个组成放入原子；岩盐型与钙钛矿型也可以在原子工作台里做元素替换得到。"

## Entries containing every symbol in `need` (all when empty), molecules or crystals.
static func filtered(kind: String, need: Array, found_only: bool, state = null) -> Array:
	var out: Array = []
	for e in (molecules() if kind == "molecule" else crystals()):
		var symbols: Dictionary = {}
		if e.has("cid"):
			for s in e.atoms: symbols[str(s)] = true
		else:
			for s in str(e.chemsys).split("-"): symbols[s] = true
		var ok := true
		for s in need:
			if not symbols.has(str(s)): ok = false; break
		if ok and found_only and (state == null or not state.index_found.has(str(e.key))): ok = false
		if ok: out.append(e)
	return out

static func found_count(state, kind: String = "") -> int:
	var n := 0
	for key in state.index_found:
		if kind.is_empty() or (kind == "molecule") == str(key).begins_with("cid:"): n += 1
	return n
