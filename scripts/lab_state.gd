extends RefCounted

const IslandStorage=preload("res://scripts/island_storage.gd")
const IslandLogistics=preload("res://scripts/island_logistics.gd")
const IslandMarket=preload("res://scripts/island_market.gd")
const PlanetProgram=preload("res://scripts/planet_program.gd")
var planet=PlanetProgram.new()
var storage=IslandStorage.new()
var logistics=IslandLogistics.new()
var market=IslandMarket.new()
var contracts=preload("res://scripts/material_contracts.gd").new()
const Refinery=preload("res://scripts/refinery.gd")
const ReactorLook=preload("res://scripts/reactor_look.gd")
## Set when a doctor's installation changes a reactor's room-temperature phase; main shows a banner.
var phase_notice: Dictionary={}
## First-time tours already shown (tour id -> true).
var coach_seen: Dictionary={}
## Off for script-driven runs (tests, screenshots) so they never touch the player's own save slot.
var default_slot_enabled: bool=true
## The 测试版 sets this to save_test.json so a test session never touches the player's save.
var save_name: String="save.json"
## v0.29 chemistry index: entries the player has made (index key -> true); see chem_index.gd.
const ChemIndex=preload("res://scripts/chem_index.gd")
var index_found: Dictionary={}
## Set on a harvest that adds a new index entry; main shows a banner.
var index_notice: Dictionary={}
## v0.30: stored compounds → gear (pick heads, solar panels); see fabricator.gd.
const Fabricator=preload("res://scripts/fabricator.gd")
var fabricator=Fabricator.new()
## v0.28: minerals → elements; replaces the coin element shop.
var refinery=Refinery.new()
var refinery_notice: String=""
## v0.34 星锻岛: 岛主等级 XP, 工业信用, island Ⅱ factories and industry items (industry.gd).
const Industry=preload("res://scripts/industry.gd")
var industry=Industry.new()
var industry_notice: String=""
var island_rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/island_balance.json"))

const CampusSim = preload("res://scripts/campus_sim.gd")
const CampusLayout = preload("res://scripts/campus_layout.gd")
const CampusPayroll = preload("res://scripts/campus_payroll.gd")
const Town = preload("res://scripts/island_town.gd")
var campus = CampusSim.new()
var layout = CampusLayout.new()
var payroll = CampusPayroll.new()
var campus_notice: String = ""
var _campus_clock: float = 0
var _production_clock: float = 0

const Economy = preload("res://scripts/economy.gd")
const Specimen = preload("res://scripts/specimen.gd")
const StructureSandbox = preload("res://scripts/structure_sandbox.gd")
const StructureStart = preload("res://scripts/structure_start.gd")
const SandboxReference = preload("res://scripts/sandbox_reference.gd")
const SciencePipeline = preload("res://scripts/science_pipeline.gd")
const Milestones = preload("res://scripts/milestones.gd")
const Codex = preload("res://scripts/codex.gd")
var economy = Economy.new()
var sandbox: RefCounted
var science: RefCounted
var sandbox_works: Array = []
var science_unlocked: Array = []
var science_runs: Array = []
var science_pending: Dictionary = {}
var _science_thread: Thread
var science_notice: String = ""
var element_inventory: Dictionary = {}
var _structure_cache: Dictionary = {}

const MAX_UNLOCKED_PLOTS = 400
const MAX_SAVED_PLOTS = 2048
const MAX_SAVE_BYTES = 33554432
const MAX_COORDINATE = 128
const CARDINAL_DIRECTIONS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# Geometry scores and all prices below are game rules, never energies or predicted properties.
var catalog: Dictionary = {}
var templates: Dictionary = {}
var elements: Dictionary = {}
var coins: float = 220.0
var materials: Array = [2, 2, 2]
var upgrades: int = 0
var engineers: int = 1
var scientists: int = 0
var crate_count: int = 0
## v0.23 goal track: ids of claimed milestones (progress itself is read from live state).
var milestones_claimed: Array = []
## Unix time of the last save; drives the capped offline catch-up.
var saved_at: int = 0
## v0.24 codex: best harvested geometry fit per reference structure, and gifts handed out.
var best_fit: Dictionary = {}
var star_rewards: int = 0
var discovered: Array = []
var plots: Array = []
var reactors: Array = []
var order: Dictionary = {}
var deliveries: int = 0
var total_harvests: int = 0
var visitor_cooldown: float = 0.0
var visitor_visits: int = 0
var visitor_skips: int = 0
var rng = RandomNumberGenerator.new()
var _dry_harvests: int = 0
var _serial: int = 1
var _town_serial: int = 1
## v0.31 undo: session-only groups of town edits (newest last). Never saved.
var town_journal: Array = []
var _town_grouping: bool = false
var _town_undoing: bool = false
const TOWN_JOURNAL_LIMIT = 40

func _init():
	market.quote_rules=island_rules.visitors
	rng.randomize()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json"))
	if parsed is Dictionary:
		catalog = parsed
		templates = catalog.get("templates", {})
		elements = catalog.get("elements", {})
	var element_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/elements.json"))
	if element_data is Dictionary:
		elements = element_data.get("elements", elements)
	sandbox = StructureSandbox.new(elements)
	science = SciencePipeline.new()
	_reset_element_inventory()
	for i in range(9):
		plots.append({"x": i % 3 - 1, "z": int(i / 3) - 1,
			"unlocked": i in [3, 4, 5, 7], "kind": "empty", "rid": -1})
	_append_frontier()
	if templates.has("water"):
		var r = _new_reactor(4, "water", 0.0)
		reactors.append(r)
		plots[4].kind = "reactor"
		plots[4].rid = 0
		discovered.append("water")
	_update_order()
	layout.initialize(plots)
	_append_frontier()
	campus.setup(engineers,scientists)
	market.spawn(economy,templates,island_rules.visitors)
	storage.finds["3"]="crystal_fox"

# --- 0.4 structure sandbox -------------------------------------------------
# Player-authored specimens are kept separate from production reactors until
# a matching science reference is explicitly added. This lets the editor be
# creative without accidentally turning an unknown structure into a sellable
# product or claiming an energy prediction.
func baseline_ids() -> Array:
	return sandbox.baseline_ids() if sandbox != null else []

func baseline_data(id: String) -> Dictionary:
	return sandbox.baseline(id) if sandbox != null else {}

func new_sandbox_structure(name: String = "未命名样品", baseline_id: String = "") -> Dictionary:
	return sandbox.new_structure(name, baseline_id) if sandbox != null else {}

func sandbox_from_baseline(id: String, name: String = "") -> Dictionary:
	return sandbox.from_baseline(id, name) if sandbox != null else {}

func sandbox_add_atom(structure: Dictionary, symbol: String, position: Array = [0.0, 0.0, 0.0]) -> int:
	return sandbox.add_atom(structure, symbol, position) if sandbox != null else -1

func sandbox_remove_atom(structure: Dictionary, index: int) -> bool:
	return sandbox.remove_atom(structure, index) if sandbox != null else false

func sandbox_set_position(structure: Dictionary, index: int, position: Array) -> bool:
	return sandbox.set_position(structure, index, position) if sandbox != null else false

func sandbox_toggle_bond(structure: Dictionary, first: int, second: int, order: int = 1) -> bool:
	return sandbox.toggle_bond(structure, first, second, order) if sandbox != null else false

func sandbox_formula(structure: Dictionary) -> String:
	return sandbox.formula(structure) if sandbox != null else "探索空笼"

func sandbox_complexity(structure: Dictionary) -> float:
	return sandbox.complexity(structure) if sandbox != null else 0.0

func sandbox_validate(structure: Dictionary) -> bool:
	return sandbox.validate(structure) if sandbox != null else false

func sandbox_saved_root() -> String:
	return save_root_for_platform(OS.get_name()) + "/structures"

func _sandbox_name_allowed(name: String) -> bool:
	var clean := name.strip_edges()
	return not clean.is_empty() and clean.length() <= 48 and clean.validate_filename() == clean and not clean.contains("..")

func _sandbox_path(name: String) -> String:
	return sandbox_saved_root() + "/" + name.strip_edges() + ".json"

func save_sandbox_structure(name: String, structure: Dictionary) -> String:
	if sandbox == null or not _sandbox_name_allowed(name) or not sandbox_validate(structure) or structure.atoms.is_empty():
		return "保存失败：名称或结构无效"
	var root := sandbox_saved_root()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) != OK:
		return "保存失败：无法创建作品库"
	var path := _sandbox_path(name)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return "保存失败：无法写入作品库"
	var record: Dictionary = sandbox.serializable(structure)
	record["name"] = name.strip_edges()
	file.store_string(JSON.stringify(record, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return "保存失败：写入未完成"
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".bak"))!=OK: return "保存失败：未能备份原作品"
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))!=OK: return "保存失败：原作品已保留"
	var replaced := false
	for i in range(sandbox_works.size()):
		if str(sandbox_works[i].get("name", "")) == name.strip_edges():
			sandbox_works[i] = record
			replaced = true
			break
	if not replaced:
		sandbox_works.append(record)
	return "作品已保存：%s · %s" % [name.strip_edges(), sandbox_formula(structure)]

func load_sandbox_structure(name: String) -> Dictionary:
	if not _sandbox_name_allowed(name):
		return {}
	var path := _sandbox_path(name)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 524288:
		if file != null: file.close()
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary or not sandbox_validate(parser.data):
		return {}
	var record: Dictionary = parser.data.duplicate(true)
	# JSON has no integer-array type guarantee; restore canonical topology values
	# so loaded works compare and edit exactly like freshly authored works.
	var canonical_bonds: Array = []
	for bond in record.get("bonds", []):
		canonical_bonds.append([int(bond[0]), int(bond[1]), int(bond[2]) if bond.size() > 2 else 1])
	record.bonds = canonical_bonds
	if not record.has("name"): record.name = name.strip_edges()
	var known := false
	for item in sandbox_works:
		if str(item.get("name", "")) == str(record.name):
			known = true
			break
	if not known: sandbox_works.append(record)
	return record

func list_sandbox_structures() -> Array:
	var result: Array = []
	var root := sandbox_saved_root()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root)):
		var dir := DirAccess.open(root)
		if dir != null:
			dir.list_dir_begin()
			var filename := dir.get_next()
			while not filename.is_empty():
				if not dir.current_is_dir() and filename.ends_with(".json"):
					var item := load_sandbox_structure(filename.trim_suffix(".json"))
					if not item.is_empty(): result.append(item)
				filename = dir.get_next()
			dir.list_dir_end()
	result.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	sandbox_works = result
	return result.duplicate(true)

func delete_sandbox_structure(name: String) -> bool:
	if not _sandbox_name_allowed(name): return false
	var path := _sandbox_path(name)
	if not FileAccess.file_exists(path): return false
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK: return false
	for i in range(sandbox_works.size() - 1, -1, -1):
		if str(sandbox_works[i].get("name", "")) == name.strip_edges(): sandbox_works.remove_at(i)
	return true

# --- 0.6 / 0.7 research progression ---------------------------------------
func reactor_work(r: Dictionary) -> Dictionary:
	if r.get("sandbox",false):
		return {"name":r.get("work_name","我的作品"),"atoms":r.atoms.duplicate(),"positions":r.positions.duplicate(true),"bonds":r.get("bonds",[]).duplicate(true),"mode":r.get("mode","science"),"periodic":r.get("periodic",false),"cell":r.get("cell_lengths",[6.0,6.0,6.0]).duplicate(),"baseline_id":""}
	var info := structure_data(r)
	return {"name":info.name,"atoms":atom_symbols(r).duplicate(),"positions":r.positions.duplicate(true),"bonds":info.get("bond_orders",[]).duplicate(true),"mode":"science","periodic":false,"cell":[6.0,6.0,6.0],"baseline_id":info.reference_id}

func sandbox_reference(work: Dictionary) -> Dictionary:
	var info := SandboxReference.describe(work,templates,elements)
	info["index"] = ChemIndex.identify(work)
	if not info.known and ChemIndex.is_find(info.index): info.formula = ChemIndex.formula(info.index.entry)
	return info

func sandbox_reactor_quote(index: int, work: Dictionary) -> Dictionary:
	var q := {"ready":false,"changed":false,"fee":0,"required":{},"message":"请选择反应炉"}
	if not _valid_index(index): return q
	if not sandbox_validate(work) or work.atoms.is_empty(): q.message="至少放一个原子；结构必须在工作台范围内"; return q
	var r: Dictionary = reactors[index]
	if float(r.build_left)>0: q.message="请等待反应炉建好"; return q
	if not r.get("installation",{}).is_empty(): q.message="已有待装炉样品，请等待博士或取消装炉"; return q
	if not storage.can_add(signature(r),int(r.pending)): q.message="工具箱批次已满，请先交付订单"; return q
	var old := reactor_work(r)
	q.changed = old.atoms != work.atoms or old.positions != work.positions or old.bonds != work.bonds or old.mode != work.get("mode","science") or old.periodic != work.get("periodic",false) or old.cell != work.get("cell",[6.0,6.0,6.0])
	if not q.changed: q.message="结构未改变，不扣费"; return q
	# Reserve existing atom species. Only net additions/replacements consume
	# inventory; removals never refund, and cannot be used to duplicate atoms.
	var available := {}
	for s in old.atoms: available[s] = int(available.get(s,0))+1
	for s in work.atoms:
		if int(available.get(s,0))>0: available[s]-=1
		else: q.required[s]=int(q.required.get(s,0))+1
	q.fee = edit_cost(r)
	q.message = "需要 %d 金币；更换组成由博士装炉，已完成产物保留" % q.fee
	if coins < q.fee: q.message="金币不足：本级固定%d金币"%q.fee; return q
	# v0.31: a new composition is installed by a doctor; coordinates alone stay free to tune.
	if old.atoms != work.atoms or old.bonds != work.bonds or old.mode != work.get("mode","science") or old.periodic != work.get("periodic",false) or old.cell != work.get("cell",[6.0,6.0,6.0]):
		var gate := install_status()
		if not gate.ok: q.message=gate.message+"（没有博士时只能微调坐标）"; return q
	var short := element_shortage(q.required)
	if not short.is_empty(): q.message=short; return q
	q.ready=true
	return q

func apply_sandbox_to_reactor(index: int, work: Dictionary) -> String:
	var q := sandbox_reactor_quote(index,work)
	if not q.ready: return q.message
	coins -= int(q.fee)
	for s in q.required: element_inventory[s] -= int(q.required[s])
	var r: Dictionary=reactors[index]
	var old=reactor_work(r)
	if old.atoms!=work.atoms or old.bonds!=work.bonds or old.mode!=work.get("mode","science") or old.periodic!=work.get("periodic",false) or old.cell!=work.get("cell",[6.0,6.0,6.0]):
		return _queue_install(r,{"kind":"sandbox","work":work.duplicate(true)},q)
	_collect(r)
	_install_sandbox(r,work)
	return "坐标已保存 · -%d金币；旧批次已收入工具箱" % q.fee

func _install_sandbox(r: Dictionary, work: Dictionary) -> void:
	r.sandbox=true
	r.work_name=str(work.get("name","我的作品")).left(48)
	r.atoms=work.atoms.duplicate()
	r.positions=work.positions.duplicate(true)
	r.bonds=work.bonds.duplicate(true)
	r.mode=str(work.get("mode","science"))
	r.periodic=bool(work.get("periodic",false))
	r.cell_lengths=work.get("cell",[6.0,6.0,6.0]).duplicate()
	_structure_cache.clear()
	_reset_product(r)

func science_method_ids() -> Array:
	return science.ids() if science != null else []

func science_method(id: String) -> Dictionary:
	return science.data(id) if science != null else {}

func science_method_unlocked(id: String) -> bool:
	return id in science_unlocked

func science_method_status(id: String, reactor_index: int = -1) -> Dictionary:
	var info: Dictionary = science_method(id)
	var result := {"id": id, "known": not info.is_empty(), "unlocked": science_method_unlocked(id), "supported": false, "message": "未知研究项目"}
	if info.is_empty(): return result
	result["scientists_required"] = int(info.requires_scientists)
	result["cost"] = int(info.cost)
	result["catalysts"] = int(info.catalysts)
	result["kind"] = str(info.kind)
	if not science_method_unlocked(id):
		result.message = "需要%d位科学家、%d金币%s" % [int(info.requires_scientists), int(info.cost), "和%d枚催化晶" % int(info.catalysts) if int(info.catalysts) > 0 else ""]
		return result
	if reactor_index < 0 or not _valid_index(reactor_index):
		result.message = "选择一台反应炉后运行研究"
		return result
	var r: Dictionary = reactors[reactor_index]
	var symbols: Array = atom_symbols(r)
	result.supported = science.supports(id, symbols) and not bool(r.get("periodic",false)) and r.get("mode","science") != "art"
	if id.begins_with("empirical_") and reference_id(r).is_empty(): result.supported=false
	result.message = "适用：%s" % ", ".join(symbols) if result.supported else "当前结构超出适用元素或原子数范围"
	return result

func unlock_science_method(id: String) -> String:
	var info: Dictionary = science_method(id)
	if info.is_empty(): return "研究项目不存在"
	if science_method_unlocked(id): return "%s已经解锁" % info.name
	if scientists < int(info.requires_scientists): return "需要至少%d位科学家" % int(info.requires_scientists)
	if coins < float(info.cost): return "解锁%s需要%d金币" % [info.name, int(info.cost)]
	if upgrades < int(info.catalysts): return "还需要%d枚精品催化晶" % int(info.catalysts)
	coins -= float(info.cost)
	upgrades -= int(info.catalysts)
	science_unlocked.append(id)
	return "%s已解锁 · 适用范围已写入研究档案" % info.name

func run_science_task(id: String, reactor_index: int) -> String:
	var status: Dictionary = science_method_status(id, reactor_index)
	if not status.known or not status.unlocked or not status.supported: return str(status.message)
	if not science_pending.is_empty(): return "研究台正在运行，请等待或取消当前任务"
	var r: Dictionary=reactors[reactor_index]
	if float(r.build_left)>0: return "请先等待反应炉建造完成"
	for record in science_runs:
		if record.get("result",{}).get("success",false) and record.get("method","")==id and record.get("signature","")==signature(r): return "已找到相同结构和方法的缓存结果，请查看研究记录"
	science_pending={"method":id,"reactor":str(r.id),"signature":signature(r),"time":Time.get_datetime_string_from_system(),"specimen":{"atoms":atom_symbols(r).duplicate(),"positions":r.positions.duplicate(true)},"reference":structure_data(r).duplicate(true)}
	_start_science_worker()
	return "已提交计算；可继续经营小岛。计算免费，应用优化结构时单独确认编辑费。"

func _start_science_worker() -> void:
	_science_thread=Thread.new()
	var error:=_science_thread.start(_compute_snapshot.bind(science_pending.duplicate(true)))
	if error!=OK:
		science_notice="无法启动计算，未扣费，请重试"
		science_pending.clear()
		_science_thread=null

func _compute_snapshot(job: Dictionary) -> Dictionary:
	return SciencePipeline.new().compute(job.method,job.specimen,job.reference)

func poll_science() -> void:
	if _science_thread==null or _science_thread.is_alive(): return
	var result = _science_thread.wait_to_finish()
	_science_thread=null
	if science_pending.is_empty(): return
	if science_pending.get("cancelled",false):
		science_pending.clear()
		science_notice="研究已取消，未修改结构"
		return
	var record:=science_pending.duplicate(true)
	record.erase("specimen")
	record.erase("reference")
	record.result=result if result is Dictionary else {"success":false,"message":"计算未能返回结果"}
	science_runs.push_front(record)
	if science_runs.size()>24: science_runs.resize(24)
	science_pending.clear()
	science_notice="研究完成，可在研究站查看曲线" if record.result.get("success",false) else "研究未收敛或超出范围；请查看研究记录"

func close_science() -> void:
	if _science_thread!=null:
		_science_thread.wait_to_finish()
		_science_thread=null

func cancel_science() -> String:
	# Worker uses immutable copies and may finish in the background; discard
	# its result rather than killing a thread during numerical computation.
	if science_pending.is_empty(): return "当前没有进行中的研究"
	science_pending.cancelled=true
	return "任务已取消，等待计算线程安全退出"

func apply_science_result(record_index: int) -> String:
	if record_index<0 or record_index>=science_runs.size(): return "记录不存在"
	var record: Dictionary=science_runs[record_index]
	var result: Dictionary=record.get("result",{})
	if not result.get("success",false) or not result.get("can_apply",false): return "这项结果不能修改三维结构"
	for i in range(reactors.size()):
		var r: Dictionary=reactors[i]
		if r.id!=record.reactor: continue
		if signature(r)!=record.signature: return "样品已变化，旧结果已过期；请重新计算"
		if r.get("sandbox",false):
			var work:=reactor_work(r)
			work.positions=result.positions.duplicate(true)
			return apply_sandbox_to_reactor(i,work)
		return apply_edit(i,result.positions)
	return "原反应炉不存在"

func science_summary() -> String:
	return "已解锁 %d / %d 项研究 · 最近完成 %d 次教学任务" % [science_unlocked.size(), science_method_ids().size(), science_runs.size()]

func _new_reactor(plot_index: int, template_id: String, build_time: float) -> Dictionary:
	var r = {"id": "R%03d" % _serial, "plot": plot_index, "template": template_id,
		"level": 1, "positions": initial_positions(template_id, "R%03d" % _serial),
		"progress": 0.0, "stock": 0, "pending": 0, "stored_coins": 0.0,
		"build_left": build_time, "signature": ""}
	r.atoms = templates[template_id].atoms.duplicate()
	_serial += 1
	r.signature = signature(r)
	return r

func initial_positions(template_id: String, reactor_id: String) -> Array:
	return StructureStart.positions(templates[template_id].positions, "reactor:" + reactor_id + ":" + template_id)

func _valid_index(index: int) -> bool:
	return index >= 0 and index < reactors.size()

func _v(point: Array) -> Vector3:
	return Vector3(float(point[0]), float(point[1]), float(point[2]))

func atom_symbols(r: Dictionary) -> Array:
	return r.get("atoms",templates[r.template].atoms)

func structure_data(r: Dictionary) -> Dictionary:
	var atoms: Array = atom_symbols(r)
	if bool(r.get("sandbox",false)):
		var work := reactor_work(r)
		var custom_key := JSON.stringify([work.atoms,work.bonds,work.mode,work.periodic,work.name])
		if not _structure_cache.has(custom_key):
			if _structure_cache.size()>256: _structure_cache.clear()
			_structure_cache[custom_key] = sandbox_reference(work)
		return _structure_cache[custom_key]
	var key: String = str(r.template) + ":" + ",".join(atoms)
	if not _structure_cache.has(key):
		# Bound the cache during long sandbox sessions.
		if _structure_cache.size() > 256: _structure_cache.clear()
		var info := Specimen.describe(r.template,atoms,templates,elements)
		var base: Dictionary = templates[r.template]
		info["index"] = ChemIndex.identify({"atoms":atoms,"bonds":info.get("bond_orders",[]),"occupancies":base.get("occupancies",[]),"family":str(base.get("family","")),"chapter":str(base.get("chapter",""))})
		if not info.known and ChemIndex.is_find(info.index):
			# Still an exploration sample for the economy, but named for what it really is.
			info.formula = ChemIndex.formula(info.index.entry)
			info.name = "%s · 化学索引收录" % (str(info.index.entry.name) if info.index.kind == "molecule" else "%s 晶体" % str(info.index.entry.spacegroup))
		_structure_cache[key] = info
	return _structure_cache[key]

func reference_id(r: Dictionary) -> String:
	return str(structure_data(r).reference_id)

func _reset_element_inventory() -> void:
	element_inventory.clear()
	for symbol in elements:
		element_inventory[symbol] = int(economy.rules.starter_elements.get(symbol,0))

func quality(r: Dictionary) -> float:
	if not templates.has(r.get("template", "")):
		return 0.0
	var template: Dictionary = structure_data(r)
	if not template.known: return 0.0
	var positions = r.get("positions", [])
	if not _valid_positions(positions, template.atoms.size()):
		return 0.0
	var agreement = 0.0
	var weight = 0.0
	for bond in template.bonds:
		var distance = _v(positions[int(bond[0])]).distance_to(_v(positions[int(bond[1])]))
		var relative_error = (distance - float(bond[2])) / float(bond[2])
		agreement += exp(-pow(relative_error / 0.22, 2))
		weight += 1.0
	for angle in template.angles:
		var a = _v(positions[int(angle[0])]) - _v(positions[int(angle[1])])
		var b = _v(positions[int(angle[2])]) - _v(positions[int(angle[1])])
		var value = 0.0
		if a.length() > 0.00001 and b.length() > 0.00001:
			var degrees = rad_to_deg(a.angle_to(b))
			value = exp(-pow((degrees - float(angle[3])) / 18.0, 2))
		agreement += 0.45 * value
		weight += 0.45
	# Ideal cells also compare their full relative geometry so corner atoms matter.
	# These distances are geometric references, not additional chemical bonds.
	if template.has("cell"):
		for i in range(positions.size()):
			for j in range(i + 1, positions.size()):
				var reference = _v(template.positions[i]).distance_to(_v(template.positions[j]))
				var actual = _v(positions[i]).distance_to(_v(positions[j]))
				agreement += 0.08 * exp(-pow((actual - reference) / (reference * 0.15), 2))
				weight += 0.08
	var collision_penalty = 1.0
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var min_distance = 0.45 * (float(template.atom_contexts[i].radius) + float(template.atom_contexts[j].radius))
			var distance = _v(positions[i]).distance_to(_v(positions[j]))
			if distance < min_distance:
				collision_penalty *= clampf(distance / min_distance, 0.0, 1.0)
	return clampf(agreement / maxf(weight, 0.001) * collision_penalty, 0.0, 1.0)

func income(r: Dictionary) -> float:
	return float(income_breakdown(r).rate)

func income_breakdown(r: Dictionary) -> Dictionary:
	var info: Dictionary = structure_data(r)
	var result: Dictionary = economy.breakdown(info, quality(r), int(r.level), float(r.get("build_left", 0.0)) > 0.0)
	result.known = info.known
	if not info.known:
		# A real compound from the index earns more than a hypothesis, still far below a tuned template.
		result.index = ChemIndex.is_find(info.get("index",{}))
		result.rate = 0.0 if float(r.get("build_left",0.0)) > 0.0 else float(economy.rules.exploration_rate) * (ChemIndex.INDEX_RATE_FACTOR if result.index else 1.0)
	return result

func total_income() -> float:
	var result = 0.0
	for r in reactors:
		if int(r.pending)<reactor_capacity(r): result += income(r)
	return result

func tick(delta: float):
	poll_science()
	if not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, 60.0)
	# Long frames use the same order of production, travel and collection as live play.
	if delta>1.0:
		for step in range(int(delta)): tick(1.0)
		if delta-floor(delta)>0.0: tick(delta-floor(delta))
		return
	planet.tick(delta,campus.industrial_rate(campus_context()) if not planet.laminates.job.is_empty() or (planet.production_mode=="island" and not planet.job.is_empty()) else 1.0)
	_campus_clock += delta
	while _campus_clock >= 1.0:
		var payroll_result: Dictionary=payroll.tick(1.0,campus.people,campus.config,coins)
		coins-=float(payroll_result.paid)
		campus.work_factor=payroll.work_factor(campus.config)
		var context=campus_context()
		context["logistics"]=logistics.prepare(campus.people,reactors,context.reachable_plots,storage,island_rules)
		var campus_result: Dictionary=campus.tick(1.0,context)
		var served: Array=industry.serve(self,1.0)
		if not served.is_empty(): industry_notice="；".join(served)
		_finish_logistics(logistics.arrivals(campus.people,1.0,storage,island_rules))
		_campus_clock-=1.0
		if not campus_result.get("notifications",[]).is_empty(): campus_notice="；".join(campus_result.notifications)
		if payroll_result.settled:
			campus_notice="已发放薪酬 %.1f 金币%s" % [payroll_result.paid,"；欠薪 %.1f，工作效率暂为75%%，收获后可补发" % payroll.arrears if payroll.arrears>0 else ""]
	_production_clock += delta
	if _production_clock < 0.2: return
	delta=_production_clock
	_production_clock=0.0
	market.tick(delta,economy,templates,island_rules.visitors,contracts.offers(self))
	sync_gear()
	var refined: Array=refinery.tick(self,delta)
	if not refined.is_empty(): refinery_notice="；".join(refined)
	industry.sync_legacy(self)
	var made: Array=industry.tick(self,delta)
	if not made.is_empty(): industry_notice="星锻岛："+"；".join(made)
	visitor_cooldown = maxf(0.0, visitor_cooldown - delta)
	_produce(delta)

## Reactor construction and output for `delta` seconds (shared by live ticks and offline catch-up).
func _produce(delta: float) -> void:
	for r in reactors:
		var active_time = delta
		if float(r.build_left) > 0.0:
			var build_speed = campus.construction_factor(int(r.plot))
			if build_speed<=0: continue
			var time_needed = float(r.build_left) / build_speed
			r.build_left = maxf(0.0, float(r.build_left) - delta * build_speed)
			active_time = maxf(0.0, delta - time_needed)
		if active_time <= 0.0:
			continue
		if int(r.pending)>=reactor_capacity(r): continue
		# Unrecognized chemistry earns only the explicit exploration stipend.
		# It cannot create sellable units or building-material drops.
		if reference_id(r).is_empty() and not r.get("sandbox",false):
			r.stored_coins=minf(income(r)*float(island_rules.production.seconds_per_unit)*reactor_capacity(r),float(r.stored_coins)+income(r)*active_time)
			continue
		var speed = (0.35 + quality(r) * 0.65) * (1.0 + (int(r.level) - 1) * float(island_rules.production.level_speed_bonus)) / float(island_rules.production.seconds_per_unit)
		if "process_control" in campus.unlocked_materials: speed*=1.15
		var free=reactor_capacity(r)-int(r.pending)
		active_time=minf(active_time,(float(free)-float(r.progress))/speed)
		r.stored_coins=minf(100000000.0,float(r.stored_coins)+income(r)*active_time)
		r.progress = float(r.progress) + active_time * speed
		var produced = mini(free,int(floor(float(r.progress)+0.0000001)))
		if produced > 0:
			r.progress = maxf(0,float(r.progress)-produced)
			r.stock = mini(1000000, int(r.stock) + produced)
			r.pending = mini(1000000, int(r.get("pending", 0)) + produced)

const OFFLINE_MAX_SECONDS = 7200
const OFFLINE_RATE = 0.5
const OFFLINE_MIN_SECONDS = 60

## Capped offline progress: reactors and the refinery (only) run for half the time away, up to two hours.
## Payroll, campus life and the planet stay paused, matching "离线不计薪".
func offline_catch_up(now: int) -> Dictionary:
	if saved_at <= 0 or now - saved_at < OFFLINE_MIN_SECONDS: return {}
	var away := mini(now - saved_at, 1000000000)
	var simulated := minf(float(away), OFFLINE_MAX_SECONDS) * OFFLINE_RATE
	var units_before := 0; var coins_before := 0.0
	for r in reactors: units_before += int(r.pending); coins_before += float(r.stored_coins)
	var left := simulated
	sync_gear()
	while left > 0.0:
		_produce(minf(left, 10.0)); refinery.tick(self, minf(left, 10.0)); industry.tick(self, minf(left, 10.0)); left -= 10.0
	saved_at = now
	var units := 0; var stored := 0.0
	for r in reactors: units += int(r.pending); stored += float(r.stored_coins)
	return {"away": away, "simulated": simulated, "capped": away > OFFLINE_MAX_SECONDS, "units": units - units_before, "coins": stored - coins_before}

func click_energy() -> String:
	coins = minf(100000000.0, coins + 2.0)
	return "+2 金币 · 微光正在聚集"

func edit_cost(r: Dictionary) -> int:
	return 12 * int(r.level) * int(r.level)

func upgrade_cost(r: Dictionary) -> int:
	return 90 * int(r.level) * int(r.level)

func _collect(r: Dictionary) -> Dictionary:
	var result = {"coins": 0.0, "drops": 0, "units": 0, "gifts": [], "index": []}
	if float(r.build_left) > 0.0 or (int(r.get("pending", 0)) == 0 and float(r.stored_coins) <= 0.0):
		return result
	if not storage.add_product(product_snapshot(r),int(r.pending)): return result
	result.coins = float(r.stored_coins)
	coins = minf(100000000.0, coins + result.coins)
	r.stored_coins = 0.0
	var units = int(r.get("pending", 0))
	r.pending = 0
	r.stock = 0
	result.units = units
	for unit in range(units if not reference_id(r).is_empty() else 0):
		_dry_harvests += 1
		if rng.randf() < float(island_rules.production.drop_probability) or _dry_harvests >= int(island_rules.production.drop_pity):
			var selected = rng.randi_range(0, 2)
			if _dry_harvests >= int(island_rules.production.drop_pity):
				selected = materials.find(materials.min())
			materials[selected] = mini(1000000, int(materials[selected]) + 1)
			result.drops += 1
			_dry_harvests = 0
	total_harvests += units
	var ref_id: String = reference_id(r)
	if units > 0 and not ref_id.is_empty() and not discovered.has(ref_id):
		discovered.append(ref_id)
	result.gifts = Codex.record(self, ref_id, quality(r)) if units > 0 and not ref_id.is_empty() else []
	var found: Dictionary = structure_data(r).get("index",{})
	var index_gift: String = ChemIndex.record(self, found)
	if not index_gift.is_empty():
		result.index.append(index_gift)
		index_notice = {"formula":ChemIndex.formula(found.entry),"name":str(found.entry.get("name","")) if found.kind=="molecule" else str(found.entry.get("spacegroup","")),"kind":str(found.kind),"key":str(found.key)}
	return result

func harvest(index: int) -> String:
	if not _valid_index(index):
		return "请先选择反应炉"
	var result = _collect(reactors[index])
	if result.coins <= 0.0 and result.units == 0:
		return "反应炉正在准备，稍后再来收获"
	return "收获 +%d 金币 · +%d 建材 · %d 份产物入库" % [int(result.coins), result.drops, result.units] + _gift_text(result.gifts) + _index_text(result.index)

func harvest_all() -> String:
	var earned = 0.0
	var drops = 0
	var gifts: Array = []
	var index: Array = []
	for r in reactors:
		var result = _collect(r)
		earned += result.coins
		drops += result.drops
		gifts.append_array(result.gifts)
		index.append_array(result.index)
	return "全岛收获 +%d 金币 · +%d 建材" % [int(earned), drops] + _gift_text(gifts) + _index_text(index)

func _gift_text(gifts: Array) -> String:
	return "" if gifts.is_empty() else " · 图鉴奖励 " + "、".join(gifts)

func _index_text(finds: Array) -> String:
	return "" if finds.is_empty() else " · " + "、".join(finds)

func plot_at(x: int, z: int) -> int:
	for i in range(plots.size()):
		if int(plots[i].x) == x and int(plots[i].z) == z:
			return i
	return -1

func unlocked_plot_count() -> int:
	var count = 0
	for p in plots:
		if p.unlocked:
			count += 1
	return count

func can_expand(index: int) -> bool:
	if index < 0 or index >= plots.size() or plots[index].unlocked or unlocked_plot_count() >= MAX_UNLOCKED_PLOTS:
		return false
	var p = plots[index]
	for direction in CARDINAL_DIRECTIONS:
		var neighbor = plot_at(int(p.x) + direction.x, int(p.z) + direction.y)
		if neighbor >= 0 and plots[neighbor].unlocked:
			return true
	return false

func plot_cost(index: int) -> int:
	if index < 0 or index >= plots.size():
		return 0
	var p = plots[index]
	return 2 + maxi(0, maxi(absi(int(p.x)), absi(int(p.z))) - 1)

func plot_label(index: int) -> String:
	if index < 0 or index >= plots.size():
		return "未选择地块"
	return "地块 (%d, %d)" % [int(plots[index].x), int(plots[index].z)]

func _append_frontier():
	# Indices are persistent building identities. Extend only; never sort or rebuild.
	var coordinates = {}
	for p in plots:
		coordinates[Vector2i(int(p.x), int(p.z))] = true
	var additions: Array = []
	for p in plots:
		if not p.unlocked:
			continue
		for direction in CARDINAL_DIRECTIONS:
			var coordinate = Vector2i(int(p.x), int(p.z)) + direction
			if coordinates.has(coordinate) or absi(coordinate.x) > MAX_COORDINATE or absi(coordinate.y) > MAX_COORDINATE:
				continue
			if plots.size() + additions.size() >= MAX_SAVED_PLOTS:
				plots.append_array(additions)
				return
			coordinates[coordinate] = true
			additions.append({"x": coordinate.x, "z": coordinate.y, "unlocked": false, "kind": "empty", "rid": -1,"road":false,"building_level":1,"props":[],"items":[]})
	plots.append_array(additions)

func buy_plot(index: int) -> String:
	if index < 0 or index >= plots.size():
		return "请选择岛上的地块"
	if plots[index].unlocked:
		return "这块土地已经开放了"
	if unlocked_plot_count() >= MAX_UNLOCKED_PLOTS:
		return "本版可开拓%d块土地；星球才是无限的远方" % MAX_UNLOCKED_PLOTS
	if not can_expand(index):
		return "请从已开拓土地相邻的边缘继续扩建"
	var cost = plot_cost(index)
	for amount in materials:
		if int(amount) < cost:
			return "开拓这块土地需要三种建材各%d份；收获产物有机会获得" % cost
	for i in range(3):
		materials[i] -= cost
	plots[index].unlocked = true
	plots[index].road=true
	layout.mark_changed()
	_append_frontier()
	if (unlocked_plot_count()-5)%int(island_rules.relics.every_plots)==0:
		var kinds: Array=island_rules.relics.kinds
		storage.finds[str(index)]=kinds[(unlocked_plot_count()/int(island_rules.relics.every_plots))%kinds.size()]
	return "新土地已开拓！可以放置反应炉或装饰"

# --- v0.31 gates: a doctor installs, and the atoms come from the element store -----------
## A doctor on post auto or logistics installs new samples. Without one, only coordinates change.
func install_status() -> Dictionary:
	var doctors: int = 0
	for person in campus.people:
		if person.role != "doctor": continue
		doctors += 1
		if str(person.get("post","auto")) in ["auto","logistics"]: return {"ok":true,"message":""}
	if doctors == 0: return {"ok":false,"message":"需要装炉博士：先建博士公寓与科研院所，再招募博士"}
	return {"ok":false,"message":"博士都在其他岗位：在小镇 · 居民里安排一位博士负责装炉"}

func _atom_counts(atoms: Array) -> Dictionary:
	var out := {}
	for symbol in atoms: out[str(symbol)] = int(out.get(str(symbol),0)) + 1
	return out

## Empty when the store holds every required element, otherwise what is short and where to get it.
func element_shortage(required: Dictionary) -> String:
	for symbol in required:
		var have: int = int(element_inventory.get(symbol,0))
		if have < int(required[symbol]):
			return "%s不足：需要%d份，仓库有%d份。来源：%s" % [symbol,int(required[symbol]),have,refinery.how_to_get(symbol)]
	return ""

## Building a reactor: 100 coins plus every atom of the starting structure.
func reactor_quote(plot_index: int, template_id: String) -> Dictionary:
	var q := {"ready":false,"fee":100,"required":{},"message":""}
	if plot_index < 0 or plot_index >= plots.size() or not templates.has(template_id):
		q.message = "请选择有效的土地和结构"; return q
	q.required = _atom_counts(templates[template_id].atoms)
	if templates[template_id].get("substitution_only",false) and template_id not in campus.unlocked_materials:
		q.message = "这个结构需要在原子工作台中替换元素来发现"; return q
	if not plots[plot_index].unlocked or plots[plot_index].kind != "empty":
		q.message = "请在已开拓的空地上建造"; return q
	var probe: Dictionary = plots[plot_index].duplicate(); probe.kind = "reactor"
	if not Town.island_free(plots, plot_index, Town.primary_rect(probe)).is_empty():
		q.message = "反应炉需要地块中央8×8格的空位；先挪开这里的装饰"; return q
	if coins < 100.0:
		q.message = "建造反应炉需要100金币"; return q
	var gate := install_status()
	if not gate.ok: q.message = gate.message; return q
	q.message = element_shortage(q.required)
	if not q.message.is_empty(): return q
	q.ready = true
	q.message = "100金币 + 结构里的全部元素"
	return q

## Loading another starting structure: 25 coins plus only the atoms the reactor doesn't hold yet.
func template_quote(index: int, template_id: String) -> Dictionary:
	var q := {"ready":false,"fee":25,"required":{},"message":""}
	if not _valid_index(index) or not templates.has(template_id):
		q.message = "请选择有效的反应炉和结构"; return q
	if templates[template_id].get("substitution_only",false) and template_id not in campus.unlocked_materials:
		q.message = "这个结构只能通过元素替换获得，不能直接装载"; return q
	var r: Dictionary = reactors[index]
	var held := _atom_counts(atom_symbols(r))
	var wanted := _atom_counts(templates[template_id].atoms)
	for symbol in wanted:
		var extra: int = int(wanted[symbol]) - int(held.get(symbol,0))
		if extra > 0: q.required[symbol] = extra
	if float(r.build_left) > 0.0: q.message = "反应炉建好后才能更换结构"; return q
	if not r.get("installation",{}).is_empty(): q.message = "已有待装炉样品，请等待博士或取消装炉"; return q
	if reference_id(r) == template_id: q.message = "反应炉已经使用这个结构；修改坐标请使用原子编辑器"; return q
	if coins < 25.0: q.message = "更换结构需要25金币"; return q
	var gate := install_status()
	if not gate.ok: q.message = gate.message; return q
	q.message = element_shortage(q.required)
	if not q.message.is_empty(): return q
	q.ready = true
	q.message = "25金币 + 新增的元素，博士装炉"
	return q

func place_reactor(plot_index: int, template_id: String = "water") -> String:
	var q := reactor_quote(plot_index, template_id)
	if not q.ready: return q.message
	coins -= 100.0
	for symbol in q.required: element_inventory[symbol] -= int(q.required[symbol])
	var r = _new_reactor(plot_index, template_id, 12.0)
	reactors.append(r)
	plots[plot_index].kind = "reactor"
	plots[plot_index].rid = reactors.size() - 1
	layout.mark_changed()
	return "反应炉开始建造 · 用掉%s · 初始结构待调节，调整键长可提高产率" % _required_text(q.required)

func _required_text(required: Dictionary) -> String:
	var parts: Array = []
	for symbol in required: parts.append("%s×%d" % [symbol,int(required[symbol])])
	return "、".join(parts) if not parts.is_empty() else "无新元素"

const DECORATIONS = {"garden":{"name":"晶体花园","cost":35},"house":{"name":"工程师小屋","cost":60},"road":{"name":"星砂小径","cost":18},"fence":{"name":"木质围栏","cost":24},"sculpture":{"name":"原子纪念雕塑","cost":85}}

func place_decoration(plot_index: int, kind: String) -> String:
	if plot_index < 0 or plot_index >= plots.size() or not DECORATIONS.has(kind): return "请选择有效的土地和装饰"
	if not plots[plot_index].unlocked or plots[plot_index].kind != "empty": return "装饰需要一块已开拓的空地"
	if not plots[plot_index].get("items",[]).is_empty(): return "整块装饰需要完全空着的地块"
	if kind == "sculpture" and deliveries < 3: return "完成3次交付，解锁原子纪念雕塑"
	var info: Dictionary = DECORATIONS[kind]
	if coins < int(info.cost): return "金币不足，需要%d金币" % int(info.cost)
	coins -= int(info.cost)
	plots[plot_index].kind = kind
	layout.pin(plots[plot_index])
	layout.mark_changed()
	return "%s落成了" % info.name

func move_building(source: int, target: int) -> String:
	if source < 0 or source >= plots.size() or target < 0 or target >= plots.size(): return "请选择有效地块"
	var origin: Dictionary = plots[source]
	if origin.kind=="plaza": return "广场是公共交通入口，不可搬迁"
	var destination: Dictionary = plots[target]
	if not origin.unlocked or origin.kind == "empty": return "这里没有可搬迁的建筑"
	if not destination.unlocked or destination.kind != "empty": return "请选择已开拓的空地"
	var probe: Dictionary = destination.duplicate(); probe.kind = origin.kind
	if origin.has("at"): probe.at = origin.at.duplicate()
	if not Town.island_free(plots, target, Town.primary_rect(probe), ["%d:p" % source]).is_empty(): return "那块地上的装饰挡住了建筑位置，先挪开"
	# Other buildings on the old plot keep their residents; only the moved kind's people follow.
	var moved_kind: String = Town.building_kind(str(origin.kind))
	var stays: bool = false
	for item in origin.get("items", []):
		if Town.building_kind(str(item.kind)) == moved_kind: stays = true
	destination.kind = origin.kind
	if origin.has("at"): destination.at = origin.at.duplicate(); origin.erase("at")
	destination.rid = origin.rid
	destination.building_level=origin.get("building_level",1)
	if storage.cupboards.has(str(source)):
		storage.cupboards[str(target)]=storage.cupboards[str(source)]
		storage.cupboards.erase(str(source))
	origin.building_level=1
	for resident in campus.people:
		var follows: bool = moved_kind in campus.config.roles[resident.role].housing or (moved_kind == "engineer_house" and resident.role == "engineer")
		if int(resident.home_plot)==source and follows: resident.home_plot=target
		if int(resident.work_plot)==source and not stays: resident.work_plot=target
		if int(resident.target_plot)==source and not stays:
			resident.target_plot=target
			resident.arrived=false
	layout.mark_changed()
	if origin.kind == "reactor": reactors[int(origin.rid)].plot = target
	origin.kind = "empty"
	origin.rid = -1
	return "搬迁完成，结构、等级与库存均已保留"

func hire_engineer() -> String:
	return campus_hire("engineer")

func open_crate() -> String:
	var cost = 0 if crate_count == 0 else 45
	if coins < cost:
		return "探索箱需要45金币；每第10箱必得工程师"
	coins -= cost
	crate_count += 1
	var roll = rng.randf()
	if crate_count % 10 == 0 or roll >= 0.85:
		var context=campus_context()
		context.coins=100000000
		var result: Dictionary=campus.hire("engineer",context)
		if result.ready:
			_sync_campus_counts()
			return "探索箱打开：免费工程师 +1，已入住空床位！"
		coins+=85.0
		return "暂时没有连路的空床位，工程师奖励转换为85金币"
	if roll < 0.50:
		var prize = rng.randi_range(28, 90)
		coins += prize
		return "探索箱打开：+%d 金币" % prize
	var selected = rng.randi_range(0, 2)
	materials[selected] += 3
	return "探索箱打开：%s +3" % ["星砂", "晶露", "合金片"][selected]

func upgrade_reactor(index: int) -> String:
	if not _valid_index(index):
		return "请先选择反应炉"
	var r = reactors[index]
	if float(r.build_left) > 0.0:
		return "请等待反应炉建造完成"
	if int(r.level) >= 20:
		return "反应炉已达到演示版最高等级"
	var cost = upgrade_cost(r)
	if coins < cost or upgrades < 1:
		return "升级需要%d金币和1枚精品催化晶；完成精品订单可获得" % cost
	coins -= cost
	upgrades -= 1
	r.level += 1
	if ReactorLook.tier_step(int(r.level))==1:
		return "反应炉升至Lv.%d · 外观升级为「%s」：%s" % [r.level, ReactorLook.tier_info(int(r.level)).name, ReactorLook.tier_info(int(r.level)).blurb]
	return "反应炉升至Lv.%d · 生产加快；本级每次编辑固定%d金币" % [r.level, edit_cost(r)]

## What the 3D views draw: the identified structure, its phase and live installation progress.
func reactor_views() -> Array:
	var views: Array = []
	for r in reactors:
		var info: Dictionary = structure_data(r)
		var view: Dictionary = r.duplicate(false)
		view.atoms = info.atoms
		view.atom_contexts = info.atom_contexts
		view.bonds = info.bonds
		if info.known: view.template = info.reference_id
		view.phase = str(ReactorLook.phase(str(info.reference_id)).get("phase","")) if info.known else ""
		var job: Dictionary = r.get("installation",{})
		if not job.is_empty():
			view.install_elements = _install_symbols(job)
			view.install_progress = clampf(1.0-float(job.remaining)/maxf(1.0,float(island_rules.logistics.installation_seconds)),0.0,1.0)
		views.append(view)
	return views

## Elements a doctor carries in: the reserved ones, else the incoming structure's own atoms.
func _install_symbols(job: Dictionary) -> Array:
	var symbols: Array = job.get("elements",{}).keys()
	if not symbols.is_empty(): return symbols
	var payload: Dictionary = job.get("payload",{})
	var atoms: Array = []
	match str(payload.get("kind","")):
		"template": atoms = templates.get(str(payload.get("template","")),{}).get("atoms",[])
		"structure": atoms = payload.get("atoms",[])
		"sandbox": atoms = payload.get("work",{}).get("atoms",[])
	for atom in atoms:
		var symbol: String = str(atom.get("element",atom.get("symbol",""))) if atom is Dictionary else str(atom)
		if not symbol.is_empty() and symbol not in symbols: symbols.append(symbol)
	return symbols

func reactor_phase(r: Dictionary) -> String:
	var info: Dictionary = structure_data(r)
	return str(ReactorLook.phase(str(info.reference_id)).get("phase","")) if info.known else ""

func _update_order():
	order = economy.make_order(deliveries+visitor_skips, templates)
	order.accept_exploration = (deliveries+visitor_skips)%4==3
	if order.accept_exploration:
		order.name="星球创意展策展人"
		order.story="收集自创作品做成小岛展览。按展示样品收购，不评价真实稳定性；无精品催化晶。"

func _first_visitor() -> Dictionary:
	for v in market.visitors:
		if v.phase=="visiting" and not contracts.is_material(v): return v
	return {}

func dismiss_visitor() -> String:
	var v=_first_visitor()
	return visitor_countdown_text() if v.is_empty() else dismiss_market_visitor(int(v.id))

func delivery_quote(index: int) -> Dictionary:
	if not _valid_index(index): return {}
	var v=_first_visitor()
	var snapshot=product_snapshot(reactors[index])
	var batch=storage.batch(str(snapshot.id))
	if batch.is_empty(): snapshot["quantity"]=0; batch=snapshot
	if v.is_empty(): v={"phase":"arriving","order":order}
	return market.quote(v,batch,economy)

func visitor_available() -> bool:
	return not _first_visitor().is_empty()

func visitor_countdown_text() -> String:
	if visitor_available(): return "收购商已到访 · 可以接待"
	return "下一位收购商约 %02d:%02d 后到访" % [int(market.clock)/60,int(market.clock)%60]

func market_candidates() -> Array:
	var rows=[]
	for i in range(reactors.size()):
		var q=delivery_quote(i); q["index"]=i; rows.append(q)
	rows.sort_custom(func(a,b): return a.score>b.score)
	return rows

func deliver(index: int) -> String:
	if not _valid_index(index): return "请选择反应炉"
	var v=_first_visitor()
	if v.is_empty(): return visitor_countdown_text()
	return fulfill_order(int(v.id),signature(reactors[index]))

func research() -> String:
	return campus_hire("doctor")

func optimize(index: int) -> String:
	if not _valid_index(index):
		return "请先选择反应炉"
	if scientists < 1:
		return "请先在研究站解锁H–O参考几何辅助"
	var r = reactors[index]
	if reference_id(r) != "water":
		return "当前仅研究了H–O水分子参考几何；其他体系尚未解锁"
	return apply_edit(index, templates.water.positions.duplicate(true))

func _valid_positions(value, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for point in value:
		if not point is Array or point.size() != 3:
			return false
		for component in point:
			if not (component is float or component is int):
				return false
			if not is_finite(float(component)) or absf(float(component)) > 20.0:
				return false
	return true

func _reset_product(r: Dictionary):
	r.progress = 0.0
	r.stock = 0
	r.pending = 0
	r.stored_coins = 0.0
	r.signature = signature(r)

func apply_edit(index: int, positions: Array) -> String:
	if not _valid_index(index):
		return "请先选择反应炉"
	return apply_structure_edit(index,positions,atom_symbols(reactors[index]))

func _valid_atoms(atoms, count: int) -> bool:
	if not atoms is Array or atoms.size() != count: return false
	for symbol in atoms:
		if not symbol is String or not elements.has(symbol): return false
	return true

func edit_quote(index: int, positions: Array, atoms: Array) -> Dictionary:
	var quote = {"valid":false,"changed":false,"ready":false,"fee":0,"required":{},"known":false,"reference_id":"","formula":"","message":"请选择有效的反应炉"}
	if not _valid_index(index): return quote
	var r = reactors[index]
	if not r.get("installation",{}).is_empty(): quote.message="已有待装炉样品，请等待博士或取消装炉"; return quote
	if not storage.can_add(signature(r),int(r.pending)): quote.message="工具箱批次已满，请先交付订单"; return quote
	if float(r.build_left) > 0.0:
		quote.message = "反应炉建好后才可以编辑结构"
		return quote
	if not _valid_positions(positions,templates[r.template].atoms.size()) or not _valid_atoms(atoms,positions.size()):
		quote.message = "坐标或元素无效：请保持位点数，坐标须为-20至20 Å内的有限数值"
		return quote
	quote.valid = true
	var old_atoms: Array = atom_symbols(r)
	for i in range(positions.size()):
		if _v(positions[i]).distance_to(_v(r.positions[i])) > 0.000001:
			quote.changed = true
		if atoms[i] != old_atoms[i]:
			quote.changed = true
			quote.required[atoms[i]] = int(quote.required.get(atoms[i],0)) + 1
	var candidate: Dictionary = {"template":r.template,"atoms":atoms}
	var info: Dictionary = structure_data(candidate)
	quote.known = info.known
	quote.reference_id = info.reference_id
	quote.formula = info.formula
	if not quote.changed:
		quote.message = "结构未变化，不扣费"
		return quote
	if atoms != old_atoms:
		var gate := install_status()
		if not gate.ok:
			quote.message = gate.message + "（没有博士时只能微调坐标）"
			return quote
	quote.fee = edit_cost(r)
	if coins < quote.fee:
		quote.message = "本级确认编辑需要%d金币" % quote.fee
		return quote
	var short := element_shortage(quote.required)
	if not short.is_empty():
		quote.message = short
		return quote
	quote.ready = true
	quote.message = "可以应用：一次编辑%d金币，元素按预览扣除" % quote.fee
	return quote

func apply_structure_edit(index: int, positions: Array, atoms: Array) -> String:
	var quote: Dictionary = edit_quote(index,positions,atoms)
	if not quote.ready: return quote.message
	var r: Dictionary = reactors[index]
	coins -= int(quote.fee)
	for symbol in quote.required:
		element_inventory[symbol] -= int(quote.required[symbol])
	if atoms!=atom_symbols(r):
		return _queue_install(r,{"kind":"structure","positions":positions.duplicate(true),"atoms":atoms.duplicate()},quote)
	_collect(r)
	r.positions = positions.duplicate(true)
	r.atoms = atoms.duplicate()
	_reset_product(r)
	return "结构已保存 · -%d 金币；旧批次已收入工具箱。%s" % [quote.fee,"识别为"+quote.formula if quote.known else "探索样品暂不评定精品"]

func change_template(index: int, template_id: String) -> String:
	if not _valid_index(index) or not templates.has(template_id):
		return "请选择有效的反应炉和结构"
	if templates[template_id].get("substitution_only",false) and template_id not in campus.unlocked_materials:
		return "这个结构只能通过元素替换获得，不能直接装载"
	var q := template_quote(index, template_id)
	if not q.ready: return q.message
	coins -= 25.0
	for symbol in q.required: element_inventory[symbol] -= int(q.required[symbol])
	return _queue_install(reactors[index],{"kind":"template","template":template_id},q)

func signature(r: Dictionary) -> String:
	var parts = [str(r.get("template", "unknown"))]
	if r.get("sandbox",false): parts.append(JSON.stringify([r.get("bonds",[]),r.get("mode","science"),r.get("periodic",false),r.get("cell_lengths",[])]))
	for symbol in atom_symbols(r): parts.append(str(symbol))
	for point in r.get("positions", []):
		parts.append("%.6f,%.6f,%.6f" % [float(point[0]), float(point[1]), float(point[2])])
	return "|".join(parts).sha256_text().substr(0, 12)

static func save_root_for_platform(platform: String) -> String:
	# APK resources are immutable. Desktop keeps the existing project-local saves.
	return "user://saves" if platform in ["Android","Web"] else "res://saves"

static func save_path_allowed_for_platform(path: String, platform: String) -> bool:
	var prefix = save_root_for_platform(platform) + "/"
	if not path.begins_with(prefix):
		return false
	var filename = path.substr(prefix.length())
	return filename.length() > 5 and filename.ends_with(".json") and not filename.contains("..") and filename.validate_filename() == filename and not filename.contains("/") and not filename.contains("\\")

func _save_path_allowed(path: String) -> bool:
	return save_path_allowed_for_platform(path, OS.get_name())

func save_game(path: String = "") -> String:
	var root = save_root_for_platform(OS.get_name())
	if path.is_empty():
		if not default_slot_enabled: return "测试运行不写入玩家存档"
		path = root + "/" + save_name
	if not _save_path_allowed(path):
		return "保存失败：存档只能写入专用的saves目录"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) != OK:
		return "保存失败：无法创建存档目录"
	var snapshot = {"version": 28, "industry": industry.serialize(), "fabricator": fabricator.serialize(), "index_found": index_found.keys(), "refinery": refinery.serialize(), "coach": coach_seen.keys(), "best_fit": best_fit, "star_rewards": star_rewards, "milestones_claimed": milestones_claimed, "saved_at": int(Time.get_unix_time_from_system()), "planet":planet.serialize(), "storage":storage.serialize(),"market":market.serialize(),"logistics_rounds":logistics.rounds.duplicate(), "campus":campus.serialize(), "payroll":payroll.serialize(), "coins": coins, "materials": materials, "upgrades": upgrades,
		"element_inventory":element_inventory,
		"engineers": engineers, "scientists": scientists, "crate_count": crate_count,
		"discovered": discovered, "plots": plots, "reactors": reactors,
		"deliveries": deliveries, "total_harvests": total_harvests,
		"dry_harvests": _dry_harvests, "serial": _serial,
		"visitor_cooldown": visitor_cooldown, "visitor_visits": visitor_visits, "visitor_skips": visitor_skips,
		"science_unlocked": science_unlocked, "science_runs": science_runs, "science_pending": science_pending}
	var temporary = path + ".tmp"
	# Retain tiny SI inputs and atomic coordinates across save/load cycles.
	var encoded=JSON.stringify(snapshot,"\t",true,true)
	if encoded.to_utf8_buffer().size()>MAX_SAVE_BYTES: return "保存失败：存档容量已满，请交付部分产物；旧存档仍保留"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "保存失败：无法写入存档"
	file.store_string(encoded)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK:
		return "保存失败：写入未完成，旧存档已保留"
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak")) != OK:
			return "保存失败：无法备份旧存档"
	var rename_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		return "保存失败：无法替换存档；备份仍保留"
	return "已保存到本机 · 下次可以继续这座小岛" if OS.get_name() in ["Android","Web"] else "已保存到当前项目 · 下次可以继续这座小岛"

func _number_ok(value, low: float, high: float, integer: bool = false) -> bool:
	if not (value is int or value is float):
		return false
	var n = float(value)
	return is_finite(n) and n >= low and n <= high and (not integer or floor(n) == n)

func _valid_science_record(record) -> bool:
	if not record is Dictionary: return false
	for field in ["method","reactor","signature","time"]:
		if not record.get(field) is String: return false
	if record.method not in science_method_ids() or not record.get("result") is Dictionary: return false
	var result: Dictionary = record.result
	if not result.get("success") is bool or not result.get("can_apply",false) is bool: return false
	for field in ["message","notes","units","status"]:
		if result.has(field) and not result[field] is String: return false
	for field in ["validation_rmse","validation_max_error","integrated_electrons"]:
		if result.has(field) and not _number_ok(result[field],0,1e12): return false
	for field in ["training_count","validation_count"]:
		if result.has(field) and not _number_ok(result[field],0,100000,true): return false
	if not result.get("history",[]) is Array or result.get("history",[]).size()>2000: return false
	for point in result.get("history",[]):
		if not point is Dictionary or not _number_ok(point.get("energy"),-1e12,1e12): return false
	if not result.get("density",[]) is Array or result.get("density",[]).size()>4096: return false
	for point in result.get("density",[]):
		if not point is Array or point.size()!=2: return false
		if not _number_ok(point[0],-1e6,1e6) or not _number_ok(point[1],0,1e6): return false
	if result.success and not _number_ok(result.get("energy"),-1e12,1e12): return false
	if result.get("can_apply",false):
		if record.method=="dft_teaching" or not result.get("positions") is Array: return false
		if not _valid_positions(result.positions,result.positions.size()) or result.positions.is_empty() or result.positions.size()>64: return false
	return true

func _validate_save(data) -> bool:
	if not data is Dictionary or not _number_ok(data.get("version"), 1, 28, true):
		return false
	if int(data.version)>=28 and not Industry.new().restore(data.get("industry")): return false
	if int(data.version)>=26 and not Fabricator.new().restore(data.get("fabricator")): return false
	if int(data.version)>=25 and (not data.get("index_found") is Array or data.index_found.size()>4096 or data.index_found.any(func(id): return not id is String or str(id).length()>40)): return false
	if int(data.version)>=24 and not Refinery.new().restore(data.get("refinery"),elements): return false
	if data.has("coach") and (not data.coach is Array or data.coach.size()>32 or data.coach.any(func(id): return not id is String or str(id).length()>32)): return false
	if int(data.version)>=23:
		if not data.get("best_fit") is Dictionary or data.best_fit.size()>templates.size(): return false
		for id in data.best_fit:
			if not templates.has(id) or not _number_ok(data.best_fit[id],0,1): return false
		if not _number_ok(data.get("star_rewards"),0,Codex.rewards().size(),true): return false
	if int(data.version)>=22:
		if not data.get("milestones_claimed") is Array or not _number_ok(data.get("saved_at"),0,4102444800,true): return false
		for id in data.milestones_claimed:
			if not id is String: return false
	if int(data.version)>=11 and not PlanetProgram.new().restore(data.get("planet"),self): return false
	if int(data.version)==12 and data.planet.version!=2: return false
	if int(data.version)==13 and data.planet.version!=3: return false
	if int(data.version)>=14 and int(data.version)<15 and data.planet.version!=4: return false
	if int(data.version)==15 and data.planet.version!=5: return false
	if int(data.version)==16 and data.planet.version!=6: return false
	if int(data.version)==17 and data.planet.version!=7: return false
	if int(data.version)==18 and data.planet.version!=8: return false
	if int(data.version)==19 and data.planet.version!=9: return false
	if int(data.version)>=20 and int(data.planet.version) not in [10,11,12]: return false
	if int(data.version) >= 3:
		# v0.3 saves may predate newly discoverable elements. Keep every
		# existing quantity and initialize only symbols introduced in v0.4.
		if not data.get("element_inventory") is Dictionary or data.element_inventory.size() > elements.size(): return false
		for saved_symbol in data.element_inventory:
			if not elements.has(saved_symbol) or not _number_ok(data.element_inventory.get(saved_symbol),0,9999,true): return false
	if not _number_ok(data.get("coins"), 0, 100000000):
		return false
	if not _number_ok(data.get("visitor_cooldown", 0), 0, 86400) or not _number_ok(data.get("visitor_visits", 0), 0, 1000000, true):
		return false
	if not _number_ok(data.get("visitor_skips",0),0,1000000,true): return false
	for key in ["upgrades", "crate_count", "deliveries", "total_harvests"]:
		if not _number_ok(data.get(key), 0, 1000000, true):
			return false
	if not _number_ok(data.get("engineers"), 0, 100, true) or not _number_ok(data.get("scientists"), 0, 3, true):
		return false
	if data.has("science_unlocked"):
		if not data.science_unlocked is Array or data.science_unlocked.size() > science_method_ids().size(): return false
		for method_id in data.science_unlocked:
			if not method_id is String or method_id not in science_method_ids(): return false
	if not data.get("science_pending",{}) is Dictionary: return false
	if data.has("science_runs"):
		if not data.science_runs is Array or data.science_runs.size() > 24: return false
		for record in data.science_runs:
			if not _valid_science_record(record): return false
	if not _number_ok(data.get("dry_harvests", 0), 0, int(island_rules.production.drop_pity)-1, true) or not _number_ok(data.get("serial", 1), 1, 1000, true):
		return false
	if not data.get("materials") is Array or data.materials.size() != 3:
		return false
	for item in data.materials:
		if not _number_ok(item, 0, 1000000, true):
			return false
	if not data.get("discovered") is Array or data.discovered.size() > templates.size():
		return false
	var known = {}
	for id in data.discovered:
		if not id is String or not templates.has(id) or known.has(id):
			return false
		known[id] = true
	if not data.get("plots") is Array or data.plots.size() < 9 or data.plots.size() > MAX_SAVED_PLOTS:
		return false
	if int(data.version) == 1 and data.plots.size() != 9:
		return false
	if not data.get("reactors") is Array or data.reactors.size() < 1 or data.reactors.size() > MAX_UNLOCKED_PLOTS:
		return false
	if int(data.version) == 1 and data.reactors.size() > 9:
		return false
	var seen_ids = {}
	var seen_plots = {}
	for i in range(data.reactors.size()):
		var r = data.reactors[i]
		if not r is Dictionary or not r.get("id") is String or r.id.length() > 32 or r.id.is_empty() or seen_ids.has(r.id):
			return false
		seen_ids[r.id] = true
		if not r.get("template") is String or not templates.has(r.template):
			return false
		if r.get("sandbox",false):
			if int(data.version)<7 or not r.get("sandbox") is bool: return false
			if not r.get("atoms") is Array or r.atoms.is_empty(): return false
			if not r.get("positions") is Array or not r.get("bonds",[]) is Array or not r.get("cell_lengths",[]) is Array: return false
			if not sandbox_validate(reactor_work(r)): return false
		elif int(data.version) >= 3 and not _valid_atoms(r.get("atoms"),templates[r.template].atoms.size()): return false
		if not _number_ok(r.get("plot"), 0, data.plots.size() - 1, true) or seen_plots.has(int(r.plot)):
			return false
		seen_plots[int(r.plot)] = true
		if not _number_ok(r.get("level"), 1, 20, true) or not _valid_positions(r.get("positions"), r.atoms.size() if r.get("sandbox",false) else templates[r.template].atoms.size()):
			return false
		if not _number_ok(r.get("progress"), 0, 0.999999999) or not _number_ok(r.get("stock"), 0, 1000000, true):
			return false
		if not _number_ok(r.get("pending", 0), 0, 1000000, true) or not _number_ok(r.get("stored_coins"), 0, 100000000):
			return false
		if not _number_ok(r.get("build_left"), 0, 12):
			return false
		if not _valid_installation(r): return false
		if int(data.version) >= 3 and reference_id(r).is_empty() and not r.get("sandbox",false):
			if int(r.stock) != 0 or int(r.get("pending",0)) != 0 or float(r.progress) != 0.0: return false
	var coordinates = {}
	var open_count = 0
	for i in range(data.plots.size()):
		var p = data.plots[i]
		if not p is Dictionary or not p.get("unlocked") is bool or not p.get("kind") is String or p.kind not in ["empty", "reactor", "garden", "house", "road", "fence", "sculpture", "plaza"] + layout.building_kinds():
			return false
		if int(data.version)>=8 and not layout.valid_plot_fields(p): return false
		if int(data.version) >= 2:
			if not _number_ok(p.get("x"), -MAX_COORDINATE, MAX_COORDINATE, true) or not _number_ok(p.get("z"), -MAX_COORDINATE, MAX_COORDINATE, true):
				return false
			var coordinate = Vector2i(int(p.x), int(p.z))
			if coordinates.has(coordinate):
				return false
			coordinates[coordinate] = true
			if i < 9 and coordinate != Vector2i(i % 3 - 1, int(i / 3) - 1):
				return false
		if p.unlocked:
			open_count += 1
		if not _number_ok(p.get("rid"), -1, data.reactors.size() - 1, true):
			return false
		if not p.unlocked and p.kind != "empty":
			return false
		if p.kind == "reactor":
			if int(p.rid) < 0 or int(data.reactors[int(p.rid)].plot) != i:
				return false
		elif int(p.rid) != -1 or seen_plots.has(i):
			return false
	if int(data.version)>=8:
		if data.has("payroll"):
			if not data.payroll is Dictionary or not CampusPayroll.new().restore(data.payroll): return false
		if not data.get("campus") is Dictionary: return false
		var check_campus=CampusSim.new()
		if not check_campus.restore(data.campus): return false
		for resident in check_campus.people:
			for location in ["home_plot","target_plot","work_plot","current_plot","next_plot","travel_target"]:
				if int(resident.get(location,-1))>=data.plots.size(): return false
			for location in resident.get("travel_route",[]):
				if int(location)>=data.plots.size(): return false
	if int(data.version)>=20:
		var uses_family=false
		for d in data.planet.materials.designs.values():
			if d.get("basis")=="family_model": uses_family=true
		if uses_family or data.planet.laminates.purchased.Cu>0 or data.planet.laminates.purchased.Al>0:
			if "laminate_design" not in data.campus.unlocked_materials: return false
	if int(data.version)>=21 and data.get("market",{}).get("version")!=2: return false
	if int(data.version)>=9:
		if not IslandStorage.new().restore(data.get("storage"),layout.config.props.keys()+["road"]+Town.rules().items.keys(),island_rules.consumables.keys(),data.plots): return false
		for batch in data.storage.batches:
			if not sandbox_validate(batch.work) or (not batch.reference.is_empty() and not templates.has(batch.reference)): return false
		if not IslandMarket.new().restore(data.get("market"),island_rules.visitors,templates,contracts.valid_order): return false
		for v in data.market.visitors:
			if contracts.is_material(v) and (int(data.version)<21 or not data.planet.joined or "laminate_design" not in data.campus.unlocked_materials): return false
		if not data.get("logistics_rounds") is Dictionary: return false
		for id in data.logistics_rounds:
			var maximum_rounds=0
			for food in island_rules.consumables.values(): maximum_rounds=maxi(maximum_rounds,int(food.rounds))
			if not str(id).is_valid_int() or not _number_ok(data.logistics_rounds[id],0,maximum_rounds,true): return false
	if int(data.version)>=11:
		var exhibits={}
		for item in data.planet.get("v2",{}).get("construction",{}).get("miniatures",{}).values():
			var plot=int(item.plot)
			if plot<0: continue
			if plot>=data.plots.size() or not data.plots[plot].unlocked or data.plots[plot].kind=="plaza" or exhibits.has(plot): return false
			exhibits[plot]=true
	if int(data.version)>=8 and not _valid_town(data): return false
	return open_count <= MAX_UNLOCKED_PLOTS+1

func load_game(path: String = "") -> bool:
	if path.is_empty() and not default_slot_enabled: return false
	if path.is_empty():
		path = save_root_for_platform(OS.get_name()) + "/" + save_name
	if not _save_path_allowed(path):
		return false
	var data = null
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file = FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		# Refuse huge files before parsing; normal saves remain far below this limit.
		if file.get_length() > MAX_SAVE_BYTES:
			file.close()
			continue
		var content = file.get_as_text()
		file.close()
		var parser = JSON.new()
		if parser.parse(content) == OK and _validate_save(parser.data):
			data = parser.data
			break
	if data == null:
		return false
	planet=PlanetProgram.new()
	if int(data.version)>=11: planet.restore(data.planet,self)
	coins = float(data.coins)
	_reset_element_inventory()
	if int(data.version) >= 3:
		for symbol in elements: element_inventory[symbol] = int(data.element_inventory.get(symbol, 0))
	refinery=Refinery.new()
	if int(data.version) >= 24: refinery.restore(data.refinery,elements)
	coach_seen={}
	for id in data.get("coach",[]): coach_seen[str(id)]=true
	index_found={}
	for id in data.get("index_found",[]): index_found[str(id)]=true
	fabricator=Fabricator.new()
	if int(data.version) >= 26: fabricator.restore(data.fabricator)
	# Older saves start island Ⅱ locked; their old progress converts to 岛主 XP on the first tick.
	industry=Industry.new()
	if int(data.version) >= 28: industry.restore(data.industry)
	materials = [int(data.materials[0]), int(data.materials[1]), int(data.materials[2])]
	upgrades = int(data.upgrades)
	engineers = int(data.engineers)
	scientists = int(data.scientists)
	crate_count = int(data.crate_count)
	discovered = data.discovered.duplicate(true)
	plots = data.plots.duplicate(true)
	reactors = data.reactors.duplicate(true)
	deliveries = int(data.deliveries)
	total_harvests = int(data.total_harvests)
	visitor_cooldown = float(data.get("visitor_cooldown", 0.0))
	visitor_visits = int(data.get("visitor_visits", 0))
	visitor_skips = int(data.get("visitor_skips", 0))
	science_unlocked = data.get("science_unlocked", []).duplicate(true) if data.get("science_unlocked", []) is Array else []
	science_runs = data.get("science_runs", []).duplicate(true) if data.get("science_runs", []) is Array else []
	science_runs = science_runs.filter(func(item): return item is Dictionary and item.get("result") is Dictionary)
	science_pending.clear()
	if not data.get("science_pending",{}).is_empty(): science_notice="上次研究因退出而中断，可免费重新运行"
	# Interrupted jobs are not charged; the user can restart after reload.
	_dry_harvests = int(data.get("dry_harvests", 0))
	_serial = maxi(int(data.get("serial", reactors.size() + 1)), reactors.size() + 1)
	for i in range(plots.size()):
		var p = plots[i]
		p.rid = int(p.rid)
		p.x = i % 3 - 1 if int(data.version) == 1 else int(p.x)
		p.z = int(i / 3) - 1 if int(data.version) == 1 else int(p.z)
	_append_frontier()
	for r in reactors:
		if int(data.version) < 3: r.atoms = templates[r.template].atoms.duplicate()
		r.plot = int(r.plot)
		r.level = int(r.level)
		r.stock = int(r.stock)
		r.pending = int(r.get("pending", 0))
		r.signature = signature(r)
	_update_order()
	layout.initialize(plots,true)
	_append_frontier()
	_restore_town_serial()
	town_journal.clear()
	if int(data.version)>=8:
		campus.restore(data.campus)
	else:
		campus.setup(engineers,scientists)
	payroll=CampusPayroll.new()
	if data.has("payroll"): payroll.restore(data.payroll)
	campus.work_factor=payroll.work_factor(campus.config)
	storage=IslandStorage.new(); logistics=IslandLogistics.new(); market=IslandMarket.new()
	market.quote_rules=island_rules.visitors
	if int(data.version)>=9:
		storage.restore(data.storage,layout.config.props.keys()+["road"]+Town.rules().items.keys(),island_rules.consumables.keys(),plots)
		if int(data.version)<10: _repair_legacy_references()
		market.restore(data.market,island_rules.visitors,templates,contracts.valid_order)
		logistics.rounds=data.logistics_rounds.duplicate()
		for id in logistics.rounds: logistics.rounds[id]=int(logistics.rounds[id])
		for r in reactors:
			if r.get("installation",{}).is_empty(): continue
			r.installation.fee=int(r.installation.fee)
			for symbol in r.installation.elements: r.installation.elements[symbol]=int(r.installation.elements[symbol])
	else:
		# Previously collected stock moves into the bag; uncollected output remains at the reactor.
		# Legacy pending could exceed stock after selling directly from the furnace: cap before migrating.
		for r in reactors:
			var waiting=mini(int(r.stock),int(r.pending))
			storage.add_product(product_snapshot(r),int(r.stock)-waiting)
			r.stock=waiting; r.pending=waiting
		market.spawn(economy,templates,island_rules.visitors)
		storage.finds["3"]="crystal_fox"
	milestones_claimed=[]
	if int(data.version)>=22:
		for id in data.milestones_claimed: milestones_claimed.append(str(id))
		saved_at=int(data.saved_at)
	else:
		# Goals already reached before v0.23 are marked done without paying them out again.
		saved_at=0
		Milestones.settle_existing(self)
	best_fit={}; star_rewards=0
	if int(data.version)>=23:
		for id in data.best_fit: best_fit[str(id)]=float(data.best_fit[id])
		star_rewards=int(data.star_rewards)
	else:
		# Pre-codex saves: current samples of discovered structures seed the codex; star gifts
		# already within reach are settled without payout.
		for r in reactors:
			var ref_id: String=reference_id(r)
			if float(r.build_left)<=0.0 and ref_id in discovered: best_fit[ref_id]=maxf(float(best_fit.get(ref_id,0.0)),quality(r))
		Codex.settle_existing(self)
	if int(data.version)<25:
		# Pre-index saves: what the reactors already hold counts as found, without a windfall.
		for r in reactors:
			if float(r.build_left)<=0.0: ChemIndex.record(self,structure_data(r).get("index",{}),false)
	sync_gear()
	return true


func _repair_legacy_references() -> void:
	# Correct old mislabelled snapshots without changing amounts, IDs, coordinates or paid income.
	for batch in storage.batches:
		if not str(batch.reference).is_empty(): continue
		var work: Dictionary=batch.work
		var info=sandbox_reference(work)
		if not info.known: continue
		batch.reference=info.reference_id; batch.name=info.name; batch.formula=info.formula
		var specimen={"template":info.reference_id,"sandbox":true,"atoms":work.atoms,"positions":work.positions,"bonds":work.bonds,"mode":work.get("mode","science"),"periodic":work.get("periodic",false),"cell_lengths":work.get("cell",[6.0,6.0,6.0])}
		batch.quality=quality(specimen)

func campus_context() -> Dictionary:
	return {"plots":plots,"reactors":reactors,"buildings":layout.buildings(plots),"plaza_plot":layout.plaza_index,"coins":coins,"deliveries":deliveries,"total_harvests":total_harvests,"templates":templates,"road_links":layout.road_links(plots),"reachable_plots":layout.reachable(plots)}

func _sync_campus_counts() -> void:
	engineers=campus.role_count("engineer")
	scientists=mini(3,campus.people.size()-engineers)

func _campus_transaction(result: Dictionary) -> String:
	if result.get("ready",false):
		coins-=float(result.get("cost",0))
		_sync_campus_counts()
	return str(result.get("message","操作未完成"))

func campus_hire(role: String) -> String:
	return _campus_transaction(campus.hire(role,campus_context()))

## v0.36: lay a PVC irrigation line on Earth from 星锻岛 PVC stock (drought preparation).
func lay_pipe() -> String:
	var need=int(planet.v2.incidents.rules.pipe.pvc)
	if int(industry.items.get("pvc",0))<need: return "需要星锻岛高分子工厂做的 PVC 管材 ×%d" % need
	var message: String=planet.v2.incidents.lay_pipe()
	if message.begins_with("铺设"):
		industry.items["pvc"]=int(industry.items.pvc)-need
		if int(industry.items.pvc)<=0: industry.items.erase("pvc")
	return message

## v0.35: the player approves a graduate's promotion to 星锻岛.
func campus_promote(id: int) -> String:
	var message: String=industry.promote(self,id)
	_sync_campus_counts()
	return message

func campus_dismiss(id: int) -> String:
	var message: String=campus.dismiss(id)
	_sync_campus_counts()
	return message

func campus_resolve_request(id: int, choice: String) -> String:
	return _campus_transaction(campus.resolve_request(id,choice,campus_context()))

func campus_start_research(project_id: String) -> String:
	return _campus_transaction(campus.start_research(project_id,campus_context()))

func campus_assign_post(id: int,post: String) -> String:
	return campus.assign_post(id,post)

func campus_pay_arrears() -> String:
	if payroll.arrears<=0: return "目前没有欠薪"
	var paid=payroll.pay_arrears(coins)
	coins-=paid
	campus.work_factor=payroll.work_factor(campus.config)
	return "已补发%.1f金币，剩余欠薪%.1f" % [paid,payroll.arrears]

## Without a tile position: the first free spot. An empty plot gets a main building, a plot that
## already has one gets another building beside it (v0.27).
func campus_build(plot: int, kind: String) -> String:
	var info=layout.building_info(kind)
	if plot<0 or plot>=plots.size() or info.is_empty(): return "请选择有效地块与建筑"
	if not plots[plot].unlocked or plots[plot].kind in ["reactor","plaza"] or plots[plot].kind in Town.LEGACY_WHOLE: return "建筑需要已开拓的空地或住宅区地块"
	if coins<float(info.cost): return "需要%d金币" % int(info.cost)
	layout.pin(plots[plot])
	var at: Vector2i = town_spot(plot,kind)
	if at.x<0: return "这块地放不下%s了；试试另一块地" % info.name
	var message=town_place(plot,kind,at.x,at.y)
	if message.contains("落成"): return "%s已落成，小路自动连通" % info.name
	return message

func campus_upgrade(plot: int) -> String:
	if plot<0 or plot>=plots.size(): return "地块不存在"
	var p: Dictionary=plots[plot]
	var info=layout.building_info(p.kind)
	if info.is_empty(): return "此建筑没有住宅/工位升级"
	var level=int(p.get("building_level",1))
	if level>=int(info.max_level): return "已达到最高楼层"
	var cost=int(info.upgrade_cost)*level
	if coins<cost: return "升级需要%d金币" % cost
	coins-=cost
	p.building_level=level+1
	layout.mark_changed()
	return "%s升至%d层，容量%d人" % [info.name,level+1,layout.capacity(p)]

## v0.27.1: every opened plot joins the path network by itself. Kept for old callers and saves.
func campus_road(plot: int) -> String:
	if plot<0 or plot>=plots.size() or not plots[plot].unlocked: return "先开拓这块地"
	if not plots[plot].get("road",false):
		plots[plot].road=true
		layout.mark_changed()
	return "小路会自动连通所有已开拓的地块"

func campus_prop(plot: int, slot: int, kind: String) -> String:
	if plot<0 or plot>=plots.size() or not plots[plot].unlocked or slot<0 or slot>7: return "请选择已开拓地块的有效小物件位置"
	if not layout.config.props.has(kind): return "物件不存在"
	if plots[plot].kind=="plaza": return "公共广场保留交通空间，请在外围地块布置"
	var info: Dictionary=layout.config.props[kind]
	if info.get("exploration",false) and kind not in storage.unlocked: return "开拓土地，拾取这个物件后解锁"
	if deliveries<int(info.requires_deliveries): return "完成%d次交付后解锁" % int(info.requires_deliveries)
	var props: Array=plots[plot].get("props",[])
	for prop in props:
		if int(prop.slot)==slot: return "这个位置已有物件，请先收纳"
	layout.pin(plots[plot])
	if not Town.island_free(plots,plot,Rect2i(Town.prop_tile(slot),Vector2i.ONE)).is_empty(): return "这个位置已被建筑或庭院物品占用"
	if int(storage.decorations.get(kind,0))>0: storage.decorations[kind]-=1
	else:
		if coins<float(info.cost): return "金币不足"
		coins-=float(info.cost)
	props.append({"slot":slot,"kind":kind})
	plots[plot].props=props
	layout.mark_changed()
	return "%s已摆放，可与主建筑共用一个地块" % info.name

func campus_remove_prop(plot: int, slot: int) -> String:
	if plot<0 or plot>=plots.size(): return "地块不存在"
	var props: Array=plots[plot].get("props",[])
	for i in range(props.size()):
		if int(props[i].slot)==slot:
			var kind: String=props[i].kind
			storage.decorations[kind]=int(storage.decorations.get(kind,0))+1
			props.remove_at(i)
			layout.mark_changed()
			return "物件已收入工具箱，可以免费再次摆放"
	return "这里没有物件"

func reactor_capacity(r: Dictionary) -> int:
	return int(island_rules.production.base_capacity)+(int(r.level)-1)*int(island_rules.production.capacity_per_level)+(3 if "buffer_storage" in campus.unlocked_materials else 0)

func product_snapshot(r: Dictionary) -> Dictionary:
	var info=structure_data(r)
	var work=reactor_work(r)
	if info.has("cell"): work.periodic=true
	var found: Dictionary=info.get("index",{})
	var snapshot={"id":signature(r),"name":str(info.name),"formula":str(info.formula),"reference":reference_id(r),"quality":quality(r),"work":work}
	# v0.30: the batch remembers what the chemistry index says it is, so the fabricator can read real properties.
	if ChemIndex.is_find(found): snapshot["index"]=str(found.key); snapshot["index_match"]=str(found.match)
	return snapshot

## v0.30: the chemistry-index identity of a stored batch. Older batches are identified from their work.
func batch_index(batch: Dictionary) -> Dictionary:
	var key=str(batch.get("index",""))
	if key!="":
		var entry: Dictionary=ChemIndex.entry_by_key(key)
		if not entry.is_empty(): return {"kind":"molecule" if entry.has("cid") else "crystal","match":str(batch.get("index_match","composition")),"entry":entry,"key":key,"polymorphs":0}
	var work: Dictionary=batch.get("work",{}).duplicate()
	var base: Dictionary=templates.get(str(work.get("baseline_id","")),{})
	if not base.is_empty():
		work["occupancies"]=base.get("occupancies",[]); work["family"]=str(base.get("family","")); work["chapter"]=str(base.get("chapter",""))
	return ChemIndex.identify(work)

## v0.30: gear acts through the digging rule and the refinery speed; both read plain numbers set here.
func sync_gear() -> void:
	planet.v2.nature.pick_hv=fabricator.pick_hv()
	planet.v2.nature.pick_name=fabricator.pick_name()
	# v0.34: an industry drill bit from 星锻岛 counts when it is harder than the fabricator pick.
	if industry.bit_hv()>planet.v2.nature.pick_hv:
		planet.v2.nature.pick_hv=industry.bit_hv(); planet.v2.nature.pick_name=str(Industry.rules().items[industry.bit].name)
	refinery.power_gain=fabricator.refinery_gain()

func _queue_install(r: Dictionary, payload: Dictionary, quote: Dictionary) -> String:
	r["installation"]={"payload":payload.duplicate(true),"remaining":float(island_rules.logistics.installation_seconds),"fee":int(quote.fee),"elements":quote.required.duplicate()}
	return "样品已排队 · 费用已预付；空闲博士沿小路前来装炉。旧炉继续生产，可随时取消并退款。"

func cancel_installation(index: int) -> String:
	if not _valid_index(index) or reactors[index].get("installation",{}).is_empty(): return "没有待装炉任务"
	var job: Dictionary=reactors[index].installation
	# A refund must never silently lose reserved elements at the inventory limit.
	for symbol in job.elements:
		if int(element_inventory.get(symbol,0))+int(job.elements[symbol])>9999: return "元素仓库已满，请先使用部分元素再取消"
	coins+=int(job.fee)
	for symbol in job.elements: element_inventory[symbol]=int(element_inventory.get(symbol,0))+int(job.elements[symbol])
	reactors[index].erase("installation")
	return "已取消装炉，金币与预留元素原数退回"

func _finish_logistics(events: Array) -> void:
	for event in events:
		var r: Dictionary=reactors[int(event.reactor)]
		if event.kind=="collect":
			var result=_collect(r)
			if int(result.units)>0:
				var id=str(int(event.person))
				logistics.rounds[id]=maxi(0,int(logistics.rounds.get(id,0))-1)
				var p=campus.person(int(event.person))
				p.hunger=minf(100,float(p.hunger)+5)
		elif event.kind=="install" and not r.get("installation",{}).is_empty():
			var job: Dictionary=r.installation
			job.remaining=maxf(0,float(job.remaining)-campus.person_efficiency(int(event.person)))
			if float(job.remaining)>0 or not storage.can_add(signature(r),int(r.pending)): continue
			_collect(r)
			var phase_before: String=reactor_phase(r)
			var payload: Dictionary=job.payload
			match str(payload.kind):
				"sandbox": _install_sandbox(r,payload.work)
				"template":
					r.sandbox=false; r.template=payload.template
					r.atoms=templates[r.template].atoms.duplicate(); r.positions=initial_positions(r.template,r.id)
					_reset_product(r)
				"structure":
					r.atoms=payload.atoms.duplicate(); r.positions=payload.positions.duplicate(true); _reset_product(r)
			r.erase("installation"); _structure_cache.clear()
			campus_notice="博士完成装炉：%s。旧批次已保留，新的结构开始生产。" % structure_data(r).formula
			var phase_after: String=reactor_phase(r)
			if phase_after!=phase_before:
				phase_notice={"reactor":str(r.id),"formula":str(structure_data(r).formula),"from":phase_before,"to":phase_after}

func _valid_installation(r: Dictionary) -> bool:
	var job=r.get("installation",{})
	if not job is Dictionary: return false
	if job.is_empty(): return true
	if not _number_ok(job.get("remaining"),0,float(island_rules.logistics.installation_seconds)) or not _number_ok(job.get("fee"),0,100000,true): return false
	if not IslandStorage.counts_ok(job.get("elements"),elements.keys()) or not job.get("payload") is Dictionary: return false
	var p: Dictionary=job.payload
	match str(p.get("kind","")):
		"template": return templates.has(p.get("template",""))
		"sandbox": return p.get("work") is Dictionary and sandbox_validate(p.work) and not p.work.atoms.is_empty()
		"structure": return _valid_atoms(p.get("atoms"),templates[r.template].atoms.size()) and _valid_positions(p.get("positions"),templates[r.template].atoms.size())
	return false

func buy_consumable(kind: String, quantity: int=1) -> String:
	if not island_rules.consumables.has(kind) or quantity<1 or quantity>100: return "请选择有效补给"
	var info: Dictionary=island_rules.consumables[kind]
	var cost=int(info.cost)*quantity
	if coins<cost: return "金币不足，需要%d金币" % cost
	if int(storage.consumables.get(kind,0))+quantity>9999: return "补给库存已满"
	coins-=cost; storage.consumables[kind]=int(storage.consumables.get(kind,0))+quantity
	return "%s ×%d 已收入工具箱；放入博士公寓后使用" % [info.name,quantity]

func supply_dorm(plot: int, kind: String, quantity: int) -> String:
	if plot<0 or plot>=plots.size() or plots[plot].kind!="doctor_dorm" or not island_rules.consumables.has(kind): return "请选择博士公寓"
	if not storage.deposit_food(plot,kind,quantity,int(island_rules.logistics.cupboard_capacity)): return "补给不足或公寓储物柜已满（30份）"
	return "已放入公寓，空闲博士会回家补充体力后收集"

func collect_find(plot: int) -> String:
	var key=str(plot)
	var kind=str(storage.finds.get(key,""))
	if kind.is_empty() or kind=="collected": return "这里没有待拾取的小物件"
	storage.finds[key]="collected"
	if kind not in storage.unlocked: storage.unlocked.append(kind)
	storage.decorations[kind]=int(storage.decorations.get(kind,0))+1
	layout.mark_changed()
	return "发现%s！已收入工具箱，可摆在任意庭院空位" % layout.config.props[kind].name

func store_road(_plot: int) -> String:
	return "小路自动连通所有地块，不需要收纳"

func visitor_candidates(id: int) -> Array:
	var v=market.visitor(id)
	if contracts.is_material(v): return contracts.candidates(self,v)
	return market.candidates(id,storage.batches,economy)

func fulfill_order(visitor_id: int, batch_id: String) -> String:
	var visitor=market.visitor(visitor_id)
	if contracts.is_material(visitor): return contracts.deliver(self,visitor,batch_id)
	var batch=storage.batch(batch_id)
	if visitor.is_empty() or visitor.phase!="visiting": return "这位客人尚未到达或已离开"
	if batch.is_empty(): return "这个批次已用完，请先收集新产物"
	var quote=market.quote(visitor,batch,economy)
	if not quote.ready: return "库存不足或不符合订单，请先生产并收集"
	if not storage.take_product(batch_id,int(visitor.order.quantity)): return "库存已变化，请重试"
	coins+=int(quote.payment); upgrades+=int(quote.catalysts); deliveries+=1; visitor_visits+=1
	market.leave(visitor_id,true)
	return "%s成交！+%d金币%s" % ["精品" if quote.premium else "普通",int(quote.payment)," · 催化晶+1" if quote.premium else ""]

func dismiss_market_visitor(id: int) -> String:
	var v=market.visitor(id)
	if v.is_empty() or v.phase!="visiting": return "这位客人暂时不能接待"
	market.leave(id); visitor_skips+=1
	return "已送别这位客人，其他订单仍然保留"

# --- 0.27 Hometown: many buildings, decorations and pedestals on one plot --------------
# Tiles and footprints live in island_town.gd. uid 0 always means the plot's main building.
func town_items(plot: int) -> Array:
	return plots[plot].get("items",[]) if plot>=0 and plot<plots.size() else []

func town_item(plot: int, uid: int) -> Dictionary:
	for item in town_items(plot):
		if int(item.uid)==uid: return item
	return {}

func town_name(kind: String) -> String:
	if Town.is_building(kind): return str(layout.building_info(kind).get("name",kind))
	return str(Town.info(kind).get("name",kind))

func town_price(kind: String) -> int:
	if Town.is_building(kind): return int(layout.building_info(kind).get("cost",0))
	return int(Town.info(kind).get("cost",0))

## Empty string when the player may buy this kind now, otherwise the reason.
func town_locked(kind: String) -> String:
	var spec: Dictionary=Town.info(kind)
	# v0.35: 星锻岛 furniture is made in the 未来家居工坊, never bought with coins.
	if spec.has("industry"): return "在星锻岛未来家居工坊制作，再送回工具箱"
	if int(spec.get("requires_plots",0))>unlocked_plot_count(): return "开拓%d块土地后解锁" % int(spec.requires_plots)
	if int(spec.get("requires_deliveries",0))>deliveries: return "完成%d次交付后解锁" % int(spec.requires_deliveries)
	return ""

func _town_plot_error(plot: int) -> String:
	if plot<0 or plot>=plots.size() or not plots[plot].unlocked: return "请选择已开拓的地块"
	if plots[plot].kind=="plaza": return "迎客广场保留通行空间，请在其他地块布置"
	if plots[plot].kind in Town.LEGACY_WHOLE: return "这块地是旧版整块装饰，先把它搬到别处"
	return ""

func town_place(plot: int, kind: String, x: int, z: int, rot: int=0) -> String:
	var error=_town_plot_error(plot)
	if not error.is_empty(): return error
	var building=Town.is_building(kind) and not layout.building_info(kind).is_empty()
	if not building and not Town.is_decor(kind): return "没有这种建筑或装饰"
	var p: Dictionary=plots[plot]; layout.pin(p)
	if p.items.size()>=int(Town.rules().max_items_per_plot): return "这块地已经摆得很满了"
	var stored=int(storage.decorations.get(kind,0))
	if not building and stored<=0:
		var locked=town_locked(kind)
		if not locked.is_empty(): return locked
	error=town_fits(plot,kind,Vector2i(x,z),rot)
	if not error.is_empty(): return error
	var price=0 if (not building and stored>0) else town_price(kind)
	if coins<price: return "金币不足，需要%d金币" % price
	coins-=price
	if not building and stored>0: storage.decorations[kind]=stored-1
	var entry={"op":"place","plot":plot,"uid":0,"kind":kind,"paid":price,"toolbox":not building and stored>0}
	if building and p.kind=="empty":
		p.kind=kind; p.building_level=1; p.at=[x,z]
		layout.mark_changed(); _town_log(entry)
		return "%s落成了 · 同一块地还能再建其他建筑和装饰" % town_name(kind)
	var item={"uid":_town_serial,"kind":kind,"x":x,"z":z,"rot":posmod(rot,4) if not building else 0}
	_town_serial+=1
	if building: item.level=1
	if bool(Town.info(kind).get("display",false)): item.show={}
	p.items.append(item)
	layout.mark_changed()
	entry.uid=int(item.uid); _town_log(entry)
	if building: return "%s落成了 · 与同地块的同类建筑共用床位/工位" % town_name(kind)
	return "%s已摆放%s" % [town_name(kind)," · 从工具箱取出" if price==0 else ""]

## Move within a plot (buildings) or to any open plot (decorations). uid 0 moves the main building.
func town_move(plot: int, uid: int, target: int, x: int, z: int, rot: int=0) -> String:
	var error=_town_plot_error(target)
	if not error.is_empty(): return error
	if plot<0 or plot>=plots.size(): return "地块不存在"
	var p: Dictionary=plots[plot]
	if uid==0:
		if not Town.is_building(str(p.kind)): return "这里没有可挪动的主建筑"
		if target!=plot: return "主建筑请用长按拖动搬到另一块空地"
		error=town_fits(plot,str(p.kind),Vector2i(x,z),0,["%d:p" % plot])
		if not error.is_empty(): return error
		var old=Town.primary_anchor(p)
		p.at=[x,z]; layout.mark_changed()
		_town_log({"op":"move","plot":plot,"uid":0,"from":plot,"x":old.x,"z":old.y,"rot":0})
		return "%s已挪到新位置" % town_name(str(p.kind))
	var item=town_item(plot,uid)
	if item.is_empty(): return "找不到这件物品"
	if Town.is_building(str(item.kind)) and target!=plot: return "建筑的落脚格要留在本地块（可以跨出边缘），居民的住址不变"
	var destination: Dictionary=plots[target]; layout.pin(destination)
	error=town_fits(target,str(item.kind),Vector2i(x,z),rot,["%d:%d" % [plot,uid]])
	if not error.is_empty(): return error
	if target!=plot:
		if destination.items.size()>=int(Town.rules().max_items_per_plot): return "那块地已经摆得很满了"
		p.items.erase(item); destination.items.append(item)
	_town_log({"op":"move","plot":target,"uid":uid,"from":plot,"x":int(item.x),"z":int(item.z),"rot":int(item.get("rot",0))})
	item.x=x; item.z=z
	if not Town.is_building(str(item.kind)): item.rot=posmod(rot,4)
	layout.mark_changed()
	return "%s已挪到新位置" % town_name(str(item.kind))

func _town_take_back(item: Dictionary) -> void:
	var show: Dictionary=item.get("show",{})
	if show.is_empty(): return
	if show.type=="mineral":
		var stock: Dictionary=planet.v2.nature.minerals
		stock[show.id]=int(stock.get(show.id,0))+1
	elif planet.v2.construction.miniatures.has(show.id):
		planet.v2.construction.miniatures[show.id].plot=-1; planet.v2.construction.revision+=1
	item.show={}

## Decorations only: back into the toolbox, placeable again for free.
func town_store(plot: int, uid: int) -> String:
	var item=town_item(plot,uid)
	if item.is_empty(): return "找不到这件物品"
	if Town.is_building(str(item.kind)): return "建筑不能收进工具箱，可以出售"
	_town_take_back(item)
	plots[plot].items.erase(item)
	storage.decorations[item.kind]=int(storage.decorations.get(item.kind,0))+1
	layout.mark_changed()
	_town_log({"op":"store","plot":plot,"item":item.duplicate(true)})
	return "%s已收入工具箱，可以免费再次摆放" % town_name(str(item.kind))

func _town_building_in_use(plot: int, item: Dictionary) -> String:
	var kind=Town.building_kind(str(item.kind))
	var remaining=layout.kind_capacity(plots,plot,kind)-layout.capacity({"kind":kind,"building_level":int(item.level)})
	for role in campus.config.roles:
		if kind in campus.config.roles[role].housing:
			var living=0
			for person in campus.people:
				if int(person.home_plot)==plot and person.role==role: living+=1
			if living>remaining: return "还有%d位居民住在这里，先给他们找到其他床位" % living
			return ""
	if remaining<=0:
		for person in campus.people:
			if int(person.work_plot)==plot or (int(person.target_plot)==plot and not bool(person.get("arrived",false))): return "还有居民在这里工作或正在赶来"
	return ""

func town_sell(plot: int, uid: int) -> String:
	var item=town_item(plot,uid)
	if item.is_empty(): return "找不到这件物品"
	if Town.is_building(str(item.kind)):
		var busy=_town_building_in_use(plot,item)
		if not busy.is_empty(): return busy
	_town_take_back(item)
	if Town.info(str(item.kind)).has("industry"):
		plots[plot].items.erase(item); storage.decorations[str(item.kind)]=int(storage.decorations.get(str(item.kind),0))+1
		layout.mark_changed()
		return "%s已收回工具箱" % town_name(str(item.kind))
	var spent=town_price(str(item.kind))
	if Town.is_building(str(item.kind)):
		var info=layout.building_info(str(item.kind))
		for level in range(1,int(item.level)): spent+=int(info.upgrade_cost)*level
	var refund=int(floor(spent*float(Town.rules().sell_ratio)))
	plots[plot].items.erase(item); coins+=refund
	layout.mark_changed()
	return "%s已出售 · 退回%d金币" % [town_name(str(item.kind)),refund]

func town_upgrade(plot: int, uid: int) -> String:
	if uid==0: return campus_upgrade(plot)
	var item=town_item(plot,uid)
	if item.is_empty() or not Town.is_building(str(item.kind)): return "这件物品不能升级"
	var info=layout.building_info(str(item.kind))
	var level=int(item.level)
	if level>=int(info.max_level): return "已达到最高楼层"
	var cost=int(info.upgrade_cost)*level
	if coins<cost: return "升级需要%d金币" % cost
	coins-=cost; item.level=level+1
	layout.mark_changed()
	return "%s升至%d层 · %s" % [info.name,level+1,TIER_NAMES[Town.tier(level+1,int(info.max_level))-1]]

const TIER_NAMES=["木屋外观","砖房外观","玻璃幕墙外观"]

## Put a mined mineral specimen or a river miniature on a pedestal. what = {"type","id"}.
func town_exhibit(plot: int, uid: int, what: Dictionary) -> String:
	var item=town_item(plot,uid)
	if item.is_empty() or not bool(Town.info(str(item.kind)).get("display",false)): return "请选择一个展台"
	var id=str(what.get("id",""))
	match str(what.get("type","")):
		"mineral":
			var spec: Dictionary=preload("res://scripts/planet_geology.gd").info(id)
			if spec.is_empty() or id in ["topsoil","bedrock"]: return "这种物质不能作为标本展出"
			if int(planet.v2.nature.minerals.get(id,0))<1: return "背包里没有%s；先去星球地下采掘" % spec.name
			_town_take_back(item)
			planet.v2.nature.minerals[id]=int(planet.v2.nature.minerals[id])-1
			item.show={"type":"mineral","id":id}
		"mini":
			var boxes: Dictionary=planet.v2.construction.miniatures
			if not boxes.has(id): return "找不到这件河湾作品"
			if int(boxes[id].plot)!=-1: return "这件作品已经摆在别处，先收回"
			_town_take_back(item)
			boxes[id].plot=-2; planet.v2.construction.revision+=1
			item.show={"type":"mini","id":id}
		_: return "请选择要展示的标本或作品"
	layout.mark_changed()
	return "展品已摆上%s · 名牌写明来源" % town_name(str(item.kind))

func town_unexhibit(plot: int, uid: int) -> String:
	var item=town_item(plot,uid)
	if item.is_empty() or item.get("show",{}).is_empty(): return "这个展台是空的"
	_town_take_back(item)
	layout.mark_changed()
	return "展品已收回背包"

# --- v0.31 Builder: island-wide tiles, undo, recycle ------------------------------------
## Placement check with the anchor in plot and the footprint free across the island.
func town_fits(plot: int, kind: String, at: Vector2i, rot: int=0, ignore: Array=[]) -> String:
	return Town.island_fits(plots,plot,kind,at,rot,ignore)

## A free anchor for kind in plot, or (-1,-1): centred on an empty plot, else the first free spot.
func town_spot(plot: int, kind: String) -> Vector2i:
	if plot<0 or plot>=plots.size(): return Vector2i(-1,-1)
	if plots[plot].kind=="empty":
		var at=Town.default_anchor(plots[plot],kind)
		if town_fits(plot,kind,at).is_empty(): return at
	return Town.island_first_fit(plots,plot,kind)

## What sits on a global tile: {"plot", "id"} with id "p", "s<slot>" or the uid as a string; {} if free.
func town_at(global: Vector2i) -> Dictionary:
	var plot=int(Town.coord_lookup(plots).get(Town.plot_of(global),-1))
	if plot<0: return {}
	var who=Town.island_cells(plots,plot).get(global)
	return {} if who==null else {"plot":int(who[0]),"id":str(who[1])}

## Decorations a recycle would collect: one plot's paths and decor, or (plot -1) every path.
func town_recyclable(plot: int) -> Array:
	var out: Array=[]
	for i in range(plots.size()):
		if plot>=0 and i!=plot: continue
		for item in plots[i].get("items",[]):
			if Town.is_building(str(item.kind)): continue
			if plot<0 and str(Town.info(str(item.kind)).get("category",""))!="path": continue
			out.append([i,int(item.uid)])
	return out

## One tap: everything town_recyclable() lists goes into the toolbox as one undo step.
func town_recycle(plot: int) -> String:
	var list=town_recyclable(plot)
	if list.is_empty(): return "这里没有可回收的小路或装饰" if plot>=0 else "岛上还没有铺小路"
	town_group_begin()
	for pair in list: town_store(int(pair[0]),int(pair[1]))
	town_group_end()
	return "已回收%d件%s到工具箱 · 可以撤销，也可以免费再摆" % [list.size(),"小路" if plot<0 else "小路与装饰"]

func town_group_begin() -> void:
	town_journal.append([]); _town_grouping=true
	while town_journal.size()>TOWN_JOURNAL_LIMIT: town_journal.pop_front()

func town_group_end() -> void:
	_town_grouping=false
	if not town_journal.is_empty() and town_journal.back().is_empty(): town_journal.pop_back()

func _town_log(entry: Dictionary) -> void:
	if _town_undoing: return
	if _town_grouping and not town_journal.is_empty(): town_journal.back().append(entry); return
	town_journal.append([entry])
	while town_journal.size()>TOWN_JOURNAL_LIMIT: town_journal.pop_front()

func _town_group_text(group: Array) -> String:
	var verbs={"place":"摆放","move":"挪动","store":"回收"}
	var counts={}; var order: Array=[]
	for entry in group:
		var kind=str(entry.item.kind) if entry.op=="store" else str(entry.get("kind","")) if entry.op=="place" else ""
		if entry.op=="move":
			var p: Dictionary=plots[int(entry.plot)]
			kind=str(p.kind) if int(entry.uid)==0 else str(town_item(int(entry.plot),int(entry.uid)).get("kind",""))
		var key="%s%s" % [verbs.get(entry.op,""),town_name(kind)]
		if not counts.has(key): order.append(key)
		counts[key]=int(counts.get(key,0))+1
	var parts: Array=[]
	for key in order: parts.append(key if int(counts[key])==1 else "%s×%d" % [key,int(counts[key])])
	return "、".join(parts)

## Label for the undo button, empty when there is nothing to undo.
func town_undo_text() -> String:
	return "" if town_journal.is_empty() else _town_group_text(town_journal.back())

## Undo the newest group; coins and toolbox stock go back exactly as they were taken.
func town_undo() -> String:
	if town_journal.is_empty(): return "没有可以撤销的操作"
	var group: Array=town_journal.pop_back()
	var text=_town_group_text(group)
	_town_undoing=true
	var failed=""
	for i in range(group.size()-1,-1,-1):
		var message=_town_revert(group[i])
		if not message.is_empty(): failed=message
	_town_undoing=false
	layout.mark_changed()
	return "已撤销：" + text if failed.is_empty() else "部分没能撤销：" + failed

func _town_revert(entry: Dictionary) -> String:
	var plot=int(entry.plot)
	if plot<0 or plot>=plots.size(): return "地块不存在"
	var p: Dictionary=plots[plot]
	match str(entry.op):
		"place":
			var kind=str(entry.kind)
			if int(entry.uid)==0:
				if str(p.kind)!=kind: return "%s已经不在原处" % town_name(kind)
				if int(p.get("building_level",1))>1: return "%s已经升级，请改用出售" % town_name(kind)
				var busy=_town_building_in_use(plot,{"kind":kind,"level":1})
				if not busy.is_empty(): return busy
				p.kind="empty"; p.erase("at"); p.building_level=1
				coins+=float(entry.paid)
				return ""
			var item=town_item(plot,int(entry.uid))
			if item.is_empty(): return "%s已经不在原处" % town_name(kind)
			if Town.is_building(kind):
				if int(item.level)>1: return "%s已经升级，请改用出售" % town_name(kind)
				var busy=_town_building_in_use(plot,item)
				if not busy.is_empty(): return busy
			_town_take_back(item)
			p.items.erase(item)
			if bool(entry.toolbox): storage.decorations[kind]=int(storage.decorations.get(kind,0))+1
			else: coins+=float(entry.paid)
			return ""
		"move":
			var message=town_move(plot,int(entry.uid),int(entry.from),int(entry.x),int(entry.z),int(entry.rot))
			return "" if message.contains("已挪到") else message
		"store":
			var item: Dictionary=entry.item.duplicate(true)
			var kind=str(item.kind)
			if int(storage.decorations.get(kind,0))<=0: return "工具箱里的%s已经用掉了" % town_name(kind)
			var error=town_fits(plot,kind,Vector2i(int(item.x),int(item.z)),int(item.get("rot",0)))
			if not error.is_empty(): return error
			storage.decorations[kind]=int(storage.decorations[kind])-1
			if item.has("show"): item.show={}
			p.items.append(item)
			return ""
	return ""

## Cross-plot save rules: unique uids and exhibits that really exist exactly once.
func _valid_town(data: Dictionary) -> bool:
	if not Town.valid_island(data.plots): return false
	var uids={}
	var shown={}
	var boxes: Dictionary=data.get("planet",{}).get("v2",{}).get("construction",{}).get("miniatures",{})
	for p in data.plots:
		for item in p.get("items",[]):
			if uids.has(int(item.uid)): return false
			uids[int(item.uid)]=true
			var show: Dictionary=item.get("show",{})
			if show.is_empty(): continue
			if show.type=="mineral":
				if preload("res://scripts/planet_geology.gd").info(str(show.id)).is_empty() or show.id in ["topsoil","bedrock"]: return false
			else:
				if not boxes.has(show.id) or int(boxes[show.id].get("plot",-1))!=-2 or shown.has(show.id): return false
				shown[show.id]=true
	for id in boxes:
		if int(boxes[id].get("plot",-1))==-2 and not shown.has(id): return false
	return true

func _restore_town_serial() -> void:
	_town_serial=1
	for p in plots:
		for item in p.get("items",[]): _town_serial=maxi(_town_serial,int(item.uid)+1)
