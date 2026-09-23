extends RefCounted
## Sparse, persistent changes over deterministic terrain. Inventory commits are atomic.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_nature.json"))
var edits={}
var trees={}
var seeds={"oak":0,"birch":0,"pine":0}
var revision=0
var chunk_versions={}
var planted_by_chunk={}

func cell_key(p: Vector2) -> String:
	return "%d:%d" % [roundi(p.x),roundi(p.y)]

func natural_id(p: Vector2) -> String:
	return "n:%d:%d" % [roundi(p.x/3.3),roundi(p.y/3.3)]

func touch(p: Vector2,t) -> void:
	revision+=1
	var chunk=t.chunk_at(p)
	for z in range(-1,2):
		for x in range(-1,2):
			var k=chunk+Vector2i(x,z); chunk_versions[k]=int(chunk_versions.get(k,0))+1

func descriptor(id: String,p: Vector2) -> Dictionary:
	var keys=rules.species.keys(); var kind=keys[posmod(roundi(p.x/3.3)*7+roundi(p.y/3.3)*13,3)]
	var row=trees.get(id,{"species":kind,"growth":1.0,"cut":false,"hits":0,"water":0.0})
	return {"id":id,"x":p.x,"z":p.y,"species":row.species,"growth":row.growth,"cut":row.cut,"hits":row.hits,"water":row.water}

func records(chunk: Vector2i,t) -> Array:
	var result=[]
	for p in t.chunk_tree_origins(chunk): result.append(descriptor(natural_id(p),p))
	for id in planted_by_chunk.get(chunk,[]):
		var row=trees[id]; result.append(descriptor(id,Vector2(row.x,row.z)))
	return result

func lookup(id: String,t) -> Dictionary:
	var parts=id.split(":")
	if parts.size()!=3 or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return {}
	if parts[0]=="p":
		if not trees.has(id): return {}
		return descriptor(id,Vector2(trees[id].x,trees[id].z))
	if parts[0]!="n": return {}
	var ix=int(parts[1]); var iz=int(parts[2])
	var p=Vector2(ix*3.3+sin(iz*12.7+ix)*0.8,iz*3.3+cos(ix*4.3)*0.8)
	if not t.inside(p,2) or p not in t.chunk_tree_origins(t.chunk_at(p)): return {}
	return descriptor(id,p)

func chop(id: String,field,t) -> String:
	var tree=lookup(id,t)
	if tree.is_empty() or tree.cut: return "这里已经只剩树桩"
	if tree.growth<0.99: return "这棵幼树还没长成，先照顾它"
	if not field.can_add("timber",int(rules.timber_yield)) or seeds[tree.species]>=int(rules.max_seed_stock): return "木料或树种已满，先整理背包"
	if not trees.has(id) and trees.size()>=int(rules.max_trees): return "林木记录已满"
	tree.hits+=1; trees[id]=tree
	if tree.hits<int(rules.chop_hits): touch(Vector2(tree.x,tree.z),t); return "%s · 砍伐 %d/%d" % [rules.species[tree.species].name,tree.hits,rules.chop_hits]
	tree.cut=true; tree.hits=0
	field.stock.timber+=int(rules.timber_yield); field.revision+=1; seeds[tree.species]+=1; touch(Vector2(tree.x,tree.z),t)
	return "%s倒下了：木料 ×%d，%s ×1。树桩不会自动刷回大树。" % [rules.species[tree.species].name,rules.timber_yield,rules.species[tree.species].seed]

func plant(kind: String,p: Vector2,v) -> String:
	var t=v.construction.terrain; p=p.round()
	if not seeds.has(kind) or seeds[kind]<1: return "背包里没有这种树种；砍成熟的同种树可得到"
	if not t.inside(p,2) or t.height_at(p)<0.22 or t.bridge(p) or t.on_path(p): return "请选一块干燥的空地"
	if t.blocked(p,v.construction.obstacles) or v.construction.overlaps(p,t.ground(p),5): return "这里有树木或建筑，换一块空地"
	for z in range(-1,2):
		for x in range(-1,2):
			for tree in records(t.chunk_at(p)+Vector2i(x,z),t):
				if not tree.cut and p.distance_to(Vector2(tree.x,tree.z))<2.2: return "树苗需要留出两米生长空间"
	var id="p:"+cell_key(p)
	if trees.has(id) and not trees[id].cut: return "这里已经有树苗"
	if not trees.has(id) and trees.size()>=int(rules.max_trees): return "林木记录已满"
	var chunk=t.chunk_at(p)
	if not planted_by_chunk.has(chunk): planted_by_chunk[chunk]=[]
	if id not in planted_by_chunk[chunk]: planted_by_chunk[chunk].append(id)
	seeds[kind]-=1; trees[id]={"id":id,"x":p.x,"z":p.y,"species":kind,"growth":0.12,"cut":false,"hits":0,"water":0.0}; touch(p,t)
	return "种下"+str(rules.species[kind].name)+"；雨水能让它慢慢长大，水样或水箱可加快生长"

func water_error(id: String,t) -> String:
	var tree=lookup(id,t)
	if tree.is_empty() or tree.cut or tree.growth>=1: return "请瞄准一棵还在生长的幼树"
	if tree.water>0.7: return "这棵树的土壤已经湿润"
	return ""

func water(id: String,t) -> void:
	trees[id].water=1.0; touch(Vector2(trees[id].x,trees[id].z),t)

func tick(t) -> void:
	for id in trees:
		var tree=trees[id]
		if tree.cut or tree.growth>=1: continue
		var phase=int(tree.growth*8)
		tree.growth=minf(1,tree.growth+(float(rules.watering_growth) if tree.water>0.1 else float(rules.rain_growth))/float(rules.growth_seconds))
		tree.water=maxf(0,tree.water-0.003)
		if int(tree.growth*8)!=phase: touch(Vector2(tree.x,tree.z),t)

func terraform(delta: int,point: Vector3,v) -> String:
	var c=v.construction; var t=c.terrain; var p=t.cell_center(Vector2(point.x,point.z)); var k=cell_key(p)
	if delta not in [-1,1] or not t.inside(p,3): return "只能在探索区内施工"
	if t.bridge(p) or t.on_path(p): return "公共桥梁和主路旁保留通行地面"
	if t.blocked(p,c.obstacles): return "先移开这里的树木或设施"
	for tree in records(t.chunk_at(p),t):
		if not tree.cut and p.distance_to(Vector2(tree.x,tree.z))<0.9: return "幼树正在这里扎根，换一块地施工"
	for b in c.blocks.values():
		if Vector2(b.x,b.z).distance_to(p)<1.0: return "先拆回上面的构件，以免建筑悬空或被掩埋"
	for entity in v.combat.entities(v):
		if entity.position.distance_to(p)<0.9: return "生物正在这里，等它走开再施工"
	var value=int(edits.get(k,0)); var next=value+delta
	if absi(next)>int(rules.height_change_limit): return "这一列已到当前可改造的高度范围"
	if not edits.has(k) and edits.size()>=int(rules.max_edits): return "改造记录已满，先恢复一些地面"
	if delta<0 and not v.field.can_add("soil",1): return "土方格已满"
	if delta>0 and v.field.stock.soil<1: return "需要1份土方；用铲子挖土获得"
	if delta>0 and not v.actor.is_empty():
		var feet: Vector3=v.actor.feet
		if absf(feet.x-p.x)<0.85 and absf(feet.z-p.y)<0.85 and feet.y<t.ground(p)+1: return "退开一点，不能把土填到脚下"
	v.field.stock.soil-=delta; v.field.revision+=1
	if next==0: edits.erase(k)
	else: edits[k]=next
	touch(p,t)
	return "挖出1份土方，地面下降一格" if delta<0 else "放下1份土方，地面抬高一格"

func serialize() -> Dictionary:
	return {"version":1,"edits":edits.duplicate(),"trees":trees.duplicate(true),"seeds":seeds.duplicate()}

func restore(data,t) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	for k in ["edits","trees","seeds"]:
		if not data.get(k) is Dictionary: return false
	if data.edits.size()>int(rules.max_edits) or data.trees.size()>int(rules.max_trees) or data.seeds.size()!=seeds.size(): return false
	for k in seeds:
		if not _num(data.seeds.get(k),0,rules.max_seed_stock,true): return false
	for k in data.edits:
		var parts=str(k).split(":")
		if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
		var p=Vector2(int(parts[0]),int(parts[1]))
		if k!=cell_key(p) or not t.inside(p,3) or not _num(data.edits[k],-rules.height_change_limit,rules.height_change_limit,true): return false
	for id in data.trees:
		var row=data.trees[id]
		if not row is Dictionary or not rules.species.has(row.get("species")) or not row.get("cut") is bool: return false
		if not _num(row.get("x"),-float(t.rules.radius),float(t.rules.radius)) or not _num(row.get("z"),-float(t.rules.radius),float(t.rules.radius)): return false
		var p=Vector2(row.x,row.z)
		if not t.inside(p,2): return false
		if str(id).begins_with("p:"):
			if p!=p.round() or id!="p:"+cell_key(p): return false
		elif lookup(str(id),t).is_empty() or id!=natural_id(p) or not p.is_equal_approx(Vector2(lookup(id,t).x,lookup(id,t).z)): return false
		if not _num(row.get("growth"),0.12,1) or not _num(row.get("water"),0,1) or not _num(row.get("hits"),0,int(rules.chop_hits)-1,true): return false
	edits=data.edits.duplicate(); trees=data.trees.duplicate(true); seeds=data.seeds.duplicate(); revision+=1; chunk_versions.clear(); planted_by_chunk.clear()
	for id in trees:
		if not str(id).begins_with("p:"): continue
		var chunk=t.chunk_at(Vector2(trees[id].x,trees[id].z))
		if not planted_by_chunk.has(chunk): planted_by_chunk[chunk]=[]
		planted_by_chunk[chunk].append(id)
	return true

func _num(n,lo: float,hi: float,whole: bool=false) -> bool:
	return (n is float or n is int) and is_finite(n) and n>=lo and n<=hi and (not whole or n==floor(n))
