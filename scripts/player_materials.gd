extends RefCounted
## Bounded, immutable sample archive. Collection costs one specimen; hypotheses cost no real goods.
var fixture=preload("res://scripts/player_fixture.gd").new()
var records: Dictionary={}
var designs: Dictionary={}

func identity(work: Dictionary) -> String:
	var shape={}
	for key in ["atoms","positions","bonds","mode","periodic","cell_lengths"]:
		shape[key]=work.get(key,"science" if key=="mode" else false if key=="periodic" else [6,6,6] if key=="cell_lengths" else [])
	return fixture.canonical(shape).sha256_text().substr(0,32)

func archive(state,batch_id: String) -> String:
	var batch=state.storage.batch(batch_id)
	if batch.is_empty() or int(batch.quantity)<1 or not state.sandbox_validate(batch.work) or batch.work.atoms.is_empty(): return "请先收集一份有效结构样品"
	var id=identity(batch.work)
	if records.has(id): return "这个结构已经留样；不会重复消耗样品"
	if records.size()>=int(fixture.rules.max_records): return "材料档案已满（32个结构）"
	var reference=str(state.sandbox_reference(batch.work).get("reference_id",""))
	var record={"id":id,"name":str(batch.name),"formula":state.sandbox_formula(batch.work),"source_batch":batch_id,"reference":reference,"work":batch.work.duplicate(true)}
	if not state.storage.take_product(batch_id,1): return "样品数量不足"
	records[id]=record
	return "已消耗1份样品留档；结构身份不等于宏观物性认证"

func propose(record_id: String,kind: String,mode: String,properties: Dictionary) -> String:
	if not records.has(record_id): return "先选择已留档的结构"
	var proof=fixture.build(record_id,kind,mode,properties)
	if proof.is_empty(): return "所需性质仍未知或超出试验范围，请明确填写假设"
	if designs.has(proof.id): return "相同方案已保存，无需重复创建"
	if designs.size()>=int(fixture.rules.max_designs): return "方案档案已满（96份）"
	designs[proof.id]=proof
	return "条件计算已保存；这是玩家假设方案，只能用于隔离计算"

func serialize() -> Dictionary:
	return {"version":2,"records":records.duplicate(true),"designs":designs.duplicate(true)}

func restore(data,state) -> bool:
	if not data is Dictionary or not preload("res://scripts/island_storage.gd").count_ok(data.get("version")) or int(data.get("version",0)) not in [1,2] or not data.get("records") is Dictionary or not data.get("designs") is Dictionary: return false
	if data.records.size()>int(fixture.rules.max_records) or data.designs.size()>int(fixture.rules.max_designs): return false
	for id in data.records:
		var r=data.records[id]
		if not r is Dictionary or r.get("id")!=id or not r.get("work") is Dictionary or not state.sandbox_validate(r.work) or r.work.atoms.is_empty(): return false
		if id!=identity(r.work) or r.get("formula")!=state.sandbox_formula(r.work) or r.get("reference")!=str(state.sandbox_reference(r.work).get("reference_id","")): return false
		if not r.get("name") is String or r.name.is_empty() or r.name.length()>120 or not r.get("source_batch") is String or r.source_batch.is_empty() or r.source_batch.length()>120: return false
	for id in data.designs:
		var d=data.designs[id]
		if not fixture.valid(d) or d.id!=id or not data.records.has(d.record_id): return false
		if d.basis=="family_model":
			if data.version<2 or not fixture.electrical._same(d.counts,preload("res://scripts/laminate_model.gd").new().counts(data.records[d.record_id].work)): return false
	records=data.records.duplicate(true); designs=data.designs.duplicate(true); return true

func propose_laminate(state,record_id: String,orientation: String,mode: String) -> String:
	if not state.planet.laminates.unlocked(state): return "先完成科研院所的分层构件方法研发"
	if not records.has(record_id): return "先留存一份铜铝结构提案"
	var model=state.planet.laminates.model
	var c=model.counts(records[record_id].work)
	if c.is_empty(): return "此模型只接受同时含铜、铝且没有其他元素的投料提案；其他结构继续保留未知性质"
	var d=model.build(record_id,c,orientation,mode)
	if d.is_empty(): return "选择有效的层片方向和几何约束"
	if designs.has(d.id): return "相同模型方案已保存"
	if designs.size()>=int(fixture.rules.max_designs): return "方案档案已满"
	designs[d.id]=d; return "已保存分层装配模型；这是标准层料构件估算，不是原子结构的实测物性"
