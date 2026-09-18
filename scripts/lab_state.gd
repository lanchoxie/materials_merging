extends RefCounted

const CampusSim = preload("res://scripts/campus_sim.gd")
const CampusLayout = preload("res://scripts/campus_layout.gd")
const CampusPayroll = preload("res://scripts/campus_payroll.gd")
var campus = CampusSim.new()
var layout = CampusLayout.new()
var payroll = CampusPayroll.new()
var campus_notice: String = ""
var _campus_clock: float = 0
var _production_clock: float = 0

const Economy = preload("res://scripts/economy.gd")
const Specimen = preload("res://scripts/specimen.gd")
const StructureSandbox = preload("res://scripts/structure_sandbox.gd")
const SandboxReference = preload("res://scripts/sandbox_reference.gd")
const SciencePipeline = preload("res://scripts/science_pipeline.gd")
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

const MAX_UNLOCKED_PLOTS = 128
const MAX_SAVED_PLOTS = 1024
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

func _init():
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
		r.positions[1][0] += 0.20
		r.positions[2][1] += 0.12
		r.signature = signature(r)
		reactors.append(r)
		plots[4].kind = "reactor"
		plots[4].rid = 0
		discovered.append("water")
	_update_order()
	layout.initialize(plots)
	_append_frontier()
	campus.setup(engineers,scientists)

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
	return SandboxReference.describe(work,templates,elements)

func sandbox_reactor_quote(index: int, work: Dictionary) -> Dictionary:
	var q := {"ready":false,"changed":false,"fee":0,"required":{},"message":"请选择反应炉"}
	if not _valid_index(index): return q
	if not sandbox_validate(work) or work.atoms.is_empty(): q.message="至少放一个原子；结构必须在工作台范围内"; return q
	var r: Dictionary = reactors[index]
	if float(r.build_left)>0: q.message="请等待反应炉建好"; return q
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
	q.message = "需要 %d 金币；确认后清空旧产物" % q.fee
	if coins < q.fee: q.message="金币不足：本级固定%d金币"%q.fee; return q
	for s in q.required:
		if int(element_inventory.get(s,0))<int(q.required[s]): q.message="%s不足：需要%d，库存%d"%[s,q.required[s],element_inventory.get(s,0)]; return q
	q.ready=true
	return q

func apply_sandbox_to_reactor(index: int, work: Dictionary) -> String:
	var q := sandbox_reactor_quote(index,work)
	if not q.ready: return q.message
	coins -= int(q.fee)
	for s in q.required: element_inventory[s] -= int(q.required[s])
	var r: Dictionary=reactors[index]
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
	return "作品已装入%s · -%d金币 · %s"%[r.id,q.fee,"按参考生产" if not reference_id(r).is_empty() else "生产展示样品，等待创意收购商"]

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
		"level": 1, "positions": templates[template_id].positions.duplicate(true),
		"progress": 0.0, "stock": 0, "pending": 0, "stored_coins": 0.0,
		"build_left": build_time, "signature": ""}
	r.atoms = templates[template_id].atoms.duplicate()
	_serial += 1
	r.signature = signature(r)
	return r

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
			_structure_cache[custom_key] = SandboxReference.describe(work,templates,elements)
		return _structure_cache[custom_key]
	var key: String = str(r.template) + ":" + ",".join(atoms)
	if not _structure_cache.has(key):
		# Bound the cache during long sandbox sessions.
		if _structure_cache.size() > 256: _structure_cache.clear()
		_structure_cache[key] = Specimen.describe(r.template,atoms,templates,elements)
	return _structure_cache[key]

func reference_id(r: Dictionary) -> String:
	return str(structure_data(r).reference_id)

func _reset_element_inventory() -> void:
	element_inventory.clear()
	for symbol in elements:
		element_inventory[symbol] = int(economy.rules.element_shop.starter.get(symbol,0))

func purchase_quote(symbol: String, quantity: int) -> Dictionary:
	var q = {"ready":false,"unit_price":0,"total":0,"message":"请选择有效的元素与数量"}
	if not elements.has(symbol) or quantity < 1 or quantity > 99: return q
	q.unit_price = int(economy.rules.element_shop.prices.get(symbol,0))
	if q.unit_price <= 0: return q
	q.total = q.unit_price * quantity
	q.ready = coins >= q.total and int(element_inventory.get(symbol,0)) + quantity <= 9999
	q.message = "库存已满或金币不足" if not q.ready else "购买%d份%s需要%d金币" % [quantity,symbol,q.total]
	return q

func buy_elements(symbol: String, quantity: int) -> String:
	var q: Dictionary = purchase_quote(symbol,quantity)
	if not q.ready: return q.message
	coins -= int(q.total)
	element_inventory[symbol] = int(element_inventory.get(symbol,0)) + quantity
	return "元素入库：%s × %d · -%d 金币" % [symbol,quantity,q.total]

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
		result.rate = 0.0 if float(r.get("build_left",0.0)) > 0.0 else float(economy.rules.element_shop.exploration_rate)
	return result

func total_income() -> float:
	var result = 0.0
	for r in reactors:
		result += income(r)
	return result

func tick(delta: float):
	poll_science()
	if not is_finite(delta) or delta <= 0.0:
		return
	delta = minf(delta, 3600.0)
	_campus_clock += delta
	if _campus_clock >= 1.0:
		var payroll_result: Dictionary=payroll.tick(_campus_clock,campus.people,campus.config,coins)
		coins-=float(payroll_result.paid)
		campus.work_factor=payroll.work_factor(campus.config)
		var campus_result: Dictionary=campus.tick(_campus_clock,campus_context())
		_campus_clock=0.0
		if not campus_result.get("notifications",[]).is_empty(): campus_notice="；".join(campus_result.notifications)
		if payroll_result.settled:
			campus_notice="已发放薪酬 %.1f 金币%s" % [payroll_result.paid,"；欠薪 %.1f，工作效率暂为75%%，收获后可补发" % payroll.arrears if payroll.arrears>0 else ""]
	_production_clock += delta
	if _production_clock < 0.2: return
	delta=_production_clock
	_production_clock=0.0
	visitor_cooldown = maxf(0.0, visitor_cooldown - delta)
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
		r.stored_coins = minf(100000000.0, float(r.stored_coins) + income(r) * active_time)
		# Unrecognized chemistry earns only the explicit exploration stipend.
		# It cannot create sellable units or building-material drops.
		if reference_id(r).is_empty() and not r.get("sandbox",false): continue
		var speed = (0.35 + quality(r) * 0.65) * (1.0 + (int(r.level) - 1) * 0.35) / 7.0
		r.progress = float(r.progress) + active_time * speed
		var produced = int(floor(float(r.progress)))
		if produced > 0:
			r.progress = fmod(float(r.progress), 1.0)
			r.stock = mini(1000000, int(r.stock) + produced)
			r.pending = mini(1000000, int(r.get("pending", 0)) + produced)

func click_energy() -> String:
	coins = minf(100000000.0, coins + 2.0)
	return "+2 金币 · 微光正在聚集"

func edit_cost(r: Dictionary) -> int:
	return 12 * int(r.level) * int(r.level)

func upgrade_cost(r: Dictionary) -> int:
	return 90 * int(r.level) * int(r.level)

func _collect(r: Dictionary) -> Dictionary:
	var result = {"coins": 0.0, "drops": 0, "units": 0}
	if float(r.build_left) > 0.0 or (int(r.get("pending", 0)) == 0 and float(r.stored_coins) < 1.0):
		return result
	result.coins = float(r.stored_coins)
	coins = minf(100000000.0, coins + result.coins)
	r.stored_coins = 0.0
	var units = int(r.get("pending", 0))
	r.pending = 0
	result.units = units
	for unit in range(units if not reference_id(r).is_empty() else 0):
		_dry_harvests += 1
		if rng.randf() < 0.38 or _dry_harvests >= 5:
			var selected = rng.randi_range(0, 2)
			if _dry_harvests >= 5:
				selected = materials.find(materials.min())
			materials[selected] = mini(1000000, int(materials[selected]) + 1)
			result.drops += 1
			_dry_harvests = 0
	total_harvests += units
	var ref_id: String = reference_id(r)
	if units > 0 and not ref_id.is_empty() and not discovered.has(ref_id):
		discovered.append(ref_id)
	return result

func harvest(index: int) -> String:
	if not _valid_index(index):
		return "请先选择反应炉"
	var result = _collect(reactors[index])
	if result.coins <= 0.0 and result.units == 0:
		return "反应炉正在准备，稍后再来收获"
	return "收获 +%d 金币 · +%d 建材 · %d 份产物入库" % [int(result.coins), result.drops, result.units]

func harvest_all() -> String:
	var earned = 0.0
	var drops = 0
	for r in reactors:
		var result = _collect(r)
		earned += result.coins
		drops += result.drops
	return "全岛收获 +%d 金币 · +%d 建材" % [int(earned), drops]

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
			additions.append({"x": coordinate.x, "z": coordinate.y, "unlocked": false, "kind": "empty", "rid": -1,"road":false,"building_level":1,"props":[]})
	plots.append_array(additions)

func buy_plot(index: int) -> String:
	if index < 0 or index >= plots.size():
		return "请选择岛上的地块"
	if plots[index].unlocked:
		return "这块土地已经开放了"
	if unlocked_plot_count() >= MAX_UNLOCKED_PLOTS:
		return "本版可开拓128块土地；后续版本会继续扩展岛屿"
	if not can_expand(index):
		return "请从已开拓土地相邻的边缘继续扩建"
	var cost = plot_cost(index)
	for amount in materials:
		if int(amount) < cost:
			return "开拓这块土地需要三种建材各%d份；收获产物有机会获得" % cost
	for i in range(3):
		materials[i] -= cost
	plots[index].unlocked = true
	plots[index].road=false
	layout.mark_changed()
	_append_frontier()
	return "新土地已开拓！可以放置反应炉或装饰"

func place_reactor(plot_index: int, template_id: String = "water") -> String:
	if plot_index < 0 or plot_index >= plots.size() or not templates.has(template_id):
		return "请选择有效的土地和结构"
	if templates[template_id].get("substitution_only",false) and template_id not in campus.unlocked_materials:
		return "这个结构需要在原子工作台中替换元素来发现"
	if not plots[plot_index].unlocked or plots[plot_index].kind != "empty":
		return "请在已开拓的空地上建造"
	if coins < 100.0:
		return "建造反应炉需要100金币"
	coins -= 100.0
	var r = _new_reactor(plot_index, template_id, 12.0)
	reactors.append(r)
	plots[plot_index].kind = "reactor"
	plots[plot_index].rid = reactors.size() - 1
	layout.mark_changed()
	return "反应炉开始建造 · 工程师越多，建造越快"

const DECORATIONS = {"garden":{"name":"晶体花园","cost":35},"house":{"name":"工程师小屋","cost":60},"road":{"name":"星砂小径","cost":18},"fence":{"name":"木质围栏","cost":24},"sculpture":{"name":"原子纪念雕塑","cost":85}}

func place_decoration(plot_index: int, kind: String) -> String:
	if plot_index < 0 or plot_index >= plots.size() or not DECORATIONS.has(kind): return "请选择有效的土地和装饰"
	if not plots[plot_index].unlocked or plots[plot_index].kind != "empty": return "装饰需要一块已开拓的空地"
	if kind == "sculpture" and deliveries < 3: return "完成3次交付，解锁原子纪念雕塑"
	var info: Dictionary = DECORATIONS[kind]
	if coins < int(info.cost): return "金币不足，需要%d金币" % int(info.cost)
	coins -= int(info.cost)
	plots[plot_index].kind = kind
	layout.mark_changed()
	return "%s落成了" % info.name

func move_building(source: int, target: int) -> String:
	if source < 0 or source >= plots.size() or target < 0 or target >= plots.size(): return "请选择有效地块"
	var origin: Dictionary = plots[source]
	if origin.kind=="plaza": return "广场是公共交通入口，不可搬迁"
	var destination: Dictionary = plots[target]
	if not origin.unlocked or origin.kind == "empty": return "这里没有可搬迁的建筑"
	if not destination.unlocked or destination.kind != "empty": return "请选择已开拓的空地"
	destination.kind = origin.kind
	destination.rid = origin.rid
	destination.building_level=origin.get("building_level",1)
	origin.building_level=1
	for resident in campus.people:
		if int(resident.home_plot)==source: resident.home_plot=target
		if int(resident.work_plot)==source: resident.work_plot=target
		if int(resident.target_plot)==source:
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
	return "反应炉升至Lv.%d · 生产加快；本级每次编辑固定%d金币" % [r.level, edit_cost(r)]

func _update_order():
	order = economy.make_order(deliveries+visitor_skips, templates)
	order.accept_exploration = (deliveries+visitor_skips)%4==3
	if order.accept_exploration:
		order.name="星球创意展策展人"
		order.story="收集自创作品做成小岛展览。按展示样品收购，不评价真实稳定性；无精品催化晶。"

func dismiss_visitor() -> String:
	if not visitor_available(): return visitor_countdown_text()
	visitor_skips += 1
	visitor_visits += 1
	visitor_cooldown=float(economy.rules.orders.visitor_cooldown_seconds)
	_update_order()
	return "已送别访客，下一位正在赶来"

func delivery_quote(index: int) -> Dictionary:
	if not _valid_index(index):
		return {}
	var r: Dictionary = reactors[index]
	var ref_id: String = reference_id(r)
	var quote: Dictionary = economy.quote(ref_id, quality(r), int(r.stock), float(r.build_left) > 0.0, order)
	quote.known = not ref_id.is_empty()
	quote.exploration = bool(order.get("accept_exploration",false)) and r.get("sandbox",false) and ref_id.is_empty()
	if ref_id.is_empty():
		quote.ready = quote.exploration and int(r.stock)>=int(order.quantity) and float(r.build_left)<=0
		quote.payment = 18 if quote.exploration else 0
		quote.catalysts = 0
		quote.premium = false
	if order.get("accept_exploration",false) and quote.known:
		quote.premium=false
		quote.catalysts=0
		quote.payment=18
	return quote

func visitor_available() -> bool:
	return visitor_cooldown <= 0.0

func visitor_countdown_text() -> String:
	if visitor_available(): return "收购商已到访 · 可以接待"
	var seconds := maxi(1, ceili(visitor_cooldown))
	return "下一位收购商约 %02d:%02d 后到访" % [seconds / 60, seconds % 60]

func market_candidates() -> Array:
	var candidates: Array = []
	for i in range(reactors.size()):
		var quote: Dictionary = delivery_quote(i)
		quote.known = quote.get("known", false)
		quote.score = economy.ranking_score(quote)
		quote.reason = economy.ranking_reason(quote)
		quote.index = i
		candidates.append(quote)
	# Stable insertion sort keeps reactor order when two offers are equal.
	for i in range(1, candidates.size()):
		var current: Dictionary = candidates[i]
		var j := i - 1
		while j >= 0 and float(candidates[j].score) < float(current.score):
			candidates[j + 1] = candidates[j]
			j -= 1
		candidates[j + 1] = current
	return candidates

func deliver(index: int) -> String:
	if not _valid_index(index):
		return "请选择要交付的反应炉"
	if not visitor_available():
		return visitor_countdown_text()
	var r = reactors[index]
	if reference_id(r).is_empty() and not delivery_quote(index).get("exploration",false):
		return "探索样品暂无适用参考，不能交付科研订单"
	if float(r.build_left) > 0.0 or int(r.stock) < int(order.quantity):
		return "买家需要3份产物，请等待反应炉完成生产"
	var quote: Dictionary = delivery_quote(index)
	var premium: bool = quote.premium
	var payment: int = quote.payment
	r.stock -= int(order.quantity)
	coins += payment
	if premium:
		upgrades += 1
	var ref_id: String = reference_id(r)
	if not ref_id.is_empty() and not discovered.has(ref_id):
		discovered.append(ref_id)
	deliveries += 1
	visitor_visits += 1
	visitor_cooldown = float(economy.rules.orders.get("visitor_cooldown_seconds", 45))
	_update_order()
	return "精品成交！+%d 金币 · 精品催化晶 +1" % payment if premium else "普通成交 +%d 金币；下一张订单已到达" % payment

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
	quote.fee = edit_cost(r)
	if coins < quote.fee:
		quote.message = "本级确认编辑需要%d金币" % quote.fee
		return quote
	for symbol in quote.required:
		if int(element_inventory.get(symbol,0)) < int(quote.required[symbol]):
			quote.message = "%s不足：需要%d份，仓库有%d份" % [symbol,quote.required[symbol],element_inventory.get(symbol,0)]
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
	r.positions = positions.duplicate(true)
	r.atoms = atoms.duplicate()
	_reset_product(r)
	return "结构已保存 · -%d 金币；旧产物已清空。%s" % [quote.fee,"识别为"+quote.formula if quote.known else "探索样品暂不评定精品"]

func change_template(index: int, template_id: String) -> String:
	if not _valid_index(index) or not templates.has(template_id):
		return "请选择有效的反应炉和结构"
	if templates[template_id].get("substitution_only",false) and template_id not in campus.unlocked_materials:
		return "这个结构只能通过元素替换获得，不能直接装载"
	var r = reactors[index]
	if float(r.build_left) > 0.0:
		return "反应炉建好后才能更换结构"
	if reference_id(r) == template_id:
		return "反应炉已经使用这个结构；修改坐标请使用原子编辑器"
	if coins < 25.0:
		return "更换结构需要25金币"
	coins -= 25.0
	r.sandbox = false
	r.template = template_id
	r.positions = templates[template_id].positions.duplicate(true)
	r.atoms = templates[template_id].atoms.duplicate()
	_reset_product(r)
	return "新结构已装载 · -25金币；旧库存与待收获金币已清空"

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
		path = root + "/save.json"
	if not _save_path_allowed(path):
		return "保存失败：存档只能写入专用的saves目录"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) != OK:
		return "保存失败：无法创建存档目录"
	var snapshot = {"version": 8, "campus":campus.serialize(), "payroll":payroll.serialize(), "coins": coins, "materials": materials, "upgrades": upgrades,
		"element_inventory":element_inventory,
		"engineers": engineers, "scientists": scientists, "crate_count": crate_count,
		"discovered": discovered, "plots": plots, "reactors": reactors,
		"deliveries": deliveries, "total_harvests": total_harvests,
		"dry_harvests": _dry_harvests, "serial": _serial,
		"visitor_cooldown": visitor_cooldown, "visitor_visits": visitor_visits, "visitor_skips": visitor_skips,
		"science_unlocked": science_unlocked, "science_runs": science_runs, "science_pending": science_pending}
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "保存失败：无法写入存档"
	file.store_string(JSON.stringify(snapshot, "\t"))
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
	if not data is Dictionary or not _number_ok(data.get("version"), 1, 8, true):
		return false
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
	if not _number_ok(data.get("dry_harvests", 0), 0, 4, true) or not _number_ok(data.get("serial", 1), 1, 1000, true):
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
	return open_count <= MAX_UNLOCKED_PLOTS+1

func load_game(path: String = "") -> bool:
	if path.is_empty():
		path = save_root_for_platform(OS.get_name()) + "/save.json"
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
		if file.get_length() > 4194304:
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
	coins = float(data.coins)
	_reset_element_inventory()
	if int(data.version) >= 3:
		for symbol in elements: element_inventory[symbol] = int(data.element_inventory.get(symbol, 0))
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
	if int(data.version)>=8:
		campus.restore(data.campus)
	else:
		campus.setup(engineers,scientists)
	payroll=CampusPayroll.new()
	if data.has("payroll"): payroll.restore(data.payroll)
	campus.work_factor=payroll.work_factor(campus.config)
	return true


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

func campus_dismiss(id: int) -> String:
	var message: String=campus.dismiss(id)
	_sync_campus_counts()
	return message

func campus_resolve_request(id: int, choice: String) -> String:
	return _campus_transaction(campus.resolve_request(id,choice,campus_context()))

func campus_start_research(project_id: String) -> String:
	return _campus_transaction(campus.start_research(project_id,campus_context()))

func campus_pay_arrears() -> String:
	if payroll.arrears<=0: return "目前没有欠薪"
	var paid=payroll.pay_arrears(coins)
	coins-=paid
	campus.work_factor=payroll.work_factor(campus.config)
	return "已补发%.1f金币，剩余欠薪%.1f" % [paid,payroll.arrears]

func campus_build(plot: int, kind: String) -> String:
	var info=layout.building_info(kind)
	if plot<0 or plot>=plots.size() or info.is_empty(): return "请选择有效地块与建筑"
	if not plots[plot].unlocked or plots[plot].kind!="empty": return "建筑需要已开拓的空地"
	if coins<float(info.cost): return "需要%d金币" % int(info.cost)
	coins-=float(info.cost)
	plots[plot].kind=kind
	plots[plot].building_level=1
	layout.mark_changed()
	return "%s已落成；请铺设小路连通广场" % info.name

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

func campus_road(plot: int) -> String:
	if plot<0 or plot>=plots.size() or not plots[plot].unlocked: return "先开拓这块地"
	if plots[plot].get("road",false): return "这里已经铺好小路，相邻小路会自动接通"
	var cost=int(layout.config.roads.cost)
	if coins<cost: return "铺路需要%d金币" % cost
	coins-=cost
	plots[plot].road=true
	layout.mark_changed()
	return "小路铺好了，相邻已铺小路自动连接"

func campus_prop(plot: int, slot: int, kind: String) -> String:
	if plot<0 or plot>=plots.size() or not plots[plot].unlocked or slot<0 or slot>7: return "请选择已开拓地块的有效小物件位置"
	if not layout.config.props.has(kind): return "物件不存在"
	if plots[plot].kind=="plaza": return "公共广场保留交通空间，请在外围地块布置"
	var info: Dictionary=layout.config.props[kind]
	if deliveries<int(info.requires_deliveries): return "完成%d次交付后解锁" % int(info.requires_deliveries)
	var props: Array=plots[plot].get("props",[])
	for prop in props:
		if int(prop.slot)==slot: return "这个位置已有物件，请先收纳"
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
			coins+=float(layout.config.props[kind].cost)
			props.remove_at(i)
			layout.mark_changed()
			return "物件已收回，返还原价金币"
	return "这里没有物件"
